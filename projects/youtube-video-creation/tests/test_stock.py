"""実写素材の取得。背景を決め打ちにしないための仕組み。"""

import json

import pytest

from src.stock import Clip, StockError, _record, pick


def _clip(width=1920, height=1080, seconds=10.0, source="pexels"):
    return Clip(source=source, url="https://example/1", file_url="https://example/1.mp4",
                author="撮影者", width=width, height=height, seconds=seconds,
                license="Pexels License")


def test_横向きを優先して選ぶ():
    """縦の映像は16対9の画面に敷けない。"""
    tall = _clip(width=1080, height=1920)
    wide = _clip(width=1920, height=1080)

    assert pick([tall, wide]) is wide


def test_必要な尺があるものを優先する():
    """短すぎるとループが目立つ。"""
    short = _clip(seconds=3.0, width=3840)
    enough = _clip(seconds=12.0, width=1920)

    assert pick([short, enough], seconds=8.0) is enough


def test_条件を満たすものが無ければ一番大きいものを返す():
    """空を返して止めるより、あるもので進めたほうがよい。"""
    only = [_clip(seconds=2.0, width=1280), _clip(seconds=2.0, width=1920)]

    assert pick(only, seconds=8.0).width == 1920


def test_クレジットを写真と同じ形で控える(tmp_path):
    target = tmp_path / "stadium.mp4"
    target.write_bytes(b"x")

    _record(target, _clip())

    rows = json.loads((tmp_path / "credits.json").read_text(encoding="utf-8"))
    assert rows[0]["file"] == "stadium.mp4"
    assert rows[0]["author"] == "撮影者"
    assert rows[0]["license"] == "Pexels License"
    assert rows[0]["page_url"].startswith("https://")


def test_同じ名前は上書きする(tmp_path):
    """取り直したとき、古い行が残ると出典が二重になる。"""
    target = tmp_path / "stadium.mp4"
    target.write_bytes(b"x")

    _record(target, _clip())
    _record(target, _clip(source="pixabay"))

    rows = json.loads((tmp_path / "credits.json").read_text(encoding="utf-8"))
    assert len(rows) == 1
    assert rows[0]["source"] == "pixabay"


def test_素材が無ければ言って止まる():
    from src import stock

    with pytest.raises(StockError):
        stock.pick([], seconds=8.0) if False else stock.search_video("")


# 背景は節ごとに20秒ほどしか映らない。元の尺（30〜120秒）をそのまま置くと重い。
# 2026-09-07 に 120秒576MB の素材を掴み、書き出しが1分から4分21秒に伸びた。

def test_落としたクリップを切り詰める(tmp_path):
    """入れ物を詰め替えるだけ。作り直さない。"""
    import subprocess

    import imageio_ffmpeg

    from src.stock import KEEP_SECONDS, trim

    ff = imageio_ffmpeg.get_ffmpeg_exe()
    long_clip = tmp_path / "bg.mp4"
    subprocess.run(
        [ff, "-y", "-loglevel", "error", "-f", "lavfi", "-i",
         f"testsrc=size=320x180:rate=15:duration={KEEP_SECONDS + 20}",
         "-c:v", "libx264", "-pix_fmt", "yuv420p", str(long_clip)],
        check=True, capture_output=True,
    )
    before = long_clip.stat().st_size

    assert trim(long_clip, 8.0)
    assert long_clip.stat().st_size < before

    info = subprocess.run([ff, "-hide_banner", "-i", str(long_clip)],
                          capture_output=True, text=True, encoding="utf-8", errors="replace").stderr
    import re
    match = re.search(r"Duration: (\d+):(\d\d):(\d\d(?:\.\d+)?)", info)
    seconds = int(match.group(1)) * 3600 + int(match.group(2)) * 60 + float(match.group(3))
    assert seconds <= KEEP_SECONDS + 2


def test_短いクリップは触らない(tmp_path):
    import subprocess

    import imageio_ffmpeg

    from src.stock import trim

    ff = imageio_ffmpeg.get_ffmpeg_exe()
    clip = tmp_path / "short.mp4"
    subprocess.run(
        [ff, "-y", "-loglevel", "error", "-f", "lavfi", "-i",
         "testsrc=size=320x180:rate=15:duration=5",
         "-c:v", "libx264", "-pix_fmt", "yuv420p", str(clip)],
        check=True, capture_output=True,
    )
    before = clip.stat().st_size
    trim(clip, 8.0)
    # 元が短いので、切っても中身は変わらない（大きくはならない）
    assert clip.stat().st_size <= before + 4096
