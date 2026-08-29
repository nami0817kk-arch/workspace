import pytest

from ailab.utils import parse_size, slugify


def test_slugify_removes_path_unsafe_characters():
    assert slugify('a/b:c*d?e"f<g>h|i j') == "a_b_c_d_e_f_g_h_i_j"


def test_slugify_keeps_japanese_and_truncates():
    assert slugify("猫のイラスト") == "猫のイラスト"
    assert len(slugify("あ" * 100, max_length=10)) == 10


def test_slugify_falls_back_when_empty():
    assert slugify("   ") == "image"


@pytest.mark.parametrize(
    ("text", "expected"), [("1024x1024", (1024, 1024)), (" 800 × 450 ", (800, 450))]
)
def test_parse_size(text, expected):
    assert parse_size(text) == expected


def test_parse_size_rejects_invalid():
    with pytest.raises(ValueError):
        parse_size("おおきめ")
