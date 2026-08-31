"""
値上がり率ランキングを取得する。

ソース:
  kabudragon (デフォルト・過去日付対応):
    https://www.kabudragon.com/ranking/age.html
    https://www.kabudragon.com/ranking/YYYY/MM/DD/age.html

  kabutan (当日リアルタイム):
    https://kabutan.jp/warning/?mode=2_1&market={1,2,3}
"""
import re
import time
import requests
import pandas as pd
from bs4 import BeautifulSoup
from datetime import date

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "ja,en;q=0.9",
}

# ── kabudragon ──────────────────────────────────────────────
_KDRAGON_BASE  = "https://www.kabudragon.com/ranking/age.html"
_KDRAGON_DATED = "https://www.kabudragon.com/ranking/{yyyy}/{mm}/{dd}/age.html"


def _kdragon_fetch(date_str: str | None = None, retries: int = 3) -> str | None:
    if date_str:
        yyyy, mm, dd = date_str.split("-")
        url = _KDRAGON_DATED.format(yyyy=yyyy, mm=mm, dd=dd)
    else:
        url = _KDRAGON_BASE

    for attempt in range(retries):
        try:
            resp = requests.get(url, headers=_HEADERS, timeout=30)
            resp.raise_for_status()
            return resp.text
        except Exception as e:
            if attempt < retries - 1:
                time.sleep(3 * (attempt + 1))
            else:
                print(f"  [WARN] kabudragon 取得失敗: {e}")
    return None


def _kdragon_parse(html: str) -> pd.DataFrame:
    soup = BeautifulSoup(html, "lxml")
    tables = soup.find_all("table")
    if len(tables) < 2:
        return pd.DataFrame()

    rows = []
    for tr in tables[1].find_all("tr"):
        tds = tr.find_all("td")
        if len(tds) < 8:
            continue
        texts = [td.get_text(strip=True) for td in tds]

        rank_idx = None
        for i, t in enumerate(texts):
            if re.match(r"^\d{1,3}$", t) and i + 1 < len(texts):
                if re.match(r"^[0-9]{4}[0-9A-Z]?$", texts[i + 1]):
                    rank_idx = i
                    break
        if rank_idx is None:
            continue

        try:
            code  = texts[rank_idx + 1]
            name  = texts[rank_idx + 2]
            close = texts[rank_idx + 5].replace(",", "")
            gain_s = texts[rank_idx + 7]
            vol_s  = texts[rank_idx + 8].replace(",", "")

            gain = float(re.sub(r"[^0-9.\-]", "", gain_s))
            if gain <= 0:
                continue

            rows.append({
                "ticker":    code + ".T",
                "name":      name,
                "終値":      float(close) if close.replace(".", "").isdigit() else None,
                "値上がり率%": gain,
                "出来高":    int(vol_s) if vol_s.isdigit() else None,
            })
        except (IndexError, ValueError):
            continue

    if not rows:
        return pd.DataFrame()

    return (
        pd.DataFrame(rows)
        .drop_duplicates("ticker")
        .sort_values("値上がり率%", ascending=False)
        .reset_index(drop=True)
    )


def _kdragon_page_date(html: str) -> str | None:
    m = re.search(r"(\d{4})/(\d{2})/(\d{2})", html)
    return f"{m.group(1)}-{m.group(2)}-{m.group(3)}" if m else None


# ── kabutan ─────────────────────────────────────────────────
# HTML の取得・解析は ai-lab の共有パッケージ `kabutan` に一本化してある
# （kabu-agari-ranking と共通）。構造の変化は ai-lab 側で直す。
from kabutan import MARKETS as _KABUTAN_MARKETS  # noqa: E402
from kabutan import MODE_GAINERS as _MODE_GAINERS  # noqa: E402
from kabutan import fetch_ranking_html as _lib_fetch_ranking_html  # noqa: E402
from kabutan import fetch_stock_name as _lib_fetch_stock_name  # noqa: E402
from kabutan import parse_ranking_table as _lib_parse_ranking_table  # noqa: E402


def _kabutan_fetch_market(market: int, retries: int = 3) -> str | None:
    return _lib_fetch_ranking_html(_MODE_GAINERS, market, retries=retries)


def _kabutan_parse(html: str) -> pd.DataFrame:
    """共有パッケージの中立な列名を、このプロジェクトの列名に変換し、上昇銘柄だけ残す。"""
    df = _lib_parse_ranking_table(html)
    if df.empty:
        return df
    df = df[df["change_pct"] > 0]
    if df.empty:
        return pd.DataFrame()
    return pd.DataFrame({
        "ticker":      df["ticker"],
        "name":        df["name"],
        "終値":        df["close"],
        "値上がり率%": df["change_pct"],
        "出来高":      df["metric_value"],
    }).reset_index(drop=True)


def _fetch_name_kabutan(code: str) -> str:
    """kabutan の個別ページから日本語銘柄名を取得する（共有パッケージへ委譲）。"""
    return _lib_fetch_stock_name(code)


def _fill_names_kabutan(df: pd.DataFrame) -> pd.DataFrame:
    """銘柄名がコード（数字4桁）になっている行を kabutan 個別ページで補完する。"""
    needs_name = df["name"].str.match(r"^\d{4}$")
    for idx, row in df[needs_name].iterrows():
        code = row["ticker"].replace(".T", "")
        name = _fetch_name_kabutan(code)
        df.at[idx, "name"] = name
        time.sleep(0.5)
    return df


def _fetch_kabutan(top_n: int = 50) -> pd.DataFrame:
    """kabutan.jp 3市場を集約して上位 top_n を返す。記録日=今日。"""
    all_rows = []
    for market in _KABUTAN_MARKETS:
        html = _kabutan_fetch_market(market)
        if html:
            df_m = _kabutan_parse(html)
            if not df_m.empty:
                all_rows.append(df_m)
        time.sleep(1)

    if not all_rows:
        return pd.DataFrame()

    df = (
        pd.concat(all_rows, ignore_index=True)
        .drop_duplicates("ticker")
        .sort_values("値上がり率%", ascending=False)
        .head(top_n)
        .reset_index(drop=True)
    )

    # スタンダード/グロース銘柄の名前を kabutan 個別ページで補完
    df = _fill_names_kabutan(df)

    df["記録日"] = str(date.today())
    return df


# ── 公開 API ────────────────────────────────────────────────

def fetch_jp_gainers(
    top_n: int = 50,
    date_str: str | None = None,
    source: str = "kabudragon",
) -> pd.DataFrame:
    """
    値上がり率ランキングを取得する。

    Args:
        top_n:    取得件数上限
        date_str: 取得日付 'YYYY-MM-DD'（kabudragon のみ有効）
        source:   "kabudragon" | "kabutan"

    Returns:
        DataFrame: ticker, name, 終値, 値上がり率%, 出来高, 記録日
    """
    if source == "kabutan":
        print("  値上がりランキング取得中（kabutan.jp）...")
        return _fetch_kabutan(top_n)

    # kabudragon
    html = _kdragon_fetch(date_str)
    if html is None:
        return pd.DataFrame()

    df = _kdragon_parse(html)
    if df.empty:
        return df

    df["記録日"] = _kdragon_page_date(html)
    return df.head(top_n)
