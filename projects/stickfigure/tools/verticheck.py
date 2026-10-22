"""縦(9:16)に切り出したとき、戦う 2 人が枠に収まっているかを、plan だけで数える(Blender 不要・数十秒)。

縦の切り出しは横の 1/3 の幅(405/1280 画素)。2 人のどちらかが枠から出たコマの割合と、最悪の時刻を出す。
使い方: python tools/verticheck.py tools/shots/kachinuki2_red.py [--zoom 1.7]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stickfig import compose, episode, plan as pm  # noqa: E402
from stickfig.compose import P3, W, H  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("shot")
    ap.add_argument("--zoom", type=float, default=None, help="vertical_zoom を上書きして試す")
    ap.add_argument("--margin", type=float, default=30.0, help="枠の端からこの画素以内は、はみ出し扱い")
    a = ap.parse_args()
    sc = episode.load_shot(a.shot)
    vz = a.zoom if a.zoom is not None else sc.get("vertical_zoom")
    sc["output"] = {"aspect": "vertical"}
    if vz:
        sc["cam_zoom"] = float(sc.get("cam_zoom", 1.0)) * float(vz)
        sc["output"]["crop"] = "camera"
    pl = pm.build_plan(sc)
    cw = int(H * 9 / 16)
    xs = compose.crop_centers(pl, cw)
    names = list(pl["actors"])[:2]
    out, worst = 0, (0.0, 0)
    for f, fr in enumerate(pl["frames"]):
        px = [P3(fr["cam"], fr["actors"][w]["root_x"], 0.0, 0.95)[0] for w in names]
        lo, hi = xs[f] - cw / 2 + a.margin, xs[f] + cw / 2 - a.margin
        bad = [p for p in px if not (lo <= p <= hi)]
        if bad:
            out += 1
            over = max(max(lo - p, p - hi) for p in bad)
            if over > worst[0]:
                worst = (over, f)
    n = len(pl["frames"])
    print(f"{Path(a.shot).stem}: 2人のどちらかが枠の外 {out}/{n} コマ({100 * out / n:.0f}%)、最悪 {worst[0]:.0f} 画素(時刻 {worst[1] / 30:.2f} 秒)  vertical_zoom={vz}")


if __name__ == "__main__":
    main()
