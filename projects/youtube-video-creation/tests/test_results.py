"""試合結果の取得。

フィードは移籍ニュースが中心で、試合結果は数時間で流れ切る。実測で、
移籍期限の翌日に177件拾って**試合結果は0件**だった。結果は結果として取る。
"""

from dataclasses import dataclass, field
from datetime import date

import pytest
import requests

from src.results import Match, ResultsError, fetch_day, league_key

LEAGUES = {"england": {}, "germany": {}, "spain": {}}

PAYLOAD = {
    "date": "20260830",
    "leagues": [
        {"ccode": "ENG", "id": 47, "primaryId": 47, "name": "Premier League", "matches": [
            {"id": "1", "home": {"name": "Chelsea"}, "away": {"name": "Brighton"},
             "status": {"scoreStr": "4 - 3"}},
            {"id": "2", "home": {"name": "Leeds"}, "away": {"name": "Brentford"},
             "status": {"scoreStr": ""}},          # まだ終わっていない
        ]},
        # 「Premier League」を名乗る大会は実測で12あった。国が違えば別物
        {"ccode": "BLR", "id": 923169, "primaryId": 923169, "name": "Premier League",
         "matches": [{"id": "9", "home": {"name": "BATE"}, "away": {"name": "FC Minsk"},
                      "status": {"scoreStr": "2 - 1"}}]},
        {"ccode": "GER", "id": 54, "primaryId": 54, "name": "Bundesliga", "matches": [
            {"id": "3", "home": {"name": "Freiburg"}, "away": {"name": "Bremen"},
             "status": {"scoreStr": "4 - 1"}},
        ]},
    ],
}


@dataclass
class FakeResponse:
    status_code: int = 200
    payload: dict | None = None
    text: str = ""

    def json(self):
        if self.payload is None:
            raise ValueError("no json")
        return self.payload


@dataclass
class FakeSession:
    response: FakeResponse = field(default_factory=lambda: FakeResponse(payload=PAYLOAD))
    error: Exception | None = None

    def get(self, url, params=None, headers=None, timeout=None):
        if self.error:
            raise self.error
        return self.response


def test_終わった試合だけを返す():
    found = fetch_day(date(2026, 8, 30), LEAGUES, session=FakeSession())
    assert [m.title() for m in found if m.league] == [
        "Chelsea 4 - 3 Brighton", "Freiburg 4 - 1 Bremen"
    ]


def test_同名の別大会を取り違えない():
    """「Premier League」を名乗る大会は実測で12あり、名前だけでは外す。"""
    found = fetch_day(date(2026, 8, 30), LEAGUES, session=FakeSession())
    assert all(m.league != "england" or m.home != "BATE" for m in found)
    assert not [m for m in found if m.home == "BATE" and m.league]


def test_国コードと大会IDで見分ける():
    assert league_key({"ccode": "ENG", "primaryId": 47}) == "england"
    assert league_key({"ccode": "BLR", "primaryId": 923169}) == ""
    assert league_key({"ccode": "GER", "primaryId": 54}) == "germany"


def test_合計得点を数える():
    assert Match("germany", "Bundesliga", "A", "B", "3 - 2").goals == 5
    assert Match("germany", "Bundesliga", "A", "B", "").goals == -1
    assert not Match("germany", "Bundesliga", "A", "B", "").finished


def test_1件も返らなければ黙って空にしない():
    """公開されていないAPIなので、形が変わったら気づけるようにする。"""
    fake = FakeSession(response=FakeResponse(payload={"leagues": []}))
    with pytest.raises(ResultsError, match="1件も返りません"):
        fetch_day(date(2026, 8, 30), LEAGUES, session=fake)


def test_HTTPが200でなければ理由を言う():
    fake = FakeSession(response=FakeResponse(status_code=503))
    with pytest.raises(ResultsError, match="503"):
        fetch_day(date(2026, 8, 30), LEAGUES, session=fake)


def test_つながらないときも理由を言う():
    fake = FakeSession(error=requests.ConnectionError("切断"))
    with pytest.raises(ResultsError, match="接続できません"):
        fetch_day(date(2026, 8, 30), LEAGUES, session=fake)


# 手で立てる欄（反応/番狂わせ/得点/数字）は、実際には365件中0件しか立たなかった。
# 重み17点のうち9点分が死んでいた。試合データから機械で決める。

DETAIL = {
    "content": {"lineup": {
        "homeTeam": {"starters": [
            {"name": "Yuito Suzuki", "countryCode": "JPN",
             "performance": {"rating": 9.7, "events": [{"type": "goal"}]}},
            {"name": "Anton Kade", "countryCode": "GER",
             "performance": {"rating": 7.1, "events": [{"type": "yellowCard"}]}},
        ], "subs": []},
        "awayTeam": {"starters": [
            {"name": "Marco Friedl", "countryCode": "AUT",
             "performance": {"rating": 6.2, "events": []}},
        ], "subs": []},
    }}
}


def _detail_session():
    return FakeSession(response=FakeResponse(payload=DETAIL))


def test_採点と得点者と国籍を取る():
    from src.results import fetch_detail

    d = fetch_detail("1", session=_detail_session())
    assert d.best == ("Yuito Suzuki", 9.7)
    assert d.scorers == ["Yuito Suzuki"]
    assert d.japanese_players() == ["Yuito Suzuki"]
    assert d.japanese_scorers() == ["Yuito Suzuki"]


def test_国籍で日本人を見分ける():
    """名前の一覧に頼ると、表記ゆれと載せ忘れの両方で外す。"""
    from src.results import fetch_detail

    d = fetch_detail("1", session=_detail_session())
    assert "Anton Kade" not in d.japanese_players()


def test_点が多く動いた試合に得点のフラグが立つ():
    from src.results import Match, flags

    assert flags(Match("x", "y", "A", "B", "4 - 3")).get("goals")
    assert not flags(Match("x", "y", "A", "B", "1 - 0")).get("goals")


def test_傑出した採点があれば数字のフラグが立つ():
    """8.0 だと20試合中18試合で立ち、印にならなかった（実測）。9.0 に絞る。"""
    from src.results import Match, fetch_detail, flags

    d = fetch_detail("1", session=_detail_session())
    assert flags(Match("x", "y", "A", "B", "1 - 0"), d).get("numbers")

    d.ratings["Yuito Suzuki"] = 8.4
    assert not flags(Match("x", "y", "A", "B", "1 - 0"), d).get("numbers")


def test_反応のフラグは機械で立てない():
    """賛否が割れているかは試合データからは分からない。数えていないものを立てない。"""
    from src.results import Match, fetch_detail, flags

    d = fetch_detail("1", session=_detail_session())
    assert "reaction" not in flags(Match("x", "y", "A", "B", "5 - 4"), d)
