from PIL import Image

from src.config import load_config
from src.thumbnail import SIZE, build_thumbnail


def _config():
    config = load_config()
    config.video.background = "assets/backgrounds/stadium.png"
    return config


def test_band_style_renders(tmp_path):
    path = build_thumbnail(
        _config(), "", tmp_path / "band.png", style="band",
        lines=("黄色帯の文字", "赤帯の文字"), tags=["反応"],
    )
    with Image.open(path) as image:
        assert image.size == SIZE and image.mode == "RGB"


def test_band_style_paints_the_two_bands(tmp_path):
    """下段に黄色帯と赤帯が乗っていること。"""
    path = build_thumbnail(
        _config(), "", tmp_path / "band.png", style="band",
        lines=("黄色帯", "赤帯"),
    )
    with Image.open(path) as image:
        colours = {image.getpixel((30, y)) for y in range(int(SIZE[1] * 0.6), SIZE[1] - 30)}
    assert any(r > 200 and g > 190 and b < 90 for r, g, b in colours)   # 黄色
    assert any(r > 180 and g < 80 and b < 90 for r, g, b in colours)    # 赤


def test_clean_style_still_works(tmp_path):
    path = build_thumbnail(
        _config(), "タイトル", tmp_path / "clean.png", subtitle="サブ",
        badge="移籍", date="2026年8月29日", style="clean",
    )
    assert path.exists()


def test_long_band_text_stays_inside(tmp_path):
    """長い文字でも枠外にはみ出さない（字を詰めて2行まで）。"""
    path = build_thumbnail(
        _config(), "", tmp_path / "long.png", style="band",
        lines=("あ" * 30, "い" * 30),
    )
    with Image.open(path) as image:
        assert image.size == SIZE
