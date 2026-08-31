"""X の投稿本文を、認証なしで取れているか。

検索経由だと本文が「…Barcel...」で切れ、表示名ではなりすましを見分けられない。
oEmbed はこの2つを消す。消せているかを確かめる。
"""

from dataclasses import dataclass, field

import pytest
import requests

from src import xembed
from src.xembed import XEmbedError

HTML = (
    '<blockquote class="twitter-tweet"><p lang="en" dir="ltr">'
    '\U0001f6a8\U0001f535\U0001f534 Understand Alejandro Balde has informed '
    '&quot;Barcelona&quot; about his desire to STAY.<br><br>'
    'Decision up to the club after exploring sale '
    '<a href="https://t.co/abc">pic.twitter.com/abc</a>'
    '</p>&mdash; Fabrizio Romano (@FabrizioRomano) '
    '<a href="https://x.com/FabrizioRomano/status/2092546263447146991">August 26, 2026</a>'
    "</blockquote>"
)

PAYLOAD = {
    "html": HTML,
    "author_name": "Fabrizio Romano",
    "author_url": "https://x.com/FabrizioRomano",
}

URL = "https://x.com/FabrizioRomano/status/2092546263447146991"


@dataclass
class FakeResponse:
    status_code: int = 200
    payload: dict | None = None
    text: str = ""

    def json(self):
        if self.payload is None:
            raise ValueError("no json")
        return self.payload


@dataclass
class FakeSession:
    """通信せずに試すための差し替え。"""

    response: FakeResponse = field(default_factory=lambda: FakeResponse(payload=PAYLOAD))
    error: Exception | None = None
    calls: list = field(default_factory=list)

    def get(self, url, params=None, headers=None, timeout=None):
        self.calls.append({"url": url, "params": params})
        if self.error:
            raise self.error
        return self.response


def test_本文を全文で返す():
    post = xembed.fetch(URL, session=FakeSession())
    assert post.text.startswith("\U0001f6a8\U0001f535\U0001f534 Understand Alejandro Balde")
    assert post.text.endswith("pic.twitter.com/abc")
    assert not post.truncated


def test_改行を残しリンクは表示されているテキストのまま置く():
    post = xembed.fetch(URL, session=FakeSession())
    # t.co の生URLに戻すと、投稿に書いてある文字列と違うものを引用してしまう
    assert "https://t.co/abc" not in post.text
    assert "pic.twitter.com/abc" in post.text
    assert "\n\nDecision up to the club" in post.text


def test_HTMLの実体参照を戻す():
    post = xembed.fetch(URL, session=FakeSession())
    assert '"Barcelona"' in post.text
    assert "&quot;" not in post.text


def test_正のハンドルは表示名ではなくauthor_urlから取る():
    post = xembed.fetch(URL, session=FakeSession())
    assert post.handle == "FabrizioRomano"
    assert post.author == "Fabrizio Romano"


def test_なりすましはハンドルの食い違いで分かる():
    fake = FakeSession(response=FakeResponse(payload={
        "html": HTML,
        "author_name": "Fabrizio Romano",      # 表示名は同じ
        "author_url": "https://x.com/FabrizioRomanoo",   # ハンドルだけ違う
    }))
    post = xembed.fetch(URL, session=fake)
    assert "なりすまし" in xembed.impersonation(URL, post)


def test_同じハンドルなら何も言わない():
    post = xembed.fetch(URL, session=FakeSession())
    assert xembed.impersonation(URL, post) == ""


def test_投稿時刻はIDから出す():
    """通信で返ってくる日付は日付までしか無い。IDなら分単位で分かる。"""
    post = xembed.fetch(URL, session=FakeSession())
    assert post.posted_at is not None
    assert post.posted_at.year == 2026


def test_画像だけの投稿は本文が空になる():
    fake = FakeSession(response=FakeResponse(payload={
        "html": '<blockquote class="twitter-tweet">&mdash; X (@X) </blockquote>',
        "author_url": "https://x.com/FabrizioRomano",
    }))
    assert xembed.fetch(URL, session=fake).text == ""


def test_切れた本文は引用に使わないよう印をつける():
    """oEmbed は全文を返すはずだが、返さなくなったときに黙って引かないため。"""
    fake = FakeSession(response=FakeResponse(payload={
        "html": '<blockquote><p>Arsenal remain attentive to Julián Álv…</p></blockquote>',
        "author_url": "https://x.com/FabrizioRomano",
    }))
    assert xembed.fetch(URL, session=fake).truncated


def test_消された投稿は404で分かる():
    fake = FakeSession(response=FakeResponse(status_code=404))
    with pytest.raises(XEmbedError, match="見つかりません"):
        xembed.fetch(URL, session=fake)


def test_立て続けに聞きすぎたら待つよう言う():
    fake = FakeSession(response=FakeResponse(status_code=429))
    with pytest.raises(XEmbedError, match="しばらく待って"):
        xembed.fetch(URL, session=fake)


def test_つながらないときは理由を言う():
    fake = FakeSession(error=requests.ConnectionError("切断"))
    with pytest.raises(XEmbedError, match="接続できません"):
        xembed.fetch(URL, session=fake)


def test_Xの投稿URLでなければ通信する前に落とす():
    fake = FakeSession()
    with pytest.raises(Exception):
        xembed.fetch("https://example.com/a", session=fake)
    assert fake.calls == []
