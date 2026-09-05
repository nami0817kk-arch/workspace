import pytest
from PIL import Image

from src.backgrounds import VARIANTS, generate

SIZE = (640, 360)


@pytest.mark.parametrize("variant", VARIANTS)
def test_each_variant_renders(tmp_path, variant):
    path = generate(tmp_path / f"{variant}.png", SIZE, variant)
    with Image.open(path) as image:
        assert image.size == SIZE
        assert image.mode == "RGB"


def test_unknown_variant_is_rejected(tmp_path):
    with pytest.raises(ValueError, match="背景の種類"):
        generate(tmp_path / "x.png", SIZE, "ばくだん")


def test_pitch_is_green_and_bottom_is_dark(tmp_path):
    """芝は緑で、テロップを載せる下側は文字が読める程度に暗い。"""
    path = generate(tmp_path / "stadium.png", SIZE, "stadium")
    with Image.open(path) as image:
        middle = image.getpixel((SIZE[0] // 2, int(SIZE[1] * 0.62)))
        bottom = image.getpixel((SIZE[0] // 2, SIZE[1] - 6))
    assert middle[1] > middle[0] and middle[1] > middle[2]  # 緑が優勢
    assert sum(bottom) < sum(middle)                        # 下ほど暗い


# 背景に模様が無いと、寄っていても動いて見えない（2026-09-05 実測）。
# night は ばらつき7.3 で、stadium(22.4) の3分の1しかなかった。


def test_どの背景にも寄りが分かるだけの模様がある(tmp_path):
    from PIL import Image, ImageStat

    from src.backgrounds import VARIANTS, generate

    for variant in VARIANTS:
        path = generate(tmp_path / f"{variant}.png", (960, 540), variant)
        spread = ImageStat.Stat(Image.open(path).convert("L")).stddev[0]
        assert spread >= 12.0, f"{variant} のばらつきが {spread:.1f} しかない"
