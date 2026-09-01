"""切り出したハンドラのうち、大きい3つ（fetch / x / pick）。

いずれも通信か研究ファイルが要るため、長らく直接のテストが無かった。
関数に切り出したことで、外に出る所だけ差し替えれば呼べるようになった。
"""

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from src import cli
from src.feeds import FeedError, Item
from src.xembed import XEmbedError
from src.xposts import Post


def _args(**kw):
    return SimpleNamespace(**kw)


def _item(title, hours_ago=1.0):
    when = datetime.now(timezone.utc) - timedelta(hours=hours_ago)
    return Item(title=title, url="https://example.com/a", published=when)


# ---------------------------------------------------------------- fetch

def test_fetch_discover_はページが宣言しているフィードを並べる(monkeypatch, capsys):
    from src import feeds

    monkeypatch.setattr(feeds, "discover",
                        lambda url: [("Sky Sports Football", "https://sky/rss/11661")])
    args = _args(discover="https://sky/football", url=None, league=None,
                 check=False, hours=24)
    assert cli._cmd_fetch(args, None) == 0
    out = capsys.readouterr().out
    assert "Sky Sports Football" in out
    assert "https://sky/rss/11661" in out
    # 当て推量をさせないため、次に打つコマンドまで出す
    assert "fetch --url" in out


def test_fetch_discover_は宣言が無ければ1を返す(monkeypatch, capsys):
    from src import feeds

    monkeypatch.setattr(feeds, "discover", lambda url: [])
    args = _args(discover="https://sky/football", url=None, league=None,
                 check=False, hours=24)
    assert cli._cmd_fetch(args, None) == 1
    assert "宣言していません" in capsys.readouterr().err


def test_fetch_url_は設定に足す前に中身を見せる(monkeypatch, capsys):
    from src import feeds

    monkeypatch.setattr(feeds, "fetch", lambda url: [_item("Arsenal sign X"), _item("Spurs")])
    args = _args(discover=None, url="https://sky/rss/11661", league=None,
                 check=False, hours=24)
    assert cli._cmd_fetch(args, None) == 0
    out = capsys.readouterr().out
    assert "Arsenal sign X" in out
    assert "2件" in out


def test_fetch_url_は取れなければ1を返す(monkeypatch, capsys):
    from src import feeds

    def boom(url):
        raise FeedError("HTTP 404")

    monkeypatch.setattr(feeds, "fetch", boom)
    args = _args(discover=None, url="https://sky/rss/9999", league=None,
                 check=False, hours=24)
    assert cli._cmd_fetch(args, None) == 1
    assert "取得できません" in capsys.readouterr().err


def test_fetch_url_は0件でも成功にしない(monkeypatch, capsys):
    """生きているが空、は「使えるフィード」ではない。"""
    from src import feeds

    monkeypatch.setattr(feeds, "fetch", lambda url: [])
    args = _args(discover=None, url="https://sky/rss/0", league=None,
                 check=False, hours=24)
    assert cli._cmd_fetch(args, None) == 1
    assert "項目が1つもありません" in capsys.readouterr().err


# ---------------------------------------------------------------- x

URL = "https://x.com/FabrizioRomano/status/2092546263447146991"


def test_x_は投稿の本文を全文出す(monkeypatch, capsys):
    from src import xembed

    monkeypatch.setattr(xembed, "fetch", lambda url: Post(
        url=url, handle="FabrizioRomano", author="Fabrizio Romano",
        text="Balde has informed Barcelona\nabout his desire to STAY",
    ))
    args = _args(urls=[URL], calls=False, note=None, topic=None, no_body=False)
    assert cli._cmd_x(args, None) == 0
    out = capsys.readouterr().out
    assert "| Balde has informed Barcelona" in out
    assert "| about his desire to STAY" in out


def test_x_はなりすましを警告する(monkeypatch, capsys):
    from src import xembed

    monkeypatch.setattr(xembed, "fetch", lambda url: Post(
        url=url, handle="FabrizioRomanoo", author="Fabrizio Romano", text="here we go",
    ))
    args = _args(urls=[URL], calls=False, note=None, topic=None, no_body=False)
    assert cli._cmd_x(args, None) == 0
    assert "なりすまし" in capsys.readouterr().out


def test_x_は本文が取れなくても止まらない(monkeypatch, capsys):
    """時刻と鮮度は本文なしでも分かる。そこまでは出す。"""
    from src import xembed

    def boom(url):
        raise XEmbedError("投稿が見つかりません（消されたか、非公開のアカウント）")

    monkeypatch.setattr(xembed, "fetch", boom)
    args = _args(urls=[URL], calls=False, note=None, topic=None, no_body=False)
    assert cli._cmd_x(args, None) == 0
    out = capsys.readouterr().out
    assert "本文を取れませんでした" in out
    assert "@FabrizioRomano" in out


def test_x_は_no_body_なら通信しない(monkeypatch, capsys):
    from src import xembed

    def fail(url):
        raise AssertionError("--no-body なのに取りに行った")

    monkeypatch.setattr(xembed, "fetch", fail)
    args = _args(urls=[URL], calls=False, note=None, topic=None, no_body=True)
    assert cli._cmd_x(args, None) == 0
    assert "投稿:" in capsys.readouterr().out


def test_x_は投稿URLでないものを弾く(capsys):
    args = _args(urls=["https://example.com/a"], calls=False, note=None,
                 topic=None, no_body=True)
    assert cli._cmd_x(args, None) == 0
    assert "投稿URLとして読めません" in capsys.readouterr().out


# ---------------------------------------------------------------- pick

CANDIDATES = """date: "2026年9月1日"
candidates:
  - id: alvarez_arsenal
    title: アルバレスのアーセナル移籍
    en: Julian Alvarez Arsenal
    league: england
    topic: alvarez
    kind: transfer
    hours_ago: 2
    tier: 報道
    sources:
      - https://www.skysports.com/football/news/1/2/alvarez
"""


def test_pick_は候補を採点して並べる(tmp_path, capsys):
    path = tmp_path / "20260901_candidates.yaml"
    path.write_text(CANDIDATES, encoding="utf-8")
    assert cli._cmd_pick(_args(candidates=str(path)), None) == 0
    out = capsys.readouterr().out
    assert "候補の採点" in out
    assert "アルバレスのアーセナル移籍" in out


def test_pick_は確度が情報源の上限を超えていたら進ませない(tmp_path, capsys):
    """噂まとめだけを根拠に『確定』と出すのが、いちばん起きやすい間違い。"""
    path = tmp_path / "20260901_candidates.yaml"
    path.write_text(
        CANDIDATES.replace("tier: 報道", "tier: 確定")
                  .replace("https://www.skysports.com/football/news/1/2/alvarez",
                           "https://caughtoffside.com/alvarez"),
        encoding="utf-8",
    )
    assert cli._cmd_pick(_args(candidates=str(path)), None) == 1
    assert "直すところがあります" in capsys.readouterr().out
