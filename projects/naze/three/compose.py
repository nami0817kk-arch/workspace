"""描いたコマに字(問い・速さのカウンター・スローの表示)と光のにじみを重ね、効果音を合成して mp4 にする。一覧画像も作る。

字は naze.overlay(游ゴシック太字・縁取り)を使う。横長の配置にするため NAZE_ASPECT=landscape で読み込む。
"""
from __future__ import annotations

import os

os.environ.setdefault("NAZE_ASPECT", "landscape")

import math  # noqa: E402
import subprocess  # noqa: E402
import wave  # noqa: E402
from pathlib import Path  # noqa: E402

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

from naze import overlay as ov  # noqa: E402
from naze.config import ffmpeg  # noqa: E402

W, H = 1920, 1080
Q_Y, Q_SIZE = 82, 66                          # 問い(画面の上の真ん中)
COUNTER = (1470, 170, 1880, 330)              # 速さのカウンターの箱(右上)
SLOW = (40, 980)                              # スローの表示(左下)


def text_boxes(question: str) -> dict:
    """字の占める箱(点検で主役と重ならないかを見る)。"""
    f = ov.font(Q_SIZE)
    segs = ov.parse(question)
    w = sum(f.getlength(t) for t, _ in segs)
    lh = int(Q_SIZE * 1.3)
    return dict(question=(W / 2 - w / 2 - 10, Q_Y - lh / 2 - 10, W / 2 + w / 2 + 10, Q_Y + lh / 2 + 6), counter=COUNTER)


def kmh(v: float) -> float:
    return v * 3.6


def counter_value(fr: dict, plan: dict, t: float) -> tuple[float, bool]:
    """表示する速さ(km/h)と、数え上げが終わったか。当たった瞬間から 0.7 秒かけて数字が上がる。"""
    v_hit = plan["v_hit"]
    if t < v_hit:
        return 0.0, False
    k = min(1.0, (t - v_hit) / 0.7)
    e = 1 - (1 - k) ** 3
    return kmh(fr["ball"]["speed"]) * e, k >= 1.0


def bloom(img: Image.Image, thr: float = 0.82, radius: int = 18, gain: float = 0.9) -> Image.Image:
    a = np.asarray(img.convert("RGB"), np.float32) / 255
    lum = a.max(axis=2, keepdims=True)
    hi = np.clip((lum - thr) / (1 - thr), 0, 1) * a
    g = Image.fromarray((hi * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius))
    g2 = Image.fromarray((hi * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius * 3))
    b = np.asarray(g, np.float32) / 255 * gain + np.asarray(g2, np.float32) / 255 * gain * 0.6
    out = 1 - (1 - a) * (1 - np.clip(b, 0, 1))          # スクリーン合成
    return Image.fromarray((out * 255).astype(np.uint8))


def draw_frame(src: Path, fr: dict, plan: dict, sc: dict, grey: bool) -> Image.Image:
    img = Image.open(src).convert("RGB")
    if img.size != (W, H):
        img = img.resize((W, H), Image.LANCZOS)
    if not grey:
        img = bloom(img)
    img = img.convert("RGBA")
    t = fr["i"] / plan["fps"]
    dr = ImageDraw.Draw(img)
    ov.rows(dr, sc["question"], Q_Y, Q_SIZE, maxw=1500, stroke=9)
    # 速さのカウンター
    val, done = counter_value(fr, plan, t)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = COUNTER
    ld.rounded_rectangle(COUNTER, 22, fill=ov.NAVY + (200,), outline=(255, 255, 255, 230), width=4)
    img.alpha_composite(layer)
    dr = ImageDraw.Draw(img)
    dr.text((x0 + 26, y0 + 14), sc.get("counter_label", "速さ"), font=ov.font(34), fill=ov.DIM)
    num = f"{val:,.0f}"
    fn = ov.font(92)
    unit = "km/h"
    fu = ov.font(40)
    wn, wu = fn.getlength(num), fu.getlength(unit)
    xr = x1 - 26
    dr.text((xr - wu, y1 - 26 - 46), unit, font=fu, fill=ov.WHITE)
    dr.text((xr - wu - 14 - wn, y1 - 26 - 104), num, font=fn, fill=ov.YEL, stroke_width=3, stroke_fill=ov.NAVY)
    walls = [e for e in plan["events"] if e["kind"] == "mat"]
    if walls and t >= walls[0]["v"]:
        peak = f"最高 {kmh(plan['v0']):,.0f} km/h"
        f3 = ov.font(34)
        dr.text((x1 - f3.getlength(peak), y1 + 14), peak, font=f3, fill=ov.WHITE, stroke_width=5, stroke_fill=ov.NAVY)
    # スローの表示
    if fr["rate"] < 0.9:
        txt = f"スロー  {1 / fr['rate']:.0f}分の1"
        dr.text(SLOW, txt, font=ov.font(38), fill=ov.WHITE, stroke_width=6, stroke_fill=ov.NAVY)
    return img.convert("RGB")


# ---------------- 効果音(合成) ----------------

def _noise(n, seed):
    return np.random.default_rng(seed).uniform(-1, 1, n)


def _lp(x, a):
    y, s = np.empty_like(x), 0.0
    for i, v in enumerate(x):
        s += a * (v - s)
        y[i] = s
    return y


def snd_hit(sr):
    n = int(0.9 * sr)
    t = np.arange(n) / sr
    crack = _noise(n, 1) * np.exp(-t / 0.012)
    crack = crack - _lp(crack, 0.15)
    thump = np.sin(2 * np.pi * (55 + 90 * np.exp(-t / 0.05)) * t) * np.exp(-t / 0.28)
    boom = _lp(_noise(n, 2), 0.02) * np.exp(-t / 0.35) * 4
    return 0.55 * crack + 0.9 * thump + 0.5 * boom


def snd_whoosh(sr, dur=0.9):
    n = int(dur * sr)
    x = np.arange(n) / n
    r = _noise(n, 3)
    out = _lp(r, 0.08) * 2.5
    return out * np.sin(np.pi * np.minimum(1, x * 1.6)) ** 2 * (1 - x) ** 1.2


def snd_thud(sr, strength=1.0):
    n = int(0.6 * sr)
    t = np.arange(n) / sr
    body = np.sin(2 * np.pi * (70 + 60 * np.exp(-t / 0.04)) * t) * np.exp(-t / 0.18)
    puff = _lp(_noise(n, 4), 0.05) * np.exp(-t / 0.06) * 3
    return strength * (0.9 * body + 0.5 * puff)


def snd_tok(sr, strength):
    n = int(0.15 * sr)
    t = np.arange(n) / sr
    return strength * (np.sin(2 * np.pi * 180 * t) * np.exp(-t / 0.03) + 0.3 * _lp(_noise(n, 5), 0.3) * np.exp(-t / 0.01))


def audio(plan: dict, out: Path, sr: int = 48000) -> Path:
    n = int((plan["n"] / plan["fps"] + 0.5) * sr)
    a = np.zeros(n)

    def put(t, s, g):
        i = int(t * sr)
        j = min(n, i + len(s))
        if 0 <= i < j:
            a[i:j] += s[: j - i] * g

    floor_n = 0
    for e in plan["events"]:
        if e["kind"] == "hit":
            put(e["v"] - 0.01, snd_hit(sr), 0.9)
            put(e["v"] + 0.02, snd_whoosh(sr, 1.4), 0.35)
        elif e["kind"] == "mat":
            put(e["v"], snd_thud(sr, min(1.0, e["speed"] / 30)), 0.9)
        elif e["kind"] == "floor" and floor_n < 6:
            put(e["v"], snd_tok(sr, min(1.0, e["speed"] / 8)), 0.5)
            floor_n += 1
    a = a / max(1e-6, np.abs(a).max()) * 0.89
    st = np.repeat(a[:, None], 2, axis=1)
    with wave.open(str(out), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((st * 32767).astype(np.int16).tobytes())
    return out


# ---------------- まとめ ----------------

def compose(frames_dir: Path, comp_dir: Path, plan: dict, sc: dict, grey: bool, video: Path) -> Path:
    comp_dir.mkdir(parents=True, exist_ok=True)
    for fr in plan["frames"]:
        src = frames_dir / f"{fr['i']:05d}.png"
        dst = comp_dir / f"{fr['i']:05d}.jpg"
        if not src.exists():
            continue
        draw_frame(src, fr, plan, sc, grey).save(dst, quality=93)
    wav = audio(plan, video.with_suffix(".wav"))
    cmd = [ffmpeg(), "-y", "-loglevel", "error", "-framerate", str(plan["fps"]), "-i", str(comp_dir / "%05d.jpg"), "-i", str(wav),
           "-vf", "scale=in_range=pc:out_range=tv", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-color_range", "tv", "-crf", "18", "-preset", "medium", "-c:a", "aac", "-b:a", "192k", "-shortest", str(video)]
    subprocess.run(cmd, check=True)
    return video


def sheet(comp_dir: Path, plan: dict, out: Path, picks: list[int] | None = None, cols: int = 4, tw: int = 480) -> Path:
    """書き出したコマから数枚を抜いて1枚に並べる(目で見る用)。"""
    n = plan["n"]
    a, b = plan["cuts"]
    hit = int(round(plan["v_hit"] * plan["fps"]))
    walls = [int(round(e["v"] * plan["fps"])) for e in plan["events"] if e["kind"] == "mat"]
    w = walls[0] if walls else b + 10
    if picks is None:
        picks = [0, hit - 12, hit - 2, hit, hit + 3, hit + 10, a + 1, (a + b) // 2, b + 1, w - 2, w + 3, n - 1]
    picks = [min(max(0, p), n - 1) for p in picks]
    th = tw * 9 // 16
    rows = math.ceil(len(picks) / cols)
    S = Image.new("RGB", (cols * tw, rows * (th + 30)), (20, 20, 24))
    d = ImageDraw.Draw(S)
    for k, p in enumerate(picks):
        f = comp_dir / f"{p:05d}.jpg"
        if not f.exists():
            continue
        im = Image.open(f).resize((tw, th))
        x, y = (k % cols) * tw, (k // cols) * (th + 30)
        S.paste(im, (x, y + 30))
        fr = plan["frames"][p]
        d.text((x + 6, y + 4), f"#{p} {p / plan['fps']:.2f}s 場面{fr['shot']} 物理{fr['s']:.3f}s", font=ov.font(20), fill=(230, 230, 230))
    S.save(out, quality=92)
    return out
