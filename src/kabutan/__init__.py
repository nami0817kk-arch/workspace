"""kabutan.jp のランキング取得・解析の共有クライアント。

kabu-agari-ranking（公開サイト）と quality-gainer-tracker（記録・追跡）が
同じ解析ロジックを二重に持っていたのを、ここに一本化した。
kabutan の HTML 構造が変わったときに直す場所はこのパッケージだけ。

利用側は薄いマッピング層（列名の変換・絞り込み）だけを持つ。
"""

from kabutan.client import HEADERS, fetch_errors, fetch_ranking_html, fetch_stock_name
from kabutan.parse import extract_asof_date, parse_ranking_table

MODE_GAINERS = "2_1"  # 今日の上昇率（値上がり率ランキング）
MODE_LOSERS = "2_2"   # 今日の下落率（値下がり率ランキング）
MODE_ACTIVE = "2_9"   # 本日の活況銘柄（約定回数。出来高そのものではない）

MARKETS = (1, 2, 3)   # プライム, スタンダード, グロース

__all__ = [
    "HEADERS",
    "MARKETS",
    "MODE_ACTIVE",
    "MODE_GAINERS",
    "MODE_LOSERS",
    "extract_asof_date",
    "fetch_errors",
    "fetch_ranking_html",
    "fetch_stock_name",
    "parse_ranking_table",
]
