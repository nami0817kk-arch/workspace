"""フリーイラスト検索の共通インターフェース。"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import asdict, dataclass, field


class SourceError(RuntimeError):
    """素材サイト API のエラー。"""


@dataclass
class IllustItem:
    """検索でヒットした素材1点。ライセンス表記に必要な情報を必ず持たせる。"""

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


class IllustSource(ABC):
    """素材サイトの基底クラス。"""

    name: str = "base"
    api_key_env: str | None = None
    #: 表示用のライセンス概要
    license_note: str = ""

    def api_key(self) -> str | None:
        from ..config import get_env

        return get_env(self.api_key_env) if self.api_key_env else None

    def is_available(self) -> bool:
        return self.api_key_env is None or bool(self.api_key())

    def unavailable_reason(self) -> str:
        if self.is_available():
            return ""
        return f"環境変数 {self.api_key_env} が未設定です"

    @abstractmethod
    def search(self, query: str, *, limit: int = 10, timeout: int = 30) -> list[IllustItem]:
        """キーワードで素材を検索する。"""
        raise NotImplementedError
