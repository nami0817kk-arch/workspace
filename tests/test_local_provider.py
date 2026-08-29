from ailab.imagegen import LocalProvider


def test_generates_png_of_requested_size():
    from PIL import Image
    import io

    images = LocalProvider().generate("テスト用の画像", size="320x180")
    assert len(images) == 1
    assert images[0].data[:8] == b"\x89PNG\r\n\x1a\n"
    assert Image.open(io.BytesIO(images[0].data)).size == (320, 180)


def test_same_prompt_gives_same_image():
    first = LocalProvider().generate("同じ入力", size="128x128")[0].data
    second = LocalProvider().generate("同じ入力", size="128x128")[0].data
    assert first == second


def test_different_prompt_gives_different_image():
    first = LocalProvider().generate("入力A", size="128x128")[0].data
    second = LocalProvider().generate("入力B", size="128x128")[0].data
    assert first != second


def test_generates_multiple_distinct_images():
    images = LocalProvider().generate("複数枚", size="128x128", n=3)
    assert len({image.data for image in images}) == 3


def test_local_provider_is_always_available():
    assert LocalProvider().is_available()


def test_save_writes_file(tmp_path):
    image = LocalProvider().generate("保存テスト", size="64x64")[0]
    path = image.save(tmp_path)
    assert path.exists() and path.suffix == ".png"
    assert path.read_bytes() == image.data
