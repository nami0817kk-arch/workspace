"""kabutan の HTML 解析。

ここが壊れると、利用側は「エラーも出さずにランキングが空になる」という
一番気づきにくい壊れ方をする。想定している構造は tests/kabutan/ で固定してある。
"""
from __future__ import annotations

import io
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


# 「いま制限値幅の上限（下限）に張り付いている」ことを示す印。
# 株価の隣のセルに単独で S が入る。市場の列は「東Ｓ」のように全角なので、
# 半角1文字と完全一致させれば取り違えない。
# 銘柄コード。2024年から英文字を含むもの（例: 627A）が割り当てられている。
# 「4桁の数字」に限っていた間、新しい形式の銘柄を1件も保存できていなかった
# （2026-09-25 に発覚。保存済み1,260行中0件で、その日の値上がり上位にも載っていた）。
_CODE_RE = re.compile(r"^[0-9][0-9A-Z]{3}$")

_AT_LIMIT_MARK = "S"
# 印を探す範囲。銘柄名やPERの側まで見ると誤検出が増える。
_AT_LIMIT_SCAN = 8


def _at_limit(texts: list[str]) -> bool:
    return any(t == _AT_LIMIT_MARK for t in texts[:_AT_LIMIT_SCAN])


def parse_ranking_table(html: str) -> pd.DataFrame:
    """stock_table を中立な列名の DataFrame にする。

    列の意味はランキング種別で共通:
      13列 (プライム): code[0] name[1] market[2] _ _ close[5] _ 前日比[7] change%[8] metric[9]
      12列 (スタンダード/グロース): code[0] market[1] _ _ close[4] _ 前日比[6] change%[7] metric[8]

    metric 列は値上がり/値下がりランキングでは出来高、活況ランキングでは約定回数。
    12列版には銘柄名が無いので、いったんコードで埋める（利用側で補完する）。

    ``at_limit`` は「その時点で制限値幅の上限（下限）に張り付いているか」。
    ストップ高／安のランキング（mode 3_1 / 3_2）では、大引け後に取れば
    「引けでストップ高だったか」がそのまま分かる。値上がりランキングにも
    同じ印が出るので、推定ではなく事実として使える。

    なお 3_1 / 3_2 では ``metric_value``（出来高）の位置がニュース欄に
    置き換わっているため None になる。

    Returns:
        columns: ticker, code, name, close, change_pct, metric_value, at_limit
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
            if not _CODE_RE.match(code):
                continue

            # 銘柄名は行の見出しセル（th）にある。ここを読まずに個別ページへ
            # 取りに行くと、1銘柄につき1リクエスト余計に叩くことになる。
            heading = tr.find("th")
            heading_name = heading.get_text(strip=True) if heading else ""

            if n >= 13:
                name = texts[1]
                close = texts[5].replace(",", "")
                change_s = texts[8]
                metric_s = texts[9].replace(",", "")
            else:
                # 見出しセルに名前があればそれを使う（無い版のページもある）
                name = heading_name or code
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
                "at_limit": _at_limit(texts),
            })
        except (IndexError, ValueError):
            continue

    return pd.DataFrame(rows) if rows else pd.DataFrame()


def parse_daily_prices(html: str) -> pd.DataFrame:
    """個別銘柄の「日々株価（日足）」ページを DataFrame にする。

    ランキングは当日分しか出ないので、**過去の相場日を確かめられる唯一の窓口**が
    この表になる（終値と前日比が日付つきで並んでいる）。
    保存済みデータの日付が疑わしいとき、同じ数字がある日を探して照合する。

    Returns:
        columns: date（YYYY-MM-DD）, close, change_pct
        表が無ければ空の DataFrame。
    """
    try:
        # flavor を指定しないと、表が無いときに html5lib を探しに行って
        # ImportError になる（依存を増やさないため lxml に固定する）。
        tables = pd.read_html(io.StringIO(html), flavor="lxml")
    except ValueError:
        return pd.DataFrame()

    for table in tables:
        columns = [str(c) for c in table.columns]
        if not any("日付" in c for c in columns):
            continue
        out = pd.DataFrame({
            # ページは「26/09/18」の2桁年。西暦に直す。
            "date": "20" + table["日付"].astype(str).str.replace("/", "-", regex=False),
            "close": pd.to_numeric(table["終値"], errors="coerce"),
            "change_pct": pd.to_numeric(table["前日比％"], errors="coerce"),
        })
        return out.dropna(subset=["close"]).reset_index(drop=True)
    return pd.DataFrame()
