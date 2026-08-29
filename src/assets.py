"""立ち絵・背景のプレースホルダ生成。

配布素材の立ち絵は権利表記が要るものが多いため、まずは自前で描いた仮素材で
パイプラインを回せるようにしておく。差し替えは assets/characters/<key>/ に
`<表情>_<close|open>.png` を置くだけでよい（docs/pipeline.md 参照）。
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

from .audio_gen import ensure_audio_assets
from .config import ProjectConfig, _resolve

EMOTIONS = ("normal", "smile", "angry", "surprise")
SPRITE_SIZE = (700, 760)
SKIN = (248, 231, 211, 255)
OUTLINE = (60, 48, 42, 255)


def ensure_assets(config: ProjectConfig, force: bool = False) -> list[Path]:
    """不足している背景・立ち絵を生成する。生成したファイルの一覧を返す。"""
    created: list[Path] = []

    background = config.video.background_path()
    if force or not background.exists():
        background.parent.mkdir(parents=True, exist_ok=True)
        generate_background(background, (config.video.width, config.video.height))
        created.append(background)

    created += ensure_audio_assets(force=force)

    for member in config.cast.values():
        if member.position == "none":
            continue
        directory = member.sprite_dir()
        directory.mkdir(parents=True, exist_ok=True)
        for emotion in EMOTIONS:
            for mouth in ("close", "open"):
                target = directory / f"{emotion}_{mouth}.png"
                if force or not target.exists():
                    generate_character(target, member.color, emotion, mouth == "open")
                    created.append(target)
    return created


def generate_background(path: Path, size: tuple[int, int]) -> Path:
    """上下グラデーション + 薄いドットのシンプルな背景。"""
    width, height = size
    image = Image.new("RGB", size, (18, 24, 38))
    draw = ImageDraw.Draw(image)
    top, bottom = (26, 34, 56), (12, 16, 26)
    for y in range(height):
        ratio = y / max(1, height - 1)
        draw.line(
            [(0, y), (width, y)],
            fill=tuple(int(top[i] + (bottom[i] - top[i]) * ratio) for i in range(3)),
        )
    for x in range(0, width, 64):
        for y in range(0, height, 64):
            draw.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(255, 255, 255, 12))
    image.save(path)
    return path


def generate_character(path: Path, color: str, emotion: str, mouth_open: bool) -> Path:
    """ゆっくり風の丸顔立ち絵（仮）。表情と口の開閉ぶんを描き分ける。"""
    image = Image.new("RGBA", SPRITE_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    accent = _hex_to_rgb(color)
    cx, cy, r = 350, 430, 290

    # 顔
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=SKIN, outline=OUTLINE, width=8)
    # 髪（上半分をアクセント色で覆う）
    draw.pieslice([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=accent + (255,), outline=OUTLINE, width=8)
    draw.ellipse([cx - r, cy - r + 120, cx + r, cy + r - 120], fill=SKIN)
    draw.pieslice([cx - r, cy - r, cx + r, cy + r], 195, 345, fill=accent + (255,))
    # リボン
    draw.polygon([(cx - 250, cy - 250), (cx - 130, cy - 300), (cx - 140, cy - 200)], fill=accent + (255,), outline=OUTLINE)
    draw.polygon([(cx + 250, cy - 250), (cx + 130, cy - 300), (cx + 140, cy - 200)], fill=accent + (255,), outline=OUTLINE)

    eye_y = cy + 20
    for sign in (-1, 1):
        ex = cx + sign * 110
        if emotion == "smile":
            draw.arc([ex - 55, eye_y - 45, ex + 55, eye_y + 45], 200, 340, fill=OUTLINE, width=12)
        elif emotion == "surprise":
            draw.ellipse([ex - 48, eye_y - 58, ex + 48, eye_y + 58], fill=(255, 255, 255, 255), outline=OUTLINE, width=6)
            draw.ellipse([ex - 22, eye_y - 26, ex + 22, eye_y + 26], fill=OUTLINE)
        else:
            draw.ellipse([ex - 40, eye_y - 50, ex + 40, eye_y + 50], fill=(255, 255, 255, 255), outline=OUTLINE, width=6)
            draw.ellipse([ex - 20, eye_y - 24, ex + 20, eye_y + 24], fill=OUTLINE)
            draw.ellipse([ex - 12, eye_y - 34, ex - 2, eye_y - 24], fill=(255, 255, 255, 255))
        if emotion == "angry":
            draw.line([(ex - sign * 55, eye_y - 90), (ex + sign * 45, eye_y - 60)], fill=OUTLINE, width=12)

    if mouth_open:
        draw.ellipse([cx - 55, cy + 130, cx + 55, cy + 215], fill=(120, 52, 60, 255), outline=OUTLINE, width=6)
    else:
        draw.arc([cx - 55, cy + 120, cx + 55, cy + 200], 20, 160, fill=OUTLINE, width=10)

    if emotion == "smile":
        # 半透明の頬紅は別レイヤーで合成する（直接描くと下地を置き換えてしまう）
        blush = Image.new("RGBA", SPRITE_SIZE, (0, 0, 0, 0))
        blush_draw = ImageDraw.Draw(blush)
        for sign in (-1, 1):
            blush_draw.ellipse(
                [cx + sign * 200 - 45, cy + 60, cx + sign * 200 + 45, cy + 120],
                fill=(240, 150, 150, 130),
            )
        image.alpha_composite(blush)

    image.save(path)
    return path


def _hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    if len(value) != 6:
        return (200, 200, 200)
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))
