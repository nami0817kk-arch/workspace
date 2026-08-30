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
from .images_gemini import GeminiImages
from .images_huggingface import HuggingFaceImages
from .images_local import LocalImages
from .images_openai import OpenAIImages
from .images_replicate import ReplicateImages
from .images_stability import StabilityImages
from .publish_github import GitHubPublish

__all__ = [
    "GeminiImages",
    "GitHubPublish",
    "HuggingFaceImages",
    "IconifyAssets",
    "LocalImages",
    "OpenAIImages",
    "OpenverseAssets",
    "PexelsAssets",
    "PixabayAssets",
    "UnsplashAssets",
    "StabilityImages",
    "WikimediaAssets",
]
