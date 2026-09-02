"""試合結果を日付で取る。

フィードは移籍ニュースが中心で、試合結果は数時間で流れ切る。実測では、
移籍期限の翌日に177件拾って**試合結果は0件**だった。ニュースのフィードから
試合結果を拾おうとしても構造的に届かない。

そこで結果は結果として取る。使うのは FotMob のデータ API。
2026-09-02 の実測で、ブンデスリーガ第1節の9試合すべてが
bundesliga.com（公式）のスコアと一致した。

**注意: これは公開ドキュメントの無い内部APIで、予告なく変わる。**
壊れたら doctor が気づけるよう、取得件数が0のときは黙って空を返さず例外にする。

ここで作るのは候補（報道）であって確定ではない。スコアと得点者は、
台本にする段でリーグ公式まで辿ること（match の取材計画の check にある通り）。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date

import requests

BASE = "https://www.fotmob.com/api/data"
TIMEOUT = 25
UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/152.0 Safari/537.36"
)


class ResultsError(Exception):
    pass


@dataclass
class Match:
    league: str          # 設定のリーグキー（england / germany …）。不明なら空
    competition: str     # 大会名（そのまま）
    home: str
    away: str
    score: str           # "3 - 2"。まだなら空
    match_id: str = ""
    ratings: dict = field(default_factory=dict)   # チーム名 -> 採点

    @property
    def goals(self) -> int:
        """両チームの合計得点。読めなければ -1。"""
        try:
            left, right = (int(x.strip()) for x in self.score.split("-"))
        except (ValueError, AttributeError):
            return -1
        return left + right

    @property
    def finished(self) -> bool:
        return self.goals >= 0

    def title(self) -> str:
        return f"{self.home} {self.score} {self.away}"

    def url(self) -> str:
        return f"https://www.fotmob.com/matches/x/{self.match_id}" if self.match_id else ""


def _get(path: str, params: dict, session=None) -> dict:
    client = session or requests
    try:
        response = client.get(
            f"{BASE}/{path}", params=params, headers={"User-Agent": UA}, timeout=TIMEOUT
        )
    except requests.RequestException as error:
        raise ResultsError(f"試合結果に接続できません: {error}") from error
    if response.status_code != 200:
        raise ResultsError(
            f"試合結果を取れません（HTTP {response.status_code}）。"
            "公開されていないAPIなので、変わった可能性があります"
        )
    try:
        return response.json()
    except ValueError as error:
        raise ResultsError(f"試合結果の応答を読めません: {error}") from error


def fetch_day(day: date, leagues: dict | None = None, session=None) -> list[Match]:
    """その日に行われた試合。終わったものだけを返す。"""
    payload = _get("matches", {"date": day.strftime("%Y%m%d")}, session)
    blocks = payload.get("leagues") or []
    if not blocks:
        raise ResultsError(
            f"{day} の試合が1件も返りませんでした。"
            "APIの形が変わったか、その日に試合が無かったかのどちらかです"
        )

    found: list[Match] = []
    for block in blocks:
        competition = str(block.get("name", ""))
        key = league_key(block, leagues)
        for row in block.get("matches") or []:
            match = Match(
                league=key,
                competition=competition,
                home=str((row.get("home") or {}).get("name", "")),
                away=str((row.get("away") or {}).get("name", "")),
                score=str((row.get("status") or {}).get("scoreStr", "") or ""),
                match_id=str(row.get("id", "")),
            )
            if match.finished and match.home and match.away:
                found.append(match)
    return found


# 国コードと大会IDでリーグを見分ける。
#
# 名前だけで照合すると外す。「Premier League」を名乗る大会は実測で12あり、
# ロシア・ベラルーシ・カザフスタン・カナダ・クウェートまで拾ってしまった。
# FotMob は国コード(ccode)と大会ID(primaryId)を持っているので、その2つで見る。
LEAGUE_IDS = {
    "england": ("ENG", 47),
    "spain": ("ESP", 87),
    "germany": ("GER", 54),
    "italy": ("ITA", 55),
    "france": ("FRA", 53),
    "netherlands": ("NED", 57),
    "japan": ("JPN", 8974),
}


def league_key(block: dict, leagues: dict | None = None) -> str:
    """FotMob のブロックが、設定のどのリーグか。分からなければ空。"""
    ccode = str(block.get("ccode", "")).upper()
    primary = block.get("primaryId")
    for key, (want_cc, want_id) in LEAGUE_IDS.items():
        if leagues and key not in leagues:
            continue
        if ccode == want_cc and primary == want_id:
            return key
    return ""


# 採点がこの値以上なら「数字が立つ試合」と見る。
#
# 8.0 だと 20試合中18試合で立ってしまい、印としての意味がない。
# 2026-08-30 の20試合で各試合の最高採点を並べたところ、9.0以上が7試合だった。
# 「その日いちばん目立った選手がいた試合」を1/3ほどに絞る値として 9.0 を採る。
STANDOUT_RATING = 9.0
# 合計得点がこれ以上なら「点が動いた試合」と見る
MANY_GOALS = 5


@dataclass
class Detail:
    """1試合の中身。手で立てていたフラグを、ここから機械で決める。"""

    match_id: str
    ratings: dict = field(default_factory=dict)      # 選手名 -> 採点
    scorers: list = field(default_factory=list)      # 得点した選手名
    countries: dict = field(default_factory=dict)    # 選手名 -> 国コード

    @property
    def best(self) -> tuple[str, float] | None:
        if not self.ratings:
            return None
        name = max(self.ratings, key=lambda n: self.ratings[n])
        return name, self.ratings[name]

    def japanese_scorers(self) -> list[str]:
        return [n for n in self.scorers if self.countries.get(n) == "JPN"]

    def japanese_players(self) -> list[str]:
        return [n for n, cc in self.countries.items() if cc == "JPN"]


def fetch_detail(match_id: str, session=None) -> Detail:
    """1試合の採点・得点者・国籍を取る。

    国籍まで取れるので、日本人選手が絡む試合かどうかを名前の一覧に頼らず
    判定できる（名前の表記ゆれと、載せ忘れの両方を避けられる）。
    """
    payload = _get("matchDetails", {"matchId": str(match_id)}, session)
    lineup = (payload.get("content") or {}).get("lineup") or {}

    detail = Detail(match_id=str(match_id))
    for side in ("homeTeam", "awayTeam"):
        team = lineup.get(side) or {}
        for player in (team.get("starters") or []) + (team.get("subs") or []):
            name = str(player.get("name", "")).strip()
            if not name:
                continue
            performance = player.get("performance") or {}
            rating = performance.get("rating")
            if rating is not None:
                try:
                    detail.ratings[name] = float(rating)
                except (TypeError, ValueError):
                    pass
            country = str(player.get("countryCode", "")).strip().upper()
            if country:
                detail.countries[name] = country
            for event in performance.get("events") or []:
                if str(event.get("type")) == "goal":
                    detail.scorers.append(name)
    return detail


def flags(match: Match, detail: Detail | None = None) -> dict:
    """候補に立てるフラグ。手で立てていたものを機械で決める。

    人が365件を見て立てる前提だったので、実際には1件も立たなかった。
    ここで決まるのは「点が動いたか」「傑出した選手がいたか」「日本人が絡むか」で、
    どれも試合データから機械的に読める。**反応（賛否が割れているか）は
    ここでは決めない。** 数えていないものを立てたことにしない。
    """
    found: dict[str, bool] = {}
    if match.goals >= MANY_GOALS:
        found["goals"] = True
    if detail:
        best = detail.best
        if best and best[1] >= STANDOUT_RATING:
            found["numbers"] = True
        if detail.japanese_players():
            found["japanese"] = True
    return found
