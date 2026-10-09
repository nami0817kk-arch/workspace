"""本編の最後の15秒（終了画面の置き場）が、どの経路でも動画に入ること（2026-10-10）。

**壊れた例**：10/10 未明に書き出した3本のうち2本で、15秒が入っていなかった
（`transfer_neymar` は字幕 4:13.6 / 動画 4:14.5、`compare_bellingham_musiala` は
4:01.7 / 4:02.5）。計画（`inserts.plan`）は3本とも `outro=15.0` を返していて、
絵の列（frames.txt）も正しい長さだった。**切っていたのは `-shortest`** で、
音の実尺が絵より短い回だけ、動画が後ろから黙って詰められていた。
短くなった音の正体は、**途中まで書かれた15秒の無音**（work/gaps に残ったものを
`exists()` だけ見て使い回していた。ffmpeg はヘッダではなく実際のバイト数で
尺を決めるので、警告もエラーも出ない）。

ここで見るのは4つ。
- 絵の列の長さで動画の尺が決まる（音が短くても切られない）。**動画1本の下地と、
  下地をつなぐ経路の両方**
- 書き出しの依頼に渡す秒数に、終了画面の15秒が入っている（上と同じ2経路）
- 書きかけの無音は使い回さない・残さない
- つないだ音が計画より短ければ止まる
"""

from __future__ import annotations

import wave
from pathlib import Path

import pytest
from PIL import Image

from src import ffmpeg, inserts as inserts_mod, pipeline
from src.config import load_config
from src.inserts import Inserts, realize_audio
from src.render import Renderer
from src.script_model import parse_script

SPEECH = 2.0        # 語りのぶん（短くしてある。見るのは末尾の足し方）
OUTRO = 15.0        # 終了画面の置き場
FPS = 10            # テストの書き出しを軽くするため


def _png(path: Path, color: tuple[int, int, int, int]) -> Path:
    Image.new("RGBA", (64, 36), color).save(path)
    return path


def _wav(path: Path, seconds: float) -> Path:
    """語りのぶんだけの音（＝末尾の無音が入っていない、壊れた回の音）。"""
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(24000)
        out.writeframes(b"\x00\x01" * int(24000 * seconds))
    return path


def _frames(tmp_path: Path) -> Path:
    """本物と同じ形の列（口パク → 終了画面の静止 → 溶かし）。

    末尾を小さな秒数で終えるのも本物どおり（concat の作法で最後の1枚をもう一度
    書くので、そこが長いとその回だけ端数が大きくなる）。
    """
    closed = _png(tmp_path / "closed.png", (10, 60, 40, 255))
    opened = _png(tmp_path / "opened.png", (12, 66, 44, 255))
    card = _png(tmp_path / "outro.png", (0, 0, 0, 255))
    entries: list[tuple[Path, float]] = []
    for i in range(20):                                   # 語り（口パク）
        entries.append((opened if i % 2 else closed, SPEECH / 20))
    entries.append((card, OUTRO - 0.6))                   # 終了画面の静止
    entries += [(closed, 0.3), (opened, 0.3)]             # 溶かし（小さな秒数で終わる）
    assert sum(s for _, s in entries) == pytest.approx(SPEECH + OUTRO)
    return ffmpeg.write_concat_list(entries, tmp_path / "frames.txt")


def _clip(tmp_path: Path) -> Path:
    """下地の動画（短い1本。`-stream_loop -1` で回される）。"""
    clip = tmp_path / "stadium.mp4"
    ffmpeg.run([
        "-f", "lavfi", "-i", f"color=c=green:s=64x36:d=1:r={FPS}",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", str(clip),
    ])
    return clip


# ---------------------------------------------------------------- 実際に書き出して測る

def test_下地が動画1本でも音が短ければ切らずに終了画面のぶんを残す(tmp_path):
    """`-shortest` の経路。音は語りのぶんだけ（15秒の無音が無い壊れた回）。"""
    out = tmp_path / "video.mp4"
    ffmpeg.encode_video_over_clip(
        _frames(tmp_path), _clip(tmp_path), _wav(tmp_path / "voice.wav", SPEECH),
        out, (64, 36), FPS, duration=SPEECH + OUTRO,
    )
    info = ffmpeg.probe(out)
    assert info is not None
    # 音（2秒）ではなく、絵の列（17秒）で終わる
    assert info["duration"] == pytest.approx(SPEECH + OUTRO, abs=0.3)
    assert info["duration"] - SPEECH >= OUTRO - 0.3


def test_下地をつなぐ経路でも終了画面のぶんを残す(tmp_path):
    """静止画だけの回（`encode_video`）。こちらにも `-shortest` が付いていた。"""
    out = tmp_path / "video.mp4"
    ffmpeg.encode_video(
        _frames(tmp_path), _wav(tmp_path / "voice.wav", SPEECH), out, FPS,
        duration=SPEECH + OUTRO,
    )
    info = ffmpeg.probe(out)
    assert info is not None
    assert info["duration"] == pytest.approx(SPEECH + OUTRO, abs=0.3)


def test_音のほうが長くても尺は伸びない(tmp_path):
    """`-shortest` は外していないので、長い音に引かれて伸びることはない。

    8秒長い音を渡しても、絵の列の長さ（＋concat の作法の端数）で終わる。
    """
    out = tmp_path / "video.mp4"
    ffmpeg.encode_video(
        _frames(tmp_path), _wav(tmp_path / "voice.wav", SPEECH + OUTRO + 8.0), out, FPS,
        duration=SPEECH + OUTRO,
    )
    info = ffmpeg.probe(out)
    assert info is not None
    assert SPEECH + OUTRO - 0.3 <= info["duration"] <= SPEECH + OUTRO + ffmpeg.LENGTH_TOLERANCE


def test_尺が計画と合わなければ止める(tmp_path):
    out = tmp_path / "video.mp4"
    ffmpeg.encode_video(_frames(tmp_path), None, out, FPS, duration=SPEECH + OUTRO)
    with pytest.raises(ffmpeg.FfmpegError, match="尺が計画と合いません"):
        ffmpeg.check_length(out, SPEECH + OUTRO + 5.0)


# ------------------------------------------------- 書き出しの依頼に15秒が入っているか

def _script(background: str | None = None):
    script = parse_script(
        "## 章1\n霊夢: あいうえお。\n  telop: 一つめ\n\n## 章2\n魔理沙: かきくけこ。\n  telop: 二つめ\n"
    )
    if background:
        script.background = background
    for line in script.lines:
        line.duration, line.pause = 2.0, 0.0
    return script


def _duration_of(tmp_path, monkeypatch, *, many: bool) -> tuple[float, float]:
    """(書き出しに渡した秒数, 語りの合計) を返す。"""
    clip = tmp_path / "stadium.mp4"
    clip.write_bytes(b"")
    seen: dict[str, float] = {}
    monkeypatch.setattr(ffmpeg, "build_background_track", lambda segments, out, *a, **k: out)
    monkeypatch.setattr(
        ffmpeg, "encode_video_over_clip",
        lambda *a, duration, **k: seen.setdefault("duration", duration),
    )
    config = load_config()
    script = _script(str(clip))
    if many:
        # 節ごとに下地が違えば、今までどおり1本につないでから重ねる経路に入る
        script.scenes[1].background = "assets/backgrounds/default.png"
    inserts = inserts_mod.plan(script, config)
    assert inserts.outro == OUTRO, "config の titles.outro が 15 でなくなっている"
    inserts_mod.apply_timing(script, inserts)
    Renderer(config, tmp_path / "work").build_video(
        script, None, tmp_path / "video.mp4", tmp_path / "work", inserts)
    return seen["duration"], script.duration


@pytest.mark.parametrize("many", [False, True], ids=["下地は動画1本", "下地をつなぐ"])
def test_書き出しに渡す秒数に終了画面の15秒が入っている(tmp_path, monkeypatch, many):
    duration, speech = _duration_of(tmp_path, monkeypatch, many=many)
    assert duration - speech == pytest.approx(OUTRO, abs=0.05)


# ---------------------------------------------------------------- 書きかけの無音

def test_途中まで書かれた無音は使い回さない(tmp_path):
    gaps = tmp_path / "gaps"
    voice = tmp_path / "voice.wav"
    _wav(voice, 0.5)
    segments: list[tuple[Path | None, float]] = [(voice, 0.5), (None, OUTRO)]

    silence = realize_audio(segments, gaps)[1]
    full = silence.stat().st_size

    # ディスクが埋まった・途中で止めた回を真似て、後ろを落とす（ヘッダは15秒のまま）
    data = silence.read_bytes()
    silence.write_bytes(data[: 44 + int(0.4 * 24000 * 2)])
    assert silence.stat().st_size < full

    again = realize_audio(segments, gaps)[1]
    assert again == silence
    assert again.stat().st_size == full          # 書き直されている
    with wave.open(str(again), "rb") as handle:
        assert handle.getnframes() == int(24000 * OUTRO)


def test_無音は別名に書いてから置き換える(tmp_path):
    gaps = tmp_path / "gaps"
    voice = _wav(tmp_path / "voice.wav", 0.5)
    realize_audio([(voice, 0.5), (None, 1.0)], gaps)
    assert not list(gaps.glob("*.part")), "書きかけのファイルが残っている"


def test_揃っている無音は作り直さない(tmp_path):
    gaps = tmp_path / "gaps"
    voice = _wav(tmp_path / "voice.wav", 0.5)
    segments: list[tuple[Path | None, float]] = [(voice, 0.5), (None, 1.0)]
    first = realize_audio(segments, gaps)[1]
    stamp = first.stat().st_mtime_ns
    assert realize_audio(segments, gaps)[1].stat().st_mtime_ns == stamp


# ---------------------------------------------------------------- つないだ音の長さ

def test_つないだ音が計画より短ければ止める(tmp_path):
    track = _wav(tmp_path / "voice.wav", SPEECH)
    with pytest.raises(ffmpeg.FfmpegError, match="音の長さが計画と合いません"):
        pipeline.verify_voice_length(track, SPEECH + OUTRO)


def test_計画どおりならそのまま通る(tmp_path):
    track = _wav(tmp_path / "voice.wav", SPEECH)
    pipeline.verify_voice_length(track, SPEECH)


def test_読めない音では落とさない(tmp_path):
    pipeline.verify_voice_length(tmp_path / "無い.wav", 10.0)


def test_計画は終了画面の15秒を返す():
    """`Inserts` 側の既定（config の titles.outro）。ここが0なら上の全部が無意味になる。"""
    config = load_config()
    script = _script()
    assert inserts_mod.plan(script, config).outro == OUTRO
    assert inserts_mod.audio_segments(script, Inserts(outro=OUTRO))[-1] == (None, OUTRO)
