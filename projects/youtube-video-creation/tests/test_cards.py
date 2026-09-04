import pytest
from PIL import Image

from src.cards import CardError, card_key, render
from src.config import load_config

WIDTH = 900


@pytest.fixture(scope="module")
def fonts():
    video = load_config().video
    return str(video.font_path()), str(video.latin_font_path())


def test_quote_card_renders_with_alpha(tmp_path, fonts):
    font, latin = fonts
    path = render(
        {"type": "quote", "source": "Sky Sports", "text": "Atletico set a deadline"},
        WIDTH, font, tmp_path / "q.png", latin,
    )
    with Image.open(path) as image:
        assert image.mode == "RGBA"
        assert image.width == WIDTH
        assert image.getpixel((2, 2))[3] == 0  # 角は透過している


def test_translation_makes_the_card_taller(tmp_path, fonts):
    font, latin = fonts
    spec = {"type": "quote", "source": "ESPN", "text": "Arsenal ready if door opens"}
    with Image.open(render(spec, WIDTH, font, tmp_path / "a.png", latin)) as plain:
        short = plain.height
    spec = {**spec, "translation": "扉が開けばアーセナルは動く用意がある"}
    with Image.open(render(spec, WIDTH, font, tmp_path / "b.png", latin)) as translated:
        assert translated.height > short


def test_transfer_card_renders(tmp_path, fonts):
    font, latin = fonts
    path = render(
        {"type": "transfer", "player": "選手名", "from": "クラブA", "to": "クラブB", "fee": "1億"},
        WIDTH, font, tmp_path / "t.png", latin,
    )
    assert path.exists()


def test_points_card_renders(tmp_path, fonts):
    font, latin = fonts
    path = render(
        {"type": "points", "title": "整理", "items": ["ひとつめ", "ふたつめ"]},
        WIDTH, font, tmp_path / "p.png", latin,
    )
    assert path.exists()


def test_unknown_type_is_rejected(tmp_path, fonts):
    font, latin = fonts
    with pytest.raises(CardError, match="type"):
        render({"type": "ばくだん", "text": "x"}, WIDTH, font, tmp_path / "x.png", latin)


def test_required_fields_are_checked(tmp_path, fonts):
    font, latin = fonts
    with pytest.raises(CardError, match="text"):
        render({"type": "quote"}, WIDTH, font, tmp_path / "x.png", latin)
    with pytest.raises(CardError, match="player"):
        render({"type": "transfer", "from": "A", "to": "B"}, WIDTH, font, tmp_path / "y.png", latin)
    with pytest.raises(CardError, match="items"):
        render({"type": "points", "title": "t"}, WIDTH, font, tmp_path / "z.png", latin)


def test_card_key_changes_with_content_and_width():
    base = {"type": "quote", "text": "a"}
    assert card_key(base, 900) == card_key({"type": "quote", "text": "a"}, 900)
    assert card_key(base, 900) != card_key({"type": "quote", "text": "b"}, 900)
    assert card_key(base, 900) != card_key(base, 800)


def test_bars_card_renders(tmp_path, fonts):
    font, latin = fonts
    path = render(
        {
            "type": "bars",
            "title": "比較",
            "unit": "点",
            "items": [{"label": "A", "value": 14, "highlight": True}, {"label": "B", "value": 7}],
            "note": "※出典",
        },
        WIDTH, font, tmp_path / "bars.png", latin,
    )
    assert path.exists()


def test_bars_needs_label_and_value(tmp_path, fonts):
    font, latin = fonts
    with pytest.raises(CardError, match="items"):
        render({"type": "bars", "title": "x"}, WIDTH, font, tmp_path / "a.png", latin)
    with pytest.raises(CardError, match="label"):
        render(
            {"type": "bars", "items": [{"label": "A"}]}, WIDTH, font, tmp_path / "b.png", latin
        )


def test_bars_survives_a_zero_maximum(tmp_path, fonts):
    """全部ゼロでも割り算で落ちない。"""
    font, latin = fonts
    path = render(
        {"type": "bars", "items": [{"label": "A", "value": 0}, {"label": "B", "value": 0}]},
        WIDTH, font, tmp_path / "zero.png", latin,
    )
    assert path.exists()


def test_table_card_renders(tmp_path, fonts):
    font, latin = fonts
    path = render(
        {
            "type": "table",
            "title": "順位",
            "columns": ["順位", "クラブ", "勝点"],
            "rows": [["1", "A", "12"], ["2", "B", "10"]],
            "highlight_row": 0,
        },
        WIDTH, font, tmp_path / "table.png", latin,
    )
    assert path.exists()


def test_table_rejects_mismatched_row_length(tmp_path, fonts):
    font, latin = fonts
    with pytest.raises(CardError, match="columns と同じ数"):
        render(
            {"type": "table", "columns": ["a", "b"], "rows": [["1"]]},
            WIDTH, font, tmp_path / "bad.png", latin,
        )


def test_reactions_card_renders(tmp_path, fonts):
    font, latin = fonts
    path = render(
        {
            "type": "reactions",
            "title": "この移籍への反応",
            "items": [{"text": "短い反応", "label": "X"}, {"text": "もうひとつ"}],
            "note": "※公開されている投稿から引用",
        },
        WIDTH, font, tmp_path / "react.png", latin,
    )
    assert path.exists()


def test_reactions_needs_text(tmp_path, fonts):
    font, latin = fonts
    with pytest.raises(CardError, match="items"):
        render({"type": "reactions", "title": "x"}, WIDTH, font, tmp_path / "a.png", latin)
    with pytest.raises(CardError, match="text"):
        render(
            {"type": "reactions", "items": [{"label": "X"}]},
            WIDTH, font, tmp_path / "b.png", latin,
        )


def test_reactions_accepts_plain_strings(tmp_path, fonts):
    font, latin = fonts
    path = render(
        {"type": "reactions", "items": ["ひとこと", "ふたこと"]},
        WIDTH, font, tmp_path / "plain.png", latin,
    )
    assert path.exists()


def _render_score(tmp_path, **overrides):
    from src.cards import render
    from src.config import load_config

    config = load_config()
    spec = {"type": "score", "home": "アーセナル", "away": "リバプール", "score": "2 - 1"}
    spec.update(overrides)
    return render(
        spec, 980, str(config.video.font_path()), tmp_path / "s.png",
        str(config.video.latin_font_path()),
    )


def test_a_score_card_renders_with_and_without_the_extras(tmp_path):
    from PIL import Image

    for extras in (
        {},
        {"competition": "プレミアリーグ 第3節"},
        {"home_scorers": ["45' サカ", "78' ハヴァーツ"], "away_scorers": ["67' サラー"]},
        {"note": "エミレーツ・スタジアム", "color": "#e2495a"},
    ):
        path = _render_score(tmp_path, **extras)
        assert Image.open(path).width == 980


def test_a_score_card_needs_both_teams_and_a_score(tmp_path):
    import pytest

    from src.cards import CardError

    for missing in ({"home": ""}, {"away": ""}, {"score": ""}):
        with pytest.raises(CardError, match="score カード"):
            _render_score(tmp_path, **missing)


def test_long_team_names_are_shortened_rather_than_overflowing():
    from PIL import Image, ImageDraw, ImageFont

    from src.cards import _shorten
    from src.config import load_config

    font = ImageFont.truetype(str(load_config().video.font_path()), 22)
    ruler = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    long_name = "ボルシア・メンヒェングラートバッハ"

    result = _shorten(ruler, long_name, font, 200)
    assert result.endswith("…")
    assert ruler.textlength(result, font=font) <= 200
    # 収まる名前はそのまま
    assert _shorten(ruler, "浦和", font, 200) == "浦和"


def test_score_is_a_known_card_type():
    from src.cards import CARD_TYPES

    assert "score" in CARD_TYPES


def test_a_dark_club_colour_is_swapped_for_a_readable_one():
    from src.cards import MIN_CONTRAST, PANEL, _contrast, _hex, readable

    # トッテナムの濃紺。スコアの数字がパネルに沈んで読めなくなっていた
    navy = _hex("#132257")
    assert _contrast(navy, PANEL[:3]) < MIN_CONTRAST
    assert _contrast(readable(navy), PANEL[:3]) >= MIN_CONTRAST


def test_a_colour_that_already_reads_is_left_alone():
    from src.cards import _hex, readable

    red = _hex("#e2495a")
    assert readable(red) == red


def test_カードの折り返しも熟語を割らない():
    """カード内は文字幅だけで切っていたので、禁則も熟語の判定も効いていなかった。

    実測（2026-09-04）で、写真と横に並べてカードを細くしたとたん
    「2シーズン以上いることが必\n要」と割れた。折り返しの規則は
    render 側に1つだけ置き、カードもそれを使う。
    """
    from PIL import ImageFont

    from src.cards import _wrap
    from src.config import load_config

    font = ImageFont.truetype(str(load_config().video.font_path()), 40)
    lines = _wrap("使うにはクラブに2シーズン以上いることが必要", font, 760)

    def kanji(c):
        return "\u4e00" <= c <= "\u9fff"

    assert not any(
        kanji(a[-1]) and kanji(b[0]) for a, b in zip(lines, lines[1:]) if a and b
    )


def test_kitカードは背番号が無くても描ける(tmp_path):
    """背番号は調べがついたときだけ出す。**確かめていない数字は出さない。**"""
    from src.cards import render
    from src.config import load_config

    cfg = load_config()
    out = tmp_path / "kit.png"
    render({"type": "kit", "title": "登録メンバー",
            "items": [{"player": "遠藤 航", "short": "ENDO", "colors": ["#C8102E"], "mark": "×"},
                      {"player": "エキティケ", "short": "EKITIKE", "colors": ["#C8102E"], "mark": "○"}]},
           1000, str(cfg.video.font_path()), out, str(cfg.video.latin_font_path()))

    assert out.exists() and out.stat().st_size > 0


def test_kitカードにitemsが無ければ弾く(tmp_path):
    import pytest

    from src.cards import CardError, render
    from src.config import load_config

    cfg = load_config()
    with pytest.raises(CardError):
        render({"type": "kit", "title": "登録"}, 1000,
               str(cfg.video.font_path()), tmp_path / "x.png",
               str(cfg.video.latin_font_path()))
