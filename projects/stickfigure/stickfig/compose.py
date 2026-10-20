"""合成: コードで描く背景・壁・ひび・砂ぼこり・残像・衝撃のコマ・放射線・流線の上に、Blender の透過の人物を重ねる。

入力: plan.json と、Blender が書き出した f_####.png(RGBA)。出力: 連番 PNG と mp4。
"""
from __future__ import annotations

import math
import random
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

from PIL import Image, ImageDraw, ImageFilter

from . import anime, camera, captions, fk, look

W, H, SS = 1280, 720, 2
GROUND_Y = 560


def _rng_data(seed: int = 9):
    r = random.Random(seed)
    rays = [(r.uniform(0, 2 * math.pi), r.uniform(0.6, 1.0), r.uniform(2.0, 5.0)) for _ in range(60)]
    crack_wall = []
    for _ in range(9):
        a = r.uniform(-1.2, 1.2)
        pts, x, z = [], 0.0, 0.0
        for _ in range(7):
            a = max(-1.3, min(1.3, a + r.uniform(-0.5, 0.5)))
            x += math.cos(a) * r.uniform(0.18, 0.4)
            z += math.sin(a) * r.uniform(0.18, 0.4)
            pts.append((x, z))
        crack_wall.append(pts)
    crack_ground = []
    for sgn in (-1, 1):
        for _ in range(4):
            x, pts = 0.0, []
            for _ in range(6):
                x += sgn * r.uniform(0.2, 0.5)
                pts.append((x, r.uniform(-0.06, 0.06)))
            crack_ground.append(pts)
    debris = [(r.uniform(-3.0, -0.6), r.uniform(-0.5, 3.2), r.uniform(0.06, 0.16)) for _ in range(16)]
    return rays, crack_wall, crack_ground, debris


RAYS, CRACK_WALL, CRACK_GROUND, DEBRIS = _rng_data()


def _h(i: int, j: int) -> float:
    v = (i * 73856093) ^ (j * 19349663)
    return ((v >> 3) & 255) / 255.0


def to_px(wx: float, wz: float, cam: dict) -> Tuple[float, float]:
    """y=0 の面の点(x, z)を画面へ。遠近のあるカメラにも、従来の真横のカメラにも使える。"""
    px, py, _ = camera.project(cam, wx, 0.0, wz)
    return px, py


def _pw_at(v, tau: float) -> float:
    """数ならそのまま、[[tau, x], ...] なら折れ線で補間。"""
    if isinstance(v, (int, float)):
        return float(v)
    pts = sorted((float(a), float(b)) for a, b in v)
    if tau <= pts[0][0]:
        return pts[0][1]
    for (t0, x0), (t1, x1) in zip(pts, pts[1:]):
        if tau <= t1:
            return x0 + (x1 - x0) * (tau - t0) / max(1e-6, t1 - t0)
    return pts[-1][1]


def _prev_frame(plan: dict, f: int) -> Optional[int]:
    """tau が違う直前のコマ(2 コマ撮りの同じ絵は飛ばす)。"""
    t = plan["frames"][f]["tau"]
    g = f - 1
    while g >= 0 and plan["frames"][g]["tau"] == t:
        g -= 1
    return g if g >= 0 else None


def _limb_smear(plan: dict, f: int, cam: dict) -> Image.Image:
    """スミア: 剣・手・足が 1 コマで大きく動いたとき(振りの瞬間)、前のコマの位置から今の位置までを面で埋める。
    アニメの「振りの 1 枚」。剣は 手→剣先 の扇形(刃の色)、手・足は太い線(人物の色)。人物の下に描く。しきい値は身長比 0.3/コマ。"""
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g = _prev_frame(plan, f)
    if g is None:
        return ov
    d = ImageDraw.Draw(ov)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dg = ImageDraw.Draw(glow)
    ppu = camera.px_per_unit(cam)
    drew = False
    for who, a in plan["actors"].items():
        # 打つ側の、振りの瞬間だけ(命中の 4 コマ前〜命中)。押されて下がる足などには出さない
        kinds = {e["kind"] for e in plan["events"] if e.get("by") == who and e["frame"] - 4 <= f <= e["frame"]}
        if not kinds:
            continue
        want = {"foot"} if kinds & {"kick", "heel"} else {"hand"}      # 蹴りは足、斬り・拳は手(踏み込みの脚には出さない)
        sc = a.get("scale", 1.0)
        s = 1 if a.get("facing", 1) >= 0 else -1
        p1, p0 = plan["frames"][f]["actors"][who], plan["frames"][g]["actors"][who]
        if abs(p1.get("roll", 0.0)) > 0.5:
            continue
        sk1 = fk.skeleton(p1, s, p1["root_x"], sc)
        sk0 = fk.skeleton(p0, s, p0["root_x"], sc)
        col = tuple(int(255 * c) for c in a.get("color", [0.5, 0.5, 0.5]))
        lw = max(3, int(0.09 * ppu))
        for key, lim in (("hand", "front_arm"), ("foot", "front_leg")):
            if key not in want:
                continue
            e0, e1 = sk0[key], sk1[key]
            mv = math.hypot(e1[0] - e0[0], e1[1] - e0[1]) / (1.9 * sc)
            if a.get("weapon") and key == "hand":
                t0, t1 = sk0["tip"], sk1["tip"]
                mv = max(mv, math.hypot(t1[0] - t0[0], t1[1] - t0[1]) / (1.9 * sc))
            if mv <= 0.12:                                   # 身長比 0.12/コマ以上(突きの剣先は 0.17〜0.19)
                continue
            j0 = sk0[lim][len(sk0[lim]) // 2]                # 肘・膝
            j1 = sk1[lim][len(sk1[lim]) // 2]
            n = 3                                            # 前の位置と今の位置の間に、薄い中割りを 3 枚(多重のスミア)
            for i in range(1, n + 1):
                u = i / (n + 1)
                al = int(60 + 70 * u)
                jm = (j0[0] + (j1[0] - j0[0]) * u, j0[1] + (j1[1] - j0[1]) * u)
                em = (e0[0] + (e1[0] - e0[0]) * u, e0[1] + (e1[1] - e0[1]) * u)
                d.line([to_px(*jm, cam), to_px(*em, cam)], fill=col + (al,), width=lw)
                if a.get("weapon") and key == "hand":
                    tm = (t0[0] + (t1[0] - t0[0]) * u, t0[1] + (t1[1] - t0[1]) * u)
                    dg.line([to_px(*em, cam), to_px(*tm, cam)], fill=(120, 220, 255, al + 40), width=lw + 6)
                    d.line([to_px(*em, cam), to_px(*tm, cam)], fill=(210, 245, 255, al + 20), width=max(2, lw - 2))
            drew = True
    if not drew:
        return ov
    glow = glow.filter(ImageFilter.GaussianBlur(8))
    glow.alpha_composite(ov)
    return glow


def P3(cam: dict, x: float, y: float, z: float) -> Tuple[float, float]:
    px, py, _ = camera.project(cam, x, y, z)
    return px, py


def in_ranges(tau: float, ranges: Sequence[Sequence[float]]) -> bool:
    return any(a <= tau <= b for a, b in ranges)


def background(plan: dict, f: int) -> Image.Image:
    fr = plan["frames"][f]
    cam = fr["cam"]
    pxu = cam["pxu"]
    wall_x = plan.get("stage", {}).get("wall_x")
    events = plan["events"]
    im = Image.new("RGB", (W * SS, H * SS), (50, 50, 57))
    d = ImageDraw.Draw(im)
    gy = (GROUND_Y + cam["sz"] * pxu) * SS
    # 奥の層: ゆっくり流れる石のブロック(視差 0.5)
    bs = 0.64 * pxu
    off = cam["x"] * 0.4 * pxu
    i0 = int(math.floor((off - 40) / bs))
    for i in range(i0, i0 + int(W / bs) + 3):
        for jj in range(0, int(gy / SS / bs) + 2):
            v = 44 + int(16 * _h(i, jj))
            x0 = (i * bs - off) * SS
            y0 = (gy / SS - (jj + 1) * bs) * SS
            d.rectangle([x0, y0, x0 + bs * SS, y0 + bs * SS], fill=(v, v, v + 7))
    # 手前の層: 木の足場の影(視差 0.8)
    off2 = cam["x"] * 0.8 * pxu
    for k in range(-2, 12):
        px = (k * 2.6 * pxu - off2 % (2.6 * pxu)) * SS
        d.rectangle([px, gy - 2.4 * pxu * SS, px + 0.16 * pxu * SS, gy], fill=(64, 52, 40))
    if wall_x is not None:
        wx0, _ = to_px(wall_x, 0, cam)
        wx1, _ = to_px(wall_x + 2.5, 0, cam)
        d.rectangle([wx0 * SS, 0, wx1 * SS, gy], fill=(118, 114, 110), outline=(18, 18, 22), width=4 * SS)
        for k in range(1, 14):
            yy = gy - k * 0.5 * pxu * SS
            d.line([wx0 * SS, yy, wx1 * SS, yy], fill=(88, 84, 80), width=2 * SS)
    d.rectangle([0, gy, W * SS, H * SS], fill=(86, 78, 68))
    d.rectangle([0, gy, W * SS, gy + 8 * SS], fill=(124, 112, 92))
    x = math.floor((cam["x"] - 8) / 1.0)
    while x < cam["x"] + 8:
        px, _ = to_px(x, 0, cam)
        d.line([px * SS, gy + 8 * SS, px * SS, H * SS], fill=(66, 60, 52), width=3 * SS)
        x += 1
    for e in events:
        if e["kind"] == "wall" and f >= e["frame"] and wall_x is not None:
            cx, cy = to_px(wall_x, e["pos"][1], cam)
            for pts in CRACK_WALL:
                prev = (cx, cy)
                for (ux, uz) in pts:
                    nxt = (cx + ux * pxu, cy - uz * pxu)
                    d.line([prev[0] * SS, prev[1] * SS, nxt[0] * SS, nxt[1] * SS], fill=(16, 16, 20), width=int(3 * SS))
                    prev = nxt
            age = (f - e["frame"]) / plan["fps"]
            if age < 1.6:
                for vx, vz, sz_ in DEBRIS:
                    wxp = wall_x - 0.05 + vx * age * 0.9
                    wzp = max(0.0, e["pos"][1] + vz * age - 4.9 * age * age * 0.5)
                    px, py = to_px(wxp, wzp, cam)
                    r = sz_ * pxu
                    d.rectangle([(px - r) * SS, (py - r) * SS, (px + r) * SS, (py + r) * SS], fill=(150, 146, 140),
                                outline=(20, 20, 24), width=2 * SS)
        if e["kind"] == "heel" and f >= e["frame"]:
            cx, cy = to_px(e["pos"][0], 0, cam)
            for pts in CRACK_GROUND:
                prev = (cx, cy)
                for (ux, uz) in pts:
                    nxt = (cx + ux * pxu * 0.8, cy + 4 - uz * pxu * 2.5)
                    d.line([prev[0] * SS, prev[1] * SS, nxt[0] * SS, nxt[1] * SS], fill=(16, 16, 20), width=int(3 * SS))
                    prev = nxt
        if e["kind"] in ("land", "land2", "heel", "wall"):
            age = (f - e["frame"]) / plan["fps"]
            if 0 <= age < 0.7:
                u = age / 0.7
                cx, cy = to_px(e["pos"][0], e["pos"][1] if e["kind"] == "wall" else 0.0, cam)
                big = 1.6 if e["kind"] == "heel" else 1.0
                for k in range(4):
                    r = (0.25 + 0.9 * u + 0.12 * k) * pxu * big
                    ox = (k - 1.5) * 0.3 * pxu * u * big
                    col = (int(190 - 60 * u), int(186 - 60 * u), int(178 - 60 * u))
                    d.ellipse([(cx + ox - r) * SS, (cy - r * 0.6) * SS, (cx + ox + r) * SS, (cy + r * 0.25) * SS],
                              outline=col, width=int(6 * SS * (1 - u)) + SS)
    return im


def ground_fx(plan: dict, f: int) -> Image.Image:
    """遠近のカメラ用: 影・壁と地面のひび・破片・砂ぼこりを、舞台の上に重ねる層(RGBA)。人物より下に敷く。"""
    fr = plan["frames"][f]
    cam = fr["cam"]
    wall_x = plan.get("stage", {}).get("wall_x")
    ov = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    sh = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d, ds = ImageDraw.Draw(ov), ImageDraw.Draw(sh)

    def poly(dr, pts, **kw):
        dr.polygon([(x * SS, y * SS) for x, y in pts], **kw)

    def line(pts, col, w):
        d.line([(x * SS, y * SS) for x, y in pts], fill=col, width=int(w * SS))

    for who, a in plan["actors"].items():          # 足元の影(空中では薄く小さく)
        p = fr["actors"][who]
        sc = a.get("scale", 1.0)
        lying = abs(p.get("lean", 0)) > 1.0 or abs(p.get("roll", 0)) > 0.5
        lift = 0.0 if lying else max(0.0, (p["hz"] - 0.92) * sc)
        al = int((95 if plan.get('scene', {}).get('style') == 'flat2d' else 120) / (1 + 1.5 * lift))
        hx = p["root_x"]
        ts = [i * math.pi / 12 for i in range(24)]
        if lying:
            ell = [(hx + 0.9 * sc * math.cos(t) * 1.3, 0.35 * sc * math.sin(t)) for t in ts]
        else:
            ell = [(hx + 0.5 * sc / (1 + lift) * math.cos(t), 0.38 * sc * math.sin(t) / (1 + lift)) for t in ts]
        ay = a.get("y", 0.0)                           # 奥行きをずらした人物(味方など)の影
        poly(ds, [P3(cam, x, y + ay, 0.0) for x, y in ell], fill=(0, 0, 0, al))
    if plan.get("scene", {}).get("style") != "flat2d":       # 2D は、ぼかさない平らな影(セル画の落ち影)
        sh = sh.filter(ImageFilter.GaussianBlur(7 * SS))
    for e in plan["events"]:
        age = (f - e["frame"]) / plan["fps"]
        if e["kind"] == "wall" and f >= e["frame"] and wall_x is not None:
            z0 = e["pos"][1]
            for pts in CRACK_WALL:
                path = [P3(cam, wall_x - 0.01, 0.0, z0)]
                for (ux, uz) in pts:
                    path.append(P3(cam, wall_x - 0.01, ux * 1.1, z0 + uz))
                line(path, (16, 16, 20, 255), 3)
            if age < 1.6:
                for i, (vx, vz, sz_) in enumerate(DEBRIS):
                    x = wall_x - 0.05 + vx * age * 0.9
                    z = max(0.0, z0 + vz * age - 4.9 * age * age * 0.5)
                    y = (i % 5 - 2) * 0.25
                    cx_, cy_ = P3(cam, x, y, z)
                    r = sz_ * camera.px_per_unit(cam)
                    d.rectangle([(cx_ - r) * SS, (cy_ - r) * SS, (cx_ + r) * SS, (cy_ + r) * SS],
                                fill=(150, 146, 140, 255), outline=(20, 20, 24, 255), width=2 * SS)
        if e["kind"] == "heel" and f >= e["frame"]:
            for pts in CRACK_GROUND:
                path = [P3(cam, e["pos"][0], 0.0, 0.0)] + [P3(cam, e["pos"][0] + ux * 0.8, uz * 2.5, 0.0) for ux, uz in pts]
                line(path, (16, 16, 20, 255), 3)
        if e["kind"] in ("land", "land2", "heel", "wall") and 0 <= age < 0.7:
            u = age / 0.7
            cx0 = e["pos"][0] if e["kind"] != "wall" else wall_x - 0.3
            big = 1.6 if e["kind"] == "heel" else 1.0
            for k in range(4):
                r = (0.25 + 0.9 * u + 0.12 * k) * big
                col = (int(190 - 60 * u), int(186 - 60 * u), int(178 - 60 * u), int(255 * (1 - 0.6 * u)))
                ring = [P3(cam, cx0 + (k - 1.5) * 0.3 * u * big + r * math.cos(t), r * 0.55 * math.sin(t), 0.0)
                        for t in [i * math.pi / 14 for i in range(29)]]
                line(ring, col, max(1.0, 6 * (1 - u)))
    out = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    out.alpha_composite(sh)
    out.alpha_composite(ov)
    return out.resize((W, H), Image.LANCZOS)


def silhouette(fig: Image.Image, col: Tuple[int, int, int]) -> Image.Image:
    a = fig.split()[3]
    solid = Image.new("RGBA", fig.size, (*col, 255))
    out = Image.new("RGBA", fig.size, (*col, 0))
    out.putalpha(a)
    return Image.composite(solid, out, a)


def radial(d_ov: ImageDraw.ImageDraw, cx: float, cy: float, u: float, big: float, col=(245, 245, 245)) -> None:
    for ang, ln, wd in RAYS:
        r0 = (24 + 46 * u) * big
        r1 = r0 + (80 + 140 * ln) * big * (1 - 0.5 * u)
        a = int(255 * (1 - u ** 2))
        d_ov.line([(cx + math.cos(ang) * r0) * SS, (cy + math.sin(ang) * r0) * SS,
                   (cx + math.cos(ang) * r1) * SS, (cy + math.sin(ang) * r1) * SS],
                  fill=(*col, a), width=int(wd * SS * (1 - 0.4 * u) * (1 + 0.4 * big)))


BIG = dict(kick=1.2, slash=0.7, wall=1.5, heel=1.8, hit=0.8, clash=0.9, beam=0.8, blast=1.5, slam=1.4, wave=1.1)     # 放射線の大きさ。斬り・受け止めは控えめ(白い面積が増えると、閃光が参考の 2 倍以上になる)
BURST_FRAMES = dict(slash=7, hit=9, kick=14, wall=14, heel=14, clash=8, miss=4, beam=5, blast=12, slam=10, wave=10)   # 放射線が残るコマ数。連続する命中で重ならないよう、斬りは短く


def compose_frame(plan: dict, f: int, figs: Dict[int, Image.Image], stages: Optional[Dict[int, Image.Image]] = None) -> Image.Image:
    fr = plan["frames"][f]
    cam = fr["cam"]
    tau = fr["tau"]
    fx = plan.get("scene", {}).get("fx", {})
    lk = fr.get("look")
    if lk is not None:                         # 色つき流線の背景のカット(参考の寄り・色の画)。舞台の色で少し落として、明るさの跳ねを抑える
        base = look.streak_bg(f, int(lk))
        th = look.FLAT_THEMES.get(plan.get("stage", {}).get("theme", "cave"), look.FLAT_THEMES["cave"])
        dark = tuple(int(v * 0.5) for v in th["sky"])
        base = Image.blend(base, Image.new("RGBA", base.size, dark + (255,)), 0.6)
    elif plan["view"].get("persp") and plan.get("stage", {}).get("style") == "flat":       # 2D の舞台(ユーザー「フィールドも2d」)
        base = look.flat_bg(plan, f)
        if lk is None:
            base.alpha_composite(ground_fx(plan, f))
    elif plan["view"].get("persp"):
        base = stages[f].convert("RGBA") if stages is not None else Image.new("RGBA", (W, H), (30, 30, 34, 255))
        if lk is None:
            base.alpha_composite(ground_fx(plan, f))
    else:
        base = background(plan, f).resize((W, H), Image.LANCZOS).convert("RGBA")
    frozen = f > 0 and plan["frames"][f - 1]["tau"] == tau
    if in_ranges(tau, fx.get("trails", [])) and not frozen:
        for k, al in ((9, 0.10), (6, 0.18), (3, 0.30)):
            if f - k >= 0:
                ghost = silhouette(figs[f - k], (70, 110, 210))
                ghost.putalpha(ghost.split()[3].point(lambda v, al=al: int(v * al)))
                base.alpha_composite(ghost)
    chs = [r for r in fx.get("charge", []) if r["start"] <= tau < r["end"]] if lk is None else []
    if chs:                                    # 必殺技の溜め: 背景を暗くし、光の柱・粒・輪で包む(2 人同時の溜めは両方描く)
        auras = []
        dim = 0.0
        for ch in chs:
            age01 = (tau - ch["start"]) / (ch["end"] - ch["start"])
            aura, d_ = look.charge_aura(plan, f, ch.get("who", "A"), age01, tuple(ch.get("color", (120, 230, 255))))
            auras.append(aura)
            dim = max(dim, d_)
        base = Image.blend(base.convert("RGBA"), Image.new("RGBA", (W, H), (5, 8, 20, 255)), dim)
        for aura in auras:
            base.alpha_composite(aura)
    if plan.get("scene", {}).get("style") == "flat2d":        # セル画の見た目: 人物の外形に、濃い輪郭線
        al = figs[f].split()[3]
        grow = al.filter(ImageFilter.MaxFilter(7))
        ink = Image.new("RGBA", figs[f].size, (18, 14, 24, 0))
        ink.putalpha(grow)
        base.alpha_composite(ink)
    if fx.get("weapon_glow"):                    # 武器の発光する縁取り(Alan Becker の剣は水色の縁が光る)。描かれた刃の水色の画素から作る
        import numpy as np
        arr = np.asarray(figs[f], dtype=np.int16)
        blade = (arr[..., 3] > 150) & (arr[..., 1] > 190) & (arr[..., 2] > 190) & (arr[..., 0] < arr[..., 1] - 40)
        if blade.any():
            m = Image.fromarray((blade * 255).astype("uint8"))
            wide = m.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(5))
            col = Image.new("RGBA", (W, H), tuple(fx.get("weapon_glow_color", (60, 190, 255))) + (0,))
            col.putalpha(wide.point(lambda v: min(255, int(v * 1.6))))
            base.alpha_composite(col)
    if (plan.get("scene", {}).get("anime") or {}).get("smear", False):
        base.alpha_composite(_limb_smear(plan, f, cam))   # 振りの 1〜2 コマの間を埋めるスミア(人物の下に描く)
    for ai in fx.get("afterimages", []):       # 瞬間移動の残像の列: 消えた位置から現れた位置まで、消える直前の人影を薄く並べ、すぐ消える
        if ai["start"] <= tau <= ai["end"] and f > 0:
            q = (tau - ai["start"]) / max(1e-6, ai["end"] - ai["start"])
            g = _prev_frame(plan, f) or f
            src = figs[max(0, min(plan["n"] - 1, int(ai.get("src_frame", g))))]
            n_ = int(ai.get("n", 6))
            who_a = ai.get("who", "A")
            x_now = plan["frames"][f]["actors"][who_a]["root_x"]
            for i in range(n_):
                xw = float(ai["x0"]) + (float(ai["x1"]) - float(ai["x0"])) * (i + 1) / (n_ + 1)
                px_, _ = to_px(xw, 0.0, cam)
                px_now, _ = to_px(x_now, 0.0, cam)
                ghost = silhouette(src, tuple(int(255 * c) for c in plan["actors"][who_a].get("color", [0.5, 0.8, 0.3])))
                al = int(150 * (1 - q) * (0.4 + 0.6 * i / n_))
                ghost.putalpha(ghost.split()[3].point(lambda v, al=al: int(v * al / 255)))
                base.alpha_composite(ghost, (int(px_ - px_now), 0))
    for bm in fx.get("beams", []):             # 気の光線(人物の下に描く: 上だと撃ち合いで 2 人が光線に隠れた。手の先から壁まで。x_end は数か [[tau, x], ...] の折れ線)
        if bm["start"] <= tau <= bm["end"]:
            base.alpha_composite(look.beam(plan, f, bm.get("who", "A"), _pw_at(bm["x_end"], tau), tau - bm["start"], bm["end"] - bm["start"], tuple(bm.get("color", (120, 230, 255)))))
    base.alpha_composite(figs[f])
    for wv in fx.get("waves", []):             # 地面を走る衝撃波(人物の上。土の山が手前を通る)
        if wv["start"] <= tau <= wv["end"]:
            q = (tau - wv["start"]) / max(1e-6, wv["end"] - wv["start"])
            base.alpha_composite(look.ground_wave(plan, f, float(wv["x0"]), float(wv["x1"]), min(1.0, q), tuple(wv.get("color", (255, 220, 120)))))
    for ob in fx.get("orbs", []):              # 手に付いて膨らむ光の玉(溜め)
        if ob["start"] <= tau < ob["end"]:          # 終わり(投げる瞬間)は含めない(飛ぶ玉と二重になる)
            who_o = ob.get("who", "A")
            if ob.get("path"):                         # path があれば手でなくその位置(光線のぶつかる点など)
                hx, hz = _pw_at(ob["path"], tau), float(ob.get("z", 1.3))
            else:
                hx, hz = anime.effector_world(plan, who_o, f)["hand"]
            px_, py_ = to_px(hx, hz, cam)
            q = (tau - ob["start"]) / max(1e-6, ob["end"] - ob["start"])
            r_u = ob["r0"] + (ob["r1"] - ob["r0"]) * (q ** 1.3)      # 早めに見える大きさに(q² だと溜めの 6 割まで見えなかった)
            base.alpha_composite(look.ki_ball(px_, py_, r_u * camera.px_per_unit(cam), f, tuple(ob.get("color", (255, 190, 70)))))
    for pj in fx.get("projectiles", []):       # 飛ぶ玉(少し山なり)
        if pj["start"] <= tau <= pj["end"]:
            q = (tau - pj["start"]) / max(1e-6, pj["end"] - pj["start"])
            wx = pj["x0"] + (pj["x1"] - pj["x0"]) * q
            wz = pj["z0"] + (pj["z1"] - pj["z0"]) * q + 0.25 * math.sin(math.pi * q)
            px_, py_ = to_px(wx, wz, cam)
            qx, qy = to_px(wx - (pj["x1"] - pj["x0"]) * 0.05, wz, cam)
            if pj.get("shape") == "crescent":
                base.alpha_composite(look.crescent(px_, py_, pj["r"] * camera.px_per_unit(cam), f, px_ - qx, tuple(pj.get("color", (170, 245, 255)))))
            else:
                base.alpha_composite(look.ki_ball(px_, py_, pj["r"] * camera.px_per_unit(cam), f, tuple(pj.get("color", (255, 190, 70))), trail=(px_ - qx, py_ - qy)))
    # 顔(目)は描かない(2026-10-19 ユーザー指示)
    for e in plan["events"]:                   # 特大の効果: 斬撃の弧・衝撃の輪
        age = f - e["frame"]
        if e["kind"] == "slash" and 0 <= age <= 9:
            who_s = next((w for w, ac in plan["actors"].items() if ac.get("weapon")), None)
            path = []
            if who_s is not None:                  # 剣先が実際に通った道に沿わせる(命中の前後)
                for ff in range(max(0, e["frame"] - 7), min(plan["n"] - 1, e["frame"] + 3) + 1):
                    tip = anime.effector_world(plan, who_s, ff).get("tip")
                    if tip is not None:
                        path.append(to_px(tip[0], tip[1], cam))
            span = sum(math.hypot(path[i + 1][0] - path[i][0], path[i + 1][1] - path[i][1]) for i in range(len(path) - 1)) if len(path) > 2 else 0
            if span > 90:
                base.alpha_composite(look.sweep_arc(path, age, 9))
            else:
                cxy = to_px(e["pos"][0], e["pos"][1], cam)
                base.alpha_composite(look.slash_arc(cxy[0], cxy[1], age, 9))
        elif e["kind"] in ("kick", "heel", "wall") and 0 <= age <= 8:
            cxy = to_px(e["pos"][0], e["pos"][1], cam)
            base.alpha_composite(look.shock_ring(cxy[0], cxy[1], age, 8))
        if e["kind"] in ("blast", "slam", "wave") and 0 <= age <= 8:
            cxy = to_px(e["pos"][0], e["pos"][1], cam)
            base.alpha_composite(look.shock_ring(cxy[0], cxy[1], age, 8))
        if e["kind"] == "rapid" and 0 <= age <= 3:        # 連打乱舞: 小さな火花だけ(放射線・擬音は無し)
            cxy = to_px(e["pos"][0], e["pos"][1], cam)
            base.alpha_composite(look.sparks(cxy[0], cxy[1], age, camera.px_per_unit(cam), e["frame"] * 7 + 3, (255, 220, 120), 6, 0.5))
        if e["kind"] in ("clash", "slash", "hit", "kick", "heel", "wall", "beam", "blast", "slam", "wave") and 0 <= age <= 14:                                        # ヒットストップ中も描く(止め絵に火花が散っているのが衝撃のコマ)
            cxy = to_px(e["pos"][0], e["pos"][1], cam)                   # 火花(金属は多め・白黄、打撃は少なめ・橙)
            metal = e["kind"] in ("clash", "slash")
            base.alpha_composite(look.sparks(cxy[0], cxy[1], age, camera.px_per_unit(cam), e["frame"] * 7 + 3,
                                             (255, 240, 160) if metal else (255, 170, 90), 18 if metal else 9, 1.0 if metal else 0.7))
    ov = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    if in_ranges(tau, fx.get("speed_lines", [])):
        # 流線: 主役の動く向き(画面上)に平行な線。2コマごとに入れ替わり(ちらつき)、長さ・位置・濃さはばらつく
        a_who = next(iter(plan["actors"]))
        ang = 0.0
        if f > 0:
            pa, pb = plan["frames"][f - 1]["actors"][a_who], plan["frames"][f]["actors"][a_who]
            x0_, y0_ = P3(plan["frames"][f - 1]["cam"], pa["root_x"], 0.0, 1.0)
            x1_, y1_ = P3(cam, pb["root_x"], 0.0, 1.0)
            if abs(x1_ - x0_) + abs(y1_ - y0_) > 0.5:
                ang = math.atan2(y1_ - y0_, x1_ - x0_)
        rnd = random.Random(f // 2)
        ux, uy = math.cos(ang), math.sin(ang)
        for _ in range(16):
            cx_, cy_ = rnd.uniform(0, W), rnd.uniform(30, 560)
            ln = rnd.uniform(140, 420)
            al = int(rnd.uniform(35, 90))
            d.line([cx_ * SS, cy_ * SS, (cx_ - ux * ln) * SS, (cy_ - uy * ln) * SS], fill=(255, 255, 255, al), width=int(rnd.choice((1, 2, 2, 3)) * SS))
    invert = None
    kind_of_invert = None
    invert_kinds = fx.get("invert", ["kick", "heel"])
    for e in plan["events"]:
        age = f - e["frame"]
        nb = BURST_FRAMES.get(e["kind"], 14)
        if e["kind"] in BIG and 0 <= age <= nb:
            cx, cy = to_px(e["pos"][0], e["pos"][1], cam)
            radial(d, cx, cy, min(1.0, age / nb), BIG[e["kind"]])
            if e["kind"] in invert_kinds and age == 0:                   # 衝撃のコマは 1 コマだけ(2 コマ目の色つきは閃光が増える)
                invert = (age, cx, cy, BIG[e["kind"]])
                kind_of_invert = e["kind"]
            if e["kind"] == "wall" and age <= 1:
                d.rectangle([0, 0, W * SS, H * SS], fill=(255, 255, 255, 150 if age == 0 else 80))
    for ft in fx.get("flashes", []):          # 1コマだけの閃光(参考: 2秒に1回前後)
        if plan["frames"][f]["tau"] >= ft > plan["frames"][max(0, f - 1)]["tau"] or (f == 0 and ft <= 0):
            fl = Image.new("RGBA", (W, H), (255, 255, 255, 120))
            base.alpha_composite(fl)
    base.alpha_composite(ov.resize((W, H), Image.LANCZOS))
    frame = base.convert("RGB")
    if invert is not None:
        age, cx, cy, big = invert
        second_bg = dict(wall=(150, 22, 30), heel=(20, 45, 150), slash=(10, 30, 60)).get(kind_of_invert, (0, 0, 0))
        bgc, fgc = ((255, 255, 255), (0, 0, 0)) if age == 0 else (second_bg, (255, 255, 255))
        im = Image.new("RGBA", (W, H), (*bgc, 255))
        im.alpha_composite(silhouette(figs[f], fgc))
        ov2 = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        radial(ImageDraw.Draw(ov2), cx, cy, 0.15 if age == 0 else 0.3, big * 1.4, fgc)
        im.alpha_composite(ov2.resize((W, H), Image.LANCZOS))
        frame = im.convert("RGB")
    acfg = plan.get("scene", {}).get("anime")
    if acfg is not None and invert is None:
        frame = anime.apply(plan, f, frame, acfg if isinstance(acfg, dict) else {}, plan.setdefault("_anime_cache", {}))
    out = _color_script(frame, plan, tau, fx)
    if plan.get("_vertical"):                 # 縦画面は、切り出してから字幕を重ねる(compose 側)
        return out
    return captions.draw(out, plan, f)


def _color_script(frame: Image.Image, plan: dict, tau: float, fx: dict) -> Image.Image:
    """色の台本(fx.color_script: [[tau, [r,g,b], 強さ], ...])。場面ごとに全体の色味を変える(静かな所は冷たく、攻めは暖かく)。"""
    keys = fx.get("color_script")
    if not keys:
        return frame
    import numpy as np
    ts = [k[0] for k in keys]
    if tau <= ts[0]:
        col, s = keys[0][1], keys[0][2]
    elif tau >= ts[-1]:
        col, s = keys[-1][1], keys[-1][2]
    else:
        i = max(j for j in range(len(ts)) if ts[j] <= tau)
        u = (tau - ts[i]) / (ts[i + 1] - ts[i])
        col = [keys[i][1][k] * (1 - u) + keys[i + 1][1][k] * u for k in range(3)]
        s = keys[i][2] * (1 - u) + keys[i + 1][2] * u
    arr = np.asarray(frame, dtype=np.float32)
    tint = np.array(col, dtype=np.float32) / 255.0
    out = arr * (1 - s) + arr * tint * 1.45 * s
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def crop_centers(plan: dict, cw: int) -> List[float]:
    """縦画面の切り出しの中心 x(画面の画素)。2人の中間を追い、カットでは飛び、同じカットの中では1コマ 70px まで。"""
    xs, prev_cam, cur = [], None, None
    for f, fr in enumerate(plan["frames"]):
        cam = fr["cam"]
        pts = []
        for who in list(plan["actors"])[:2]:         # 戦う2人(味方などの3人目は数えない)
            p = fr["actors"][who]
            pts.append(P3(cam, p["root_x"], 0.0, 0.95)[0])
        tgt = sum(pts) / len(pts)
        if len(pts) >= 2 and abs(pts[0] - pts[1]) > cw * 0.8:          # 2人が縦の枠に収まらないほど離れている: 主役(最初の人物)を追う
            tgt = pts[0]
        for e in plan["events"]:                       # 命中の瞬間は、命中の位置を中心に
            if e["frame"] <= f <= e["frame"] + max(1, e.get("hold_frames", 0)):
                tgt = to_px(e["pos"][0], e["pos"][1], cam)[0]
        cut = prev_cam is None or abs(cam.get("scale", 1) - prev_cam.get("scale", 1)) > 0.3 * prev_cam.get("scale", 1) or abs(cam.get("yaw", 0) - prev_cam.get("yaw", 0)) > 8
        cur = tgt if (cut or cur is None) else cur + max(-120.0, min(120.0, tgt - cur))
        xs.append(min(max(cur, cw / 2), W - cw / 2))
        prev_cam = cam
    return xs


def compose_vertical(plan: dict, f: int, figs, stages, cx: float) -> Image.Image:
    """16:9 のコマから、縦(9:16)を切り出して 720x1280 に拡大し、その上に字幕を重ねる。"""
    plan["_vertical"] = True
    an = plan.get("scene", {}).get("anime")
    if isinstance(an, dict) and an.get("sfx", True):           # 縦画面は効果音の文字を出さない(切り出しで切れる・大きすぎる)
        plan["scene"]["anime"] = dict(an, sfx=False)
    base = compose_frame(plan, f, figs, stages)
    cw = int(H * 9 / 16)
    x0 = int(round(cx - cw / 2))
    crop = base.crop((x0, 0, x0 + cw, H)).resize((720, 1280), Image.LANCZOS)
    return captions.draw(crop, plan, f, xf=(x0, 1280 / H))


class _Lazy:
    """コマ番号で引くと、その場でファイルから読む(最近の分だけ覚える)。並列の合成で、全コマを各プロセスに送らないため。"""

    def __init__(self, dir_, mode: str, keep: int = 24):
        self.dir, self.mode, self.keep, self.cache = Path(dir_), mode, keep, {}

    def __getitem__(self, f: int) -> Image.Image:
        if f not in self.cache:
            if len(self.cache) >= self.keep:
                self.cache.pop(next(iter(self.cache)))
            self.cache[f] = Image.open(self.dir / f"f_{f + 1:04d}.png").convert(self.mode)
        return self.cache[f]


_W = {}


def _init_worker(plan, fig_dir, stage_dir, out_dir, vertical, cxs):
    _W.update(plan=plan, figs=_Lazy(fig_dir, "RGBA"), stages=_Lazy(stage_dir, "RGB") if stage_dir else None, out=Path(out_dir), vertical=vertical, cxs=cxs)


def _held_source(plan: dict, f: int) -> int:
    """2コマ撮りで止めているコマは、前のコマと同じ絵にする(効果・揺れ・火花も止める=本当の「同じ絵」)。その元のコマ番号を返す。"""
    while f > 0:
        fr, pv = plan["frames"][f], plan["frames"][f - 1]
        if all(fr["actors"][w].get("stepped") for w in fr["actors"]) and fr["cam"] == pv["cam"]:
            f -= 1
        else:
            break
    return f


def _render_one(f: int) -> int:
    plan, figs, stages = _W["plan"], _W["figs"], _W["stages"]
    src = _held_source(plan, f)
    img = compose_vertical(plan, src, figs, stages, _W["cxs"][src]) if _W["vertical"] else compose_frame(plan, src, figs, stages)
    img.save(_W["out"] / f"{f + 1:04d}.png")
    return f


def compose(plan: dict, fig_dir, out_dir, mp4_path, ffmpeg: str, stage_dir=None) -> Path:
    import multiprocessing
    import os
    fig_dir, out_dir = Path(fig_dir), Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for p in out_dir.glob("*.png"):
        p.unlink()
    n = plan["n"]
    vertical = (plan.get("scene", {}).get("output") or {}).get("aspect") == "vertical"
    cxs = crop_centers(plan, int(H * 9 / 16)) if vertical else None
    sd = stage_dir if (plan["view"].get("persp") and stage_dir is not None) else None
    workers = int(os.environ.get("STICKFIG_WORKERS", min(8, os.cpu_count() or 1)))
    if workers > 1 and n >= 12:             # コマは互いに独立なので、プロセスを分けて並列に合成する(1コマ約0.8秒)
        ctx = multiprocessing.get_context("spawn")
        with ctx.Pool(workers, initializer=_init_worker, initargs=(plan, str(fig_dir), str(sd) if sd else None, str(out_dir), vertical, cxs)) as pool:
            for _ in pool.imap_unordered(_render_one, range(n), chunksize=4):
                pass
    else:
        _init_worker(plan, str(fig_dir), str(sd) if sd else None, str(out_dir), vertical, cxs)
        for f in range(n):
            _render_one(f)
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-framerate", str(plan["fps"]), "-i", str(out_dir / "%04d.png"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", str(mp4_path)], check=True)
    return Path(mp4_path)
