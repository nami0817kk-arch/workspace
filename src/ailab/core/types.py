"""コネクタが受け渡しする共通のデータ型。"""

from __future__ import annotations

import mimetypes
from dataclasses import asdict, dataclass, field
from pathlib import Path

from ..utils import slugify, timestamp


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
        return mimetypes.guess_extension(self.mime) or ".png"

    def default_name(self, index: int = 0) -> str:
        suffix = f"_{index + 1}" if index else ""
        return f"{timestamp()}_{self.provider}_{slugify(self.prompt)}{suffix}{self.ext}"

    def save(self, path: str | Path) -> Path:
        """画像をファイルに書き出す。path がディレクトリなら自動命名する。"""
        target = Path(path)
        if target.is_dir():
            target = target / self.default_name()
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(self.data)
        return target


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
