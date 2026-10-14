"""クラブ紹介シリーズの「どのリーグか」を1か所で決める（2026-09-26）。

ユーザー「プレミアリーグ紹介のラリーガ版作れる？」→「OK」（見本はレアル・ソシエダ）。
プレミア版の道具（plbuild / plsquad / plmap / plast / plfaces / plmanagers / plpage）は
`research/pl_data` と `assets/stats/pl_*` とイングランドの地図を決め打ちしていた。
**道具を複製せず、環境変数 `CLUB_LEAGUE` で切り替える。**既定はプレミア（今までどおり）。

    CLUB_LEAGUE=laliga python tools/plsquad.py realsociedad Real_Sociedad "2026–27_Real_Sociedad_season"
    CLUB_LEAGUE=bundesliga python tools/plmap.py            # ブンデスリーガ版（2026-09-28、research/bd_data）
"""
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

LEAGUES = {
    "premier": {
        "data": "pl_data",
        "prefix": "pl_",
        # 公開する題の後ろに付くシリーズ名（2026-09-23 指示）
        "series": "プレミアリーグチーム紹介",
        # 取材メモの theme.league（タグの鍵）と、読み上げで使うリーグ名
        "league": "england",
        "league_name": "プレミアリーグ",
        "league_short": "プレミア",
        # 基礎DATAの9枚目の見出し（昨季の順位表を出す行の目印）
        "best_label": "プレミア最高位",
        "slot": "premier_1",
        "page_title": "プレミア20クラブの台本",
        # 地図（Module:Location map/data/<map_module> の四隅と白地図）
        "map_module": "UK England",
        "map_file": "United Kingdom England adm location map.svg",
        "map_png": "england.png",
        "map_note": "イングランドの白地図に20クラブの紋章を置いたもの",
        # 取材メモの出力（research/<note_prefix><番号>_<key>.yaml）
        "note_prefix": "20260920_pl",
        "legends": "pl_legends.json",
    },
    "laliga": {
        "data": "ll_data",
        "prefix": "ll_",
        "series": "ラ・リーガチーム紹介",
        "league": "spain",
        "league_name": "ラ・リーガ",
        "league_short": "ラ・リーガ",
        "best_label": "昨季の順位",
        "slot": "laliga_1",
        "page_title": "ラ・リーガ20クラブの台本",
        "map_module": "Spain",
        "map_file": "Spain location map.svg",
        "map_png": "spain.png",
        "map_note": "スペインの白地図に20クラブの紋章を置いたもの",
        "note_prefix": "20260926_ll",
        "legends": "ll_legends.json",
    },
    # ブンデスリーガ版（2026-09-28）。18クラブ。地図は Module:Location map/data/Germany の四隅
    "bundesliga": {
        "data": "bd_data",
        "prefix": "bd_",
        "series": "ブンデスリーガチーム紹介",
        "league": "germany",
        "league_name": "ブンデスリーガ",
        "league_short": "ブンデス",
        "best_label": "昨季の順位",
        "slot": "other_1",
        "page_title": "ブンデス18クラブの台本",
        "map_module": "Germany",
        "map_file": "Germany adm location map.svg",
        "map_png": "germany.png",
        "map_note": "ドイツの白地図に18クラブの紋章を置いたもの",
        "note_prefix": "20260928_bd",
        "legends": "bd_legends.json",
    },
}


def name() -> str:
    got = os.environ.get("CLUB_LEAGUE", "premier").strip().lower() or "premier"
    if got in ("pl", "england"):
        got = "premier"
    if got in ("ll", "liga", "spain"):
        got = "laliga"
    if got in ("bd", "bl", "bundes", "germany"):
        got = "bundesliga"
    if got not in LEAGUES:
        raise SystemExit(f"■ CLUB_LEAGUE={got} は知らないリーグです（{', '.join(LEAGUES)}）")
    return got


def current() -> dict:
    return LEAGUES[name()]


def data_dir() -> Path:
    return ROOT / "research" / current()["data"]


def prefix() -> str:
    return current()["prefix"]
