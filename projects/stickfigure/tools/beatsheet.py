"""手付けの殴り合いの「当たりごと」の点検(2026-10-22、moves.py で作った場面用)。

当たりの時刻ごとに、打つ側の手足の先と当て先の距離・2 人の頭の距離を出し(頭が 0.40 未満なら重なって見える)、
当たりの前後の姿勢を並べた画像を out/<名前>/beats_N.png に書く。

使い方: python tools/beatsheet.py tools/shots/duel_a.py [--per 3]
shot のスクリプトは build() が (場面, IK 残差, beats) を返すこと。
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stickfig import bout, plan as pm  # noqa: E402
import poseview  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("shot")
    ap.add_argument("--per", type=int, default=3)
    ap.add_argument("--span", type=float, default=3.4)
    a = ap.parse_args()
    sp = importlib.util.spec_from_file_location("_shot", a.shot)
    mod = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(mod)
    sc, rep, beats = mod.build()
    out = Path("out") / getattr(mod, "NAME", "shot")
    out.mkdir(parents=True, exist_ok=True)
    pl = pm.build_plan(sc)
    pm.save_plan(pl, out / "plan.json")
    hits = {round(h["tau"], 3): h for h in sc["hits"]}
    print("時刻  打つ側→受ける側  技/結果           先端と当て先  頭の距離")
    for b in beats:
        t = b["t"]
        keys = sc["keys"]
        A, B = sc["actors"][b["by"]], sc["actors"][b["to"]]
        sa, sb = bout.skel(keys[b["by"]], A, t), bout.skel(keys[b["to"]], B, t)
        h = hits.get(round(t, 3))
        limb = {"st": "front_arm", "rst": "rear_arm", "lst": "front_leg", "rlst": "rear_leg"}[b["limb"]]
        tip = sa[limb][-1]
        err = math.hypot(tip[0] - h["pos"][0], tip[1] - h["pos"][1]) if h else float("nan")
        hd = math.hypot(sa["head"][0] - sb["head"][0], sa["head"][1] - sb["head"][1])
        flag = ("  ← 先端が届いていない" if err > 0.12 and not b["miss"] else "") + ("  ← 頭が重なる" if hd < 0.40 else "")
        print(f"{t:5.2f}  {b['by']}→{b['to']}  {limb:9s} {'空振り' if b['miss'] else ('受け' if b['absorb'] else '命中'):4s}  {err:5.2f}  {hd:5.2f}{flag}")
    for i in range(0, len(beats), a.per):
        taus = []
        for b in beats[i:i + a.per]:
            taus += [b["t"] - 0.12, b["t"], b["t"] + 0.12, b["t"] + 0.30]
        img = poseview.draw(pl, [max(0.0, min(t, pl["frames"][-1]["tau"])) for t in taus], who="all", span=a.span, cols=4)
        p = out / f"beats_{i // a.per + 1}.png"
        img.save(p)
        print(p)


if __name__ == "__main__":
    main()
