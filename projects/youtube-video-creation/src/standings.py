"""リーグの順位表を取る。**定型シリーズの材料。**

2026-09-07 に分野を横断して24本を並べたら、**どのチャンネルも順位表の動画を
定期的に出していて、毎回伸びていた**（トリベラ 10万・6.1万、噂話 6.7万）。
中身は数字だけで、取材も写真も要らない。こちらには繰り返し見にくる型が
1つも無かった。

取得は `results` と同じ FotMob のデータAPI。**公開ドキュメントの無い内部API
なので、予告なく変わる。**壊れたと分かるように、0件のときは黙って空を返さず
例外にする（`results` と同じ約束）。

    python -m src.cli standings england
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import requests

from .config import ProjectConfig

BASE = "https://www.fotmob.com/api/data"
TIMEOUT = 25
UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/152.0 Safari/537.36"
)

# 設定のリーグキー → FotMob のリーグID。2026-09-07 に1つずつ引いて名前を確かめた
LEAGUE_IDS = {
    "england": 47,       # Premier League
    "spain": 87,         # LaLiga
    "germany": 54,       # Bundesliga
    "italy": 55,         # Serie A
    "france": 53,        # Ligue 1
    "netherlands": 57,   # Eredivisie
}

LEAGUE_NAMES_JA = {
    "england": "プレミアリーグ",
    "spain": "ラ・リーガ",
    "germany": "ブンデスリーガ",
    "italy": "セリエA",
    "france": "リーグ・アン",
    "netherlands": "エールディヴィジ",
}


class StandingsError(Exception):
    pass


@dataclass
class Row:
    rank: int
    team: str
    played: int
    win: int
    draw: int
    lose: int
    diff: int
    points: int


@dataclass
class Table:
    league: str          # 設定のリーグキー
    name: str            # 大会名（FotMob の表記）
    rows: list[Row]

    @property
    def matchweek(self) -> int:
        """何節を終えたか。**チームによって消化数が違うので最多で言う。**"""
        return max((row.played for row in self.rows), default=0)

    @property
    def name_ja(self) -> str:
        return LEAGUE_NAMES_JA.get(self.league, self.name)

    def title(self) -> str:
        """定型シリーズのタイトル。参考3チャンネルと同じ形にそろえる。"""
        return f"【速報】{self.name_ja}第{self.matchweek}節が終了、最新の順位表がこちらです"


def fetch(league: str, session=None) -> Table:
    """順位表を取る。"""
    key = str(league).strip().lower()
    if key not in LEAGUE_IDS:
        raise StandingsError(
            f"知らないリーグです: {league}（{' / '.join(LEAGUE_IDS)}）"
        )
    client = session or requests
    try:
        response = client.get(f"{BASE}/leagues", params={"id": LEAGUE_IDS[key]},
                              headers={"User-Agent": UA}, timeout=TIMEOUT)
        response.raise_for_status()
        payload = response.json()
    except requests.RequestException as error:
        raise StandingsError(f"順位表を引けません: {error}") from error
    except ValueError as error:
        raise StandingsError(f"順位表の中身が読めません: {error}") from error

    rows = _rows(payload)
    if not rows:
        # **黙って空を返さない。**内部APIなので、形が変わったらここで気づく
        raise StandingsError(
            f"順位表が空です（{league}）。FotMob の作りが変わった可能性があります"
        )
    details = payload.get("details") or {}
    return Table(league=key, name=str(details.get("name") or key), rows=rows)


def _rows(payload: dict) -> list[Row]:
    blocks = payload.get("table") or []
    data = (blocks[0] or {}).get("data") if blocks else {}
    table = (data or {}).get("table") or {}
    out: list[Row] = []
    for entry in table.get("all") or []:
        try:
            out.append(Row(
                rank=int(entry["idx"]),
                team=str(entry["name"]),
                played=int(entry.get("played") or 0),
                win=int(entry.get("wins") or 0),
                draw=int(entry.get("draws") or 0),
                lose=int(entry.get("losses") or 0),
                diff=int(entry.get("goalConDiff") or 0),
                points=int(entry.get("pts") or 0),
            ))
        except (KeyError, TypeError, ValueError):
            continue
    return out


def japanese(team: str) -> str:
    """クラブ名を日本語表記にする。辞書に無ければ英語のまま。

    FotMob は英語表記で返す。**読み上げにも画面にも日本語が要る**ので、
    `config/clubs.yaml`（61クラブの別名辞書）を通す。
    """
    from . import clubs as clubs_mod

    found = clubs_mod.find(team)
    return found[0].canonical if found else team


def card(table: Table, top: int = 10) -> dict:
    """台本に貼る順位表のカード。**上位だけ・5列だけ。**

    20チーム全部を1枚に載せると、動画では字が読めない（実測でカードは
    画面の6割）。順位表の動画は「上が誰か」を見せるもの。
    **列も8つ入れたら「試合勝」「得失勝点」がくっついた**（2026-09-07、
    書き出して確認）。勝敗分けは読み上げで言えばよい。
    """
    head = ["順位", "クラブ", "試合", "得失", "勝点"]
    rows = [[str(r.rank), japanese(r.team), str(r.played),
             f"{r.diff:+d}", str(r.points)]
            for r in table.rows[:top]]
    return {
        "type": "table",
        "title": f"{table.name_ja} 第{table.matchweek}節終了時点",
        "columns": head,
        "rows": rows,
        "source": "FotMob",
    }


def board(table: Table, out_path: Path, config: ProjectConfig, top: int = 10) -> Path:
    """順位表を1枚の画像にする。サムネイルの下地に使える。"""
    from . import statboard

    out_path = Path(out_path)
    statboard.build_spec(card(table, top), out_path, config)
    statboard._write_mark(
        out_path, f"{table.name_ja} 第{table.matchweek}節",
        "勝点", [(r.team, float(r.points)) for r in table.rows[:top]], "FotMob",
    )
    return out_path
