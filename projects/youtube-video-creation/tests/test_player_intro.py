"""有名選手の紹介の雛形（2026-09-28）。Transfermarkt の形を真似て、表と読み上げを確かめる。"""
import datetime
import importlib.util
from pathlib import Path

import yaml

spec = importlib.util.spec_from_file_location("player_intro", Path("tools/player_intro.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
mod.club_ja = lambda cid: {"9669": "モナコ", "162": "モナコ", "583": "パリ・サンジェルマン", "418": "レアル・マドリード"}.get(str(cid), str(cid))


def _hist(season, club, age, value):
    return {"seasonId": season, "clubId": club, "age": age, "marketValue": {"value": value, "determined": f"{season}-12-01"}}


HISTORY = [_hist(2015, "9669", 16, 50000), _hist(2016, "162", 18, 35000000), _hist(2017, "162", 18, 90000000),
           _hist(2018, "583", 19, 200000000), _hist(2023, "583", 24, 180000000), _hist(2025, "418", 27, 180000000),
           _hist(2026, "418", 27, 200000000)]


def test_市場価値の言い方():
    assert mod.compact_value(200000000) == "2億ユーロ"
    assert mod.compact_value(180000000) == "1.8億ユーロ"
    assert mod.compact_value(35000000) == "3500万ユーロ"


def test_歩んできた道は1クラブ1行で季と最高額():
    rows = mod.career_rows(HISTORY)
    # U19 とトップが同じ日本語名なら1行にまとめる
    assert rows[0] == ["15/16〜17/18", "モナコ", "16歳〜18歳", "最高 9000万ユーロ"]
    assert rows[1] == ["18/19〜23/24", "パリ・サンジェルマン", "19歳〜24歳", "最高 2億ユーロ"]
    assert rows[2][1] == "レアル・マドリード" and len(rows) == 3


def test_雛形は基礎DATA_道_今季_見立て(tmp_path):
    p = dict(id="342229", name="Kylian Mbappé", ja="キリアン・エムバペ", club="レアル・マドリード", club_id="418", shirt=10,
             captain=False, age=27, birth="1998-12-20", height=1.78, foot="右", position="センターフォワード",
             contract="2029-06-30", value=200000000, value_prev=180000000, history=HISTORY,
             season=[{"generalInformation": {"competitionId": "ES1"},
                      "statistics": {"goalStatistics": {"goalsSum": 7, "assistsSum": 2},
                                     "playingTimeStatistics": {"appearancesCount": 7, "playedMinutesSum": 630}}},
                     {"generalInformation": {"competitionId": "CL"},
                      "statistics": {"goalStatistics": {"goalsSum": 2, "assistsSum": 0},
                                     "playingTimeStatistics": {"appearancesCount": 1, "playedMinutesSum": 90}}}],
             aggregated={"goalStatistics": {"goalsSum": 9, "assistsSum": 2},
                         "playingTimeStatistics": {"appearancesCount": 8, "playedMinutesSum": 720}},
             url="/kylian-mbappe/profil/spieler/342229")
    path = tmp_path / "note.yaml"
    unknown = mod.write_note(p, datetime.date(2026, 10, 1), path)
    assert unknown == []
    note = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert note["series"] == "有名選手の紹介" and note["people"] == ["キリアン・エムバペ"]
    ids = [s["id"] for s in note["sections"]]
    assert ids == ["data", "career", "season", "view"]
    assert ["生年月日", "1998年12月20日（27歳）"] in note["sections"][0]["card"]["rows"]
    assert note["sections"][0]["say"][0] == "キリアン・エムバペ、27歳。レアル・マドリードのセンターフォワードです。"
    assert "1.8億ユーロから2億ユーロに上がりました" in note["sections"][0]["say"][-1]
    assert note["sections"][2]["main"] is True
    assert note["sections"][2]["card"]["rows"][0] == ["ラ・リーガ", "7", "7", "2", "630分"]
    assert note["sections"][2]["say"][1] == "今季はここまで8試合で9得点2アシスト、720分です。"
    assert note["sections"][3]["viewpoint"] is True
    assert note["theme"]["title"].startswith("キリアン・エムバペってどんな選手？")
