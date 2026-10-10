# -*- coding: utf-8 -*-
"""台本と画面をつないで動画にする。

台本（YAML）の行を上から読み、

  ・`screen:` の行  … ここから出す画面を切り替える（画像の名前）
  ・`cast:` の行    … 立ち絵の出し方を決める。**どちらも2人とも出す。**
                      `auto` … 左右の**下**に2人（板に載る図の画面）
                      `wipe` … 右上の**箱**に2人（全画面の様式）
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
from array import array
from pathlib import Path

import yaml
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

from danmen import typo

from danmen import cast, lipsync, reading, sfx, tts

W, H = 1920, 1080
FONT_PATH = "C:/Windows/Fonts/NotoSansJP-VF.ttf"
GOLD = (255, 206, 72)        # 字幕の数字。板の金より明るくする
EDGE = (6, 10, 18)
NUM = re.compile(r"(\d+(?:[.,]\d+)*)")
FPS = 30
READ_MAX = 6.5        # 字幕が読める速さの上限（字／秒）
FADE_FRAMES = 3       # 画面が変わるときの重なり（30fps で 0.1 秒）


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
            # `short:` はショートに切り出すための印。**本編では読み飛ばす**
            # `face:` は話す人の表情、`react:` は聞いている人の反応（どちらも書かなければ自動）
            keys = [k for k in line if k not in ("short", "face", "react")] if isinstance(line, dict) else []
            if len(keys) != 1:
                raise SystemExit("読めない行です（節 {}）: {}".format(sec.get("id"), line))
            key = keys[0]
            val = line[key]
            if key == "screen":
                out.append({"screen": str(val)})
                continue
            if key == "cast":
                out.append({"cast": str(val)})
                continue
            m = re.match(r"^(?P<who>[^\s(（]+)\s*(?:[（(](?P<tone>[^）)]+)[）)])?$", key)
            if not m:
                raise SystemExit("話者の書き方が読めません: {}".format(key))
            out.append({"who": m["who"], "tone": m["tone"] or "ふつう", "text": str(val),
                        "face": FACE_NAME.get(str(line.get("face", "")), line.get("face")),
                        "react": FACE_NAME.get(str(line.get("react", "")), line.get("react"))})
    return out


# ---- 表情（2026-10-10 に作り直した）----------------------------------------
#
# **岬はほとんど変えない**（ユーザー「男の表情はほとんど変わらずだよ」）。淡々と事実を置く人なので、
# 台本に `face:` を書いた所だけ変える。
# **小倉は台詞の中身で変える**（驚く・考え込む・むっとする・感心する）。聞いている間も、
# 相手の台詞の**後半で**反応する（人は聞き終わる前に顔に出る。最初から変えると先回りに見える）。
# 前は「行の強さ」だけで決めていて、作った絵の大半（困る・不満・しょんぼり…）が一度も出なかった。
#
# 台本の書き方（どちらも省略可。書けば自動より優先）:
#     - 聞き: それ、ずるくないですか。
#       face: 不満            ← 話す人の表情
#     - 語り: 127億9780万円です。
#       react: 驚き           ← 聞いている人の反応

FACE_NAME = {"ふつう": "normal", "驚き": "surprise", "にっこり": "smile", "感心": "wonder",
             "不満": "pout", "困る": "trouble", "くやしい": "grimace", "すぼめる": "pucker",
             "え": "huh", "お": "oh", "しょんぼり": "sad", "真剣": "serious", "大笑い": "laugh",
             "": None, "None": None}
SEATS = [("left", "katari"), ("right", "kikite")]       # 左右に、いつも同じ人が立つ
REACT_FROM = 0.55                                      # 聞き手が反応し始めるのは、台詞のこの割合から
_NUM = re.compile(r"\d")
# 驚く数字は、金額・人数・件数・倍だけ（日付や年数で反応すると、ずっと口が開いている）
_BIG = re.compile(r"\d[\d,.]*\s*(億|万|円|人|件|倍)")


def speak_face(art: str, step: dict) -> str:
    """話している人の表情。"""
    if step.get("face"):
        return step["face"]
    if art == "katari":
        return "normal"                     # 岬は台本で書いた所だけ
    t, tone = step["text"], step["tone"]
    if tone in ("強", "特強"):
        return "surprise"
    if any(w in t for w in ("ずるい", "ずるく", "ひどい", "おかしくないですか")):
        return "pout"
    if "納得いかな" in t:
        return "pout"
    # 「〜じゃないんですね」「〜ないんですね」は、納得していない気づき。目を輝かせない
    if t.rstrip("。").endswith(("ないんですね", "ないんだ")):
        return "trouble"
    # 気づいた台詞（「……そうなんですね」）は感心。「……」で始まっても困り顔にしない
    if t.rstrip("。").endswith(("んですね", "んだ", "なるほど", "そういうことか", "そういうことですか")):
        return "wonder"
    if any(w in t for w in ("正直", "ピンとこない", "分からない", "わからない", "えっと", "どうしよう")):
        return "trouble"
    if t.startswith("……"):
        return "trouble"
    if any(w in t for w in ("よかった", "うれしい", "助かる")):
        return "smile"
    return "normal"


def listen_face(art: str, step: dict, nxt: dict | None, prev: dict | None = None) -> str:
    """聞いている人の反応（台詞の後半に出す）。"""
    if step.get("react"):
        return step["react"]
    if art == "katari":
        return "normal"                     # 岬は聞いていても顔を変えない
    t = step["text"]
    # 次に小倉が驚くなら、その手前で目を丸くし始める
    if nxt and nxt.get("who") == "聞き" and nxt.get("tone") in ("強", "特強"):
        return "surprise"
    # 大きな数字を聞いたら、口が小さく「お」の形になる。**数字が続く所では最初の1回だけ**
    if _BIG.search(t) and len(t) <= 30 and not (prev and prev.get("who") == step["who"] and _BIG.search(prev["text"])):
        return "oh"
    # 短い否定（「違います。」「書いてありません。」）には「え？」
    if len(t) <= 12 and t.rstrip("。").endswith(("違います", "ありません", "いません", "ないです")):
        return "huh"
    return "normal"


def parse_cast(text: str) -> dict | None:
    """立ち絵の出し方を読む。誰を出すかは `SEATS` で決まっている（2人とも）。

    `auto`  … 左右の**下**に2人。板に載る図の画面で（下 420px が空いている）
    `wipe`  … **箱**に2人。全画面の様式で（画面いっぱいに描くので、
              下に置くと中身と重なる）。場所を足せる（`wipe 右下`）。
              **画面ごとに空いている場所が違うので、画面を見て決める**
    どちらも数字を足すと大きさを変えられる（`auto 460` / `wipe 210`）。下の既定は 420。
    `なし`  … 消す
    """
    t = text.split()
    if not t or t[0] in ("なし", "none", "-"):
        return None
    style = "wipe" if t[0] in ("wipe", "箱", "ワイプ") else "bottom"
    # 下に置くときの高さは 420（2026-10-10 ユーザーが 320/380/420/480 を画面で見比べて選んだ。
    # 480 だと字幕の幅が足りず字が小さくなる）
    h = 190 if style == "wipe" else 420
    pos = "右上"
    for a in t[1:]:
        if a.isdigit():
            h = int(a)
        elif a in WIPE_POS:
            pos = a
    return {"style": style, "height": h, "pos": pos}


def cast_width(height: int) -> int:
    """その高さで立ち絵を出したときに、**人が実際に描かれている所**が画面の端から何 px まで来るか。

    絵の矩形には透明な余白があり、その割合は絵ごとに違う。前は「矩形の幅 × 0.76」で決めていて、
    新しい絵（2026-10-10）では字幕の端が小倉の髪にかかった。不透明な所の内側の端から測る。
    """
    w = 0
    for side, who in SEATS:
        ch = cast.bust(who, height)
        cols = [x for x in range(ch.width) if ch.getpixel((x, ch.height - 1))[3] > 0 or
                any(ch.getpixel((x, y))[3] > 40 for y in range(0, ch.height, 6))]
        if not cols:
            continue
        inner = (ch.width - min(cols)) if side == "right" else (max(cols) + 1)
        w = max(w, 62 + inner)
    return w


# ワイプを置ける場所。(箱の幅, 2つぶんの高さ) を受け取り、左上の座標を返す
WIPE_POS = {
    "右上": lambda w, h: (W - 44 - w, 44),
    "左上": lambda w, h: (44, 44),
    "右下": lambda w, h: (W - 44 - w, H - 270 - h),
    "左下": lambda w, h: (44, H - 270 - h),
}


def put_wipe(base: Image.Image, height: int, speaker: str, faces: dict,
             pos: str = "右上", mouth="closed", blinking: frozenset = frozenset()) -> Image.Image:
    """右上の箱に2人を縦に並べる。**全画面の様式**で使う。

    画面いっぱいに描く様式（速報の帯・左右の比べ・おさらい）では、下に立ち絵を
    置くと中身と重なった（2026-10-08）。`studio.flip` のワイプと同じ形。
    """
    im = base.convert("RGBA").copy()
    bw, bh = int(height * 0.86), height
    total = bh * 2 + 24
    x, y0 = WIPE_POS.get(pos, WIPE_POS["右上"])(bw, total)
    for i, (_, who) in enumerate(SEATS):
        y = y0 + i * (bh + 24)
        speaking = who == speaker
        mood = faces.get(who, "normal")
        ch = cast.bust(who, int(bh * 1.3), mood, mouth if speaking else "closed", who in blinking)
        d = ImageDraw.Draw(im)
        # 枠。しゃべっている人は金、聞いている人は灰
        edge = (231, 185, 63) if speaking else (96, 104, 118)
        d.rectangle([x - 5, y - 5, x + bw + 5, y + bh + 5], fill=edge)
        tile = Image.new("RGBA", (bw, bh), (20, 28, 44, 255))
        if ch is not None:
            # 顔が箱の中に収まるよう、上のほうを切り出す
            face = ch.crop((0, 0, ch.width, min(int(ch.height * 0.80), ch.height)))
            sc = bh / face.height
            face = face.resize((max(int(face.width * sc), 1), bh), Image.LANCZOS)
            tile.alpha_composite(face, ((bw - face.width) // 2, 0))
        if not speaking:
            tile = ImageEnhance.Brightness(tile.convert("RGB")).enhance(0.66).convert("RGBA")
        im.alpha_composite(tile, (x, y))
    return im.convert("RGB")


_dim: dict = {}


def put_cast(base: Image.Image, height: int, speaker: str, faces: dict,
             mouth="closed", blinking: frozenset = frozenset()) -> Image.Image:
    """画面に立ち絵を重ねる。**2人とも常に出す。**

    片方だけ出すと、話者が変わるたびに画面の人が入れ替わって落ち着かない
    （2026-10-08 ユーザー指示）。左に語り手、右に聞き手で固定し、
    **しゃべっている人を明るく、聞いている人を少し暗く小さく**する。

    口はしゃべっている人だけ動かす（mouth は lipsync の口の形）。瞬きは2人とも
    （blinking に入っている人が目を閉じる）。
    """
    im = base.convert("RGBA").copy()
    for side, who in SEATS:
        speaking = who == speaker
        h = height if speaking else int(height * 0.90)
        mood = faces.get(who, "normal")
        ch = cast.bust(who, h, mood, mouth if speaking else "closed", who in blinking)
        x = 62 if side == "left" else (W - 62 - ch.width)
        y = H - ch.height                       # 切り口を画面の下端にそろえる
        if not speaking:
            # 聞いている人は少し暗く落とす（誰がしゃべっているかを見失わないように）。
            # **話している人の縁を光らせるのはやめた**（2026-10-10 ユーザー「白い線は何で？」→「外して」）
            key = (who, h, mood, who in blinking)
            if key not in _dim:
                rgb = ImageEnhance.Brightness(ch.convert("RGB")).enhance(0.72)
                dim = rgb.convert("RGBA")
                dim.putalpha(ch.split()[3].point(lambda v: int(v * 0.88)))
                _dim[key] = dim
            ch = _dim[key]
        im.alpha_composite(ch, (x, y))
    return im.convert("RGB")


# ---- 字幕 -------------------------------------------------------------------

def _is_hira(c: str) -> bool:
    return "\u3041" <= c <= "\u309f"


_CONTENT = {"名詞", "動詞", "形容詞", "副詞", "代名詞", "連体詞", "接続詞", "感動詞", "形状詞", "接頭辞"}
# 前の語とひと続きに読む言葉。この手前では割らない（「聞いた｜こと」「書いて｜ある」）
_FORMAL = {"こと", "もの", "ところ", "よう", "わけ", "ため", "はず", "とき", "ほう", "くらい", "ぐらい",
           "など", "ん", "の", "まま", "うち", "ごと", "ぶん", "分", "方", "中", "目", "的"}
_tagger = None


def _tag(text: str):
    """fugashi（unidic-lite）で単語に分ける。入っていなければ None。"""
    global _tagger
    try:
        if _tagger is None:
            import fugashi
            _tagger = fugashi.Tagger()
        out, pos = [], 0
        for w in _tagger(text):
            i = text.find(w.surface, pos)
            if i < 0:
                return None
            out.append((i, w.surface, w.feature.pos1, w.feature.pos2))
            pos = i + len(w.surface)
        return out
    except Exception:
        return None


def _breaks(text: str) -> list[int]:
    """字幕を2行に割ってよい位置（その文字の手前で割る）。

    **文節の頭でだけ割る。** 単語に分けて（fugashi）、中身のある単語（名詞・動詞…）の手前を候補にする。
    ただし名詞が続く所（「受け取り｜手」）、「〜こと」「〜てある」の手前、かぎかっこの中では割らない。
    文字の種類だけで決めていたときは「ありますけ｜ど」「受け取り｜手」になった（2026-10-10）。
    """
    toks = _tag(text)
    if toks is None:
        return _breaks_by_char(text)
    out, depth = [], 0
    for n, (i, surf, p1, p2) in enumerate(toks):
        opens = surf and surf[0] in "「『（("
        if n and depth == 0:
            pi, psurf, pp1, pp2 = toks[n - 1]
            ok = False
            if pp1 == "補助記号" and psurf[-1] in "、。？?！!…」』）)" and surf[0] not in "、。」』）)ー…":
                ok = True
            elif opens:
                ok = pp1 not in ("接頭辞",)
            elif surf == "って" and pp1 in ("助動詞", "動詞", "形容詞"):
                ok = True                           # 「分からない｜ってことですか」
            elif p1 in _CONTENT and pp1 not in ("接頭辞",):
                ok = True
                if p1 in ("名詞", "代名詞") and pp1 in ("名詞", "代名詞", "接頭辞"):
                    ok = False                      # 名詞が続く（複合語）
                if surf in _FORMAL:
                    ok = False
                if p1 == "動詞" and p2 == "非自立可能" and psurf in ("て", "で"):
                    ok = False                      # 「書いて｜ある」
                if pp1 in ("名詞",) and p1 == "動詞" and surf[0] in "しすさせ":
                    ok = False                      # 「申請｜し」「納付｜する」
                if p1 == "動詞" and psurf in ("と", "って") and surf.startswith(("いう", "いっ", "いわ")):
                    ok = False                      # 「〜と｜いう」（漢字の「言う」は割ってよい）
            if ok:
                out.append(i)
        for c in surf:
            if c in "「『（(":
                depth += 1
            elif c in "」』）)":
                depth = max(depth - 1, 0)
    return out


def _breaks_by_char(text: str) -> list[int]:
    """fugashi が無いときの代わり。ひらがなから漢字・カタカナ・数字に変わる所で割る。"""
    out, depth = [], 0
    for i, c in enumerate(text):
        if c in "「『（(":
            if i and depth == 0 and (_is_hira(text[i - 1]) or text[i - 1] in "、。？?！!…"):
                out.append(i)
            depth += 1
            continue
        if c in "」』）)":
            depth = max(depth - 1, 0)
            continue
        if depth or i == 0:
            continue
        prev = text[i - 1]
        if prev in "、。？?！!" or (prev == "…" and c != "…"):
            if c not in "、。」』）)ー…":
                out.append(i)
        elif _is_hira(prev) and not _is_hira(c) and c not in "、。？?！!」』）)ーっゃゅょ…":
            out.append(i)
    return out


def _split2(d, text: str, font, width: float) -> list[str] | None:
    """1行か、言葉の切れ目で2行に割れるなら、その行。割れなければ None。"""
    if d.textlength(text, font=font) <= width:
        return [text]
    best = None
    for i in _breaks(text):
        a, b = text[:i], text[i:]
        wa, wb = d.textlength(a, font=font), d.textlength(b, font=font)
        if wa <= width and wb <= width:
            score = abs(wa - wb)
            if best is None or score < best[0]:
                best = (score, [a, b])
    return best[1] if best else None


CAP_SIZES = (74, 70, 66)     # 言葉の切れ目で2行に入れるために、ここまでは字を小さくしてよい


def _wrap(d, text: str, font, width: float) -> list[str]:
    """字幕の折り返し。**2行で収まるなら、言葉の切れ目のうち真ん中に近い所で割る。**

    文字数で割ると「ライバルどう｜し」「「不当｜な取引制限」」のように言葉の途中で切れた
    （2026-10-10。立ち絵を大きくして字幕の幅が狭まったとき）。割れないときだけ `typo.wrap` に任せる。
    """
    if d.textlength(text, font=font) <= width:
        return [text]
    best = None
    for i in _breaks(text):
        a, b = text[:i], text[i:]
        wa, wb = d.textlength(a, font=font), d.textlength(b, font=font)
        if wa <= width and wb <= width:
            score = abs(wa - wb)
            if best is None or score < best[0]:
                best = (score, [a, b])
    if best:
        return best[1]
    return typo.wrap(d, text, font, width)

# 話す人の名札。**字幕だけだと、どちらが話しているか分からない**（2026-10-10 ユーザー指摘）。
# 名前と色を札にして、話す人のいる側に寄せる（岬は左、小倉は右）。字幕の文字の色は変えない
SPEAKER_TAG = {"katari": ("岬", (52, 108, 196)), "kikite": ("小倉", (222, 92, 120))}


def caption(im: Image.Image, text: str, size: int = 74,
            side_room: int = 0, who: str = "") -> Image.Image:
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
    lines = None
    for sz in CAP_SIZES:
        lines = _split2(d, text, F(sz), width)
        if lines:
            size, f = sz, F(sz)
            break
    if not lines:
        lines = _wrap(d, text, f, width)
    while len(lines) > 2 and size > 52:
        size -= 4
        f = F(size)
        lines = _wrap(d, text, f, width)
    # **それでも収まらないときも、字は捨てない**（3行で出す）。前は2行で切っていて、
    # 立ち絵を大きくしたとき台詞の後ろが消えた（2026-10-10）。split_caption で先に割るので、
    # ここに来るのは句読点の無い長い一続きの言葉だけ
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
    if who in SPEAKER_TAG and lines:
        name, col = SPEAKER_TAG[who]
        tf = F(34, 900)
        tw = d.textlength(name, font=tf) + 36
        xs = [x for _, x, _, _ in place]
        left = min(xs)
        right = max(x + d.textlength(p, font=f) for p, x, _, _ in place)
        tx = left if who == "katari" else right - tw
        ty = y0 - 58
        d.rounded_rectangle([tx, ty, tx + tw, ty + 48], radius=24, fill=col,
                            outline=(255, 255, 255), width=3)
        d.text((tx + 18, ty + 4), name, font=tf, fill=(255, 255, 255))
    return out


_measure = ImageDraw.Draw(Image.new("RGB", (8, 8)))


def _fits(text: str, side_room: int) -> bool:
    """1行で収まるか、**言葉の切れ目で**2行に割って収まるか（字は CAP_SIZES まで小さくしてよい）。"""
    width = W - 160 - side_room * 2
    return any(_split2(_measure, text, F(sz), width) for sz in CAP_SIZES)


_PUNCT = "。、？?！!」』"


def split_caption(text: str, side_room: int) -> list[str]:
    """字幕が2行に収まらないとき、**何枚かに分ける**。

    テレビの字幕と同じく、話している途中で次の字幕に送る。字を小さくして詰めると読みにくく、
    捨てると台詞が消える（2026-10-10、立ち絵を 420 にして字幕の幅が 788px になったとき）。
    区切る場所は**句読点を先に**探し、無ければ言葉の切れ目（`_breaks`）。
    1枚ずつ、言葉の切れ目で2行に収まるいちばん長いところまで取る。
    """
    if _fits(text, side_room):
        return [text]
    cuts_all = sorted(set(_breaks(text)) | {i + 1 for i, c in enumerate(text) if c in _PUNCT})
    chunks, st = [], 0
    while st < len(text):
        rest = text[st:]
        if _fits(rest, side_room):
            chunks.append(rest)
            break
        cand = [c for c in cuts_all if c > st]
        ok = [c for c in cand if _fits(text[st:c], side_room)]
        if not ok:                                 # どこで切っても入らない（とても長い一続きの言葉）
            chunks.append(rest)
            break
        punct = [c for c in ok if text[c - 1] in _PUNCT]
        e = max(punct) if punct and (max(punct) - st) >= (max(ok) - st) * 0.6 else max(ok)
        # 句読点で切ると短すぎるときは、言葉の切れ目でより長く取る
        chunks.append(text[st:e])
        st = e
    return chunks


def fade_frames(before: Image.Image, after: Image.Image, work: Path,
                tag: str, n: int = FADE_FRAMES) -> list[Path]:
    """2つの画面のあいだに挟む、重なりのコマ。

    画面がパッと切り替わると、静止画を並べただけに見える。
    0.1 秒だけ重ねると落ち着く。コマは3枚なので手間はほとんど増えない。
    """
    out: list[Path] = []
    a = before.convert("RGB")
    b = after.convert("RGB")
    for i in range(n):
        p = work / "{}_f{}.jpg".format(tag, i)
        Image.blend(a, b, (i + 1) / (n + 1)).save(p, quality=88)
        out.append(p)
    return out


class Sink:
    """コマを ffmpeg に直接流し込む（**画像をディスクに置かない**）。

    口パクを入れると絵が 30分で1万枚を超え、JPEG で置くと 3GB 近くになって
    ドライブが一杯になった（2026-10-10）。同じ絵が続くあいだは同じバイト列を流すだけ。

    いちばん新しい絵は送らずに持っておく。次の行で画面が変わるとき、その絵の
    終わりのコマを、切り替えの重なりに回す（時間を足さない）ため。
    """

    def __init__(self, path: Path):
        self.path = path
        self.p = subprocess.Popen(
            [ffmpeg(), "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
             "-s", "{}x{}".format(W, H), "-r", str(FPS), "-i", "-",
             "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p", str(path)],
            stdin=subprocess.PIPE)
        self.pending: tuple[Image.Image, int] | None = None
        self.frames = 0
        self.unique = 0

    def _write(self, im: Image.Image, n: int) -> None:
        b = im.convert("RGB").tobytes()
        for _ in range(n):
            self.p.stdin.write(b)
        self.frames += n

    def add(self, im: Image.Image, n: int = 1) -> None:
        if self.pending is not None and self.pending[0] is im:
            self.pending = (im, self.pending[1] + n)
            return
        if self.pending is not None:
            self._write(*self.pending)
        self.pending = (im, n)
        self.unique += 1

    def last(self) -> Image.Image | None:
        return self.pending[0] if self.pending else None

    def borrow(self, n: int) -> int:
        """持っている絵の終わりから n コマを返してもらう（1コマは残す）。"""
        if not self.pending:
            return 0
        im, c = self.pending
        k = max(min(n, c - 1), 0)
        self.pending = (im, c - k)
        return k

    def close(self) -> None:
        if self.pending is not None:
            self._write(*self.pending)
            self.pending = None
        self.p.stdin.close()
        if self.p.wait() != 0:
            raise SystemExit("ffmpeg が失敗しました（映像）")


def gap_after(text: str, nxt: dict | None, base: float) -> float:
    """その行のあとに空ける間。**一律にしない。**

    問いのあとは受け手が考える間がいる。驚きはかぶせ気味のほうが自然。
    一律 0.28 秒だと、どの行も同じ間合いになって機械的に聞こえる（2026-10-08）。
    """
    t = text.rstrip()
    if t.endswith(("？", "?")) or t.endswith("でしょうか。") or t.endswith("ですか。"):
        return base + 0.26            # 問いのあとは長めに
    if nxt and nxt.get("who") == "聞き" and nxt.get("tone") in ("強", "特強"):
        return max(base - 0.14, 0.10)  # 驚きはかぶせ気味に
    if t.endswith("。") and len(t) <= 12:
        return base + 0.10            # 短い言い切りは、少し置く
    return base


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
    cues: list[dict] = []          # 効果音を置くための、行ごとの時刻
    gaps: list[float] = []         # 行ごとの間（一律にしない）
    at = 0.0                       # いまの時刻（秒）
    screen_changed = True          # 直前に画面が変わったか
    # 台本の話者の名前（語り／聞き）から、立ち絵の名前（katari／kikite）へ
    who_art = {k: Path(str(v.get("image", ""))).stem or k
               for k, v in cfg.get("cast", {}).items()}
    too_fast: list[tuple[int, str, float]] = []
    wavs: list[Path] = []
    out.parent.mkdir(parents=True, exist_ok=True)
    video_only = work / "video.mp4"
    sink = Sink(video_only)
    n = 0
    frame_no = 0                               # いまのコマ番号（30コマ/秒）
    prev_step = None
    # 瞬き。**2人とも、それぞれ不規則な間隔で**（同時に瞬くと機械に見える）
    blink_at = {"katari": lipsync.blinks30(3 * 3600, FPS, seed=11),
                "kikite": lipsync.blinks30(3 * 3600, FPS, seed=29)}
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
            screen_changed = True
            continue
        if current is None:
            raise SystemExit("最初の話者の行より前に screen: がありません")
        style_id, params = tts.params_for(cfg, step["who"], step["tone"])
        wav = work / "{:03d}.wav".format(n)
        # **読み上げるときだけ数字を漢数字に直す。字幕は算用数字のまま。**
        # 単位のあとに数字が続くと桁として読めない（「1リットル175円」→
        # 「イチナナゴエン」。2026-10-08 に実際に起きた）
        say = reading.reading(step["text"])
        wav.write_bytes(tts.synth(tts.engine_for(cfg, step["who"]), say, style_id, **params))
        wavs.append(wav)
        # 次の話者の行を先に見て、間を決める
        nxt = None
        for later in steps[steps.index(step) + 1:]:
            if "who" in later:
                nxt = later
                break
        this_gap = gap_after(step["text"], nxt, gap)
        gaps.append(this_gap)
        sec = wav_seconds(wav) + this_gap
        # 中間の画像は JPEG。PNG は 1枚 0.59 秒かかるが JPEG なら 0.04 秒。
        # 最後に H.264 にするので、この段階の劣化は見えない（2026-10-07 実測）
        art = who_art.get(step["who"], "")
        # 立ち絵が出ているぶん、字幕が使える幅を左右から狭める。
        # 立ち絵の矩形には透明な余白があるので、実際の人の幅に合わせて少し詰める。
        # ワイプは画面の上にいるので、字幕の幅は狭めなくてよい
        room = 0
        if cast_spec and cast_spec["style"] == "bottom":
            room = cast_width(cast_spec["height"]) + 4 - 80       # 字幕は左右 80px の余白込み。立ち絵とは 4px 空ける
        # **口パクと瞬き。** 行の中をコマに分け、絵が変わるところだけ画像を作る
        # （同じ絵が続くあいだは1枚を長く出す）。字幕は行の頭で1回だけ焼く
        q = tts.timing_query(say)
        exact = tts.engine_for(cfg, step["who"]).endswith(":50021")
        shapes, _ = lipsync.visemes(wav, q, exact=exact, fps=FPS)
        # 長い台詞は字幕を何枚かに分け、話している時間を文字数で割って送る
        chunks = split_caption(step["text"], room)
        capped_list = [caption(current, c, side_room=room, who=art if cast_spec else "") for c in chunks]
        weights = [len(c) for c in chunks]
        cut_at, acc = [], 0
        for wgt in weights[:-1]:
            acc += wgt
            cut_at.append(int(len(shapes) * acc / sum(weights)))
        f0 = frame_no
        f1 = int(round((at + sec) * FPS))      # この行の終わりのコマ（積み重ねで丸めがずれない）
        line: list[list] = []                  # [絵, コマ数]
        prev_key = None
        listener = [w for _, w in SEATS if w != art]
        sp_face = speak_face(art, step)
        li_face = {w: listen_face(w, step, nxt, prev_step) for w in listener}
        react_at = int(len(shapes) * REACT_FROM)
        for k in range(f1 - f0):
            g = f0 + k
            mouth = shapes[k] if k < len(shapes) else "closed"
            # 瞬きはふつうの顔のときだけ（表情の目を瞬きで消すと眉が跳ねる）
            faces = {art: sp_face}
            for w in listener:
                faces[w] = li_face[w] if k >= react_at else "normal"
            blinking = frozenset(w for w, bl in blink_at.items() if g in bl and faces.get(w) == "normal")
            ci = sum(1 for c in cut_at if k >= c)
            capped = capped_list[ci]
            key = (mouth, blinking, tuple(sorted(faces.items())), ci)
            if key == prev_key:
                line[-1][1] += 1
                continue
            if cast_spec:
                if cast_spec["style"] == "wipe":
                    painted = put_wipe(capped, cast_spec["height"], art, faces,
                                       cast_spec.get("pos", "右上"), mouth, blinking)
                else:
                    painted = put_cast(capped, cast_spec["height"], art, faces, mouth, blinking)
            else:
                painted = capped
            line.append([painted, 1])
            prev_key = key
        # 画面が変わるところに、短い重なりを挟む。**前の行の終わり（間）から時間を借りる**
        # （足すと、そのぶん画面だけが声より遅れていく。2026-10-10 に見つけた）
        if sink.last() is not None and screen_changed:
            prev = sink.last().convert("RGB")
            take = sink.borrow(FADE_FRAMES)
            first = line[0][0].convert("RGB")
            for i in range(take):
                sink.add(Image.blend(prev, first, (i + 1) / (take + 1)))
        for im_, c in line:
            sink.add(im_, c)
        frame_no = f1
        prev_step = step
        cues.append({"start": at, "screen_changed": screen_changed,
                     "who": step["who"], "tone": step["tone"]})
        at += sec
        screen_changed = False
        # 字幕が読める速さか。日本語の字幕は **1秒あたり 4〜6文字**が目安。
        # これを超えると、聞けても読めない（読み終わる前に次へ行く）。
        cps = len(step["text"]) / sec if sec else 0
        fast = "  ← 速い（{:.1f}字/秒）".format(cps) if cps > READ_MAX else ""
        if fast:
            too_fast.append((n + 1, step["text"], cps))
        print("  {:>3}  {:>5.2f}秒  {:>4.1f}字/秒  [{}]  {}{}".format(
            n + 1, sec, cps, current_name, step["text"][:26], fast))
        if say != step["text"]:
            print("           読み: {}".format(say[:46]))
        n += 1

    sink.close()
    if sink.frames == 0:
        raise SystemExit("話者の行が1つもありません")

    # 音声をつなぐ
    voice = work / "voice.wav"
    tts.join_wavs(wavs, voice, gap_sec=gaps)
    # 効果音を重ねる。**BGM は入れない。** 画面が変わるところと、
    # 聞き手が驚くところにだけ、声よりずっと小さく置く
    evs = sfx.events(cues)
    if evs:
        with wave.open(str(voice), "rb") as w:
            params = w.getparams()
            data = w.readframes(w.getnframes())
        a = array("h")
        a.frombytes(data)
        a = sfx.overlay(a, params.framerate, params.nchannels, evs)
        with wave.open(str(voice), "wb") as w:
            w.setparams(params)
            w.writeframes(a.tobytes())
        print("  効果音 {} か所（画面の変わり目と、聞き手の驚き）".format(len(evs)))

    # 映像（声なし）に声を重ねる。映像は作り直さずにそのまま写す
    cmd = [ffmpeg(), "-y", "-i", str(video_only), "-i", str(voice), "-c:v", "copy",
           "-c:a", "aac", "-b:a", "192k", "-shortest", str(out)]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print(r.stderr[-2500:], file=sys.stderr)
        raise SystemExit("ffmpeg が失敗しました")
    video_only.unlink()
    print("書き出しました: {}（{:.1f}秒 / 絵 {}枚）".format(out, sink.frames / FPS, sink.unique))
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
