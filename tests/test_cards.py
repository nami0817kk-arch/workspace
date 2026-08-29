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
