"""画面の作り(2026-11-20 に決めた形)。字の置き場を決め、真ん中は絵だけ。1 文に 1 枚、同じ場面は数文かけて育てる。

置き場(場面が何でも同じ):
  左上 = その回の問いの札(EP["qtag"])/ 右上 = 出典(素材の sources.json から自動)/ 左下 = 場所・人の札(場面の place)
  上の真ん中 = ずっと出すメーター(EP["meter"]、行の meter=値)/ 下の真ん中 = 字幕(2 行まで。【】の語だけ黄色)

台本の 1 行の書き方(ep.py の lines の 1 つ):
  dict(id, text, say?, scene=dict(kind=..., ...)?, fx=[dict(k=..., ...)]?, meter=値?)
  scene がある行で絵が替わる。無い行は前の場面が続き、fx で足していく(絵を育てる)。
  fx は出たまま場面の終わりまで残る。on="言葉" を書くと、その言葉を言い始めた瞬間に出る(声の時間割から)。

場面(scene の kind):
  map    地図(worldmap)。view=(経度, 緯度, 横幅の度, 傾き) → to=(...) へ場面のあいだに寄る。place=("名前", "添え書き")
  video  実写の映像。src="assets/x.mp4", start=秒。track="person" で歩く人を追う(fx の person が使う)
  photo  写真に奥行きを付けて動かす(Depth Anything)。src, move="in"|"left"|"right"。ai=True なら右上に「イメージ」
  words  黒い地に字だけ。rows=["1 行目", "【2 行目】"]、rows_on=[None, "言葉"](2 行目を出す言葉)
  bars   柱の比べ。items=[dict(name, value, unit, on?)](出る順)。数字は数え上がる。focus=名前 でほかを灰色に
  boxes  予告の空の枠。n=3。fx の fill で枠に絵が入り、expand で画面いっぱいに広がる
  card   用語のカード。title, sub(読みなど), body(定義), src(出典)
  split  左右に並べる。left=dict(src, name), right=dict(src, name)。札の色は EP["colors"] で 1 本の中で固定
  custom 題材の ep.py の関数で描く。fn="名前" → ep の draw_<名前>(img, t, ctx) が RGBA の img に描く

足し方(fx の k):
  route  線が伸びる。pts=[(経度, 緯度)...](地図)か [(x, y)...](画面)、label="約2,000km"、dur=伸びる秒
  note   物から細い線を引いて小さな札。xy=(x, y) か ll=(経度, 緯度)、text
  q      わからない所に「？」。xy か ll、label(下の小さな字)
  dim    絵を暗くする(打ち消しの文で)。amount=0.55
  spot   枠の外を暗くして、注目する所だけ残す。box=(x0, y0, x1, y1)
  person 映像の人を丸で囲んで札(大きさの目安)。text="人"
  fill   boxes の枠 i に絵を入れる。i, src, label
  expand boxes の枠 i を画面いっぱいに広げる(次の場面へつなぐ)
  add    bars の柱を足す(items と同じ形 1 つ)。ratio=dict(text, sub) で比べの札
  focus  bars・split で 1 つだけ濃くする。name
"""
from __future__ import annotations

import json
import math
import re
from functools import lru_cache
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from . import overlay as ov
from .config import FPS, H, W

PORTRAIT = H > W
WHITE, YEL, RED, GRAY = (255, 250, 240), (255, 214, 64), (255, 112, 72), (150, 150, 155)
BLUE = (150, 210, 255)
FONTS = "C:/Windows/Fonts/"
# 置き場(縦はショートの下の題名・右のボタンを避ける)
LAY = dict(
    sub_y=(1430 if PORTRAIT else H - 70), sub_size=(60 if PORTRAIT else 50), sub_maxw=(W - 140 if PORTRAIT else W - 360),
    qtag=(36, 130) if PORTRAIT else (40, 34), credit=(W - 36, 140) if PORTRAIT else (W - 36, 40),
    place=(50, 1140) if PORTRAIT else (60, H - 300), meter=(W / 2, 230) if PORTRAIT else (W / 2, 40),
)
MAX_LABELS = 3                    # 札(note・q・route の字)は同時に 3 つまで。地図に札を散らさない


@lru_cache(maxsize=None)
def F(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONTS + name, size)


def ease(u: float) -> float:
    u = min(max(u, 0.0), 1.0)
    return u * u * (3 - 2 * u)


# ---- 色の調子(全部の場面に同じものをかける) -----------------------------------------------------
_VIG = None


def grade(a: np.ndarray, vig: float = 0.32, seed: int = 0) -> np.ndarray:
    global _VIG
    x = a[..., :3].astype(np.float32) / 255
    x = np.clip((x - 0.5) * 1.12 + 0.5, 0, 1)
    l = x.mean(2, keepdims=True)
    x = x + (1 - l) * np.array([-0.03, 0.01, 0.035]) + l * np.array([0.035, 0.01, -0.03])
    if _VIG is None:
        yy, xx = np.mgrid[0:H, 0:W]
        _VIG = np.clip(np.hypot((xx - W / 2) / (W / 2), (yy - H / 2) / (H / 2)) - 0.45, 0, 1) ** 1.6
    x = x * (1 - vig * _VIG)[..., None] + np.random.default_rng(seed).normal(0, 0.012, (H, W, 1))
    return (np.clip(x, 0, 1) * 255).astype(np.uint8)


def cover(img: np.ndarray, w: int = W, h: int = H, cx: float = 0.5) -> np.ndarray:
    """画面いっぱいに切り出す。cx は横長の素材を縦に切るときの中心(0=左端、1=右端)。"""
    ih, iw = img.shape[:2]
    s = max(w / iw, h / ih)
    img = cv2.resize(img, (round(iw * s) + 1, round(ih * s) + 1), interpolation=cv2.INTER_AREA if s < 1 else cv2.INTER_CUBIC)
    y = (img.shape[0] - h) // 2
    x = int(min(max(img.shape[1] * cx - w / 2, 0), img.shape[1] - w))
    return img[y:y + h, x:x + w]


def dark_bg(col=(16, 19, 26)) -> np.ndarray:
    yy = np.linspace(0, 1, H)[:, None, None]
    base = np.array(col) * (1 - 0.35 * yy) + np.array([6, 7, 9]) * 0.35 * yy
    return np.broadcast_to(base, (H, W, 3)).astype(np.uint8).copy()


# ---- 字 -------------------------------------------------------------------------------------------
def stext(d: ImageDraw.ImageDraw, xy, s: str, font, fill=WHITE, anchor="la", r: int = 3, reg: Optional[str] = None) -> None:
    """影付きの字。reg を渡すと点検(重なり・はみ出し)に数える。"""
    a = fill[3] if len(fill) == 4 else 255
    for dx, dy in [(-r, 0), (r, 0), (0, -r), (0, r), (-2, -2), (2, 2), (2, -2), (-2, 2), (3, 4)]:
        d.text((xy[0] + dx, xy[1] + dy), s, font=font, fill=(10, 10, 12, int(230 * a / 255)), anchor=anchor)
    d.text(xy, s, font=font, fill=fill, anchor=anchor)
    if reg and a > 30:
        ov.BOXES.append((reg, d.textbbox(xy, s, font=font, anchor=anchor), s, 1.0))


def rich(s: str) -> List[Tuple[str, tuple]]:
    out, hot = [], False
    for ch in s:
        if ch in "【】":
            hot = ch == "【"
            continue
        out.append((ch, YEL if hot else WHITE))
    return out


def plain(s: str) -> str:
    return re.sub(r"[【】]", "", s)


def _rows(d, segs, f, maxw) -> list:
    """幅に収まる行に分ける。行の数を先に決め、長さがそろう所の近くの句読点で切る(1〜2 字だけの行を作らない)。"""
    def wid(x):
        return d.textlength("".join(c for c, _ in x), font=f)
    if wid(segs) <= maxw:
        return [segs]
    for n in range(math.ceil(wid(segs) / maxw), 8):
        rows = _split(segs, n, wid, maxw)
        if all(wid(r) <= maxw for r in rows):
            return rows
    return rows


def _split(segs, n, wid, maxw) -> list:
    rows, rest = [], list(segs)
    for r in range(n, 1, -1):
        target = len(rest) / r
        cand = [i + 1 for i, (c, _) in enumerate(rest) if c in "、。" and target * 0.6 <= i + 1 <= target * 1.35 and wid(rest[:i + 1]) <= maxw]
        cut = min(cand, key=lambda i: abs(i - target)) if cand else int(round(target))
        while cut > 1 and wid(rest[:cut]) > maxw:
            cut -= 1
        rows.append(rest[:cut])
        rest = rest[cut:]
    return rows + [rest]


def subtitle(d: ImageDraw.ImageDraw, text: str, k: float = 0.0) -> None:
    """2 行まで。長い文は 2 行ずつに分け、行の進み k(0〜1)で次へめくる。"""
    f = F("meiryob.ttc", LAY["sub_size"])
    segs = rich(text.replace("\n", ""))
    rows = _rows(d, segs, f, LAY["sub_maxw"])
    if len(rows) == 3:                                     # 3 行になるなら、句読点で 2 枚に分ける
        n = sum(len(r) for r in rows)
        p = [i for i, (c, _) in enumerate(segs) if c in "、。" and 0.2 * n < i < 0.8 * n]
        if p:
            cut = min(p, key=lambda i: abs(i - n / 2)) + 1
            pages = [_rows(d, segs[:cut], f, LAY["sub_maxw"]), _rows(d, segs[cut:], f, LAY["sub_maxw"])]
        else:
            pages = [rows[:2], rows[2:]]
    else:
        pages = [rows[i:i + 2] for i in range(0, len(rows), 2)]
    if len(pages) > 1:
        chars = [sum(len(r) for r in pg) for pg in pages]
        acc, idx = 0, 0
        for i, c in enumerate(chars):
            if k * sum(chars) >= acc:
                idx = i
            acc += c
        lines = pages[idx]
    else:
        lines = pages[0]
    lh = int(LAY["sub_size"] * 1.4)
    y0 = LAY["sub_y"] - lh * len(lines)
    for k, ln in enumerate(lines):
        w = d.textlength("".join(c for c, _ in ln), font=f)
        x, y = (W - w) / 2, y0 + lh * k
        ov.BOXES.append(("text", (x - 3, y - 3, x + w + 3, y + lh), "".join(c for c, _ in ln), 1.0 if w <= LAY["sub_maxw"] else LAY["sub_maxw"] / w))
        for c, col in ln:
            stext(d, (x, y), c, f, col)
            x += d.textlength(c, font=f)


def qtag(d: ImageDraw.ImageDraw, s: str) -> None:
    if not s:
        return
    f = F("YuGothB.ttc", 34 if PORTRAIT else 30)
    x, y = LAY["qtag"]
    w = d.textlength(s, font=f)
    d.rounded_rectangle([x, y, x + w + 64, y + 56], 8, fill=(12, 14, 18, 190), outline=(255, 255, 255, 90), width=2)
    d.rectangle([x, y, x + 8, y + 56], fill=YEL)
    d.text((x + 30, y + 28), s, font=f, fill=WHITE, anchor="lm")
    ov.BOXES.append(("corner", (x, y, x + w + 64, y + 56), s, 1.0))


def credit(d: ImageDraw.ImageDraw, s: str) -> None:
    if s:
        x, y = LAY["credit"]
        f = F("YuGothM.ttc", 22 if PORTRAIT else 20)
        d.text((x, y), s, font=f, fill=(235, 230, 220, 170), anchor="ra")
        ov.BOXES.append(("corner", d.textbbox((x, y), s, font=f, anchor="ra"), s, 1.0))


def place(d: ImageDraw.ImageDraw, a, k: float = 1.0) -> None:
    if not a or k <= 0:
        return
    f1, f2 = F("yumindb.ttf", 44 if PORTRAIT else 40), F("YuGothM.ttc", 26 if PORTRAIT else 24)
    A = int(255 * k)
    x, y = LAY["place"]
    w = max(d.textlength(a[0], font=f1), d.textlength(a[1] if len(a) > 1 else "", font=f2)) + 60
    hh = 96 if len(a) > 1 and a[1] else 64
    d.rectangle([x, y, x + w, y + hh], fill=(10, 10, 12, int(140 * k)))
    d.rectangle([x, y, x + 4, y + hh], fill=(255, 255, 255, A))
    d.text((x + 26, y + 10), a[0], font=f1, fill=WHITE + (A,))
    if len(a) > 1 and a[1]:
        d.text((x + 26, y + 62), a[1], font=f2, fill=(220, 215, 205, A))
    ov.BOXES.append(("corner", (x, y, x + w, y + hh), a[0], 1.0))


def meter(d: ImageDraw.ImageDraw, spec: dict, v: float) -> None:
    x, y = LAY["meter"]
    s = spec.get("fmt", "{:,.0f}").format(v)
    f1, f2 = F("YuGothM.ttc", 22), F("yumindb.ttf", 46)
    w = max(d.textlength(s, font=f2), d.textlength(spec["label"], font=f1)) + 60
    d.rounded_rectangle([x - w / 2, y, x + w / 2, y + 92], 6, fill=(12, 14, 18, 200), outline=YEL + (200,), width=2)
    d.text((x, y + 8), spec["label"], font=f1, fill=(220, 215, 205), anchor="ma")
    d.text((x, y + 34), s, font=f2, fill=WHITE, anchor="ma")
    ov.BOXES.append(("corner", (x - w / 2, y, x + w / 2, y + 92), spec["label"], 1.0))


def glow_line(img: Image.Image, pts, c, w: int = 6, k: float = 1.0) -> None:
    if len(pts) < 2:
        return
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.line(pts, fill=tuple(c[:3]) + (int(70 * k),), width=w * 4, joint="curve")
    ld.line(pts, fill=tuple(c[:3]) + (int(255 * k),), width=w, joint="curve")
    img.alpha_composite(lay)


def arrow_head(d, p, q, c, size=26):
    ang = math.atan2(q[1] - p[1], q[0] - p[0])
    ex, ey = q
    d.polygon([(ex + size * math.cos(ang), ey + size * math.sin(ang)), (ex + size * 0.7 * math.cos(ang + 2.3), ey + size * 0.7 * math.sin(ang + 2.3)),
               (ex + size * 0.7 * math.cos(ang - 2.3), ey + size * 0.7 * math.sin(ang - 2.3))], fill=c)


# ---- 素材 ------------------------------------------------------------------------------------------
class Media:
    """題材の assets/ の映像・写真と、出典(assets/sources.json: {ファイル名: {by, site, url, ai?}})。"""

    def __init__(self, folder: Path, cache: Path):
        self.folder, self.cache = folder, cache
        sp = folder / "assets" / "sources.json"
        self.sources = json.loads(sp.read_text(encoding="utf-8")) if sp.exists() else {}
        self.caps: Dict[str, list] = {}
        self.imgs: Dict[str, np.ndarray] = {}
        self.depths: Dict[str, np.ndarray] = {}
        self.tracks: Dict[str, dict] = {}

    def path(self, src: str) -> Path:
        return self.folder / src

    def credit(self, src: str) -> str:
        s = self.sources.get(Path(src).name)
        if not s:
            return ""
        if s.get("ai"):
            return "イメージ(AI で作成)"
        kind = "写真" if Path(src).suffix.lower() in (".jpg", ".jpeg", ".png", ".webp") else "映像"
        return f"{kind}: {s['by']} / {s.get('site', 'Pexels')}"

    def frame(self, src: str, t: float, cx: float = 0.5) -> np.ndarray:
        c = self.caps.get((src, cx))
        if c is None:
            cap = cv2.VideoCapture(str(self.path(src)))
            c = self.caps[(src, cx)] = [cap, -1.0, None, cap.get(cv2.CAP_PROP_FPS) or 30.0]
        cap, last, f, vfps = c
        if f is not None and abs(t - last) < 0.5 / vfps:
            return f
        if not (0 < t - last <= 1.5 / vfps):
            cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000)
        ok, g = cap.read()
        if not ok:
            return f if f is not None else np.zeros((H, W, 3), np.uint8)
        c[1], c[2] = t, cover(cv2.cvtColor(g, cv2.COLOR_BGR2RGB), cx=cx)
        return c[2]

    def image(self, src: str, w: int = W, h: int = H) -> np.ndarray:
        k = f"{src}@{w}x{h}"
        if k not in self.imgs:
            self.imgs[k] = cover(np.asarray(Image.open(self.path(src)).convert("RGB")), w, h)
        return self.imgs[k]

    def depth(self, src: str, big: np.ndarray) -> np.ndarray:
        """奥行き(1=手前)。一度測ったら out に置いておく(分けて描く同時の書き出しで測り直さない)。"""
        if src in self.depths:
            return self.depths[src]
        p = self.cache / f"depth_{Path(src).stem}_{big.shape[1]}x{big.shape[0]}.npy"
        if p.exists():
            d = np.load(p)
        else:
            import onnxruntime as ort
            ses = ort.InferenceSession(r"C:/Users/なみ/dev/assets3d/models/depth_anything_v2_small.onnx", providers=["CPUExecutionProvider"])
            x = cv2.resize(big, (518, 518)).astype(np.float32) / 255
            x = (x - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]
            d = ses.run(None, {ses.get_inputs()[0].name: x.transpose(2, 0, 1)[None].astype(np.float32)})[0][0]
            d = cv2.resize(d, (big.shape[1], big.shape[0]))
            d = cv2.GaussianBlur((d - d.min()) / (d.max() - d.min() + 1e-6), (0, 0), 3).astype(np.float32)
            np.save(p, d)
        self.depths[src] = d
        return d

    def track(self, src: str, start: float, dur: float) -> dict:
        """映像の中のいちばん大きな暗い塊(歩く人)の頭の位置を 10 回/秒で測って、なめらかにしておく。"""
        k = f"{src}@{start:.2f}"
        if k in self.tracks:
            return self.tracks[k]
        p = self.cache / f"track_{Path(src).stem}_{start:.2f}.json"
        if p.exists():
            tr = json.loads(p.read_text())
        else:
            cap = cv2.VideoCapture(str(self.path(src)))
            pts, last = [], None
            for i in range(int(dur * 10) + 2):
                cap.set(cv2.CAP_PROP_POS_MSEC, (start + i / 10) * 1000)
                ok, g = cap.read()
                if not ok:
                    pts.append(last)
                    continue
                f = cover(cv2.cvtColor(g, cv2.COLOR_BGR2RGB))
                gr = cv2.cvtColor(f, cv2.COLOR_RGB2GRAY)
                y0, y1, x0, x1 = int(H * 0.12), int(H * 0.85), int(W * 0.04), int(W * 0.96)
                n, _, st, _ = cv2.connectedComponentsWithStats((gr[y0:y1, x0:x1] < 50).astype(np.uint8), 8)
                tall = [j for j in range(1, n) if st[j, 3] > st[j, 2] * 1.3 and st[j, 4] > 30]   # 立っている人は縦長(足あとや影は横長)
                if tall:
                    j = max(tall, key=lambda j: st[j, 4])
                    x, y, w, h = st[j, :4]
                    p0 = (float(x0 + x + w / 2), float(y0 + y))
                    last = p0 if last is None else (last[0] * 0.7 + p0[0] * 0.3, last[1] * 0.7 + p0[1] * 0.3)
                pts.append(last)
            tr = dict(pts=pts)
            p.write_text(json.dumps(tr))
        self.tracks[k] = tr
        return tr


# ---- 場面 ------------------------------------------------------------------------------------------
class Ctx:
    """場面を描くときに渡すもの。t は場面の頭からの秒、T は場面の長さ。when(fx) は fx が出る秒(場面の頭から)。"""

    def __init__(self, st: "Stage", seg: dict, t: float):
        self.st, self.seg, self.t, self.T = st, seg, t, seg["end"] - seg["start"]
        self.view = None                                    # 地図の場面なら View(fx が経度・緯度を画面に直す)

    def when(self, fx: dict) -> float:
        return fx["_at"] - self.seg["start"]

    def k(self, fx: dict, dur: float = 0.5) -> float:
        return ease((self.t - self.when(fx)) / dur)

    def xy(self, fx: dict):
        if "ll" in fx and self.view is not None:
            return self.view.px(*fx["ll"])
        return fx.get("xy", (W / 2, H / 2))

    def active(self, kind: str) -> List[dict]:
        return [f for f in self.seg["fx"] if f["k"] == kind and self.t >= self.when(f)]


def s_map(c: Ctx, sc: dict) -> Image.Image:
    m = c.st.map
    u = ease(c.t / max(c.T, 0.1))
    a = sc["view"]
    b = sc.get("to", a)
    from .worldmap import View
    va, vb = m.view(*a), m.view(*b)
    v = View.lerp(va, vb, u)
    v = m.view(v.lon, v.lat, v.span, v.tilt)
    key = ("map", id(sc), round(c.t * 15))
    base = c.st.cache_get(key, lambda: grade(np.asarray(m.base_img(v))[..., :3].copy()))
    c.view = v
    return Image.fromarray(base).convert("RGBA")


def s_video(c: Ctx, sc: dict) -> Image.Image:
    f = c.st.media.frame(sc["src"], sc.get("start", 0.0) + c.t * sc.get("speed", 1.0), sc.get("cx", 0.5))
    return Image.fromarray(grade(f)).convert("RGBA")


def s_photo(c: Ctx, sc: dict) -> Image.Image:
    md = c.st.media
    src = md.image(sc["src"])
    big = c.st.cache_get(("photo", sc["src"]), lambda: cv2.resize(grade(src), (int(W * 1.12), int(H * 1.12)), interpolation=cv2.INTER_CUBIC))
    d = md.depth(sc["src"], big)
    u = ease(c.t / max(c.T, 0.1))
    h, w = big.shape[:2]
    yy, xx = c.st.grid()
    mv = sc.get("move", "in")
    zoom = 1.0 + (0.07 * u if mv == "in" else 0.02)
    sx = {"in": 30, "left": -60, "right": 60}.get(mv, 0) * (u - 0.5)
    px = (xx - W / 2) / zoom + w / 2 + sx
    py = (yy - H / 2) / zoom + h / 2
    dd = cv2.remap(d, px, py, cv2.INTER_LINEAR)
    sh = (dd - 0.5) * (50 * u - 25)
    f = cv2.remap(big, px - sh, py - (dd - 0.5) * 14 * u, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    return Image.fromarray(f).convert("RGBA")


def s_words(c: Ctx, sc: dict) -> Image.Image:
    im = Image.fromarray(dark_bg((24, 26, 32))).convert("RGBA")          # 真っ黒にしない(qc の黒いコマに当たる・字だけでも地の色を持つ)
    d = ImageDraw.Draw(im)
    rows = sc["rows"]
    ons = sc.get("rows_on", [None] * len(rows))
    f = F("meiryob.ttc", 84 if PORTRAIT else 96)
    lh = int(f.size * 1.6)
    y0 = H / 2 - lh * (len(rows) - 1) / 2 - (80 if PORTRAIT else 0)
    for i, (r, on) in enumerate(zip(rows, ons)):
        t0 = 0.0 if on is None else c.st.mark_time(c.seg, on)
        a = ease((c.t - t0) / 0.3)
        if a <= 0:
            continue
        hot = r.startswith("【")
        stext(d, (W / 2, y0 + lh * i), plain(r), f, (YEL if hot else WHITE) + (int(255 * a),), anchor="mm", reg="words")
    return im


def s_bars(c: Ctx, sc: dict) -> Image.Image:
    im = Image.fromarray(grade(dark_bg(sc.get("bg", (16, 19, 26))), 0.2)).convert("RGBA")
    d = ImageDraw.Draw(im, "RGBA")
    items = [dict(it, _at=c.seg["start"]) for it in sc.get("items", [])] + [dict(f["item"], _at=f["_at"]) for f in c.seg["fx"] if f["k"] == "add" and "item" in f]
    vmax = sc.get("max") or max(it["value"] for it in items)
    if PORTRAIT:
        base, top, x0, x1 = 1150, 520, 120, W - 120
    else:
        base, top, x0, x1 = 780, 250, 420, 1500
    n = max(len(items), 2)
    bw = min(230, (x1 - x0) / n * 0.55)
    focus = [f["name"] for f in c.active("focus")]
    d.line([(x0, base), (x1, base)], fill=(255, 255, 255, 120), width=2)
    fN, fL = F("yumindb.ttf", 80 if not PORTRAIT else 70), F("YuGothB.ttc", 34)
    for i, it in enumerate(items):
        k = ease((c.t - (it["_at"] - c.seg["start"]) - 0.3) / 1.4)
        if c.t < it["_at"] - c.seg["start"]:
            continue
        cx = x0 + (x1 - x0) * (i + 0.5) / n
        col = c.st.color(it["name"], BLUE)
        if focus and it["name"] not in focus:
            col = GRAY
        h = (base - top) * it["value"] / vmax * k
        for j in range(int(h)):
            u = j / max(h, 1)
            cc = tuple(int(v * (0.55 + 0.45 * u)) for v in col) + (235,)
            d.line([(cx - bw / 2, base - j), (cx + bw / 2, base - j)], fill=cc)
        d.line([(cx - bw / 2, base - h), (cx + bw / 2, base - h)], fill=tuple(min(255, v + 60) for v in col) + (255,), width=3)
        stext(d, (cx, base + 22), it["name"], fL, WHITE, anchor="ma", reg="fig")
        num = it["value"] * k
        s = (f"{num:,.0f}" if it["value"] >= 10 else f"{num:.1f}") + it.get("unit", "")
        if "label" in it and k >= 1:   # 0.61 や「17〜25」のように、数え上げの形で書けない数字(数え終わったら差し替える)
            s = it["label"]
        stext(d, (cx, base - h - 18), s, fN, WHITE, anchor="ms", reg="fig")
    for f in c.active("add"):
        if "ratio" in f:
            a = c.k(f)
            rt = f["ratio"]
            x = x1 - 20 if not PORTRAIT else W - 90
            d.line([(x, top + 6), (x, base - 14)], fill=YEL + (int(255 * a),), width=4)
            for xx in range(int(x0 + (x1 - x0) * 0.4), int(x), 22):
                d.line([(xx, top), (xx + 10, top)], fill=(255, 255, 255, int(170 * a)), width=2)
            stext(d, (x - 20, (top + base) / 2 - 40), rt["text"], fN, YEL + (int(255 * a),), anchor="rm", reg="label")
            if rt.get("sub"):
                stext(d, (x - 20, (top + base) / 2 + 40), rt["sub"], fL, YEL + (int(255 * a),), anchor="rm")
    return im


BOX_N = 3


def _boxes_rects(n: int):
    if PORTRAIT:
        bw, bh, gap = 820, 300, 40
        y0 = H / 2 - (bh * n + gap * (n - 1)) / 2 - 120
        return [((W - bw) / 2, y0 + i * (bh + gap), (W + bw) / 2, y0 + i * (bh + gap) + bh) for i in range(n)]
    bw, bh, gap = 440, 310, 60
    x0 = W / 2 - (bw * n + gap * (n - 1)) / 2
    return [(x0 + i * (bw + gap), 330, x0 + i * (bw + gap) + bw, 330 + bh) for i in range(n)]


def s_boxes(c: Ctx, sc: dict) -> Image.Image:
    im = Image.fromarray(grade(dark_bg(), 0.2)).convert("RGBA")
    d = ImageDraw.Draw(im, "RGBA")
    rects = _boxes_rects(sc.get("n", BOX_N))
    ex = c.active("expand")
    zoom = ease((c.t - c.when(ex[0])) / 0.7) if ex else 0.0
    zi = ex[0]["i"] if ex else -1
    fB = F("yumindb.ttf", 110)
    for i, (x0, y0, x1, y1) in enumerate(rects):
        a = ease((c.t - 0.2 - 0.25 * i) / 0.4) * (1 - zoom)
        if a <= 0:
            continue
        al = (255, 255, 255, int(110 * a))
        for x in range(int(x0), int(x1), 26):
            d.line([(x, y0), (min(x + 14, x1), y0)], fill=al, width=2)
            d.line([(x, y1), (min(x + 14, x1), y1)], fill=al, width=2)
        for y in range(int(y0), int(y1), 26):
            d.line([(x0, y), (x0, min(y + 14, y1))], fill=al, width=2)
            d.line([(x1, y), (x1, min(y + 14, y1))], fill=al, width=2)
        d.text(((x0 + x1) / 2, (y0 + y1) / 2), str(i + 1), font=fB, fill=(255, 255, 255, int(70 * a)), anchor="mm")
    for f in c.active("fill"):
        i = f["i"]
        x0, y0, x1, y1 = rects[i]
        z = zoom if i == zi else 0.0
        X0, Y0, X1, Y1 = [p + (q - p) * z for p, q in zip((x0, y0, x1, y1), (0, 0, W, H))]
        a = c.k(f, 0.6)
        src = c.st.media.image(f["src"])
        bw, bh = max(int(X1 - X0), 2), max(int(Y1 - Y0), 2)
        s = max(bw / W, bh / H)
        sm = cv2.resize(grade(src), (int(W * s) + 1, int(H * s) + 1), interpolation=cv2.INTER_AREA)
        ox, oy = (sm.shape[1] - bw) // 2, (sm.shape[0] - bh) // 2
        tile = Image.fromarray(sm[oy:oy + bh, ox:ox + bw])
        im.paste(tile, (int(X0), int(Y0)), Image.new("L", tile.size, int(255 * a)))
        d = ImageDraw.Draw(im, "RGBA")
        if z < 1:
            d.rectangle([X0, Y0, X1, Y1], outline=WHITE + (int(255 * a * (1 - z)),), width=3)
            if f.get("label"):
                stext(d, ((X0 + X1) / 2, Y1 + 18), f["label"], F("YuGothB.ttc", 38), WHITE + (int(255 * a * (1 - z)),), anchor="ma", reg="label")
        c.seg["_credit"] = c.st.media.credit(f["src"])
    return im


def s_card(c: Ctx, sc: dict) -> Image.Image:
    im = Image.fromarray(grade(dark_bg(sc.get("bg", (20, 24, 32))), 0.2)).convert("RGBA")
    d = ImageDraw.Draw(im, "RGBA")
    a = ease(c.t / 0.4)
    x = 90 if PORTRAIT else 260
    y = H * 0.30 if PORTRAIT else 300
    d.rectangle([x, y, x + 10, y + (520 if PORTRAIT else 380)], fill=YEL + (int(255 * a),))
    fT, fS, fB = F("yumindb.ttf", 92 if PORTRAIT else 100), F("YuGothM.ttc", 34), F("YuGothM.ttc", 42 if PORTRAIT else 40)
    stext(d, (x + 50, y), sc["title"], fT, WHITE + (int(255 * a),), reg="words")
    tw = d.textlength(sc["title"], font=fT)
    if sc.get("sub"):
        if PORTRAIT:
            d.text((x + 52, y + 120), sc["sub"], font=fS, fill=(220, 215, 205, int(255 * a)))
        else:
            d.text((x + 70 + tw, y + 52), sc["sub"], font=fS, fill=(220, 215, 205, int(255 * a)))
    b = ease((c.t - 0.5) / 0.5)
    yy = y + (190 if PORTRAIT else 160)
    for line in _wrap(d, sc.get("body", ""), fB, W - x - 140):
        d.text((x + 52, yy), line, font=fB, fill=(240, 236, 228, int(255 * b)))
        yy += fB.size * 1.6
    if sc.get("src"):
        d.text((x + 52, yy + 20), "出典: " + sc["src"], font=F("YuGothM.ttc", 24), fill=(180, 178, 170, int(255 * b)))
    return im


def _wrap(d, s: str, f, maxw: float) -> List[str]:
    out, cur = [], ""
    for ch in s:
        if ch == "\n" or d.textlength(cur + ch, font=f) > maxw:
            out.append(cur)
            cur = "" if ch == "\n" else ch
        else:
            cur += ch
    return out + ([cur] if cur else [])


def s_split(c: Ctx, sc: dict) -> Image.Image:
    im = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    focus = [f["name"] for f in c.active("focus")]
    sides = [sc["left"], sc["right"]]
    for i, sd in enumerate(sides):
        if PORTRAIT:
            box = (0, int(H * 0.12) + i * int(H * 0.36), W, int(H * 0.12) + (i + 1) * int(H * 0.36) - 8)
        else:
            box = (i * W // 2 + (4 if i else 0), 0, (i + 1) * W // 2 - (0 if i else 4), H)
        bw, bh = box[2] - box[0], box[3] - box[1]
        p = Path(sd["src"])
        src = c.st.media.frame(sd["src"], sd.get("start", 0.0) + c.t) if p.suffix == ".mp4" else c.st.media.image(sd["src"])
        tile = cover(grade(src), bw, bh)
        if focus and sd["name"] not in focus:
            tile = (tile.astype(np.float32) * 0.35).astype(np.uint8)
        im.paste(Image.fromarray(tile), box[:2])
        d = ImageDraw.Draw(im, "RGBA")
        col = c.st.color(sd["name"], BLUE)
        f = F("YuGothB.ttc", 38)
        tw = d.textlength(sd["name"], font=f)
        x, y = box[0] + 40, box[1] + (40 if PORTRAIT else 130)
        d.rounded_rectangle([x, y, x + tw + 40, y + 60], 8, fill=col + (230,))
        d.text((x + 20, y + 30), sd["name"], font=f, fill=(15, 15, 18), anchor="lm")
        ov.BOXES.append(("label", (x, y, x + tw + 40, y + 60), sd["name"], 1.0))
    return im


SCENES = dict(map=s_map, video=s_video, photo=s_photo, words=s_words, bars=s_bars, boxes=s_boxes, card=s_card, split=s_split)


# ---- 足すもの(fx) --------------------------------------------------------------------------------
def draw_fx(img: Image.Image, c: Ctx) -> Image.Image:
    st = c.st
    for f in c.active("dim"):
        a = c.k(f) * f.get("amount", 0.55)
        img = Image.blend(img, Image.new("RGBA", img.size, (0, 0, 0, 255)), a)
    for f in c.active("spot"):
        a = c.k(f) * f.get("amount", 0.6)
        x0, y0, x1, y1 = f["box"]
        m = Image.new("L", img.size, int(255 * a))
        ImageDraw.Draw(m).rounded_rectangle([x0, y0, x1, y1], 24, fill=0)
        img = Image.composite(Image.new("RGBA", img.size, (0, 0, 0, 255)), img, m.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(img, "RGBA")
    fL = F("YuGothB.ttc", 40 if PORTRAIT else 38)
    for f in c.active("route"):
        pts = [c.view.px(*p) for p in f["pts"]] if c.view is not None and f.get("geo", True) and c.view else f["pts"]
        k = ease((c.t - c.when(f)) / f.get("dur", 2.0))
        n = max(2, int(len(pts) * k))
        glow_line(img, pts[:n], f.get("color", RED), f.get("w", 6))
        d = ImageDraw.Draw(img, "RGBA")
        if f.get("arrow") and k >= 1:
            arrow_head(d, pts[-3], pts[-1], tuple(f.get("color", RED)) + (255,))
        if k >= 1 and f.get("label"):
            a = ease((c.t - c.when(f) - f.get("dur", 2.0)) / 0.5)
            lx, ly = f.get("label_xy") or pts[len(pts) // 2]
            stext(d, (lx - 40, ly), f["label"], F("yumindb.ttf", 80 if not PORTRAIT else 70), YEL + (int(255 * a),), anchor="rm", reg="label")
    for f in c.active("note"):
        a = c.k(f)
        px, py = c.xy(f)
        dx, dy = f.get("off", (110, -110))
        d.ellipse([px - 7, py - 7, px + 7, py + 7], outline=WHITE + (int(255 * a),), width=3)
        d.line([(px + dx * 0.12, py + dy * 0.12), (px + dx, py + dy)], fill=WHITE + (int(255 * a),), width=3)
        stext(d, (px + dx + (10 if dx >= 0 else -10), py + dy), f["text"], fL, WHITE + (int(255 * a),), anchor="lm" if dx >= 0 else "rm", reg="label")
    for f in c.active("person"):
        tr = st.media.track(c.seg["scene"]["src"], c.seg["scene"].get("start", 0.0), c.T + 1)
        i = min(int(c.t * 10), len(tr["pts"]) - 1)
        p = tr["pts"][i]
        if p:
            a = c.k(f, 0.6)
            px, py = p
            d.ellipse([px - 46, py - 18, px + 46, py + 70], outline=YEL + (int(255 * a),), width=4)
            d.line([(px, py - 22), (px, py - 130)], fill=WHITE + (int(255 * a),), width=3)
            stext(d, (px, py - 140), f.get("text", "人"), fL, WHITE + (int(255 * a),), anchor="ms", reg="label")
    for f in c.active("q"):
        a = c.k(f)
        cx, cy = c.xy(f)
        r = 110
        for i in range(0, 360, 20):
            d.arc([cx - r, cy - r * 0.7, cx + r, cy + r * 0.7], i, i + 11, fill=(255, 255, 255, int(220 * a)), width=4)
        stext(d, (cx, cy + 8), "？", F("meiryob.ttc", 150), YEL + (int(255 * a),), anchor="mm")
        if f.get("label"):
            stext(d, (cx, cy + r * 0.7 + 20), f["label"], fL, WHITE + (int(255 * a),), anchor="ma", reg="label")
    return img


# ---- 組み立て ---------------------------------------------------------------------------------------
class Stage:
    def __init__(self, ep: dict, tl: dict, out: Path):
        self.ep, self.out = ep, out
        self.mod = ep["_mod"]
        self.defs = {l["id"]: l for l in ep["lines"]}
        self.lines = tl["lines"]
        self.total = tl["total"]
        folder = Path(self.mod.__file__).parent
        self.media = Media(folder if (folder / "assets").exists() else folder.parent, out)
        self._cache: dict = {}
        self._grid = None
        mp = ep.get("map")                                  # 地図の下地は EP["map"]=dict(lat0, bases)(MAP にすると vqc が別の形で読む)
        if isinstance(mp, dict):
            from .worldmap import Map
            mp = Map(lat0=mp["lat0"], bases=mp["bases"])
        self.map = mp
        self.segs = self._segments()

    # 場面ごとの区切り: scene がある行で始まり、次の scene の行の前まで
    def _segments(self) -> List[dict]:
        segs: List[dict] = []
        for l in self.lines:
            dfn = self.defs.get(l["id"], {})
            if dfn.get("scene") or not segs:
                segs.append(dict(scene=dfn.get("scene") or dict(kind="words", rows=[""]), start=max(0.0, l["start"] - 0.15), lines=[], fx=[]))
            segs[-1]["lines"].append(l)
            for f in dfn.get("fx", []):
                f2 = dict(f)
                f2["_at"] = l["start"] + (l.get("marks", {}).get(f["on"], 0.0) if f.get("on") else 0.0)
                segs[-1]["fx"].append(f2)
        segs[0]["start"] = 0.0
        for a, b in zip(segs, segs[1:]):
            a["end"] = b["start"]
        segs[-1]["end"] = self.total
        return segs

    def mark_time(self, seg: dict, word: str) -> float:
        for l in seg["lines"]:
            if word in (l.get("marks") or {}):
                return l["start"] + l["marks"][word] - seg["start"]
            if word in self.defs.get(l["id"], {}).get("text", "") and not l.get("marks"):
                return l["start"] - seg["start"]
        return 0.0

    def color(self, name: str, default) -> tuple:
        return tuple(self.ep.get("colors", {}).get(name, default))

    def grid(self):
        if self._grid is None:
            self._grid = np.mgrid[0:H, 0:W].astype(np.float32)
        return self._grid

    def cache_get(self, key, fn):
        if key not in self._cache:
            if len(self._cache) > 6:
                self._cache.pop(next(iter(self._cache)))
            self._cache[key] = fn()
        return self._cache[key]

    def seg_at(self, t: float) -> Tuple[int, dict]:
        for i, s in enumerate(self.segs):
            if s["start"] <= t < s["end"]:
                return i, s
        return len(self.segs) - 1, self.segs[-1]

    def render_seg(self, s: dict, t: float) -> Image.Image:
        c = Ctx(self, s, t - s["start"])
        sc = s["scene"]
        if sc["kind"] == "custom":
            img = Image.new("RGBA", (W, H), (12, 14, 20, 255))
            getattr(self.mod, "draw_" + sc["fn"])(img, c.t, c)
        else:
            img = SCENES[sc["kind"]](c, sc)
        return draw_fx(img, c), c

    def frame(self, fi: int) -> Image.Image:
        t = (fi - 1) / FPS
        ov.BOXES.clear()
        i, s = self.seg_at(t)
        img, c = self.render_seg(s, t)
        # 文の切れ目でさっと替える(0.2 秒だけ重ねる)。字だけの画面との間は切る
        if i > 0 and t - s["start"] < 0.2 and s["scene"]["kind"] != "words" and self.segs[i - 1]["scene"]["kind"] != "words":
            prev, _ = self.render_seg(self.segs[i - 1], s["start"] - 1e-3)
            ov.BOXES.clear()
            img = Image.blend(prev, img, (t - s["start"]) / 0.2)
            img, c = img, Ctx(self, s, t - s["start"])
        d = ImageDraw.Draw(img, "RGBA")
        sc = s["scene"]
        cur = ov.current(self.lines, t + 0.15)
        dfn = self.defs.get(cur["id"], {}) if cur else {}
        if sc["kind"] != "words":
            qtag(d, self.ep.get("qtag", ""))
            cr = sc.get("credit") or s.get("_credit") or (self.media.credit(sc["src"]) if sc.get("src") else "")
            if sc["kind"] == "map" and not cr:
                cr = "地図: NASA Blue Marble・Natural Earth"
            credit(d, cr)
            place(d, sc.get("place"), ease((t - s["start"] - 0.3) / 0.6))
            ms = self.ep.get("meter")
            if ms:
                meter(d, ms, self.meter_value(t))
        if cur and cur["id"] == "cta":
            ov.cta(img, t - cur["start"], (LAY["sub_y"] - 260, LAY["sub_y"] + 20) if not PORTRAIT else (1300, 1700))
        elif cur and sc["kind"] != "words":
            kk = (t - cur["start"]) / max(cur["end"] - cur["start"], 0.1)
            subtitle(d, dfn.get("sub") or dfn.get("text", ""), kk)
        return img.convert("RGB")

    def meter_value(self, t: float) -> float:
        pts = [(l["start"], self.defs[l["id"]]["meter"]) for l in self.lines if "meter" in self.defs.get(l["id"], {})]
        v = pts[0][1] if pts else 0.0
        for i, (t0, val) in enumerate(pts):
            if t >= t0:
                prev = pts[i - 1][1] if i else val
                v = prev + (val - prev) * ease((t - t0) / 1.0)
        return v


# ---- 点検(qc から呼ぶ) -----------------------------------------------------------------------------
def lint(ep: dict) -> Tuple[List[str], List[str]]:
    """台本の点検: 絵が替わらない文・出典の無い素材・場面の書き間違い。"""
    fails, warns = [], []
    lines = [l for l in ep["lines"] if l.get("id") != "cta"]
    folder = Path(ep["_mod"].__file__).parent
    root = folder if (folder / "assets").exists() else folder.parent
    sp = root / "assets" / "sources.json"
    sources = json.loads(sp.read_text(encoding="utf-8")) if sp.exists() else {}
    if lines and not lines[0].get("scene"):
        fails.append(f"{lines[0]['id']}: 1 行目に scene が無い")
    for l in lines:
        sc, fx = l.get("scene"), l.get("fx", [])
        if not sc and not fx and l is not lines[0]:
            fails.append(f"{l['id']}: 文が替わっても絵が替わらない(scene か fx を足す。1 文に 1 枚)")
        if sc:
            if sc.get("kind") not in SCENES and sc.get("kind") != "custom":
                fails.append(f"{l['id']}: 場面の種類 {sc.get('kind')} は無い")
            # card の src は出典の文字(論文名など)で、素材のファイルではない
            srcs = ([] if sc.get("kind") == "card" else [sc.get("src")]) + [sc.get(s, {}).get("src") for s in ("left", "right")]
        else:
            srcs = []
        srcs += [f.get("src") for f in fx]
        for s in filter(None, srcs):
            if not (root / s).exists():
                fails.append(f"{l['id']}: 素材が無い {s}")
            elif Path(s).name not in sources:
                fails.append(f"{l['id']}: 出典が控えていない {s}(assets/sources.json に by・site・url。AI の絵は ai=true)")
        for f in fx:
            if f.get("on") and f["on"] not in plain(l.get("text", "")):
                fails.append(f"{l['id']}: fx の on「{f['on']}」が文に無い")
    return fails, warns


def labels_check(frame_fn, nf: int) -> List[str]:
    """札が同時に MAX_LABELS を超える時間(地図に札を散らさない)。"""
    hits = []
    for fi in range(1, nf + 1, FPS // 2):
        frame_fn(fi)
        n = sum(1 for k, *_ in ov.BOXES if k == "label")
        if n > MAX_LABELS:
            hits.append((fi - 1) / FPS)
    return [f"札が {MAX_LABELS} つより多い {hits[0]:.1f}秒〜(計 {len(hits) / 2:.1f}秒)。真ん中は絵だけにする"] if hits else []
