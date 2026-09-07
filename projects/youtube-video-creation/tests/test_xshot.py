"""X の投稿を画像にする（2026-09-08 ユーザーが有名人の投稿を許可）。

**誰でもよいわけではない。**accounts: に載っている人だけ。
"""

import pytest

from src.xshot import ShotError, allowed, parse

ACCOUNTS = [
    {"handle": "FabrizioRomano", "name": "Fabrizio Romano", "tier": "確定"},
    {"handle": "DiMarzio", "name": "Gianluca Di Marzio", "tier": "未確認"},
]


def test_投稿URLから誰の何番かを取る():
    assert parse("https://x.com/FabrizioRomano/status/123") == ("FabrizioRomano", "123")
    assert parse("https://twitter.com/DiMarzio/status/9") == ("DiMarzio", "9")


def test_投稿URLでなければ止める():
    for bad in ("https://x.com/FabrizioRomano", "https://example.com/a", ""):
        with pytest.raises(ShotError):
            parse(bad)


def test_載っている人だけ通す():
    assert allowed("FabrizioRomano", ACCOUNTS)["name"] == "Fabrizio Romano"
    assert allowed("@dimarzio", ACCOUNTS) is not None      # @ と大文字小文字は無視
    assert allowed("random_person", ACCOUNTS) is None


def test_載っていない人は撮らない(tmp_path):
    from src.xshot import capture

    with pytest.raises(ShotError) as caught:
        capture("https://x.com/random_person/status/1", tmp_path, ACCOUNTS)
    assert "accounts:" in str(caught.value)
