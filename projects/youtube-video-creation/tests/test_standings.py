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
