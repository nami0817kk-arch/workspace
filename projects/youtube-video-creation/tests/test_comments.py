"""最初のコメント（2026-09-08）。問いを置いて、高評価とコメントに誘う。"""
from pathlib import Path

import pytest

from src import comments


def _built(tmp_path, title="サンチョの移籍先、報道がバラバラ", question="どこへ行くのか"):
    body = title + chr(10) + chr(10) + title + chr(10) + chr(10)
    if question:
        body += "この動画が答える問い: " + question + chr(10)
    (tmp_path / "description.txt").write_text(body, encoding="utf-8")
    (tmp_path / "script.json").write_text(
        '{"title": "' + title + '", "scenes": []}', encoding="utf-8")
    return tmp_path


def test_問いがあれば問いから作る(tmp_path):
    text = comments.compose(_built(tmp_path))
    assert "どこへ行くのか" in text
    assert "高評価" in text and "コメント" in text
    assert len(text) <= comments.MAX_LENGTH


def test_問いが無ければタイトルから作る(tmp_path):
    text = comments.compose(_built(tmp_path, question=""))
    assert "サンチョの移籍先" in text
    assert "？" in text


def test_動画が変われば結びが変わる(tmp_path):
    (tmp_path / "a").mkdir()
    a = comments.compose(_built(tmp_path / "a", title="A の話", question="なぜAか"))
    seen = {a.split(" ", 1)[1]}
    for n in range(12):
        d = tmp_path / f"b{n}"
        d.mkdir()
        seen.add(comments.compose(_built(d, title=f"B{n} の話", question=f"なぜB{n}か")).split(" ", 1)[1])
    assert len(seen) >= 3, "結びが毎回同じでは定型になる"


def test_同じ動画には同じ文(tmp_path):
    d = _built(tmp_path)
    assert comments.compose(d) == comments.compose(d)


def test_何も無ければ止まる(tmp_path):
    with pytest.raises(comments.CommentError):
        comments.compose(tmp_path)


def test_具体的な二択にできる(tmp_path):
    """12本に書いて返信ゼロ。「納得なら高評価」が動画ごとに同じだった（2026-09-09）。"""
    text = comments.compose(_built(tmp_path), ("妥当", "忖度"))
    assert "「妥当」なら高評価" in text and "「忖度」ならコメント" in text
    assert len(text) <= comments.MAX_LENGTH
