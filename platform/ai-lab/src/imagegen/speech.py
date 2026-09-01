"""音声合成の入口。

実体は imagegen.connectors の speech_* コネクタ。コネクタの選択と、合成の前後
（長文の分割・つなぎ直し・利用量の記録・クレジットの持ち回り）をここにまとめる。
CLI・レシピ・MCP はすべてここを通る。

長文をそのまま投げると、どのサービスでも入力の上限に当たる。上限はサービスごとに
違うので、**分割はコネクタではなくここでやる**（コネクタは1回分の合成だけを知っていればよい）。
"""

from __future__ import annotations

import io
import re
import wave
from pathlib import Path

from .core import registry
from .core.errors import ConfigError, ConnectorError
from .core.types import SynthesizedSpeech, Voice
from .utils import slugify, timestamp

#: 文の切れ目（句点・感嘆符・改行のうしろで切る）
SENTENCE_BOUNDARY = re.compile(r"(?<=[。．！？!?\n])")
CREDITS_MD = "CREDITS.md"


def available_providers() -> list[tuple[str, bool, str]]:
    """(名前, 利用可否, 理由) の一覧を優先順に返す。"""
    return [
        (c.name, c.is_available(), c.unavailable_reason())
        for c in registry.by_capability("synthesize")
    ]


def auto_provider():
    """利用可能な音声合成コネクタを優先順に選ぶ。"""
    usable = registry.by_capability("synthesize", available_only=True)
    if not usable:  # pragma: no cover - beep が常にあるので通常起きない
        raise ConnectorError("使える音声合成コネクタがありません")
    return usable[0]


def get_provider(name: str = "auto"):
    """名前から音声合成コネクタを得る。'auto' なら利用可能な先頭を選ぶ。"""
    if name == "auto":
        return auto_provider()
    connector = registry.get(name)
    if not hasattr(connector, "synthesize"):
        raise ConnectorError(f"{name} は音声合成に対応していません")
    return connector


def list_voices(provider: str = "auto") -> list[Voice]:
    """そのコネクタで使える声の一覧。"""
    return list(get_provider(provider).list_voices())


# --- 長文の分割 -------------------------------------------------------
def split_text(text: str, limit: int) -> list[str]:
    """文の切れ目を優先して、limit 文字以下のかたまりに分ける。

    1文が limit を超える場合だけ、やむを得ず文の途中で切る。
    """
    text = text.strip()
    if not text:
        return []
    if limit <= 0 or len(text) <= limit:
        return [text]

    chunks: list[str] = []
    current = ""
    for piece in SENTENCE_BOUNDARY.split(text):
        if not piece:
            continue
        while len(piece) > limit:  # 1文が長すぎるとき
            if current:
                chunks.append(current)
                current = ""
            chunks.append(piece[:limit])
            piece = piece[limit:]
        if len(current) + len(piece) > limit:
            chunks.append(current)
            current = piece
        else:
            current += piece
    if current.strip():
        chunks.append(current)
    return [chunk.strip() for chunk in chunks if chunk.strip()]


# --- WAV のつなぎ直し -------------------------------------------------
def join_wav(clips: list[SynthesizedSpeech]) -> SynthesizedSpeech:
    """分割して合成した WAV を1本につなぐ（標準ライブラリだけで行う）。"""
    if not clips:
        raise ConfigError("つなぐ音声がありません")
    if len(clips) == 1:
        return clips[0]

    settings: tuple | None = None
    frames: list[bytes] = []
    for clip in clips:
        try:
            with wave.open(io.BytesIO(clip.data)) as reader:
                current = (reader.getnchannels(), reader.getsampwidth(), reader.getframerate())
                if settings is None:
                    settings = current
                elif current != settings:
                    raise ConfigError(f"形式の違う音声はつなげません: {current} と {settings}")
                frames.append(reader.readframes(reader.getnframes()))
        except wave.Error as exc:
            raise ConfigError(f"WAV として読めませんでした: {exc}") from exc

    channels, width, rate = settings  # type: ignore[misc]
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as writer:
        writer.setnchannels(channels)
        writer.setsampwidth(width)
        writer.setframerate(rate)
        writer.writeframes(b"".join(frames))

    first = clips[0]
    return SynthesizedSpeech(
        data=buffer.getvalue(),
        mime="audio/wav",
        provider=first.provider,
        model=first.model,
        voice=first.voice,
        text="".join(clip.text for clip in clips),
        credit=first.credit,
        meta={**first.meta, "chunks": len(clips)},
    )


def can_join(clips: list[SynthesizedSpeech]) -> bool:
    """つなげる形式かどうか（WAV のときだけつなげる）。"""
    return len(clips) > 1 and all(clip.mime in ("audio/wav", "audio/x-wav") for clip in clips)


# --- 合成 -------------------------------------------------------------
def synthesize(
    text: str,
    *,
    provider: str = "auto",
    voice: str | None = None,
    model: str | None = None,
    speed: float = 1.0,
    fmt: str | None = None,
    join: bool = True,
    **options,
) -> list[SynthesizedSpeech]:
    """文章を読み上げた音声を作る（もっとも手軽な入口）。

    上限を超える長文は分割して合成する。WAV なら既定で1本につなぎ直す
    （つなげない形式のときは分かれたまま返す）。
    """
    from . import usage

    if not text or not text.strip():
        raise ConfigError("読み上げる文章が空です")

    connector = get_provider(provider)
    limit = int(getattr(connector, "max_chars", 0) or 0)
    chunks = split_text(text, limit)

    clips = [
        connector.synthesize(chunk, voice=voice, model=model, speed=speed, fmt=fmt, **options)
        for chunk in chunks
    ]
    usage.record_speech(clips)  # つなぐ前の回数で記録する（課金は合成した回数と文字数で決まる）

    if join and can_join(clips):
        return [join_wav(clips)]
    return clips


# --- 保存 -------------------------------------------------------------
def save_all(
    clips: list[SynthesizedSpeech], dest_dir: str | Path, *, basename: str | None = None
) -> list[Path]:
    """音声を保存する。複数あるときは連番を振る。"""
    directory = Path(dest_dir)
    saved: list[Path] = []
    for index, clip in enumerate(clips):
        if basename:
            suffix = f"_{index + 1}" if len(clips) > 1 else ""
            name = f"{slugify(basename)}{suffix}{clip.ext}"
        else:
            name = clip.default_name(index)
        saved.append(clip.save(directory / name))
    return saved


def write_credits(clips: list[SynthesizedSpeech], dest_dir: str | Path) -> Path | None:
    """表示が必要なクレジットを CREDITS.md に追記する。

    VOICEVOX のように、生成した音声を使うときにキャラクター名の表示が要る
    サービスがある。素材と同じく、出典は必ず手元に残す。
    """
    needed = sorted({clip.credit for clip in clips if clip.credit})
    if not needed:
        return None

    directory = Path(dest_dir)
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / CREDITS_MD
    existing = path.read_text(encoding="utf-8") if path.is_file() else ""
    lines = [line for line in (f"- {credit}" for credit in needed) if line not in existing]
    if not lines:
        return path

    header = "" if existing else "# クレジット\n"
    section = "\n## 音声\n" if "## 音声" not in existing else ""
    with path.open("a", encoding="utf-8") as stream:
        stream.write(f"{header}{section}" + "\n".join(lines) + "\n")
    return path


def default_basename(text: str) -> str:
    """文章から保存名を作る（先頭だけ使う）。"""
    return f"{timestamp()}_{slugify(text.strip().splitlines()[0] if text.strip() else 'speech', 24)}"


__all__ = [
    "SynthesizedSpeech",
    "auto_provider",
    "available_providers",
    "can_join",
    "default_basename",
    "get_provider",
    "join_wav",
    "list_voices",
    "save_all",
    "split_text",
    "synthesize",
    "write_credits",
]
