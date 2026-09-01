"""FastAPI アプリのエントリポイント。

起動: uvicorn app.main:app --reload
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.clients.gemini import GeminiClient, GeminiError
from app.config import Settings, get_settings
from app.routers import generate, health
from app.security import enforce_rate_limit, require_api_key
from app.services.cache import build_cache
from app.services.ratelimit import RateLimiter

logger = logging.getLogger("gemini-api")


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings: Settings = app.state.settings
    logging.basicConfig(
        level=settings.log_level.upper(),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    if not settings.gemini_api_key:
        logger.warning("GEMINI_API_KEY が未設定です。SDK の環境変数フォールバックに委ねます")
    if not settings.api_key_list:
        logger.warning("API_KEYS が未設定です。/v1 は認証なしで公開されます")

    app.state.gemini_client = GeminiClient(settings)
    app.state.cache = build_cache(settings.cache_ttl, settings.redis_url)
    app.state.rate_limiter = RateLimiter(settings.rate_limit_per_minute)
    logger.info(
        "started (model=%s, cache_ttl=%ss, rate_limit=%s/min)",
        settings.gemini_model,
        settings.cache_ttl,
        settings.rate_limit_per_minute or "無制限",
    )
    yield
    await app.state.cache.close()
    logger.info("shutting down")


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()

    app = FastAPI(
        title="Gemini API Gateway",
        description="Gemini API を叩いて結果を JSON で返す自分用のゲートウェイ。",
        version="0.1.0",
        lifespan=lifespan,
    )
    app.state.settings = settings

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=False,
        allow_methods=["GET", "POST"],
        allow_headers=["*"],
    )

    @app.exception_handler(GeminiError)
    async def gemini_error_handler(request: Request, exc: GeminiError) -> JSONResponse:
        logger.error("%s %s -> %s", request.method, request.url.path, exc)
        return JSONResponse(status_code=exc.status_code, content={"detail": str(exc)})

    app.include_router(health.router)
    app.include_router(
        generate.router,
        dependencies=[Depends(require_api_key), Depends(enforce_rate_limit)],
    )
    return app


app = create_app()
