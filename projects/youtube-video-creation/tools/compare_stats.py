"""比べる回のスタッツを、条件を揃えて取り出す（2026-10-15）。

ユーザー「比べる時は、スタッツをちゃんと扱ってほしい」。それまでの比べる回（`player_compare.py`）は
Transfermarkt の合計（試合・得点・アシスト・出場時間）だけで、次が抜けていた。

- **出場時間が違う2人を合計で比べていた。**カマラは約530分、バレバはシーズンの詳細スタッツが無い
- **90分あたり・xG・パス・守備の数字が無い**（FotMob には42項目ある）
- **同じ大会・同じシーズンか確かめていない**（リーグの強さが違う2人を並べると不公平になる）
- **標本が小さい数字（試合数が少ない）を、大きい数字と同じ重さで出していた**

    python tools/compare_stats.py 1352713 816325 --names バレバ カマラ
    python tools/compare_stats.py <FotMobの番号A> <番号B> --names A B --min 450 --out research/raw/20261017_stats.json

FotMob の番号は `python tools/fotmob_player.py find "<英語名>"`。FotMob は公開ドキュメントの無い内部API
（`fotmob_player.py` と同じ。壊れたら例外で止まる。1人1日1回だけ取って控える）。

やること
1. **条件を確かめる**：大会・シーズン・出場時間・位置の群。違えば `条件` に理由つきで出す
2. **比べられない項目は出さない**：出場時間が足りない（既定450分＝約5試合）側が1人でもいれば、スタッツの比較は出さず理由だけ出す
3. **90分あたりで比べる**（合計は出場時間が違うと比べられない）。割合（パス成功・デュエル勝率・空中戦勝率・ドリブル成功率）はそのまま
4. **同じ位置の選手の中での順位（パーセンタイル）も添える**（数字の大小だけでなく、位置の中でどこか）
5. 取材メモに貼れる `card: {type: duel, …}` の行と、語りに使える「条件の一言」を出す

**言ってはいけないこと**：出場時間が足りない側の数字で「〜が上」と言い切らない。**足りない回は、スタッツの節を置かず、
出せる数字（市場価値・年齢・経歴）で比べる**。
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

_spec = importlib.util.spec_from_file_location("fotmob_player", ROOT / "tools" / "fotmob_player.py")
fm = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fm)

MIN_MINUTES = 450                 # これ未満は比べない（約5試合。標本が小さい）
SMALL_SAMPLE = 900                # これ未満は比べるが「標本が小さい」と添える（約10試合）
# 比べる指標（FotMob の title → (日本語, 種類, 小さいほうが上か)）。種類: per90＝90分あたり、rate＝割合（そのまま）
METRICS: list[tuple[str, str, str, str, bool]] = [
    # 群, FotMob の title, 日本語, 種類, 小さいほうが上
    ("攻撃", "Goals", "得点", "per90", False),
    ("攻撃", "xG", "xG（ゴール期待値）", "per90", False),
    ("攻撃", "Shots", "シュート", "per90", False),
    ("攻撃", "Touches in opposition box", "相手ボックス内のタッチ", "per90", False),
    ("配球", "Chances created", "チャンス創出", "per90", False),
    ("配球", "xA", "xA（アシスト期待値）", "per90", False),
    ("配球", "Pass accuracy", "パス成功率", "rate", False),
    ("配球", "Line-breaking passes", "ラインを破るパス", "per90", False),
    ("運ぶ", "Dribbles", "ドリブル成功", "per90", False),
    ("運ぶ", "Touches", "ボールタッチ", "per90", False),
    ("守備", "Tackles", "タックル", "per90", False),
    ("守備", "Interceptions", "インターセプト", "per90", False),
    ("守備", "Recoveries", "ボール奪取", "per90", False),
    ("守備", "Duels won %", "デュエル勝率", "rate", False),
    ("守備", "Aerials won %", "空中戦勝率", "rate", False),
    ("守備", "Dribbled past", "かわされた回数", "per90", True),
]


def context(data: dict) -> dict:
    """比べる条件：大会・シーズン・出場時間・試合数・位置の群。取れなければ None。"""
    main = data.get("mainLeague") or {}
    stats = {s.get("title"): s.get("value") for s in (main.get("stats") or [])}
    group, _traits = fm.traits(data)
    return {
        "name": data.get("name"),
        "team": (data.get("primaryTeam") or {}).get("teamName"),
        "league": main.get("leagueName"),
        "season": main.get("season"),
        "minutes": _num(stats.get("Minutes played")),
        "matches": _num(stats.get("Matches")),
        "group": group,
        "has_section": bool(fm.season_stats(data)),
    }


def _num(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def conditions(ctx: list[dict], min_minutes: int = MIN_MINUTES,
               allow_season_gap: bool = False) -> tuple[list[str], list[str]]:
    """(条件の一言の一覧, 比べられない理由の一覧)。理由が空なら比べてよい。

    **シーズンが違う2人は比べない**（2026-10-15、三笘＝去年のシーズン1721分とサカ＝今季508分が「比べられる」と出た）。
    「同じ年齢で並べる」など、別のシーズンを並べること自体が主題の回だけ `allow_season_gap` で許す。"""
    notes, blockers = [], []
    names = [c["name"] or "?" for c in ctx]
    for c in ctx:
        if not c["has_section"]:
            blockers.append(f"{c['name']}: FotMob に今季の詳細スタッツがありません（出場時間が足りない）")
        elif c["minutes"] is None:
            blockers.append(f"{c['name']}: 出場時間が分かりません")
        elif c["minutes"] < min_minutes:
            blockers.append(f"{c['name']}: 出場時間が{int(c['minutes'])}分で、{min_minutes}分（約5試合）に届きません")
    leagues = {c["league"] for c in ctx if c["league"]}
    seasons = {c["season"] for c in ctx if c["season"]}
    groups = {c["group"] for c in ctx if c["group"]}
    if len(leagues) > 1:
        notes.append(f"大会が違います（{' / '.join(f'{c['name']}={c['league']}' for c in ctx)}）。リーグの強さが違う点を言う")
    if len(seasons) > 1:
        text = f"シーズンが違います（{' / '.join(f'{c['name']}={c['season']}' for c in ctx)}）"
        if allow_season_gap:
            notes.append(text + "。別のシーズンを並べること自体を主題にする回として出す")
        else:
            blockers.append(text + "。90分あたりは同じシーズンどうしでしか比べられない（今季の数字が無い側は、まだ出ていない）")
    if len(groups) > 1:
        blockers.append(f"位置の群が違います（{' / '.join(f'{c['name']}={c['group']}' for c in ctx)}）。パーセンタイルの物差しが違う")
    for c in ctx:
        if c["minutes"] and c["minutes"] < SMALL_SAMPLE:
            notes.append(f"{c['name']}: {int(c['minutes'])}分で標本が小さい。シーズンが進むと数字は動く（「いまの時点」と言う）")
    for c in ctx:
        if c["minutes"]:
            notes.append(f"{c['name']}: {c['team']}・{c['league']} {c['season']}・{int(c['matches'] or 0)}試合 {int(c['minutes'])}分")
    return notes, blockers


def metric_table(datas: list[dict]) -> list[dict]:
    """指標ごとの [A, B] の値（90分あたりか割合）とパーセンタイル。"""
    by_player = []
    for data in datas:
        by_player.append({s["title"]: s for s in fm.season_stats(data)})
    rows = []
    for group, title, ja, kind, lower in METRICS:
        cells = []
        for stats in by_player:
            s = stats.get(title)
            if not s:
                cells.append(None)
                continue
            value = s["per90"] if kind == "per90" else _num(s["value"])
            cells.append({"value": value, "pct": s.get("pct")})
        if all(cells):
            rows.append({"group": group, "title": title, "ja": ja, "kind": kind, "lower": lower, "cells": cells})
    return rows


def fmt(value, kind: str) -> str:
    if value is None:
        return "—"
    if kind == "rate":
        return f"{value:.0f}%"
    return f"{value:.2f}" if abs(value) < 1 else f"{value:.1f}"


def top_text(pct, lower: bool = False) -> str:
    """パーセンタイルを「上位○%」にする。FotMob のパーセンタイルは値の大きさの順位（高いほど大きい）なので、
    **小さいほうが上の項目（かわされた回数）は向きを逆にする**。1%未満は「上位1%以内」。"""
    if pct is None:
        return "—"
    top = pct if lower else 100 - pct
    return "上位1%以内" if top < 1 else f"上位{top:.0f}%"


def pick_rows(rows: list[dict], per_group: int = 2) -> list[dict]:
    """対面カードの行：群（攻撃・配球・運ぶ・守備）ごとに、同じ位置の中での差が大きい項目を2つずつ（計8行まで）。"""
    def gap(r):
        a, b = (c["pct"] for c in r["cells"])
        return abs((a or 0) - (b or 0))
    chosen = []
    for group in ("攻撃", "配球", "運ぶ", "守備"):
        part = sorted((r for r in rows if r["group"] == group), key=gap, reverse=True)[:per_group]
        chosen += sorted(part, key=lambda r: rows.index(r))
    return chosen[:8]


def duel_rows(rows: list[dict]) -> list[list[str]]:
    """duel カードの rows（[[項目, A, B], …]）。90分あたりは「/90」を付けず、項目名に出す。"""
    out = []
    for r in rows:
        label = r["ja"] + ("（90分あたり）" if r["kind"] == "per90" else "")
        out.append([label, fmt(r["cells"][0]["value"], r["kind"]), fmt(r["cells"][1]["value"], r["kind"])])
    return out


def pct_lines(names: list[str], rows: list[dict]) -> list[str]:
    """同じ位置の中での位置（パーセンタイル）で、2人の差が大きい項目を語りの材料として出す。"""
    out = []
    for r in rows:
        a, b = (c["pct"] for c in r["cells"])
        if a is None or b is None or abs(a - b) < 25:
            continue
        hi, lo = (0, 1) if a > b else (1, 0)
        up = (lambda i: top_text(r["cells"][i]["pct"], r["lower"]))
        best, worst = (hi, lo) if not r["lower"] else (lo, hi)
        out.append(f"{r['ja']}：{names[best]}は同じ位置の{up(best)}、{names[worst]}は{up(worst)}")
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("a")
    ap.add_argument("b")
    ap.add_argument("--names", nargs=2, default=None, help="日本語名を2つ（既定は FotMob の英語名）")
    ap.add_argument("--min", type=int, default=MIN_MINUTES, help="これ未満の出場時間は比べない（分）")
    ap.add_argument("--allow-season-gap", action="store_true",
                    help="シーズンが違っても比べる（「同じ年齢で並べる」など、別のシーズンを並べること自体が主題の回だけ）")
    ap.add_argument("--out", default="", help="控えの出力先（JSON）")
    args = ap.parse_args(argv)

    datas = [fm.load(args.a), fm.load(args.b)]
    ctx = [context(d) for d in datas]
    names = list(args.names) if args.names else [c["name"] for c in ctx]
    for c, n in zip(ctx, names):
        c["name"] = n
    notes, blockers = conditions(ctx, args.min, args.allow_season_gap)

    print("■ 条件")
    for n in notes:
        print("  -", n)
    if blockers:
        print("\n■ 比べられません（スタッツの節は置かない。出せる数字＝市場価値・年齢・経歴で比べる）")
        for b in blockers:
            print("  ×", b)
        result = {"ok": False, "context": ctx, "blockers": blockers, "notes": notes}
    else:
        rows = metric_table(datas)
        print(f"\n■ 90分あたりの数字（{len(rows)}項目）")
        for group in ("攻撃", "配球", "運ぶ", "守備"):
            part = [r for r in rows if r["group"] == group]
            if not part:
                continue
            print(f"  [{group}]")
            for r in part:
                a, b = r["cells"]
                print(f"    {r['ja']:<14} {names[0]} {fmt(a['value'], r['kind']):>7}（{top_text(a['pct'], r['lower'])}）"
                      f"   {names[1]} {fmt(b['value'], r['kind']):>7}（{top_text(b['pct'], r['lower'])}）")
        print("\n■ 同じ位置の中での差が大きい項目（語りの材料）")
        for line in pct_lines(names, rows):
            print("  -", line)
        print("\n■ 取材メモの card（対面カード）")
        card = {"type": "duel", "left": {"name": names[0]}, "right": {"name": names[1]},
                "rows": duel_rows(pick_rows(rows)),
                "lower": [r["ja"] + "（90分あたり）" for r in pick_rows(rows) if r["lower"]]}
        print("  " + json.dumps(card, ensure_ascii=False))
        result = {"ok": True, "context": ctx, "notes": notes, "rows": rows, "card": card}
    if args.out:
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out).write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"\n控え: {args.out}")
    return 0 if not blockers else 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
