"""フリー素材の検索・取得の入口（後方互換シム）。

実体は ailab.connectors の assets_* コネクタと ailab.assets。
"""

from __future__ import annotations

from .assets import download, download_all, search, write_credits
from .core import registry
from .core.errors import ConnectorError
from .core.types import Asset

#: 旧名との互換
IllustItem = Asset
SourceError = ConnectorError


def available_sources() -> list[tuple[str, bool, str]]:
    """(名前, 利用可否, 理由) の一覧を優先順に返す。"""
    return [
        (c.name, c.is_available(), c.unavailable_reason())
        for c in registry.by_capability("search_assets")
    ]


def get_source(name: str):
    connector = registry.get(name)
    if not hasattr(connector, "search_assets"):
        raise ConnectorError(f"{name} は素材検索に対応していません")
    return connector


__all__ = [
    "Asset",
    "IllustItem",
    "SourceError",
    "available_sources",
    "download",
    "download_all",
    "get_source",
    "search",
    "write_credits",
]
