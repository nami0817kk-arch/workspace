"""日本人の次の相手（2026-09-28）。FotMob の形を真似て、表と雛形を確かめる。"""
import datetime
import importlib.util
from pathlib import Path

import yaml

spec = importlib.util.spec_from_file_location("next_opponent", Path("tools/next_opponent.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def test_名簿のクラブと_FotMobのクラブ名を突き合わせる():
    kubo = {"name": "久保建英", "club": "レアル・ソシエダ", "club_en": "Real Sociedad"}
    assert mod.same_club("Real Sociedad", kubo)
    assert not mod.same_club("Real Madrid", kubo)
    endo = {"name": "遠藤航", "club": "リバプール", "club_en": "Liverpool FC"}
    assert mod.same_club("Liverpool", endo)


def test_直近5試合と過去の対戦の表():
    entries = [{"resultString": "W", "tooltipText": {"utcTime": "2026-09-20T14:00:00.000Z", "homeTeam": "Valencia", "homeTeamId": 1,
                                                       "homeScore": "2", "awayTeam": "Real Sociedad", "awayTeamId": 2, "awayScore": "3"}},
               {"resultString": "L", "tooltipText": {"utcTime": "2026-09-13T14:00:00.000Z", "homeTeam": "Real Sociedad", "homeTeamId": 2,
                                                       "homeScore": "0", "awayTeam": "Barcelona", "awayTeamId": 3, "awayScore": "1"}}]
    rows = mod.form_rows(entries, "2")
    assert rows[0] == ["9/20", "バレンシア", "3-2", "○"]
    assert rows[1] == ["9/13", "バルセロナ", "0-1", "●"]
    h2h = {"summary": [3, 2, 1], "matches": [
        {"status": {"finished": False, "utcTime": "2027-01-01T00:00:00.000Z"}, "home": {"name": "A"}, "away": {"name": "B"}},
        {"status": {"finished": True, "utcTime": "2026-05-16T13:30:00.000Z", "scoreStr": "0 - 2"}, "home": {"name": "Real Sociedad"}, "away": {"name": "Deportivo A Coruña"}},
    ]}
    rows, summary = mod.h2h_rows(h2h)
    assert rows == [["2026/5/16", "レアル・ソシエダ", "0 - 2", "デポルティーボ"]] and summary == [3, 2, 1]


def test_雛形は相手_直近_過去_日本人_見立て(tmp_path):
    m = dict(id="1", league="spain", utc="2026-10-11T14:15:00Z", home="Real Sociedad", away="Deportivo A Coruña", home_id="2", away_id="9",
             home_ja="レアル・ソシエダ", away_ja="デポルティーボ", stadium="Reale Arena",
             japanese={"home": [dict(name="久保建英", tm="405398", played=7, starts=7, minutes=600, goals=2, assists=1)], "away": []},
             form={"home": [["9/20", "バレンシア", "3-2", "○"]], "away": [["9/20", "ベティス", "1-1", "△"], ["9/13", "ヘタフェ", "0-2", "●"]]},
             h2h=[["2026/5/16", "レアル・ソシエダ", "0 - 2", "デポルティーボ"]], h2h_summary=[3, 2, 1],
             standing={"home": dict(rank=4, points=15), "away": dict(rank=12, points=8)})
    path = tmp_path / "note.yaml"
    mod.write_note(m, datetime.date(2026, 10, 9), path)
    note = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert note["series"] == "日本人の次の相手" and note["people"] == ["久保建英"]
    assert [s["id"] for s in note["sections"]] == ["opponent", "form", "h2h", "japan", "view"]
    assert note["sections"][0]["say"][0] == "10月11日 23:15、久保建英のレアル・ソシエダはデポルティーボと対戦します。"
    assert ["順位", "12位（勝点8）"] in note["sections"][0]["card"]["rows"]
    assert note["sections"][1]["card"]["rows"] == m["form"]["away"]
    assert note["sections"][2]["say"][0] == "久保建英のレアル・ソシエダとデポルティーボ、過去の対戦は3勝2分1敗です。"
    assert note["sections"][3]["main"] is True
    assert note["sections"][3]["say"][1] == "久保建英は今季7試合で600分、2得点1アシスト。"
    assert note["theme"]["title"] == "久保建英のレアル・ソシエダ、次はデポルティーボ。相手はいまどんな状態か"
