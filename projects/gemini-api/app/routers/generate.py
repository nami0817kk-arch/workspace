import json
import logging
import time
from collections.abc import AsyncIterator

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse

from app.clients.gemini import GeminiClient, GeminiError
from app.dependencies import get_cache, get_client
from app.schemas import (
    GenerateRequest,
    GenerateResponse,
    ModelInfo,
    ModelListResponse,
    Usage,
)
from app.services import cache as cache_module
from app.services.cache import CacheBackend

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1", tags=["gemini"])


def _cache_key(body: GenerateRequest) -> str:
    return cache_module.make_key(
        prompt=body.prompt,
        system_instruction=body.system_instruction,
        model=body.model,
        temperature=body.temperature,
        max_output_tokens=body.max_output_tokens,
    )


@router.post("/generate", response_model=GenerateResponse, summary="テキストを生成する")
async def generate(
    body: GenerateRequest,
    client: GeminiClient = Depends(get_client),
    cache: CacheBackend = Depends(get_cache),
) -> GenerateResponse:
    started = time.perf_counter()
    key = _cache_key(body)

    hit = await cache.get(key)
    if hit is not None:
        return GenerateResponse(
            text=hit["text"],
            model=hit["model"],
            cached=True,
            elapsed_ms=int((time.perf_counter() - started) * 1000),
            usage=Usage(**hit["usage"]) if hit.get("usage") else None,
        )

    result = await client.generate(
        body.prompt,
        model=body.model,
        system_instruction=body.system_instruction,
        temperature=body.temperature,
        max_output_tokens=body.max_output_tokens,
    )
    await cache.set(key, {"text": result.text, "model": result.model, "usage": result.usage})

    return GenerateResponse(
        text=result.text,
        model=result.model,
        cached=False,
        elapsed_ms=int((time.perf_counter() - started) * 1000),
        usage=Usage(**result.usage) if result.usage else None,
    )


@router.post(
    "/generate/stream",
    summary="テキストを生成する（SSE ストリーミング）",
    response_class=StreamingResponse,
    responses={
        200: {
            "content": {"text/event-stream": {}},
            "description": (
                "text/event-stream。`data: {\"text\": \"...\"}` が届いた順に流れ、"
                "最後に `data: [DONE]`。途中で失敗した場合は `event: error` が流れる。"
            ),
        }
    },
)
async def generate_stream(
    body: GenerateRequest,
    client: GeminiClient = Depends(get_client),
) -> StreamingResponse:
    """ストリーミングはキャッシュしない（途中経過を保存しても再利用できないため）。"""

    async def event_source() -> AsyncIterator[str]:
        try:
            async for chunk in client.generate_stream(
                body.prompt,
                model=body.model,
                system_instruction=body.system_instruction,
                temperature=body.temperature,
                max_output_tokens=body.max_output_tokens,
            ):
                yield "data: " + json.dumps({"text": chunk}, ensure_ascii=False) + "\n\n"
        except GeminiError as exc:
            # ヘッダは送信済みなのでステータスは変えられない。エラーイベントで伝える
            logger.error("stream failed: %s", exc)
            payload = json.dumps(
                {"detail": str(exc), "status": exc.status_code}, ensure_ascii=False
            )
            yield f"event: error\ndata: {payload}\n\n"
            return
        yield "data: [DONE]\n\n"

    return StreamingResponse(
        event_source(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.get("/models", response_model=ModelListResponse, summary="利用可能なモデル一覧")
async def list_models(client: GeminiClient = Depends(get_client)) -> ModelListResponse:
    items = await client.list_models()
    models = [ModelInfo(**item) for item in items]
    return ModelListResponse(count=len(models), models=models)
