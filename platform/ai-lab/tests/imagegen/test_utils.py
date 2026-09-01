import pytest

from imagegen.utils import parse_size, slugify


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


@pytest.mark.parametrize(
    ("mime", "expected"),
    [
        ("image/png", ".png"),
        ("image/jpeg", ".jpg"),
        ("image/webp", ".webp"),
        ("image/svg+xml", ".svg"),
        ("image/webp; charset=binary", ".webp"),
        ("IMAGE/PNG", ".png"),
    ],
)
def test_extension_for_is_os_independent(mime, expected):
    """mimetypes は OS 設定に左右されるので自前の表を使う（Windows で webp が引けなかった）。"""
    from imagegen.utils import extension_for

    assert extension_for(mime) == expected


def test_extension_for_unknown_type_uses_the_default():
    from imagegen.utils import extension_for

    assert extension_for("application/octet-stream", default=".bin") == ".bin"
    assert extension_for("") == ".png"


class _FakeStream:
    """reconfigure を記録するだけの標準出力もどき。"""

    def __init__(self, encoding, fails=False):
        self.encoding = encoding
        self.fails = fails
        self.reconfigured = None

    def reconfigure(self, **kwargs):
        if self.fails:
            raise OSError("付け替えられない")
        self.reconfigured = kwargs


def test_streams_are_switched_to_utf8():
    """Windows の cp932 コンソールで日本語を出すと落ちるため。"""
    from imagegen.utils import ensure_utf8_streams

    stream = _FakeStream("cp932")
    ensure_utf8_streams([stream])
    assert stream.reconfigured == {"encoding": "utf-8", "errors": "replace"}


def test_utf8_streams_are_left_alone():
    from imagegen.utils import ensure_utf8_streams

    for encoding in ("utf-8", "UTF8"):
        stream = _FakeStream(encoding)
        ensure_utf8_streams([stream])
        assert stream.reconfigured is None


def test_streams_without_reconfigure_are_skipped():
    import io

    from imagegen.utils import ensure_utf8_streams

    ensure_utf8_streams([io.StringIO(), object()])  # 例外を出さない


def test_failure_to_reconfigure_is_not_fatal():
    from imagegen.utils import ensure_utf8_streams

    ensure_utf8_streams([_FakeStream("cp932", fails=True)])  # 例外を出さない
