"""ニュース取得の例外経路が黙らないことのテスト。

news.py の取得系は「1ソースの失敗で全体を落とさない」ために例外を握って
`continue` している。継続そのものは意図した仕様だが、握りつぶしたままだと
「なぜこのソースの記事が0件なのか」を後から追えない。
継続しつつ WARN が出ることを、ここで固定する。
"""

import pytest

from src.report import news


def test_yahoo_fetch_failure_warns_and_continues(monkeypatch, capsys):
    """1ソースが落ちても例外を投げず、WARN にソース名が出る。"""

    def boom(*args, **kwargs):
        raise RuntimeError("接続できません")

    monkeypatch.setattr(news.requests, "get", boom)

    assert news.fetch_yahoo_finance_news() == []

    out = capsys.readouterr().out
    assert "[WARN]" in out
    assert "接続できません" in out, "原因が追えるよう例外の内容を残すこと"


def test_youtube_fetch_failure_warns_per_channel(monkeypatch, capsys):
    """チャンネル単位で落ちても続行し、どのチャンネルかが WARN に出る。"""

    def boom(*args, **kwargs):
        raise RuntimeError("フィードが壊れています")

    monkeypatch.setattr(news.feedparser, "parse", boom)

    assert news.fetch_youtube_with_transcripts() == []

    out = capsys.readouterr().out
    # 1チャンネルで止まらず、全チャンネル分を試していること
    assert out.count("[WARN]") == len(news.YOUTUBE_CHANNELS)
    for channel_id in news.YOUTUBE_CHANNELS:
        assert channel_id in out
