"""VOICEVOX ENGINE（手元で動く無料の音声合成）。

APIキーが要らず、生成した音声を商用でも使える。ただし**手元で VOICEVOX ENGINE が
起動している必要がある**（起動していなければ接続エラーになる）。
キーを1つも持っていない環境で本物の読み上げが作れる唯一のコネクタなので、
auto ではプレースホルダ（beep）の直前に選ばれる。

制約:
- 出力は WAV のみ。
- キャラクターごとに利用規約があり、**「VOICEVOX:キャラ名」のクレジット表記が要る**。
  文言は /speakers から引いて credit に載せるので、話者を変えても表記がずれない。
- 話者IDは環境によって増減する。`imagegen voices --provider voicevox` で確認する。
"""

from __future__ import annotations

from ..config import get_env
from ..core.connector import AuthSpec, CheckResult, Connector
from ..core.errors import ConfigError, NetworkError
from ..core.registry import register
from ..core.types import SynthesizedSpeech, Voice

DEFAULT_URL = "http://127.0.0.1:50021"


@register
class VoicevoxSpeech(Connector):
    name = "voicevox"
    category = "speech"
    summary = "手元の VOICEVOX ENGINE で読み上げ（APIキー不要・要クレジット表記）"
    #: 有料APIの後、プレースホルダの beep より前
    priority = 40
    auth = AuthSpec(
        env=("VOICEVOX_URL",),
        optional=True,
        signup_url="https://voicevox.hiroshiba.jp/",
        note="APIキーは不要。ENGINE を起動しておく（既定 http://127.0.0.1:50021）",
    )
    terms_url = "https://voicevox.hiroshiba.jp/term/"
    license_note = "生成音声の利用にはキャラクターごとの規約と『VOICEVOX:キャラ名』の表示が要る"
    default_model = "voicevox-engine"
    #: 話者ID。環境によって中身が違うので名前ではなくIDを既定にする
    default_voice = "3"
    #: 長文は合成に時間がかかるので、この長さで区切って合成する
    max_chars = 400

    def base_url(self) -> str:
        return (get_env("VOICEVOX_URL") or DEFAULT_URL).rstrip("/")

    def resolve_voice(self, voice: str | None = None) -> int:
        """話者IDを決める。優先順位は 引数 > VOICEVOX_SPEAKER > 既定値。"""
        raw = str(voice or get_env("VOICEVOX_SPEAKER") or self.default_voice).strip()
        if not raw.isdigit():
            raise ConfigError(
                f"voicevox の話者は数字のIDで指定します: {raw!r}"
                "（一覧: imagegen voices --provider voicevox）"
            )
        return int(raw)

    # --- 声の一覧 -----------------------------------------------------
    def list_voices(self) -> list[Voice]:
        speakers = self.get_json(f"{self.base_url()}/speakers", timeout=30)
        voices: list[Voice] = []
        for speaker in speakers or []:
            name = speaker.get("name", "")
            for style in speaker.get("styles") or []:
                voices.append(
                    Voice(
                        id=str(style.get("id", "")),
                        name=f"{name}（{style.get('name', '')}）",
                        provider=self.name,
                        detail="VOICEVOX",
                    )
                )
        return voices

    def credit_for(self, speaker_id: int) -> str:
        """クレジット表記を組み立てる。話者名が引けなければ製品名だけ返す。"""
        try:
            for voice in self.list_voices():
                if voice.id == str(speaker_id):
                    return f"VOICEVOX:{voice.name}"
        except (NetworkError, ValueError):  # 表記のために合成を失敗させない
            pass
        return "VOICEVOX"

    # --- 疎通確認 -----------------------------------------------------
    def check(self) -> CheckResult:
        try:
            version = self.request("GET", f"{self.base_url()}/version", timeout=10).text
        except NetworkError:
            # ENGINE が動いていないのは「壊れている」ではなく「用意がまだ」なので、
            # キー未設定と同じ未確認扱いにする（doctor 全体を失敗にしない）
            return CheckResult(
                self.name,
                ok=False,
                skipped=True,
                detail=f"ENGINE に接続できません（{self.base_url()} で起動しているか確認）",
            )
        return CheckResult(self.name, ok=True, detail=f"ENGINE {version.strip().strip(chr(34))}")

    # --- 合成 ---------------------------------------------------------
    def synthesize(
        self,
        text: str,
        *,
        voice: str | None = None,
        model: str | None = None,
        speed: float = 1.0,
        fmt: str | None = None,
        timeout: int = 180,
    ) -> SynthesizedSpeech:
        if fmt and fmt != "wav":
            raise ConfigError(f"voicevox は wav だけ出力できます（指定: {fmt}）")

        speaker = self.resolve_voice(voice)
        base = self.base_url()
        query = self.request(
            "POST", f"{base}/audio_query", params={"text": text, "speaker": speaker}, timeout=timeout
        ).json()
        query["speedScale"] = float(speed)

        response = self.request(
            "POST",
            f"{base}/synthesis",
            params={"speaker": speaker},
            json=query,
            headers={"Content-Type": "application/json"},
            timeout=timeout,
        )
        return SynthesizedSpeech(
            data=response.content,
            mime="audio/wav",
            provider=self.name,
            model=self.resolve_model(model),
            voice=str(speaker),
            text=text,
            credit=self.credit_for(speaker),
            meta={"speed": float(speed)},
        )
