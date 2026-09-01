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
from .feed_edinet import EdinetFeed
from .feed_estat import EstatFeed
from .feed_qiita import QiitaFeed
from .feed_rss import RssFeed
from .feed_wikipedia import WikipediaFeed
from .github import GitHubConnector
from .images_cloudflare import CloudflareImages
from .images_gemini import GeminiImages
from .images_huggingface import HuggingFaceImages
from .images_local import LocalImages
from .images_openai import OpenAIImages
from .images_pollinations import PollinationsImages
from .images_replicate import ReplicateImages
from .images_stability import StabilityImages
from .speech_beep import BeepSpeech
from .speech_elevenlabs import ElevenLabsSpeech
from .speech_openai import OpenAISpeech
from .speech_voicevox import VoicevoxSpeech

__all__ = [
    "BeepSpeech",
    "CloudflareImages",
    "EdinetFeed",
    "ElevenLabsSpeech",
    "EstatFeed",
    "GeminiImages",
    "GitHubConnector",
    "HuggingFaceImages",
    "IconifyAssets",
    "LocalImages",
    "OpenAIImages",
    "OpenAISpeech",
    "OpenverseAssets",
    "PexelsAssets",
    "PixabayAssets",
    "PollinationsImages",
    "QiitaFeed",
    "ReplicateImages",
    "RssFeed",
    "StabilityImages",
    "VoicevoxSpeech",
    "WikipediaFeed",
    "UnsplashAssets",
    "WikimediaAssets",
]
