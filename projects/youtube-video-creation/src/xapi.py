"""X API v2 から投稿を取る。

検索経由（xposts.py）には3つの弱点があった。実測で確認したもの:

  1. 索引が1〜2日遅れる  → 速報に使えない
  2. 本文が途中で切れる  → 「…Barcel...」で終わる引用が使えない
  3. なりすましが混ざる  → 表示名が同じで、ハンドルだけ違う

APIを使うとこの3つが消える。投稿時刻もクラブ側の値が返るので、
IDから逆算する必要がなくなる。

そのかわり有料。料金は変わるので、使う前に必ず docs.x.com/x-api で確認すること。
トークンは環境変数 X_BEARER_TOKEN で渡す。ファイルには書かない。
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import datetime, timezone

import requests

from .xposts import Post

BASE = "https://api.x.com/2"
TOKEN_ENV = "X_BEARER_TOKEN"

# 1リクエストで取れる上限。増やすほど課金対象の読み取りが増える
MAX_RESULTS = 10
TIMEOUT = 20


class XApiError(Exception):
    pass


@dataclass
class Client:
    token: str
    base: str = BASE
    timeout: int = TIMEOUT
    session: requests.Session | None = None

    @classmethod
    def from_env(cls, **kwargs) -> "Client":
        token = os.environ.get(TOKEN_ENV, "").strip()
        if not token:
            raise XApiError(
                f"環境変数 {TOKEN_ENV} が設定されていません。\n"
                "  export X_BEARER_TOKEN='...'\n"
                "トークンは https://developer.x.com のダッシュボードで作ります。"
                "ファイルには書かず、環境変数で渡してください"
            )
        return cls(token=token, **kwargs)

    def _get(self, path: str, params: dict) -> dict:
        client = self.session or requests
        try:
            response = client.get(
                f"{self.base}{path}",
                params=params,
                headers={"Authorization": f"Bearer {self.token}"},
                timeout=self.timeout,
            )
        except requests.RequestException as error:
            raise XApiError(f"X API に接続できません: {error}") from error

        if response.status_code == 401:
            raise XApiError(f"認証に失敗しました。{TOKEN_ENV} の値を確認してください")
        if response.status_code == 403:
            raise XApiError(
                "このエンドポイントは、いまのプランでは使えません。"
                "読み取りができるプランか確認してください（docs.x.com/x-api）"
            )
        if response.status_code == 429:
            raise XApiError(
                "レート制限に達しました。しばらく待つか、"
                "config/sources.yaml の max_results を減らしてください"
            )
        if response.status_code >= 400:
            raise XApiError(f"X API がエラーを返しました（{response.status_code}）: {response.text[:200]}")

        try:
            return response.json()
        except ValueError as error:
            raise XApiError(f"X API の応答を読めません: {error}") from error

    def search_recent(self, query: str, max_results: int = MAX_RESULTS) -> list[Post]:
        """直近7日から検索する。新しい順に返る。"""
        payload = self._get(
            "/tweets/search/recent",
            {
                "query": query,
                "max_results": max(10, min(int(max_results), 100)),  # APIの許容範囲
                "tweet.fields": "created_at,author_id",
                "expansions": "author_id",
                "user.fields": "username,name",
            },
        )
        return to_posts(payload)

    def by_accounts(
        self, handles: list[str], topic: str = "", max_results: int = MAX_RESULTS
    ) -> list[Post]:
        """登録したアカウントに絞って検索する。

        なりすましを引かないための形。from: で著者を限定するので、
        表示名が同じだけの別アカウントは最初から入ってこない。
        """
        names = [h.lstrip("@").strip() for h in handles if h and h.strip()]
        if not names:
            raise XApiError("アカウントが1つも指定されていません")
        who = " OR ".join(f"from:{name}" for name in names)
        query = f"({who}) -is:retweet"
        if topic.strip():
            query = f"{query} {topic.strip()}"
        return self.search_recent(query, max_results)


def to_posts(payload: dict) -> list[Post]:
    """API の応答を Post の並びにする。新しい順。

    検索経由と同じ形にそろえるので、これより先の処理は共通で書ける。
    """
    users = {
        str(user.get("id")): user
        for user in ((payload.get("includes") or {}).get("users") or [])
    }
    posts: list[Post] = []
    for row in payload.get("data") or []:
        user = users.get(str(row.get("author_id")), {})
        handle = str(user.get("username", ""))
        posts.append(
            Post(
                url=f"https://x.com/{handle or 'i'}/status/{row.get('id')}",
                handle=handle,
                author=str(user.get("name", "")),
                text=str(row.get("text", "")).strip(),
                posted_at=_time(row.get("created_at")),
                truncated=False,  # APIは本文を丸ごと返すので切れない
            )
        )
    posts.sort(key=lambda p: p.posted_at or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
    return posts


def _time(value) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
