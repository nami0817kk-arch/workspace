"""料金表。

左（モデルのトークン単価）は LLM API料金計算ツールの表示元であり、
かつ AI機能を動かしたときの自分の原価でもある。
価格改定時はここだけを直せば、サイトの表示も台帳の原価計算も同時に追随する。
"""

from __future__ import annotations

# 1Mトークンあたりのドル単価 (input, output)。出典: Anthropic 公開価格。
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

# キャッシュ読み出しは入力単価の10%（概算）。
CACHE_READ_DISCOUNT = 0.10


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
