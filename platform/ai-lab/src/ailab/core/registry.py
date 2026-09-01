"""コネクタの登録簿。CLI も MCP もここだけを見る。"""

from __future__ import annotations

from .connector import CAPABILITIES, Connector
from .errors import ConfigError

_REGISTRY: dict[str, type[Connector]] = {}
_LOADED = False


def _ensure_loaded() -> None:
    """初回アクセス時に ailab.connectors を読み込んで登録を済ませる。

    import 時ではなく呼び出し時に読むことで、コネクタ側が registry を
    import していても循環しない。
    """
    global _LOADED
    if _LOADED:
        return
    _LOADED = True
    from .. import connectors  # noqa: F401  (登録のための副作用 import)


def register(connector_cls: type[Connector]) -> type[Connector]:
    """コネクタを登録する（クラスデコレータとして使う）。"""
    name = connector_cls.name
    if not name or name == "base":
        raise ConfigError(f"{connector_cls.__name__} に name が設定されていません")
    if name in _REGISTRY and _REGISTRY[name] is not connector_cls:
        raise ConfigError(f"コネクタ名が重複しています: {name}")
    _REGISTRY[name] = connector_cls
    return connector_cls


def names() -> list[str]:
    """優先順位（priority、同値なら名前）順のコネクタ名。"""
    _ensure_loaded()
    return sorted(_REGISTRY, key=lambda name: (_REGISTRY[name].priority, name))


def get(name: str, **kwargs) -> Connector:
    """名前からコネクタのインスタンスを作る。"""
    _ensure_loaded()
    if name not in _REGISTRY:
        raise ConfigError(f"未知のコネクタです: {name}（一覧: ailab connectors）")
    return _REGISTRY[name](**kwargs)


def all_connectors(**kwargs) -> list[Connector]:
    return [_REGISTRY[name](**kwargs) for name in names()]


def by_category(category: str, **kwargs) -> list[Connector]:
    return [c for c in all_connectors(**kwargs) if c.category == category]


def by_capability(capability: str, *, available_only: bool = False, **kwargs) -> list[Connector]:
    """能力（search_assets / generate / publish）を持つコネクタを返す。"""
    if capability not in CAPABILITIES:
        raise ConfigError(f"未知の能力です: {capability}（{', '.join(CAPABILITIES)}）")
    protocol = CAPABILITIES[capability]
    found = [c for c in all_connectors(**kwargs) if isinstance(c, protocol)]
    return [c for c in found if c.is_available()] if available_only else found
