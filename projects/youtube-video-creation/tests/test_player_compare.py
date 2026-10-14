"""有名選手の比較の雛形（2026-09-28）。2人の数字を横に並べ、どちらが上かは言わない。"""
import datetime
import importlib.util
from pathlib import Path

import yaml

spec = importlib.util.spec_from_file_location("player_compare", Path("tools/player_compare.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def _player(pid, name, club, age, value, goals, apps, minutes, peak_value, peak_age):
    return dict(id=pid, name=name, ja=name, club=club, club_id="1", shirt=9, captain=False, age=age, birth="2000-01-01",
                height=1.8, foot="右", position="センターフォワード", contract="2029-06-30", value=value, value_prev=value,
                history=[{"seasonId": 2020, "clubId": "1", "age": peak_age, "marketValue": {"value": peak_value}},
                         {"seasonId": 2026, "clubId": "1", "age": age, "marketValue": {"value": value}}],
                season=[], aggregated={"goalStatistics": {"goalsSum": goals, "assistsSum": 1},
                                       "playingTimeStatistics": {"appearancesCount": apps, "playedMinutesSum": minutes}},
                url=f"/x/profil/spieler/{pid}")


def test_2人の数字を横に並べて90分あたりも出す(tmp_path):
    a = _player("1", "エムバペ", "レアル・マドリード", 27, 200000000, 9, 8, 720, 200000000, 19)
    b = _player("2", "ハーランド", "マンチェスター・シティ", 26, 220000000, 10, 7, 630, 220000000, 26)
    rows = mod.season_rows(a, b)
    assert rows[0] == ["試合", "8", "7"] and rows[-1] == ["90分あたり得点", "1.12", "1.43"]
    assert mod.data_rows(a, b)[0] == ["所属", "レアル・マドリード", "マンチェスター・シティ"]
    path = tmp_path / "note.yaml"
    mod.write_note(a, b, datetime.date(2026, 10, 2), path)
    note = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert note["series"] == "有名選手の比較" and note["people"] == ["エムバペ", "ハーランド"]
    assert [s["id"] for s in note["sections"]] == ["data", "season", "value", "view"]
    assert note["sections"][1]["main"] is True and note["sections"][1]["card"]["columns"] == ["項目", "エムバペ", "ハーランド"]
    assert note["sections"][2]["card"]["rows"][1] == ["そのときの年齢", "19歳", "26歳"]
    assert note["thumbnail"]["face_link"] == "VS"
    assert "上下は言わず" in note["sections"][3]["say"][0]
    assert note["sections"][0]["say"][2] == "2人ともセンターフォワードです。"
    assert note["thumbnail"]["line1"] == "エムバペとハーランド"
    assert all(len(line) <= 40 for s in note["sections"] for line in s["say"] if isinstance(line, str))
