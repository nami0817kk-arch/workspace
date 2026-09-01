"""imagegen の連携基盤。コネクタの共通契約・登録簿・通信まわり。"""

from .connector import (
    AuthSpec,
    CheckResult,
    Connector,
    GenerateImage,
    PublishFile,
    RateLimit,
    ReadFeed,
    SearchAssets,
    capabilities_of,
    reset_limiters,
)
from .errors import (
    AuthError,
    ConfigError,
    ConnectorError,
    ImagegenError,
    NetworkError,
    NotFoundError,
    RateLimitError,
)
from .types import Asset, FeedItem, GeneratedImage, PublishResult

__all__ = [
    "Asset",
    "AuthError",
    "AuthSpec",
    "CheckResult",
    "ConfigError",
    "Connector",
    "ConnectorError",
    "FeedItem",
    "GenerateImage",
    "GeneratedImage",
    "ImagegenError",
    "NetworkError",
    "NotFoundError",
    "PublishFile",
    "PublishResult",
    "RateLimit",
    "RateLimitError",
    "ReadFeed",
    "SearchAssets",
    "capabilities_of",
    "reset_limiters",
]
