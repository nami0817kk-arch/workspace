"""生成画像の後処理（縮小・形式変換）。"""

import io

import pytest
from PIL import Image

from imagegen import imaging
from imagegen.core.errors import ConfigError
from imagegen.core.types import GeneratedImage


def make_image(size=(800, 400), mode="RGB", fmt="PNG") -> GeneratedImage:
    buffer = io.BytesIO()
    Image.new(mode, size, (120, 80, 200)).save(buffer, format=fmt)
    mime = {"PNG": "image/png", "JPEG": "image/jpeg", "WEBP": "image/webp"}[fmt]
    return GeneratedImage(data=buffer.getvalue(), mime=mime, provider="local", model="m", prompt="p")


def opened(image: GeneratedImage) -> Image.Image:
    return Image.open(io.BytesIO(image.data))


def test_no_options_returns_the_same_object():
    original = make_image()
    assert imaging.convert(original) is original


def test_resize_keeps_the_aspect_ratio():
    converted = imaging.convert(make_image((800, 400)), max_width=200)
    assert opened(converted).size == (200, 100)


def test_smaller_images_are_left_alone():
    original = make_image((100, 50))
    assert imaging.convert(original, max_width=400) is original


def test_format_conversion_updates_the_mime_type():
    converted = imaging.convert(make_image(), fmt="webp")
    assert converted.mime == "image/webp"
    assert converted.ext == ".webp"
    assert opened(converted).format == "WEBP"


def test_transparent_image_becomes_jpeg_on_white():
    converted = imaging.convert(make_image(mode="RGBA"), fmt="jpg")
    assert opened(converted).mode == "RGB"
    assert converted.mime == "image/jpeg"


def test_metadata_is_carried_over():
    converted = imaging.convert(make_image(), fmt="webp")
    assert (converted.provider, converted.model, converted.prompt) == ("local", "m", "p")
    assert converted.meta["converted"] is True


def test_unknown_format_is_rejected():
    with pytest.raises(ConfigError, match="対応していない形式"):
        imaging.convert(make_image(), fmt="tiff")


def test_undecodable_data_is_reported():
    broken = GeneratedImage(data=b"<svg></svg>", mime="image/svg+xml")
    with pytest.raises(ConfigError, match="変換できません"):
        imaging.convert(broken, max_width=100)


def test_generate_applies_the_conversion(tmp_path, monkeypatch):
    from imagegen import generation

    monkeypatch.setenv("IMAGEGEN_OUTPUT_DIR", str(tmp_path))
    images = generation.generate(
        "変換テスト", provider="local", size="800x400", fmt="webp", max_width=200
    )
    assert opened(images[0]).size == (200, 100)
    assert images[0].mime == "image/webp"
