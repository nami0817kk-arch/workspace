"""KDP ペーパーバックの寸法・費用の決まり。

**値はすべて kdp.amazon.co.jp/ja_JP/help/ の公式ヘルプで 2026-09-26 に確認したもの。**
変えるときは出典を読み直すこと。日本語版の実体は kdp.amazon.co.jp 側にあり、
kdp.amazon.com/ja_JP/... は英語版へ転送される。
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Trim:
    width_in: float
    height_in: float


# 判型。本文PDFのページサイズはこれと完全に一致させる（裁ち落としなしの場合）。
# 出典: topic/GVBQ3CMEQW3W2VL6 の「(kdp.amazon.co.jp)」の表。
# 8.5 x 11 in は「(kdp.amazon.com)」の表にしか無いので置かない。
TRIMS: dict[str, Trim] = {
    "a4": Trim(8.27, 11.69),  # 21.0 x 29.7 cm。白黒・白い紙で 24〜780 ページ
    "b5": Trim(7.17, 10.12),  # 18.2 x 25.7 cm。24〜828 ページ
}

MIN_PAGES = 24  # topic/G201857950

# 線の最小の太さ 0.75 pt（topic/G201857950）。解答ページの縮小図もこれを下回らせない。
MIN_LINE_PT = 0.75

# 裁ち落としなしのときの天・地・小口の最小は 0.25 in（topic/GVBQ3CMEQW3W2VL6）。
# 高齢者が手で押さえて書き込むので、最小値よりずっと広く取る。
OUTSIDE_MARGIN_IN = 0.6
TOP_MARGIN_IN = 0.6
BOTTOM_MARGIN_IN = 0.6

# ノドは最小値に加えて少し足す（書き込むときに綴じ側へ手が入りにくいため）。
GUTTER_EXTRA_IN = 0.125

# ページ数ごとの内側（ノド）の最小値 (上限ページ数, インチ)。topic/GVBQ3CMEQW3W2VL6
_INSIDE_MARGIN_TABLE: list[tuple[int, float]] = [
    (150, 0.375),
    (300, 0.5),
    (500, 0.625),
    (700, 0.75),
    (828, 0.875),
]

# 表紙（topic/G201953020）
COVER_BLEED_IN = 0.125
SPINE_PER_PAGE_IN = {"white": 0.002252, "cream": 0.0025}
SPINE_TEXT_MIN_PAGES = 80  # 79 と書かれた箇所もある。厳しい方を取る
SPINE_TEXT_SIDE_MARGIN_IN = 0.0625
COVER_SAFE_IN = 0.25  # 切れては困るものは表紙の外縁からこれ以上内側（topic/G201857950）
BARCODE_BOX_IN = (2.0, 1.2)  # 裏表紙の右下に Amazon が置く白い箱（topic/GGE5T76TWKA85DJM）

# amazon.co.jp の印刷コスト（黒インク・白またはクリーム・大判）。topic/G201834340
# 大判 = 幅 6.12 in 超 または 高さ 9 in 超。A4・B5 はどちらも大判。
# 「24〜110 ページ」と「110〜828 ページ」で 110 が両方に入っていて境目があいまいなので、
# 固定費だけで済ませたいときは 108 ページ以下に収める。
LARGE_FLAT_MAX_PAGES = 108
LARGE_FLAT_COST_JPY = 530
LARGE_FIXED_JPY = 206
LARGE_PER_PAGE_JPY = 3


def inside_margin_in(page_count: int) -> float:
    for max_pages, margin in _INSIDE_MARGIN_TABLE:
        if page_count <= max_pages:
            return margin
    raise ValueError(f"KDP のペーパーバックの上限を超えている: {page_count}ページ")


def print_cost_jpy(page_count: int) -> int:
    """amazon.co.jp の印刷コスト（大判・白黒）。"""
    if page_count <= LARGE_FLAT_MAX_PAGES:
        return LARGE_FLAT_COST_JPY
    return LARGE_FIXED_JPY + LARGE_PER_PAGE_JPY * page_count


def royalty_jpy(list_price_ex_tax: int, page_count: int) -> float:
    """1冊あたりの印税。価格は税抜で入力する（消費税は Amazon が足す）。topic/G201834330

    999円以下は 50%、1,000円以上は 60%。
    """
    rate = 0.6 if list_price_ex_tax >= 1000 else 0.5
    return rate * list_price_ex_tax - print_cost_jpy(page_count)


def spine_width_in(page_count: int, paper: str = "white") -> float:
    return page_count * SPINE_PER_PAGE_IN[paper]
