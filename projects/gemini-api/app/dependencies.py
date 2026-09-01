"""ルーターが使う依存。テストではこれを override する。"""

from fastapi import Request

from app.clients.gemini import GeminiClient
from app.config import Settings
from app.services.cache import CacheBackend


def get_settings_dep(request: Request) -> Settings:
    return request.app.state.settings


def get_client(request: Request) -> GeminiClient:
    return request.app.state.gemini_client


def get_cache(request: Request) -> CacheBackend:
    return request.app.state.cache
