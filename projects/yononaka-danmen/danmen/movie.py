# -*- coding: utf-8 -*-
"""台本と画面をつないで動画にする。

台本（YAML）の行を上から読み、

  ・`screen:` の行  … ここから出す画面を切り替える（画像の名前）
  ・`cast:` の行    … ここから立ち絵を出す（「kikite odoroki right 430」の形。
                      「なし」で消す）。**しゃべっている人の口は声に合わせて動く**
  ・話者の行        … 読み上げて、その長さだけ画面を出す。字幕も焼く

行ごとに声を作って**長さを測る**ので、画面の切り替えは語りに合う。
最後に ffmpeg で連番の画像と音声をつないで mp4 にする。

    python -m danmen.movie 台本.yaml --screens out/screens --out out/試作.mp4

字幕の縁は**縁を全部描いてから本体を描く**（1文字ずつ重ねると、次の字の縁が
前の字を潰す）。数字だけ金の細縁を足す。
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import urllib.parse
import urllib.request
import wave
from pathlib import Path

import yaml
from PIL import Image, ImageDraw, ImageFont

from danmen import typo

from danmen import cast, lipsync, tts

W, H = 1920, 1080
FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"
GOLD = (255, 206, 72)        # 字幕の数字。板の金より明るくする
EDGE = (6, 10, 18)
NUM = re.compile(r"(\d+(?:[.,]\d+)*)")
FPS = 30
READ_MAX = 6.5        # 字幕が読める速さの上限（字／秒）


def F(size: int, weight: int = 900) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT_PATH, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def ffmpeg() -> str:
    """ffmpeg の場所。imageio 同梱のものを使う（別に入れなくてよい）。"""
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return "ffmpeg"


# ---- 台本 -------------------------------------------------------------------

def read_script(path: Path) -> list[dict]:
    """台本を、頭から順の指示の列にする。

    返すのは {"screen": 名前} か {"who": 話者, "tone": 強さ, "text": 本文} の並び。
    """
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    out: list[dict] = []
    for sec in data.get("sections", []):
        for line in sec.get("lines", []):
            if not isinstance(line, dict) or len(line) != 1:
                raise SystemExit("読めない行です（節 {}）: {}".format(sec.get("id"), line))
            key, val = next(iter(line.items()))
            if key == "screen":
                out.append({"screen": str(val)})
                continue
            if key == "cast":
                out.append({"cast": str(val)})
                continue
            m = re.match(r"^(?P<who>[^\s(（]+)\s*(?:[（(](?P<tone>[^）)]+)[）)])?$", key)
            if not m:
                raise SystemExit("話者の書き方が読めません: {}".format(key))
            out.append({"who": m["who"], "tone": m["tone"] or "ふつう", "text": str(val)})
    return out


def parse_cast(text: str) -> dict | None:
    """「kikite odoroki right 430」を読む。「なし」なら立ち絵を消す。"""
    t = text.split()
    if not t or t[0] in ("なし", "none", "-"):
        return None
    return {"who": t[0],
            "mood": (t[1] if len(t) > 1 and t[1] != "-" else ""),
            "side": (t[2] if len(t) > 2 else "right"),
            "height": int(t[3]) if len(t) > 3 else 430}


def put_cast(base: Image.Image, spec: dict, amount: float = 0.0) -> Image.Image:
    """画面に立ち絵を重ねる。amount は口の開き具合。"""
    im = base.convert("RGBA").copy()
    # 口を開けるのは cast.load の中（切り出す前の全身の絵に対して行う）
    ch = cast.load(spec["who"], spec["mood"], spec["height"], "bust", mouth=amount)
    if ch is None:
        return im.convert("RGB")
    x = (W - 40 - ch.width) if spec["side"] != "left" else 40
    im.alpha_composite(ch, (x, H - 6 - ch.height))
    return im.convert("RGB")


# ---- 字幕 -------------------------------------------------------------------

def _wrap(d, text: str, font, width: float) -> list[str]:
    """折り返しは `typo.wrap` に任せる（日本語の組版の決まりを守る）。"""
    return typo.wrap(d, text, font, width)

def caption(im: Image.Image, text: str, size: int = 74,
            side_room: int = 0) -> Image.Image:
    """字幕を焼く。縁を全部描いてから本体を描く（潰れを避けるため）。

    `side_room` は、立ち絵のために空ける右の幅。立ち絵が出ている画面で
    字幕を画面いっぱいに書くと、字の端が立ち絵にかかる。
    """
    out = im.convert("RGB").copy()
    d = ImageDraw.Draw(out)
    f = F(size)
    lines = _wrap(d, text, f, W - 220 - side_room)[:2]
    y0 = H - 60 - len(lines) * int(size * 1.34)
    # 置き場所を先に決めておく（文字ごとの x）
    place: list[tuple[str, float, float, bool]] = []
    for n, ln in enumerate(lines):
        x = (W - side_room - d.textlength(ln, font=f)) / 2
        y = y0 + n * int(size * 1.34)
        for part in NUM.split(ln):
            if not part:
                continue
            place.append((part, x, y, bool(NUM.fullmatch(part))))
            x += d.textlength(part, font=f)
    # ① 黒い太い縁を全部。縁を先に全部描いてから本体を描く
    for part, x, y, _ in place:
        d.text((x, y), part, font=f, fill=EDGE, stroke_width=17, stroke_fill=EDGE)
    # ② 本体。数字は金、ほかは白
    #    金の文字にさらに金の縁を重ねていたのをやめた（2026-10-07）。
    #    金の上に金を重ねると輪郭がぼやけ、黒の縁も細くなって読みにくかった。
    for part, x, y, is_num in place:
        d.text((x, y), part, font=f, fill=GOLD if is_num else (255, 255, 255))
    return out


# ---- 組み立て ---------------------------------------------------------------

def wav_seconds(p: Path) -> float:
    with wave.open(str(p), "rb") as w:
        return w.getnframes() / w.getframerate()


def build(script: Path, screens_dir: Path, out: Path, config: Path,
          gap: float = 0.28) -> Path:
    cfg = tts.load_config(config)
    steps = read_script(script)
    work = out.parent / "_movie"
    work.mkdir(parents=True, exist_ok=True)
    for old in work.glob("*"):
        old.unlink()

    current: Image.Image | None = None
    current_name = ""
    cast_spec: dict | None = None
    # 台本の話者の名前（語り／聞き）から、立ち絵の名前（katari／kikite）へ
    who_art = {k: Path(str(v.get("image", ""))).stem or k
               for k, v in cfg.get("cast", {}).items()}
    too_fast: list[tuple[int, str, float]] = []
    wavs: list[Path] = []
    shots: list[tuple[Path, float]] = []      # (画像, 出す秒数)
    n = 0
    for step in steps:
        if "cast" in step:
            cast_spec = parse_cast(step["cast"])
            continue
        if "screen" in step:
            current_name = step["screen"]
            p = screens_dir / (current_name + ".png")
            if not p.exists():
                raise SystemExit("画面が見つかりません: {}".format(p))
            current = Image.open(p).convert("RGB")
            if current.size != (W, H):
                current = current.resize((W, H), Image.LANCZOS)
            continue
        if current is None:
            raise SystemExit("最初の話者の行より前に screen: がありません")
        style_id, params = tts.params_for(cfg, step["who"], step["tone"])
        wav = work / "{:03d}.wav".format(n)
        wav.write_bytes(tts.synth(cfg["engine_url"], step["text"], style_id, **params))
        wavs.append(wav)
        sec = wav_seconds(wav) + gap
        # 中間の画像は JPEG。PNG は 1枚 0.59 秒かかるが JPEG なら 0.04 秒。
        # 最後に H.264 にするので、この段階の劣化は見えない（2026-10-07 実測）
        art = who_art.get(step["who"], "")
        speaking = bool(cast_spec) and cast_spec["who"] == art
        # 立ち絵が出ているぶん、字幕が使える幅を狭める
        room = 0
        if cast_spec:
            ch = cast.load(cast_spec["who"], cast_spec["mood"], cast_spec["height"], "bust")
            room = (ch.width + 80) if ch is not None else 0
        if speaking:
            mood_name = cast_spec["who"] + (
                "_" + cast_spec["mood"] if cast_spec["mood"] else "")
            # もともと口が開いている表情は動かせないので、1枚で済ませる
            speaking = lipsync.can_move(mood_name)
        if speaking:
            # 声に合わせて口を動かす。同じ開き具合が続くところはまとめるので、
            # 作る画像は3枚（閉じ・半分・開き）で済む
            made: dict[float, Path] = {}
            for amt, dur in lipsync.runs(lipsync.levels(wav)):
                if amt not in made:
                    p = work / "{:03d}_{:.0f}.jpg".format(n, amt * 100)
                    caption(put_cast(current, cast_spec, amt),
                            step["text"], side_room=room).save(p, quality=93)
                    made[amt] = p
                shots.append((made[amt], dur))
            # 行と行のあいだの無音ぶんは、口を閉じたコマで埋める
            if 0.0 not in made:
                p = work / "{:03d}_sil.jpg".format(n)
                caption(put_cast(current, cast_spec, 0.0),
                        step["text"], side_room=room).save(p, quality=93)
                made[0.0] = p
            shots.append((made[0.0], gap))
        else:
            shot = work / "{:03d}.jpg".format(n)
            frame = put_cast(current, cast_spec) if cast_spec else current
            caption(frame, step["text"], side_room=room).save(shot, quality=93)
            shots.append((shot, sec))
        # 字幕が読める速さか。日本語の字幕は **1秒あたり 4〜6文字**が目安。
        # これを超えると、聞けても読めない（読み終わる前に次へ行く）。
        cps = len(step["text"]) / sec if sec else 0
        fast = "  ← 速い（{:.1f}字/秒）".format(cps) if cps > READ_MAX else ""
        if fast:
            too_fast.append((n + 1, step["text"], cps))
        print("  {:>3}  {:>5.2f}秒  {:>4.1f}字/秒  [{}]  {}{}".format(
            n + 1, sec, cps, current_name, step["text"][:26], fast))
        n += 1

    if not shots:
        raise SystemExit("話者の行が1つもありません")

    # 音声をつなぐ
    voice = work / "voice.wav"
    tts.join_wavs(wavs, voice, gap_sec=gap)

    # 画像の並びを ffmpeg の concat で渡す
    lst = work / "list.txt"
    with lst.open("w", encoding="utf-8") as fh:
        for p, sec in shots:
            fh.write("file '{}'\n".format(p.as_posix()))
            fh.write("duration {:.3f}\n".format(sec))
        fh.write("file '{}'\n".format(shots[-1][0].as_posix()))   # 最後は1回多く要る

    out.parent.mkdir(parents=True, exist_ok=True)
    # preset は veryfast。medium（45分）より速く（29分）、しかも容量が小さい
    cmd = [ffmpeg(), "-y", "-f", "concat", "-safe", "0", "-i", str(lst),
           "-i", str(voice), "-c:v", "libx264", "-preset", "veryfast",
           "-pix_fmt", "yuv420p",
           "-r", str(FPS), "-c:a", "aac", "-b:a", "192k", "-shortest", str(out)]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print(r.stderr[-2500:], file=sys.stderr)
        raise SystemExit("ffmpeg が失敗しました")
    total = sum(s for _, s in shots)
    print("書き出しました: {}（{:.1f}秒 / 画面 {}枚）".format(out, total, len(shots)))
    if too_fast:
        print()
        print("字幕が速すぎる行が {} つあります（目安は {} 字/秒まで）。".format(
            len(too_fast), READ_MAX))
        for i, text, cps in too_fast:
            print("  {:>3}  {:.1f}字/秒  {}".format(i, cps, text))
        print("  → 台本を短くするか、2行に割って画面を1枚足してください。")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="台本と画面をつないで動画にする")
    ap.add_argument("script", help="台本（YAML）")
    ap.add_argument("--screens", required=True, help="画面の画像を置いた場所")
    ap.add_argument("--out", default="out/movie.mp4")
    ap.add_argument("--config", default="config.yaml")
    ap.add_argument("--gap", type=float, default=0.28, help="行と行のあいだ（秒）")
    a = ap.parse_args()
    build(Path(a.script), Path(a.screens), Path(a.out), Path(a.config), a.gap)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
