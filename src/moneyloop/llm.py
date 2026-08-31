"""LLMクライアント。

`ClaudeClient` が本番、`StubClient` がオフライン用（--dry-run とテスト）。
どちらも同じ :class:`LLMResult` を返すので、上位のパイプラインは
どちらを渡されたかを意識しない。
"""

from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass
from typing import Any, Protocol

from .pricing import token_cost_usd

# 生成の一貫性を担保するシステムプロンプト。プロンプトキャッシュを効かせるため、
# 号ごとに変わる情報は絶対にここへ入れない（前半が1バイトでも変わるとキャッシュが無効化される）。
EDITOR_SYSTEM = """あなたは実務家向け有料ニュースレターの編集者です。読者は多忙な意思決定者で、
「読む時間」に対価を払っています。次の規律を厳守してください。

1. 事実は与えられた記事の範囲内でのみ述べる。記事にない数値・固有名詞を創作しない。
2. 推測・解釈を書くときは「筆者の見立て」と明示して事実と分ける。
3. 各トピックには必ず出典URLをMarkdownリンクで添える。原文の丸写しはせず、要約と分析を書く。
4. 「なぜ今これが重要か」「読者は明日何をすべきか」を必ず含める。一般論で埋めない。
5. 出力は日本語のMarkdown。見出しレベルは ## 以下を使う。
"""


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
        """構造化出力をパースする。tool入力と同様、素の文字列一致は使わない。"""
        try:
            return json.loads(self.text)
        except json.JSONDecodeError as exc:
            raise LLMError(f"構造化出力のJSONパースに失敗しました: {exc}") from exc


class LLMClient(Protocol):
    def complete(
        self,
        prompt: str,
        *,
        model: str,
        schema: dict | None = None,
        max_tokens: int = 16000,
        effort: str = "high",
        system: str = EDITOR_SYSTEM,
    ) -> LLMResult: ...


class ClaudeClient:
    """Anthropic公式SDK経由の実装。

    Claude Opus 5 の既定に合わせ、思考は adaptive（既定でオン）、
    安全分類による拒否に備えてサーバサイドフォールバックを有効にしている。
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
        # キー未設定でも `ant auth login` のプロファイルで解決されるため、
        # ここでキーの有無を検査しない。
        self.client = anthropic.Anthropic(api_key=key) if key else anthropic.Anthropic()
        self.enable_fallbacks = enable_fallbacks

    def complete(
        self,
        prompt: str,
        *,
        model: str,
        schema: dict | None = None,
        max_tokens: int = 16000,
        effort: str = "high",
        system: str = EDITOR_SYSTEM,
    ) -> LLMResult:
        kwargs: dict[str, Any] = {
            "model": model,
            "max_tokens": max_tokens,
            # 安定部分をキャッシュ対象にして、号を重ねるほど入力原価を下げる。
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

        text = "".join(b.text for b in response.content if b.type == "text")
        usage = response.usage
        return LLMResult(
            text=text,
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
            # SDK/アカウントがこのbetaに未対応の場合のみ、通常経路で再試行する。
            self.enable_fallbacks = False
            return self.client.messages.create(**kwargs)


class StubClient:
    """API不要の決定論的スタブ。

    課金が発生しないので、パイプラインの配線・冪等性・収支計算の検証に使う。
    スキーマが与えられた場合はそれを満たす最小のJSONを組み立てて返す。
    """

    def __init__(self, tokens_per_call: tuple[int, int] = (4000, 1500)) -> None:
        self.tokens_per_call = tokens_per_call
        self.calls: list[dict[str, Any]] = []

    def complete(
        self,
        prompt: str,
        *,
        model: str,
        schema: dict | None = None,
        max_tokens: int = 16000,
        effort: str = "high",
        system: str = EDITOR_SYSTEM,
    ) -> LLMResult:
        self.calls.append({"prompt": prompt, "model": model, "schema": schema})
        text = json.dumps(self._synth(schema, prompt), ensure_ascii=False) if schema else "(stub output)"
        return LLMResult(
            text=text,
            model=model,
            input_tokens=self.tokens_per_call[0],
            output_tokens=self.tokens_per_call[1],
        )

    def _synth(self, schema: dict, prompt: str) -> Any:
        """スキーマ駆動でダミー値を組み立てる。配列長はプロンプト内の項目数に合わせる。"""
        seed = int(hashlib.sha256(prompt.encode()).hexdigest()[:8], 16)
        n_items = max(1, prompt.count("[item "))

        def build(node: dict, depth: int = 0) -> Any:
            kind = node.get("type")
            if kind == "object":
                props = node.get("properties", {})
                return {k: build(v, depth + 1) for k, v in props.items()}
            if kind == "array":
                length = n_items if depth == 0 or "index" in str(node) else 2
                items = node.get("items", {"type": "string"})
                out = []
                for i in range(length):
                    value = build(items, depth + 1)
                    if isinstance(value, dict) and "index" in value:
                        value["index"] = i
                    if isinstance(value, dict) and "score" in value:
                        value["score"] = 60 + (seed + i * 7) % 40
                    out.append(value)
                return out
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
