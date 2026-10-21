"""地面より下に出た部位を時刻ごとに出す(qa の ground に落ちたときの切り分け)。

使い方: python tools/lowparts.py tools/shots/bout_r1.py [--every 6]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stickfig import plan as pm, qa  # noqa: E402
from stickfig.episode import load_shot  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("shot")
    ap.add_argument("--every", type=int, default=6)
    ap.add_argument("--tol", type=float, default=0.06)
    a = ap.parse_args()
    pl = pm.build_plan(load_shot(a.shot))
    n = 0
    for f in range(pl["n"]):
        for who in pl["actors"]:
            sk = qa._skel(pl, who, f)
            parts = {k: min(p[1] for p in sk[k]) for k in ("front_leg", "rear_leg", "front_arm", "rear_arm", "torso")}
            parts["head"] = sk["head"][1] - sk["head_r"]
            low = {k: round(v, 2) for k, v in parts.items() if v < -a.tol}
            if low:
                if n % a.every == 0:
                    fr = pl["frames"][f]["actors"][who]
                    print(f, round(pl["frames"][f]["tau"], 2), who, low, "rz", round(fr["rz"], 2), "roll", round(fr["roll"], 2), "hz", round(fr["hz"], 2))
                n += 1
    print("合計", n)


if __name__ == "__main__":
    main()
