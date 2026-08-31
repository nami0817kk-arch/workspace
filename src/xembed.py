"""X の投稿本文を、公式の埋め込み用エンドポイントから取る。

検索経由（xposts.py）には3つの弱点があった。実測で確認したもの:

  1. 索引が1〜2日遅れる  → 速報に使えない
  2. 本文が途中で切れる  → 「…Barcel...」で終わる引用が使えない
  3. なりすましが混ざる  → 表示名が同じで、ハンドルだけ違う

publish.twitter.com/oembed は**認証なしで**このうち 2 と 3 を消す。
全文が返り、正のハンドルが `author_url` で返ってくるので、表示名で
見分ける必要がなくなる。

**1 は消えない。** これは投稿URLを既に持っている前提のしくみで、
「見つける」ことはできない。発見は検索か、有料の xapi.py のまま。

投稿時刻はここでは使わない。IDから逆算するほうが正確で、通信も要らない
（xposts.posted_at）。

X 公式の埋め込み用エンドポイントだが、レート制限は公開されていない。
1投稿につき1回にとどめ、一度取ったものは控えを使い回すこと。
"""

from __future__ import annotations

import html as html_mod
import re

import requests

from .xposts import TRUNCATED, Post, parse_url, posted_at

ENDPOINT = "https://publish.twitter.com/oembed"
TIMEOUT = 20

# 返ってくるのは埋め込み用の HTML。本文は最初の <p> に入っている。
#   <blockquote ...><p ...>本文</p>&mdash; 名前 (@handle) <a>日付</a></blockquote>
BODY = re.compile(r"<p[^>]*>(.*?)</p>", re.DOTALL)
BREAK = re.compile(r"<br\s*/?>", re.IGNORECASE)
TAG = re.compile(r"<[^>]+>")


class XEmbedError(Exception):
    pass


def body_of(embed_html: str) -> str:
    """埋め込みHTMLから本文だけを取り出す。

    リンクは表示されているテキストのまま残す。t.co の生URLに戻すと、
    投稿に書いてある文字列と違うものを引用することになる。
    """
    match = BODY.search(embed_html or "")
    if not match:
        return ""            # 画像だけの投稿など、本文が無いもの
    text = BREAK.sub("\n", match.group(1))
    text = TAG.sub("", text)
    return html_mod.unescape(text).strip()


def handle_of(author_url: str) -> str:
    """author_url から正のハンドルを取る。表示名では判定しない。"""
    return (author_url or "").rstrip("/").rsplit("/", 1)[-1]


def fetch(url: str, session=None, timeout: int = TIMEOUT) -> Post:
    """投稿URLから、本文の入った Post を作る。"""
    asked, _ = parse_url(url)          # URLとして読めなければここで落ちる

    client = session or requests
    try:
        response = client.get(
            ENDPOINT,
            params={"url": url, "omit_script": 1, "dnt": "true"},
            headers={"User-Agent": "youtube-video-creation (news script builder)"},
            timeout=timeout,
        )
    except requests.RequestException as error:
        raise XEmbedError(f"X に接続できません: {error}") from error

    if response.status_code == 404:
        raise XEmbedError(
            f"投稿が見つかりません（消されたか、非公開のアカウント）: {url}"
        )
    if response.status_code == 403:
        raise XEmbedError(f"この投稿は埋め込みが許可されていません: {url}")
    if response.status_code == 429:
        raise XEmbedError(
            "X に立て続けに聞きすぎました。しばらく待ってください。"
            "一度取った本文は控えを使い回します"
        )
    if response.status_code >= 400:
        raise XEmbedError(f"X がエラーを返しました（{response.status_code}）: {url}")

    try:
        payload = response.json()
    except ValueError as error:
        raise XEmbedError(f"X の応答を読めません: {error}") from error

    text = body_of(str(payload.get("html", "")))
    handle = handle_of(str(payload.get("author_url", ""))) or asked

    return Post(
        url=url,
        handle=handle,
        author=str(payload.get("author_name", "")),
        text=text,
        posted_at=posted_at(url),
        # oEmbed は全文を返すが、返さなくなったときに黙って引かないよう見張る
        truncated=bool(text) and text.endswith(TRUNCATED),
    )


def impersonation(url: str, post: Post) -> str:
    """URLのハンドルと、X が返した正のハンドルが食い違っていないか。"""
    asked, _ = parse_url(url)
    if post.handle and asked.lower() != post.handle.lower():
        return (
            f"URLは @{asked} ですが、X が返したのは @{post.handle} です。"
            "なりすましか、改名された可能性があります"
        )
    return ""
