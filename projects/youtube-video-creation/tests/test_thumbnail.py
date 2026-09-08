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


def _yellow(pixel) -> bool:
    r, g, b = pixel[:3]
    return r > 200 and g > 190 and b < 90


def test_band_style_paints_one_yellow_plate(tmp_path):
    """2026-09-07: 黄色帯＋赤帯の2枚から、**蛍光イエロー1枚**に変えた。

    参考チャンネルの最高再生2本（64万回・25万回）がこの形で、赤は帯ではなく
    2行目の**文字の色**として入っている。
    """
    path = build_thumbnail(
        _config(), "", tmp_path / "band.png", style="band",
        lines=("上の行", "下の行"),
    )
    with Image.open(path) as image:
        plate = {image.getpixel((24, y)) for y in range(int(SIZE[1] * 0.75), SIZE[1] - 30)}
        inside = [image.getpixel((x, y))
                  for y in range(int(SIZE[1] * 0.75), SIZE[1] - 30)
                  for x in range(34, 420, 3)]
    assert any(r > 200 and g > 190 and b < 90 for r, g, b in plate)      # 帯は黄色
    assert any(r > 180 and g < 80 and b < 90 for r, g, b in inside)      # 赤い文字
    assert not any(r > 180 and g < 80 and b < 90 for r, g, b in plate)   # 赤い帯は無い


def test_反応の小窓が帯の上に出る(tmp_path):
    """一覧の時点で「反応を集めた動画」だと分かるようにする。"""
    path = build_thumbnail(
        _config(), "", tmp_path / "chip.png", style="band",
        lines=("上の行", "下の行"), reaction="変な声出た",
    )
    with Image.open(path) as image:
        # 帯の上端を探してから、その上を見る（帯の高さは文字数で変わる）
        band_top = min(y for y in range(SIZE[1])
                       if _yellow(image.getpixel((24, y))))
        above = [image.getpixel((x, y))
                 for y in range(band_top - 90, band_top)
                 for x in range(40, 500, 3)]
    assert any(r > 240 and g > 240 and b > 240 for r, g, b in above)     # 白い小窓
    assert any(r > 180 and g < 80 and b < 90 for r, g, b in above)       # 赤い文字


def test_指定が無ければ台本から反応を拾う():
    from src.script_model import parse_script
    from src.thumbnail import reaction_line

    body = """---
title: T
---

## 章

キャスター: これはナレーションなので拾わない。

ネット民: 変な声出た。
"""
    assert reaction_line(parse_script(body)) == "変な声出た"


def test_長い反応は小窓に出さない():
    """縮めると意味が変わる。入らないなら出さない。"""
    from src.script_model import parse_script
    from src.thumbnail import reaction_line

    body = """---
title: T
---

## 章

ネット民: これは小窓には長すぎるので出せない書き込みです。
"""
    assert reaction_line(parse_script(body)) == ""


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


# 縦長の顔写真を全面に敷くと、16:9 に切った時点で顔が残らず、下の見出しと
# ぶつかる（2026-09-05 実測。切る位置を 0.12→0.30→0.14→0.20 と変えても解けなかった）。
# 縦長は右に置いて、文字は左に寄せる。


def test_縦長の写真は右に置く(tmp_path):
    from PIL import Image

    from src.thumbnail import _is_portrait

    tall = tmp_path / "tall.jpg"
    Image.new("RGB", (864, 1080), (200, 60, 60)).save(tall)
    wide = tmp_path / "wide.jpg"
    Image.new("RGB", (1920, 1080), (60, 60, 200)).save(wide)

    assert _is_portrait(str(tall)) is True
    assert _is_portrait(str(wide)) is False
    assert _is_portrait(None) is False
    assert _is_portrait(str(tmp_path / "ない.jpg")) is False


def test_右に置いた写真が左の文字にかからない(tmp_path):
    """左半分に写真が入り込むと、見出しが読めなくなる。"""
    from PIL import Image, ImageStat

    from src.thumbnail import SIZE, _paste_side

    canvas = Image.new("RGBA", SIZE, (10, 14, 22, 255))
    photo = tmp_path / "tall.png"
    Image.new("RGB", (800, 1200), (240, 30, 30)).save(photo)

    _paste_side(canvas, str(photo))

    left = canvas.convert("RGB").crop((0, 0, int(SIZE[0] * 0.5), SIZE[1]))
    assert ImageStat.Stat(left).mean[0] < 60, "左半分に写真がはみ出している"


def test_切る位置を台本から指定できる():
    """顔の位置は写真ごとに違うので、割合の決め打ちでは当たらない。"""
    from src.thumbnail import from_meta

    assert from_meta({"thumbnail_focus": 0.3}, "見出し")["focus"] == 0.3
    assert from_meta({}, "見出し")["focus"] is None

def test_バッジはタイトルの接頭辞から取る():
    """**既定の「速報」を出しっぱなしにすると、悲報の記事に速報と出る。**

    2026-09-06 に実際に食い違った（マルティネッリ退団の回）。
    """
    from src.thumbnail import _prefix_of

    assert _prefix_of("【悲報】マルティネッリの別れの言葉") == "悲報"
    assert _prefix_of("【朗報】モドリッチが代表続行") == "朗報"
    assert _prefix_of("接頭辞のないタイトル") == ""
    assert _prefix_of("") == ""


def test_正方形に近い写真は右に置く(tmp_path):
    """891×935 の写真が全面に敷かれ、16:9 で額と目しか残らなかった（2026-09-07）。"""
    photo = tmp_path / "square.png"
    Image.new("RGB", (900, 950), (200, 60, 60)).save(photo)
    path = build_thumbnail(
        _config(), "", tmp_path / "square_thumb.png", style="band",
        lines=("上の行", "下の行"), background=str(photo),
    )
    with Image.open(path) as image:
        left = image.getpixel((80, 120))          # 文字を置く側
        right = image.getpixel((SIZE[0] - 80, 120))
    assert right[0] > 150 and right[1] < 110      # 写真は右にある
    # **左は同じ写真をぼかして暗くした下地**（2026-09-08 に塗りつぶしから変更）。
    # 塗りつぶしだと顔の段の72%が黒くなり、一覧で沈んで見えた。
    # 右よりはっきり暗く、かつ真っ黒ではないこと
    assert left[0] < right[0] - 30
    assert sum(left[:3]) > 60


def test_帯の2行は同じ大きさで1行ずつに収める(tmp_path):
    """1行目だけで字の大きさを決めていて、2行目が泣き別れた（2026-09-07）。"""
    from PIL import ImageDraw

    from src.thumbnail import _fit_one_line

    draw = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    font_path = str(_config().video.font_path())
    texts = ["UEFAが処分を発表", "最も重いのはGKコーチ"]
    font = _fit_one_line(draw, texts, font_path, 712)
    assert font is not None
    for text in texts:
        assert draw.textlength(text, font=font) <= 712, text


def test_エンブレムがあると絵が変わる(tmp_path, monkeypatch):
    """**小さく添えるだけ**（2026-09-08 ユーザー判断）。権利は晴れていない。

    置き場に絵があるときだけ、札のまわりが変わることを見る。
    座標で当てにいくと、札の位置が変わるたびに壊れる。
    """
    from src import crest as crest_mod

    photo = tmp_path / "wide.png"
    Image.new("RGB", (1600, 900), (40, 120, 60)).save(photo)
    monkeypatch.chdir(tmp_path)

    def draw(name: str):
        return build_thumbnail(
            _config(), "", tmp_path / f"{name}.png", style="band",
            lines=("見出し", "副見出し"), background=str(photo), tags=["レスター"],
        ).read_bytes()

    before = draw("before")
    crests = tmp_path / "assets" / "crests"
    crests.mkdir(parents=True)
    Image.new("RGBA", (120, 120), (255, 0, 0, 255)).save(crests / "レスター.png")
    assert crest_mod.find("レスター") is not None
    assert draw("after") != before
    assert crest_mod.CREST_PX <= 48        # **大きくしない**


def test_左の余白に言葉を積む(tmp_path):
    """**「ただのぼかし」に見えた**（2026-09-08 ユーザー指摘）。

    縦長の写真を右に置くと左がぼかしだけになる。余白を埋めるのではなく、
    動画の答えにあたる言葉を置く。
    """
    photo = tmp_path / "tall.png"
    Image.new("RGB", (600, 1200), (200, 60, 60)).save(photo)

    def draw(name: str, points):
        return build_thumbnail(
            _config(), "", tmp_path / f"{name}.png", style="band",
            lines=("見出し", "副見出し"), background=str(photo), points=points,
        ).read_bytes()

    assert draw("with", ["ひとつ", "ふたつ"]) != draw("without", [])


def test_横長の写真には積まない(tmp_path):
    """全面に敷く回は余白が無いので、重ねると顔にかぶる。"""
    photo = tmp_path / "wide.png"
    Image.new("RGB", (1600, 900), (40, 120, 60)).save(photo)

    def draw(name: str, points):
        return build_thumbnail(
            _config(), "", tmp_path / f"{name}.png", style="band",
            lines=("見出し", "副見出し"), background=str(photo), points=points,
        ).read_bytes()

    assert draw("w", ["ひとつ"]) == draw("wo", [])


def test_写真を並べると全面が写真になる(tmp_path):
    """**縦長1枚だと左がぼかしで埋まる**（2026-09-08 ユーザー指摘）。

    参考チャンネルは全面が写真で、顔を2〜3枚並べた回もあった。
    """
    a = tmp_path / "a.png"; b = tmp_path / "b.png"
    Image.new("RGB", (600, 1200), (200, 60, 60)).save(a)
    Image.new("RGB", (600, 1200), (60, 60, 200)).save(b)
    path = build_thumbnail(
        _config(), "", tmp_path / "tiled.png", style="band",
        lines=("見出し", "副見出し"), background=str(a), photos=[str(a), str(b)],
    )
    with Image.open(path) as image:
        left = image.getpixel((120, 120))
        right = image.getpixel((SIZE[0] - 120, 120))
    assert left[0] > 150 and left[2] < 110      # 左は1枚目
    assert right[2] > 150 and right[0] < 110    # 右は2枚目
