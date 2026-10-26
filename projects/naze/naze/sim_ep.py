"""計算の回(kind: sim)。声と字幕はこちら、画面の中身は題材の ep.py の draw(img, dr, t, ctx) が描く。

EP: title, header, lines=[{id, text, say?, sub?, pause?, style?: question|end}], credit(左上の小さな表記)
ep.py に draw(img, dr, t, ctx) を書く。ctx = {lines, cur(今の行), L(id→行), k(今の行の中の進み 0〜1), at(id)→その行の開始秒}
字幕は下寄り(y 1560 前後)に出るので、draw は y 220〜1450 あたりを使う。
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

from . import compose, overlay as ov, sfx, tts
from .config import FPS, H, LAYOUT, W


def kana(ep: dict) -> None:
    for s in tts.kana(ep["lines"]):
        print(s)


def voice(ep: dict, out: Path) -> dict:
    tl = tts.synth(ep["lines"], out)
    (out / "timeline.json").write_text(json.dumps(tl, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"語り {tl['total']:.1f} 秒")
    return tl


def frame_fn(ep: dict, out: Path):
    tl = json.loads((out / "timeline.json").read_text(encoding="utf-8"))
    lines = tl["lines"]
    L = {l["id"]: l for l in lines}
    defs = {l["id"]: l for l in ep["lines"]}
    draw = ep["_mod"].draw
    nf = int(math.ceil(tl["total"] * FPS))

    def frame(fi: int) -> Image.Image:
        t = (fi - 1) / FPS
        ov.BOXES.clear()
        img = Image.new("RGBA", (W, H), (10, 18, 40, 255))
        dr = ImageDraw.Draw(img)
        cur = ov.current(lines, t)
        k = 0.0 if not cur else max(0.0, min(1.0, (t - cur["start"]) / max(1e-6, cur["end"] - cur["start"])))
        scene = cur
        if cur and cur["id"] == "cta":          # お願いの間は、最後の場面をそのまま見せる
            scene, k = lines[-2], 1.0
        ctx = dict(lines=lines, cur=scene, L=L, k=k, at=lambda i: L[i]["start"], defs=defs)
        draw(img, dr, t, ctx)
        dr = ImageDraw.Draw(img)
        if ep.get("credit"):
            ov.corner(dr, ep["credit"])
        d = defs[cur["id"]] if cur else {}
        sub = d.get("sub", d.get("text", ""))
        style = d.get("style")
        if style == "question":
            ov.rows(dr, sub, *LAYOUT["sim_question"], stroke=10)
        elif style == "end":
            ov.band(img, *LAYOUT["sim_band"], 0.8)
            dr = ImageDraw.Draw(img)
            ov.rows(dr, sub, *LAYOUT["sim_end"], stroke=10)
        elif style == "cta":
            ov.cta(img, t - cur["start"], LAYOUT["sim_band"])
        elif cur:
            ov.rows(dr, ov.page_of(sub, t, cur["start"], cur["end"]), *LAYOUT["sim_sub"])
        return img.convert("RGB")

    return frame, nf


def stills(ep: dict, out: Path, frames: str) -> list:
    fr, _ = frame_fn(ep, out)
    (out / "check").mkdir(exist_ok=True)
    res = []
    for f in [int(x) for x in frames.split(",")]:
        q = out / "check" / f"c_{f:04d}.png"
        fr(f).save(q)
        res.append(q)
    return res


def sfx_events(ep: dict, out: Path) -> list:
    """題材の ep.py に sfx_events(L) があればそれを使う(L は id → 行の時刻)。無ければ行の頭(2 行目から)に「シュッ」。"""
    L = {l["id"]: l for l in json.loads((out / "timeline.json").read_text(encoding="utf-8"))["lines"]}
    f = getattr(ep["_mod"], "sfx_events", None)
    return f(L) if f else [(L[d["id"]]["start"], "whoosh") for d in ep["lines"][1:]]


def final(ep: dict, out: Path, name: str) -> Path:
    fr, n = frame_fn(ep, out)
    audio = sfx.mix(out / "narration.wav", sfx_events(ep, out), out / "narration_sfx.wav") if ep.get("sfx", True) else out / "narration.wav"
    return compose.write(fr, n, audio, out / f"{name}.mp4", bgm=ep.get("bgm"))
