import time

from fastapi import APIRouter, Depends

from app.clients.gemini import GeminiClient
from app.dependencies import get_cache, get_client
from app.schemas import (
    GenerateRequest,
    GenerateResponse,
    ModelInfo,
    ModelListResponse,
    Usage,
)
from app.services.cache import TTLCache

router = APIRouter(prefix="/v1", tags=["gemini"])


@router.post("/generate", response_model=GenerateResponse, summary="テキストを生成する")
async def generate(
    body: GenerateRequest,
    client: GeminiClient = Depends(get_client),
    cache: TTLCache = Depends(get_cache),
) -> GenerateResponse:
    started = time.perf_counter()

    key = TTLCache.make_key(
        prompt=body.prompt,
        system_instruction=body.system_instruction,
        model=body.model,
        temperature=body.temperature,
        max_output_tokens=body.max_output_tokens,
    )
    hit = cache.get(key)
    if hit is not None:
        return GenerateResponse(
            text=hit.text,
            model=hit.model,
            cached=True,
            elapsed_ms=int((time.perf_counter() - started) * 1000),
            usage=Usage(**hit.usage) if hit.usage else None,
        )

    result = await client.generate(
        body.prompt,
        model=body.model,
        system_instruction=body.system_instruction,
        temperature=body.temperature,
        max_output_tokens=body.max_output_tokens,
    )
    cache.set(key, result)

    return GenerateResponse(
        text=result.text,
        model=result.model,
        cached=False,
        elapsed_ms=int((time.perf_counter() - started) * 1000),
        usage=Usage(**result.usage) if result.usage else None,
    )


@router.get("/models", response_model=ModelListResponse, summary="利用可能なモデル一覧")
async def list_models(client: GeminiClient = Depends(get_client)) -> ModelListResponse:
    items = await client.list_models()
    models = [ModelInfo(**item) for item in items]
    return ModelListResponse(count=len(models), models=models)
