"""文字入り画像の合成（compose）とフォントの収め方（fonts）。"""

import io
import json

import pytest
from PIL import Image, ImageStat

from imagegen import cli, compose, fonts, mcp_server, recipes
from imagegen.core.errors import ConfigError


def open_image(image):
    return Image.open(io.BytesIO(image.data))


def brightness(image) -> float:
    return ImageStat.Stat(open_image(image).convert("L")).mean[0]


@pytest.fixture
def photo(tmp_path):
    """背景に敷く写真の代わり（縦横比がわざと出力と違う）。"""
    path = tmp_path / "bg.png"
    Image.new("RGB", (100, 50), (200, 30, 30)).save(path)
    return path


@pytest.fixture
def logo(tmp_path):
    path = tmp_path / "logo.png"
    Image.new("RGBA", (40, 40), (0, 255, 0, 255)).save(path)
    return path


# --- サイズ -----------------------------------------------------------
def test_preset_sizes():
    assert compose.resolve_size(preset="youtube") == (1280, 720)
    assert compose.resolve_size(preset="shorts") == (1080, 1920)


def test_size_overrides_the_preset():
    assert compose.resolve_size("800x400", preset="ogp") == (800, 400)


def test_unknown_preset_lists_the_choices():
    with pytest.raises(ConfigError, match="youtube"):
        compose.resolve_size(preset="tiktok")


def test_output_matches_the_preset():
    image = compose.compose(title="見出し", preset="ogp")
    assert open_image(image).size == (1200, 630)
    assert image.meta["size"] == "1200x630"


# --- 色 ---------------------------------------------------------------
def test_parse_color_accepts_hex_and_names():
    assert compose.parse_color("#ff0000") == (255, 0, 0)
    assert compose.parse_color("white") == (255, 255, 255)


def test_parse_color_rejects_garbage():
    with pytest.raises(ConfigError, match="色の指定"):
        compose.parse_color("まっか")


# --- 背景 -------------------------------------------------------------
def test_background_fills_the_frame(photo):
    """縦横比が違っても余白（黒帯）を作らず、はみ出しは中央で切る。"""
    image = compose.compose(background=photo, preset="youtube")
    pixels = open_image(image)
    for point in ((5, 5), (1275, 5), (5, 715), (1275, 715)):
        red, green, blue = pixels.getpixel(point)
        assert red > 150 and green < 80 and blue < 80


def test_background_can_be_bytes(photo):
    image = compose.compose(background=photo.read_bytes(), size="200x100")
    assert open_image(image).size == (200, 100)


def test_missing_background_is_reported(tmp_path):
    with pytest.raises(ConfigError, match="背景の画像がありません"):
        compose.compose(title="あ", background=tmp_path / "nope.png")


def test_broken_background_is_reported(tmp_path):
    path = tmp_path / "broken.png"
    path.write_bytes(b"not an image")
    with pytest.raises(ConfigError, match="開けませんでした"):
        compose.compose(title="あ", background=path)


def test_dim_darkens_the_background(photo):
    plain = compose.compose(background=photo, size="200x100")
    dimmed = compose.compose(background=photo, size="200x100", dim=0.6)
    assert brightness(dimmed) < brightness(plain)


def test_blur_keeps_the_size(photo):
    image = compose.compose(background=photo, size="200x100", blur=4)
    assert open_image(image).size == (200, 100)


# --- 文字 -------------------------------------------------------------
def test_title_changes_the_picture():
    plain = compose.compose(color="#000000", size="400x200")
    titled = compose.compose(title="見出し", color="#000000", size="400x200")
    assert titled.data != plain.data
    assert brightness(titled) > brightness(plain)  # 白い文字が載る


def test_band_darkens_behind_the_text():
    without = compose.compose(title="見出し", color="#ffffff", size="400x200")
    with_band = compose.compose(title="見出し", color="#ffffff", size="400x200", band=True)
    assert brightness(with_band) < brightness(without)


def test_band_reaches_the_edge_at_the_bottom():
    """下寄せの帯が途中で切れると、下に背景が細く残って「ずれ」に見える。"""
    image = compose.compose(
        title="見出し", color="#ffffff", size="400x200", band=True, band_alpha=255
    )
    assert open_image(image).getpixel((200, 199)) == (0, 0, 0)


def test_subtitle_is_drawn_too():
    only_title = compose.compose(title="見出し", size="600x300")
    with_subtitle = compose.compose(title="見出し", subtitle="補足の説明", size="600x300")
    assert with_subtitle.data != only_title.data


def test_positions_move_the_text():
    top = compose.compose(title="見出し", size="400x200", position="top")
    bottom = compose.compose(title="見出し", size="400x200", position="bottom")
    assert top.data != bottom.data


def test_alignments_move_the_text():
    left = compose.compose(title="見出し", size="600x200", align="left")
    right = compose.compose(title="見出し", size="600x200", align="right")
    assert left.data != right.data


def test_rejects_an_unknown_position():
    with pytest.raises(ConfigError, match="position"):
        compose.compose(title="あ", position="middle")


def test_rejects_an_unknown_align():
    with pytest.raises(ConfigError, match="align"):
        compose.compose(title="あ", align="justify")


def test_without_any_text_it_still_makes_a_picture():
    image = compose.compose(color="#123456", size="120x60")
    assert open_image(image).size == (120, 60)


def test_the_same_input_makes_the_same_picture():
    """乱数を使わない。素材として作り直せることが大事。"""
    first = compose.compose(title="同じ見出し", subtitle="同じ補足", size="400x200")
    second = compose.compose(title="同じ見出し", subtitle="同じ補足", size="400x200")
    assert first.data == second.data


# --- 形式 -------------------------------------------------------------
def test_jpeg_output():
    image = compose.compose(title="見出し", size="200x100", fmt="jpg")
    assert image.mime == "image/jpeg"
    assert image.ext == ".jpg"


def test_rejects_an_unknown_format():
    with pytest.raises(ConfigError, match="対応していない形式"):
        compose.compose(title="あ", fmt="tiff")


# --- ロゴ -------------------------------------------------------------
def test_logo_is_pasted_in_the_corner(logo):
    image = compose.compose(color="#000000", size="400x200", logo=logo, logo_scale=0.25)
    pixels = open_image(image)
    # 幅の25% = 100px 四方が右下（余白24px）に載る
    red, green, blue = pixels.getpixel((326, 126))
    assert green > 200 and red < 80 and blue < 80


def test_logo_corner_can_be_chosen(logo):
    image = compose.compose(
        color="#000000", size="400x200", logo=logo, logo_scale=0.25, logo_position="top_left"
    )
    assert open_image(image).getpixel((30, 30))[1] > 200


def test_missing_logo_is_reported(tmp_path):
    with pytest.raises(ConfigError, match="ロゴの画像がありません"):
        compose.compose(title="あ", logo=tmp_path / "nope.png")


def test_unknown_logo_corner_is_reported(logo):
    with pytest.raises(ConfigError, match="ロゴの位置"):
        compose.compose(title="あ", logo=logo, logo_position="middle")


# --- fonts ------------------------------------------------------------
def test_wrap_breaks_japanese_by_character():
    font = fonts.pick_font(20)
    lines = fonts.wrap_text("あいうえおかきくけこさしすせそ", font, 60)
    assert len(lines) > 1
    assert "".join(lines) == "あいうえおかきくけこさしすせそ"


def test_wrap_keeps_explicit_newlines():
    font = fonts.pick_font(20)
    assert fonts.wrap_text("上の行\n下の行", font, 10_000) == ["上の行", "下の行"]


def test_fit_shrinks_until_it_fits():
    """長い見出しでも、行数と高さの両方が収まるまで小さくする。"""
    long_font, long_lines, _height = fonts.fit(
        "とても長い見出しをわざと入れて折り返しと縮小が効くかを確かめるための文章です",
        max_width=400,
        max_height=150,
        start_size=80,
    )
    short_font, _lines, _h = fonts.fit("短い", max_width=400, max_height=150, start_size=80)
    assert len(long_lines) <= 3
    assert long_font.size < short_font.size


def test_fit_stops_at_the_minimum_size():
    """入りきらなくても止まる（縮め続けて固まらない）。"""
    font, lines, _height = fonts.fit(
        "あ" * 400, max_width=40, max_height=20, start_size=40, min_size=10
    )
    assert font.size == 10
    assert len(lines) <= 3


def test_measure_returns_a_positive_box():
    width, height = fonts.measure("あ", fonts.pick_font(30))
    assert width > 0 and height > 0


# --- CLI / MCP / レシピ ------------------------------------------------
def test_cli_compose_writes_a_file(tmp_path, capsys):
    assert cli.main(
        ["compose", "--title", "見出し", "--preset", "ogp", "-o", str(tmp_path), "--name", "ogp"]
    ) == 0
    assert (tmp_path / "ogp.png").is_file()
    assert "1200x630" in capsys.readouterr().out


def test_cli_compose_needs_some_text(capsys):
    assert cli.main(["compose"]) == 1
    assert "--title" in capsys.readouterr().err


def test_mcp_compose_image(tmp_path):
    result = mcp_server.handle(
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "compose_image",
                "arguments": {"title": "見出し", "size": "300x150", "out": str(tmp_path)},
            },
        }
    )["result"]
    assert not result["isError"]
    assert "300x150" in result["content"][0]["text"]
    assert len(list(tmp_path.glob("*.png"))) == 1


def test_mcp_tool_list_includes_compose():
    assert "compose_image" in {tool["name"] for tool in mcp_server.tool_definitions()}


def test_recipe_compose_step(tmp_path):
    recipe = {
        "steps": [
            {
                "id": "thumb",
                "compose": {
                    "title": "今日の値上がり",
                    "preset": "ogp",
                    "out": str(tmp_path),
                    "filename": "thumb",
                },
            }
        ]
    }
    result = recipes.run(recipe)
    item = result.steps[0].items[0]
    assert item["path"].endswith("thumb.png")
    assert item["size"] == "1200x630"


def test_recipe_compose_can_use_a_previous_step(tmp_path, monkeypatch):
    """集めた見出しをそのままサムネイルにする（feed → compose）。"""
    from imagegen.core.types import FeedItem

    monkeypatch.setattr(
        "imagegen.connectors.feed_rss.RssFeed.fetch_items",
        lambda self, query, limit=10: [FeedItem(source="rss", title="移籍が決まりました")],
    )
    recipe = {
        "steps": [
            {"id": "news", "feed": {"source": "rss", "query": "https://example.com/feed"}},
            {"compose": {"title": "{{ news.0.title }}", "out": str(tmp_path), "filename": "n"}},
        ]
    }
    result = recipes.run(recipe)
    assert (tmp_path / "n.png").is_file()
    assert result.files() == [str(tmp_path / "n.png")]


def test_recipe_compose_needs_text(tmp_path):
    with pytest.raises(ConfigError, match="title か subtitle"):
        recipes.run({"steps": [{"compose": {"out": str(tmp_path)}}]})


def test_cli_compose_json_free_of_secrets(tmp_path):
    """出力に秘密が混ざらないこと（compose は外部と通信しない）。"""
    assert json.dumps(compose.PRESETS)
