"""FotMob の選手データから板と材料を作る道具（2026-09-28）。形を真似た JSON で確かめる。"""
import importlib.util
from pathlib import Path

from PIL import Image

spec = importlib.util.spec_from_file_location("fotmob_player", Path("tools/fotmob_player.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

spec2 = importlib.util.spec_from_file_location("player_intro", Path("tools/player_intro.py"))
intro = importlib.util.module_from_spec(spec2)
spec2.loader.exec_module(intro)

spec3 = importlib.util.spec_from_file_location("widecrop", Path("tools/widecrop.py"))
wide = importlib.util.module_from_spec(spec3)
spec3.loader.exec_module(wide)


def _data():
    def item(title, value, pct):
        return {"title": title, "statValue": value, "per90": 1.0, "percentileRankPer90": pct}
    return {
        "name": "Erling Haaland",
        "traits": {"key": "stats_comparison_forwards", "items": [{"key": "goals", "title": "Goals", "value": 0.99},
                                                                  {"key": "touches", "title": "Touches", "value": 0.01},
                                                                  {"key": "aerials_won", "title": "Aerial duels", "value": 0.57}]},
        "firstSeasonStats": {"statsSection": {"items": [{"title": "Shooting", "items": [item("Goals", "5", 100), item("Shots", "20", 92), item("xGOT", "5.2", 100)]},
                                                         {"title": "Passing", "items": [item("Assists", "0", 0), item("Chances created", "1", 4)]},
                                                         {"title": "Discipline", "items": [item("Yellow cards", "0", 100)]}]},
                             "shotmap": [{"eventType": "Goal", "x": 100.0, "y": 34.0, "expectedGoals": 0.6, "isOnTarget": True},
                                         {"eventType": "Miss", "x": 90.0, "y": 30.0, "expectedGoals": 0.1, "isOnTarget": False}],
                             "heatmap": {"coordinates": [{"x": 90.0, "y": 34.0}, {"x": 60.0, "y": 30.0}, {"x": 95.0, "y": 36.0}]}},
        "recentMatches": [{"playedInMatch": True, "matchDate": {"utcTime": "2026-09-27T18:45:00Z"}, "opponentTeamName": "Portugal",
                           "minutesPlayed": 90, "goals": 1, "assists": 0, "ratingProps": {"rating": "7.9"}},
                          {"playedInMatch": False, "matchDate": {"utcTime": "2026-09-20T14:00:00Z"}, "opponentTeamName": "Sunderland"}],
        "nextMatch": {"matchDate": "2026-10-11T15:30:00Z", "homeName": "Liverpool", "awayName": "Manchester City", "leagueName": "Premier League"},
    }


def test_武器と弱点は数の無い項目と警告を外して選ぶ():
    stats = mod.season_stats(_data())
    strong, weak = mod.strengths(stats)
    assert [s["ja"] for s in strong] == ["得点", "xGOT（枠内の質）", "シュート"]
    assert weak[0]["ja"] in ("アシスト", "チャンス創出") and weak[0]["title"] != "Yellow cards"


def test_直近の試合は出た試合だけで相手は日本語():
    rows = mod.recent(_data())
    assert rows == [["9/27", "ポルトガル", "90分", "1G 0A", "7.9"]]
    nxt = mod.next_match(_data())
    assert nxt == dict(when="10月12日", home="リバプール", away="マンチェスター・シティ", league="Premier League")


def test_板は4種とも書け_縦版と印が付く(tmp_path):
    d = _data()
    group, items = mod.traits(d)
    assert group == "同じFW" and items[0] == ("得点", 0.99)
    radar = mod.radar_board(group, items, tmp_path / "r.png", "ハーランド")
    shots = mod.shotmap_board(mod.shots(d), tmp_path / "s.png", "ハーランド")
    heat = mod.heatmap_board(mod.heat(d), tmp_path / "h.png", "ハーランド")
    hist = [{"seasonId": 2019, "clubId": "1", "age": 19, "marketValue": {"value": 45000000, "determined": "2019-12-01"}},
            {"seasonId": 2026, "clubId": "2", "age": 26, "marketValue": {"value": 220000000, "determined": "2026-06-04"}}]
    value = mod.value_board(hist, tmp_path / "v.png", "ハーランド", club_of=lambda c: {"1": "ザルツブルク", "2": "シティ"}[c])
    for board in (radar, shots, heat, value):
        assert Image.open(board).size == (1280, 720)
        assert board.with_name(board.name + ".statboard.txt").exists()
        tall = mod.portrait_variant(board)
        assert Image.open(tall).size == (1080, 1920) and tall.name.endswith("_v.png")


def test_縦写真を顔を残して16対9に切る(tmp_path):
    src = tmp_path / "p" / "01.jpg"
    src.parent.mkdir()
    Image.new("RGB", (3000, 4500), (120, 30, 30)).save(src)
    (src.parent / "credits.json").write_text('{"source": "x"}', encoding="utf-8")
    out = wide.crop_wide(src, tmp_path / "w", top=0.05)
    assert Image.open(out).size == (3000, 1687)
    assert (tmp_path / "w" / "credits.json").exists()


def test_読み上げ用の言い換え():
    assert intro._meters(1.95) == "1メートル95"
    assert intro._season_ja("21/22") == "2021年からのシーズン"
    assert intro._pos_short("センターフォワード") == "FW" and intro._pos_short("守備的MF") == "MF"
    assert intro._circled(2) == "②"
