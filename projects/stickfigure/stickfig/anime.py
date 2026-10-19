"""アニメっぽい演出(合成の側)。台本の `anime:` で有効になる。

- 軌跡: 剣先・足・手が速く動く間、光る弧(尾を引く線)を描く(斬撃・蹴りの軌跡)
- 擬音: 命中に「ドガッ!!」などの大きな文字を、飛び出す動きで出す
- ズームブラー: 命中の最初の数コマ、衝撃の中心から放射状にぼかす
- 仕上げ: 発光(ブルーム)・四隅を暗く(ビネット)・コントラスト・命中での画面の傾き(roll)
カメラの「ズームパンチ」と傾きは plan(plan.py)が出す。ここは画面に描く部分。

台本:
  anime: {trails: true, sfx: true, zoom_blur: true, grade: true,
          trail_speed: 0.09, sfx_text: {kick: "ドガッ!!"}, roll: true}
"""
from __future__ import annotations

import math
from typing import Dict, List, Optional, Sequence, Tuple

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

from . import camera, fk

W, H = 1280, 720
FONT = "C:/Windows/Fonts/YuGothB.ttc"
SFX = dict(kick="ドガッ!!", slash="ザンッ!", hit="バシッ!", wall="ドゴォォン!!", land="ズサァッ", land2="ズザッ", heel="ドガァッ!!", clash="ガキィン!", miss="ヒュッ", beam="ドォォォン!!")
SFX_COLOR = dict(kick=(255, 226, 60), slash=(120, 235, 255), hit=(255, 226, 60), wall=(255, 150, 60), land=(235, 235, 235), land2=(235, 235, 235), heel=(255, 110, 70), clash=(255, 250, 200), miss=(210, 210, 220))
SFX_SIZE = dict(kick=140, slash=120, hit=110, wall=140, land=85, land2=75, heel=150, clash=125, miss=70, beam=160)
TRAIL_COLOR = dict(A=(150, 255, 200), B=(255, 140, 110))
# カメラの演出(plan.py が使う): 命中の種類ごとの「寄る量」と「傾き(度)」
ZOOM_PUNCH = dict(kick=0.13, slash=0.07, hit=0.06, wall=0.09, heel=0.12, clash=0.09, miss=0.02, beam=0.1)
ROLL_SHAKE = dict(kick=2.6, slash=1.8, hit=1.4, wall=3.4, heel=3.0, clash=2.2, miss=0.0, beam=2.4)


def _font(px: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(FONT, px)
    except OSError:
        return ImageFont.load_default()


def effector_world(plan: dict, who: str, f: int) -> Dict[str, Tuple[float, float]]:
    """人物 who の、f コマ目の剣先・手・足の世界座標(x, z)。"""
    a = plan["actors"][who]
    p = plan["frames"][f]["actors"][who]
    s = 1 if a.get("facing", 1) >= 0 else -1
    sk = fk.skeleton(p, s, p["root_x"], a.get("scale", 1.0))
    out = {"hand": sk["hand"], "foot": sk["foot"], "rear_foot": sk["rear_foot"]}
    if a.get("weapon"):
        out["tip"] = sk["tip"]
    return out


def chaikin(pts: List[Tuple[float, float]], it: int = 2) -> List[Tuple[float, float]]:
    """折れ線の角を落としてなめらかにする(コマ間が離れた速い動きの弧が、角張らないように)。"""
    for _ in range(it):
        if len(pts) < 3:
            break
        out = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
            out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        out.append(pts[-1])
        pts = out
    return pts


def trails(plan: dict, f: int, cfg: dict, cache: Dict[Tuple[str, int], dict]) -> Optional[Image.Image]:
    """速く動く剣先・足・手の、光る弧。RGB の加算用の層を返す(黒地)。"""
    fps = plan["fps"]
    n = int(cfg.get("trail_frames", 9))
    thr = cfg.get("trail_speed", 0.22)            # 身長/コマ。これより速い間だけ描く(0.15 だと受け止めの前の歩み寄りで剣先がジグザグの線を床に残した)
    layer = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(layer)
    drew = False
    cam = plan["frames"][f]["cam"]
    for who in plan["actors"]:
        # 打つ側の、命中の前後だけ(走りで剣先が速いだけの所に出ると、床にジグザグの線が残る。2026-10-19 fight_mix の冒頭で確認)
        strikers = [e for e in plan.get("events", []) if e.get("by")]
        mine = [e for e in strikers if e["by"] == who and e["frame"] - 8 <= f <= e["frame"] + 3]
        if strikers and not mine:
            continue
        want = None
        if mine:                                          # 打つ手足だけ(蹴りは足、斬り・拳は手と剣先。踏み込みの足に出ると床にジグザグが残る)
            want = {"foot"} if any(e["kind"] in ("kick", "heel") for e in mine) else {"hand", "tip"}
        sc = plan["actors"][who].get("scale", 1.0)
        pts: Dict[str, List[Tuple[float, float]]] = {}
        for k in range(max(0, f - n), f + 1):
            key = (who, k)
            if key not in cache:
                cache[key] = effector_world(plan, who, k)
            for name, p in cache[key].items():
                pts.setdefault(name, []).append(p)
        for name, path in pts.items():
            if len(path) < 3 or (want is not None and name not in want):
                continue
            speed = math.hypot(path[-1][0] - path[-2][0], path[-1][1] - path[-2][1]) / (1.9 * sc)
            if speed < thr:
                continue
            col = TRAIL_COLOR.get(who, (255, 255, 255))
            if name == "tip":
                col = (170, 245, 255)
            scr = chaikin([camera.project(cam, x, 0.0, z)[:2] for x, z in path])
            m = len(scr)
            for i in range(m - 1):
                u = (i + 1) / (m - 1)               # 古い所は細く暗く
                w = (2 + 11 * u * min(1.0, speed / 0.35)) * min(1.0, camera.px_per_unit(cam) / 200.0)     # 画面の大きさに合わせる(近いカメラで太くなりすぎない)
                a = (u ** 1.4)
                c = tuple(int(v * a) for v in col)
                d.line([scr[i], scr[i + 1]], fill=c, width=int(w))
                cw = tuple(int(255 * a) for _ in range(3))        # 芯は白
                d.line([scr[i], scr[i + 1]], fill=cw, width=max(1, int(w * 0.28)))
            drew = True
    if not drew:
        return None
    return layer.filter(ImageFilter.GaussianBlur(2.2))


def sfx_overlay(plan: dict, f: int, cfg: dict) -> Optional[Image.Image]:
    """命中の擬音。命中から約0.45秒、ぽんと大きく出て、少し傾いて消える。RGBA。"""
    texts = dict(SFX, **cfg.get("sfx_text", {}))
    fps = plan["fps"]
    life_max = int(0.3 * fps)                       # 0.45 秒だと次の動作(かわし等)の上に前の擬音が残っていた(fight_dodge 2026-10-19)
    cam = plan["frames"][f]["cam"]
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    any_ = False
    sfx_frames = sorted(e2["frame"] for e2 in plan["events"] if e2["kind"] in texts)
    for idx, e in enumerate(plan["events"]):
        age = f - e["frame"]
        kind = e["kind"]
        nxt = next((x for x in sfx_frames if x > e["frame"]), None)
        life = life_max if nxt is None else max(4, min(life_max, nxt - e["frame"] - 1))   # 次の擬音が出る前に消す
        if kind not in texts or not (0 <= age < life):
            continue
        # 同じ種類の短い間隔の連続は、最初だけ出す
        t = age / life
        pop = 1.0 + 0.28 * math.exp(-age * 0.5) * math.cos(age * 0.9)     # ぽんと出て、少し揺れて収まる
        fade = 1.0 if t < 0.7 else max(0.0, (1.0 - t) / 0.3)
        size = int(SFX_SIZE.get(kind, 120) * pop)
        txt = texts[kind]
        ang = (-9 if idx % 2 == 0 else 7) + 3 * math.sin(age * 0.7)
        font = _font(size)
        tmp = Image.new("RGBA", (W, H // 2), (0, 0, 0, 0))
        td = ImageDraw.Draw(tmp)
        bw = int(size * 0.13)
        td.text((20, 20), txt, font=font, fill=SFX_COLOR.get(kind, (255, 226, 60)), stroke_width=bw, stroke_fill=(15, 10, 20))
        bbox = tmp.getbbox()
        if bbox is None:
            continue
        tmp = tmp.crop(bbox)
        # 白い縁(アニメの擬音の二重縁)
        edge = Image.new("RGBA", (tmp.width + 24, tmp.height + 24), (0, 0, 0, 0))
        ed = ImageDraw.Draw(edge)
        ed.text((12 + bw, 12 + bw), txt, font=font, fill=(255, 255, 255), stroke_width=bw + 6, stroke_fill=(255, 255, 255))
        edge.alpha_composite(tmp.convert("RGBA"), (12, 12))
        edge = edge.rotate(ang, expand=True, resample=Image.BICUBIC)
        px, py, _ = camera.project(cam, e["pos"][0], 0.0, min(e["pos"][1], 3.0) + 0.9)
        px = max(edge.width * 0.5 + 10, min(W - edge.width * 0.5 - 10, px))
        py = max(edge.height * 0.5 + 10, min(H - edge.height * 0.5 - 10, py - 60))
        if fade < 1.0:
            a = edge.split()[3].point(lambda v: int(v * fade))
            edge.putalpha(a)
        out.alpha_composite(edge, (int(px - edge.width / 2), int(py - edge.height / 2)))
        any_ = True
    return out if any_ else None


def zoom_blur(img: Image.Image, cx: float, cy: float, strength: float) -> Image.Image:
    """中心から放射状にぼかす(複数の拡大を重ねる)。strength 0〜1。"""
    if strength <= 0:
        return img
    base = np.asarray(img.convert("RGB"), dtype=np.float32)
    acc = base.copy()
    steps = 6
    for i in range(1, steps + 1):
        k = 1.0 + 0.07 * strength * i / steps
        w, h = int(W / k), int(H / k)
        x0, y0 = int(cx - (cx / k)), int(cy - (cy / k))
        x0 = max(0, min(W - w, x0))
        y0 = max(0, min(H - h, y0))
        crop = img.crop((x0, y0, x0 + w, y0 + h)).resize((W, H), Image.BILINEAR)
        acc += np.asarray(crop.convert("RGB"), dtype=np.float32)
    acc /= steps + 1
    out = base * (1 - 0.7 * strength) + acc * (0.7 * strength)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


_VIG = None


def _vignette() -> np.ndarray:
    global _VIG
    if _VIG is None:
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
        _VIG = (1.0 - 0.38 * np.clip(r - 0.55, 0, 1) ** 1.6)[:, :, None]
    return _VIG


def grade(img: Image.Image, bloom: float = 0.32) -> Image.Image:
    """発光(ブルーム)・コントラスト・彩度・ビネット。"""
    a = np.asarray(img.convert("RGB"), dtype=np.float32) / 255.0
    bloom *= max(0.15, 1.0 - 1.6 * float(a.mean()))          # 全体が明るい(白い閃光のコマ)ときは、発光を弱めて白飛びを防ぐ
    # 発光: 明るい所だけ取り出してぼかし、足す
    lum = a.max(axis=2, keepdims=True)
    bright = a * np.clip((lum - 0.72) / 0.28, 0, 1)
    bl = Image.fromarray(np.clip(bright * 255, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14))
    a = a + np.asarray(bl, dtype=np.float32) / 255.0 * bloom
    # 彩度とコントラスト(S字)
    g = a.mean(axis=2, keepdims=True)
    a = g + (a - g) * 1.18
    a = np.clip(a, 0, 1)
    a = a * a * (3 - 2 * a) * 0.35 + a * 0.65
    a = a * _vignette()
    return Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))


def tilt(img: Image.Image, deg: float) -> Image.Image:
    """画面全体を傾ける(命中の衝撃)。端が欠けないよう、少し拡大する。"""
    if abs(deg) < 0.05:
        return img
    k = 1.0 + abs(math.radians(deg)) * 1.2
    big = img.resize((int(W * k), int(H * k)), Image.BILINEAR).rotate(deg, resample=Image.BICUBIC)
    x0, y0 = (big.width - W) // 2, (big.height - H) // 2
    return big.crop((x0, y0, x0 + W, y0 + H))


def apply(plan: dict, f: int, frame: Image.Image, cfg: dict, cache: dict) -> Image.Image:
    """合成済みの1コマに、アニメの演出を重ねて返す。"""
    img = frame.convert("RGB")
    # 軌跡(加算)
    if cfg.get("trails", True):
        tr = trails(plan, f, cfg, cache)
        if tr is not None:
            img = ImageChops.add(img, tr)
    # ズームブラー(命中の最初の数コマ)
    if cfg.get("zoom_blur", True):
        for e in plan["events"]:
            age = f - e["frame"]
            if e["kind"] in ZOOM_PUNCH and 0 <= age < 4:
                cam = plan["frames"][f]["cam"]
                px, py, _ = camera.project(cam, e["pos"][0], 0.0, e["pos"][1])
                img = zoom_blur(img, px, py, 0.9 * (1 - age / 4))
                break
    # 擬音
    if cfg.get("sfx", True):
        ov = sfx_overlay(plan, f, cfg)
        if ov is not None:
            im = img.convert("RGBA")
            im.alpha_composite(ov)
            img = im.convert("RGB")
    if cfg.get("grade", True):
        img = grade(img, cfg.get("bloom", 0.32))
    if cfg.get("roll", True):
        img = tilt(img, plan["frames"][f]["cam"].get("roll", 0.0))
    return img
