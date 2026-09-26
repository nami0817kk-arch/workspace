"""kabutan.jp のランキング取得・解析の共有クライアント。

kabu-agari-ranking（公開サイト）が
同じ解析ロジックを二重に持っていたのを、ここに一本化した。
kabutan の HTML 構造が変わったときに直す場所はこのパッケージだけ。

利用側は薄いマッピング層（列名の変換・絞り込み）だけを持つ。
"""

from kabutan.client import (
    HEADERS,
    fetch_daily_html,
    fetch_stock_page,
    fetch_errors,
    fetch_ranking_html,
    fetch_stock_name,
)
from kabutan.parse import (
    extract_asof_date,
    parse_daily_prices,
    parse_ranking_table,
    parse_stock_profile,
)

MODE_GAINERS = "2_1"  # 今日の上昇率（値上がり率ランキング）
MODE_LOSERS = "2_2"   # 今日の下落率（値下がり率ランキング）
MODE_ACTIVE = "2_9"   # 本日の活況銘柄（約定回数。出来高そのものではない）
# 「その日ストップ高（安）をつけた銘柄」。引けまで保ったとは限らない
# （場中につけて下げた銘柄も載る）。引けで保ったかは at_limit で分かる。
MODE_STOP_HIGH = "3_1"
MODE_STOP_LOW = "3_2"

MARKETS = (1, 2, 3)   # プライム, スタンダード, グロース

__all__ = [
    "HEADERS",
    "MARKETS",
    "MODE_ACTIVE",
    "MODE_GAINERS",
    "MODE_LOSERS",
    "MODE_STOP_HIGH",
    "MODE_STOP_LOW",
    "extract_asof_date",
    "fetch_daily_html",
    "fetch_stock_page",
    "fetch_errors",
    "fetch_ranking_html",
    "fetch_stock_name",
    "parse_daily_prices",
    "parse_stock_profile",
    "parse_ranking_table",
]
