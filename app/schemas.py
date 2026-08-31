"""リクエスト / レスポンスのスキーマ。"""

from pydantic import BaseModel, ConfigDict, Field


class GenerateRequest(BaseModel):
    model_config = ConfigDict(protected_namespaces=())

    prompt: str = Field(..., min_length=1, max_length=100_000, description="Gemini に渡す入力テキスト")
    system_instruction: str | None = Field(None, max_length=100_000, description="システム指示（役割や口調の指定）")
    model: str | None = Field(None, description="使うモデル。未指定なら GEMINI_MODEL")
    temperature: float | None = Field(None, ge=0.0, le=2.0)
    max_output_tokens: int | None = Field(None, ge=1, le=65_536)


class Usage(BaseModel):
    prompt_tokens: int | None = None
    output_tokens: int | None = None
    total_tokens: int | None = None


class GenerateResponse(BaseModel):
    model_config = ConfigDict(protected_namespaces=())

    text: str
    model: str
    cached: bool = False
    elapsed_ms: int
    usage: Usage | None = None


class ModelInfo(BaseModel):
    name: str
    display_name: str | None = None
    description: str | None = None
    input_token_limit: int | None = None
    output_token_limit: int | None = None


class ModelListResponse(BaseModel):
    count: int
    models: list[ModelInfo]


class HealthResponse(BaseModel):
    model_config = ConfigDict(protected_namespaces=())

    status: str
    model: str
    api_key_configured: bool


class ErrorResponse(BaseModel):
    detail: str
