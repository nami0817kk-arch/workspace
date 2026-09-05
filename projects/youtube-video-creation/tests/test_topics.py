"""まとめ集約サイト（FOOTBALL TOPIC）の読み取り。"""

from datetime import datetime

SAMPLE = """
<ul class="postList">
<li><h2 class="postTitle"><img src="x" alt="">&nbsp;<a href="https://a.example/1.html" onclick="c(1);" target="_blank">◆悲報◆セルタ戦の久保建英、宇宙開発</a></h2>
<p class="postInfo">WorldFootballNews&nbsp;on&nbsp;2026.09.05/06:00　<span class="tweet">50&nbsp;Points</span></p></li>
<li><h2 class="postTitle"><img src="x" alt="">&nbsp;<a href="https://b.example/2.html" onclick="c(2);" target="_blank">◆速報◆中村敬斗リヨン移籍</a></h2>
<p class="postInfo">footballnet&nbsp;on&nbsp;2026.09.05/09:00　<span class="tweet">120&nbsp;Points</span></p></li>
<li><h2 class="postTitle"><img src="x" alt="">&nbsp;<a href="https://c.example/3.html" onclick="c(3);" target="_blank">古い記事</a></h2>
<p class="postInfo">サカサカ10&nbsp;on&nbsp;2026.09.01/12:00　<span class="tweet">999&nbsp;Points</span></p></li>
</ul>
"""

NOW = datetime(2026, 9, 5, 18, 0)


def test_見出しとURLと日時とPointsを読む():
    from src.topics import parse

    rows = parse(SAMPLE)

    assert [r.url for r in rows] == ["https://a.example/1.html", "https://b.example/2.html",
                                     "https://c.example/3.html"]
    assert rows[0].title == "◆悲報◆セルタ戦の久保建英、宇宙開発"
    assert rows[0].points == 50
    assert rows[0].posted == datetime(2026, 9, 5, 6, 0)
    assert rows[0].site == "WorldFootballNews"


def test_省略可能な組で_Points_が0にならない():
    """1つの正規表現に省略可能な組を混ぜると、遅延一致が空で通していた。"""
    from src.topics import parse

    assert all(r.points > 0 for r in parse(SAMPLE))


def test_直近ぶんだけを人気順に並べ直す(monkeypatch):
    """並びは全期間のクリック数順なので、日時で絞ってから数え直す。"""
    from src import topics

    monkeypatch.setattr(topics, "fetch", lambda *a, **k: topics.parse(SAMPLE))
    rows = topics.recent(hours=24, now=NOW)

    assert [r.points for r in rows] == [120, 50]   # 999点の古い記事は落ちる
    assert [r.rank for r in rows] == [1, 2]


def test_経過時間を返す():
    from src.topics import parse

    rows = parse(SAMPLE)
    assert rows[0].hours_ago(NOW) == 12.0


def test_metaは順位と経過時間を持つ(monkeypatch):
    from src import topics

    monkeypatch.setattr(topics, "fetch", lambda *a, **k: topics.parse(SAMPLE))
    found = topics.meta(topics.recent(hours=24, now=NOW), now=NOW)

    assert found["https://b.example/2.html"]["rank"] == 1
    assert found["https://b.example/2.html"]["points"] == 120
    assert found["https://a.example/1.html"]["hours_ago"] == 12.0
