"""コネクタが受け渡しする共通のデータ型。"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from pathlib import Path

from ..utils import extension_for, slugify, timestamp


def _write_binary(data: bytes, path: str | Path, default_name: str) -> Path:
    """バイト列をファイルに書き出す。path がディレクトリなら自動命名する。"""
    target = Path(path)
    if target.is_dir():
        target = target / default_name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    return target


@dataclass
class Asset:
    """素材サイトで見つかった素材1点。ライセンス表記に必要な情報を必ず持たせる。"""

    source: str
    title: str
    image_url: str
    page_url: str = ""
    thumbnail_url: str = ""
    license: str = "unknown"
    license_url: str = ""
    creator: str = ""
    creator_url: str = ""
    width: int = 0
    height: int = 0
    source_id: str = ""
    tags: list[str] = field(default_factory=list)
    #: サイト固有の情報（Unsplash のダウンロード計測URLなど）
    meta: dict = field(default_factory=dict)

    @property
    def attribution(self) -> str:
        """クレジット表記用の1行テキスト。"""
        parts = [f'"{self.title}"' if self.title else "(無題)"]
        if self.creator:
            parts.append(f"by {self.creator}")
        if self.page_url:
            parts.append(f"({self.page_url})")
        parts.append(f"[{self.license}]")
        return " ".join(parts)

    def to_dict(self) -> dict:
        data = asdict(self)
        data["attribution"] = self.attribution
        return data


@dataclass
class GeneratedImage:
    """生成された画像1枚。"""

    data: bytes
    mime: str = "image/png"
    provider: str = ""
    model: str = ""
    prompt: str = ""
    meta: dict = field(default_factory=dict)

    @property
    def ext(self) -> str:
        return extension_for(self.mime)

    def default_name(self, index: int = 0) -> str:
        suffix = f"_{index + 1}" if index else ""
        return f"{timestamp()}_{self.provider}_{slugify(self.prompt)}{suffix}{self.ext}"

    def save(self, path: str | Path) -> Path:
        """画像をファイルに書き出す。path がディレクトリなら自動命名する。"""
        return _write_binary(self.data, path, self.default_name())


@dataclass
class SynthesizedSpeech:
    """合成された音声1本。

    素材と同じく**クレジット表記を持ち回る**（VOICEVOX のように、生成物の利用に
    キャラクター名の表示が要るサービスがあるため）。
    """

    data: bytes
    mime: str = "audio/wav"
    provider: str = ""
    model: str = ""
    voice: str = ""
    text: str = ""
    #: 表示が必要なクレジット（例: "VOICEVOX:ずんだもん"）。不要なサービスは空
    credit: str = ""
    meta: dict = field(default_factory=dict)

    @property
    def ext(self) -> str:
        return extension_for(self.mime, ".wav")

    @property
    def chars(self) -> int:
        return len(self.text)

    @property
    def seconds(self) -> float | None:
        """再生時間（WAV のときだけ分かる。MP3 などは None）。"""
        if self.ext != ".wav":
            return None
        import io
        import wave

        try:
            with wave.open(io.BytesIO(self.data)) as reader:
                return reader.getnframes() / float(reader.getframerate() or 1)
        except (wave.Error, EOFError, ValueError):
            return None

    def default_name(self, index: int = 0) -> str:
        suffix = f"_{index + 1}" if index else ""
        return f"{timestamp()}_{self.provider}_{slugify(self.text)}{suffix}{self.ext}"

    def save(self, path: str | Path) -> Path:
        """音声をファイルに書き出す。path がディレクトリなら自動命名する。"""
        return _write_binary(self.data, path, self.default_name())


@dataclass
class Voice:
    """音声合成コネクタが使える声1つ。"""

    id: str
    name: str
    provider: str = ""
    detail: str = ""

    def to_dict(self) -> dict:
        return asdict(self)

    def describe(self) -> str:
        return f"{self.id:<10} {self.name}" + (f"  ({self.detail})" if self.detail else "")


@dataclass
class PublishResult:
    """外部サービスへ送り出した結果。"""

    target: str
    url: str = ""
    detail: str = ""
    dry_run: bool = False

    def describe(self) -> str:
        head = f"[ドライラン] {self.target}" if self.dry_run else f"{self.target} へ送信しました"
        return " ".join(part for part in (head, self.url, self.detail) if part)


@dataclass
class FeedItem:
    """情報収集コネクタが返す記事・リリースなど1件。"""

    source: str
    title: str
    url: str = ""
    published: str = ""
    summary: str = ""
    author: str = ""
    tags: list[str] = field(default_factory=list)
    meta: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return asdict(self)

    def describe(self) -> str:
        head = f"{self.title}"
        when = f"（{self.published[:10]}）" if self.published else ""
        return f"{head}{when}"
