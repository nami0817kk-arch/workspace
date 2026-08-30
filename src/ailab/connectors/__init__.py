"""連携コネクタ。import されると registry へ自動登録される。

新しい連携先はこのフォルダに1ファイル追加し、ここに import を1行足すだけでよい。
CLI・MCP 側の変更は不要。
"""

from .assets_iconify import IconifyAssets
from .assets_openverse import OpenverseAssets
from .assets_pexels import PexelsAssets
from .assets_pixabay import PixabayAssets
from .assets_unsplash import UnsplashAssets
from .assets_wikimedia import WikimediaAssets
from .feed_qiita import QiitaFeed
from .feed_rss import RssFeed
from .github import GitHubConnector
from .images_gemini import GeminiImages
from .images_huggingface import HuggingFaceImages
from .images_local import LocalImages
from .images_openai import OpenAIImages
from .images_pollinations import PollinationsImages
from .images_replicate import ReplicateImages
from .images_stability import StabilityImages


__all__ = [
    "GeminiImages",
    "GitHubConnector",
    "HuggingFaceImages",
    "IconifyAssets",
    "LocalImages",
    "OpenAIImages",
    "OpenverseAssets",
    "PexelsAssets",
    "PixabayAssets",
    "PollinationsImages",
    "QiitaFeed",
    "ReplicateImages",
    "RssFeed",
    "StabilityImages",
    "UnsplashAssets",
    "WikimediaAssets",
]
