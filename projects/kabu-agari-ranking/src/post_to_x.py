"""
本日の値上がりランキング上位を X(Twitter) に自動投稿する。

X APIキー（X_API_KEY / X_API_SECRET / X_ACCESS_TOKEN / X_ACCESS_TOKEN_SECRET）が
GitHub Secretsに未設定の場合は、何もせず正常終了する（機能を有効化するまでは無害）。

同じ rec_date への重複投稿を防ぐため、最後に投稿した日付を
data/last_tweet.txt に記録し、次回実行時に比較する。
"""
import json
import os
from pathlib import Path

import sys

import requests
from requests_oauthlib import OAuth1Session

sys.path.insert(0, str(Path(__file__).resolve().parent))

import price_limit
import site_config

_DATA_DIR = Path(__file__).resolve().parent.parent / "data"
_LATEST_PATH = _DATA_DIR / "latest.json"
_LAST_POST_PATH = _DATA_DIR / "last_tweet.txt"

# 公開先は site_config が持つ（ドメインを変えるときはそこだけ触る）
SITE_URL = site_config.SITE_URL
_TWEET_URL = "https://api.x.com/2/tweets"
_TOP_N = 3
_NAME_MAX_LEN = 10


# X の文字数は「素の文字数」ではない。ラテン系の一部だけが1文字、
# 日本語を含むそれ以外は2文字として数え、URL は長さによらず23文字になる。
# （X の weighted length。配分は v3 の既定値）
# ここを素の len() で見ていると、名前が長い日に上限を超えて 403 で弾かれる。
# 投稿の失敗は警告を出すだけでサイトには影響しないので、**気づきにくい**。
_TWEET_LIMIT = 280
_URL_WEIGHT = 23
_LIGHT_RANGES = ((0, 4351), (8192, 8205), (8208, 8223), (8242, 8247))


def weighted_length(text: str) -> int:
    """X が数える長さ。URL は23文字として扱う。"""
    total = 0
    for token in text.split():
        if token.startswith(("http://", "https://")):
            total += _URL_WEIGHT + 1   # 前後の空白ぶん
            continue
        for ch in token:
            o = ord(ch)
            total += 1 if any(lo <= o <= hi for lo, hi in _LIGHT_RANGES) else 2
        total += 1
    return max(total - 1, 0)   # 最後の空白は数えない


def _truncate(name: str, max_len: int = _NAME_MAX_LEN) -> str:
    return name if len(name) <= max_len else name[:max_len] + "…"


def _day_url(rec_date: str) -> str:
    """その日のページ。

    トップを貼ると、翌日には別の日の内容に変わってしまう。投稿は後からも
    読まれるので、投稿した日の中身がそのまま残る URL を貼る。
    """
    return f"{SITE_URL.rstrip('/')}/archive/gainers/{rec_date}"


def _build_tweet(payload: dict) -> str:
    gainers = payload["gainers"]
    lines = [f"📈 {payload['rec_date']} 値上がりランキング"]
    for row in gainers[:_TOP_N]:
        stop = ""
        if price_limit.classify(row.get("close"), row.get("change_pct")) == price_limit.STOP_HIGH:
            stop = "（S高）"
        lines.append(f"{row['rank']}位 {_truncate(row['name'])} +{row['change_pct']:.2f}%{stop}")

    stops = sum(
        1 for r in gainers
        if price_limit.classify(r.get("close"), r.get("change_pct")) == price_limit.STOP_HIGH
    )
    if stops:
        lines.append(f"上位{len(gainers)}銘柄のうちストップ高は{stops}銘柄")

    lines.append("")
    lines.append(_day_url(payload["rec_date"]))
    lines.append("#日本株 #株式投資")
    return "\n".join(lines)


def post_today() -> None:
    api_key = os.environ.get("X_API_KEY", "")
    api_secret = os.environ.get("X_API_SECRET", "")
    access_token = os.environ.get("X_ACCESS_TOKEN", "")
    access_secret = os.environ.get("X_ACCESS_TOKEN_SECRET", "")
    if not all([api_key, api_secret, access_token, access_secret]):
        print("  X APIキーが未設定のため投稿をスキップします")
        return

    if not _LATEST_PATH.exists():
        print("  data/latest.json が無いため投稿をスキップします")
        return

    payload = json.loads(_LATEST_PATH.read_text(encoding="utf-8"))
    rec_date = payload["rec_date"]

    if _LAST_POST_PATH.exists() and _LAST_POST_PATH.read_text(encoding="utf-8").strip() == rec_date:
        print(f"  {rec_date} は投稿済みのためスキップします")
        return

    if not payload.get("gainers"):
        print("  値上がりデータが無いため投稿をスキップします")
        return

    text = _build_tweet(payload)
    session = OAuth1Session(
        api_key, client_secret=api_secret,
        resource_owner_key=access_token, resource_owner_secret=access_secret,
    )
    try:
        resp = session.post(_TWEET_URL, json={"text": text}, timeout=30)
    except requests.RequestException as e:
        print(f"  [WARN] X投稿でエラーが発生しました: {e}")
        return

    if resp.status_code not in (200, 201):
        print(f"  [WARN] X投稿に失敗しました: {resp.status_code} {resp.text}")
        return

    _LAST_POST_PATH.write_text(rec_date, encoding="utf-8")
    print(f"  Xに投稿しました（{rec_date}）")


if __name__ == "__main__":
    post_today()
