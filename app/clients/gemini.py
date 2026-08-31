"""Gemini API を叩く薄いクライアント層。

google-genai SDK をラップし、タイムアウト・リトライ・エラー変換だけを足す。
ルーター側は SDK の型を直接触らない。
"""

from __future__ import annotations

import asyncio
import logging
from collections.abc import AsyncIterator
from dataclasses import dataclass, field

from google import genai
from google.genai import types

from app.config import Settings

logger = logging.getLogger(__name__)

# リトライ対象にする上流ステータス（レート制限と一時的なサーバ側障害）
RETRYABLE_STATUS = {429, 500, 502, 503, 504}

# リトライを使い切ったとき、クライアントにそのまま返す上流ステータス。
# これ以外（上流の 500 など）は自分側の 502 に丸める。
PASSTHROUGH_ON_EXHAUSTION = {429, 503}


class GeminiError(RuntimeError):
    """上流 API 由来のエラー。status_code はクライアントに返す HTTP ステータス。"""

    def __init__(self, message: str, status_code: int = 502) -> None:
        super().__init__(message)
        self.status_code = status_code


@dataclass
class GenerationResult:
    text: str
    model: str
    usage: dict[str, int | None] = field(default_factory=dict)


def _upstream_status(exc: Exception) -> int | None:
    """SDK の例外から上流の HTTP ステータスを取り出す（取れなければ None）。"""
    for attr in ("code", "status_code"):
        value = getattr(exc, attr, None)
        if isinstance(value, int):
            return value
    response = getattr(exc, "response", None)
    value = getattr(response, "status_code", None)
    return value if isinstance(value, int) else None


def _extract_usage(response: object) -> dict[str, int | None]:
    meta = getattr(response, "usage_metadata", None)
    if meta is None:
        return {}
    return {
        "prompt_tokens": getattr(meta, "prompt_token_count", None),
        "output_tokens": getattr(meta, "candidates_token_count", None),
        "total_tokens": getattr(meta, "total_token_count", None),
    }


class GeminiClient:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        # api_key を渡さない場合、SDK が GEMINI_API_KEY / GOOGLE_API_KEY を自動で拾う
        self._client = (
            genai.Client(api_key=settings.gemini_api_key)
            if settings.gemini_api_key
            else genai.Client()
        )

    def _build_config(
        self,
        *,
        system_instruction: str | None,
        temperature: float | None,
        max_output_tokens: int | None,
    ) -> types.GenerateContentConfig:
        settings = self._settings
        return types.GenerateContentConfig(
            temperature=settings.temperature if temperature is None else temperature,
            max_output_tokens=(
                settings.max_output_tokens if max_output_tokens is None else max_output_tokens
            ),
            system_instruction=system_instruction,
            # tools を渡していないので自動関数呼び出しは不要。有効なままだと毎回警告が出る
            automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
        )

    async def generate(
        self,
        prompt: str,
        *,
        model: str | None = None,
        system_instruction: str | None = None,
        temperature: float | None = None,
        max_output_tokens: int | None = None,
    ) -> GenerationResult:
        model_name = model or self._settings.gemini_model
        config = self._build_config(
            system_instruction=system_instruction,
            temperature=temperature,
            max_output_tokens=max_output_tokens,
        )

        async def call() -> object:
            return await self._client.aio.models.generate_content(
                model=model_name,
                contents=prompt,
                config=config,
            )

        response = await self._with_retry(call, what=f"generate_content({model_name})")
        text = getattr(response, "text", None)
        if not text:
            # セーフティフィルタ等で候補が空になるケース
            raise GeminiError("モデルがテキストを返しませんでした（安全フィルタ等の可能性）", 502)
        return GenerationResult(text=text, model=model_name, usage=_extract_usage(response))

    async def generate_stream(
        self,
        prompt: str,
        *,
        model: str | None = None,
        system_instruction: str | None = None,
        temperature: float | None = None,
        max_output_tokens: int | None = None,
    ) -> AsyncIterator[str]:
        """生成されたテキストを届いた順に yield する。

        リトライがかかるのはストリームを張るところまで。いったん本文が流れ始めたら、
        途中で失敗しても最初からやり直さない（同じ内容が二重に届くため）。
        """
        model_name = model or self._settings.gemini_model
        config = self._build_config(
            system_instruction=system_instruction,
            temperature=temperature,
            max_output_tokens=max_output_tokens,
        )

        async def start() -> object:
            return await self._client.aio.models.generate_content_stream(
                model=model_name,
                contents=prompt,
                config=config,
            )

        stream = await self._with_retry(start, what=f"generate_content_stream({model_name})")

        try:
            async for chunk in stream:
                text = getattr(chunk, "text", None)
                if text:
                    yield text
        except GeminiError:
            raise
        except Exception as exc:
            status = _upstream_status(exc)
            raise GeminiError(
                f"ストリーミング中に Gemini API との接続が切れました: {exc}",
                status if status is not None else 502,
            ) from exc

    async def list_models(self) -> list[dict[str, object]]:
        """利用可能なモデル一覧を取得する。

        SDK のページャは同期イテレータなので、別スレッドで回してからまとめて返す。
        """

        def collect() -> list[dict[str, object]]:
            items: list[dict[str, object]] = []
            for m in self._client.models.list():
                items.append(
                    {
                        "name": getattr(m, "name", "") or "",
                        "display_name": getattr(m, "display_name", None),
                        "description": getattr(m, "description", None),
                        "input_token_limit": getattr(m, "input_token_limit", None),
                        "output_token_limit": getattr(m, "output_token_limit", None),
                    }
                )
            return items

        return await self._with_retry(lambda: asyncio.to_thread(collect), what="models.list")

    async def _with_retry(self, call, *, what: str):
        settings = self._settings
        last_exc: Exception | None = None
        last_status: int | None = None

        for attempt in range(settings.max_retries + 1):
            try:
                return await asyncio.wait_for(call(), timeout=settings.request_timeout)
            except asyncio.TimeoutError as exc:
                last_exc, last_status = exc, None
                logger.warning("%s timed out (attempt %d)", what, attempt + 1)
            except Exception as exc:  # SDK の例外階層に依存しすぎないよう広く受ける
                status = _upstream_status(exc)
                if status is not None and status not in RETRYABLE_STATUS:
                    raise GeminiError(f"Gemini API エラー: {exc}", status) from exc
                last_exc, last_status = exc, status
                logger.warning("%s failed with %s (attempt %d)", what, exc, attempt + 1)

            if attempt < settings.max_retries:
                await asyncio.sleep(2**attempt)  # 1s, 2s, 4s ...

        if isinstance(last_exc, asyncio.TimeoutError):
            raise GeminiError(
                f"Gemini API がタイムアウトしました（{settings.request_timeout}s）", 504
            ) from last_exc
        # 429 / 503 はクライアント側の再試行判断に使えるので、そのまま透過させる
        status = last_status if last_status in PASSTHROUGH_ON_EXHAUSTION else 502
        raise GeminiError(f"Gemini API の呼び出しに失敗しました: {last_exc}", status) from last_exc
