"""有名選手の紹介の人選一覧（2026-09-28）。市場価値の順にリーグとクラブをばらして並べる。"""
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("player_pool", Path("tools/player_pool.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def _row(name, club, league, value, ja=""):
    return dict(id=name, name=name, ja=ja, club=club, club_id="1", league=league, age=25, birth="2001-01-01",
                position="センターフォワード", value=value, contract=None, captain=False)


def test_同じリーグが続かず同じクラブは2人まで():
    rows = [_row("A1", "レアル", "spain", 200), _row("A2", "レアル", "spain", 190), _row("A3", "レアル", "spain", 180),
            _row("B1", "シティ", "england", 170), _row("B2", "アーセナル", "england", 160),
            _row("C1", "バイエルン", "germany", 150), _row("D1", "インテル", "italy", 140), _row("E1", "PSG", "france", 130)]
    got = [r["name"] for r in mod.pick(rows, 8)]
    assert got[0] == "A1" and got[1] != "A2"            # 首位は市場価値どおり。2人目は別のリーグ
    assert "A3" not in got                               # レアルは2人まで
    assert all(got[i] != got[i + 1] for i in range(len(got) - 1))
    leagues = [next(r["league"] for r in rows if r["name"] == n) for n in got]
    assert all(leagues[i] != leagues[i + 1] for i in range(len(leagues) - 1))


def test_詳細から一覧の行を作る():
    data = {"id": "342229", "name": "Kylian Mbappé", "lifeDates": {"age": 27, "dateOfBirth": "1998-12-20"},
            "attributes": {"position": {"name": "Centre-Forward"}, "contractUntil": "2029-06-30"},
            "marketValueDetails": {"current": {"value": 200000000}}}
    row = mod.row_of(data, "レアル・マドリード", "418", "spain")
    assert row["position"] == "センターフォワード" and row["value"] == 200000000 and row["age"] == 27
    assert mod.row_of({"id": "1"}, "x", "1", "spain") is None
