"""順位表（定型シリーズ）。

分野を横断して24本を並べたら、どのチャンネルも節ごとに順位表を出していて
毎回伸びていた（トリベラ10万・6.1万、噂話6.7万）。中身は数字だけ。
"""

import pytest

from src.standings import (LEAGUE_IDS, Row, StandingsError, Table, card, fetch,
                           japanese)


def _table(n=6):
    rows = [Row(rank=i + 1, team=f"Team {i}", played=3, win=3 - i % 3,
                draw=0, lose=i % 3, diff=5 - i, points=9 - i) for i in range(n)]
    return Table(league="england", name="Premier League", rows=rows)


class _Response:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        pass

    def json(self):
        return self._payload


class _Session:
    def __init__(self, payload):
        self.payload = payload

    def get(self, url, **kwargs):
        return _Response(self.payload)


def _payload(rows):
    return {"details": {"name": "Premier League"},
            "table": [{"data": {"table": {"all": rows}}}]}


def test_順位表を読む():
    session = _Session(_payload([
        {"idx": 1, "name": "Arsenal", "played": 3, "wins": 3, "draws": 0,
         "losses": 0, "goalConDiff": 5, "pts": 9},
    ]))
    table = fetch("england", session=session)
    assert table.rows[0].team == "Arsenal" and table.rows[0].points == 9
    assert table.matchweek == 3


def test_空なら黙って返さない():
    """内部APIなので、形が変わったらここで気づけるようにする。"""
    with pytest.raises(StandingsError):
        fetch("england", session=_Session(_payload([])))


def test_知らないリーグは止める():
    with pytest.raises(StandingsError):
        fetch("brazil")


def test_リーグは6つ登録してある():
    assert set(LEAGUE_IDS) == {"england", "spain", "germany", "italy",
                               "france", "netherlands"}


def test_クラブ名を日本語にする():
    assert japanese("Arsenal") == "アーセナル"
    assert japanese("Hull City") == "ハル・シティ"
    assert japanese("Nowhere United") == "Nowhere United"   # 辞書に無ければそのまま


def test_カードは5列に収める():
    """8列にしたら「試合勝」「得失勝点」がくっついた（書き出して確認）。"""
    spec = card(_table(), top=4)
    assert spec["columns"] == ["順位", "クラブ", "試合", "得失", "勝点"]
    assert len(spec["rows"]) == 4
    assert all(len(row) == 5 for row in spec["rows"])


def test_タイトルは定型にそろえる():
    assert _table().title() == "【速報】プレミアリーグ第3節が終了、最新の順位表がこちらです"


def test_順位表の取材メモを組む():
    """定型シリーズ（2026-09-09）。9/7 に決めたが1本も作っていなかった。"""
    import yaml

    from src import standings
    from src.research import build_notes

    rows = [standings.Row(rank=n, team=f"Team{n}", played=3, win=3 - n % 3, draw=0,
                          lose=n % 3, diff=10 - n, points=9 - n) for n in range(1, 21)]
    table = standings.Table(league="england", name="Premier League", rows=rows)
    text = standings.note(table, "2026年9月9日")
    raw = yaml.safe_load(text)
    assert raw["format"] == "news"
    assert "順位が動いたのはどこか" in raw["theme"]["title"]     # 答え（首位）は書かない
    assert raw["sections"][0]["card"]["type"] == "table"
    assert raw["sections"][0]["official"] is True
    assert "premierleague.com" in raw["sections"][0]["sources"][0]
    notes = build_notes(raw)                                     # 取材メモとして読める
    assert notes.format == "news" and len(notes.sections) == 4
    assert notes.sections[-1].id == "reactions"                  # 反応は最後（反応で終わる）
