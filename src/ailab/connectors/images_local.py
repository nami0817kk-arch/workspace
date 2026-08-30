"""APIキー不要のローカル画像生成（Pillow）。

生成AIではなく、プロンプトから決定的に作るアブストラクト画像。
ダミー画像・プレースホルダ・OGP風バナーなど「とりあえず絵が要る」場面に使う。
同じプロンプトからは常に同じ画像が得られる。
"""

from __future__ import annotations

import colorsys
import hashlib
import io
import random
from pathlib import Path

from ..core.connector import AuthSpec, CheckResult, Connector
from ..core.errors import ConnectorError
from ..core.registry import register
from ..core.types import GeneratedImage
from ..utils import parse_size

#: 日本語が化けないように、よくある CJK フォントを順に探す
FONT_CANDIDATES = [
    "C:/Windows/Fonts/meiryo.ttc",
    "C:/Windows/Fonts/YuGothM.ttc",
    "C:/Windows/Fonts/msgothic.ttc",
    "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
]


def pick_font(size: int):
    """使えるフォントを1つ選ぶ（見つからなければ Pillow 標準フォント）。"""
    from PIL import ImageFont

    for candidate in FONT_CANDIDATES:
        if Path(candidate).is_file():
            try:
                return ImageFont.truetype(candidate, size)
            except OSError:
                continue
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # Pillow < 10.1
        return ImageFont.load_default()


def _palette(rng: random.Random) -> tuple[tuple[int, int, int], tuple[int, int, int]]:
    """相性のよい2色（グラデーションの上下）を作る。"""
    hue = rng.random()
    shift = rng.choice([0.08, -0.08, 0.5, 0.33])

    def rgb(h: float, s: float, v: float) -> tuple[int, int, int]:
        r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v)
        return int(r * 255), int(g * 255), int(b * 255)

    return rgb(hue, 0.55, 0.95), rgb(hue + shift, 0.75, 0.55)


def _wrap(text: str, font, max_width: int, draw) -> list[str]:
    """描画幅に収まるように改行する（日本語は1文字単位で折り返す）。"""
    lines: list[str] = []
    current = ""
    for char in text:
        trial = current + char
        if draw.textlength(trial, font=font) > max_width and current:
            lines.append(current)
            current = char
        else:
            current = trial
    if current:
        lines.append(current)
    return lines[:3]


@register
class LocalImages(Connector):
    name = "local"
    category = "images"
    summary = "APIキー不要のローカル生成（プレースホルダ画像）"
    auth = AuthSpec()
    default_model = "abstract-v1"
    priority = 90

    def check(self) -> CheckResult:
        try:
            import PIL  # noqa: F401
        except ImportError:
            return CheckResult(self.name, ok=False, detail="Pillow が入っていません")
        return CheckResult(self.name, ok=True, detail="ローカル生成が使えます")

    def generate(
        self,
        prompt: str,
        *,
        size: str = "1024x1024",
        n: int = 1,
        model: str | None = None,
        timeout: int = 180,
        caption: bool = True,
    ) -> list[GeneratedImage]:
        try:
            from PIL import Image, ImageDraw, ImageFilter
        except ImportError as exc:  # pragma: no cover - 環境依存
            raise ConnectorError("Pillow が必要です: pip install Pillow") from exc

        width, height = parse_size(size)
        images: list[GeneratedImage] = []

        for index in range(max(1, n)):
            seed = hashlib.sha256(f"{prompt}#{index}".encode("utf-8")).hexdigest()
            rng = random.Random(int(seed[:16], 16))
            top, bottom = _palette(rng)

            base = Image.new("RGB", (width, height), top)
            draw = ImageDraw.Draw(base)
            for y in range(height):  # 縦グラデーション
                t = y / max(1, height - 1)
                draw.line(
                    [(0, y), (width, y)],
                    fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)),
                )

            shapes = Image.new("RGBA", (width, height), (0, 0, 0, 0))
            shape_draw = ImageDraw.Draw(shapes)
            for _ in range(rng.randint(5, 9)):
                radius = rng.randint(min(width, height) // 10, min(width, height) // 3)
                cx = rng.randint(0, width)
                cy = rng.randint(0, height)
                color = _palette(rng)[rng.randint(0, 1)]
                box = (cx - radius, cy - radius, cx + radius, cy + radius)
                if rng.random() < 0.6:
                    shape_draw.ellipse(box, fill=(*color, rng.randint(40, 110)))
                else:
                    shape_draw.rounded_rectangle(
                        box, radius=radius // 4, fill=(*color, rng.randint(40, 110))
                    )
            shapes = shapes.filter(ImageFilter.GaussianBlur(max(2, min(width, height) // 90)))
            base = Image.alpha_composite(base.convert("RGBA"), shapes).convert("RGB")

            if caption and prompt.strip():
                base = self._draw_caption(base, prompt.strip(), width, height)

            buffer = io.BytesIO()
            base.save(buffer, format="PNG")
            images.append(
                GeneratedImage(
                    data=buffer.getvalue(),
                    mime="image/png",
                    provider=self.name,
                    model=model or self.default_model,
                    prompt=prompt,
                    meta={"seed": seed[:16]},
                )
            )
        return images

    @staticmethod
    def _draw_caption(base, text: str, width: int, height: int):
        from PIL import Image, ImageDraw

        overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        draw = ImageDraw.Draw(overlay)
        font = pick_font(max(16, width // 22))
        margin = max(16, width // 24)
        lines = _wrap(text, font, width - margin * 2, draw)
        line_height = int((font.size if hasattr(font, "size") else 16) * 1.35)
        block_height = line_height * len(lines) + margin

        draw.rectangle([(0, height - block_height), (width, height)], fill=(0, 0, 0, 110))
        y = height - block_height + margin // 2
        for line in lines:
            draw.text((margin, y), line, font=font, fill=(255, 255, 255, 235))
            y += line_height
        return Image.alpha_composite(base.convert("RGBA"), overlay).convert("RGB")
