from fastapi import APIRouter, Depends

from app.config import Settings
from app.dependencies import get_settings_dep
from app.schemas import HealthResponse

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse, summary="死活確認")
async def health(settings: Settings = Depends(get_settings_dep)) -> HealthResponse:
    """上流には問い合わせない。プロセスが生きているかと設定状況だけを返す。"""
    return HealthResponse(
        status="ok",
        model=settings.gemini_model,
        api_key_configured=bool(settings.gemini_api_key),
    )
