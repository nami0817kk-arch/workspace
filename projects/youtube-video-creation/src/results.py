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
