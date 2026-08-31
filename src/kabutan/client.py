"""kabutan.jp への HTTP アクセス。

注意: kabutan は GitHub Actions のランナー IP を 405 でブロックする（2026-08-31 実測）。
CI から直接叩く設計にはしないこと。取得は手元の回線か自前の実行環境で行う。
"""
from __future__ import annotations

import time

import requests
from bs4 import BeautifulSoup

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "ja,en;q=0.9",
}

_RANKING_URL = "https://kabutan.jp/warning/?mode={mode}&market={market}"

# 取得時に発生した通信エラーの記録。
# 「休場日で0件」と「取得先に拒否されて0件」を呼び出し元が区別するために使う。
# 後者を休場日扱いで握りつぶすと、定期実行が緑のまま更新だけが止まる。
fetch_errors: list[str] = []


def fetch_ranking_html(mode: str, market: int, retries: int = 3) -> str | None:
    """ランキングページの HTML を返す。失敗時は None（fetch_errors に記録）。"""
    url = _RANKING_URL.format(mode=mode, market=market)
    for attempt in range(retries):
        try:
            resp = requests.get(url, headers=HEADERS, timeout=30)
            resp.raise_for_status()
            return resp.text
        except Exception as e:
            if attempt < retries - 1:
                time.sleep(3 * (attempt + 1))
            else:
                print(f"  [WARN] kabutan mode={mode} market={market} 取得失敗: {e}")
                fetch_errors.append(f"mode={mode} market={market}: {e}")
    return None


def fetch_stock_name(code: str) -> str:
    """個別ページから日本語銘柄名を取得する。失敗時はコードをそのまま返す。"""
    try:
        url = f"https://kabutan.jp/stock/?code={code}"
        resp = requests.get(url, headers=HEADERS, timeout=10)
        soup = BeautifulSoup(resp.text, "lxml")
        h1 = soup.find("h1")
        if h1:
            return h1.get_text(strip=True).split("(")[0].strip()
        print(f"  [WARN] {code}: 個別ページに銘柄名が見つかりませんでした")
    except Exception as e:
        # 名前が引けなくてもランキング自体は出せるのでコードで代替する。
        # ただし黙って通すと、名前がコードのまま並んでいる原因が追えなくなる。
        print(f"  [WARN] {code}: 銘柄名の取得に失敗しました: {e}")
    return code
