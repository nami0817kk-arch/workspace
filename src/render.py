"""1フレームぶんの画面を描き、静止画の並びとして動画を組み立てる。

各セリフは「口を閉じた絵」と「開けた絵」の2枚だけを作り、concat demuxer で
交互に並べることで口パクにする。フレームは内容ハッシュでキャッシュするので、
同じ画面が続いても PNG は増えない。
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from . import ffmpeg
from .config import CastMember, ProjectConfig, _resolve
from .script_model import Line, Scene, Script

MOUTH_INTERVAL = 0.14  # 口パクの切り替え間隔（秒）
TELOP_MARGIN = 110
TELOP_HEIGHT = 250
TELOP_BOTTOM = 58


@dataclass
class Layout:
    width: int
    height: int

    @property
    def telop_box(self) -> tuple[int, int, int, int]:
        top = self.height - TELOP_BOTTOM - TELOP_HEIGHT
        return (TELOP_MARGIN, top, self.width - TELOP_MARGIN, top + TELOP_HEIGHT)

    def character_anchor(self, position: str) -> tuple[int, int]:
        """立ち絵の中心 x と足元 y。"""
        x = int(self.width * (0.24 if position == "left" else 0.76))
        return x, self.telop_box[1] - 20


class Renderer:
    def __init__(self, config: ProjectConfig, work_dir: Path):
        self.config = config
        self.layout = Layout(config.video.width, config.video.height)
        self.frame_dir = work_dir / "frames"
        self.frame_dir.mkdir(parents=True, exist_ok=True)

        font_path = str(config.video.font_path())
        self.font_telop = ImageFont.truetype(font_path, config.video.telop_size)
        self.font_name = ImageFont.truetype(font_path, config.video.name_size)
        self.font_scene = ImageFont.truetype(font_path, 36)

        self._backgrounds: dict[str, Image.Image] = {}
        self._sprites: dict[tuple[str, str, bool], Image.Image | None] = {}

    # ------------------------------------------------------------------ 画面

    def frame(self, line: Line, scene: Scene, mouth_open: bool) -> Path:
        member = self.config.resolve_speaker(line.speaker)
        background = scene.background or self.config.video.background
        key = "|".join(
            [
                background,
                scene.title,
                member.key,
                line.emotion,
                line.telop_text(),
                line.image or "",
                "open" if mouth_open else "close",
                f"{self.layout.width}x{self.layout.height}",
            ]
        )
        target = self.frame_dir / f"{hashlib.sha1(key.encode('utf-8')).hexdigest()[:16]}.png"
        if target.exists():
            return target

        canvas = self._background(background).copy()
        self._draw_characters(canvas, member, line.emotion, mouth_open)
        if line.image:
            self._draw_inset(canvas, line.image)
        self._draw_scene_title(canvas, scene.title)
        self._draw_telop(canvas, member, line.telop_text())
        canvas.convert("RGB").save(target)
        return target

    def _background(self, name: str) -> Image.Image:
        if name not in self._backgrounds:
            path = _resolve(name)
            if path.exists():
                image = Image.open(path).convert("RGBA")
                self._backgrounds[name] = _cover(image, self.layout.width, self.layout.height)
            else:
                self._backgrounds[name] = Image.new(
                    "RGBA", (self.layout.width, self.layout.height), (20, 26, 40, 255)
                )
        return self._backgrounds[name]

    def _sprite(self, member: CastMember, emotion: str, mouth_open: bool) -> Image.Image | None:
        cache_key = (member.key, emotion, mouth_open)
        if cache_key in self._sprites:
            return self._sprites[cache_key]
        directory = member.sprite_dir()
        suffix = "open" if mouth_open else "close"
        for name in (f"{emotion}_{suffix}.png", f"normal_{suffix}.png", f"{emotion}.png"):
            path = directory / name
            if path.exists():
                self._sprites[cache_key] = Image.open(path).convert("RGBA")
                return self._sprites[cache_key]
        self._sprites[cache_key] = None
        return None

    def _draw_characters(
        self, canvas: Image.Image, speaking: CastMember, emotion: str, mouth_open: bool
    ) -> None:
        """左右の立ち絵を配置する。話していない側は少し縮めて暗くする。"""
        for member in self.config.cast.values():
            if member.position not in ("left", "right"):
                continue
            is_active = member.key == speaking.key
            sprite = self._sprite(
                member,
                emotion if is_active else "normal",
                mouth_open and is_active,
            )
            if sprite is None:
                continue

            target_height = int(self.layout.height * (0.62 if is_active else 0.55))
            scale = target_height / sprite.height
            sprite = sprite.resize(
                (int(sprite.width * scale), target_height), Image.LANCZOS
            )
            if not is_active:
                sprite = _dim(sprite, 0.55)

            cx, base_y = self.layout.character_anchor(member.position)
            canvas.alpha_composite(sprite, (cx - sprite.width // 2, base_y - sprite.height))

    def _draw_inset(self, canvas: Image.Image, image_path: str) -> None:
        path = _resolve(image_path)
        if not path.exists():
            return
        inset = Image.open(path).convert("RGBA")
        max_w, max_h = int(self.layout.width * 0.42), int(self.layout.height * 0.42)
        scale = min(max_w / inset.width, max_h / inset.height)
        inset = inset.resize((int(inset.width * scale), int(inset.height * scale)), Image.LANCZOS)

        cx, cy = self.layout.width // 2, int(self.layout.height * 0.38)
        box = (cx - inset.width // 2, cy - inset.height // 2)
        frame = Image.new("RGBA", (inset.width + 16, inset.height + 16), (255, 255, 255, 235))
        canvas.alpha_composite(frame, (box[0] - 8, box[1] - 8))
        canvas.alpha_composite(inset, box)

    def _draw_scene_title(self, canvas: Image.Image, title: str) -> None:
        # RGBA の canvas に直接半透明の図形を描くと下地を「置き換えて」しまうため、
        # 透明レイヤーに描いてから alpha_composite する。
        layer, draw = _layer(canvas.size)
        text_w = draw.textlength(title, font=self.font_scene)
        draw.rounded_rectangle(
            [48, 42, 48 + text_w + 56, 42 + 68], radius=34, fill=(0, 0, 0, 150)
        )
        draw.text((76, 58), title, font=self.font_scene, fill=(240, 240, 240, 255))
        canvas.alpha_composite(layer)

    def _draw_telop(self, canvas: Image.Image, member: CastMember, text: str) -> None:
        if not text:
            return
        layer, draw = _layer(canvas.size)
        left, top, right, bottom = self.layout.telop_box
        draw.rounded_rectangle([left, top, right, bottom], radius=28, fill=(12, 14, 22, 205))
        draw.rounded_rectangle([left, top, right, bottom], radius=28, outline=(255, 255, 255, 60), width=3)

        # 話者名タグ
        name_w = draw.textlength(member.name, font=self.font_name)
        tag = [left + 26, top - 34, left + 26 + name_w + 48, top + 30]
        draw.rounded_rectangle(tag, radius=22, fill=_hex(member.color) + (255,))
        draw.text((tag[0] + 24, tag[1] + 8), member.name, font=self.font_name, fill=(20, 20, 24, 255))

        lines = wrap_text(draw, text, self.font_telop, right - left - 88)
        line_height = self.config.video.telop_size + 16
        y = top + (bottom - top - line_height * len(lines)) // 2 + 12
        for chunk in lines:
            draw.text(
                (left + 44, y),
                chunk,
                font=self.font_telop,
                fill=(255, 255, 255, 255),
                stroke_width=4,
                stroke_fill=(0, 0, 0, 220),
            )
            y += line_height
        canvas.alpha_composite(layer)

    # ------------------------------------------------------------ タイムライン

    def frame_entries(self, script: Script) -> list[tuple[Path, float]]:
        """(画像, 表示秒数) の並びを作る。口パクはここで展開する。"""
        entries: list[tuple[Path, float]] = []
        for scene in script.scenes:
            for line in scene.lines:
                closed = self.frame(line, scene, mouth_open=False)
                opened = self.frame(line, scene, mouth_open=True)
                pause = line.pause or 0.0
                speaking = max(0.0, line.duration - pause)

                remaining = speaking
                mouth_open = False
                while remaining > 0.01:
                    step = min(MOUTH_INTERVAL, remaining)
                    entries.append((opened if mouth_open else closed, step))
                    mouth_open = not mouth_open
                    remaining -= step
                if pause > 0.01:
                    entries.append((closed, pause))
        return entries

    def build_video(
        self, script: Script, audio_path: Path | None, out_path: Path, work_dir: Path
    ) -> Path:
        entries = self.frame_entries(script)
        list_path = ffmpeg.write_concat_list(entries, work_dir / "frames.txt")
        out_path.parent.mkdir(parents=True, exist_ok=True)
        return ffmpeg.encode_video(list_path, audio_path, out_path, self.config.video.fps)


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_width: float) -> list[str]:
    """日本語向けに1文字ずつ幅を見て折り返す。禁則は行頭約物のみ簡易対応。"""
    forbidden = "、。！？」』）,.!?"
    lines: list[str] = []
    current = ""
    for char in text:
        if char == "\n":
            lines.append(current)
            current = ""
            continue
        if draw.textlength(current + char, font=font) > max_width and current:
            if char in forbidden:
                current += char
                lines.append(current)
                current = ""
                continue
            lines.append(current)
            current = char
        else:
            current += char
    if current:
        lines.append(current)
    return lines


def _layer(size: tuple[int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    """合成用の透明レイヤーと描画ハンドルを返す。"""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    return layer, ImageDraw.Draw(layer)


def _cover(image: Image.Image, width: int, height: int) -> Image.Image:
    """アスペクト比を保ったまま画面いっぱいに敷き詰める。"""
    scale = max(width / image.width, height / image.height)
    resized = image.resize((int(image.width * scale), int(image.height * scale)), Image.LANCZOS)
    left = (resized.width - width) // 2
    top = (resized.height - height) // 2
    return resized.crop((left, top, left + width, top + height))


def _dim(sprite: Image.Image, factor: float) -> Image.Image:
    overlay = Image.new("RGBA", sprite.size, (0, 0, 0, int(255 * (1 - factor))))
    result = sprite.copy()
    result.alpha_composite(overlay)
    result.putalpha(sprite.getchannel("A"))
    return result


def _hex(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    if len(value) != 6:
        return (200, 200, 200)
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))
