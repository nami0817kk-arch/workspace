import wave

import pytest

from src import audio
from src.audio import SoundEffect, collect_effects, mix
from src.audio_gen import ensure_audio_assets
from src.config import AudioConfig, build_config
from src.script_model import parse_script

CAST = {"霊夢": {"key": "reimu", "style_id": 2}, "魔理沙": {"key": "marisa", "style_id": 3}}


def _timed(text):
    script = parse_script(text)
    start = 0.0
    for line in script.lines:
        line.duration, line.pause, line.start = 2.0, 0.4, start
        start += line.duration
    return script


def _voice(path, seconds=1.0, channels=1):
    """digital silence の wav。"""
    with wave.open(str(path), "wb") as out:
        out.setnchannels(channels)
        out.setsampwidth(2)
        out.setframerate(24000)
        out.writeframes(b"\x00" * 2 * channels * int(24000 * seconds))
    return path


def _tone(path, seconds=3.0):
    """無音ではない wav。loudnorm を通せる。"""
    import math
    import struct

    frames = bytearray()
    for n in range(int(24000 * seconds)):
        frames += struct.pack("<h", int(math.sin(2 * math.pi * 440 * n / 24000) * 12000))
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(24000)
        out.writeframes(bytes(frames))
    return path


def test_collect_effects_uses_line_timing(tmp_path):
    se = _voice(tmp_path / "se.wav", 0.1)
    config = build_config({"cast": CAST, "audio": {}})
    script = _timed(f"## S\n霊夢: あ。\n魔理沙: い。\n  se: {se}\n")

    effects = collect_effects(script, config)
    assert [e.at for e in effects] == [2.0]


def test_collect_effects_adds_scene_se(tmp_path):
    se = _voice(tmp_path / "scene.wav", 0.1)
    config = build_config({"cast": CAST, "audio": {"scene_se": str(se)}})
    script = _timed("## 章1\n霊夢: あ。\n\n## 章2\n魔理沙: い。\n")

    effects = collect_effects(script, config)
    assert [e.at for e in effects] == [0.0, 2.0]


def test_missing_effect_file_is_skipped(tmp_path):
    config = build_config({"cast": CAST, "audio": {}})
    script = _timed("## S\n霊夢: あ。\n  se: assets/audio/存在しない.wav\n")
    assert collect_effects(script, config) == []


def test_mix_returns_voice_when_nothing_to_add(tmp_path):
    voice = _voice(tmp_path / "voice.wav")
    config = AudioConfig(bgm="", loudness_target=0)
    assert mix(voice, tmp_path / "out.m4a", tmp_path, config, 1.0) == voice


def test_mix_normalizes_loudness_when_voice_has_signal(tmp_path):
    voice = _tone(tmp_path / "voice.wav")
    config = AudioConfig(bgm="", loudness_target=-14)
    out = mix(voice, tmp_path / "out.m4a", tmp_path, config, 3.0)
    assert out.name == "out.m4a" and out.stat().st_size > 0


def test_silent_voice_skips_loudness_normalization(tmp_path):
    """無音に loudnorm を掛けると NaN で落ちるので、そのまま返す。"""
    voice = _voice(tmp_path / "voice.wav", 2.0)
    config = AudioConfig(bgm="", loudness_target=-14)
    assert mix(voice, tmp_path / "out.m4a", tmp_path, config, 2.0) == voice


def test_mix_with_bgm_and_effects(tmp_path):
    ensure_audio_assets()
    voice = _voice(tmp_path / "voice.wav", 3.0)
    se = _voice(tmp_path / "se.wav", 0.2)
    config = AudioConfig(bgm="assets/audio/bgm_loop.wav")
    out = mix(
        voice,
        tmp_path / "out.m4a",
        tmp_path,
        config,
        duration=3.0,
        effects=[SoundEffect(1.0, se)],
    )
    assert out.exists() and out.stat().st_size > 0


def test_mono_voice_is_detected(tmp_path):
    assert audio._is_mono(_voice(tmp_path / "m.wav", 0.2, channels=1))
    assert not audio._is_mono(_voice(tmp_path / "s.wav", 0.2, channels=2))


def test_generated_audio_assets_are_valid_wav():
    for path in [p for p in (ensure_audio_assets() or []) if p.suffix == ".wav"]:
        with wave.open(str(path), "rb") as handle:
            assert handle.getnframes() > 0


def test_the_prefix_picks_the_music():
    from src.audio_gen import track_for

    # 速報とまとめで同じ曲が流れると、どちらも同じ温度に聞こえる。
    # 2026-09-05 に曲調を5つへ増やした。**悲報と速報も温度が違う**ので分けた
    # （登録外・退団・敗戦の回に急かす曲が流れると、内容と合わない）。
    assert track_for("【速報】クラブが公式声明").endswith("bgm_breaking.wav")
    assert track_for("【悲報】2試合で無得点").endswith("bgm_somber.wav")
    assert track_for("【詳報】移籍市場のまとめ").endswith("bgm_calm.wav")
    assert track_for("【朗報】復帰へ").endswith("bgm_victory.wav")
    assert track_for("札のないタイトル").endswith("bgm_loop.wav")


def test_an_explicit_track_wins_over_the_prefix():
    from src.audio_gen import track_for

    assert track_for("【速報】x", "assets/audio/mine.wav") == "assets/audio/mine.wav"


def test_each_mood_has_its_own_tempo_and_progression():
    from src.audio_gen import MOODS, _mood

    breaking, calm = _mood("breaking"), _mood("calm")
    assert breaking["bpm"] > calm["bpm"]          # 速報のほうが速い
    assert breaking["pulse"] > calm["pulse"]      # 低音も強い
    assert breaking["progression"] != calm["progression"]
    assert all(m["seconds"] > 10 for m in (breaking, calm))


def test_an_unknown_mood_falls_back_to_news():
    from src.audio_gen import _mood

    assert _mood("しらない曲調")["bpm"] == _mood("news")["bpm"]


def test_every_mood_renders_a_loopable_file(tmp_path):
    import struct
    import wave

    from src.audio_gen import MOODS, generate_bgm

    for name in MOODS:
        path = generate_bgm(tmp_path / f"{name}.wav", name)
        with wave.open(str(path)) as handle:
            samples = struct.unpack(f"<{handle.getnframes() * 2}h", handle.readframes(handle.getnframes()))
        assert handle.getnchannels() == 2

        # 継ぎ目が鳴らないよう、両端は落ちきっている（真ん中は鳴っている）
        assert max(abs(v) for v in samples[:40]) < 200, name
        assert max(abs(v) for v in samples[-40:]) < 200, name
        middle = samples[len(samples) // 2 - 400: len(samples) // 2 + 400]
        assert max(abs(v) for v in middle) > 500, name


# ---------------------------------------------------------------- 文字コード
# ffmpeg は UTF-8 で書く。読む側がロケールの文字コード（Windows の日本語環境なら
# cp932）を使うと、エラー文の中身によっては読み取りそのものが落ちて、
# 本当の失敗の理由が見えなくなる。

def test_ffmpegの出力はUTF8で読む(monkeypatch):
    import subprocess

    from src import ffmpeg

    seen = {}

    def fake(command, **kwargs):
        seen.update(kwargs)
        return subprocess.CompletedProcess(command, 0, "", "")

    monkeypatch.setattr(ffmpeg, "ffmpeg_exe", lambda: "ffmpeg")
    monkeypatch.setattr(subprocess, "run", fake)
    ffmpeg.run(["-i", "a.wav", "b.wav"])

    assert seen["encoding"] == "utf-8"
    assert seen["errors"] == "replace"


def test_音量の測定も同じ(monkeypatch, tmp_path):
    import subprocess

    from src import ffmpeg

    seen = {}

    def fake(command, **kwargs):
        seen.update(kwargs)
        return subprocess.CompletedProcess(command, 0, "", "max_volume: -3.0 dB")

    monkeypatch.setattr(ffmpeg, "ffmpeg_exe", lambda: "ffmpeg")
    monkeypatch.setattr(subprocess, "run", fake)
    assert ffmpeg.max_volume(tmp_path / "a.wav") == -3.0
    assert seen["encoding"] == "utf-8"
