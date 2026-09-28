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


def test_雛形は8節で_数字の行は埋まり_残りは人が書く(tmp_path):
    p = dict(id="342229", name="Kylian Mbappé", ja="キリアン・エムバペ", club="レアル・マドリード", club_id="418", shirt=10,
             captain=False, age=27, birth="1998-12-20", height=1.78, foot="右", position="センターフォワード",
             contract="2029-06-30", value=200000000, value_prev=180000000, history=HISTORY,
             season=[{"generalInformation": {"competitionId": "ES1"},
                      "statistics": {"goalStatistics": {"goalsSum": 7, "assistsSum": 2},
                                     "playingTimeStatistics": {"appearancesCount": 7, "playedMinutesSum": 630}}}],
             aggregated={"goalStatistics": {"goalsSum": 9, "assistsSum": 2},
                         "playingTimeStatistics": {"appearancesCount": 8, "playedMinutesSum": 720}},
             past=[["25/26", "50", "40", "8", "4000分"], ["24/25", "48", "38", "7", "3900分"]],
             url="/kylian-mbappe/profil/spieler/342229")
    fb = dict(fotmob_id="1", group="同じFW", traits=[], boards={"radar": "assets/stats/r.png", "shots": "assets/stats/s.png", "heat": "assets/stats/h.png", "value": "assets/stats/v.png"},
              strong=[dict(ja="得点", pct=99.0)], weak=[dict(ja="アシスト", pct=3.0)],
              recent=[["9/27", "ポルトガル", "90分", "1G 0A", "7.9"]], next=dict(when="10月12日", home="リバプール", away="マンチェスター・シティ", league="Premier League"))
    path = tmp_path / "note.yaml"
    mod.write_note(p, datetime.date(2026, 10, 1), path, fb)
    note = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert [s["id"] for s in note["sections"]] == ["hook", "data", "career", "style", "past", "season", "story", "view"]
    assert note["theme"]["nameplate"] == "キリアン・エムバペ｜レアル・マドリード FW"
    assert note["theme"]["bgm"] == "assets/audio/bgm_calm.wav"
    style = note["sections"][3]
    assert style["card"]["type"] == "bars" and style["card"]["items"][0]["label"] == "得点"
    assert style["say"][0]["image"] == "assets/stats/r.png" and style["say"][0]["no_telop"] is True
    season = note["sections"][5]
    assert season["main"] is True and season["say"][0]["short_only"] is True
    assert "今季はここまで8試合で9得点2アシスト、出場時間は720分。" in season["say"][1] and "80分" in season["say"][1]   # 語尾は選手ごとに回る（品質100回の88）
    assert note["sections"][4]["card"]["rows"][0][0] == "24/25"      # 古い順
    assert note["sections"][7]["telop"] == "10月12日、リバプール対マンチェスター・シティ"
    assert note["sections"][1]["say"][2].startswith("身長は1メートル78、利き足は右。契約は2029年まで")
