"""画面を描く。絵画（背景）・肖像・年号の札・地層の年表・2人の立ち絵。

画面は「状態」（背景・肖像・札・年号・話している人）が変わったときだけ描き、
同じ状態が続くあいだは同じ1枚を流す。話者が替わる瞬間だけ、話す側が少し跳ねる。
"""
from __future__ import annotations

import hashlib
import math
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFont

INK = (244, 236, 220)
GOLD = (214, 178, 110)
DIM = (176, 164, 140)
STRATA = [(70, 58, 44), (92, 74, 52), (120, 96, 62), (150, 118, 74), (110, 52, 44)]

HOP_PX = 22          # 話し始めに跳ねる高さ
HOP_FRAMES = 6       # 跳ねる長さ（フレーム数）
LISTENER_DIM = 0.72  # 聞いている側の明るさ


@dataclass(frozen=True)
class State:
    section: int
    background: object
    portrait: object
    card: object
    year: int | None
    speaker: str


class Painter:
    def __init__(self, config: dict, script, assets: Path, size: tuple[int, int]):
        self.config = config
        self.script = script
        self.assets = assets
        self.W, self.H = size
        self._fonts: dict = {}
        self._images: dict = {}

    # --- 素材 -------------------------------------------------------------
    def font(self, kind: str, size: int, bold: bool = False):
        key = (kind, size, bold)
        if key not in self._fonts:
            f = ImageFont.truetype(self.config["fonts"][kind], size)
            if bold:
                try:
                    f.set_variation_by_name("Bold")
                except Exception:
                    pass
            self._fonts[key] = f
        return self._fonts[key]

    def image(self, rel: str) -> Image.Image:
        if rel not in self._images:
            path = self.assets / rel
            if not path.exists():
                raise FileNotFoundError(f"素材がありません: {path}")
            self._images[rel] = Image.open(path).convert("RGBA")
        return self._images[rel]

    def character(self, speaker: str) -> Image.Image:
        key = ("char", speaker)
        if key not in self._images:
            cast = self.config["cast"][speaker]
            im = self.image(cast["image"])
            im = im.crop(im.getbbox())
            h = int(cast.get("height", 1150) * self.H / 1080)
            im = im.resize((int(im.width * h / im.height), h), Image.LANCZOS)
            self._images[key] = im.crop((0, 0, im.width, int(h * cast.get("bust", 0.4))))
        return self._images[key]

    # --- 背景と情報 -------------------------------------------------------
    def _cover(self, im: Image.Image) -> Image.Image:
        s = max(self.W / im.width, self.H / im.height)
        im = im.resize((math.ceil(im.width * s), math.ceil(im.height * s)), Image.LANCZOS)
        x, y = (im.width - self.W) // 2, (im.height - self.H) // 2
        return im.crop((x, y, x + self.W, y + self.H))

    def _background(self, pic) -> Image.Image:
        W, H = self.W, self.H
        if pic is None:
            bg = Image.new("RGB", (W, H), (24, 19, 14))
        else:
            bg = self._cover(self.image(pic.image).convert("RGB"))
            bg = ImageEnhance.Brightness(bg).enhance(0.55)
            bg = ImageEnhance.Color(bg).enhance(0.8)
        shade = Image.linear_gradient("L").resize((W, H))
        shade = shade.point(lambda v: int(max(0, (v - 140) / 115) * 200))
        return Image.composite(Image.new("RGB", (W, H), (12, 10, 8)), bg, shade).convert("RGBA")

    def _timeline(self, dr: ImageDraw.ImageDraw, x0: float, x1: float, yb: float, year: int | None):
        sc = self.script
        if sc.timeline_start is None or sc.timeline_end is None:
            return
        y0, y1 = sc.timeline_start, sc.timeline_end
        X = lambda y: x0 + (x1 - x0) * (y - y0) / max(1, (y1 - y0))
        marks = sorted({y for y, _ in sc.events} | {y0, y1})
        for i, (a, b) in enumerate(zip(marks, marks[1:])):
            color = STRATA[min(i, len(STRATA) - 2)] if b != y1 or len(marks) < 3 else STRATA[-1]
            dr.rectangle([X(a), yb - 14, X(b), yb + 14], fill=color + (255,))
        u = self.H / 1080
        for y, label in sc.events:
            on = (year == y)
            dr.line([X(y), yb - 26, X(y), yb + 26], fill=(GOLD if on else DIM) + (255,), width=4 if on else 2)
            dr.text((X(y), yb - 40 * u), str(y), font=self.font("gothic", int((30 if on else 26) * u)),
                    fill=GOLD if on else DIM, anchor="ms")
            dr.text((X(y), yb + 44 * u), label, font=self.font("serif", int((30 if on else 24) * u)),
                    fill=INK if on else DIM, anchor="mt")
        if year is not None and y0 <= year <= y1:
            cx = X(year)
            dr.polygon([(cx - 14, yb - 108 * u), (cx + 14, yb - 108 * u), (cx, yb - 88 * u)], fill=GOLD)

    def base(self, state: State) -> Image.Image:
        """立ち絵以外の部分（横長の本編用）。"""
        W, H = self.W, self.H
        img = self._background(state.background)
        dr = ImageDraw.Draw(img, "RGBA")
        title = self.script.sections[state.section].title
        dr.text((120, 120), f"第{state.section + 1}節", font=self.font("gothic", 30), fill=GOLD)
        # 題名が長いと右の肖像画に重なるので、収まるまで字を小さくする
        limit = (W - 330 - 400 - 40 - 120) if state.portrait is not None else (W - 240)
        size = 64
        while size > 36 and self.font("serif", size, bold=True).getlength(title) > limit:
            size -= 2
        dr.text((120, 165 + (64 - size) // 2), title, font=self.font("serif", size, bold=True), fill=INK)
        if state.card is not None:
            body_w = self.font("serif", 40).getlength(state.card.body or "")
            w = max(520, int(body_w) + 70)
            dr.rounded_rectangle([120, 290, 120 + w, 420], radius=10, fill=(20, 16, 10, 190), outline=GOLD, width=2)
            dr.text((150, 305), state.card.head, font=self.font("gothic", 34), fill=GOLD)
            if state.card.body:
                dr.text((150, 355), state.card.body, font=self.font("serif", 40), fill=INK)
        if state.portrait is not None:
            p = self.image(state.portrait.image).convert("RGB")
            ph = 540
            p = p.resize((int(p.width * ph / p.height), ph), Image.LANCZOS)
            px, py = W - p.width - 330, 90
            dr.rectangle([px - 14, py - 14, px + p.width + 14, py + ph + 14], fill=(30, 24, 16, 255),
                         outline=GOLD, width=3)
            img.paste(p, (px, py))
            dr = ImageDraw.Draw(img, "RGBA")
            if state.portrait.caption:
                dr.text((px + p.width / 2, py + ph + 34), state.portrait.caption, font=self.font("serif", 26),
                        fill=DIM, anchor="mt")
        self._timeline(dr, 470, W - 470, 920, state.year)
        if state.background is not None and state.background.credit:
            dr.text((W / 2, H - 18), f"背景：{state.background.credit}", font=self.font("serif", 20),
                    fill=DIM, anchor="ms")
        names = "　".join(f"VOICEVOX:{c['name']}" for c in self.config["cast"].values())
        dr.text((W - 40, 34), names, font=self.font("serif", 20), fill=DIM, anchor="rs")
        return img

    def with_cast(self, base: Image.Image, speaker: str, hop: float = 0.0) -> Image.Image:
        """立ち絵を重ねる。話している側は明るく、hop（0〜1）のぶん跳ねる。"""
        img = base.copy()
        for who, cast in self.config["cast"].items():
            ch = self.character(who)
            if who != speaker:
                a = ch.split()[3]
                ch = ImageEnhance.Brightness(ch.convert("RGB")).enhance(LISTENER_DIM).convert("RGBA")
                ch.putalpha(a)
                lift = 0
            else:
                lift = int(HOP_PX * math.sin(math.pi * hop))
            x = 20 if cast.get("side", "left") == "left" else self.W - ch.width - 10
            img.alpha_composite(ch, (x, self.H - ch.height + 10 - lift))
        return img.convert("RGB")


def state_of(line) -> State:
    return State(line.section, line.background, line.portrait, line.card, line.year, line.speaker)


def _name(state, hop_i: int) -> str:
    h = hashlib.sha1(repr((state, hop_i)).encode("utf-8")).hexdigest()[:12]
    return f"{h}.png"


def frames(painter: Painter, cues: list, total: float, frame_dir: Path, fps: int,
           with_text: bool = False) -> list[tuple[Path, float]]:
    """(画像, 表示する秒数) の並びを作る。同じ状態の画像は使い回す。

    with_text=True（ショート）は、せりふを画面に焼き込むので行ごとに画像が変わる。
    """
    frame_dir.mkdir(parents=True, exist_ok=True)
    bases: dict = {}
    out: list[tuple[Path, float]] = []
    prev_speaker = None
    for i, cue in enumerate(cues):
        state = state_of(cue.line)
        start = 0.0 if i == 0 else cue.start
        end = cues[i + 1].start if i + 1 < len(cues) else total
        key = (state.section, state.background, state.portrait, state.card, state.year)
        hop = cue.line.speaker != prev_speaker
        n_hop = HOP_FRAMES if hop else 0
        # 跳ねるのは話し始めの瞬間。行の前の間（無音）は静止画で埋める
        lead = max(0.0, cue.start - start) if i > 0 else cue.start
        steps: list[tuple[int, float]] = []
        if lead > 0:
            steps.append((0, lead))
        for k in range(1, n_hop + 1):
            steps.append((k, 1 / fps))
        rest = end - start - sum(d for _, d in steps)
        steps.append((0, max(1 / fps, rest)))
        text = cue.line.text if with_text else ""
        for k, dur in steps:
            path = frame_dir / _name((state, text), k)
            if not path.exists():
                if key not in bases:
                    bases[key] = painter.base(state)
                hop_t = k / (n_hop + 1) if k else 0.0
                im = (painter.with_cast(bases[key], state.speaker, hop_t, text) if with_text
                      else painter.with_cast(bases[key], state.speaker, hop_t))
                im.save(path)
            out.append((path, dur))
        prev_speaker = cue.line.speaker
    return out


def concat_list(items: list[tuple[Path, float]]) -> str:
    """ffmpeg の concat 用の並び。最後の1枚は2回書く（ffmpeg の決まり）。"""
    lines = []
    for path, dur in items:
        lines.append(f"file '{path.as_posix()}'")
        lines.append(f"duration {dur:.4f}")
    if items:
        lines.append(f"file '{items[-1][0].as_posix()}'")
    return "\n".join(lines) + "\n"
