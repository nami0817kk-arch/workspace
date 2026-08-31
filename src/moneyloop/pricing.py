"""料金表。左が原価（Claudeのトークン単価）、右が売価（購読プラン）。

この2つを1ファイルに置いているのは、粗利がこの差でしか決まらないため。
価格改定時はここだけを触る。
"""

from __future__ import annotations

from dataclasses import dataclass

# 1Mトークンあたりのドル単価 (input, output)。
# 出典: Anthropic 公開価格。改定時はここを更新する。
MODEL_PRICES_USD_PER_MTOK: dict[str, tuple[float, float]] = {
    "claude-fable-5": (10.00, 50.00),
    "claude-opus-5": (5.00, 25.00),
    "claude-opus-4-8": (5.00, 25.00),
    "claude-opus-4-7": (5.00, 25.00),
    "claude-opus-4-6": (5.00, 25.00),
    "claude-sonnet-5": (2.00, 10.00),
    "claude-sonnet-4-6": (3.00, 15.00),
    "claude-haiku-4-5": (1.00, 5.00),
}

# キャッシュ読み出しは入力単価の10%（概算）。号のプロンプト前半を再利用する運用向け。
CACHE_READ_DISCOUNT = 0.10


@dataclass(frozen=True)
class Plan:
    """購読プラン。paywalled=False は無料枠（ティザーのみ受信）。"""

    code: str
    name: str
    monthly_usd: float
    paywalled: bool


def token_cost_usd(
    model: str,
    input_tokens: int,
    output_tokens: int,
    cache_read_tokens: int = 0,
) -> float:
    """トークン使用量からAPI原価を算出する。未知モデルは Opus 5 相当で見積もる。"""
    in_rate, out_rate = MODEL_PRICES_USD_PER_MTOK.get(model, MODEL_PRICES_USD_PER_MTOK["claude-opus-5"])
    cost = (input_tokens * in_rate + output_tokens * out_rate) / 1_000_000
    cost += cache_read_tokens * in_rate * CACHE_READ_DISCOUNT / 1_000_000
    return cost
