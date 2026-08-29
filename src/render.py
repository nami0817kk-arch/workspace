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
from .ffmpeg import is_video
from .config import CastMember, ProjectConfig, _resolve
from .script_model import Line, Scene, Script

MOUTH_INTERVAL = 0.14  # 口パクの切り替え間隔（秒）
TELOP_RISE = 46        # テロップが せり上がる 距離(px)

# 情報の確度バッジ。ニュース系で「確定」と「噂」を見た目で分けるためのもの
SOURCE_BADGES = {
    "official": ("確定", (61, 200, 120)),
    "report": ("報道", (235, 165, 40)),
    "rumor": ("未確認", (150, 152, 158)),
}
SPEAKER_HOP = 24       # 話し始めに立ち絵が跳ねる高さ(px)
TELOP_MARGIN = 110
TELOP_HEIGHT = 250
TELOP_BOTTOM = 58


@dataclass
class Layout:
    width: int
    height: int
    with_characters: bool = True

    @property
    def telop_box(self) -> tuple[int, int, int, int]:
        top = self.height - TELOP_BOTTOM - TELOP_HEIGHT
        return (TELOP_MARGIN, top, self.width - TELOP_MARGIN, top + TELOP_HEIGHT)

    @property
    def headline_box(self) -> tuple[int, int, int, int]:
        """立ち絵なしのときの見出し領域。下寄せで、画面の幅をたっぷり使う。"""
        left = int(self.width * 0.075)
        return (left, int(self.height * 0.58), self.width - left, int(self.height * 0.88))

    def character_anchor(self, position: str) -> tuple[int, int]:
        """立ち絵の中心 x と足元 y。"""
        x = int(self.width * (0.24 if position == "left" else 0.76))
        return x, self.telop_box[1] - 20


class Renderer:
    def __init__(self, config: ProjectConfig, work_dir: Path):
        self.config = config
        self.layout = Layout(
            config.video.width, config.video.height, config.video.show_characters
        )
        self.frame_dir = work_dir / "frames"
        self.frame_dir.mkdir(parents=True, exist_ok=True)

        font_path = str(config.video.font_path())
        self.font_telop = ImageFont.truetype(font_path, config.video.telop_size)
        self.font_headline = ImageFont.truetype(font_path, config.video.headline_size)
        self.font_name = ImageFont.truetype(font_path, config.video.name_size)
        self.font_scene = ImageFont.truetype(font_path, 36)

        self.script_background: str | None = None  # 台本 frontmatter の bg
        # 背景に動画が1つでも混ざる場合、フレームは透過で描いて後から重ねる
        self.over_video = False
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
        headline: tuple[str, str | None] | None = None,
    ) -> Path:
        """1枚の画面を描いて PNG のパスを返す。

        telop_t / hop_t は 0→1 のアニメーション進捗。同じ絵は使い回すので、
        アニメーションを入れてもフレーム数は必要なぶんしか増えない。

        headline に (文字列, 確度) を渡すと、その行の telop / source ではなく
        そちらを描く。ニュース風レイアウトで見出しを次の行にも残すために使う。
        """
        member = self.config.resolve_speaker(line.speaker)
        text, source = (line.telop_text(), line.source) if headline is None else headline
        background = scene.background or self.script_background or self.config.video.background
        key = "|".join(
            [
                background,
                scene.title,
                member.key if self.layout.with_characters else "-",
                line.emotion if self.layout.with_characters else "-",
                text,
                source or "",
                line.image or "",
                # 立ち絵を出さないなら口パクも跳ねも絵に影響しない
                ("open" if mouth_open else "close") if self.layout.with_characters else "-",
                f"{telop_t:.2f}/{hop_t if self.layout.with_characters else 1.0:.2f}",
                f"{self.layout.width}x{self.layout.height}",
            ]
        )
        target = self.frame_dir / f"{hashlib.sha1(key.encode('utf-8')).hexdigest()[:16]}.png"
        if target.exists():
            return target

        over_video = self.over_video
        canvas = self._transparent() if over_video else self._background(background).copy()
        if self.layout.with_characters:
            self._draw_characters(canvas, member, line.emotion, mouth_open, hop_t)
        if line.image:
            self._draw_inset(canvas, line.image)
        self._draw_scene_title(canvas, scene.title)
        if self.layout.with_characters:
            self._draw_telop(canvas, member, text, telop_t, source)
        else:
            self._draw_headline(canvas, text, telop_t, source)
        # 動画背景のときは重ねる前提なのでアルファを残す
        canvas.save(target) if over_video else canvas.convert("RGB").save(target)
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

    def _transparent(self) -> Image.Image:
        """動画背景に重ねるための透過キャンバス。

        実写のうえに白文字を置くと読めないので、下側だけ暗くする幕を先に敷く。
        """
        canvas = Image.new("RGBA", (self.layout.width, self.layout.height), (0, 0, 0, 0))
        scrim, draw = _layer(canvas.size)
        start = int(self.layout.height * 0.45)
        for y in range(start, self.layout.height):
            ratio = (y - start) / max(1, self.layout.height - start)
            draw.line([(0, y), (self.layout.width, y)], fill=(4, 8, 14, int(215 * ratio**1.3)))
        canvas.alpha_composite(scrim)
        return canvas

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
        self,
        canvas: Image.Image,
        member: CastMember,
        text: str,
        telop_t: float = 1.0,
        source: str | None = None,
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

        # 確度バッジは話者名の右隣に置く
        badge = SOURCE_BADGES.get(source or "")
        if badge:
            label, color = badge
            label_w = draw.textlength(label, font=self.font_name)
            box = [tag[2] + 16, tag[1], tag[2] + 16 + label_w + 44, tag[3]]
            draw.rounded_rectangle(box, radius=22, fill=color + (255,))
            draw.text((box[0] + 22, box[1] + 8), label, font=self.font_name, fill=(16, 16, 20, 255))

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

    def _draw_headline(
        self,
        canvas: Image.Image,
        text: str,
        telop_t: float = 1.0,
        source: str | None = None,
    ) -> None:
        """立ち絵なしのときの見出し。左に縦のアクセント帯を置いたニュース風。"""
        if not text:
            return
        layer, draw = _layer(canvas.size)
        left, top, right, bottom = self.layout.headline_box
        rise = int(TELOP_RISE * (1.0 - _ease_out(telop_t)))

        lines = wrap_text(draw, text, self.font_headline, right - left - 90)[:3]
        line_height = self.config.video.headline_size + 26
        text_top = bottom - line_height * len(lines) + rise

        badge = SOURCE_BADGES.get(source or "")
        # 話者ではなく情報の確度で色を決める。会話が続くあいだ見出しを動かさないため
        accent = badge[1] if badge else _hex(self.config.video.accent)

        # 縦のアクセント帯
        draw.rounded_rectangle(
            [left, text_top - 6, left + 11, text_top + line_height * len(lines) - 12],
            radius=6, fill=accent + (255,),
        )

        if badge:
            label, color = badge
            label_w = draw.textlength(label, font=self.font_name)
            chip = [left + 34, text_top - 84, left + 34 + label_w + 46, text_top - 20]
            draw.rounded_rectangle(chip, radius=22, fill=color + (255,))
            draw.text((chip[0] + 23, chip[1] + 9), label, font=self.font_name,
                      fill=(16, 16, 20, 255))

        y = text_top
        for chunk in lines:
            draw.text(
                (left + 34, y), chunk, font=self.font_headline, fill=(255, 255, 255, 255),
                stroke_width=5, stroke_fill=(0, 0, 0, 225),
            )
            y += line_height

        if telop_t < 1.0:
            layer.putalpha(layer.getchannel("A").point(lambda a: int(a * _ease_out(telop_t))))
        canvas.alpha_composite(layer)

    # ------------------------------------------------------------ タイムライン

    def frame_entries(self, script: Script) -> list[tuple[Path, float]]:
        self.script_background = script.background
        self.over_video = any(is_video(bg) for bg, _ in self.background_segments(script))
        """(画像, 表示秒数) の並びを作る。口パクと演出をここで展開する。

        音声の尺は動かさない。演出に使う時間は、そのセリフの発話時間の内側から取る。
        """
        motion = self.config.motion
        entries: list[tuple[Path, float]] = []
        previous: Path | None = None

        for scene in script.scenes:
            headline: tuple[str, str | None] = ("", None)
            for index, line in enumerate(scene.lines):
                # 立ち絵なしのニュース風では、見出しは telop を書いた行でだけ差し替え、
                # それ以外の行は直前の見出しを出したままにする（生のセリフは出さない）
                changed = True
                current: tuple[str, str | None] | None = None
                if not self.layout.with_characters:
                    previous_headline = headline
                    if line.no_telop:
                        headline = ("", None)
                    elif line.telop is not None:
                        # 見出しと確度はセットで差し替える
                        headline = (line.telop, line.source)
                    current = headline
                    changed = headline != previous_headline

                closed = self.frame(line, scene, mouth_open=False, headline=current)
                opened = self.frame(line, scene, mouth_open=True, headline=current)
                pause = line.pause or 0.0
                speaking = max(0.0, line.duration - pause)
                is_scene_head = index == 0

                intro = 0.0
                if motion.enabled:
                    if is_scene_head and previous is not None and motion.scene_fade > 0:
                        # シーン転換。前の画面から新しい画面へ溶かす
                        intro = min(motion.scene_fade, speaking * 0.5)
                        entries += self._transition(previous, closed, intro)
                    elif changed and motion.telop_in > 0 and (
                        current[0] if current else line.telop_text()
                    ):
                        # 見出しが変わったときだけ、せり上がりのアニメを入れる
                        intro = min(motion.telop_in, speaking * 0.5)
                        entries += self._intro(line, scene, intro, current)

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

    def _intro(
        self,
        line: Line,
        scene: Scene,
        seconds: float,
        headline: tuple[str, str | None] | None = None,
    ) -> list[tuple[Path, float]]:
        steps = max(1, round(seconds * self.config.motion.fps))
        step = seconds / steps
        entries = []
        for i in range(steps):
            progress = (i + 1) / steps
            # 出現中は口を閉じたままにして、フレームの種類が増えすぎないようにする
            entries.append(
                (
                    self.frame(
                        line, scene, False, telop_t=progress, hop_t=progress, headline=headline
                    ),
                    step,
                )
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

    def background_segments(self, script: Script) -> list[tuple[Path, float]]:
        """シーンごとの (背景, 表示秒数)。静止画と動画を混ぜてよい。"""
        segments: list[tuple[Path, float]] = []
        for scene in script.scenes:
            name = scene.background or script.background or self.config.video.background
            segments.append((_resolve(name), scene.duration))
        return segments

    def build_video(
        self, script: Script, audio_path: Path | None, out_path: Path, work_dir: Path
    ) -> Path:
        entries = self.frame_entries(script)
        list_path = ffmpeg.write_concat_list(entries, work_dir / "frames.txt")
        out_path.parent.mkdir(parents=True, exist_ok=True)
        size = (self.layout.width, self.layout.height)

        if self.over_video:
            # 背景をつないだ1本の動画にしてから、透過フレームを重ねる
            track = ffmpeg.build_background_track(
                self.background_segments(script),
                work_dir / "background.mp4",
                size,
                self.config.video.fps,
            )
            return ffmpeg.encode_video_over_clip(
                list_path, track, audio_path, out_path, size, self.config.video.fps
            )
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
