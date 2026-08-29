"""Web上のフリーイラスト・フリー素材を検索して取得するモジュール。"""

from __future__ import annotations

from .base import IllustItem, IllustSource, SourceError
from .downloader import download, download_all, write_credits
from .openverse import OpenverseSource
from .pixabay import PixabaySource
from .wikimedia import WikimediaSource

SOURCES: dict[str, type[IllustSource]] = {
    "openverse": OpenverseSource,
    "pixabay": PixabaySource,
    "wikimedia": WikimediaSource,
}


def get_source(name: str) -> IllustSource:
    if name not in SOURCES:
        raise SourceError(f"未知の素材サイトです: {name} (選択肢: all, {', '.join(SOURCES)})")
    return SOURCES[name]()


def available_sources() -> list[tuple[str, bool, str]]:
    """(名前, 利用可否, 理由) の一覧を返す。"""
    result = []
    for name, source_cls in SOURCES.items():
        source = source_cls()
        result.append((name, source.is_available(), source.unavailable_reason()))
    return result


def search(query: str, *, source: str = "all", limit: int = 10) -> list[IllustItem]:
    """フリー素材を検索する。source='all' なら使える全サイトを横断する。"""
    if source != "all":
        return get_source(source).search(query, limit=limit)

    items: list[IllustItem] = []
    errors: list[str] = []
    for name, source_cls in SOURCES.items():
        instance = source_cls()
        if not instance.is_available():
            continue
        try:
            items.extend(instance.search(query, limit=limit))
        except SourceError as exc:  # 1サイト落ちても他は返す
            errors.append(f"{name}: {exc}")
    if not items and errors:
        raise SourceError(" / ".join(errors))
    return items


__all__ = [
    "IllustItem",
    "IllustSource",
    "SOURCES",
    "SourceError",
    "available_sources",
    "download",
    "download_all",
    "get_source",
    "search",
    "write_credits",
]
