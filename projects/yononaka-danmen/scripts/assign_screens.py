# -*- coding: utf-8 -*-
"""台本の行に `screen:` と `cast:` を割り当てる。

`build_screens.py` が作る画面を、その節の台詞に配る。

**ただ等分すると、画面と話がずれる。** 2026-10-09 に実際に起きた：割増の表が
出ているのに、台詞はごま油の話をしていた。だから図の側に

    - kind: bars
      from: 逆に、増える場合もあるんですか。   # この台詞から、この図に切り替える

と書けるようにした。`from:` は台詞の一部でよい（最初に当たった行を使う）。
書かなかった図は、前後の `from:` のあいだを**枚数の比で**分ける。

図の中の画面（項目が1つずつ増える列）は、その図の範囲を等分する。
**中扉は最初の1行だけ。** 掴みなので長く見せない。

    python scripts/assign_screens.py scripts/cartel.yaml
    python scripts/assign_screens.py scripts/cartel.yaml --clear

**何度でも掛けられる。** 掛ける前に既存の `screen:` `cast:` を落とす。
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

SPEAKER = re.compile(r"^\s+- (語り|聞き)(\([^)]+\))?: (.*)$")
SCREEN = re.compile(r"^\s+- screen: \S+\s*$")
CAST = re.compile(r"^\s+- cast: \S+\s*$")
SEC_ID = re.compile(r'^  - id: "(\d+)"\s*$')


def figures_of(sec: dict) -> list[dict]:
    return [f for f in [sec.get("figure")] + list(sec.get("more") or []) if f]


def sheets(fig: dict) -> int:
    """その図が何枚になるか。項目が複数あれば1つずつ増やすので項目数。

    `step: false` の図は1枚（全部の行を一度に出す）。台詞で何行かをまとめて読む所に使う
    （「前田道路、大成ロテック、鹿島道路…」を1行で言うのに、6段の図を1段ずつ出すと台詞が足りない）。
    """
    items = fig.get("items")
    if fig.get("step") is False:
        return 1
    return len(items) if isinstance(items, list) and len(items) > 1 else 1


def starts_of(figs: list[dict], texts: list[str]) -> list[int]:
    """図ごとの開始台詞。`from:` が無いものは、前後のあいだを枚数の比で分ける。"""
    n = len(figs)
    at: list[int | None] = []
    for f in figs:
        key = str(f.get("from", "")).strip()
        hit = next((j for j, t in enumerate(texts) if key and key in t), None)
        at.append(hit)
    # 1行目は中扉の場所。ただし最初の図に `from:` があれば、そこまで中扉を出す
    if at[0] is None:
        at[0] = 1 if len(texts) > 1 else 0
    at[0] = max(at[0], 1 if len(texts) > 1 else 0)
    # 未指定を、確定している左右のあいだで埋める
    i = 0
    while i < n:
        if at[i] is not None:
            i += 1
            continue
        lo = i - 1
        hi = next((j for j in range(i, n) if at[j] is not None), n)
        left = at[lo] + 1 if lo >= 0 and at[lo] is not None else 1
        right = at[hi] if hi < n else len(texts)
        gap = [sheets(figs[j]) for j in range(i, hi)]
        room, done = max(right - left, 0), 0
        for k, j in enumerate(range(i, hi)):
            at[j] = left + (round(room * done / sum(gap)) if sum(gap) else 0)
            done += gap[k]
        i = hi
    # 後ろの図が前に来ないように均す
    for j in range(1, n):
        at[j] = max(at[j], at[j - 1] + 1)
    return [min(x, max(len(texts) - 1, 0)) for x in at]


def section_plan(sec: dict, texts: list[str], head: int = 0) -> dict[int, str]:
    """{台詞の番号: 画面の名前}。`head` は節の前に置く画面の数（冒頭の掴み）。"""
    sid = str(sec["id"])
    figs = figures_of(sec)
    out: dict[int, str] = {}
    for i in range(head):                               # 冒頭の掴み。1行に1枚
        out[i] = "s{}{:02d}".format(sid, i + 1)
    out[head] = "s{}{:02d}".format(sid, head + 1)       # 中扉
    if not figs:
        return out
    starts = starts_of(figs[:], texts[head:])
    starts = [x + head for x in starts]
    k = head + 2                                         # 画面の通番（中扉の次から）
    for i, fig in enumerate(figs):
        lo = starts[i]
        hi = starts[i + 1] if i + 1 < len(figs) else len(texts)
        n = sheets(fig)
        room = max(hi - lo, 1)
        # **行が出るのは、台詞でその行の名前が出たところ。** 等分すると、話していない行に印が付き、
        # 会話と画面が合わなかった（2026-10-10 ユーザー指摘）。名前が台詞に無い行だけ等分で埋める
        items = fig.get("items") if isinstance(fig.get("items"), list) and n > 1 else None
        spots = []
        for m in range(n):
            hit = None
            if items:
                it = items[m]
                keys = [str(it.get("from", "")).strip(), str(it.get("label", "")).strip()]
                for key in [x for x in keys if len(x) >= 2]:
                    lo2 = spots[-1] + 1 if spots and spots[-1] is not None else lo
                    hit = next((j for j in range(max(lo2, lo), hi) if key in texts[j]), None)
                    if hit is not None:
                        break
            spots.append(hit)
        if spots:
            spots[0] = lo                       # 1行目は図が出るところ（`from:` の台詞）で出す
        for m in range(n):                      # 見つからない行は、前後のあいだを等分
            if spots[m] is None:
                prev = spots[m - 1]
                nxt = next((spots[j] for j in range(m + 1, n) if spots[j] is not None), hi)
                run = 1
                while m + run < n and spots[m + run] is None:
                    run += 1
                spots[m] = prev + max(1, round((nxt - prev) / (run + 1)))
        for m in range(1, n):
            spots[m] = max(spots[m], spots[m - 1] + 1)
        for m in range(n):
            at = min(spots[m], len(texts) - 1)
            out[at] = "s{}{:02d}".format(sid, k + m)
        k += n
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="台本の行に screen: と cast: を割り当てる")
    ap.add_argument("script")
    ap.add_argument("--clear", action="store_true", help="割り当てを消すだけ")
    a = ap.parse_args()

    p = Path(a.script)
    doc = yaml.safe_load(p.read_text(encoding="utf-8"))
    secs = {str(s["id"]): s for s in doc["sections"]}

    src = [ln for ln in p.read_text(encoding="utf-8").splitlines()
           if not SCREEN.match(ln) and not CAST.match(ln)]
    if a.clear:
        p.write_text("\n".join(src) + "\n", encoding="utf-8")
        print("screen: と cast: の行を消しました")
        return 0

    sid, spots, says = None, {}, {}
    for i, ln in enumerate(src):
        m = SEC_ID.match(ln)
        if m:
            sid = m.group(1)
            spots[sid], says[sid] = [], []
        elif sid and SPEAKER.match(ln):
            spots[sid].append(i)
            says[sid].append(SPEAKER.match(ln).group(3))

    plan, rows, lost = {}, [], 0
    for s, idxs in spots.items():
        head = 2 if s == "00" and doc.get("hook") else 0
        pl = section_plan(secs[s], says[s], head)
        for at, name in pl.items():
            plan[idxs[at]] = name
        n = head + 1 + sum(sheets(f) for f in figures_of(secs[s]))
        lost += n - len(pl)
        rows.append("  {} 台詞{:>3}行 / 画面{:>3}枚 → {:>3}か所{}".format(
            s, len(idxs), n, len(pl), "  ← {}枚が余る".format(n - len(pl)) if n > len(pl) else ""))

    # **節の頭で立ち絵を出す。** ただし冒頭の掴みは全画面なので、人は出さない
    first, none_at = {}, set()
    for sid2, idxs in spots.items():
        if not idxs:
            continue
        head = 2 if sid2 == "00" and doc.get("hook") else 0
        if head:
            none_at.add(idxs[0])
        first[idxs[head]] = "auto"
    out = []
    for i, ln in enumerate(src):
        indent = " " * (len(ln) - len(ln.lstrip()))
        if i in plan:
            out.append("{}- screen: {}".format(indent, plan[i]))
        if i in none_at:
            out.append("{}- cast: なし".format(indent))
        if i in first:
            # **`cast:` が無いと movie.py は立ち絵を1人も重ねない**（2026-10-09）
            out.append("{}- cast: {}".format(indent, first[i]))
        out.append(ln)
    p.write_text("\n".join(out) + "\n", encoding="utf-8")

    print("■ 画面を割り当てました")
    print("\n".join(rows))
    print("  合計 {} か所{}".format(len(plan), "（{}枚が出ません）".format(lost) if lost else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
