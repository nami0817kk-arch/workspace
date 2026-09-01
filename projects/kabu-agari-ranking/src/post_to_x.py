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

import requests
from requests_oauthlib import OAuth1Session

_DATA_DIR = Path(__file__).resolve().parent.parent / "data"
_LATEST_PATH = _DATA_DIR / "latest.json"
_LAST_POST_PATH = _DATA_DIR / "last_tweet.txt"

SITE_URL = "https://kabu-agari-ranking.pages.dev/"
_TWEET_URL = "https://api.x.com/2/tweets"
_TOP_N = 3
_NAME_MAX_LEN = 10


def _truncate(name: str, max_len: int = _NAME_MAX_LEN) -> str:
    return name if len(name) <= max_len else name[:max_len] + "…"


def _build_tweet(payload: dict) -> str:
    lines = [f"📈 {payload['rec_date']} 値上がりランキング"]
    for row in payload["gainers"][:_TOP_N]:
        lines.append(f"{row['rank']}位 {_truncate(row['name'])} +{row['change_pct']:.2f}%")
    lines.append("")
    lines.append("全ランキングはこちら👇")
    lines.append(SITE_URL)
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
