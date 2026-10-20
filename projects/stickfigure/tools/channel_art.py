"""チャンネルのアイコン・バナー(とサムネの人物)を、plan.json の骨格から高解像度で描く。

動画のコマを切り出すと 300px 程度で甘い。骨格(fk.skeleton)を好きな px/単位で線と円に描き直せば、
2D の見た目(太い線・丸い頭・濃い手足)のまま何 px でも出せる。

使い方:
  python tools/channel_art.py pose out/fight_two_on_one/plan.json 286 A --ppu 320 --out out/channel/a.png
  python tools/channel_art.py icon  --out out/channel/icon.png  (既定: 一太刀の振り抜き)
  python tools/channel_art.py banner "棒人間ストーリー" "剣と拳と必殺技。棒人間の2Dアニメバトル" --out out/channel/banner.png
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stickfig import fk  # noqa: E402

NAVY = (22, 26, 52)
FONTS = [r"C:\Windows\Fonts\YuGothB.ttc", r"C:\Windows\Fonts\meiryob.ttc", r"C:\Windows\Fonts\msgothic.ttc"]


def _font(size: int) -> ImageFont.FreeTypeFont:
    for fp in FONTS:
        if os.path.exists(fp):
            return ImageFont.truetype(fp, size)
    return ImageFont.load_default()


def draw_pose(plan_path: str, frame: int, who: str, ppu: float = 300.0, pad: float = 0.35) -> Image.Image:
    """plan の frame 番目の who を、1 単位 = ppu px で透過画像に描く。"""
    plan = json.load(open(plan_path, encoding="utf-8"))
    a = plan["actors"][who]
    p = plan["frames"][frame]["actors"][who]
    s = 1 if a.get("facing", 1) >= 0 else -1
    sc = float(a.get("scale", 1.0))
    sk = fk.skeleton(p, s, 0.0, sc)
    col = tuple(int(255 * c) for c in a.get("color", [0.5, 0.8, 0.3]))
    dark = (70, 70, 80)
    pts = [q for ln in fk.body_lines(sk) for q in ln] + [sk["head"]]
    if a.get("weapon") and "sword" in sk:
        pts += list(sk["sword"])
    xs, zs = [q[0] for q in pts], [q[1] for q in pts]
    r_head = float(sk["head_r"])
    x0, x1 = min(xs) - r_head - pad, max(xs) + r_head + pad
    z0, z1 = min(zs) - pad, max(zs) + r_head + pad
    W, H = int((x1 - x0) * ppu), int((z1 - z0) * ppu)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    def P(q):
        return ((q[0] - x0) * ppu, (z1 - q[1]) * ppu)

    w_line = max(3, int(0.11 * sc * ppu))
    w_edge = w_line + max(2, int(0.025 * ppu))

    def poly(ln, color, width):
        pp = [P(q) for q in ln]
        for q1, q2 in zip(pp, pp[1:]):
            d.line([q1, q2], fill=color, width=width)
        for q in pp:
            d.ellipse([q[0] - width / 2, q[1] - width / 2, q[0] + width / 2, q[1] + width / 2], fill=color)

    lines = fk.body_lines(sk)
    for ln in lines:                       # 縁(少し濃い)
        poly(ln, (int(col[0] * 0.55), int(col[1] * 0.55), int(col[2] * 0.55)), w_edge)
    hx, hz = P(sk["head"])
    rr = r_head * ppu
    d.ellipse([hx - rr - w_edge / 2, hz - rr - w_edge / 2, hx + rr + w_edge / 2, hz + rr + w_edge / 2], fill=(int(col[0] * 0.55), int(col[1] * 0.55), int(col[2] * 0.55)))
    for ln in lines:
        poly(ln, col, w_line)
    d.ellipse([hx - rr, hz - rr, hx + rr, hz + rr], fill=col)
    for ln in lines[1:]:                   # 手先・足先は濃い色(手袋・靴)
        poly(ln[-2:], dark, w_line) if len(ln) >= 2 else None
        tip = ln[-1]
        mid = ((ln[-2][0] + tip[0]) / 2, (ln[-2][1] + tip[1]) / 2)
        poly([mid, tip], dark, w_line)
    if a.get("weapon") and "sword" in sk:
        q0, q1 = P(sk["sword"][0]), P(sk["sword"][1])
        glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        g = ImageDraw.Draw(glow)
        g.line([q0, q1], fill=(120, 230, 255, 160), width=w_line * 2)
        im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(w_line)))
        d = ImageDraw.Draw(im)
        d.line([q0, q1], fill=(120, 230, 255), width=max(3, int(w_line * 0.55)))
        d.line([q0, q1], fill=(235, 250, 255), width=max(2, int(w_line * 0.22)))
    return im


def icon(fig: Image.Image, path: str, size: int = 800) -> None:
    im = Image.new("RGBA", (size, size), NAVY)
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([size * 0.15, size * 0.15, size * 0.85, size * 0.85], fill=(70, 200, 255, 80))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(size * 0.08)))
    h = int(size * 0.74)
    w = int(fig.size[0] * h / fig.size[1])
    if w > size * 0.86:
        w = int(size * 0.86)
        h = int(fig.size[1] * w / fig.size[0])
    im.alpha_composite(fig.resize((w, h), Image.LANCZOS), ((size - w) // 2, (size - h) // 2 + int(size * 0.02)))
    im.convert("RGB").save(path)


def banner(figs: list, title: str, sub: str, path: str) -> None:
    """2560x1440。字は中央の安全域(1546x423)に、人物は安全域の外側(PC・TV で見える所)に置く。"""
    W, H = 2560, 1440
    im = Image.new("RGBA", (W, H), NAVY)
    d = ImageDraw.Draw(im)
    for i in range(-400, W + 400, 160):
        d.line([i, 0, i - 300, H], fill=(30, 36, 70), width=40)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([W // 2 - 700, H // 2 - 300, W // 2 + 700, H // 2 + 300], fill=(70, 200, 255, 60))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(120)))
    sx, sy = (W - 1546) // 2, (H - 423) // 2
    h = 520
    for k, fg in enumerate(figs):
        w = int(fg.size[0] * h / fg.size[1])
        x = sx - w + 170 if k == 0 else sx + 1546 - 170                                   # 安全域の縁(字の無い所)に少し掛ける: 外に置くと端で切れた
        im.alpha_composite(fg.resize((w, h), Image.LANCZOS), (x, sy + 423 - h + 40))
    d = ImageDraw.Draw(im)
    F, F2 = _font(170), _font(64)
    tw = d.textlength(title, font=F)
    d.text(((W - tw) / 2 + 7, sy + 60 + 7), title, font=F, fill=(0, 0, 0, 170))
    d.text(((W - tw) / 2, sy + 60), title, font=F, fill=(255, 255, 255))
    tw2 = d.textlength(sub, font=F2)
    d.text(((W - tw2) / 2, sy + 290), sub, font=F2, fill=(170, 230, 255))
    im.convert("RGB").save(path)


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("pose"); p.add_argument("plan"); p.add_argument("frame", type=int); p.add_argument("who"); p.add_argument("--ppu", type=float, default=300); p.add_argument("--out", required=True)
    p = sub.add_parser("icon"); p.add_argument("--plan", default="out/fight_two_on_one/plan.json"); p.add_argument("--frame", type=int, default=286); p.add_argument("--who", default="A"); p.add_argument("--out", required=True)
    p = sub.add_parser("banner"); p.add_argument("title"); p.add_argument("sub"); p.add_argument("--left", default="out/fight_two_on_one/plan.json:286:A"); p.add_argument("--right", default="out/fight_barrier/plan.json:38:B"); p.add_argument("--out", required=True)
    a = ap.parse_args()
    if a.cmd == "pose":
        draw_pose(a.plan, a.frame, a.who, a.ppu).save(a.out)
    elif a.cmd == "icon":
        icon(draw_pose(a.plan, a.frame, a.who, 400), a.out)
    else:
        figs = []
        for spec in (a.left, a.right):
            pl, fr, who = spec.rsplit(":", 2)
            figs.append(draw_pose(pl, int(fr), who, 400))
        banner(figs, a.title, a.sub, a.out)
    print(a.out)


if __name__ == "__main__":
    main()
