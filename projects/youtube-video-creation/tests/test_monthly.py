"""月間まとめの雛形（2026-09-28）。手元の控えを寄せ集めて、表と読み上げを作る。"""
import datetime
import importlib.util
from pathlib import Path

import yaml

spec = importlib.util.spec_from_file_location("monthly", Path("tools/monthly.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def test_月の範囲():
    assert mod.month_range("2026-09") == (datetime.date(2026, 9, 1), datetime.date(2026, 9, 30))
    assert mod.month_range("2026-12")[1] == datetime.date(2026, 12, 31)


def _standings():
    return {lg: {"name_ja": lg, "rows": [dict(team="A", team_ja="エー", points=15), dict(team="B", team_ja="ビー", points=12)]}
            for lg in mod.LEAGUES}


def _scorers():
    return {lg: {"name_ja": lg, "rows": [dict(name="X", team_ja="エー", goals=5, penalties=0, minutes=450, games=5)]} for lg in mod.LEAGUES}


def test_雛形は首位_得点王_日本人_出来事_見立て(tmp_path):
    japan = [dict(name="鈴木彩艶", club="アストン・ヴィラ", week=dict(games=6, played=6, starts=5, minutes=495, goals=0, assists=0)),
             dict(name="誰か", club="どこか", week=dict(games=0, played=0, starts=0, minutes=0, goals=0, assists=0))]
    topics = [dict(at="2026-09-05T20:16", league="england", headline="三笘薫、監督の言葉が変わった", sources=["https://x/1"]),
              dict(at="2026-09-06T20:16", league="england", headline="三笘薫、監督の言葉が変わった", sources=["https://x/1"])]
    path = tmp_path / "note.yaml"
    mod.write_note("2026-09", datetime.date(2026, 10, 1), _standings(), _scorers(), {"X": "エックス"}, japan, topics, path)
    text = path.read_text(encoding="utf-8")
    assert text.count("三笘薫、監督の言葉が変わった") == 1          # 同じ見出しは1回
    note = yaml.safe_load(text)
    assert note["series"] == "月間まとめ" and note["people"] == []
    assert [s["id"] for s in note["sections"]] == ["leaders", "scorers", "japan", "events", "view"]
    assert note["sections"][0]["card"]["rows"][0] == ["england", "エー", "15", "3"]
    assert note["sections"][1]["card"]["rows"][0] == ["england", "エックス", "エー", "5"]
    assert note["sections"][2]["main"] is True
    assert note["sections"][2]["card"]["rows"] == [["鈴木彩艶", "アストン・ヴィラ", "6試合（先発5）", "495分", "0G 0A"]]
    assert note["sections"][2]["say"][1] == "9月にいちばん長く出たのは鈴木彩艶、495分。"
    assert note["theme"]["title"] == "鈴木彩艶と、5大リーグの9月。数字で振り返ると何が見えるか"
    assert note["sections"][4]["viewpoint"] is True
