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


def test_meta_is_read_the_same_way_by_build_and_the_thumbnail_command():
    from src.thumbnail import from_meta

    # draft が書く新しい形
    new = from_meta(
        {
            "thumbnail_line1": "アトレティコが期限提示",
            "thumbnail_line2": "バルサ移籍は絶望的",
            "thumbnail_tags": ["そこまでやる？", "アーセナル待機中"],
            "date": "2026年8月30日",
        },
        "タイトル",
    )
    assert new["lines"] == ("アトレティコが期限提示", "バルサ移籍は絶望的")
    assert new["tags"] == ["そこまでやる？", "アーセナル待機中"]
    assert new["date"] == "2026年8月30日"

    # 手書きの古い形も読める
    old = from_meta(
        {"thumbnail_title": "見出し", "thumbnail_subtitle": "そえ書き", "thumbnail_badge": "移籍"},
        "タイトル",
    )
    assert old["lines"] == ("見出し", "そえ書き")
    assert old["badge"] == "移籍"
    assert old["tags"] == []


def test_the_title_is_used_when_no_thumbnail_line_is_given():
    from src.thumbnail import from_meta

    assert from_meta({}, "【速報】タイトル")["lines"] == ("【速報】タイトル", "")


def test_band_text_never_overflows_the_band():
    from PIL import Image, ImageDraw

    from src.config import load_config
    from src.thumbnail import SIZE, _fit_band

    config = load_config()
    font_path = str(config.video.font_path())
    draw = ImageDraw.Draw(Image.new("RGBA", SIZE))

    # 禁則で改行できず、1行のまま帯からはみ出していた文字列を含む
    for text in (
        "バルサ移籍は絶望的ｷﾀｰ！！",
        "アトレティコが期限提示",
        "非常に長い見出しを入れてみたときにどう折り返されるかの確認です",
        "短い",
    ):
        font, rows = _fit_band(draw, text, font_path)
        for row in rows:
            right = 34 + draw.textlength(row, font=font)
            assert right <= SIZE[0] - 16, f"はみ出し: {text} / {row}"
