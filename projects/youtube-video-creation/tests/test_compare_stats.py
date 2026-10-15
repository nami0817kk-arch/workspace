"""比べる回のスタッツ（tools/compare_stats.py）の条件と選び方（2026-10-15）。"""
import importlib.util
from pathlib import Path

_spec = importlib.util.spec_from_file_location("compare_stats", Path(__file__).resolve().parents[1] / "tools" / "compare_stats.py")
cs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cs)


def _ctx(name, minutes, league="Premier League", season="2026/2027", group="同じMF", section=True):
    return {"name": name, "team": "X", "league": league, "season": season, "minutes": minutes,
            "matches": 6, "group": group, "has_section": section}


def test_出場時間が足りない側がいれば比べない():
    notes, blockers = cs.conditions([_ctx("A", 31, section=False), _ctx("B", 534)])
    assert any("A" in b and "詳細スタッツ" in b for b in blockers)
    notes, blockers = cs.conditions([_ctx("A", 300), _ctx("B", 534)])
    assert any("300分" in b and "450分" in b for b in blockers)


def test_条件がそろえば比べてよく大会が違えば一言添える():
    notes, blockers = cs.conditions([_ctx("A", 700), _ctx("B", 800, league="LaLiga")])
    assert blockers == []
    assert any("大会が違います" in n for n in notes)


def test_位置の群が違えば比べない():
    _, blockers = cs.conditions([_ctx("A", 700, group="同じMF"), _ctx("B", 800, group="同じFW")])
    assert any("位置の群が違います" in b for b in blockers)


def test_標本が小さい側には一言添える():
    notes, blockers = cs.conditions([_ctx("A", 500), _ctx("B", 1500)])
    assert blockers == [] and any("標本が小さい" in n for n in notes)


def test_パーセンタイルの向きは小さいほうが上の項目で逆になる():
    assert cs.top_text(96) == "上位4%"
    assert cs.top_text(99.8) == "上位1%以内"
    assert cs.top_text(24, lower=True) == "上位24%"      # かわされた回数が少ない＝上
    assert cs.top_text(None) == "—"


def test_対面カードの行は群ごとに差の大きい項目を選ぶ():
    def row(group, title, a, b):
        return {"group": group, "title": title, "ja": title, "kind": "per90", "lower": False,
                "cells": [{"value": 1, "pct": a}, {"value": 2, "pct": b}]}
    rows = [row("攻撃", "g1", 50, 52), row("攻撃", "g2", 10, 90), row("攻撃", "g3", 20, 70),
            row("守備", "d1", 5, 95), row("守備", "d2", 40, 41)]
    chosen = [r["title"] for r in cs.pick_rows(rows)]
    assert chosen == ["g2", "g3", "d1", "d2"]
    assert len(cs.pick_rows([row("攻撃", f"x{i}", 0, i * 10) for i in range(9)])) <= 8
