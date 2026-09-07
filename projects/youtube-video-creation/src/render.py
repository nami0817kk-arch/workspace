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

from . import cards, ffmpeg
from .backgrounds import moving_background
from .inserts import Inserts
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
    "context": ("背景", (124, 148, 184)),
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
    def is_portrait(self) -> bool:
        """縦型（ショート）か。**横型の割合をそのまま使うと文字が切れる。**

        実測（2026-09-06）で、幅1080の縦型にカードを64%（691px）で作ったところ、
        選手名が右端で切れた。横1920なら同じ64%で1228pxあり、収まっていた。
        """
        return self.height > self.width

    @property
    def media_slot(self) -> tuple[int, int]:
        """画像やカードを置く縦の範囲。文字の上を使う。"""
        floor = (self.headline_box if not self.with_characters else self.telop_box)[1]
        return (int(self.height * 0.11), floor - 34)

    @property
    def headline_box(self) -> tuple[int, int, int, int]:
        """立ち絵なしのときの見出し領域。下寄せで、画面の幅をたっぷり使う。

        **縦型は余白を削る。**伸びている参考チャンネルは見出しが画面幅いっぱいで、
        こちらは幅1080に対して余白が左右75pxずつあった（2026-09-07 に並べて確認）。
        """
        left = int(self.width * (0.042 if self.is_portrait else 0.075))
        return (left, int(self.height * 0.58), self.width - left, int(self.height * 0.88))

    def character_anchor(self, position: str) -> tuple[int, int]:
        """立ち絵の中心 x と足元 y。"""
        x = int(self.width * (0.24 if position == "left" else 0.76))
        return x, self.telop_box[1] - 20


# 台本の構造につけた名前で、視聴者には情報にならないもの。左上のラベルには出さない
INTERNAL_SCENE_TITLES = ("オープニング", "イントロ", "まとめ", "エンディング", "締め")


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
        self.font_title = ImageFont.truetype(font_path, config.video.title_size)
        # 冒頭のタイトルは全画面なので大きめに組む
        self.font_title_big = ImageFont.truetype(font_path, int(config.video.title_size * 1.4))
        self.font_label = ImageFont.truetype(font_path, 32)
        self.font_date = ImageFont.truetype(font_path, 30)

        self.script_background: str | None = None  # 台本 frontmatter の bg
        self.script_cards: dict = {}
        self.script_date = ""
        self.card_dir = work_dir / "cards"
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
        panel: tuple[str, str | None, str | None] | None = None,
    ) -> Path:
        """1枚の画面を描いて PNG のパスを返す。

        telop_t / hop_t は 0→1 のアニメーション進捗。同じ絵は使い回すので、
        アニメーションを入れてもフレーム数は必要なぶんしか増えない。

        panel に (見出し, 確度, カード名) を渡すと、その行の telop / source / card
        ではなくそちらを描く。ニュース風レイアウトで見出しやカードを次の行にも
        残すために使う。
        """
        member = self.config.resolve_speaker(line.speaker)
        text, source, card = (
            (line.telop_text(), line.source, line.card) if panel is None else panel
        )
        background = scene.background or self.script_background or self.config.video.background
        key = "|".join(
            [
                background,
                scene.title,
                member.key if self.layout.with_characters else "-",
                line.emotion if self.layout.with_characters else "-",
                text,
                source or "",
                card or "",
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
        self._draw_media(canvas, line.image, card, telop_t)
        # **縦型では制作側の言葉を画面に出さない**（2026-09-07 の方針）。
        # 「オープニング」「まとめ」は章の目印で、視聴者には意味が無い。
        # 一等地の左上を、本編の作業用ラベルで埋めない。
        # 中身のある節名（「監督は何と言ったか」など）は残す
        if not (self.layout.is_portrait and scene.title in INTERNAL_LABELS):
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

    def _draw_media(
        self,
        canvas: Image.Image,
        image_path: str | None,
        card_name: str | None,
        progress: float = 1.0,
    ) -> None:
        """画像とカードを文字の上のスペースに置く。両方あれば左右に並べる。

        以前は縦に積んでいたが、カードが高いぶん写真が潰れた。実測
        （2026-09-04）で、顔が判別できない大きさ（横120px）になっていた。
        画面は横1920あるので、両方あるときは幅を使う。
        """
        slot_top, slot_bottom = self.layout.media_slot
        slot_height = max(80, slot_bottom - slot_top)
        # **縦型は縦に積む。**横に並べると1つあたりの幅が半分になり、
        # ただでさえ狭い1080がさらに割れる。上下は余っている
        side_by_side = (bool(image_path) and bool(card_name)
                        and not self.layout.is_portrait)
        items: list[Image.Image] = []

        if image_path:
            picture = self._picture(image_path, slot_height, beside=side_by_side)
            if picture is not None:
                items.append(picture)
        if card_name:
            card = self._card(card_name, beside=side_by_side)
            if card is not None:
                items.append(card)
        if not items:
            return

        gap = 26
        if side_by_side and len(items) == 2:
            self._place_beside(canvas, items, slot_top, slot_height, gap, progress)
            return
        total = sum(item.height for item in items) + gap * (len(items) - 1)
        if total > slot_height:  # 入りきらないときは全体を縮める
            ratio = slot_height / total
            items = [
                item.resize(
                    (int(item.width * ratio), int(item.height * ratio)), Image.LANCZOS
                )
                for item in items
            ]
            total = sum(item.height for item in items) + gap * (len(items) - 1)

        y = slot_top + (slot_height - total) // 2
        for item in items:
            if progress < 1.0:
                item = item.copy()
                item.putalpha(
                    item.getchannel("A").point(lambda a: int(a * _ease_out(progress)))
                )
            canvas.alpha_composite(item, ((self.layout.width - item.width) // 2, y))
            y += item.height + gap

    def _place_beside(
        self,
        canvas: Image.Image,
        items: list[Image.Image],
        slot_top: int,
        slot_height: int,
        gap: int,
        progress: float,
    ) -> None:
        """写真とカードを左右に並べる。高さは各自の中央でそろえる。"""
        total_w = sum(item.width for item in items) + gap
        if total_w > self.layout.width - 96:  # 端に寄りすぎないよう全体を縮める
            ratio = (self.layout.width - 96) / total_w
            items = [
                item.resize((int(item.width * ratio), int(item.height * ratio)), Image.LANCZOS)
                for item in items
            ]
            total_w = sum(item.width for item in items) + gap
        x = (self.layout.width - total_w) // 2
        for item in items:
            if progress < 1.0:
                item = item.copy()
                item.putalpha(item.getchannel("A").point(lambda a: int(a * _ease_out(progress))))
            y = slot_top + (slot_height - item.height) // 2
            canvas.alpha_composite(item, (x, y))
            x += item.width + gap

    def _picture(
        self, image_path: str, slot_height: int, beside: bool = False
    ) -> Image.Image | None:
        """差し込む写真。白フチを付けて画面になじませる。

        ``beside`` はカードと横に並べるとき。幅は譲るが、**高さは枠いっぱい
        使う**。縦長の人物写真はここで効く。
        """
        path = _resolve(image_path)
        if not path.exists():
            return None
        picture = Image.open(path).convert("RGBA")
        if beside:
            max_w = int(self.layout.width * 0.26)
            max_h = int(slot_height * 0.98)
        else:
            max_w = int(self.layout.width * (0.62 if not self.layout.with_characters else 0.42))
            # **縦型は顔を大きく見せる。**縦1920では高さ側が先に頭打ちになり、
            # 幅 0.62 を使い切っていなかった（実測で写真の幅が画面の3割）。
            # 縦画面は顔が主役で、「サムネに顔を必ず入れる」方針とも揃う。
            # **横型の値は触らない。**本編の画面設計は変えない
            max_h = int(slot_height * (0.92 if self.layout.is_portrait else 0.72))
        scale = min(max_w / picture.width, max_h / picture.height)
        picture = picture.resize(
            (int(picture.width * scale), int(picture.height * scale)), Image.LANCZOS
        )
        framed = Image.new(
            "RGBA", (picture.width + 16, picture.height + 16), (255, 255, 255, 235)
        )
        framed.alpha_composite(picture, (8, 8))
        return framed

    def _card(self, name: str, beside: bool = False) -> Image.Image | None:
        spec = self.script_cards.get(name)
        if not spec:
            return None
        if self.layout.is_portrait:
            # **縦型は幅をほぼ使い切る。**割合で決めると横型より狭くなり、
            # 同じ文字量が入らない。上下は余っているので、幅を優先する
            width = int(self.layout.width * 0.90)
        elif beside:  # 写真と横に並べるぶん、カードは幅を譲る
            width = int(self.layout.width * (0.52 if not self.layout.with_characters else 0.40))
        else:
            width = int(self.layout.width * (0.64 if not self.layout.with_characters else 0.46))
        target = self.card_dir / f"{cards.card_key(spec, width)}.png"
        if not target.exists():
            cards.render(
                spec,
                width,
                str(self.config.video.font_path()),
                target,
                str(self.config.video.latin_font_path()),
            )
        return Image.open(target).convert("RGBA")

    def _draw_scene_title(self, canvas: Image.Image, title: str) -> None:
        # RGBA の canvas に直接半透明の図形を描くと下地を「置き換えて」しまうため、
        # 透明レイヤーに描いてから alpha_composite する。
        layer, draw = _layer(canvas.size)
        # **制作側の言葉は画面に出さない**（2026-09-07）。「オープニング」は
        # 台本の構造の名前で、視聴者には何の情報でもない。しかも冒頭の
        # いちばん見られる位置に出ていた。日付は残す
        if title.strip() not in INTERNAL_SCENE_TITLES:
            text_w = draw.textlength(title, font=self.font_scene)
            draw.rounded_rectangle(
                [48, 42, 48 + text_w + 56, 42 + 68], radius=34, fill=(0, 0, 0, 150)
            )
            draw.text((76, 58), title, font=self.font_scene, fill=(240, 240, 240, 255))

        if self.script_date:
            date_w = draw.textlength(self.script_date, font=self.font_date)
            right = canvas.width - 48
            draw.text(
                (right - date_w, 62), self.script_date, font=self.font_date,
                fill=(206, 214, 226, 255), stroke_width=3, stroke_fill=(0, 0, 0, 190),
            )
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

        lines = balanced_wrap(draw, text, self.font_headline, right - left - 90)[:3]
        line_height = self.config.video.headline_size + 26
        text_top = bottom - line_height * len(lines) + rise

        badge = SOURCE_BADGES.get(source or "")
        # 話者ではなく情報の確度で色を決める。会話が続くあいだ見出しを動かさないため
        accent = badge[1] if badge else _hex(self.config.video.accent)

        # 文字の下に暗い帯を敷く。**縁取りだけでは背景に沈む**（2026-09-07 に
        # 参考チャンネルと並べて確認）。63万回のチャンネルは白文字＋黒帯で、
        # 実写の上でも見出しが読めていた。こちらは白文字＋細い縁だけだった。
        band_right = left
        for chunk in lines:
            band_right = max(band_right, left + 34 + draw.textlength(chunk, font=self.font_headline))
        draw.rounded_rectangle(
            [left - 8, text_top - 18,
             min(right, int(band_right + 34)), text_top + line_height * len(lines) - 4],
            radius=10, fill=(8, 10, 16, 170),
        )

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
            # 縁取りは縦型で太くする。実写や模様の上でも輪郭が残るように
            draw.text(
                (left + 34, y), chunk, font=self.font_headline, fill=(255, 255, 255, 255),
                stroke_width=8 if self.layout.is_portrait else 5,
                stroke_fill=(0, 0, 0, 235),
            )
            y += line_height

        if telop_t < 1.0:
            layer.putalpha(layer.getchannel("A").point(lambda a: int(a * _ease_out(telop_t))))
        canvas.alpha_composite(layer)

    def title_frame(
        self,
        background: str,
        heading: str,
        sub: str,
        progress: float,
        kind: str,
        label: str = "",
    ) -> Path:
        """冒頭タイトル / 章タイトルの1枚。progress は 0→1 のフェード。"""
        key = f"title|{kind}|{background}|{heading}|{sub}|{label}|{progress:.2f}|{self.over_video}"
        target = self.frame_dir / f"t{hashlib.sha1(key.encode('utf-8')).hexdigest()[:15]}.png"
        if target.exists():
            return target

        base = self._transparent() if self.over_video else self._background(background).copy()
        layer, draw = _layer(base.size)

        # 背景を落として文字を主役にする。落としすぎると背景が死ぬので控えめに
        draw.rectangle([0, 0, base.width, base.height], fill=(6, 10, 18, 178))

        accent = _hex(self.config.video.accent)
        font = self.font_title_big if kind == "intro" else self.font_title
        lines = wrap_text(draw, heading, font, int(base.width * 0.76))[:3]
        line_height = font.size + 26
        block = line_height * len(lines)
        top = (base.height - block) // 2 - (34 if sub else 0)

        left = int(base.width * 0.11)
        if label:
            draw.text(
                (left, top - 60), label, font=self.font_label, fill=accent + (255,),
                stroke_width=3, stroke_fill=(0, 0, 0, 190),
            )
        draw.rounded_rectangle(
            [left - 36, top + 6, left - 22, top + block - 14], radius=7, fill=accent + (255,)
        )
        y = top
        for chunk in lines:
            draw.text(
                (left, y), chunk, font=font, fill=(255, 255, 255, 255),
                stroke_width=6, stroke_fill=(0, 0, 0, 205),
            )
            y += line_height

        if sub:
            draw.text((left, y + 14), sub, font=self.font_scene, fill=(190, 200, 216, 255))

        if progress < 1.0:
            layer.putalpha(layer.getchannel("A").point(lambda a: int(a * _ease_out(progress))))
        base.alpha_composite(layer)
        base.save(target) if self.over_video else base.convert("RGB").save(target)
        return target

    def _title_entries(
        self,
        background: str,
        heading: str,
        sub: str,
        seconds: float,
        kind: str,
        label: str = "",
    ) -> list[tuple[Path, float]]:
        """フェードイン → 静止 → フェードアウト。静止部分は1枚を使い回す。"""
        fade = min(self.config.titles.fade, seconds / 2.5)
        steps = max(1, round(fade * self.config.motion.fps))
        step = fade / steps
        entries: list[tuple[Path, float]] = []

        for i in range(steps):
            entries.append(
                (self.title_frame(background, heading, sub, (i + 1) / steps, kind, label), step)
            )
        hold = max(0.0, seconds - fade * 2)
        if hold > 0:
            entries.append((self.title_frame(background, heading, sub, 1.0, kind, label), hold))
        for i in range(steps):
            entries.append(
                (self.title_frame(background, heading, sub, 1 - (i + 1) / steps, kind, label), step)
            )
        return entries

    # ------------------------------------------------------------ タイムライン

    def frame_entries(
        self, script: Script, inserts: Inserts | None = None
    ) -> list[tuple[Path, float]]:
        """(画像, 表示秒数) の並びを作る。タイトルカード・口パク・演出をここで展開する。

        セリフの尺は動かさない。演出に使う時間は発話時間の内側から取り、
        タイトルカードのぶんは音声側に無音が入っているので、ここでも同じ秒数を使う。
        """
        self.script_background = script.background
        self.script_cards = script.cards
        self.script_date = script.date
        self.over_video = any(is_video(bg) for bg, _ in self.background_segments(script))
        motion = self.config.motion
        inserts = inserts or Inserts()
        entries: list[tuple[Path, float]] = []
        previous: Path | None = None

        if inserts.intro > 0 and script.scenes:
            first_bg = script.scenes[0].background or script.background or self.config.video.background
            entries += self._title_entries(
                first_bg,
                script.intro_title(),
                script.date,
                inserts.intro,
                "intro",
                str(script.meta.get("intro_label") or ""),
            )

        for scene_index, scene in enumerate(script.scenes):
            gap = inserts.before_scene(scene_index)
            if gap > 0:
                background = scene.background or script.background or self.config.video.background
                entries += self._title_entries(
                    background,
                    scene.title,
                    f"{scene_index + 1} / {len(script.scenes)}",
                    gap,
                    "chapter",
                )
                previous = None  # 章タイトル直後は転換の溶かしを入れない
            headline: tuple[str, str | None] = ("", None)
            card: str | None = None
            for index, line in enumerate(scene.lines):
                # 立ち絵なしのニュース風では、見出しは telop を書いた行でだけ差し替え、
                # それ以外の行は直前の見出しを出したままにする（生のセリフは出さない）
                changed = True
                current: tuple[str, str | None, str | None] | None = None
                if not self.layout.with_characters:
                    before = (headline, card)
                    if line.no_telop:
                        headline = ("", None)
                    elif line.telop is not None:
                        # 見出しと確度はセットで差し替える
                        headline = (line.telop, line.source)
                    if line.card is not None:
                        # カードも指定した行で差し替え、それ以外は出したまま
                        card = None if line.card in ("none", "なし") else line.card
                    current = (headline[0], headline[1], card)
                    changed = (headline, card) != before

                closed = self.frame(line, scene, mouth_open=False, panel=current)
                opened = self.frame(line, scene, mouth_open=True, panel=current)
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
                        (current[0] or current[2]) if current else line.telop_text()
                    ):
                        # 見出しやカードが変わったときだけ、出現のアニメを入れる
                        intro = min(motion.telop_in, speaking * 0.5)
                        entries += self._intro(line, scene, intro, current)

                entries += self._mouth_loop(closed, opened, speaking - intro)
                if pause > 0.01:
                    entries.append((closed, pause))
                previous = closed

        if inserts.outro > 0 and script.scenes:
            last_bg = (
                script.scenes[-1].background or script.background or self.config.video.background
            )
            entries += self._title_entries(
                last_bg,
                str(script.meta.get("outro_title") or "ご視聴ありがとうございました"),
                str(script.meta.get("outro_sub") or "チャンネル登録で続報をチェック"),
                inserts.outro,
                "outro",
                str(script.meta.get("intro_label") or ""),
            )

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
        panel: tuple[str, str | None, str | None] | None = None,
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
                        line, scene, False, telop_t=progress, hop_t=progress, panel=panel
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

    def background_segments(
        self, script: Script, inserts: Inserts | None = None
    ) -> list[tuple[Path, float]]:
        """シーンごとの (背景, 表示秒数)。静止画と動画を混ぜてよい。

        タイトルカードのぶんも、そのシーンの背景で埋める。
        """
        inserts = inserts or Inserts()
        segments: list[tuple[Path, float]] = []
        for index, scene in enumerate(script.scenes):
            name = scene.background or script.background or self.config.video.background
            # 既に書いた台本は .png を指している。書き出しのたびに実写を探す
            name = moving_background(name)
            extra = inserts.before_scene(index)
            if index == 0:
                extra += inserts.intro
            if index == len(script.scenes) - 1:
                extra += inserts.outro
            seconds = scene.duration + extra
            segments += self._split_long(name, seconds, index)
        return segments

    # 1枚の絵をこれ以上見せ続けない。実測で「まとめ」が24秒あり、
    # 同じ画面が3カット続いていた。
    # 2026-09-05 に 12秒 → 7秒。参考3チャンネルは尺そのものが1〜2分で、
    # 絵が変わらない時間が長いと**間が持たない**。背景が切り替わるだけでも
    # 画面は動いて見える
    MAX_STILL_SECONDS = 7.0

    def _split_long(self, name: str, seconds: float, index: int) -> list[tuple[Path, float]]:
        """長いシーンは背景を2枚に割る。読み上げの途中でも絵が変わる。

        割る先は BACKGROUNDS の並びから、いまの絵と違うものを選ぶ。
        動画の背景（mp4）は元から動いているので割らない。
        """
        source = _resolve(name)
        if seconds <= self.MAX_STILL_SECONDS or is_video(source):
            return [(self._moving(source, seconds), seconds)]

        from .research import BACKGROUNDS

        alternatives = [c for c in BACKGROUNDS if Path(c).name != source.name]
        if not alternatives:
            return [(self._moving(source, seconds), seconds)]
        second = _resolve(alternatives[index % len(alternatives)])
        if not second.exists():
            return [(self._moving(source, seconds), seconds)]

        half = seconds / 2
        return [
            (self._moving(source, half), half),
            (self._moving(second, seconds - half), seconds - half),
        ]

    def _moving(self, path: Path, seconds: float) -> Path:
        """静止画の背景を、ゆっくり寄っていくクリップに置き換える。

        止まった絵が続くと動画に見えないので既定で有効。同じ画と長さの
        組み合わせは作り直さない。
        """
        zoom = self.config.motion.background_zoom
        if zoom <= 1.0 or is_video(path) or not path.exists():
            return path

        length = max(4.0, math.ceil(seconds))
        cache = _resolve("assets/backgrounds/.motion")
        # 名前に**元画像の中身の指紋**を入れる。名前が同じだと古いクリップが
        # 使い回され、背景を描き直しても反映されない（2026-09-05 に実際に
        # 起きた。背景の模様を増やしたのに、動画は前のまま静止していた）。
        # 寄り方を変えたときも同じことが起きるので、版（r2）も残す。
        stamp = hashlib.sha1(path.read_bytes()).hexdigest()[:8]
        target = cache / f"{path.stem}_{int(length)}s_{int(zoom * 100)}r2_{stamp}.mp4"
        if not target.exists():
            cache.mkdir(parents=True, exist_ok=True)
            ffmpeg.still_to_clip(
                path, target, length,
                (self.layout.width, self.layout.height), zoom, self.config.video.fps,
            )
        return target

    def build_video(
        self,
        script: Script,
        audio_path: Path | None,
        out_path: Path,
        work_dir: Path,
        inserts: Inserts | None = None,
    ) -> Path:
        entries = self.frame_entries(script, inserts)
        list_path = ffmpeg.write_concat_list(entries, work_dir / "frames.txt")
        out_path.parent.mkdir(parents=True, exist_ok=True)
        size = (self.layout.width, self.layout.height)

        if self.over_video:
            # 背景をつないだ1本の動画にしてから、透過フレームを重ねる
            track = ffmpeg.build_background_track(
                self.background_segments(script, inserts),
                work_dir / "background.mp4",
                size,
                self.config.video.fps,
            )
            return ffmpeg.encode_video_over_clip(
                list_path, track, audio_path, out_path, size, self.config.video.fps
            )
        return ffmpeg.encode_video(list_path, audio_path, out_path, self.config.video.fps)


def balanced_wrap(
    draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_width: float
) -> list[str]:
    """折り返した行の長さをそろえる。

    素直に詰めると最後の行だけ数文字になりがちで、見出しとして落ち着かない。
    行数を変えずに幅を狭めて配り直す。
    """
    lines = wrap_text(draw, text, font, max_width)
    if len(lines) < 2:
        return lines

    # 行数が同じ候補の中から、切れ目のいちばん良いものを選ぶ。
    # 幅だけで詰めると「チェルシーが激怒した、移／籍期限…」のように
    # 熟語の途中で割れる。句読点の直後で切れているほうが読みやすい。
    # 幅を少しずつ狭めて候補を作る。刻みが粗いと、良い切れ目の幅を飛ばす。
    # 実測（2026-09-04）で、5段階だと「12月まで／戻らない」で切れる幅
    # （上限の約0.88倍）が候補に入らず、「まで戻／らない」しか選べなかった。
    best = lines
    best_score = _break_score(lines)
    for step in range(60, 100, 2):
        candidate = wrap_text(draw, text, font, max_width * step / 100)
        if len(candidate) != len(lines):
            continue
        score = _break_score(candidate)
        if score > best_score:
            best, best_score = candidate, score
    return best


# 行末がこの文字なら、切れ目として良い（意味の区切りで改行できている）
GOOD_BREAK_END = "、。！？」』）・"


def _is_kanji(char: str) -> bool:
    return "一" <= char <= "鿿"


def _is_hiragana(char: str) -> bool:
    return "ぁ" <= char <= "ん"


def _is_katakana(char: str) -> bool:
    return "ァ" <= char <= "ヴ"


# 行頭に来ても読みを壊さないひらがな（助詞・助動詞の頭）。
# 「選手が／外れた」は読めるが、「戻／らない」は動詞が割れて読めない。
# どちらも「漢字のあとにひらがな」で、字種だけでは見分けられないので、
# 助詞として使われる字を挙げて区別する。
PARTICLE_HEAD = "がをにはへもとやでかねよ"


def _break_score(lines: list[str]) -> int:
    """行の切れ目の良さ。大きいほど読みやすい。

    - 句読点や閉じ括弧で終わっていれば +2（意味の区切りで改行できている）
    - 漢字が続く途中で割ったら -3（「移／籍」「成／立」のような熟語の分断）
    - カタカナが続く途中で割ったら -3（「シー／ズン」。外来語は1語で読む）
    - ひらがなが続く途中で割ったら -2（「12月ま／で」「動くかど／うか」）
    - 送り仮名を置き去りにしたら -2（「戻／らない」。助詞なら減点しない）

    分断のほうを重く見る。多少 行末がそろわなくても、語が割れないほうが読める。

    ひらがなを漢字より軽くしているのは、助詞の切れ目（「遠藤選手が／外れた」）は
    実際には読めるため。同じ減点にすると、まともな切れ目まで避けてしまう。
    """
    score = 0
    for index, line in enumerate(lines[:-1]):
        if not line:
            continue
        if line[-1] in GOOD_BREAK_END:
            score += 2
        next_line = lines[index + 1]
        if not next_line:
            continue
        tail, head = line[-1], next_line[0]
        if _is_kanji(tail) and _is_kanji(head):
            score -= 3
        elif _is_katakana(tail) and _is_katakana(head):
            score -= 3
        elif _is_hiragana(tail) and _is_hiragana(head):
            score -= 2
        elif _is_kanji(tail) and _is_hiragana(head) and head not in PARTICLE_HEAD:
            score -= 2
    return score


# 行頭に置いてはいけない文字（行頭禁則）。
# 約物だけでは足りない。実測で「チェルシー」が「チ／ェルシー」に割れ、
# 行頭が小文字の「ェ」になっていた。拗音・促音・長音符も行頭に来てはいけない。
LINE_START_FORBIDDEN = (
    "、。，．・：；！？」』）］｝〉》"      # 約物
    "ぁぃぅぇぉっゃゅょゎゕゖ"              # ひらがなの小書き
    "ァィゥェォッャュョヮヵヶ"              # カタカナの小書き
    "ーヽヾゝゞ々〻"                        # 長音符・繰り返し記号
    ",.!?:;)]}’”"                # 欧文の約物
)

# 行末に置いてはいけない文字（行末禁則）。開き括弧はぶら下げない
LINE_END_FORBIDDEN = "「『（［｛〈《([{‘“"


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_width: float) -> list[str]:
    """日本語向けに1文字ずつ幅を見て折り返す。行頭・行末の禁則を守る。

    幅だけで切ると、単語や拗音の途中で改行されて読みにくくなる。
    実測では「チェルシー」が「チ／ェルシー」に、「成立」が「成／立」に割れていた。
    """
    forbidden = LINE_START_FORBIDDEN
    lines: list[str] = []
    current = ""
    for char in text:
        if char == "\n":
            lines.append(current)
            current = ""
            continue
        if draw.textlength(current + char, font=font) > max_width and current:
            if char in forbidden:
                # 行頭に来てはいけない文字は、はみ出しても前の行にぶら下げる
                current += char
                lines.append(current)
                current = ""
                continue
            # 行末に来てはいけない文字（開き括弧）は、次の行へ送る
            if current[-1] in LINE_END_FORBIDDEN:
                lines.append(current[:-1])
                current = current[-1] + char
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


# 制作の都合で付けている章の名前。視聴者に見せる意味が無い
INTERNAL_LABELS = ("オープニング", "まとめ")


def _cover(image: Image.Image, width: int, height: int, focus: float | None = None) -> Image.Image:
    """アスペクト比を保ったまま画面いっぱいに敷き詰める。

    **縦長の写真は上寄りに切る。**人物写真は顔が上にあるので、真ん中で切ると
    顔が落ちる。実測（2026-09-05）で、サムネに選手の写真を敷いたら胴体だけが
    残り、誰なのか分からなくなった。
    """
    scale = max(width / image.width, height / image.height)
    resized = image.resize((int(image.width * scale), int(image.height * scale)), Image.LANCZOS)
    left = (resized.width - width) // 2
    spare = resized.height - height
    tall = image.height > image.width * 1.1
    # focus は「縦のどこを残すか」（0.0=上端 / 1.0=下端）。**顔の位置は写真ごとに
    # 違うので、割合の決め打ちでは当たらない**（2026-09-05 実測。上から12%で
    # 切ったら、顔が真ん中にある写真で目の高さから切れた）。既定は当たりで、
    # 合わないものは台本から指定する
    where = focus if focus is not None else (0.12 if tall else 0.5)
    top = int(spare * min(1.0, max(0.0, where)))
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
