"""画像生成モジュール。"""

from __future__ import annotations

from .base import GeneratedImage, ImageProvider, ProviderError
from .gemini_provider import GeminiProvider
from .local_provider import LocalProvider
from .openai_provider import OpenAIProvider
from .stability_provider import StabilityProvider

#: --provider auto のときに試す順番（APIキーがあるものが優先、最後は必ず動く local）
PROVIDERS: dict[str, type[ImageProvider]] = {
    "openai": OpenAIProvider,
    "gemini": GeminiProvider,
    "stability": StabilityProvider,
    "local": LocalProvider,
}


def get_provider(name: str) -> ImageProvider:
    """名前からプロバイダのインスタンスを得る。'auto' なら利用可能な先頭を選ぶ。"""
    if name == "auto":
        return auto_provider()
    if name not in PROVIDERS:
        raise ProviderError(
            f"未知のプロバイダです: {name} (選択肢: auto, {', '.join(PROVIDERS)})"
        )
    return PROVIDERS[name]()


def auto_provider() -> ImageProvider:
    """利用可能なプロバイダを優先順に選ぶ。"""
    for provider_cls in PROVIDERS.values():
        provider = provider_cls()
        if provider.is_available():
            return provider
    return LocalProvider()  # pragma: no cover - local は常に利用可能


def available_providers() -> list[tuple[str, bool, str]]:
    """(名前, 利用可否, 理由) の一覧を返す。"""
    result = []
    for name, provider_cls in PROVIDERS.items():
        provider = provider_cls()
        result.append((name, provider.is_available(), provider.unavailable_reason()))
    return result


def generate(
    prompt: str,
    *,
    provider: str = "auto",
    size: str = "1024x1024",
    n: int = 1,
    model: str | None = None,
) -> list[GeneratedImage]:
    """プロンプトから画像を生成する（もっとも手軽な入口）。"""
    return get_provider(provider).generate(prompt, size=size, n=n, model=model)


__all__ = [
    "GeneratedImage",
    "ImageProvider",
    "ProviderError",
    "PROVIDERS",
    "auto_provider",
    "available_providers",
    "generate",
    "get_provider",
]
