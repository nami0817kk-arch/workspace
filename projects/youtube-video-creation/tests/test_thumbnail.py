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


def _news(tmp_path, **kwargs):
    from src.config import load_config
    from src.thumbnail import build_thumbnail

    options = {
        "lines": ("見出し", "副見出し"),
        "tags": ["キーワード"],
        "badge": "速報",
        "date": "2026年8月30日",
    }
    options.update(kwargs)
    return build_thumbnail(
        load_config(), options["lines"][0], tmp_path / "t.png", style="news", **options
    )


def test_the_news_style_renders_for_every_combination(tmp_path):
    from PIL import Image

    # 日付・タグ・副見出しは無いことがある。どれが欠けても落ちない
    for options in (
        {},
        {"date": "", "tags": [], "badge": ""},
        {"lines": ("見出しだけ", "")},
        {"lines": ("とても長い見出しを入れたときに2行へ折り返されることの確認", "副見出しも長めに書いてみる")},
    ):
        path = _news(tmp_path, **options)
        assert Image.open(path).size == (1280, 720)


def test_the_date_is_reformatted_for_the_news_flag():
    from src.thumbnail import _news_date

    assert _news_date("2026年8月30日") == "2026.08.30"
    assert _news_date("2026年12月5日") == "2026.12.05"
    assert _news_date("") == ""
    assert _news_date("移籍期限直前") == "移籍期限直前"   # 数字が無ければそのまま


def test_news_headlines_never_overflow_their_plate():
    from PIL import Image, ImageDraw

    from src.config import load_config
    from src.thumbnail import MARGIN, NEWS_BAR, NEWS_HEAD_SIZES, SIZE, _fit_news

    config = load_config()
    font_path = str(config.video.font_path())
    draw = ImageDraw.Draw(Image.new("RGBA", SIZE))

    for text in ("アルバレスに決断の期限", "とても長い見出しを入れたときにどう折り返されるかの確認です", "短い"):
        font, rows = _fit_news(draw, text, font_path, NEWS_HEAD_SIZES)
        for row in rows:
            right = MARGIN + 6 + NEWS_BAR + draw.textlength(row, font=font)
            assert right <= SIZE[0] - MARGIN + 40, f"はみ出し: {text} / {row}"


def test_a_script_without_alternatives_gives_one_option():
    from src.thumbnail import variants

    (only,) = variants({"thumbnail_line1": "見出し", "thumbnail_line2": "そえ書き"}, "T")
    assert only["name"] == "案1"
    assert only["lines"] == ("見出し", "そえ書き")


def test_alternatives_become_extra_options():
    from src.thumbnail import variants

    meta = {
        "thumbnail_line1": "本命",
        "thumbnail_line2": "そえ書き",
        "thumbnail_tags": ["タグA"],
        "thumbnail_badge": "速報",
        "thumbnail_alt": [
            {"line1": "別案", "line2": "別のそえ書き"},
            {"line1": "3案目", "badge": "詳報"},
        ],
    }
    options = variants(meta, "T")
    assert [o["name"] for o in options] == ["案1", "案2", "案3"]
    assert options[1]["lines"] == ("別案", "別のそえ書き")
    # 書かなかったところは1案目を引き継ぐ
    assert options[2]["lines"][1] == "そえ書き"
    assert options[2]["badge"] == "詳報"
    assert options[1]["tags"] == ["タグA"]


def test_options_are_stacked_into_one_sheet(tmp_path):
    from PIL import Image

    from src.thumbnail import SIZE, contact_sheet

    paths = []
    for index in range(3):
        path = tmp_path / f"t{index}.png"
        Image.new("RGB", SIZE, (0, 0, 0)).save(path)
        paths.append(path)

    sheet = Image.open(contact_sheet(paths, tmp_path / "sheet.png"))
    assert sheet.width == SIZE[0]
    assert sheet.height == SIZE[1] * 3 + 16 * 2      # 案のあいだに隙間が入る


# 参考3チャンネルはどれも人の顔を全面に出している。文字だけのサムネは
# 一覧で埋もれる（2026-09-05 実測）。台本に thumbnail_photo と書けば敷ける。


def test_サムネの下地に写真を指定できる():
    from src.thumbnail import from_meta

    look = from_meta({"thumbnail_photo": "assets/images/endo/08.jpg"}, "見出し")
    assert look["photo"] == "assets/images/endo/08.jpg"

    assert from_meta({}, "見出し")["photo"] == ""


def test_縦長の写真は上寄りに切る():
    """人物写真は顔が上にある。真ん中で切ると胴体だけが残る。"""
    from PIL import Image

    from src.render import _cover

    # 上半分を白、下半分を黒にした縦長の画像
    tall = Image.new("RGB", (400, 1000), (0, 0, 0))
    tall.paste(Image.new("RGB", (400, 500), (255, 255, 255)), (0, 0))

    cut = _cover(tall, 1280, 720)
    top_half = cut.crop((0, 0, 1280, 360)).convert("L")
    assert min(top_half.getdata()) > 200      # 上は白のまま＝顔の側が残っている


def test_横長の写真は真ん中で切る():
    from PIL import Image

    from src.render import _cover

    wide = Image.new("RGB", (2000, 800), (120, 120, 120))
    assert _cover(wide, 1280, 720).size == (1280, 720)
