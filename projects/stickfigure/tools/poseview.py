"""ポーズの見比べ: plan のコマを、世界座標のまま大きく並べて描く(地面・箱・足の位置の印つき)。
手付けのカット(keyshot)の確認用。カメラも合成も通さないので、姿勢・接地・物との接触だけを見られる。

使い方: python tools/poseview.py out/shot_heavy_box/plan.json 0.2 0.5 1.4 ... --out out/poses.png [--who A] [--span 2.6]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stickfig import fk  # noqa: E402


def draw(plan: dict, taus, who: str = "A", span: float = 2.6, ppu: int = 170, cols: int = 4) -> Image.Image:
    W, H = int(span * ppu), int(2.1 * ppu)
    rows = (len(taus) + cols - 1) // cols
    sheet = Image.new("RGB", (W * cols, H * rows), (250, 250, 250))
    try:
        font = ImageFont.truetype(r"C:\Windows\Fonts\meiryo.ttc", 18)
    except Exception:
        font = ImageFont.load_default()
    props = plan.get("scene", {}).get("fx", {}).get("props", [])
    a = plan["actors"][who]
    for i, tau in enumerate(taus):
        f = min(range(plan["n"]), key=lambda k: abs(plan["frames"][k]["tau"] - tau))
        p = plan["frames"][f]["actors"][who]
        ox, oy = (i % cols) * W, (i // cols) * H
        cx = p["root_x"]
        img = Image.new("RGB", (W, H), (250, 250, 250))       # パネルごとに描いて貼る(はみ出しを切る)
        d = ImageDraw.Draw(img)
        ox_, oy_ = ox, oy
        ox, oy = 0, 0

        def P(x, z):
            return ox + W / 2 + (x - cx) * ppu, oy + H - 0.25 * ppu - z * ppu

        d.rectangle([ox, oy, ox + W - 1, oy + H - 1], outline=(200, 200, 200))
        gx0, gy = P(cx - span, 0)
        d.line([ox, gy, ox + W, gy], fill=(120, 160, 90), width=3)
        for pr in props:                                      # 箱(その時刻の位置)
            ks = pr.get("keys") or []
            k = min(ks, key=lambda q: abs(q[0] - plan["frames"][f]["tau"])) if ks else None
            if k is None:
                continue
            s_ = pr.get("size", 0.6)
            x0, y1 = P(k[1] - s_ / 2, k[2])
            x1, y0 = P(k[1] + s_ / 2, k[2] + pr.get("h", s_))
            d.rectangle([x0, y0, x1, y1], outline=(170, 110, 50), width=3, fill=(235, 200, 150))
        sk = fk.skeleton(p, fk.sign_of(a, p), p["root_x"], a.get("scale", 1.0))
        col = tuple(int(255 * c * 0.8) for c in a["color"])
        for name, c in (("rear_leg", (150, 150, 150)), ("rear_arm", (150, 150, 150)), ("torso", col), ("front_leg", col), ("front_arm", col)):
            pts = [P(*q) for q in sk[name]]
            d.line(pts, fill=c, width=7, joint="curve")
        hx, hz = sk["head"]
        r = sk["head_r"] * ppu
        X, Y = P(hx, hz)
        d.ellipse([X - r, Y - r, X + r, Y + r], fill=col)
        for key, c in (("foot", (220, 40, 40)), ("rear_foot", (40, 40, 220))):
            X, Y = P(*sk[key])
            d.ellipse([X - 5, Y - 5, X + 5, Y + 5], fill=c)
        d.text((ox + 8, oy + 6), f"{plan['frames'][f]['tau']:.2f}s", fill=(40, 40, 40), font=font)
        sheet.paste(img, (ox_, oy_))
    return sheet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("plan")
    ap.add_argument("taus", nargs="+", type=float)
    ap.add_argument("--out", required=True)
    ap.add_argument("--who", default="A")
    ap.add_argument("--span", type=float, default=2.6)
    a = ap.parse_args()
    plan = json.load(open(a.plan, encoding="utf-8"))
    draw(plan, a.taus, a.who, a.span).save(a.out)
    print(a.out)


if __name__ == "__main__":
    main()
