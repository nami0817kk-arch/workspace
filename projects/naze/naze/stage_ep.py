"""画面の作り(stage.py)で描く回(kind: "stage")。2026-11-20 から新しい回はこれで作る。

EP: kind="stage", qtag="その回の問い(左上)", lines=[...], colors={名前: (r, g, b)}?, meter=dict(label, fmt)?, map=dict(lat0, bases)?
素材は題材のフォルダ(章なら題材のフォルダ)の assets/ に置き、出典は assets/sources.json に控える(tools/media.py が書く)。
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from . import compose, sfx, tts
from .config import FPS


def _with_marks(lines):
    """fx・場面の on="言葉" を、声の時間割で測る言葉(marks)に入れる。"""
    out = []
    for l in lines:
        keys = list(l.get("marks", []))
        keys += [f["on"] for f in l.get("fx", []) if f.get("on")]
        keys += [w for w in (l.get("scene") or {}).get("rows_on", []) if w]
        out.append(dict(l, marks=list(dict.fromkeys(keys))) if keys else l)
    return out


def _rows_on_marks(lines):
    """words の 2 行目以降を出す言葉は、その言葉を含む行の marks にも入れる(場面の行と別の行に書くことが多い)。"""
    words = [w for l in lines for w in (l.get("scene") or {}).get("rows_on", []) if w]
    out = []
    for l in lines:
        ks = [w for w in words if w in l.get("text", "")]
        out.append(dict(l, marks=list(dict.fromkeys(list(l.get("marks", [])) + ks))) if ks else l)
    return out


def kana(ep: dict) -> None:
    for s in tts.kana(ep["lines"]):
        print(s)


def voice(ep: dict, out: Path) -> dict:
    tl = tts.synth(_rows_on_marks(_with_marks(ep["lines"])), out)
    (out / "timeline.json").write_text(json.dumps(tl, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"語り {tl['total']:.1f} 秒")
    return tl


def frame_fn(ep: dict, out: Path):
    from .stage import Stage
    tl = json.loads((out / "timeline.json").read_text(encoding="utf-8"))
    st = Stage(ep, tl, out)
    return st.frame, int(math.ceil(tl["total"] * FPS))


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
    """場面が替わる行の頭に「シュッ」。題材に sfx_events(L) があればそちら。"""
    L = {l["id"]: l for l in json.loads((out / "timeline.json").read_text(encoding="utf-8"))["lines"]}
    f = getattr(ep["_mod"], "sfx_events", None)
    if f:
        return f(L)
    return [(L[d["id"]]["start"], "whoosh") for d in ep["lines"][1:] if d.get("scene") and d["id"] in L]


def final(ep: dict, out: Path, name: str) -> Path:
    fr, n = frame_fn(ep, out)
    audio = sfx.mix(out / "narration.wav", sfx_events(ep, out), out / "narration_sfx.wav") if ep.get("sfx", True) else out / "narration.wav"
    return compose.write(fr, n, audio, out / f"{name}.mp4", bgm=None, folder=Path(ep["_mod"].__file__).parent)
