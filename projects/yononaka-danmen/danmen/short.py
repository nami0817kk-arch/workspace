# -*- coding: utf-8 -*-
"""ショート（縦 1080×1920）を、本編の台詞から作る。

台本の `shorts:` に、使う台詞（本文の頭）を並べる。**ショート専用の台詞は書かない**（CLAUDE.md）。

    shorts:
      intro: [ビールを作る大手4社に, ...]    # 10本とも頭に置く台詞（intro: true の回）
      s1:
        title: 上の段に出す題／2行目
        hook: 最初の数秒に上の段に出す問い／2行目
        tease: 最後に大きく出す問い（**答えは本編にだけある**）
        intro: true
        lines: [台詞の頭, ...]

    python -m danmen.short scripts/cartel.yaml --only s1
    python -m danmen.short scripts/cartel.yaml          # 全部

画面の作り（上から）:
  題（最初の HOOK_SEC 秒は頭の問い） → 本編の画面（板・背景・言いたいことの帯） → 字幕と名札 → 2人の立ち絵
最後に TEASE_SEC 秒、終わりの問いを大きく出す（「答えは本編で」）。
口パク・瞬き・表情・声の速さ・読み替えは本編（movie.py）と同じものを使う。
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import wave
from array import array
from pathlib import Path

import yaml
from PIL import Image, ImageDraw, ImageEnhance

from danmen import cast, lipsync, reading, sfx, tts
from danmen.movie import (EDGE, FPS, GOLD, NUM, SPEAKER_TAG, F, _breaks, ffmpeg, gap_after,
                          listen_face, read_script, speak_face)

W, H = 1080, 1920
NAVY = (10, 16, 34)
TOP_H = 330                      # 題の段
SCREEN_Y = TOP_H                 # 本編の画面（1920×1080 を幅 1080 に）
SCREEN_H = 608
CAST_H = 600                     # 立ち絵の高さ（おなかまで）
CAP_Y0, CAP_Y1 = SCREEN_Y + SCREEN_H + 30, H - CAST_H + 40
HOOK_SEC = 3.5                   # 最初に頭の問いを出す秒数
TEASE_SEC = 3.0                  # 最後に終わりの問いを出す秒数
SEATS = [("left", "katari"), ("right", "kikite")]
ART = {"語り": "katari", "聞き": "kikite"}


class Sink:
    def __init__(self, path: Path):
        self.p = subprocess.Popen(
            [ffmpeg(), "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
             "-s", "{}x{}".format(W, H), "-r", str(FPS), "-i", "-",
             "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p", str(path)],
            stdin=subprocess.PIPE)
        self.frames = 0

    def add(self, im: Image.Image, n: int) -> None:
        b = im.convert("RGB").tobytes()
        for _ in range(n):
            self.p.stdin.write(b)
        self.frames += n

    def close(self) -> None:
        self.p.stdin.close()
        if self.p.wait() != 0:
            raise SystemExit("ffmpeg が失敗しました（ショートの映像）")


def wrap_words(d, text: str, font, width: float) -> list[str]:
    """言葉の切れ目（文節の頭・句読点のあと）で、幅に収まるように何行にでも割る。

    本編の `_wrap` は2行に収まらないとき文字数で割る処理に落ち、そこが幅を守っていなかった
    （縦の画面で字幕がはみ出した。2026-10-10）。1つの言葉が幅より長いときだけ、文字で割る。
    """
    cuts = [0] + sorted(set(_breaks(text))) + [len(text)]
    segs = [text[a:b] for a, b in zip(cuts, cuts[1:]) if b > a]
    lines, cur = [], ""
    for sg in segs:
        if d.textlength(cur + sg, font=font) <= width:
            cur += sg
            continue
        if cur:
            lines.append(cur)
        cur = sg
        while d.textlength(cur, font=font) > width:      # 1つの言葉が長すぎる
            k = len(cur)
            while k > 1 and d.textlength(cur[:k], font=font) > width:
                k -= 1
            lines.append(cur[:k]); cur = cur[k:]
    if cur:
        lines.append(cur)
    return lines


def _center_lines(d, lines, font, y, fills, stroke=12, gap=1.22):
    for n, ln in enumerate(lines):
        w = d.textlength(ln, font=font)
        d.text(((W - w) / 2, y + n * int(font.size * gap)), ln, font=font, fill=fills[min(n, len(fills) - 1)],
               stroke_width=stroke, stroke_fill=EDGE)


def top_band(text: str) -> Image.Image:
    """上の段（題か頭の問い）。「／」で2行に割る。2行目は金。"""
    im = Image.new("RGB", (W, TOP_H), NAVY)
    d = ImageDraw.Draw(im)
    lines = [t for t in str(text).split("／") if t]
    size = 84
    while size > 52 and max(d.textlength(t, font=F(size)) for t in lines) > W - 70:
        size -= 4
    total = len(lines) * int(size * 1.22)
    _center_lines(d, lines, F(size), (TOP_H - total) // 2, [(255, 255, 255), GOLD])
    d.rectangle([0, TOP_H - 6, W, TOP_H], fill=GOLD)
    return im


def subtitle(base: Image.Image, text: str, who: str) -> Image.Image:
    """字幕と名札。画面の下（立ち絵の上）に、最大3行。"""
    out = base.copy()
    d = ImageDraw.Draw(out)
    width = W - 90
    size, lines = 70, None
    while size >= 50:
        lines = wrap_words(d, text, F(size), width)
        if len(lines) <= 3:
            break
        size -= 4
    f = F(size)
    lh = int(size * 1.3)
    y0 = CAP_Y0 + 60
    place = []
    for n, ln in enumerate(lines[:3]):
        x = (W - d.textlength(ln, font=f)) / 2
        y = y0 + n * lh
        for part in NUM.split(ln):
            if part:
                place.append((part, x, y, bool(NUM.fullmatch(part))))
                x += d.textlength(part, font=f)
    for part, x, y, _ in place:
        d.text((x, y), part, font=f, fill=EDGE, stroke_width=15, stroke_fill=EDGE)
    for part, x, y, num in place:
        d.text((x, y), part, font=f, fill=GOLD if num else (255, 255, 255))
    if who in SPEAKER_TAG and place:
        name, col = SPEAKER_TAG[who]
        tf = F(38, 900)
        tw = d.textlength(name, font=tf) + 40
        left = min(x for _, x, _, _ in place)
        right = max(x + d.textlength(p, font=f) for p, x, _, _ in place)
        tx = left if who == "katari" else right - tw
        d.rounded_rectangle([tx, y0 - 62, tx + tw, y0 - 10], radius=26, fill=col, outline=(255, 255, 255), width=3)
        d.text((tx + 20, y0 - 58), name, font=tf, fill=(255, 255, 255))
    return out


_dim: dict = {}


def put_two(im: Image.Image, speaker: str, faces: dict, mouth, blinking) -> Image.Image:
    out = im.convert("RGBA")
    for side, who in SEATS:
        speaking = who == speaker
        ch = cast.bust(who, CAST_H, faces.get(who, "normal"), mouth if speaking else "closed", who in blinking)
        x = -30 if side == "left" else W - ch.width + 30
        if not speaking:
            key = (who, faces.get(who), who in blinking)
            if key not in _dim:
                dim = ImageEnhance.Brightness(ch.convert("RGB")).enhance(0.72).convert("RGBA")
                dim.putalpha(ch.split()[3].point(lambda v: int(v * 0.9)))
                _dim[key] = dim
            ch = _dim[key]
        out.alpha_composite(ch, (int(x), H - ch.height))
    return out.convert("RGB")


def tease_card(text: str) -> Image.Image:
    im = Image.new("RGB", (W, H), NAVY)
    d = ImageDraw.Draw(im)
    parts = [t for t in str(text).split("／") if t]
    size = 88
    lines, fills = [], []
    for k, t in enumerate(parts):
        for ln in wrap_words(d, t, F(size), W - 110):
            lines.append(ln); fills.append((255, 255, 255) if k == 0 else GOLD)
    y = 900 - len(lines) * int(size * 1.22)
    for n, ln in enumerate(lines):
        w = d.textlength(ln, font=F(size))
        d.text(((W - w) / 2, y + n * int(size * 1.22)), ln, font=F(size), fill=fills[n], stroke_width=14, stroke_fill=EDGE)
    f2 = F(64)
    msg = "答えは、本編で。"
    d.rounded_rectangle([(W - d.textlength(msg, font=f2)) / 2 - 40, 1120, (W + d.textlength(msg, font=f2)) / 2 + 40, 1220],
                        radius=20, fill=GOLD)
    d.text(((W - d.textlength(msg, font=f2)) / 2, 1130), msg, font=f2, fill=NAVY)
    return im


def lines_of(doc: dict, sid: str, steps: list[dict]) -> list[tuple[dict, str]]:
    """そのショートで使う (台詞の手順, その時の画面の名前) を、本編の順に。"""
    spec = doc["shorts"][sid]
    heads = (list(doc["shorts"].get("intro") or []) if spec.get("intro") else []) + list(spec["lines"])
    screen, table = None, []
    for st in steps:
        if "screen" in st:
            screen = st["screen"]
        elif "who" in st:
            table.append((st, screen))
    picked = []
    for h in heads:
        hits = [i for i, (st, _) in enumerate(table) if st["text"].startswith(str(h))]
        if len(hits) != 1:
            raise SystemExit("{}: 台詞「{}」が {} 行に当たります（1行に決めてください）".format(sid, h, len(hits)))
        picked.append(hits[0])
    return [table[i] for i in sorted(set(picked))]


def build(script: Path, sid: str, screens: Path, out: Path, config: Path, gap: float = 0.28) -> Path:
    cfg = tts.load_config(config)
    doc = yaml.safe_load(script.read_text(encoding="utf-8"))
    spec = doc["shorts"][sid]
    steps = read_script(script)
    rows = lines_of(doc, sid, steps)
    work = out.parent / "_short_{}".format(sid)
    work.mkdir(parents=True, exist_ok=True)
    for old in work.glob("*"):
        old.unlink()
    # 一番上の文字は、shorts.top があれば全部の回で固定（2026-10-10 ユーザー「固定で良い」）
    fixed = doc["shorts"].get("top")
    title_band = top_band(fixed or spec.get("title", ""))
    hook_band = title_band if fixed else (top_band(spec.get("hook", "")) if spec.get("hook") else title_band)
    video = work / "video.mp4"
    sink = Sink(video)
    blink_at = {"katari": lipsync.blinks30(600, FPS, seed=7), "kikite": lipsync.blinks30(600, FPS, seed=19)}
    wavs, gaps, cues = [], [], []
    frame_no, at = 0, 0.0
    shot_cache: dict = {}
    for n, (step, scr) in enumerate(rows):
        art = ART[step["who"]]
        style_id, params = tts.params_for(cfg, step["who"], step["tone"])
        say = reading.reading(step["text"])
        wav = work / "{:03d}.wav".format(n)
        wav.write_bytes(tts.synth(tts.engine_for(cfg, step["who"]), say, style_id, **params))
        nxt = rows[n + 1][0] if n + 1 < len(rows) else None
        this_gap = gap_after(step["text"], nxt, gap) if nxt else 0.5
        wavs.append(wav); gaps.append(this_gap)
        with wave.open(str(wav)) as w:
            sec = w.getnframes() / w.getframerate()
        q = tts.timing_query(say)
        shapes, _ = lipsync.visemes(wav, q, exact=tts.engine_for(cfg, step["who"]).endswith(":50021"), fps=FPS)
        if scr and scr.endswith("01") and (screens / (scr[:-2] + "02.png")).exists():
            scr = scr[:-2] + "02"            # 節の扉はショートでは出さない（その節の次の画面に）
        if scr not in shot_cache:
            p = screens / (scr + ".png")
            shot_cache[scr] = Image.open(p).convert("RGB").resize((W, SCREEN_H), Image.LANCZOS)
        base = Image.new("RGB", (W, H), NAVY)
        base.paste(shot_cache[scr], (0, SCREEN_Y))
        caps = {}
        listener = [w_ for _, w_ in SEATS if w_ != art]
        sp_face = speak_face(art, step)
        li_face = {w_: listen_face(w_, step, nxt) for w_ in listener}
        react_at = int(len(shapes) * 0.55)
        f1 = int(round((at + sec + this_gap) * FPS))
        prev_key, run, prev_im = None, 0, None
        for k in range(f1 - frame_no):
            g = frame_no + k
            mouth = shapes[k] if k < len(shapes) else "closed"
            faces = {art: sp_face}
            for w_ in listener:
                faces[w_] = li_face[w_] if k >= react_at else "normal"
            blinking = frozenset(w_ for w_, bl in blink_at.items() if g in bl and faces.get(w_) == "normal")
            band = hook_band if g < HOOK_SEC * FPS else title_band
            key = (mouth, blinking, tuple(sorted(faces.items())), band is hook_band)
            if key == prev_key:
                run += 1
                continue
            if prev_im is not None:
                sink.add(prev_im, run)
            cb = (band is hook_band)
            if cb not in caps:
                b2 = base.copy(); b2.paste(band, (0, 0))
                caps[cb] = subtitle(b2, step["text"], art)
            prev_im = put_two(caps[cb], art, faces, mouth, blinking)
            prev_key, run = key, 1
        if prev_im is not None:
            sink.add(prev_im, run)
        cues.append({"start": at, "screen_changed": n == 0 or rows[n - 1][1] != scr,
                     "who": step["who"], "tone": step["tone"]})
        at += sec + this_gap
        frame_no = f1
        print("  {:>2}  {:>5.2f}秒  {}".format(n + 1, sec + this_gap, step["text"][:30]))
    # 終わりの問い
    card = tease_card(spec.get("tease", ""))
    sink.add(card, int(TEASE_SEC * FPS))
    sink.close()
    # 声をつなぐ（最後に問いのぶんの無音）
    voice = work / "voice.wav"
    gaps[-1] = gaps[-1] + TEASE_SEC
    tts.join_wavs(wavs, voice, gap_sec=gaps)
    evs = sfx.events(cues)
    if evs:
        with wave.open(str(voice), "rb") as w:
            prm = w.getparams(); data = w.readframes(w.getnframes())
        a = array("h"); a.frombytes(data)
        a = sfx.overlay(a, prm.framerate, prm.nchannels, evs)
        with wave.open(str(voice), "wb") as w:
            w.setparams(prm); w.writeframes(a.tobytes())
    out.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run([ffmpeg(), "-y", "-i", str(video), "-i", str(voice), "-c:v", "copy", "-c:a", "aac",
                        "-b:a", "192k", "-shortest", str(out)], capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print(r.stderr[-2000:], file=sys.stderr)
        raise SystemExit("ffmpeg が失敗しました")
    print("書き出しました: {}（{:.1f}秒）".format(out, sink.frames / FPS))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="ショート（縦）を本編の台詞から作る")
    ap.add_argument("script")
    ap.add_argument("--screens", default=r"C:/Users/なみ/dev/output/yononaka-danmen/screens")
    ap.add_argument("--out", default=r"C:/Users/なみ/dev/output/yononaka-danmen/shorts")
    ap.add_argument("--config", default="config.yaml")
    ap.add_argument("--only", help="この1本だけ（例 s1）")
    a = ap.parse_args()
    script = Path(a.script)
    doc = yaml.safe_load(script.read_text(encoding="utf-8"))
    ids = [a.only] if a.only else [k for k in doc["shorts"] if k not in ("intro", "top")]
    for sid in ids:
        print("■ {} {}".format(sid, doc["shorts"][sid].get("title", "")))
        build(script, sid, Path(a.screens), Path(a.out) / "{}_short_{}.mp4".format(script.stem, sid), Path(a.config))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
