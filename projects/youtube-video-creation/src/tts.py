"""セリフを音声にする層。バックエンドを2つ持つ。

- ``engine`` … VOICEVOX アプリ / ENGINE の HTTP API を叩く。手元に VOICEVOX がある場合はこれが一番手軽。
- ``core``   … VOICEVOX CORE (voicevox_core) を Python から直接呼ぶ。アプリの起動が不要なので
               サーバやCI、この種の自動化環境でも動く。`scripts/setup_voicevox_core.py` で用意する。

どちらも使えない場合は無音で埋め、尺だけ確認できる状態にする。
"""

from __future__ import annotations

import hashlib
import io
import json
import wave
from pathlib import Path

import requests

from .config import CastMember, ProjectConfig, _resolve
from .script_model import Line, Script

# 無音フォールバック時の wav フォーマット（VOICEVOX の出力に合わせる）
SILENT_PARAMS = (1, 2, 24000)  # channels, sampwidth, framerate


class TtsError(RuntimeError):
    pass


# --------------------------------------------------------------------- backends


class SilentBackend:
    """音声を作らず、文字数から推定した長さの無音を返す。"""

    name = "silent"

    def available(self) -> bool:
        return True

    def synthesize(self, line: Line, member: CastMember) -> bytes:
        return _silent_wav(line.estimated_duration())

    def speaker_name(self, style_id: int) -> str | None:
        return None


class EngineBackend:
    """VOICEVOX ENGINE の HTTP API。"""

    name = "engine"

    def __init__(self, url: str, timeout: int = 60):
        self.url = url.rstrip("/")
        self.timeout = timeout
        self._speakers: list[dict] | None = None

    def available(self) -> bool:
        try:
            requests.get(f"{self.url}/version", timeout=3).raise_for_status()
            return True
        except requests.RequestException:
            return False

    def speakers(self) -> list[dict]:
        if self._speakers is None:
            response = requests.get(f"{self.url}/speakers", timeout=self.timeout)
            response.raise_for_status()
            self._speakers = response.json()
        return self._speakers

    def speaker_name(self, style_id: int) -> str | None:
        try:
            for speaker in self.speakers():
                if any(style["id"] == style_id for style in speaker["styles"]):
                    return speaker["name"]
        except requests.RequestException:
            return None
        return None

    def synthesize(self, line: Line, member: CastMember) -> bytes:
        try:
            query = requests.post(
                f"{self.url}/audio_query",
                params={"text": line.text, "speaker": member.style_id},
                timeout=self.timeout,
            )
            query.raise_for_status()
            params = query.json()
            params["speedScale"] = line.speed if line.speed is not None else member.speed
            params["pitchScale"] = member.pitch
            params["intonationScale"] = member.intonation

            audio = requests.post(
                f"{self.url}/synthesis",
                params={"speaker": member.style_id},
                json=params,
                timeout=self.timeout,
            )
            audio.raise_for_status()
            return audio.content
        except requests.RequestException as exc:
            raise TtsError(f"VOICEVOX ENGINE への合成が失敗しました（{self.url}）: {exc}") from exc


class CoreBackend:
    """VOICEVOX CORE を Python から直接呼ぶ。

    ``core_dir`` には ONNX Runtime・Open JTalk 辞書・音声モデル(.vvm)が入っている想定。
    音声モデルは使うスタイルのぶんだけ遅延ロードする（全部読むとメモリを食うため）。
    """

    name = "core"

    def __init__(self, core_dir: Path):
        self.core_dir = core_dir
        self._synthesizer = None
        self._loaded: set[str] = set()
        self._index: dict | None = None

    # -- 素材の場所

    def _onnxruntime(self) -> Path | None:
        hits = sorted(self.core_dir.glob("**/libvoicevox_onnxruntime.so*"))
        hits += sorted(self.core_dir.glob("**/voicevox_onnxruntime.dll"))
        hits += sorted(self.core_dir.glob("**/libvoicevox_onnxruntime*.dylib"))
        return hits[0] if hits else None

    def _dict_dir(self) -> Path | None:
        hits = sorted(self.core_dir.glob("**/open_jtalk_dic_utf_8*"))
        return next((p for p in hits if p.is_dir()), None)

    def _vvm_dir(self) -> Path | None:
        hits = [p for p in self.core_dir.glob("**/vvms") if p.is_dir()]
        return hits[0] if hits else None

    def index(self) -> dict:
        """style_id -> vvm ファイル名 の対応表。無ければ .vvm を走査して作る。"""
        if self._index is not None:
            return self._index
        cache = self.core_dir / "vvm_index.json"
        if cache.exists():
            self._index = json.loads(cache.read_text(encoding="utf-8"))
            return self._index
        self._index = self.build_index()
        return self._index

    def build_index(self) -> dict:
        from voicevox_core.blocking import VoiceModelFile

        vvm_dir = self._vvm_dir()
        if vvm_dir is None:
            raise TtsError(f"音声モデル(.vvm)が見つかりません: {self.core_dir}")
        vvms: dict[str, str] = {}
        speakers: dict[str, dict[str, int]] = {}
        for path in sorted(vvm_dir.glob("*.vvm")):
            with VoiceModelFile.open(str(path)) as model:
                for meta in model.metas:
                    for style in meta.styles:
                        vvms[str(style.id)] = path.name
                        speakers.setdefault(meta.name, {})[style.name] = style.id
        index = {"vvms": vvms, "speakers": speakers}
        (self.core_dir / "vvm_index.json").write_text(
            json.dumps(index, ensure_ascii=False, indent=1), encoding="utf-8"
        )
        self._index = index
        return index

    # -- 合成

    def available(self) -> bool:
        try:
            import voicevox_core  # noqa: F401
        except ImportError:
            return False
        return bool(self._onnxruntime() and self._dict_dir() and self._vvm_dir())

    def _synth(self):
        if self._synthesizer is None:
            from voicevox_core.blocking import Onnxruntime, OpenJtalk, Synthesizer

            runtime = Onnxruntime.load_once(filename=str(self._onnxruntime()))
            self._synthesizer = Synthesizer(runtime, OpenJtalk(str(self._dict_dir())))
        return self._synthesizer

    def _ensure_style(self, style_id: int) -> None:
        from voicevox_core.blocking import VoiceModelFile

        name = self.index()["vvms"].get(str(style_id))
        if name is None:
            raise TtsError(
                f"style_id={style_id} を含む音声モデルがありません。"
                "`python -m src.cli speakers` で使えるIDを確認してください。"
            )
        if name in self._loaded:
            return
        with VoiceModelFile.open(str(self._vvm_dir() / name)) as model:
            self._synth().load_voice_model(model)
        self._loaded.add(name)

    def speaker_name(self, style_id: int) -> str | None:
        for name, styles in self.index().get("speakers", {}).items():
            if style_id in styles.values():
                return name
        return None

    def speakers(self) -> list[dict]:
        """EngineBackend.speakers() と同じ形に揃える。"""
        return [
            {"name": name, "styles": [{"name": s, "id": i} for s, i in styles.items()]}
            for name, styles in self.index().get("speakers", {}).items()
        ]

    def synthesize(self, line: Line, member: CastMember) -> bytes:
        self._ensure_style(member.style_id)
        synth = self._synth()
        query = synth.create_audio_query(line.text, member.style_id)
        query.speed_scale = line.speed if line.speed is not None else member.speed
        query.pitch_scale = member.pitch
        query.intonation_scale = member.intonation
        return synth.synthesis(query, member.style_id)


def create_backend(config: ProjectConfig, use_tts: bool = True):
    """設定に従ってバックエンドを選ぶ。auto は engine → core → silent の順に試す。"""
    if not use_tts:
        return SilentBackend()

    wanted = (config.voicevox.backend or "auto").lower()
    engine = EngineBackend(config.voicevox.url, config.voicevox.timeout)
    core = CoreBackend(_resolve(config.voicevox.core_dir))

    if wanted == "engine":
        if not engine.available():
            raise TtsError(
                f"VOICEVOX ENGINE に接続できません（{config.voicevox.url}）。"
                "VOICEVOX を起動するか、backend を auto / core にしてください。"
            )
        return engine
    if wanted == "core":
        if not core.available():
            raise TtsError(
                "VOICEVOX CORE が使えません。`python scripts/setup_voicevox_core.py` を実行してください。"
            )
        return core
    if wanted == "silent":
        return SilentBackend()
    if wanted != "auto":
        raise TtsError(f"未対応の backend: {wanted}（auto / engine / core / silent）")

    if engine.available():
        return engine
    if core.available():
        return core
    return SilentBackend()


# ----------------------------------------------------------------- 台本まるごと


def synthesize_script(
    script: Script,
    config: ProjectConfig,
    out_dir: Path,
    use_tts: bool = True,
    backend=None,
) -> str:
    """全行を音声化し、各 Line に audio_path / duration / start を埋める。

    戻り値は実際に使ったバックエンド名（engine / core / silent）。
    """
    out_dir.mkdir(parents=True, exist_ok=True)
    backend = backend or create_backend(config, use_tts)

    cursor = 0.0
    for index, line in enumerate(script.lines):
        member = config.resolve_speaker(line.speaker)
        pause = config.voicevox.pause if line.pause is None else line.pause
        target = out_dir / f"{index:04d}_{member.key}_{_digest(line, member, pause, backend.name)}.wav"

        if not target.exists():
            _write_padded(backend.synthesize(line, member), pause, target)

        line.audio_path = target
        line.pause = pause  # 描画側が末尾の無音を口パクから外すために使う
        line.duration = wav_duration(target)
        line.start = cursor
        cursor += line.duration

    return backend.name


def credits(script: Script, config: ProjectConfig, backend) -> list[str]:
    """概要欄に入れるクレジット。VOICEVOX の規約でキャラ名の表記が必要。

    config に定義してあっても、その動画で使っていない話者はクレジットしない。
    """
    used = {config.resolve_speaker(line.speaker).style_id for line in script.lines}
    names: list[str] = []
    for style_id in sorted(used):
        name = backend.speaker_name(style_id)
        if name and name not in names:
            names.append(name)
    if not names:
        return []
    return [f"音声: VOICEVOX（{'・'.join(names)}）"]


def wav_duration(path: Path) -> float:
    with wave.open(str(path), "rb") as handle:
        return handle.getnframes() / float(handle.getframerate())


def _write_padded(raw: bytes, pause: float, target: Path) -> None:
    """合成結果の後ろに無音を足して保存する（行間の“間”）。"""
    with wave.open(io.BytesIO(raw), "rb") as source:
        channels, sampwidth, framerate = (
            source.getnchannels(),
            source.getsampwidth(),
            source.getframerate(),
        )
        frames = source.readframes(source.getnframes())
    silence = b"\x00" * int(framerate * max(0.0, pause)) * channels * sampwidth
    _write_wav(target, channels, sampwidth, framerate, frames + silence)


def _silent_wav(seconds: float) -> bytes:
    channels, sampwidth, framerate = SILENT_PARAMS
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as out:
        out.setnchannels(channels)
        out.setsampwidth(sampwidth)
        out.setframerate(framerate)
        out.writeframes(b"\x00" * int(framerate * max(0.0, seconds)) * channels * sampwidth)
    return buffer.getvalue()


def _write_wav(target: Path, channels: int, sampwidth: int, framerate: int, frames: bytes) -> None:
    with wave.open(str(target), "wb") as out:
        out.setnchannels(channels)
        out.setsampwidth(sampwidth)
        out.setframerate(framerate)
        out.writeframes(frames)


def _digest(line: Line, member: CastMember, pause: float, backend: str) -> str:
    """同じ条件なら再合成しないためのキャッシュキー。"""
    seed = (
        f"{backend}|{line.text}|{member.style_id}|{line.speed or member.speed}"
        f"|{member.pitch}|{member.intonation}|{pause}"
    )
    return hashlib.sha1(seed.encode("utf-8")).hexdigest()[:8]


def _plain(text: str) -> str:
    """Commons の作者欄は HTML で返る。表示用にタグを落とす。"""
    import re

    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", text)).strip()


def image_credits(script, root=None) -> list[str]:
    """台本が使っている画像のクレジット。

    CC BY 系は表示が必須で、書かないと利用条件を満たさない。素材を取ったときに
    imagegen が credits.json を残しているので、実際に使った画像の分だけ拾う。
    自前生成の背景（assets/backgrounds）は権利が無いので何も出さない。
    """
    import json
    from pathlib import Path

    root = Path(root) if root else Path(".")
    def origin(path: str) -> str:
        """使った背景の元になった画像の名前。クリップなら記録から辿る。"""
        target = root / path
        sidecar = target.with_suffix(target.suffix + ".source.txt")
        if sidecar.exists():
            return sidecar.read_text(encoding="utf-8").strip()
        return Path(path).name

    used = {origin(scene.background) for scene in script.scenes if scene.background}
    if script.background:
        used.add(origin(script.background))
    # 行に image: で差し込んだ写真も拾う。背景だけ見ていたので、選手の写真に
    # クレジットが付いていなかった（2026-09-04 実測）。CC BY は表示が必須で、
    # 出ていないと利用条件を満たさない。
    for scene in script.scenes:
        for line in scene.lines:
            if getattr(line, "image", None):
                used.add(origin(line.image))

    lines: list[str] = []
    for ledger in sorted(root.glob("assets/images/**/credits.json")):
        try:
            rows = json.loads(ledger.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        for row in rows if isinstance(rows, list) else rows.get("items", []):
            name = str(row.get("file") or row.get("filename") or "")
            if Path(name).name not in used:
                continue
            title = str(row.get("title", "")).strip()
            author = str(row.get("author") or row.get("creator") or "").strip()
            license_ = str(row.get("license", "")).strip()
            # Commons の控えは配布元ページを page_url に持つ。source は
            # "wikimedia" のような媒体名なので、URL としては使えない。
            url = str(row.get("page_url") or row.get("url") or "").strip()
            author = _plain(author)
            part = " / ".join(x for x in (title, author, license_, url) if x)
            if part and part not in lines:
                lines.append(part)
    return [f"画像: {line}" for line in lines]
