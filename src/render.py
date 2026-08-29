"""1フレームぶんの画面を描き、静止画の並びとして動画を組み立てる。

各セリフは「口を閉じた絵」と「開けた絵」の2枚だけを作り、concat demuxer で
交互に並べることで口パクにする。フレームは内容ハッシュでキャッシュするので、
同じ画面が続いても PNG は増えない。
"""

from __future__ import annotations

import hashlib
import math
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from . import ffmpeg
from .config import CastMember, ProjectConfig, _resolve
from .script_model import Line, Scene, Script

MOUTH_INTERVAL = 0.14  # 口パクの切り替え間隔（秒）
TELOP_RISE = 46        # テロップが せり上がる 距離(px)
SPEAKER_HOP = 24       # 話し始めに立ち絵が跳ねる高さ(px)
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

    def frame(
        self,
        line: Line,
        scene: Scene,
        mouth_open: bool,
        telop_t: float = 1.0,
        hop_t: float = 1.0,
    ) -> Path:
        """1枚の画面を描いて PNG のパスを返す。

        telop_t / hop_t は 0→1 のアニメーション進捗。同じ絵は使い回すので、
        アニメーションを入れてもフレーム数は必要なぶんしか増えない。
        """
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
                f"{telop_t:.2f}/{hop_t:.2f}",
                f"{self.layout.width}x{self.layout.height}",
            ]
        )
        target = self.frame_dir / f"{hashlib.sha1(key.encode('utf-8')).hexdigest()[:16]}.png"
        if target.exists():
            return target

        canvas = self._background(background).copy()
        self._draw_characters(canvas, member, line.emotion, mouth_open, hop_t)
        if line.image:
            self._draw_inset(canvas, line.image)
        self._draw_scene_title(canvas, scene.title)
        self._draw_telop(canvas, member, line.telop_text(), telop_t)
        canvas.convert("RGB").save(target)
        return target

    def _black(self) -> Path:
        target = self.frame_dir / "black.png"
        if not target.exists():
            Image.new("RGB", (self.layout.width, self.layout.height), (0, 0, 0)).save(target)
        return target

    def blend(self, first: Path, second: Path, ratio: float) -> Path:
        """2枚の画面を混ぜた中間フレーム。シーン転換のクロスフェードに使う。"""
        key = f"{first.name}|{second.name}|{ratio:.3f}"
        target = self.frame_dir / f"x{hashlib.sha1(key.encode('utf-8')).hexdigest()[:15]}.png"
        if target.exists():
            return target
        a = Image.open(first).convert("RGB")
        b = Image.open(second).convert("RGB")
        Image.blend(a, b, ratio).save(target)
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
        self,
        canvas: Image.Image,
        speaking: CastMember,
        emotion: str,
        mouth_open: bool,
        hop_t: float = 1.0,
    ) -> None:
        """左右の立ち絵を配置する。話していない側は少し縮めて暗くする。

        話し始めの一瞬だけ、喋る側をひょいと跳ねさせる（hop_t が 0→1 の間）。
        """
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
            hop = 0
            if is_active and hop_t < 1.0:
                hop = int(-SPEAKER_HOP * math.sin(math.pi * max(0.0, hop_t)))
            canvas.alpha_composite(
                sprite, (cx - sprite.width // 2, base_y - sprite.height + hop)
            )

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

    def _draw_telop(
        self, canvas: Image.Image, member: CastMember, text: str, telop_t: float = 1.0
    ) -> None:
        if not text:
            return
        layer, draw = _layer(canvas.size)
        left, top, right, bottom = self.layout.telop_box
        # せり上がりながらフェードインする
        rise = int(TELOP_RISE * (1.0 - _ease_out(telop_t)))
        top, bottom = top + rise, bottom + rise
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
        if telop_t < 1.0:
            layer.putalpha(layer.getchannel("A").point(lambda a: int(a * _ease_out(telop_t))))
        canvas.alpha_composite(layer)

    # ------------------------------------------------------------ タイムライン

    def frame_entries(self, script: Script) -> list[tuple[Path, float]]:
        """(画像, 表示秒数) の並びを作る。口パクと演出をここで展開する。

        音声の尺は動かさない。演出に使う時間は、そのセリフの発話時間の内側から取る。
        """
        motion = self.config.motion
        entries: list[tuple[Path, float]] = []
        previous: Path | None = None

        for scene in script.scenes:
            for index, line in enumerate(scene.lines):
                closed = self.frame(line, scene, mouth_open=False)
                opened = self.frame(line, scene, mouth_open=True)
                pause = line.pause or 0.0
                speaking = max(0.0, line.duration - pause)
                is_scene_head = index == 0

                intro = 0.0
                if motion.enabled:
                    if is_scene_head and previous is not None and motion.scene_fade > 0:
                        # シーン転換。前の画面から新しい画面へ溶かす
                        intro = min(motion.scene_fade, speaking * 0.5)
                        entries += self._transition(previous, closed, intro)
                    elif line.telop_text() and motion.telop_in > 0:
                        # テロップがせり上がりつつ、話し手がひょいと跳ねる
                        intro = min(motion.telop_in, speaking * 0.5)
                        entries += self._intro(line, scene, intro)

                entries += self._mouth_loop(closed, opened, speaking - intro)
                if pause > 0.01:
                    entries.append((closed, pause))
                previous = closed

        return entries

    def _transition(self, before: Path, after: Path, seconds: float) -> list[tuple[Path, float]]:
        """シーン転換。

        crossfade は前後の画面を直接混ぜるので、テロップが一瞬二重に見える。
        既定の dip は一度黒に落としてから次の画面を出すため、文字が重ならない。
        """
        style = self.config.motion.scene_transition
        steps = max(2, round(seconds * self.config.motion.fps))
        step = seconds / steps

        if style == "crossfade":
            return [(self.blend(before, after, (i + 1) / steps), step) for i in range(steps)]

        black = self._black()
        half = steps // 2
        entries = [
            (self.blend(before, black, (i + 1) / half), step) for i in range(half)
        ]
        rest = steps - half
        entries += [(self.blend(black, after, (i + 1) / rest), step) for i in range(rest)]
        return entries

    def _intro(self, line: Line, scene: Scene, seconds: float) -> list[tuple[Path, float]]:
        steps = max(1, round(seconds * self.config.motion.fps))
        step = seconds / steps
        entries = []
        for i in range(steps):
            progress = (i + 1) / steps
            # 出現中は口を閉じたままにして、フレームの種類が増えすぎないようにする
            entries.append(
                (self.frame(line, scene, False, telop_t=progress, hop_t=progress), step)
            )
        return entries

    def _mouth_loop(self, closed: Path, opened: Path, seconds: float) -> list[tuple[Path, float]]:
        entries: list[tuple[Path, float]] = []
        remaining = max(0.0, seconds)
        mouth_open = False
        while remaining > 1e-6:
            step = min(MOUTH_INTERVAL, remaining)
            entries.append((opened if mouth_open else closed, step))
            mouth_open = not mouth_open
            remaining -= step
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


def _ease_out(t: float) -> float:
    """最後にゆっくり止まるイージング。"""
    t = max(0.0, min(1.0, t))
    return 1.0 - (1.0 - t) ** 3


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
