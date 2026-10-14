"""数字で見る注目試合（2026-09-28）。FotMob の試合詳細の形を真似て、表・読み上げ・雛形を確かめる。"""
import datetime
import importlib.util
from pathlib import Path

import yaml

spec = importlib.util.spec_from_file_location("match_numbers", Path("tools/match_numbers.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def _payload():
    def stat(title, h, a):
        return {"title": title, "stats": [h, a]}

    return {
        "general": {"homeTeam": {"name": "Atlético Madrid"}, "awayTeam": {"name": "Real Madrid"},
                    "leagueName": "LaLiga", "matchRound": 7, "matchTimeUTCDate": "2026-09-20T14:15:00.000Z"},
        "content": {
            "matchFacts": {
                "playerOfTheMatch": {"name": {"fullName": "Giuliano Simeone"}, "rating": {"num": "8.1"}},
                "infoBox": {"Attendance": 70514},
                "events": {"events": [
                    {"type": "Goal", "time": 53, "fullName": "Alejandro Grimaldo", "isHome": True, "newScore": [1, 0],
                     "goalDescription": "Penalty"},
                    {"type": "Card", "time": 58},
                    {"type": "Goal", "time": 59, "fullName": "Jonathan David", "isHome": True, "newScore": [2, 0]},
                    {"type": "Goal", "time": 89, "fullName": "Antonio Rüdiger", "isHome": False, "newScore": [2, 1],
                     "goalDescription": "Header"},
                    {"type": "Goal", "time": 90, "overloadTime": 4, "fullName": "Nobody Known", "isHome": False,
                     "newScore": [2, 2]},
                ]},
            },
            "stats": {"Periods": {"All": {"stats": [
                {"title": "Top stats", "stats": [stat("Ball possession", 61, 39), stat("Expected goals (xG)", "2.35", "0.30"),
                                                 stat("Total shots", 18, 8), stat("Shots on target", 9, 3),
                                                 stat("Big chances", 4, 1), stat("Accurate passes", "556 (90%)", "337 (86%)")]},
                {"title": "Physical performance", "stats": [stat("Physical performance", None, None),
                                                            stat("Distance covered", 112974, 108367)]},
                {"title": "Duels", "stats": [stat("Duels won", 30, 62)]},
            ]}}},
            "lineup": {
                "homeTeam": {"starters": [{"name": "Giuliano Simeone", "age": 23, "countryCode": "ARG", "performance": {"rating": 8.1}},
                                          {"name": "Jan Oblak", "age": 33, "countryCode": "SVN", "performance": {"rating": 6.5}}]},
                "awayTeam": {"starters": [{"name": "Jude Bellingham", "age": 23, "countryCode": "ENG", "performance": {"rating": 7.4}},
                                          {"name": "Takefusa Kubo", "age": 25, "countryCode": "JPN", "performance": {"rating": 7.0}}]},
            },
        },
    }


def _match():
    p = _payload()
    goals = mod.parse_goals(p)
    return dict(id="1", home="Atlético Madrid", away="Real Madrid", home_ja="アトレティコ", away_ja="レアル",
                score=goals[-1]["score"], league_name="LaLiga", round=7, date="2026-09-20", attendance=70514,
                stats=mod.parse_stats(p), goals=goals, players=mod.parse_players(p))


def test_数字の表は決めた順で単位を付ける():
    m = _match()
    rows = mod.numbers_rows(m)
    assert rows[0] == ["ボール支配率", "61%", "39%"]
    assert rows[1] == ["xG（ゴール期待値）", "2.35", "0.30"]
    assert ["走行距離", "113.0km", "108.4km"] in rows
    assert rows[-1] == ["デュエル勝ち", "30", "62"]


def test_得点の流れは先制_追加点_1点返す_同点で読む():
    m = _match()
    lines = mod.flow_lines(m)
    assert lines[0] == "53分、アレハンドロ・グリマルド、PKで。アトレティコが先制。"
    assert lines[1].endswith("アトレティコが追加点。")
    assert lines[2] == "89分、アントニオ・リュディガー、ヘディングで。レアルが1点返す。"
    assert lines[3].startswith("90+4分、Nobody Known。レアルが同点に追いつく。")
    rows = mod.score_rows(m)
    assert rows[0] == ["53分", "アトレティコ", "アレハンドロ・グリマルド（PK）", "1-0"]


def test_xGと結果の食い違いが見立ての種になる():
    m = _match()
    m["score"] = [0, 1]
    assert "アトレティコのほうが xG で2.1上回りながら負けた" in mod.upset(m)
    m["score"] = [2, 0]
    assert mod.upset(m) == ""


def test_注目度はビッグクラブ_得点_日本人_観衆で決まる():
    m = _match()
    m["score"] = [2, 2]
    score, why = mod.attention(m)
    # ビッグ2つ・4ゴール・xG と結果が逆（2-2 なのに xG 2.35 対 0.30）・日本人・観衆
    assert score == 3 + 3 + 2 + 2 + 3 + 1
    assert "日本人が上位の採点" in why and "観衆70,514" in why


def test_雛形は得点の流れ_数字_選手_見立てで_英語の名前を知らせる(tmp_path):
    m = _match()
    path = tmp_path / "note.yaml"
    unknown = mod.write_note(m, datetime.date(2026, 9, 21), path, None)
    assert unknown == ["Nobody Known"]
    text = path.read_text(encoding="utf-8")
    assert "# カタカナにする（辞書に無い名前）: Nobody Known" in text
    note = yaml.safe_load(text)
    assert note["series"] == "数字で見る注目試合" and note["theme"]["league"] == "spain"
    ids = [s["id"] for s in note["sections"]]
    assert ids == ["score", "numbers", "players", "view"]
    assert note["sections"][0]["say"][0] == "アトレティコ対レアルは、2対2の引き分けでした。"
    assert note["sections"][1]["main"] is True
    assert note["sections"][1]["card"]["columns"] == ["", "アトレティコ", "レアル"]
    assert note["sections"][1]["say"][1] == "ボール支配率はアトレティコが61%、レアルが39%。"
    assert note["theme"]["title"].endswith("数字はどう見たか")
    assert note["thumbnail"]["line1"] == "アトレティコが2-2"
    assert "ジュリアーノ・シメオネ、採点8.1" in note["sections"][2]["say"][0]
    assert "ジュード・ベリンガム" in note["sections"][2]["say"][1]
    assert note["sections"][3]["viewpoint"] is True
    assert all(len(line) <= 40 for s in note["sections"][:2] for line in s["say"] if isinstance(line, str))
