"""kabutan の HTML 解析。

ここが壊れると、利用側は「エラーも出さずにランキングが空になる」という
一番気づきにくい壊れ方をする。想定している構造は tests/kabutan/ で固定してある。
"""
from __future__ import annotations

import re

import pandas as pd
from bs4 import BeautifulSoup

_ASOF_DATE_RE = re.compile(r'<time datetime="(\d{4}-\d{2}-\d{2})">終値</time>')

# ランキング表そのものが持つ日付（「2026年09月07日 / 16:00現在」の並び）。
_PAGE_DATE_RE = re.compile(r"meigara_count.{0,300}?(\d{4})年(\d{1,2})月(\d{1,2})日", re.S)


def extract_asof_date(html: str) -> str | None:
    """ページ内の日付から、実際にどの営業日の終値かを取得する。

    kabutan は休場日にアクセスしても直近営業日のデータをそのまま表示するため、
    取得日をそのままラベルにすると休日実行時に日付がずれる。

    **最初の ``<time>`` を採ってはいけない。** ページ冒頭の指数ヘッダは
    NYダウ → 国内指数の順に並んでおり、先頭は米国市場の終値日になる。
    日本時間の夕方はまだ前営業日を指しているため、国内ランキングを
    1営業日古い日付で保存してしまう（2026-09-07 に実際に発生し、
    月曜のデータが金曜のファイルを上書きした）。

    そこでランキング表自身が持つ日付を最優先で読む。取れないときだけ
    ``<time>`` に落とすが、そのときも**最も新しい日付**を採る。
    """
    m = _PAGE_DATE_RE.search(html)
    if m:
        year, month, day = m.groups()
        return f"{year}-{int(month):02d}-{int(day):02d}"

    dates = _ASOF_DATE_RE.findall(html)
    return max(dates) if dates else None


def parse_ranking_table(html: str) -> pd.DataFrame:
    """stock_table を中立な列名の DataFrame にする。

    列の意味はランキング種別で共通:
      13列 (プライム): code[0] name[1] market[2] _ _ close[5] _ 前日比[7] change%[8] metric[9]
      12列 (スタンダード/グロース): code[0] market[1] _ _ close[4] _ 前日比[6] change%[7] metric[8]

    metric 列は値上がり/値下がりランキングでは出来高、活況ランキングでは約定回数。
    12列版には銘柄名が無いので、いったんコードで埋める（利用側で補完する）。

    Returns:
        columns: ticker, code, name, close, change_pct, metric_value
        テーブルが無い・行が壊れている場合は該当行を飛ばし、最悪でも空の DataFrame。
    """
    soup = BeautifulSoup(html, "lxml")
    tbl = soup.find("table", class_="stock_table")
    if tbl is None:
        return pd.DataFrame()

    rows = []
    for tr in tbl.find_all("tr"):
        tds = tr.find_all("td")
        n = len(tds)
        if n < 9:
            continue
        texts = [td.get_text(strip=True) for td in tds]

        try:
            code = texts[0]
            if not re.match(r"^\d{4}$", code):
                continue

            if n >= 13:
                name = texts[1]
                close = texts[5].replace(",", "")
                change_s = texts[8]
                metric_s = texts[9].replace(",", "")
            else:
                name = code
                close = texts[4].replace(",", "")
                change_s = texts[7]
                metric_s = texts[8].replace(",", "")

            change_pct = float(re.sub(r"[^0-9.\-]", "", change_s))

            rows.append({
                "ticker": code + ".T",
                "code": code,
                "name": name,
                "close": float(close) if close.replace(".", "").isdigit() else None,
                "change_pct": change_pct,
                "metric_value": int(metric_s) if metric_s.isdigit() else None,
            })
        except (IndexError, ValueError):
            continue

    return pd.DataFrame(rows) if rows else pd.DataFrame()
