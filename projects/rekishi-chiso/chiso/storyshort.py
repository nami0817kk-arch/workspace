"""物語完結型のショート（10-22 ユーザー決定。伸びている他チャンネルの型に作り替える）。

    python -m chiso.cli story-short scripts/story/oichi_s1.yaml [--kana] [--only-plan]

型：冒頭1文＝感情の結末予告／起こり→事件→結末まで50〜60秒で語り切る／画面は全面のAI人物絵＋中央に特大の1フレーズ／
3〜5秒ごとに別の絵／語りは1人（剣崎雌雄・抑えめ）／キャラ立ち絵・枠・年表・字幕の2行目は出さない／BGM・効果音なし。

台本（scripts/story/*.yaml）：行ごとに「語り」（｜で絵の替わり目を示す）と cuts（絵の指示と中央のフレーズ）。
絵は tools/gen_story_art.py で作る（out/story/<名前>/NN.jpg、リポジトリには入れない）。
既存の shorts.py（本編から切り出すショート）とは別物で、本編の台本・Painter は使わない。
字形・VOICEVOX・音声のつなぎ・ffmpeg は既存（render の字体設定・voice・tts・mix・cli.encode）を使う。
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

import yaml
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

W, H = 1080, 1920
FPS = 30
FADE = 0.2                 # 絵の替わり目の溶け合い（秒）
LEAD = 0.15                # 声の始まる前の間
GAP = 0.3                  # 行と行のあいだ
GAP_HEAVY = 0.35           # 重い・しみじみの行のあと
END_HOLD = 2.0             # 最後の声のあとに残す、「本編は概要欄から」の秒数
MAX_SECONDS = 60.0
CUT_MIN, CUT_MAX = 2.5, 5.5   # 1枚の長さの目安（3〜5秒。短い・長いものは知らせる）
PHRASE_MAX_CHARS = 12
PHRASE_SIZES = (170, 156, 142, 128)
PHRASE_WIDTH = W - 120
PHRASE_CENTER_Y = int(H * 0.60)    # 中央〜やや下
WHITE, YELLOW, BLACK = (255, 255, 255), (255, 214, 0), (0, 0, 0)
AI_LABEL = "AI生成画像"
CTA_TEXT = "本編は概要欄から"
NO_HEAD = "、。，．・！？!?」』）)ーっゃゅょッャュョ…"
_EMPH = re.compile(r"《(.+?)》")


# --- 台本 -----------------------------------------------------------------

@dataclass
class Cut:
    index: int          # 通し番号（1〜）。絵のファイル名 NN.jpg
    text: str           # この絵のあいだに話す文（｜で切った断片）
    prompt: str
    phrase: str         # 《》つき


@dataclass
class Line:
    index: int
    text: str           # 読み上げる文（｜なし）
    tone: str
    cuts: list


def load(path: str | Path) -> dict:
    doc = yaml.safe_load(Path(path).read_text(encoding="utf-8"))
    doc["_path"] = Path(path)
    return doc


def lines_of(doc: dict) -> list[Line]:
    out, k = [], 0
    for i, row in enumerate(doc["lines"]):
        parts = str(row["語り"]).strip().split("｜")
        cuts = row["cuts"]
        if len(parts) != len(cuts):
            raise ValueError(f"{i + 1}行目：｜で分けた数（{len(parts)}）と cuts の数（{len(cuts)}）が違います")
        made = []
        for part, c in zip(parts, cuts):
            k += 1
            made.append(Cut(k, part, str(c.get("prompt", "")), str(c["phrase"])))
        out.append(Line(i, "".join(parts), row.get("tone", "普通"), made))
    return out


def phrase_plain(phrase: str) -> tuple[str, list[bool]]:
    """《》を外した文字列と、黄色にする字の印。"""
    plain, mask, pos = "", [], 0
    for m in _EMPH.finditer(phrase):
        seg = phrase[pos:m.start()]
        plain += seg
        mask += [False] * len(seg)
        plain += m.group(1)
        mask += [True] * len(m.group(1))
        pos = m.end()
    tail = phrase[pos:]
    return plain + tail, mask + [False] * len(tail)


def problems(doc: dict) -> list[str]:
    """台本の点検。(×)＝止める。"""
    out = []
    try:
        lines = lines_of(doc)
    except ValueError as e:
        return [str(e)]
    n = sum(len(l.cuts) for l in lines)
    if not 12 <= n <= 16:
        out.append(f"絵の数が{n}枚です（12〜16枚）")
    total = sum(len(l.text) for l in lines)
    if not 270 <= total <= 330:
        out.append(f"語りが{total}字です（約270〜330字）")
    for l in lines:
        for c in l.cuts:
            plain, _ = phrase_plain(c.phrase)
            if not plain or len(plain) > PHRASE_MAX_CHARS:
                out.append(f"絵{c.index}のフレーズ「{plain}」が{len(plain)}字です（12字以内）")
            if not c.prompt.strip():
                out.append(f"絵{c.index}に prompt がありません")
    return out


# --- 時間割 -----------------------------------------------------------------

@dataclass
class Seg:
    cut: Cut
    start: float
    end: float


def plan(lines: list[Line], seconds: list[float]) -> tuple[list, list[Seg], float]:
    """各行の声の (開始, 終了) と、絵ごとの時間、全体の長さ。

    行の中の絵の替わり目は、断片の字数に比例させる。行をまたぐ替わり目は、行のあいだの真ん中。"""
    voice, t = [], LEAD
    for i, (line, sec) in enumerate(zip(lines, seconds)):
        voice.append((t, t + sec))
        t += sec + (GAP_HEAVY if line.tone in ("重い", "しみじみ") else GAP)
    last_end = voice[-1][1]
    total = last_end + END_HOLD
    marks = []          # 絵の始まりの時刻（最初の絵は 0）
    for i, line in enumerate(lines):
        a, b = voice[i]
        chars = sum(len(c.text) for c in line.cuts)
        acc = 0
        for j, c in enumerate(line.cuts):
            if j == 0:
                marks.append(0.0 if i == 0 else (voice[i - 1][1] + a) / 2)
            else:
                marks.append(a + (b - a) * acc / chars)
            acc += len(c.text)
    cuts = [c for l in lines for c in l.cuts]
    segs = [Seg(c, marks[k], marks[k + 1] if k + 1 < len(cuts) else total) for k, c in enumerate(cuts)]
    return voice, segs, round(total, 3)


# --- 絵 -------------------------------------------------------------------

def trim_bars(im: Image.Image) -> Image.Image:
    """生成した絵の上下左右の白い帯を切る（FLUX がときどき付ける）。"""
    import numpy as np
    a = np.asarray(im.convert("L"), dtype=float)
    rows, cols = a.mean(1), a.mean(0)
    def edge(v):
        return next((i for i, x in enumerate(v) if x < 235), 0)
    t, b, l, r = edge(rows), edge(rows[::-1]), edge(cols), edge(cols[::-1])
    if max(t, b, l, r) < 6:
        return im
    pad = 4
    return im.crop((l + pad if l else 0, t + pad if t else 0, im.width - (r + pad if r else 0), im.height - (b + pad if b else 0)))


def crop_vertical(im: Image.Image) -> Image.Image:
    """正方形の絵の中央を縦 9:16 に切って 1080x1920 にする。"""
    im = trim_bars(im.convert("RGB"))
    w, h = im.size
    cw = min(w, int(h * W / H))
    x0 = (w - cw) // 2
    im = im.crop((x0, 0, x0 + cw, h)).resize((W, H), Image.LANCZOS)
    return ImageEnhance.Sharpness(im).enhance(1.25)


def shade(im: Image.Image) -> Image.Image:
    """文字が読めるように、フレーズの帯だけ少し暗くする（絵は動かさない・全面のまま）。"""
    lin = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(lin)
    top, bot = int(H * 0.43), int(H * 0.78)
    for y in range(top, bot):
        k = 1 - abs((y - (top + bot) / 2) / ((bot - top) / 2))
        d.line([(0, y), (W, y)], fill=int(110 * min(1.0, k * 1.6)))
    dark = Image.new("RGB", (W, H), (8, 6, 4))
    return Image.composite(dark, im, lin)


# --- 文字 -----------------------------------------------------------------

def split_rows(plain: str, mask: list[bool], font) -> list[tuple[str, list[bool]]]:
    """フレーズを2行に。幅が釣り合い、黄色と白の境で切れ、1字だけの行を作らない所で切る。"""
    best = None
    for k in range(1, len(plain)):
        if plain[k] in NO_HEAD:
            continue
        cost = max(font.getlength(plain[:k]), font.getlength(plain[k:]))
        if mask[k - 1] and mask[k]:
            cost += 250                      # 黄色の語の途中
        if mask[k - 1] != mask[k]:
            cost -= 120                      # 色の境
        if k < 2 or len(plain) - k < 2:
            cost += 300
        if best is None or cost < best[0]:
            best = (cost, k)
    k = best[1]
    return [(plain[:k], mask[:k]), (plain[k:], mask[k:])]


def phrase_layout(phrase: str, font_of) -> tuple[int, list]:
    """1行で特大に収まればそのまま、収まらなければ2行にして収まる最大の大きさ。"""
    plain, mask = phrase_plain(phrase)
    for size in PHRASE_SIZES[:2]:                  # 1行は特大（156 以上）のときだけ。それ以下なら2行にして大きく
        if font_of(size).getlength(plain) <= PHRASE_WIDTH:
            return size, [(plain, mask)]
    for size in PHRASE_SIZES:
        f = font_of(size)
        rows = split_rows(plain, mask, f)
        if all(f.getlength(r) <= PHRASE_WIDTH for r, _ in rows):
            return size, rows
    return PHRASE_SIZES[-1], split_rows(plain, mask, font_of(PHRASE_SIZES[-1]))


def draw_phrase(img: Image.Image, phrase: str, font_of) -> None:
    """中央〜やや下に特大の太いゴシック。白＋黒の縁取り、強調語だけ黄。"""
    size, rows = phrase_layout(phrase, font_of)
    f = font_of(size)
    step = int(size * 1.18)
    top = PHRASE_CENTER_Y - step * len(rows) / 2
    sw = max(8, size // 14)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for pass_ in ("stroke", "fill"):
        for i, (row, mask) in enumerate(rows):
            x = W / 2 - f.getlength(row) / 2
            y = top + step * i
            for ch, on in zip(row, mask):
                if pass_ == "stroke":
                    d.text((x + 4, y + 6), ch, font=f, fill=(0, 0, 0, 150), stroke_width=sw, stroke_fill=(0, 0, 0, 150))
                    d.text((x, y), ch, font=f, fill=BLACK + (255,), stroke_width=sw, stroke_fill=BLACK + (255,))
                else:
                    d.text((x, y), ch, font=f, fill=(YELLOW if on else WHITE) + (255,))
                x += f.getlength(ch)
    img.paste(layer, (0, 0), layer)


def draw_label(img: Image.Image, font_of) -> None:
    f = font_of(30)
    tw = int(f.getlength(AI_LABEL))
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([28, 40, 28 + tw + 32, 40 + 52], radius=10, fill=(0, 0, 0, 130))
    d.text((44, 66), AI_LABEL, font=f, fill=(255, 255, 255, 235), anchor="lm")


def draw_cta(img: Image.Image, font_of) -> None:
    f = font_of(62)
    tw = int(f.getlength(CTA_TEXT))
    d = ImageDraw.Draw(img, "RGBA")
    y = int(H * 0.80)
    d.rounded_rectangle([W / 2 - tw / 2 - 36, y, W / 2 + tw / 2 + 36, y + 110], radius=55, fill=(0, 0, 0, 150),
                        outline=(255, 255, 255, 220), width=3)
    d.text((W / 2, y + 55), CTA_TEXT, font=f, fill=(255, 255, 255, 255), anchor="mm")


def make_font_of(fonts: dict):
    cache = {}

    def font_of(size: int):
        if size not in cache:
            f = ImageFont.truetype(fonts["gothic"], size)
            try:
                f.set_variation_by_name("Bold")
            except Exception:
                pass
            cache[size] = f
        return cache[size]
    return font_of


def render_cut(art: Path, cut: Cut, font_of, cta: bool = False) -> Image.Image:
    with Image.open(art) as im:
        img = shade(crop_vertical(im)).convert("RGBA")
    draw_phrase(img, cut.phrase, font_of)
    draw_label(img, font_of)
    if cta:
        draw_cta(img, font_of)
    return img.convert("RGB")


# --- 組み立て ---------------------------------------------------------------

def frame_items(segs: list[Seg], frames: dict, blends: dict, total: float) -> list[tuple[Path, float]]:
    """(コマ, 秒数) の並び。絵の替わり目の前後 FADE/2 が溶け合いの FADE 秒（1/FPS 刻み）。"""
    items: list[tuple[Path, float]] = []
    n = max(1, int(round(FADE * FPS)))
    for k, s in enumerate(segs):
        a = s.start + (FADE / 2 if k > 0 else 0.0)
        b = s.end - (FADE / 2 if k + 1 < len(segs) else 0.0)
        if k + 1 == len(segs):                       # 最後の絵：最後の2秒に「本編は概要欄から」
            items.append((frames[(k, False)], max(0.01, b - a - END_HOLD)))
            items.append((frames[(k, True)], END_HOLD))
        else:
            items.append((frames[(k, False)], max(0.01, b - a)))
            for j in range(n):
                items.append((blends[(k, j)], 1 / FPS))
    got = sum(d for _p, d in items)
    if abs(got - total) > 0.05:
        raise ValueError(f"コマの長さ {got:.2f} 秒が全体 {total:.2f} 秒と合いません")
    return items


def kana_report(doc: dict, config: dict, readings: dict, engine, voice) -> list[str]:
    """全行の読みをカタカナで（誤読を音を出す前に見つけるため）。voice.py の kana_of/join_n_phrases を使う。
    あわせて libs/yomi の点検（辞書との食い違い・読みが割れる語）。"""
    from .voice import apply_readings, split_emphasis
    out = []
    items = []
    for line in lines_of(doc):
        spoken = apply_readings(split_emphasis(line.text)[0], readings)
        q = engine.query(spoken, voice.style_id)
        phrases, _ = __import__("chiso.voice", fromlist=["join_n_phrases"]).join_n_phrases(q["accent_phrases"])
        kana = "／".join("".join(m["text"] for m in p["moras"]) for p in phrases)
        out.append(f"{line.index + 1:3} {kana}")
        items.append((f"{line.index + 1}行目", line.text))
    try:
        from . import reading
        out += [f"  ! 読み：{r}" for r in reading.collision_lines(readings, items)]
        src = reading.kana_source(config["voicevox_url"], voice.style_id)
        errs, warns = reading.yomi.review(items, readings, src.kana if src.available else None,
                                          reading.lexicon(), reading.strip).lines()
        src.save()
        out += [f"  {r}" for r in errs + warns]
    except Exception as e:  # noqa: BLE001 - 点検の道具が無くても kana は出す
        out.append(f"  （yomi の点検は動きませんでした: {e}）")
    return out


def build(path: str | Path, config: dict, voices: dict, readings: dict, out_dir: Path, work_root: Path,
          name: str | None = None) -> tuple[Path, float]:
    """台本から mp4 を作る。voices は cli.voices(config)、readings は readings.yaml。"""
    from . import mix, tts
    from .cli import encode            # ffmpeg の呼び出し（音の大きさ揃えまで）は既存のものをそのまま使う
    doc = load(path)
    errs = problems(doc)
    if errs:
        raise ValueError("台本の点検で止まりました：" + " / ".join(errs))
    lines = lines_of(doc)
    stem = Path(path).stem
    art_dir = Path(doc.get("art_dir", f"out/story/{stem.split('_')[0]}"))
    if not art_dir.is_absolute():
        art_dir = Path(__file__).resolve().parent.parent / art_dir
    for c in (c for l in lines for c in l.cuts):
        if not (art_dir / f"{c.index:02d}.jpg").exists():
            raise FileNotFoundError(f"絵がありません: {art_dir / f'{c.index:02d}.jpg'}（tools/gen_story_art.py で作る）")
    wd = work_root / f"{stem}_story"
    wd.mkdir(parents=True, exist_ok=True)

    # 声：語りの1人だけ
    engine = tts.Voicevox(config["voicevox_url"])
    voice = voices["語り"]
    spoken = [tts.speak(engine, l.text, voice, l.tone, readings, wd / "voice") for l in lines]
    voice_t, segs, total = plan(lines, [s.seconds for s in spoken])
    cues = [mix.Cue(l, round(a, 3), round(b, 3), s.wav) for l, s, (a, b) in zip(lines, spoken, voice_t)]
    audio = wd / "voice.wav"
    mix.write_audio(cues, total, audio)

    # 絵とフレーズ
    font_of = make_font_of(config["fonts"])
    frames, blends = {}, {}
    fdir = wd / "frames"
    fdir.mkdir(exist_ok=True)
    imgs = {}
    for k, s in enumerate(segs):
        art = art_dir / f"{s.cut.index:02d}.jpg"
        for cta in ((False, True) if k + 1 == len(segs) else (False,)):
            p = fdir / f"cut{s.cut.index:02d}{'_cta' if cta else ''}.png"
            img = render_cut(art, s.cut, font_of, cta)
            img.save(p, compress_level=1)
            frames[(k, cta)] = p
            if not cta:
                imgs[k] = img
    n = max(1, int(round(FADE * FPS)))
    for k in range(len(segs) - 1):
        for j in range(n):
            p = fdir / f"blend{k:02d}_{j}.png"
            Image.blend(imgs[k], imgs[k + 1], (j + 1) / (n + 1)).save(p, compress_level=1)
            blends[(k, j)] = p
    items = frame_items(segs, frames, blends, total)
    stem_out = name or doc.get("out") or "{}_story_{}".format(*(stem.partition("_")[0], stem.partition("_")[2] or "s1"))
    target = out_dir / f"{stem_out}.mp4"
    encode(items, audio, target, FPS)

    # 報告：絵ごとの長さ
    for s in segs:
        d = s.end - s.start
        mark = "" if CUT_MIN <= d <= CUT_MAX else "  ! 3〜5秒から外れています"
        print(f"  絵{s.cut.index:2d} {s.start:5.1f}〜{s.end:5.1f}（{d:.1f}秒）{phrase_plain(s.cut.phrase)[0]}{mark}")
    return target, total


def contact_sheet(ffmpeg: str, video: Path, target: Path, every: float = 3.0, cols: int = 4, font=None) -> Path:
    """3秒ごとに1コマ、4列の一覧（時刻つき）。"""
    import subprocess
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(video), "-vf",
                        f"fps=1/{every},scale=270:-1", f"{td}/f%03d.png"], check=True)
        files = sorted(Path(td).glob("f*.png"))
        ims = [Image.open(f).convert("RGB") for f in files]
        w, h = ims[0].size
        rows = (len(ims) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * (w + 8) + 8, rows * (h + 8) + 8), (24, 24, 24))
        d = ImageDraw.Draw(sheet)
        f = ImageFont.truetype(font, 22) if font else ImageFont.load_default()
        for i, im in enumerate(ims):
            x, y = 8 + (i % cols) * (w + 8), 8 + (i // cols) * (h + 8)
            sheet.paste(im, (x, y))
            d.rectangle([x, y, x + 74, y + 30], fill=(0, 0, 0))
            d.text((x + 6, y + 3), f"{i * every:.0f}秒", font=f, fill=(255, 255, 255))
        target.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(target, quality=88)
    return target
