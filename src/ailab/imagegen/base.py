"""画像生成プロバイダの共通インターフェース。"""

from __future__ import annotations

import mimetypes
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from pathlib import Path

from ..utils import slugify, timestamp


class ProviderError(RuntimeError):
    """画像生成プロバイダのエラー。"""


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


class ImageProvider(ABC):
    """画像生成プロバイダの基底クラス。"""

    name: str = "base"
    default_model: str = ""
    #: 必要な環境変数名（None なら APIキー不要）
    api_key_env: str | None = None

    def api_key(self) -> str | None:
        from ..config import get_env

        return get_env(self.api_key_env) if self.api_key_env else None

    def is_available(self) -> bool:
        """このプロバイダが今すぐ使えるか。"""
        return self.api_key_env is None or bool(self.api_key())

    def unavailable_reason(self) -> str:
        if self.is_available():
            return ""
        return f"環境変数 {self.api_key_env} が未設定です"

    @abstractmethod
    def generate(
        self,
        prompt: str,
        *,
        size: str = "1024x1024",
        n: int = 1,
        model: str | None = None,
        timeout: int = 180,
    ) -> list[GeneratedImage]:
        """プロンプトから画像を生成する。"""
        raise NotImplementedError
