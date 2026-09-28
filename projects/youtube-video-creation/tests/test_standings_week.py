"""5大リーグの順位表と「今週の1つ」（2026-09-28）。控えを比べて先週比と候補を出す。"""
import datetime
import importlib.util
import json
from pathlib import Path

import yaml

spec = importlib.util.spec_from_file_location("standings_week", Path("tools/standings_week.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def _table(name_ja, rows, mw=5):
    out = []
    for rank, (team, team_ja, w, d, l, pts) in enumerate(rows, 1):
        out.append(dict(rank=rank, team=team, team_ja=team_ja, played=w + d + l, win=w, draw=d, lose=l,
                        diff=0, points=pts))
    return {"name_ja": name_ja, "matchweek": mw, "rows": out}


def _five(first_rows):
    cur = {}
    for league in mod.LEAGUES:
        cur[league] = _table(league, first_rows)
    return cur


ROWS_BEFORE = [("A", "エー", 4, 0, 1, 12), ("B", "ビー", 3, 1, 1, 10), ("C", "シー", 3, 0, 2, 9),
               ("D", "ディー", 2, 2, 1, 8), ("E", "イー", 2, 1, 2, 7), ("F", "エフ", 0, 2, 3, 2), ("G", "ジー", 0, 1, 4, 1)]
ROWS_AFTER = [("B", "ビー", 4, 1, 1, 13), ("A", "エー", 4, 0, 2, 12), ("E", "イー", 3, 1, 2, 10),
              ("C", "シー", 3, 0, 3, 9), ("D", "ディー", 2, 2, 2, 8), ("G", "ジー", 1, 1, 4, 4), ("F", "エフ", 0, 2, 4, 2)]


def test_先週比は前の控えとの順位の差():
    before, after = _five(ROWS_BEFORE), _five(ROWS_AFTER)
    delta = mod.moves(after, before)["england"]
    assert delta["B"] == 1 and delta["A"] == -1 and delta["E"] == 2 and delta["D"] == -1
    rows = mod.table_rows(after["england"], delta, known=True, top=3)
    assert rows[0] == ["1", "ビー", "6", "13", "↑1"]
    assert rows[2][4] == "↑2"
    # 控えが無い初回は「―」
    assert mod.table_rows(after["england"], mod.moves(after, None)["england"], known=False, top=1)[0][4] == "―"


def test_候補は首位交代と大きな動きを拾う():
    before = _five(ROWS_BEFORE)
    after = _five(ROWS_AFTER)
    # スペインだけ、6位だったFが2位に、首位だったAが7位に（↑4 と ↓6）
    after["spain"]["rows"][1]["team"], after["spain"]["rows"][1]["team_ja"] = "F", "エフ"
    after["spain"]["rows"][6]["team"], after["spain"]["rows"][6]["team_ja"] = "A", "エー"
    picks = mod.candidates(after, before)
    kinds = {(c["league"], c["kind"]) for c in picks}
    assert ("england", "首位交代") in kinds
    assert ("spain", "上昇") in kinds and ("spain", "下落") in kinds
    assert picks[0]["kind"] == "首位交代"
    assert any("エフが6位から2位へ（↑4）" in c["text"] for c in picks)


def test_取材メモは5リーグの表と今週の1つと見立てを持つ(tmp_path):
    before, after = _five(ROWS_BEFORE), _five(ROWS_AFTER)
    path = tmp_path / "note.yaml"
    picks = mod.write_note(after, before, datetime.date(2026, 10, 6), path,
                           boards={"england": mod.ROOT / "assets" / "stats" / "x.png"})
    text = path.read_text(encoding="utf-8")
    assert text.startswith("# 5大リーグの順位表（2026-10-06）")
    assert "[首位交代]" in text
    note = yaml.safe_load(text)
    assert note["series"] == "5大リーグの順位表"
    ids = [s["id"] for s in note["sections"]]
    assert ids == mod.LEAGUES + ["pick", "view"]
    assert note["sections"][0]["card"]["columns"] == ["順位", "クラブ", "試合", "勝点", "先週比"]
    assert len(note["sections"][0]["card"]["rows"]) == mod.TOP
    assert note["sections"][5]["main"] is True and note["sections"][5]["say"][0]["short_only"] is True
    assert note["sections"][6]["viewpoint"] is True
    assert note["thumbnail"]["board"] == "assets/stats/x.png"
    assert note["theme"]["league"] == picks[0]["league"]
    assert note["sections"][0]["say"][0] == "englandは第5節まで。"
    assert note["sections"][0]["say"][1] == "首位はビー、勝点13です。2位のエーとは1点差。"
    # 5リーグで首位の言い方が全部ちがう（draft の重複の点検にかからない）
    seconds = [s["say"][1] for s in note["sections"][:5]]
    assert len(set(seconds)) == 5
    assert all(len(line) <= 40 for s in note["sections"][:5] for line in s["say"])
    assert note["theme"]["title"].startswith("ビーの首位交代と、")
    assert note["thumbnail"]["line2"] == "ビーの首位交代"


def test_前の控えは日付より前でいちばん新しいもの(tmp_path):
    for name in ("2026-09-22", "2026-09-29", "2026-10-06", "memo"):
        (tmp_path / f"{name}.json").write_text(json.dumps({"tag": name}), encoding="utf-8")
    got = mod.previous_snapshot(datetime.date(2026, 10, 6), tmp_path)
    assert got[0] == datetime.date(2026, 9, 29) and got[1] == {"tag": "2026-09-29"}
    assert mod.previous_snapshot(datetime.date(2026, 9, 22), tmp_path) is None
