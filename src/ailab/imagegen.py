"""画像生成の入口（後方互換シム）。

実体は ailab.connectors の images_* コネクタ。既存コードのために
`imagegen.generate(...)` の呼び方を残してある。
"""

from __future__ import annotations

from .core import registry
from .core.errors import ConnectorError
from .core.types import GeneratedImage

#: 旧名との互換
ProviderError = ConnectorError


def available_providers() -> list[tuple[str, bool, str]]:
    """(名前, 利用可否, 理由) の一覧を優先順に返す。"""
    return [
        (c.name, c.is_available(), c.unavailable_reason())
        for c in registry.by_capability("generate")
    ]


def auto_provider():
    """利用可能な生成コネクタを優先順に選ぶ。"""
    usable = registry.by_capability("generate", available_only=True)
    if not usable:  # pragma: no cover - local が常にあるので通常起きない
        raise ConnectorError("使える画像生成コネクタがありません")
    return usable[0]


def get_provider(name: str = "auto"):
    """名前から生成コネクタを得る。'auto' なら利用可能な先頭を選ぶ。"""
    if name == "auto":
        return auto_provider()
    connector = registry.get(name)
    if not hasattr(connector, "generate"):
        raise ConnectorError(f"{name} は画像生成に対応していません")
    return connector


def generate(
    prompt: str,
    *,
    provider: str = "auto",
    size: str = "1024x1024",
    n: int = 1,
    model: str | None = None,
    fmt: str | None = None,
    max_width: int | None = None,
    **options,
) -> list[GeneratedImage]:
    """プロンプトから画像を生成する（もっとも手軽な入口）。

    生成の入口をここに集約し、利用量の記録と後処理（縮小・形式変換）も行う。
    CLI・レシピ・MCP はすべてこれを経由する。
    """
    from . import imaging, usage

    images = get_provider(provider).generate(prompt, size=size, n=n, model=model, **options)
    usage.record(images)  # 変換前の枚数で記録する
    if fmt or max_width:
        images = [imaging.convert(image, fmt=fmt, max_width=max_width) for image in images]
    return images


__all__ = [
    "GeneratedImage",
    "ProviderError",
    "auto_provider",
    "available_providers",
    "generate",
    "get_provider",
]
