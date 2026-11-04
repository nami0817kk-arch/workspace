"""画面の種類(ショット)を切り替える。地図だけで1本を通すと一辺倒になる(2026-11-04 ユーザー指摘)ので、
地図の回でも 2〜3 行ごとに見せ方を変える。行の scene に shot を書く(無ければ地図)。

  map       世界の地図(worldmap)。view_to を書くと行のあいだカメラが動く(山並みに沿って飛ぶなど)。relief で山の強さ
  globe     宇宙から見た地球儀。center=(経度, 緯度) から to=(経度, 緯度) へ回る。hl=国のコード で光らせる。r=半径(画面の高さの何倍)
  block     地形の箱を切った断面。lat=切る緯度、lon=(西, 東)、plate=True で沈みこむ板を描く。view は地図と同じ
  split     左右に2つの地図。left/right にそれぞれ scene(view・layers)と title
  illust    場面の絵(AI で作った絵。隅に「イメージ」)。path、title(大きな字)、sub、pan=(x0, y0, x1, y1) 0〜1 の寄りの動き
  card      大きな数字の札。big、sub、note。後ろは地図(view があれば)をぼかして暗くしたもの
  timeline  年表の帯。items=[(年, 名前)]、cur=いまの番号。後ろは地図をぼかしたもの

ショットが変わる行の頭は 0.6 秒で溶け合わせる(地図どうしは worldmap のカメラの移りで)。

編集の技(2026-11-04「動画編集のスキルはたくさんあるよね」):
  tr        切り替え。"fade"(既定)・"zoom"(前の絵に寄って抜ける)・"whip"(横に流れてぶれる)・"flash"(白く光って変わる)
  fx        粒。"snow"(雪)・"dust"(砂ぼこり)・"embers"(火の粉)。絵にも地図にも
  grade     色。"old"(昔の場面: 色を抜いて茶色く)・"cold"・"warm"
  on="言葉" 層・パネル・札をその言葉を言い始めた瞬間に出す(声の時間割の marks。worldmap.start_of)
  count     札の数字が 0 から数え上がる(card は既定でそう。地図の label は count=True)
  inset     地図の左下に小さな地球儀と、いま見ている所の赤い枠
  地図の層: route(点線が伸びて先に光る印)・fill の wipe="north" など(領土が広がる)・塗りが出るとき光が走る
"""
from __future__ import annotations

import math
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from . import overlay as ov
from . import worldmap as wm
from .config import H, W

XF = 0.6


def _ease(u: float) -> float:
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def ortho(lon: float, lat: float, lon0: float, lat0: float):
    """正射図法: 地球儀の上の (x, y)(半径 1)。裏側なら None。"""
    la, lo, la0, lo0 = map(math.radians, (lat, lon, lat0, lon0))
    cosc = math.sin(la0) * math.sin(la) + math.cos(la0) * math.cos(la) * math.cos(lo - lo0)
    if cosc < 0:
        return None
    return math.cos(la) * math.sin(lo - lo0), math.cos(la0) * math.sin(la) - math.sin(la0) * math.cos(la) * math.cos(lo - lo0)


@lru_cache(maxsize=64)
def _globe_small_cached(lon: float, lat: float, sz: int) -> Image.Image:
    import cv2
    world, ppd = _world()
    R = sz / 2 * 0.92
    yy, xx = np.mgrid[0:sz, 0:sz].astype(np.float32)
    x, y = (xx - sz / 2) / R, -(yy - sz / 2) / R
    rho2 = x * x + y * y
    z = np.sqrt(np.clip(1 - rho2, 0, 1))
    la0, lo0 = math.radians(lat), math.radians(lon)
    la = np.arcsin(np.clip(z * math.sin(la0) + y * math.cos(la0), -1, 1))
    lo = lo0 + np.arctan2(x, z * math.cos(la0) - y * math.sin(la0))
    mx = (((np.degrees(lo) + 180) % 360) * ppd).astype(np.float32)
    my = ((90 - np.degrees(la)) * ppd).astype(np.float32)
    col = cv2.remap(world, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)
    col = col * np.clip(0.45 + 0.7 * (x * -0.4 + y * 0.3 + z * 0.85), 0.3, 1.15)[..., None]
    a = np.clip((1 - np.sqrt(rho2)) * R, 0, 1) * 255
    rgba = np.dstack([np.clip(col, 0, 255), a]).astype(np.uint8)
    im = Image.fromarray(rgba, "RGBA")
    ImageDraw.Draw(im).ellipse([sz / 2 - R, sz / 2 - R, sz / 2 + R, sz / 2 + R], outline=(140, 190, 255, 200), width=2)
    return im


def globe_small(center, sz: int) -> Image.Image:
    return _globe_small_cached(round(center[0], 1), round(center[1], 1), sz)


# ---- 粒・色 -------------------------------------------------------------------------------------

def particles(img: Image.Image, kind: str, t: float) -> None:
    """雪・砂ぼこり・火の粉。決まった乱数で、時刻だけで位置が決まる(どのコマから描いても同じ)。"""
    rng = np.random.default_rng({"snow": 1, "dust": 2, "embers": 3}[kind])
    n = {"snow": 260, "dust": 140, "embers": 90}[kind]
    x0, y0 = rng.uniform(0, W, n), rng.uniform(0, H, n)
    sp = rng.uniform(0.5, 1.5, n)
    sz = rng.uniform(1.5, 4.5, n)
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    if kind == "snow":
        xs = (x0 + np.sin(t * 0.8 + x0) * 25 + t * 30 * sp) % W
        ys = (y0 + t * 70 * sp) % H
        col, al = (255, 255, 255), 0.85
    elif kind == "dust":
        xs = (x0 + t * 120 * sp) % W
        ys = (y0 + np.sin(t * 0.5 + y0) * 20) % H
        col, al = (230, 200, 150), 0.35
        sz = sz * 1.6
    else:
        xs = (x0 + np.sin(t + x0) * 30) % W
        ys = (y0 - t * 60 * sp) % H
        col, al = (255, 170, 80), 0.8
    for x, y, r, s_ in zip(xs, ys, sz, sp):
        d.ellipse([x - r, y - r, x + r, y + r], fill=col + (int(255 * al * min(1, s_)),))
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(0.8)))


def grade(img: Image.Image, kind: str) -> None:
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    if kind == "old":
        g = a @ np.array([0.30, 0.59, 0.11], np.float32)
        sep = np.stack([g * 1.07 + 18, g * 0.95 + 8, g * 0.78], axis=-1)
        a = a * 0.35 + sep * 0.65
    elif kind == "cold":
        a = a * np.array([0.92, 0.98, 1.08], np.float32)
    elif kind == "warm":
        a = a * np.array([1.08, 1.0, 0.9], np.float32)
    img.paste(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA"), (0, 0))


# ---- 地球儀 ---------------------------------------------------------------------------------

@lru_cache(maxsize=1)
def _world():
    """全世界の衛星写真(1 度 11.4 画素)と、国ごとの塗りの番号の絵。"""
    import cv2
    ppd = 4096 / 360
    img = wm.bluemarble((-180, -90, 180, 90), ppd).astype(np.float32)
    return img, ppd


@lru_cache(maxsize=8)
def _world_mask(code: str) -> np.ndarray:
    import cv2
    img, ppd = _world()
    m = np.zeros(img.shape[:2], np.uint8)
    for r in wm.shapes(code):
        cv2.fillPoly(m, [np.array([((x + 180) * ppd, (90 - y) * ppd) for x, y in r], np.int32)], 255, lineType=cv2.LINE_AA)
    return m


def draw_globe(img: Image.Image, sc: dict, u: float) -> None:
    import cv2
    world, ppd = _world()
    c0 = sc.get("center", (-70, -30))
    c1 = sc.get("to", c0)
    k = _ease(u)
    lon0, lat0 = c0[0] + (c1[0] - c0[0]) * k, c0[1] + (c1[1] - c0[1]) * k
    R = sc.get("r", 0.42) * H * (1 + 0.04 * k)
    cx, cy = W / 2 + sc.get("dx", 0.0) * W, H / 2
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    x, y = (xx - cx) / R, -(yy - cy) / R
    rho2 = x * x + y * y
    inside = rho2 <= 1
    z = np.sqrt(np.clip(1 - rho2, 0, 1))
    la0, lo0 = math.radians(lat0), math.radians(lon0)
    lat = np.arcsin(np.clip(z * math.sin(la0) + y * math.cos(la0), -1, 1))
    lon = lo0 + np.arctan2(x, z * math.cos(la0) - y * math.sin(la0))
    mx = ((np.degrees(lon) + 180) % 360) * ppd
    my = (90 - np.degrees(lat)) * ppd
    col = cv2.remap(world, mx.astype(np.float32), my.astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)
    sea = (col.sum(axis=2) < 60)[..., None]
    col = np.where(sea, col * 0.6 + np.array([10, 30, 70], np.float32) * 0.6, col)
    if sc.get("hl"):
        m = cv2.remap(_world_mask(sc["hl"]), mx.astype(np.float32), my.astype(np.float32), cv2.INTER_LINEAR).astype(np.float32)[..., None] / 255
        a = min(1.0, u * 3)
        col = col * (1 - 0.55 * m * a) + np.array(ov.RED, np.float32) * 0.55 * m * a
    light = np.clip(0.35 + 0.75 * (x * -0.45 + y * 0.35 + z * 0.82), 0.25, 1.15)[..., None]
    col = col * light
    # 背景(宇宙)と大気の光
    bg = np.zeros((H, W, 3), np.float32)
    bg[...] = np.array([4, 8, 18], np.float32)
    rng = np.random.default_rng(3)
    sx, sy = rng.integers(0, W, 500), rng.integers(0, H, 500)
    bg[sy, sx] = rng.uniform(80, 220, (500, 1))
    rr = np.sqrt(rho2)
    glow = np.clip(1 - (rr - 1) / 0.08, 0, 1) * (rr > 1)
    bg += glow[..., None] * np.array([70, 140, 255], np.float32) * 0.8
    out = np.where(inside[..., None], col, bg)
    img.paste(Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).convert("RGBA"), (0, 0))


# ---- 地形の箱(断面) -------------------------------------------------------------------------

def draw_block(img: Image.Image, mp: "wm.Map", sc: dict, t: float) -> None:
    """地図を描いてから、切る緯度より手前と左右の外を消し、手前の面に断面(海・地殻・沈みこむ板)を描く。"""
    import cv2
    v = mp.view(*sc["view"])
    r0 = mp.relief
    mp.relief = sc.get("relief", 0.13)                      # 箱は山を強めに
    base = mp.base_img(v, t)
    mp.relief = r0
    v.hfun = mp.height
    lat_s = sc["lat"]
    lo0, lo1 = sc["lon"]
    # 地面のうち箱の上の面(切る緯度より北・左右の内側)
    b, lv = mp.best(v)
    m = np.zeros(b.levels[lv].shape[:2], np.uint8)
    x0, y0 = b.xy(lo0, lat_s + sc.get("depth_lat", 6))
    x1, y1 = b.xy(lo1, lat_s)
    f = 2 ** lv
    cv2.rectangle(m, (int(x0 / f), int(y0 / f)), (int(x1 / f), int(y1 / f)), 255, -1)
    top = mp._gather(mp._warp(b, v, m, lv, 0, ext=True), fill=0).astype(np.float32)[..., None] / 255
    bgc = np.zeros((H, W, 3), np.float32)
    g = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    bgc[...] = np.array([10, 16, 30], np.float32) * (1 - g) + np.array([26, 34, 52], np.float32) * g
    out = base.astype(np.float32) * top + bgc * (1 - top)
    im = Image.fromarray(out.astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(im, "RGBA")
    # 手前の面: 地面の高さの線から、下の決まった深さまで
    n = 240
    lons = np.linspace(lo0, lo1, n)
    prof = [mp.height(lo, lat_s) for lo in lons]
    pts_top, pts_flat = [], []
    for lo, e in zip(lons, prof):
        X, Y = v.ground(lo, lat_s)
        q = v.M @ np.array([X, Y, 1.0])
        sx, sy = q[0] / q[2], q[1] / q[2]
        scale = v.relief_px * v.D / q[2] / 6000 if v.relief_px > 0 else 0.008
        pts_flat.append((sx, sy, scale))
        pts_top.append((sx, sy - e * scale))
    depth_m = sc.get("depth_m", 16000)
    bottom = [(x, y + depth_m * s) for x, y, s in pts_flat]
    # 海(海面より下で地面より上)
    for i in range(n - 1):
        if prof[i] < 0 or prof[i + 1] < 0:
            (xa, ya, sa), (xb, yb, sb) = pts_flat[i], pts_flat[i + 1]
            d.polygon([(xa, ya), (xb, yb), pts_top[i + 1], pts_top[i]], fill=(30, 80, 150, 235))
    # 地殻
    poly = pts_top + bottom[::-1]
    d.polygon(poly, fill=(120, 92, 66, 255))
    # 地層の帯
    for frac, c in ((0.35, (104, 78, 56, 255)), (0.7, (86, 62, 44, 255))):
        seg = []
        for (x, y, s), (_, yt) in zip(pts_flat, pts_top):
            yb = y + depth_m * s * frac
            if yb > yt + 4:                                # 地面より下だけ(海の中には引かない)
                seg.append((x, yb))
            elif len(seg) > 1:
                d.line(seg, fill=c, width=3)
                seg = []
            else:
                seg = []
        if len(seg) > 1:
            d.line(seg, fill=c, width=3)
    if sc.get("plate"):                                    # 沈みこむ海の板(海溝から東へ斜めに)
        tr = sc.get("trench", lo0 + (lo1 - lo0) * 0.25)
        i0 = int((tr - lo0) / (lo1 - lo0) * (n - 1))
        k = _ease(min(1.0, sc.get("_u", 1.0) * 1.5))
        up, lo_ = [], []
        e_tr = prof[i0]
        for i in range(n):
            x, y, s = pts_flat[i]
            if i <= i0:                                    # 海溝より西は海の底のすぐ下
                yy = pts_top[i][1] + 250 * s
            else:                                          # 海溝から東へ斜めに沈む
                yy = y + (-e_tr + 250 + (i - i0) / (n - i0) * depth_m * 1.1) * s
            yb = bottom[i][1]
            up.append((x, min(yy, yb)))
            lo_.append((x, min(yy + 3000 * s, yb)))
        m_ = max(2, int(n * k))
        d.polygon(up[:m_] + lo_[:m_][::-1], fill=(50, 60, 90, 255))
        d.line(up[:m_], fill=(140, 170, 230, 255), width=3)
    d.line(pts_top, fill=(255, 255, 255, 230), width=3)
    d.line([pts_top[0], bottom[0]], fill=(255, 255, 255, 120), width=2)
    d.line([pts_top[-1], bottom[-1]], fill=(255, 255, 255, 120), width=2)
    img.paste(im, (0, 0))
    for lab in sc.get("labels", []):                       # 断面の札: (経度, 深さ m(負は地下), 字)
        lo, e, text = lab
        X, Y = v.ground(lo, lat_s)
        q = v.M @ np.array([X, Y, 1.0])
        s = v.relief_px * v.D / q[2] / 6000 if v.relief_px > 0 else 0.008
        dd = ImageDraw.Draw(img)
        dd.text((q[0] / q[2], q[1] / q[2] - e * s), text, font=ov.font(40), fill=ov.WHITE, anchor="mm", stroke_width=6, stroke_fill=ov.NAVY)
        ov.BOXES.append(("label", dd.textbbox((q[0] / q[2], q[1] / q[2] - e * s), text, font=ov.font(40), anchor="mm"), text, 1.0))


# ---- 絵・札・年表 -----------------------------------------------------------------------------

@lru_cache(maxsize=16)
def _photo(path: str) -> Image.Image:
    return Image.open(path).convert("RGB")


def draw_illust(img: Image.Image, sc: dict, u: float) -> None:
    ph = _photo(str(sc["path"]))
    x0, y0, x1, y1 = sc.get("pan", (0.0, 0.0, 0.06, 0.04))
    z0, z1 = sc.get("zoom", (1.04, 1.14))
    k = _ease(u) * 0.85 + u * 0.15
    z = z0 + (z1 - z0) * k
    cw, ch = ph.width / z, ph.width / z * H / W
    if ch > ph.height:
        ch = ph.height / z
        cw = ch * W / H
    ox = (ph.width - cw) * (0.5 + (x0 + (x1 - x0) * k) - 0.03)
    oy = (ph.height - ch) * (0.5 + (y0 + (y1 - y0) * k) - 0.02)
    ox, oy = max(0, min(ph.width - cw, ox)), max(0, min(ph.height - ch, oy))
    fr = ph.resize((W, H), Image.BICUBIC, box=(ox, oy, ox + cw, oy + ch))
    a = np.asarray(fr).astype(np.float32)
    g = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    a *= 1 - 0.55 * np.clip((g - 0.55) / 0.45, 0, 1)            # 下を暗く(字幕が読めるように)
    img.paste(Image.fromarray(a.astype(np.uint8)).convert("RGBA"), (0, 0))
    d = ImageDraw.Draw(img)
    f = ov.font(28)
    d.text((W - 36, H - 40 if W > H else 260), "イメージ", font=f, fill=(230, 230, 230), anchor="rd", stroke_width=3, stroke_fill=ov.NAVY)
    if sc.get("title"):
        a2 = _ease(u * 4)
        size = int(sc.get("size", 120) * (1.12 - 0.12 * a2))
        y = sc.get("y", 0.30) * H
        d.text((W / 2, y), sc["title"], font=ov.font(size), fill=ov.YEL + (int(255 * a2),), anchor="mm", stroke_width=10, stroke_fill=ov.NAVY)
        ov.BOXES.append(("label", d.textbbox((W / 2, y), sc["title"], font=ov.font(size), anchor="mm"), sc["title"], 1.0))
        if sc.get("sub"):
            d.text((W / 2, y + size * 0.95), sc["sub"], font=ov.font(52), fill=ov.WHITE, anchor="mm", stroke_width=6, stroke_fill=ov.NAVY)


def _blur_back(img: Image.Image, mp, sc: dict, t: float) -> None:
    if mp is not None and sc.get("view"):
        v = mp.view(*sc["view"])
        b = Image.fromarray(mp.base_img(v, t))
        b = b.resize((W // 4, H // 4)).filter(ImageFilter.GaussianBlur(6)).resize((W, H), Image.BICUBIC)
        a = np.asarray(b).astype(np.float32) * 0.45 + np.array([8, 14, 30], np.float32) * 0.55
        img.paste(Image.fromarray(a.astype(np.uint8)).convert("RGBA"), (0, 0))
    else:
        g = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
        a = np.array([12, 20, 42], np.float32) * (1 - g) + np.array([26, 40, 72], np.float32) * g
        img.paste(Image.fromarray(np.broadcast_to(a, (H, W, 3)).astype(np.uint8)).convert("RGBA"), (0, 0))


def draw_card(img: Image.Image, mp, sc: dict, t: float, u: float) -> None:
    _blur_back(img, mp, sc, t)
    d = ImageDraw.Draw(img)
    a = _ease(u * 5)
    big = sc["big"]
    if sc.get("count", True):
        from .worldmap import count_text
        big = count_text(big, min(1.0, u * sc.get("_dur", 3.0) / 0.9))     # 0.9 秒で数え上がる
    rows = sc["big"].split("\n")
    size = sc.get("size", 230 if W > H else 190)
    while size > 60 and max(ov.font(size).getlength(r) for r in rows) > W * 0.86:   # 幅に収める
        size -= 6
    size = int(size * (1.15 - 0.15 * a))
    f = ov.font(size)
    lh = size * 1.12
    cy = H * (0.40 if W > H else 0.36)
    y0 = cy - lh * (len(rows) - 1) / 2
    for j, r in enumerate(big.split("\n")):
        d.text((W / 2, y0 + j * lh), r, font=f, fill=tuple(sc.get("color", ov.YEL)) + (int(255 * a),), anchor="mm", stroke_width=10, stroke_fill=ov.NAVY)
        ov.BOXES.append(("label", d.textbbox((W / 2, y0 + j * lh), r, font=f, anchor="mm"), r, 1.0))
    top, bot = y0 - size * 0.5, y0 + lh * (len(rows) - 1) + size * 0.5
    if sc.get("sub"):
        d.text((W / 2, top - 52), sc["sub"], font=ov.font(56 if W > H else 48), fill=ov.DIM, anchor="mm")
    if sc.get("note"):
        b2 = _ease(u * 3 - 0.5)
        d.text((W / 2, bot + 70), sc["note"], font=ov.font(60 if W > H else 50), fill=(255, 255, 255, int(255 * b2)), anchor="mm", stroke_width=6, stroke_fill=ov.NAVY)
    # 数字の下に伸びる線(動きを足す)
    L = W * 0.32 * _ease(u * 2.5)
    d.line([(W / 2 - L / 2, bot + 8), (W / 2 + L / 2, bot + 8)], fill=ov.YEL, width=6)


def draw_cards(img: Image.Image, mp, sc: dict, t: float, u: float) -> None:
    """答えの並べ直し: 番号つきのカードを上から。items=[(題, 添え書き)]、n=いま何枚目まで、groups=[(最初, 最後, 括弧の字)]。"""
    _blur_back(img, mp, sc, t)
    items, n = sc["items"], sc.get("n", len(sc["items"]))
    land = W > H
    x0, x1 = (W * 0.18, W * 0.82) if land else (W * 0.07, W * 0.93)
    top, gap = (H * 0.13, H * 0.155) if land else (H * 0.22, H * 0.12)
    hh = gap * 0.8
    d = ImageDraw.Draw(img, "RGBA")
    for i, (title, sub) in enumerate(items[:n]):
        a = 1.0 if i < n - 1 or sc.get("still") else _ease(u * 4)
        y = top + i * gap + (1 - a) * 30
        d.rounded_rectangle([x0, y, x1, y + hh], 18, fill=ov.NAVY + (int(225 * a),), outline=ov.YEL + (int(255 * a),) if i == n - 1 and not sc.get("still") else (255, 255, 255, int(110 * a)), width=3)
        d.ellipse([x0 + 20, y + hh / 2 - 34, x0 + 88, y + hh / 2 + 34], fill=ov.YEL + (int(255 * a),))
        d.text((x0 + 54, y + hh / 2), str(i + 1), font=ov.font(46), fill=ov.NAVY, anchor="mm")
        d.text((x0 + 112, y + hh / 2 - (16 if sub else 0)), title, font=ov.font(46 if land else 40), fill=(255, 255, 255, int(255 * a)), anchor="lm")
        if sub:
            d.text((x0 + 112, y + hh / 2 + 30), sub, font=ov.font(30), fill=ov.DIM + (int(255 * a),), anchor="lm")
        ov.BOXES.append(("label", (x0, y, x1, y + hh), title, 1.0))
    for (i0, i1, text) in sc.get("groups", []):
        if i1 >= n:
            continue
        ya, yb = top + i0 * gap, top + i1 * gap + hh
        xb = x1 + 26
        d.line([(xb - 14, ya), (xb, ya), (xb, yb), (xb - 14, yb)], fill=ov.YEL, width=5)
        d.text((xb + 18, (ya + yb) / 2), text, font=ov.font(48 if land else 34), fill=ov.YEL, anchor="lm", stroke_width=5, stroke_fill=ov.NAVY)


def draw_timeline(img: Image.Image, mp, sc: dict, t: float, u: float) -> None:
    _blur_back(img, mp, sc, t)
    items = sc["items"]
    cur = sc.get("cur", len(items) - 1)
    if H > W:                                              # 縦の画面は年表を縦に並べる
        d = ImageDraw.Draw(img)
        x = W * 0.24
        y0, y1 = H * 0.18, H * 0.70
        grow = _ease(u * 2)
        d.line([(x, y0), (x, y0 + (y1 - y0) * grow)], fill=(200, 210, 230), width=6)
        for i, (yr, name) in enumerate(items):
            y = y0 + (y1 - y0) * i / max(1, len(items) - 1)
            if y > y0 + (y1 - y0) * grow + 1:
                continue
            on = i == cur
            r = 20 if on else 12
            d.ellipse([x - r, y - r, x + r, y + r], fill=ov.YEL if on else (220, 226, 240), outline=ov.NAVY, width=3)
            d.text((x + 44, y - 4), str(yr), font=ov.font(64 if on else 46), fill=ov.YEL if on else ov.WHITE, anchor="ls", stroke_width=5, stroke_fill=ov.NAVY)
            d.text((x + 44, y + 12), name, font=ov.font(42 if on else 34), fill=ov.WHITE if on else ov.DIM, anchor="lt", stroke_width=4, stroke_fill=ov.NAVY)
            ov.BOXES.append(("label", (x + 44, y - 60, x + 500, y + 50), str(yr), 1.0))
        return
    y0s = [it[0] for it in items]
    lo, hi = min(y0s), max(y0s)
    pad = W * 0.08
    cy = H * (0.45 if W > H else 0.42)

    def X(yr):
        return pad + (W - 2 * pad) * (yr - lo) / max(1, hi - lo)

    d = ImageDraw.Draw(img)
    grow = _ease(u * 2)
    d.line([(pad, cy), (pad + (W - 2 * pad) * grow, cy)], fill=(200, 210, 230), width=6)
    for i, (yr, name) in enumerate(items):
        x = X(yr)
        if x > pad + (W - 2 * pad) * grow + 1:
            continue
        on = i == cur
        r = 18 if on else 11
        d.ellipse([x - r, cy - r, x + r, cy + r], fill=ov.YEL if on else (220, 226, 240), outline=ov.NAVY, width=3)
        up = (i % 2 == 0)
        f1, f2 = ov.font(54 if on else 40), ov.font(40 if on else 32)
        ty = cy - 70 if up else cy + 70
        d.text((x, ty), str(yr), font=f1, fill=ov.YEL if on else ov.WHITE, anchor="md" if up else "ma", stroke_width=5, stroke_fill=ov.NAVY)
        ty2 = ty - 62 if up else ty + 62
        d.text((x, ty2), name, font=f2, fill=ov.WHITE if on else ov.DIM, anchor="md" if up else "ma", stroke_width=4, stroke_fill=ov.NAVY)
        ov.BOXES.append(("label", d.textbbox((x, ty), str(yr), font=f1, anchor="md" if up else "ma"), str(yr), 1.0))


# ---- 振り分け --------------------------------------------------------------------------------

def _scenes(ctx):
    lines, defs = ctx["lines"], ctx["defs"]
    sc = ctx.setdefault("_wscenes", [])
    if not sc:
        cur = None
        for l in lines:
            d = defs.get(l["id"], {})
            if d.get("scene") is not None:
                cur = d["scene"]
            sc.append(cur)
    return sc


def render_one(img: Image.Image, mp, t: float, ctx: dict, i: int, steps=None) -> None:
    lines = ctx["lines"]
    sc = _scenes(ctx)[i]
    shot = (sc or {}).get("shot", "map")
    l = lines[i]
    # 場面の始まり(同じ scene が続く行はまとめて 1 つの場面)
    j = i
    while j > 0 and _scenes(ctx)[j - 1] is sc:
        j -= 1
    t0 = lines[j]["start"]
    k = i
    while k + 1 < len(lines) and _scenes(ctx)[k + 1] is sc:
        k += 1
    t1 = lines[k]["end"]
    u = max(0.0, min(1.0, (t - t0) / max(1e-6, t1 - t0)))
    if shot == "map":
        mp.draw(img, t, dict(ctx, cur=l), steps=steps)
    elif shot == "globe":
        draw_globe(img, sc, u)
    elif shot == "block":
        draw_block(img, mp, dict(sc, _u=u), t)
    elif shot == "illust":
        draw_illust(img, sc, u)
    elif shot == "card":
        draw_card(img, mp, dict(sc, _dur=t1 - t0), t, u)
    elif shot == "timeline":
        draw_timeline(img, mp, sc, t, u)
    elif shot == "cards":
        draw_cards(img, mp, sc, t, (t - l["start"]) / max(1e-6, l["end"] - l["start"]))
    elif shot == "split":
        halves = []
        for side in ("left", "right"):
            s2 = sc[side]
            tmp = Image.new("RGBA", (W, H))
            fake = dict(ctx, cur=l, _wscenes=[s2] * len(lines))
            mp.draw(tmp, t, fake)
            halves.append(tmp.crop((W // 4, 0, W // 4 + W // 2, H)))
        img.paste(halves[0], (0, 0))
        img.paste(halves[1], (W // 2, 0))
        d = ImageDraw.Draw(img)
        d.line([(W // 2, 0), (W // 2, H)], fill=(255, 255, 255), width=4)
        for k2, side in enumerate(("left", "right")):
            tt = sc[side].get("title")
            if tt:
                d.text((W // 4 + k2 * W // 2, 120), tt, font=ov.font(64), fill=ov.YEL, anchor="mm", stroke_width=8, stroke_fill=ov.NAVY)
    if (sc or {}).get("grade"):
        grade(img, sc["grade"])
    if (sc or {}).get("fx"):
        particles(img, sc["fx"], t)
    if steps and (sc or {}).get("step") is not None and shot != "map":
        mp.steps_band(img, steps, sc["step"])


def draw(img: Image.Image, t: float, ctx: dict, mp, steps=None) -> None:
    """計算の回の draw から呼ぶ。ショートが変わる行の頭は前のショートと溶け合わせる。"""
    lines = ctx["lines"]
    cur = ctx["cur"] or lines[0]
    i = next(j for j, l in enumerate(lines) if l["id"] == cur["id"])
    scs = _scenes(ctx)
    render_one(img, mp, t, ctx, i, steps)
    if i > 0 and scs[i] is not scs[i - 1]:
        a = (scs[i] or {}).get("shot", "map")
        b = (scs[i - 1] or {}).get("shot", "map")
        dt = t - cur["start"]
        tr = (scs[i] or {}).get("tr", "fade")
        if ((a != "map" or b != "map") or tr != "fade") and dt < XF:
            prev = Image.new("RGBA", (W, H))
            bx = list(ov.BOXES)
            render_one(prev, mp, t, ctx, i - 1, steps)
            ov.BOXES[:] = bx
            transition(img, prev, tr, dt / XF)


def transition(img: Image.Image, prev: Image.Image, tr: str, u: float) -> None:
    """前のショット prev から今の img へ。u は 0〜1。"""
    k = _ease(u)
    if tr == "zoom":                                       # 前の絵の真ん中へ寄って抜ける
        z = 1 + 0.6 * k
        cw, ch = W / z, H / z
        pz = prev.resize((W, H), Image.BICUBIC, box=((W - cw) / 2, (H - ch) / 2, (W + cw) / 2, (H + ch) / 2))
        cur = img.copy()
        z2 = 1.25 - 0.25 * k                               # 今の絵は少し寄った所から戻る
        cw, ch = W / z2, H / z2
        cur = cur.resize((W, H), Image.BICUBIC, box=((W - cw) / 2, (H - ch) / 2, (W + cw) / 2, (H + ch) / 2))
        img.paste(Image.blend(pz, cur, k), (0, 0))
    elif tr == "whip":                                     # 横に流れてぶれる
        off = int(W * k)
        both = Image.new("RGBA", (W * 2, H))
        both.paste(prev, (0, 0))
        both.paste(img, (W, 0))
        fr = both.crop((off, 0, off + W, H))
        blur = int(60 * math.sin(math.pi * k))
        if blur > 1:
            import cv2
            a = np.asarray(fr)
            ker = np.ones((1, blur), np.float32) / blur
            fr = Image.fromarray(cv2.filter2D(a, -1, ker))
        img.paste(fr, (0, 0))
    elif tr == "flash":                                    # 白く光って変わる
        base = prev if k < 0.5 else img.copy()
        w = 1 - abs(k - 0.5) * 2
        white = Image.new("RGBA", (W, H), (255, 255, 255, 255))
        img.paste(Image.blend(base, white, w * 0.85), (0, 0))
    else:
        img.paste(Image.blend(prev, img, k), (0, 0))


def sfx(lines_def, L) -> list:
    """ショートが変わる所(切り替えの種類で音を変える)・札や層が出る所・数字の札の「ドン」と数え上げ。"""
    from . import worldmap as wm_
    ev = []
    prev = None
    for d in lines_def:
        sc = d.get("scene")
        if d["id"] not in L or sc is None or sc is prev:
            continue
        l = L[d["id"]]
        tr = sc.get("tr", "fade")
        shot = sc.get("shot", "map")
        if prev is not None:
            ev.append((l["start"], {"whip": "swish", "flash": "impact"}.get(tr, "whoosh")))
        if shot == "card":
            ev.append((l["start"] + 0.05, "impact"))
            if any(c.isdigit() for c in sc.get("big", "")):
                ev.append((l["start"] + 0.1, "tick"))
        prev_ids = {x.get("id") for x in (prev or {}).get("layers", [])}
        for x in sc.get("layers", []):
            if x.get("id") in prev_ids:
                continue
            t0 = wm_.start_of(x, [l], l)
            if x["kind"] in ("label", "pin", "ghost", "fill"):
                ev.append((t0, "pop"))
            if x.get("count"):
                ev.append((t0, "tick"))
        prev = sc
    return sorted(set(ev))
