"""欧州組の週報の数え方（2026-09-28）。Transfermarkt の記録の形を真似て数える。"""
import datetime
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("japan_abroad", Path("tools/japan_abroad.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def _game(date, state="played", minutes=90, starting=True, goals=0, assists=0, grade=None, comp="GB1"):
    return {
        "gameInformation": {"season": {"id": 2026}, "isNationalGame": False, "competitionId": comp,
                            "date": {"dateTimeUTC": f"{date}T14:00:00+00:00"}},
        "clubsInformation": {"club": {"venue": "home", "goalsTotal": 2, "opponentGoalsTotal": 1}},
        "statistics": {"generalStatistics": {"participationState": state, "grade": grade},
                       "playingTimeStatistics": {"playedMinutes": minutes if state == "played" else 0,
                                                 "isStarting": starting},
                       "goalStatistics": {"goalsScoredTotal": goals, "assists": assists}},
    }


def test_出場時間と得点は試合ごとの記録を足す():
    games = [_game("2026-09-20", minutes=90, goals=1, grade=7.2),
             _game("2026-09-23", minutes=30, starting=False, assists=1, grade=6.8),
             _game("2026-09-26", state="on_bench"),
             _game("2026-09-27", state="injured")]
    got = mod.summarize(games)
    assert got["played"] == 2 and got["starts"] == 1
    assert got["minutes"] == 120 and got["goals"] == 1 and got["assists"] == 1
    assert got["grade"] == 7.0 and got["bench"] == 1 and got["injured"] == 1


def test_1週間の窓で切る():
    games = [_game("2026-09-20"), _game("2026-09-22"), _game("2026-09-28"), _game("2026-09-29")]
    week = mod.in_window(games, datetime.date(2026, 9, 22), datetime.date(2026, 9, 28))
    assert [g["gameInformation"]["date"]["dateTimeUTC"][:10] for g in week] == ["2026-09-22", "2026-09-28"]


def test_表は出た人だけ():
    rows = [
        {"name": "久保建英", "club": "レアル・ソシエダ", "week": mod.summarize([_game("2026-09-27", minutes=75, goals=1)]), "season": {}},
        {"name": "三笘薫", "club": "ブライトン", "week": mod.summarize([_game("2026-09-27", state="injured")]), "season": {}},
        {"name": "誰か", "club": "どこか", "week": mod.summarize([]), "season": {}},
    ]
    table = mod.table_rows(rows)
    assert table[0] == ["久保建英", "レアル・ソシエダ", "1試合（先発1）", "75分", "1G 0A"]
    assert table[1][2] == "けが"
    assert len(table) == 2


def test_取材メモの雛形は見立ての節を持つ(tmp_path):
    import yaml

    rows = [{"name": "久保建英", "club": "レアル・ソシエダ", "tm": "405398", "competition": "ES1",
             "week": mod.summarize([_game("2026-09-27", minutes=75, goals=1)]),
             "season": mod.summarize([_game("2026-09-27", minutes=75, goals=1)]), "matches": []}]
    path = tmp_path / "note.yaml"
    mod.write_note(rows, datetime.date(2026, 9, 28), path)
    note = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert note["series"] == "欧州組の1週間"
    assert any(s.get("viewpoint") for s in note["sections"])
    assert note["sections"][0]["card"]["rows"][0][0] == "久保建英"


def test_名前とクラブ名の整え方():
    assert mod.clean_name("遠藤 航", "Wataru Endo") == "遠藤航"
    assert mod.clean_name("小久保玲央ブライアン-LeoBrianKokubo", "小久保玲央ブライアン") == "小久保玲央ブライアン"
    assert mod.clean_name("", "鈴木 唯人") == "鈴木唯人"
    assert mod.club_ja("Manchester City") == "マンチェスター・シティ"
    assert mod.club_ja("Real Sociedad") in ("レアル・ソシエダ", "Real Sociedad")


def test_代表戦は既定で除き_代表ウィークだけ数える():
    club = _game("2026-09-20")
    national = _game("2026-09-25")
    national["gameInformation"]["isNationalGame"] = True
    national["gameInformation"]["competitionId"] = "WMQA"
    assert mod.split_games([club, national]) == [club]
    assert mod.split_games([club, national], national=True) == [club, national]
    assert mod._match_line(national)["competition"] == "W杯予選（アジア）"
