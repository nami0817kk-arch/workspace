"""数字の図（試合映像の代わりに使う下地）。

参考チャンネルの最高再生（64万回）の中身は、試合映像ではなく走行距離の
スタッツ画面だった。放送映像は使えないが、数字の図は自分で作れる。
"""

from PIL import Image

from src.config import load_config
from src.statboard import (StatboardError, build, is_statboard, parse_rows)
from src.thumbnail import SIZE


def _board(tmp_path, rows=None, **kwargs):
    return build(rows or [("ヴィルツ", 12.3), ("サラー", 9.2)],
                 tmp_path / "board.png", load_config(), **kwargs)


def test_数字の図を書き出す(tmp_path):
    path = _board(tmp_path, title="走行距離", unit="km")
    assert path.exists()
    with Image.open(path) as image:
        assert image.size == SIZE


def test_下の半分は空けておく(tmp_path):
    """サムネの帯と反応の小窓が乗る場所。**最後の行が隠れていた**（実測）。"""
    path = _board(tmp_path, rows=[(f"選手{i}", 10 - i) for i in range(5)],
                  title="走行距離", unit="km")
    with Image.open(path) as image:
        band = image.convert("RGB").crop((0, int(SIZE[1] * 0.55), SIZE[0], SIZE[1]))
        colours = set(band.getdata())
    # 図の下地は濃紺。芝の緑だけが残っていること
    assert not any(b > r + 20 and b > 60 and g < b for r, g, b in colours)


def test_自分で作った図だという印を残す(tmp_path):
    path = _board(tmp_path, title="走行距離", unit="km", note="FBref")
    assert is_statboard(path)
    mark = path.with_suffix(path.suffix + ".statboard.txt").read_text(encoding="utf-8")
    assert "ヴィルツ=12.3" in mark          # 数字の出どころを追える
    assert "source: FBref" in mark


def test_写真は印を持たない(tmp_path):
    photo = tmp_path / "face.jpg"
    photo.write_bytes(b"x")
    assert is_statboard(photo) is False


def test_名前と値の形を読む():
    assert parse_rows(["ヴィルツ=12.3", "サラー=9.2"]) == [("ヴィルツ", 12.3), ("サラー", 9.2)]


def test_読めない値は黙って捨てない():
    """捨てると、図に出ていない選手がいることに気づけない。"""
    for bad in (["ヴィルツ"], ["ヴィルツ=たくさん"], ["=12.3"]):
        try:
            parse_rows(bad)
        except StatboardError:
            continue
        raise AssertionError(f"止まっていない: {bad}")


def test_数字が無ければ作らない(tmp_path):
    try:
        build([], tmp_path / "empty.png", load_config())
    except StatboardError:
        return
    raise AssertionError("空でも書き出している")
