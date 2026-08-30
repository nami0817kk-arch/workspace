"""ailab の連携基盤。コネクタの共通契約・登録簿・通信まわり。"""

from .connector import (
    AuthSpec,
    CheckResult,
    Connector,
    GenerateImage,
    PublishFile,
    RateLimit,
    SearchAssets,
)
from .errors import (
    AilabError,
    AuthError,
    ConfigError,
    ConnectorError,
    NetworkError,
    NotFoundError,
    RateLimitError,
)
from .types import Asset, GeneratedImage, PublishResult

__all__ = [
    "AilabError",
    "Asset",
    "AuthError",
    "AuthSpec",
    "CheckResult",
    "ConfigError",
    "Connector",
    "ConnectorError",
    "GenerateImage",
    "GeneratedImage",
    "NetworkError",
    "NotFoundError",
    "PublishFile",
    "PublishResult",
    "RateLimit",
    "RateLimitError",
    "SearchAssets",
]
