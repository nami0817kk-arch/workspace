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

TURF = (34, 110, 52)
TURF_DARK = (26, 88, 42)
LINE = (236, 244, 238)

VARIANTS = ("stadium", "pitch", "tactics")


def generate(path: Path, size: tuple[int, int], variant: str = "stadium") -> Path:
    if variant not in VARIANTS:
        raise ValueError(f"背景の種類は {VARIANTS} のいずれか: {variant}")
    width, height = size
    canvas = Image.new("RGB", size, (8, 12, 20))

    if variant == "tactics":
        _tactics_board(canvas)
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

    margin_x, margin_y = int(width * 0.08), int(height * 0.10)
    box = [margin_x, margin_y, width - margin_x, height - margin_y]
    draw.rectangle(box, outline=(120, 190, 150), width=3)
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
