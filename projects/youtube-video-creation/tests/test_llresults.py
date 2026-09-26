"""ESPN の試合に節を振る（tools/llresults.py）。

ESPN の試合データには節の番号が無い。記事の番号は「そのクラブの何試合目か」のこともあり、
延期で早めに消化した試合が1つ混ざると日付順の区切りも崩れた（2026-09-27）。
"""
from __future__ import annotations

import importlib.util
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
spec = importlib.util.spec_from_file_location("llresults", ROOT / "tools" / "llresults.py")
llresults = importlib.util.module_from_spec(spec)
spec.loader.exec_module(llresults)


def _g(day, home, away):
    return {"day": day, "home": home, "away": away, "score": "1–0"}


def test_記事の番号がずれていても1節に1クラブ1試合になる():
    games = [_g("2026-08-16", "A", "B"), _g("2026-08-16", "C", "D"),
             _g("2026-08-23", "A", "C"), _g("2026-08-23", "B", "D"),
             _g("2026-08-30", "A", "D"), _g("2026-08-30", "B", "C")]
    key = llresults._key
    known = {key(games[0]): Counter({1: 1}), key(games[1]): Counter({1: 1}),
             # 「そのクラブの2試合目」の意味で 1 と書いた記事（本当は第2節）
             key(games[2]): Counter({1: 1}), key(games[3]): Counter({2: 1}),
             key(games[4]): Counter({3: 1})}
    llresults.assign(games, known)
    assert [g["round"] for g in games] == [1, 1, 2, 2, 3, 3]


def test_延期で先に消化した試合は票の節のまま():
    games = [_g("2026-08-16", "A", "B"), _g("2026-08-16", "C", "D"),
             _g("2026-08-20", "E", "F"),          # 第3節を先に消化
             _g("2026-08-23", "A", "C"), _g("2026-08-23", "B", "D"),
             _g("2026-08-30", "A", "D"), _g("2026-08-30", "B", "C")]
    key = llresults._key
    known = {key(g): Counter({r: 1}) for g, r in zip(games, [1, 1, 3, 2, 2, 3, 3])}
    llresults.assign(games, known)
    assert [g["round"] for g in games] == [1, 1, 3, 2, 2, 3, 3]
