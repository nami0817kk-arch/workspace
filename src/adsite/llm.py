"""LLMクライアント。

このサイトでAIを使うのは**公開する文章を量産するためではない**。
生成記事の量産は検索スパムポリシー（スケールされたコンテンツの不正使用）に
該当し、順位もAdSenseアカウントも失う。

使うのは社内側だけ ―― 「次にどのツールを作るべきか」の提案。
提案は人間が取捨選択して初めて実装に進むので、公開物には直結しない。
"""

from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass
from typing import Any, Protocol

from .pricing import token_cost_usd

DEFAULT_MODEL = "claude-opus-5"


class LLMError(RuntimeError):
    """LLM呼び出しが利用可能な結果を返せなかった場合。"""


@dataclass
class LLMResult:
    text: str
    model: str
    input_tokens: int = 0
    output_tokens: int = 0
    cache_read_tokens: int = 0

    @property
    def cost_usd(self) -> float:
        return token_cost_usd(self.model, self.input_tokens, self.output_tokens, self.cache_read_tokens)

    def json(self) -> Any:
        """構造化出力をパースする。素の文字列一致はしない。"""
        try:
            return json.loads(self.text)
        except json.JSONDecodeError as exc:
            raise LLMError(f"構造化出力のJSONパースに失敗しました: {exc}") from exc


class LLMClient(Protocol):
    def complete(
        self, prompt: str, *, system: str, model: str = DEFAULT_MODEL, schema: dict | None = None,
        max_tokens: int = 16000, effort: str = "high",
    ) -> LLMResult: ...


class ClaudeClient:
    """Anthropic公式SDK経由の実装。

    思考は adaptive（Opus 5 の既定でオン）、安全分類による拒否に備えて
    サーバサイドフォールバックを有効にしている。
    """

    FALLBACK_BETA = "server-side-fallback-2026-07-01"

    def __init__(self, api_key: str | None = None, enable_fallbacks: bool = True) -> None:
        try:
            import anthropic
        except ImportError as exc:  # pragma: no cover - 実行環境依存
            raise LLMError(
                "anthropic パッケージが必要です。`pip install anthropic` するか --dry-run で実行してください。"
            ) from exc
        self._anthropic = anthropic
        key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        # キー未設定でも `ant auth login` のプロファイルで解決されるため、有無は検査しない。
        self.client = anthropic.Anthropic(api_key=key) if key else anthropic.Anthropic()
        self.enable_fallbacks = enable_fallbacks

    def complete(
        self, prompt: str, *, system: str, model: str = DEFAULT_MODEL, schema: dict | None = None,
        max_tokens: int = 16000, effort: str = "high",
    ) -> LLMResult:
        kwargs: dict[str, Any] = {
            "model": model,
            "max_tokens": max_tokens,
            # 安定部分をキャッシュ対象にする。可変情報を system に混ぜるとキャッシュが無効になる。
            "system": [{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
            "messages": [{"role": "user", "content": prompt}],
            "thinking": {"type": "adaptive"},
            "output_config": {"effort": effort},
        }
        if schema is not None:
            kwargs["output_config"]["format"] = {"type": "json_schema", "schema": schema}

        response = self._create(kwargs)

        if getattr(response, "stop_reason", None) == "refusal":
            details = getattr(response, "stop_details", None)
            raise LLMError(f"モデルがリクエストを拒否しました: {getattr(details, 'category', None)}")

        usage = response.usage
        return LLMResult(
            text="".join(b.text for b in response.content if b.type == "text"),
            model=getattr(response, "model", model),
            input_tokens=getattr(usage, "input_tokens", 0) or 0,
            output_tokens=getattr(usage, "output_tokens", 0) or 0,
            cache_read_tokens=getattr(usage, "cache_read_input_tokens", 0) or 0,
        )

    def _create(self, kwargs: dict[str, Any]):
        """フォールバック付きで送信し、未対応の環境では素の呼び出しに落とす。"""
        if not self.enable_fallbacks:
            return self.client.messages.create(**kwargs)
        try:
            return self.client.beta.messages.create(
                betas=[self.FALLBACK_BETA], fallbacks="default", **kwargs
            )
        except (self._anthropic.BadRequestError, TypeError):
            self.enable_fallbacks = False
            return self.client.messages.create(**kwargs)


class StubClient:
    """API不要の決定論的スタブ。--dry-run とテストで使う。"""

    def __init__(self, tokens_per_call: tuple[int, int] = (3000, 1200)) -> None:
        self.tokens_per_call = tokens_per_call
        self.calls: list[dict[str, Any]] = []

    def complete(
        self, prompt: str, *, system: str, model: str = DEFAULT_MODEL, schema: dict | None = None,
        max_tokens: int = 16000, effort: str = "high",
    ) -> LLMResult:
        self.calls.append({"prompt": prompt, "model": model, "schema": schema})
        text = json.dumps(self._synth(schema, prompt), ensure_ascii=False) if schema else "(stub output)"
        return LLMResult(
            text=text, model=model, input_tokens=self.tokens_per_call[0], output_tokens=self.tokens_per_call[1]
        )

    def _synth(self, schema: dict, prompt: str) -> Any:
        seed = int(hashlib.sha256(prompt.encode()).hexdigest()[:8], 16)

        def build(node: dict, depth: int = 0) -> Any:
            kind = node.get("type")
            if kind == "object":
                return {k: build(v, depth + 1) for k, v in node.get("properties", {}).items()}
            if kind == "array":
                return [build(node.get("items", {"type": "string"}), depth + 1) for _ in range(3)]
            if kind == "integer":
                return (seed % 40) + 60
            if kind == "number":
                return float((seed % 40) + 60)
            if kind == "boolean":
                return True
            return "(stub)"

        return build(schema)


def build_client(dry_run: bool, enable_fallbacks: bool = True) -> LLMClient:
    return StubClient() if dry_run else ClaudeClient(enable_fallbacks=enable_fallbacks)
