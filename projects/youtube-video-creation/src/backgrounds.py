"""サッカー向けの背景を自前で生成する。

素材サイトからのダウンロードができない環境でも「サッカーの画面」に見えるように、
ピッチ・ナイトスタジアム・戦術ボードを描き起こす。自前で描いているので権利上の
制約がなく、そのまま使える。フリー素材を用意した場合は、そちらを @bg で指定すればよい。
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

from .config import _resolve

TURF = (34, 110, 52)
TURF_DARK = (26, 88, 42)
LINE = (236, 244, 238)


def moving_background(still: str) -> str:
    """静止画の下地に対応する実写クリップがあれば、そちらを返す。

    伸びている参考チャンネルは背景が常に動いている（2026-09-07 に実測）。
    `stock` が実写クリップを取る仕組みも、動画背景を敷く仕組みも既にあったのに、
    `draft` が .png を決め打ちしていたので一度も使われていなかった。

    **規則は「同じ名前で始まる動画を使う」。** `stadium.png` に対して
    `stock/stadium.mp4` があればそれを敷く。無ければ静止画のまま
    （`background_zoom` でゆっくり寄る）。

    **書き出しのたびに見る。**draft のときだけ見ると、既に書いた台本は
    静止画のままになる（実際そうなっていた）。
    """
    path = Path(still)
    stem = path.stem
    for folder in (path.parent / "stock", path.parent):
        directory = _resolve(str(folder))
        if not directory.is_dir():
            continue
        found = sorted(clip for clip in directory.glob(f"{stem}*.mp4") if clip.is_file())
        if found:
            return str(folder / found[0].name).replace("\\", "/")
    return still

# 背景の種類。**緑のピッチ以外も要る。**
# stadium / pitch / tactics は3枚とも緑が主役で、並べると同じ画に見える
# （実測: 17カット中13カットが緑系で、殺風景の主因だった）
VARIANTS = ("stadium", "pitch", "tactics", "night", "studio")


def generate(path: Path, size: tuple[int, int], variant: str = "stadium") -> Path:
    if variant not in VARIANTS:
        raise ValueError(f"背景の種類は {VARIANTS} のいずれか: {variant}")
    width, height = size
    canvas = Image.new("RGB", size, (8, 12, 20))

    if variant == "tactics":
        _tactics_board(canvas)
    elif variant == "night":
        _night_sky(canvas)
    elif variant == "studio":
        _studio(canvas)
    else:
        horizon = int(height * (0.46 if variant == "stadium" else 0.30))
        if variant == "stadium":
            _stands(canvas, horizon)
            _floodlights(canvas, horizon)
        _pitch(canvas, horizon)

    _bottom_scrim(canvas)
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)
    return path


def _night_sky(canvas: Image.Image) -> None:
    """夜の空とスタンドの灯り。ピッチを描かない。

    移籍やクラブの話は、試合そのものの話ではない。緑の芝が映っていると
    「試合の映像」に見えてしまう。芝を出さない背景がいる。
    """
    width, height = canvas.size
    draw = ImageDraw.Draw(canvas)

    # 上から下へ、濃紺から少し明るい紺へ
    for y in range(height):
        ratio = y / height
        draw.line(
            [(0, y), (width, y)],
            fill=(
                int(10 + 18 * ratio),
                int(14 + 24 * ratio),
                int(28 + 44 * ratio),
            ),
        )

    # 遠くの灯り。規則的に並べると建物に見えるので、間隔をずらす。
    # **数と明暗の幅を増やしてある。**模様が少ない背景は、寄っていても
    # 動いて見えない（2026-09-05 実測。ばらつき7.3 で、他の背景の3分の1だった）。
    rng = random.Random(20260903)
    for _ in range(900):
        x = rng.randrange(width)
        y = rng.randrange(int(height * 0.18), int(height * 0.74))
        size = rng.choice((2, 2, 3, 3, 4, 5, 6))
        warm = rng.random() < 0.4
        shade = rng.uniform(0.55, 1.0)     # 明暗に幅を持たせる
        base = (255, 226, 168) if warm else (198, 220, 255)
        color = tuple(int(c * shade) for c in base)
        draw.ellipse([x, y, x + size, y + size], fill=color)

    # ぼけた光の玉。stadium が寄って見えるのはこれがあるから（ばらつき22.4）。
    # night には無かったので、寄っても動いて見えなかった
    from PIL import ImageDraw as _D, ImageFilter as _F

    bokeh = Image.new("RGB", (width, height), (0, 0, 0))
    bd = _D.Draw(bokeh)
    for _ in range(120):
        x = rng.randrange(width)
        y = rng.randrange(int(height * 0.20), int(height * 0.70))
        r = rng.randrange(10, 34)
        warm = rng.random() < 0.45
        tone = rng.uniform(0.30, 0.85)
        base = (255, 214, 150) if warm else (170, 205, 255)
        bd.ellipse([x - r, y - r, x + r, y + r], fill=tuple(int(c * tone) for c in base))
    from PIL import ImageChops as _C

    bokeh = bokeh.filter(_F.GaussianBlur(14))
    canvas.paste(_C.add(canvas.convert("RGB"), bokeh), (0, 0))

    # スタンドの段。横に伸びる線があると、寄っているのが目で分かる
    for step in range(7):
        y = int(height * (0.40 + step * 0.045))
        tone = 34 + step * 5
        draw.line([(0, y), (width, y)], fill=(tone, tone + 8, tone + 22), width=2)

    # 地平のあたりに、灯りの帯を1本
    band = int(height * 0.72)
    glow = Image.new("RGB", (width, 90), (26, 34, 54))
    canvas.paste(glow, (0, band))


def _studio(canvas: Image.Image) -> None:
    """表やグラフを載せるための下地。

    緑の芝の上に表を置くと、線が芝の縞と干渉して読みにくい。模様の少ない
    下地がいる。ただし暗くしすぎると、ただの黒画面になって手抜きに見える。
    中央をわずかに持ち上げて、カードが載る位置に光を集める。
    """
    width, height = canvas.size
    draw = ImageDraw.Draw(canvas)

    # 濃い藍から、下にいくほど暗く
    for y in range(height):
        ratio = y / height
        draw.line(
            [(0, y), (width, y)],
            fill=(
                int(22 - 10 * ratio),
                int(30 - 13 * ratio),
                int(50 - 20 * ratio),
            ),
        )

    # 中央の光。カードが載るあたりを明るくして、視線を集める
    glow = Image.new("L", (width, height), 0)
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse(
        [int(width * 0.10), int(height * -0.30),
         int(width * 0.90), int(height * 0.95)],
        fill=70,
    )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=width // 8))
    canvas.paste(Image.new("RGB", (width, height), (52, 70, 104)), (0, 0), glow)

    # グリッド。情報番組の下地に寄せる。**線がはっきりしていないと、
    # 寄っているのが目で分からない**（2026-09-05 実測でばらつき11.7と最低だった）
    step = max(56, width // 24)
    grid = Image.new("RGB", (width, height), (0, 0, 0))
    grid_draw = ImageDraw.Draw(grid)
    for index, x in enumerate(range(0, width, step)):
        heavy = index % 4 == 0          # 4本に1本を太く
        grid_draw.line([(x, 0), (x, height)],
                       fill=(64, 84, 122) if heavy else (44, 58, 86),
                       width=3 if heavy else 1)
    for index, y in enumerate(range(0, height, step)):
        heavy = index % 4 == 0
        grid_draw.line([(0, y), (width, y)],
                       fill=(64, 84, 122) if heavy else (44, 58, 86),
                       width=3 if heavy else 1)
    canvas.paste(ImageChops.add(canvas, grid), (0, 0))


# ------------------------------------------------------------------ パーツ


def _stands(canvas: Image.Image, horizon: int) -> None:
    """観客席。奥ほど暗くして、ボケた光の粒で人の気配を出す。"""
    width, _ = canvas.size
    draw = ImageDraw.Draw(canvas)
    for y in range(horizon):
        ratio = y / max(1, horizon)
        shade = int(14 + 26 * ratio)
        draw.line([(0, y), (width, y)], fill=(shade, shade + 4, shade + 12))

    bokeh = Image.new("RGB", canvas.size, (0, 0, 0))
    spots = ImageDraw.Draw(bokeh)
    random.seed(20260829)
    for _ in range(1400):
        x = random.randint(0, width)
        y = random.randint(int(horizon * 0.18), horizon)
        depth = y / max(1, horizon)          # 手前ほど大きく明るい
        r = max(1, int(1 + depth * 5))
        level = int(40 + depth * 150 * random.uniform(0.4, 1.0))
        tint = random.choice([(level, level, level), (level, int(level * 0.85), int(level * 0.6))])
        spots.ellipse([x - r, y - r, x + r, y + r], fill=tint)
    canvas.paste(_screen(canvas, bokeh.filter(ImageFilter.GaussianBlur(2.2))), (0, 0))


def _floodlights(canvas: Image.Image, horizon: int) -> None:
    """左右上方から差し込む照明の光芒。"""
    width, height = canvas.size
    glow = Image.new("RGB", canvas.size, (0, 0, 0))
    draw = ImageDraw.Draw(glow)
    for cx in (int(width * 0.18), int(width * 0.82)):
        for step in range(26):
            spread = 60 + step * 26
            level = int(46 * (1 - step / 26) ** 2)
            draw.ellipse(
                [cx - spread, int(horizon * 0.1) - spread // 2,
                 cx + spread, int(horizon * 0.1) + spread // 2],
                fill=(level, level, int(level * 1.08)),
            )
    canvas.paste(_screen(canvas, glow.filter(ImageFilter.GaussianBlur(38))), (0, 0))


def _pitch(canvas: Image.Image, horizon: int) -> None:
    """遠近をつけた芝。手前ほど広がるように台形で描く。"""
    width, height = canvas.size
    layer = Image.new("RGB", canvas.size, (0, 0, 0))
    draw = ImageDraw.Draw(layer)

    # 芝の外側（ピッチ脇のスペース）。ここを塗らないと台形の外が黒く抜ける
    for y in range(horizon, height):
        ratio = (y - horizon) / max(1, height - horizon)
        level = int(10 + 16 * ratio)
        draw.line([(0, y), (width, y)], fill=(level, level + 4, level + 2))

    top_left, top_right = width * 0.30, width * 0.70
    bottom_left, bottom_right = -width * 0.45, width * 1.45

    # 芝刈りの縞
    stripes = 14
    for i in range(stripes):
        t0, t1 = i / stripes, (i + 1) / stripes
        color = TURF if i % 2 == 0 else TURF_DARK
        draw.polygon(
            [
                (top_left + (top_right - top_left) * t0, horizon),
                (top_left + (top_right - top_left) * t1, horizon),
                (bottom_left + (bottom_right - bottom_left) * t1, height),
                (bottom_left + (bottom_right - bottom_left) * t0, height),
            ],
            fill=color,
        )

    # 奥を暗く落として距離を出す
    shade = Image.new("L", canvas.size, 0)
    shade_draw = ImageDraw.Draw(shade)
    for y in range(horizon, height):
        ratio = (y - horizon) / max(1, height - horizon)
        shade_draw.line([(0, y), (width, y)], fill=int(150 * (1 - ratio) ** 1.6))
    layer.paste(Image.new("RGB", canvas.size, (4, 16, 10)), (0, 0), shade)

    _pitch_lines(layer, horizon)
    canvas.paste(layer.crop((0, horizon, width, height)), (0, horizon))


def _pitch_lines(layer: Image.Image, horizon: int) -> None:
    width, height = layer.size
    draw = ImageDraw.Draw(layer)

    def across(y: int) -> tuple[float, float]:
        """その高さでのピッチ左右端。"""
        ratio = (y - horizon) / max(1, height - horizon)
        left = width * 0.30 + (-width * 0.45 - width * 0.30) * ratio
        right = width * 0.70 + (width * 1.45 - width * 0.70) * ratio
        return left, right

    # タッチライン（奥）
    left, right = across(horizon + 6)
    draw.line([(left, horizon + 6), (right, horizon + 6)], fill=LINE, width=3)

    # センターライン
    mid_y = int(horizon + (height - horizon) * 0.30)
    left, right = across(mid_y)
    draw.line([(left, mid_y), (right, mid_y)], fill=LINE, width=4)

    # センターサークル（遠近で潰れた楕円）
    rx = (right - left) * 0.17
    ry = rx * 0.30
    draw.ellipse(
        [width / 2 - rx, mid_y - ry, width / 2 + rx, mid_y + ry], outline=LINE, width=4
    )
    draw.ellipse([width / 2 - 5, mid_y - 3, width / 2 + 5, mid_y + 3], fill=LINE)

    # ペナルティエリア（手前）
    box_top = int(horizon + (height - horizon) * 0.72)
    tl, tr = across(box_top)
    bl, br = across(height - 4)
    inset_top = (tr - tl) * 0.26
    inset_bottom = (br - bl) * 0.26
    draw.line([(tl + inset_top, box_top), (tr - inset_top, box_top)], fill=LINE, width=4)
    draw.line([(tl + inset_top, box_top), (bl + inset_bottom, height - 4)], fill=LINE, width=4)
    draw.line([(tr - inset_top, box_top), (br - inset_bottom, height - 4)], fill=LINE, width=4)


def _tactics_board(canvas: Image.Image) -> None:
    """戦術ボード風。図解を載せるシーン向けの落ち着いた背景。"""
    width, height = canvas.size
    draw = ImageDraw.Draw(canvas)
    for y in range(height):
        ratio = y / height
        draw.line([(0, y), (width, y)], fill=(int(12 + 10 * ratio), int(34 + 14 * ratio), int(26 + 12 * ratio)))

    # 細かい格子。線があると寄っているのが目で分かる（実測でばらつき13.5と低かった）
    for x in range(0, width, 96):
        draw.line([(x, 0), (x, height)], fill=(30, 62, 48), width=2)
    for y in range(0, height, 96):
        draw.line([(0, y), (width, y)], fill=(30, 62, 48), width=2)

    margin_x, margin_y = int(width * 0.08), int(height * 0.10)
    box = [margin_x, margin_y, width - margin_x, height - margin_y]
    draw.rectangle(box, outline=(150, 225, 180), width=4)
    draw.line([(width // 2, margin_y), (width // 2, height - margin_y)], fill=(120, 190, 150), width=3)
    r = int(height * 0.16)
    draw.ellipse(
        [width // 2 - r, height // 2 - r, width // 2 + r, height // 2 + r],
        outline=(120, 190, 150), width=3,
    )
    for side in (0, 1):
        bw, bh = int(width * 0.10), int(height * 0.34)
        x = margin_x if side == 0 else width - margin_x - bw
        draw.rectangle([x, height // 2 - bh // 2, x + bw, height // 2 + bh // 2],
                       outline=(120, 190, 150), width=3)


def _bottom_scrim(canvas: Image.Image) -> None:
    """テロップを載せる下側を暗く落として、文字を読みやすくする。"""
    width, height = canvas.size
    scrim = Image.new("L", canvas.size, 0)
    draw = ImageDraw.Draw(scrim)
    start = int(height * 0.48)
    for y in range(start, height):
        ratio = (y - start) / max(1, height - start)
        draw.line([(0, y), (width, y)], fill=int(215 * ratio**1.3))
    canvas.paste(Image.new("RGB", canvas.size, (4, 8, 14)), (0, 0), scrim)


def _screen(base: Image.Image, light: Image.Image) -> Image.Image:
    """スクリーン合成。光を足すときに使う。"""
    return ImageChops.screen(base, light)
