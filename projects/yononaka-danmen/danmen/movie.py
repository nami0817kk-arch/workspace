# -*- coding: utf-8 -*-
"""台本と画面をつないで動画にする。

台本（YAML）の行を上から読み、

  ・`screen:` の行  … ここから出す画面を切り替える（画像の名前）
  ・`cast:` の行    … 立ち絵の出し方を決める。
                      `auto` … **2人とも常に出す**（左に語り手、右に聞き手）。
                               しゃべっている人が明るく、聞いている人は少し暗い
                      `なし` … 消す
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
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

from danmen import typo

from danmen import cast, tts

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


# 行の強さから表情を決める。**語り手と聞き手で意味が違う。**
# 語り手の「強」は力をこめて話すこと、聞き手の「強」は驚くこと。
AUTO_MOOD = {
    "katari": {"ふつう": "setsumei", "強": "shinken", "特強": "shinken", "抑": ""},
    "kikite": {"ふつう": "", "強": "odoroki", "特強": "odoroki", "抑": "nattoku"},
}
# 画面の左右に、いつも同じ人が立つ（入れ替わらない）
SEATS = [("left", "katari"), ("right", "kikite")]
LISTEN_MOOD = {"katari": "", "kikite": "nattoku"}      # 聞いているときの顔


def auto_mood(art: str, tone: str) -> str:
    """その人の、その強さに合う表情。無ければ素の顔。"""
    return AUTO_MOOD.get(art, {}).get(tone, "")


def parse_cast(text: str) -> dict | None:
    """立ち絵の出し方を読む。

    `auto` または `auto 420` … **2人とも出す**（数字は高さ、既定 400）
    `なし` … 消す
    """
    t = text.split()
    if not t or t[0] in ("なし", "none", "-"):
        return None
    # 高さだけ指定できる（既定 400）。誰を出すかは SEATS で決まっている
    h = 400
    for a in t[1:]:
        if a.isdigit():
            h = int(a)
    return {"height": h}


def cast_width(height: int) -> int:
    """その高さで立ち絵を出したときの、画面の左右それぞれの占有幅。"""
    w = 0
    for _, who in SEATS:
        ch = cast.load(who, "", height, "bust")
        if ch is not None:
            w = max(w, ch.width)
    return w


def put_cast(base: Image.Image, height: int, speaker: str, tone: str) -> Image.Image:
    """画面に立ち絵を重ねる。**2人とも常に出す。**

    片方だけ出すと、話者が変わるたびに画面の人が入れ替わって落ち着かない
    （2026-10-08 ユーザー指示）。左に語り手、右に聞き手で固定し、
    **しゃべっている人を明るく、聞いている人を少し暗く小さく**する。

    口は動かさない（画像処理で開ける方法は3通り試して、どれも浮いた）。
    """
    im = base.convert("RGBA").copy()
    for side, who in SEATS:
        speaking = who == speaker
        h = height if speaking else int(height * 0.90)
        mood = auto_mood(who, tone) if speaking else LISTEN_MOOD.get(who, "")
        ch = cast.load(who, mood, h, "bust")
        if ch is None:
            continue
        x = 62 if side == "left" else (W - 62 - ch.width)
        y = H - 6 - ch.height
        if speaking:
            # 縁をうっすら光らせる
            a = ch.split()[3]
            ring = a.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(7))
            halo = Image.new("RGBA", ch.size, (255, 248, 226, 0))
            halo.putalpha(ring.point(lambda v: int(v * 0.50)))
            im.alpha_composite(halo, (x, y))
        else:
            # 聞いている人は少し暗く落とす（誰がしゃべっているかを見失わないように）
            rgb = ImageEnhance.Brightness(ch.convert("RGB")).enhance(0.72)
            dim = rgb.convert("RGBA")
            dim.putalpha(ch.split()[3].point(lambda v: int(v * 0.88)))
            ch = dim
        im.alpha_composite(ch, (x, y))
    return im.convert("RGB")


# ---- 字幕 -------------------------------------------------------------------

def _wrap(d, text: str, font, width: float) -> list[str]:
    """折り返しは `typo.wrap` に任せる（日本語の組版の決まりを守る）。"""
    return typo.wrap(d, text, font, width)

def caption(im: Image.Image, text: str, size: int = 74,
            side_room: int = 0) -> Image.Image:
    """字幕を焼く。縁を全部描いてから本体を描く（潰れを避けるため）。

    `side_room` は、**左右それぞれ**に空ける幅。立ち絵が2人いる画面で
    字幕を画面いっぱいに書くと、字の端が立ち絵にかかる。
    """
    out = im.convert("RGB").copy()
    d = ImageDraw.Draw(out)
    width = W - 160 - side_room * 2
    # **3行目は捨てずに、字を小さくして2行に収める。**
    # 2人の立ち絵で字幕の幅が狭まったとき、文末が切れていた（2026-10-08）
    f = F(size)
    lines = _wrap(d, text, f, width)
    while len(lines) > 2 and size > 52:
        size -= 4
        f = F(size)
        lines = _wrap(d, text, f, width)
    lines = lines[:2]
    y0 = H - 60 - len(lines) * int(size * 1.34)
    # 置き場所を先に決めておく（文字ごとの x）
    place: list[tuple[str, float, float, bool]] = []
    for n, ln in enumerate(lines):
        x = (W - d.textlength(ln, font=f)) / 2
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
        # 立ち絵が出ているぶん、字幕が使える幅を左右から狭める
        # 立ち絵の矩形には透明な余白がある。実際の人の幅に合わせて少し詰める
        room = int(cast_width(cast_spec["height"]) * 0.76) if cast_spec else 0
        shot = work / "{:03d}.jpg".format(n)
        frame = (put_cast(current, cast_spec["height"], art, step["tone"])
                 if cast_spec else current)
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
