import wave

import pytest

from src.config import build_config
from src.script_model import parse_script
from src.tts import (
    CoreBackend,
    EngineBackend,
    SilentBackend,
    TtsError,
    create_backend,
    credits,
    synthesize_script,
    wav_duration,
)

RAW = {
    "voicevox": {"pause": 0.5},
    "cast": {
        "霊夢": {"key": "reimu", "style_id": 2},
        "魔理沙": {"key": "marisa", "style_id": 3},
    },
}


def _config(**voicevox):
    raw = {**RAW, "voicevox": {**RAW["voicevox"], **voicevox}}
    return build_config(raw)


def test_silent_backend_length_follows_text():
    backend = SilentBackend()
    line = parse_script("## S\n霊夢: " + "あ" * 50 + "\n").lines[0]
    member = _config().resolve_speaker("霊夢")
    raw = backend.synthesize(line, member)
    assert len(raw) > 44  # wav ヘッダより長い


def test_no_tts_forces_silent_backend():
    assert create_backend(_config(backend="core"), use_tts=False).name == "silent"


def test_explicit_silent_backend():
    assert create_backend(_config(backend="silent")).name == "silent"


def test_unknown_backend_is_rejected():
    with pytest.raises(TtsError, match="未対応の backend"):
        create_backend(_config(backend="ずんだ"))


def test_engine_backend_required_but_missing(monkeypatch):
    monkeypatch.setattr(EngineBackend, "available", lambda self: False)
    with pytest.raises(TtsError, match="ENGINE"):
        create_backend(_config(backend="engine"))


def test_auto_falls_back_to_silent(monkeypatch):
    monkeypatch.setattr(EngineBackend, "available", lambda self: False)
    monkeypatch.setattr(CoreBackend, "available", lambda self: False)
    assert create_backend(_config(backend="auto")).name == "silent"


def test_auto_prefers_engine(monkeypatch):
    monkeypatch.setattr(EngineBackend, "available", lambda self: True)
    assert create_backend(_config(backend="auto")).name == "engine"


def test_synthesize_script_fills_timing(tmp_path):
    config = _config()
    script = parse_script("## S\n霊夢: あいうえお。\n魔理沙: かきくけこ。\n  pause: 1.0\n")
    name = synthesize_script(script, config, tmp_path, backend=SilentBackend())

    assert name == "silent"
    first, second = script.lines
    assert first.audio_path.exists()
    assert first.start == 0.0
    assert second.start == pytest.approx(first.duration)
    # 行ごとの pause は指定値、未指定なら config の既定値が入る
    assert first.pause == 0.5
    assert second.pause == 1.0
    # 無音ぶんが尺に足されている
    assert second.duration > second.estimated_duration()


def test_synthesized_audio_is_cached(tmp_path):
    config = _config()
    script = parse_script("## S\n霊夢: あいうえお。\n")
    synthesize_script(script, config, tmp_path, backend=SilentBackend())
    before = script.lines[0].audio_path.stat().st_mtime_ns

    again = parse_script("## S\n霊夢: あいうえお。\n")
    synthesize_script(again, config, tmp_path, backend=SilentBackend())
    assert again.lines[0].audio_path.stat().st_mtime_ns == before


def test_cache_key_separates_backends(tmp_path):
    config = _config()
    script = parse_script("## S\n霊夢: あいうえお。\n")
    synthesize_script(script, config, tmp_path, backend=SilentBackend())

    class FakeCore(SilentBackend):
        name = "core"

    other = parse_script("## S\n霊夢: あいうえお。\n")
    synthesize_script(other, config, tmp_path, backend=FakeCore())
    assert other.lines[0].audio_path != script.lines[0].audio_path


def test_wav_duration_matches_written_frames(tmp_path):
    path = tmp_path / "a.wav"
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(24000)
        out.writeframes(b"\x00" * 2 * 24000)
    assert wav_duration(path) == pytest.approx(1.0)


def test_credits_list_voicevox_speakers():
    class Named(SilentBackend):
        def speaker_name(self, style_id):
            return {2: "四国めたん", 3: "ずんだもん"}.get(style_id)

    assert credits(_config(), Named()) == ["音声: VOICEVOX（四国めたん・ずんだもん）"]


def test_credits_empty_without_speaker_names():
    assert credits(_config(), SilentBackend()) == []
