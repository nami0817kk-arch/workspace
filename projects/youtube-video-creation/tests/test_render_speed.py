"""書き出しを速くした所（2026-10-08）。速くしても絵・形式・尺が変わらないこと。

- 途中の画像: 動画に重ねる回は RGBA の PNG（透過が要る）、下地が静止画だけの回は JPEG。
  **1本の列の中で形式を混ぜない**（RGB を RGBA の列に混ぜると ffmpeg がコマを落とした。2026-10-01）
- 保存は別スレッド。frame_entries が返った時点で全部読める
- concat の並びは、続けて同じ絵ならまとめる（絵と秒は同じ）
- 下地が動画1本だけなら、つなぎ直さずにそのまま敷く
- 最後の mp4 は preset だけ veryfast。crf は 20 のまま
"""

from pathlib import Path

import pytest
from PIL import Image

from src import ffmpeg
from src.config import load_config
from src.render import Renderer
from src.script_model import parse_script


def _two_scenes(background: str | None = None):
    script = parse_script("## 章1\n霊夢: あいうえお。\n  telop: 一つめ\n\n## 章2\n魔理沙: かきくけこ。\n  telop: 二つめ\n")
    if background:
        script.background = background
    for line in script.lines:
        line.duration, line.pause = 2.0, 0.4
    return script


def _config_with_crossfade():
    config = load_config()
    config.motion.scene_fade = 0.32           # 溶かしの絵（blend）を必ず作らせる
    config.motion.scene_transition = "crossfade"
    return config


def test_動画に重ねる回は溶かしも含めて全部_RGBA_の_PNG(tmp_path):
    """透過の要る絵を JPEG にすると透過が消え、写真が替わる瞬間に下地が見える。"""
    renderer = Renderer(_config_with_crossfade(), tmp_path)
    entries = renderer.frame_entries(_two_scenes("clip.mp4"))
    assert renderer.over_video
    paths = {Path(p) for p, _ in entries}
    assert any(p.name.startswith("x") for p in paths)          # 溶かしの絵がある
    assert not list((tmp_path / "frames").glob("*.jpg"))
    for path in paths:
        assert path.suffix == ".png"
        with Image.open(path) as image:
            assert image.format == "PNG" and image.mode == "RGBA"


def test_下地が静止画だけの回は全部_JPEG_で形式を混ぜない(tmp_path):
    renderer = Renderer(_config_with_crossfade(), tmp_path)
    entries = renderer.frame_entries(_two_scenes())
    assert not renderer.over_video
    paths = {Path(p) for p, _ in entries}
    assert any(p.name.startswith("x") for p in paths)
    for path in paths:
        assert path.suffix == ".jpg"
        with Image.open(path) as image:
            assert image.format == "JPEG" and image.mode == "RGB"


def test_PNG_は可逆なので画素は前と同じ(tmp_path):
    """圧縮を軽くしただけ。読み戻した画素は、保存前の絵と1つも違わない。"""
    renderer = Renderer(load_config(), tmp_path)
    renderer.over_video = True
    image = Image.new("RGBA", (64, 36), (0, 0, 0, 0))
    image.paste((200, 30, 30, 128), (8, 8, 40, 30))
    target = renderer._save_frame(image, tmp_path / "frames" / "a.png")
    with Image.open(target) as back:
        assert back.mode == "RGBA"
        assert back.tobytes() == image.tobytes()


def test_返った時点で全部の絵が読める(tmp_path):
    """保存は別スレッド。返す前に待たないと、ffmpeg が書きかけの絵を読む。"""
    renderer = Renderer(_config_with_crossfade(), tmp_path)
    entries = renderer.frame_entries(_two_scenes("clip.mp4"))
    assert renderer._saver is None and not renderer._pending
    for path, _ in entries:
        with Image.open(path) as image:
            image.load()


def test_溶かしの絵は保存前の絵から作る(tmp_path):
    """手元に残した絵を使っても、ファイルから読み直しても同じ絵になる。"""
    config = _config_with_crossfade()
    renderer = Renderer(config, tmp_path)
    renderer.over_video = True
    a = Image.new("RGBA", (64, 36), (255, 0, 0, 255))
    b = Image.new("RGBA", (64, 36), (0, 0, 255, 255))
    (tmp_path / "frames").mkdir(parents=True, exist_ok=True)
    pa = renderer._save_frame(a, tmp_path / "frames" / "a.png")
    pb = renderer._save_frame(b, tmp_path / "frames" / "b.png")
    from_memory = renderer.blend(pa, pb, 0.5)
    other = Renderer(config, tmp_path / "other")
    other.over_video = True
    from_disk = other.blend(pa, pb, 0.5)
    with Image.open(from_memory) as m, Image.open(from_disk) as d:
        assert m.tobytes() == d.tobytes()


def test_続けて同じ絵は_concat_で1つにまとめる(tmp_path):
    a, b = tmp_path / "a.png", tmp_path / "b.png"
    entries = [(a, 0.14), (a, 0.14), (a, 0.1), (b, 0.5), (a, 0.2)]
    listing = ffmpeg.write_concat_list(entries, tmp_path / "list.txt").read_text(encoding="utf-8")
    files = [line for line in listing.splitlines() if line.startswith("file")]
    durations = [float(line.split()[1]) for line in listing.splitlines() if line.startswith("duration")]
    # a(3つ) → b → a。離れた a はまとめない。最後の1枚はもう一度書く（concat の作法）
    assert [Path(f.split("'")[1]).name for f in files] == ["a.png", "b.png", "a.png", "a.png"]
    assert durations == pytest.approx([0.38, 0.5, 0.2])
    assert sum(durations) == pytest.approx(sum(s for _, s in entries))


def test_下地が動画1本ならつなぎ直さない(tmp_path, monkeypatch):
    clip = tmp_path / "stadium.mp4"
    clip.write_bytes(b"")
    calls = {}
    monkeypatch.setattr(ffmpeg, "build_background_track",
                        lambda *a, **k: pytest.fail("動画1本をつなぎ直している"))
    monkeypatch.setattr(ffmpeg, "encode_video_over_clip",
                        lambda frames, track, *a, **k: calls.setdefault("track", track))
    config = load_config()
    renderer = Renderer(config, tmp_path / "work")
    renderer.build_video(_two_scenes(str(clip)), None, tmp_path / "video.mp4", tmp_path / "work")
    assert Path(calls["track"]) == clip


def test_下地が複数なら今までどおりつなぐ(tmp_path, monkeypatch):
    clip = tmp_path / "stadium.mp4"
    clip.write_bytes(b"")
    built = []
    monkeypatch.setattr(ffmpeg, "build_background_track",
                        lambda segments, out, *a, **k: built.append(segments) or out)
    monkeypatch.setattr(ffmpeg, "encode_video_over_clip", lambda *a, **k: None)
    script = _two_scenes(str(clip))
    script.scenes[1].background = "assets/backgrounds/default.png"
    renderer = Renderer(load_config(), tmp_path / "work")
    renderer.build_video(script, None, tmp_path / "video.mp4", tmp_path / "work")
    assert built and len(built[0]) == 2


@pytest.mark.parametrize("encode", ["encode_video", "encode_video_over_clip"])
def test_最後の_mp4_は_preset_だけ速くして_crf_は変えない(tmp_path, monkeypatch, encode):
    seen = []
    monkeypatch.setattr(ffmpeg, "run", lambda args, quiet=True: seen.append(args))
    if encode == "encode_video":
        ffmpeg.encode_video(tmp_path / "l.txt", tmp_path / "a.m4a", tmp_path / "o.mp4",
                            duration=10.0)
    else:
        ffmpeg.encode_video_over_clip(tmp_path / "l.txt", tmp_path / "c.mp4", tmp_path / "a.m4a",
                                      tmp_path / "o.mp4", (1920, 1080), duration=10.0)
    args = seen[0]
    assert args[args.index("-preset") + 1] == "veryfast"
    assert args[args.index("-crf") + 1] == "20"
    assert args[args.index("-b:a") + 1] == "192k"


def test_混ぜている途中の音は_ffmpeg_に渡す前に待つ(tmp_path, monkeypatch):
    """音の混ぜは絵を描くあいだに別スレッドで回す（pipeline）。渡すのは出来上がった音のパス。"""
    from concurrent.futures import Future

    clip = tmp_path / "stadium.mp4"
    clip.write_bytes(b"")
    seen = {}
    monkeypatch.setattr(ffmpeg, "encode_video_over_clip",
                        lambda frames, track, audio, *a, **k: seen.setdefault("audio", audio))
    pending: Future = Future()
    pending.set_result(tmp_path / "soundtrack.m4a")
    Renderer(load_config(), tmp_path / "work").build_video(
        _two_scenes(str(clip)), pending, tmp_path / "video.mp4", tmp_path / "work")
    assert seen["audio"] == tmp_path / "soundtrack.m4a"
