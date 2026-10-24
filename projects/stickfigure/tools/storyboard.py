"""絵コンテのコマを描く(2026-10-22「いきなり動画ではなくて、絵コンテですり合わせ」)。

実際の振り付け(moves.py の場面)の焼いた姿勢から取るコマと、IK で手で組むコマ(空中コンボなど、まだ動作が無いもの)を、同じ画風で描く。
画風: 明るい下地・床の線・太い線に縁取り・命中の星・動きの矢印。時刻と台詞は画像に入れず、ページ側に書く。

使い方(python から):
    fig_from_scene(sc, "A", 1.50)            # 場面の焼いた姿勢から(戻り値: 描く人物の dict)
    fig_made("A", x=0, d=1, hz=0.5, lean=0.4, f_hand=(0.6, 1.2))   # IK で組む
    panel([figA, figB], path, hits=[(x, z)], arrows=[((x0, z0), (x1, z1))], ppu=150, cx=None, w=560, h=340)
"""
from __future__ import annotations

import math
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stickfig import fk, keyshot as ks  # noqa: E402

Pt = Tuple[float, float]
BG = (247, 244, 238)
FLOOR = (206, 196, 180)
INK = (38, 36, 44)
COLORS = dict(A=(0.5, 0.85, 0.3), B=(0.25, 0.55, 0.95), C=(0.62, 0.35, 0.85), D=(0.92, 0.32, 0.28))


def fig_from_scene(sc: dict, who: str, t: float, color: Optional[Sequence[float]] = None) -> dict:
    """場面(moves.build_bout の戻り)の焼いた姿勢から、時刻 t の人物を取る。"""
    keys = sc["keys"][who]
    a = sc["actors"][who]
    k = keys[min(len(keys) - 1, int(round(t * 30)))]
    pose = dict(ks.POSE0, **{n: float(v) for n, v in k.items() if n in ks.POSE0})
    return dict(pose=pose, x=a["base_x"] + k["dx"], sc=a.get("scale", 1.0), d=1 if k["dir"] > 0 else -1, color=color or a["color"], who=who)


def fig_made(who: str, x: float, d: int, hz: float = 0.8, lean: float = 0.12, rz: float = 0.0, roll: float = 0.0, ht: float = 0.0, scale: float = 1.0,
             f_hand=None, r_hand=None, f_foot=None, r_foot=None, ang: Optional[dict] = None, color=None) -> dict:
    """IK で姿勢を組む。f_hand・r_hand・f_foot・r_foot は世界の点 (x, z)。ang で角度を直接(fa, fe, ra, re, fl, fk, rl, rk)。"""
    pose = dict(ks.POSE0, hz=hz, lean=lean, rz=rz, roll=roll, ht=ht, dir=float(d))
    if ang:
        pose.update(ang)
    s = d
    for limb, tgt in (("f_hand", f_hand), ("r_hand", r_hand), ("f_foot", f_foot), ("r_foot", r_foot)):
        if tgt is None:
            continue
        # 世界の点を、体の寸法(scale 1)へ縮めて解く(keyshot.bake と同じ)
        t = (x + (tgt[0] - x) / scale, rz + (tgt[1] - rz) / scale)
        if limb.endswith("foot"):
            ks.solve_leg(pose, s, x, limb, t)
        else:
            ks.solve_limb(pose, s, x, limb, t)
    return dict(pose=pose, x=x, sc=scale, d=d, color=color or COLORS.get(who, (0.5, 0.5, 0.5)), who=who)


def _font(size: int):
    for p in (r"C:\Windows\Fonts\meiryo.ttc", r"C:\Windows\Fonts\YuGothM.ttc"):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return ImageFont.load_default()


def _star(d: ImageDraw.ImageDraw, c: Pt, r: float, fill, outline):
    pts = []
    for i in range(16):
        a = i * math.pi / 8
        rr = r if i % 2 == 0 else r * 0.48
        pts.append((c[0] + rr * math.cos(a), c[1] + rr * math.sin(a)))
    d.polygon(pts, fill=fill, outline=outline)


def _draw_fx(d: ImageDraw.ImageDraw, P, fx, u: float, S: int):
    """エフェクト。fx の要素は (種類, x, z, 大きさ[, 向き])。spark=火花(放射の短い線+芯)、dust=土煙(灰色の丸の塊)、shock=空中の衝撃の輪、
    smear=軌跡の三日月(向きは度。振った腕・脚の通り道)、glint=きらっと光る十字、guard=受けの火花(小さな輪+短い線)。"""
    for e in fx:
        kind, x, z, sz = e[0], e[1], e[2], e[3]
        c = P(x, z)
        r = sz * u
        if kind == "spark":
            for i in range(14):
                a = i * 2 * math.pi / 14 + 0.2
                r0, r1 = r * (0.45 if i % 2 else 0.35), r * (1.15 if i % 2 else 0.8)
                d.line([(c[0] + r0 * math.cos(a), c[1] + r0 * math.sin(a)), (c[0] + r1 * math.cos(a), c[1] + r1 * math.sin(a))], fill=(255, 196, 40) if i % 2 else (255, 240, 170), width=int(3.5 * S))
            d.ellipse([c[0] - r * 0.3, c[1] - r * 0.3, c[0] + r * 0.3, c[1] + r * 0.3], fill=(255, 250, 220), outline=(240, 150, 30), width=2 * S)
        elif kind == "dust":
            for k, (dx, dz, rr) in enumerate(((-0.9, 0.0, 0.5), (-0.3, 0.35, 0.62), (0.4, 0.15, 0.55), (1.0, 0.45, 0.42), (0.1, 0.8, 0.38), (1.5, 0.1, 0.3))):
                cc = (c[0] + dx * r * 0.5, c[1] - dz * r * 0.5)
                rr_ = rr * r * 0.5
                d.ellipse([cc[0] - rr_, cc[1] - rr_, cc[0] + rr_, cc[1] + rr_], fill=(214, 204, 188), outline=(168, 156, 138), width=2 * S)
        elif kind == "shock":
            for k, a_ in enumerate((1.0, 0.7)):
                rr_ = r * a_
                d.ellipse([c[0] - rr_, c[1] - rr_, c[0] + rr_, c[1] + rr_], outline=(255, 255, 255) if k else (240, 150, 40), width=int((6 - 2 * k) * S))
        elif kind == "smear":
            ang = e[4] if len(e) > 4 else 0
            for k, w_ in enumerate((14, 8, 3)):
                box = [c[0] - r, c[1] - r, c[0] + r, c[1] + r]
                d.arc(box, ang - 38 + k * 8, ang + 38 - k * 4, fill=(255, 255, 255) if k == 2 else ((160, 205, 255) if k == 1 else (110, 160, 235)), width=int(w_ * S))
        elif kind == "glint":
            for a in (0, math.pi / 2):
                d.line([(c[0] - r * math.cos(a), c[1] - r * math.sin(a)), (c[0] + r * math.cos(a), c[1] + r * math.sin(a))], fill=(255, 255, 255), width=int(5 * S))
            d.ellipse([c[0] - r * 0.22, c[1] - r * 0.22, c[0] + r * 0.22, c[1] + r * 0.22], fill=(255, 255, 255))
        elif kind == "guard":
            d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=(120, 190, 255), width=int(4 * S))
            for i in range(8):
                a = i * math.pi / 4 + 0.4
                d.line([(c[0] + r * 1.1 * math.cos(a), c[1] + r * 1.1 * math.sin(a)), (c[0] + r * 1.6 * math.cos(a), c[1] + r * 1.6 * math.sin(a))], fill=(120, 190, 255), width=int(3 * S))
        elif kind == "beam":                                  # 光線: (beam, x0, z0, 太さ, x1, z1, 色)。色の帯に白い芯
            x1, z1 = e[4], e[5]
            col = tuple(e[6]) if len(e) > 6 else (120, 230, 255)
            c1 = P(x1, z1)
            d.line([c, c1], fill=tuple(int(v * 0.6 + 255 * 0.4) for v in col), width=int(r * 2.4))
            d.line([c, c1], fill=col, width=int(r * 1.6))
            d.line([c, c1], fill=(255, 255, 255), width=int(r * 0.6))
            d.ellipse([c[0] - r * 1.3, c[1] - r * 1.3, c[0] + r * 1.3, c[1] + r * 1.3], fill=col)
            d.ellipse([c[0] - r * 0.7, c[1] - r * 0.7, c[0] + r * 0.7, c[1] + r * 0.7], fill=(255, 255, 255))
        elif kind == "orb":                                   # 気弾: (orb, x, z, 半径, 色)
            col = tuple(e[4]) if len(e) > 4 else (255, 190, 70)
            d.ellipse([c[0] - r * 1.4, c[1] - r * 1.4, c[0] + r * 1.4, c[1] + r * 1.4], fill=tuple(int(v * 0.5 + 255 * 0.5) for v in col))
            d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=col)
            d.ellipse([c[0] - r * 0.45, c[1] - r * 0.45, c[0] + r * 0.45, c[1] + r * 0.45], fill=(255, 255, 255))
        elif kind == "shield":                                # 気の盾: (shield, x, z, 半径)。縦長の光の円盤と網目
            d.ellipse([c[0] - r * 0.45, c[1] - r, c[0] + r * 0.45, c[1] + r], outline=(150, 240, 255), width=int(6 * S))
            for k in range(-2, 3):
                yy = c[1] + k * r * 0.35
                hw = r * 0.45 * math.sqrt(max(0.0, 1 - (k * 0.35) ** 2))
                d.line([(c[0] - hw, yy), (c[0] + hw, yy)], fill=(190, 250, 255), width=int(2 * S))


def _draw_back_fx(d: ImageDraw.ImageDraw, P, fx, u: float, S: int):
    """人物の後ろに描く効果。aura=気のオーラ(体を包む炎の形。(aura, x, 腰の高さ, 大きさ, 色))、pillar=光の柱(気を溜める。(pillar, x, 0, 幅, 色))。"""
    for e in fx:
        kind, x, z, sz = e[0], e[1], e[2], e[3]
        col = tuple(e[4]) if len(e) > 4 else (130, 255, 150)
        light = tuple(int(v * 0.45 + 255 * 0.55) for v in col)
        r = sz * u
        if kind == "aura":
            c = P(x, z)
            pts = []
            for i in range(24):                               # 上に伸びる炎の輪郭(とがりを交互に)
                a = math.pi / 2 + i * 2 * math.pi / 24
                rr = r * (1.25 if i % 2 == 0 else 0.95)
                up = 1.0 + 0.9 * max(0.0, -math.sin(a))       # 上側ほど長い
                pts.append((c[0] + rr * 0.62 * math.cos(a), c[1] + rr * math.sin(a) * up))
            d.polygon(pts, fill=light, outline=col, width=int(4 * S))
        elif kind == "pillar":
            x0, yb = P(x - sz / 2, 0.0)
            x1, _ = P(x + sz / 2, 0.0)
            d.rectangle([x0, 0, x1, yb], fill=light)
            mx = (x0 + x1) / 2
            d.rectangle([mx - (x1 - x0) * 0.18, 0, mx + (x1 - x0) * 0.18, yb], fill=(255, 255, 255))
            d.ellipse([x0 - (x1 - x0) * 0.4, yb - (x1 - x0) * 0.25, x1 + (x1 - x0) * 0.4, yb + (x1 - x0) * 0.25], outline=col, width=int(5 * S))


def panel(figs: List[dict], path: Path, hits: Sequence[Pt] = (), arrows: Sequence[Tuple[Pt, Pt]] = (), rings: Sequence[Tuple[float, float, float]] = (),
          cracks: Sequence[Tuple[float, float]] = (), debris: Sequence[Tuple[float, float, float]] = (), speed: Sequence[Tuple[float, float, float, float]] = (),
          trails: Sequence[Sequence[Pt]] = (), posts: Sequence[Tuple[float, float, float]] = (), ppu: float = 150.0, cx: Optional[float] = None,
          w: int = 560, h: int = 340, ground: float = 0.86, ghosts: Sequence[dict] = (), label: str = "", scale_ss: int = 2, auto: bool = True, ppu_max: float = 150.0, fx: Sequence[tuple] = (), flash: float = 0.0, back_fx: Sequence[tuple] = ()) -> Path:
    """1 コマを描く。ghosts: 薄く重ねる前の姿勢(動きの軌跡)。ground: 地面の線の高さ(上からの割合)。"""
    S = scale_ss
    W, H = w * S, h * S
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    if auto:                                                  # 全員(と軌跡の人)の体が枠に収まるよう、拡大率と中心を決める。地面の線は固定
        pts = []
        for f in list(figs) + list(ghosts):
            sk = fk.skeleton(f["pose"], f["d"], f["x"], f["sc"])
            for name in ("torso", "front_arm", "rear_arm", "front_leg", "rear_leg"):
                pts += sk[name]
            pts += [(sk["head"][0] - sk["head_r"], sk["head"][1] + sk["head_r"]), (sk["head"][0] + sk["head_r"], sk["head"][1] + sk["head_r"])]
        for (a_, b_) in arrows:
            pts += [a_, b_]
        for hp in hits:
            pts.append(hp)
        x_lo, x_hi = min(p[0] for p in pts), max(p[0] for p in pts)
        for (rx, rz_, rr) in rings:
            pts += [(rx - rr, rz_), (rx + rr, rz_)]
        for (bx, bz, bs) in debris:
            pts.append((bx, bz))
        for (px_, pw_, ph_) in posts:
            pts += [(px_ - pw_ / 2, 0.0), (px_ + pw_ / 2, ph_)]
        for tr in trails:
            pts += list(tr)
        z_hi = max(max(p[1] for p in pts), 1.9)
        ppu = min(ppu_max, (w * 0.84) / max(x_hi - x_lo, 1.0), (h * ground * 0.90) / z_hi)
        cx = (x_lo + x_hi) / 2
    xs = [f["x"] for f in figs]
    cx = (min(xs) + max(xs)) / 2 if cx is None else cx
    gy = H * ground

    def P(x, z):
        return (W / 2 + (x - cx) * ppu * S, gy - z * ppu * S)

    d.rectangle([0, gy, W, H], fill=FLOOR)
    d.line([0, gy, W, gy], fill=(150, 140, 124), width=3 * S)

    def draw_fig(f: dict, alpha: float = 1.0):
        sk = fk.skeleton(f["pose"], f["d"], f["x"], f["sc"])
        col = tuple(int(255 * c * 0.85) for c in f["color"])
        edge = tuple(int(c * 0.45) for c in col)
        mix = lambda c: tuple(int(c[i] * alpha + BG[i] * (1 - alpha)) for i in range(3))
        dim = tuple(int(c * 0.7 + 255 * 0.3) for c in col)
        lw = int(max(6, 0.07 * ppu) * S)
        for name, c in (("rear_leg", dim), ("rear_arm", dim), ("torso", col), ("front_leg", col), ("front_arm", col)):
            pts = [P(*q) for q in sk[name]]
            d.line(pts, fill=mix(edge), width=lw + 3 * S, joint="curve")
            d.line(pts, fill=mix(c), width=lw, joint="curve")
        tipc = None                                   # 手先は丸い握りこぶし・足先も丸い先(靴は付けない。暗い色。Blender の描画と同じ形)
        for name, kind, c0 in (("rear_arm", "hand", dim), ("front_arm", "hand", col), ("rear_leg", "foot", dim), ("front_leg", "foot", col)):
            ex, ez = sk[name][-1]
            X, Y = P(ex, ez)
            if kind == "hand":
                rr = 0.055 * f["sc"] * ppu * S
                d.ellipse([X - rr, Y - rr, X + rr, Y + rr], fill=mix(c0))
            else:
                rr = 0.05 * f["sc"] * ppu * S
                Y -= 0.025 * f["sc"] * ppu * S
                d.ellipse([X - rr, Y - rr, X + rr, Y + rr], fill=mix(c0))
        hx, hz = sk["head"]
        r = sk["head_r"] * ppu * S
        X, Y = P(hx, hz)
        d.ellipse([X - r - 2 * S, Y - r - 2 * S, X + r + 2 * S, Y + r + 2 * S], fill=mix(edge))
        d.ellipse([X - r, Y - r, X + r, Y + r], fill=mix(col))

    _draw_back_fx(d, P, back_fx, ppu * S, S)                  # オーラ・光の柱(人物の後ろ)
    for i, g in enumerate(ghosts):                            # 軌跡の残像: 古いほど薄い
        draw_fig(g, 0.16 + 0.26 * (i + 1) / max(1, len(ghosts)))
    for (px_, pw_, ph_) in posts:                             # 柱(木): 地面に立つ長方形
        x0_, y0_ = P(px_ - pw_ / 2, ph_)
        x1_, y1_ = P(px_ + pw_ / 2, 0.0)
        d.rectangle([x0_, y0_, x1_, y1_], fill=(168, 126, 80), outline=(92, 64, 36), width=2 * S)
    for tr in trails:                                         # 手足・体の軌跡(点線の弧)
        pts = [P(*q) for q in tr]
        for a_, b_ in zip(pts[::2], pts[1::2]):
            d.line([a_, b_], fill=(230, 90, 60), width=3 * S)
    for (x0, z0, x1, z1) in speed:                            # 速さの線
        d.line([P(x0, z0), P(x1, z1)], fill=(140, 150, 175), width=2 * S)
    for (rx, rz_, rr) in rings:                               # 衝撃波の輪(地面に寝た楕円を重ねる)
        cxp, cyp = P(rx, rz_)
        for k, a_ in enumerate((1.0, 0.62, 0.34)):
            r_ = rr * (1 - 0.22 * k) * ppu * S
            d.ellipse([cxp - r_, cyp - r_ * 0.28, cxp + r_, cyp + r_ * 0.28], outline=(228, 120, 40), width=int((5 - k) * S))
    for (cxz, cz) in cracks:                                  # 地面の割れ目
        pts = [P(cxz, 0.0)]
        x_, z_ = cxz, 0.0
        for j in range(5):
            x_ += 0.12 * (1 if j % 2 == 0 else -0.6) * (1 + j * 0.2)
            z_ = -0.06 * (j + 1)
            pts.append(P(x_, z_))
        d.line(pts, fill=(96, 84, 70), width=3 * S)
    for (bx, bz, bs) in debris:                               # 破片
        c = P(bx, bz)
        r_ = bs * ppu * S
        d.polygon([(c[0] - r_, c[1]), (c[0], c[1] - r_ * 0.8), (c[0] + r_, c[1] + r_ * 0.3), (c[0] - r_ * 0.2, c[1] + r_)], fill=(150, 112, 70), outline=(80, 56, 30))
    for f in figs:
        draw_fig(f)
    _draw_fx(d, P, fx, ppu * S, S)                            # エフェクト(人物の上に描く)
    if flash > 0:                                             # 大技の 1 コマの閃光(画面全体を白く)
        img.paste(Image.new("RGB", (W, H), (255, 255, 255)), (0, 0), Image.new("L", (W, H), int(255 * flash)))
        d = ImageDraw.Draw(img)
    for (a, b) in arrows:
        pa, pb = P(*a), P(*b)
        d.line([pa, pb], fill=(230, 90, 60), width=4 * S)
        ang = math.atan2(pb[1] - pa[1], pb[0] - pa[0])
        hl = 14 * S
        d.polygon([pb, (pb[0] - hl * math.cos(ang - 0.45), pb[1] - hl * math.sin(ang - 0.45)), (pb[0] - hl * math.cos(ang + 0.45), pb[1] - hl * math.sin(ang + 0.45))], fill=(230, 90, 60))
    for hp in hits:
        _star(d, P(*hp), 26 * S, (255, 214, 64), (214, 120, 20))
    if label:
        d.text((10 * S, 8 * S), label, fill=INK, font=_font(15 * S))
    out = img.resize((w, h), Image.LANCZOS)
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path)
    return path
