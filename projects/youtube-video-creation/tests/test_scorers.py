"""5大リーグの得点王レース（2026-09-28）。控えを比べて先週比と候補を出す。"""
import datetime
import importlib.util
from pathlib import Path

import yaml

spec = importlib.util.spec_from_file_location("scorers", Path("tools/scorers.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def _row(rank, name, team, goals, pens=0, minutes=450, games=5, country="ESP"):
    return dict(rank=rank, name=name, team=team, team_ja=team, goals=goals, penalties=pens, minutes=minutes, games=games, country=country)


def _five(rows):
    return {lg: {"name_ja": lg, "rows": [dict(r) for r in rows]} for lg in mod.LEAGUES}


BEFORE = [_row(1, "A", "X", 6), _row(2, "B", "Y", 5), _row(3, "C", "Z", 3), _row(4, "D", "W", 3), _row(5, "E", "V", 2), _row(6, "F", "U", 2)]
AFTER = [_row(1, "B", "Y", 8, pens=4), _row(2, "A", "X", 6, minutes=300), _row(3, "F", "U", 4, minutes=180),
         _row(4, "C", "Z", 3), _row(5, "G", "T", 3, country="JPN"), _row(6, "D", "W", 3)]
WD = {"A": "エー", "B": "ビー", "C": "シー", "D": "ディー", "F": "エフ", "G": "ジー"}


def test_表は先週比と_PKの内訳を持つ():
    rows = mod.table_rows(AFTER, WD, BEFORE, top=5)
    assert rows[0] == ["1", "ビー", "Y", "8（PK4）", "↑1"]
    assert rows[1][4] == "↓1" and rows[2][4] == "↑3" and rows[4][4] == "new"
    assert mod.table_rows(AFTER, WD, None, top=1)[0][4] == "―"


def test_候補は首位交代_PK頼み_日本人_急浮上を拾う():
    picks = mod.candidates(_five(AFTER), _five(BEFORE), WD)
    kinds = {c["kind"] for c in picks}
    assert {"首位交代", "PK頼み", "日本人", "急浮上"} <= kinds
    assert picks[0]["kind"] == "首位交代" and "エーからビーに" in picks[0]["text"]
    assert any(c["kind"] == "日本人" and "G" in c["name"] for c in picks)


def test_雛形は5リーグと今週の1つと見立てで_首位の言い方を変える(tmp_path):
    path = tmp_path / "note.yaml"
    unknown = mod.write_note(_five(AFTER), _five(BEFORE), datetime.date(2026, 10, 1), path, WD)
    assert unknown == []
    note = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert note["series"] == "5大リーグの得点王レース"
    assert [s["id"] for s in note["sections"]] == mod.LEAGUES + ["pick", "view"]
    seconds = [s["say"][1] for s in note["sections"][:5]]
    assert len(set(seconds)) == 5
    assert "PKが4本。PKを抜くと4点です。" in note["sections"][0]["say"][2]
    assert note["sections"][5]["main"] is True and note["sections"][6]["viewpoint"] is True
    assert note["theme"]["title"].startswith("ビーの首位交代。")
    assert all(len(line) <= 44 for s in note["sections"][:5] for line in s["say"])
