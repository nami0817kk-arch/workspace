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


class _Named(SilentBackend):
    def speaker_name(self, style_id):
        return {2: "四国めたん", 3: "ずんだもん"}.get(style_id)


def test_credits_list_voicevox_speakers():
    script = parse_script("## S\n霊夢: あ。\n魔理沙: い。\n")
    assert credits(script, _config(), _Named()) == ["音声: VOICEVOX（四国めたん・ずんだもん）"]


def test_credits_skip_unused_speakers():
    """config に定義してあっても、その動画で喋っていない話者は載せない。"""
    script = parse_script("## S\n霊夢: あ。\n")
    assert credits(script, _config(), _Named()) == ["音声: VOICEVOX（四国めたん）"]


def test_credits_empty_without_speaker_names():
    script = parse_script("## S\n霊夢: あ。\n")
    assert credits(script, _config(), SilentBackend()) == []


# 背景画像しか見ておらず、行に image: で差し込んだ写真のクレジットが
# 出ていなかった（2026-09-04 実測）。CC BY は表示が必須なので、
# 出ないと利用条件を満たさない。


def test_行に差し込んだ写真のクレジットも出す(tmp_path):
    import json

    from src.script_model import parse_script
    from src.tts import image_credits

    ledger = tmp_path / "assets" / "images" / "endo"
    ledger.mkdir(parents=True)
    (ledger / "credits.json").write_text(json.dumps([{
        "file": "03.jpg", "title": "File:Wataru endo.jpg",
        "author": '<a href="/wiki/User:X">Jeollo</a>', "license": "CC BY 3.0",
        "page_url": "https://commons.wikimedia.org/wiki/File:Wataru_endo.jpg",
        "source": "wikimedia",
    }]), encoding="utf-8")

    script = parse_script(
        "## S\nキャスター: 遠藤選手です。\n  image: assets/images/endo/03.jpg\n"
    )
    # **2段になった**（2026-09-06 ユーザーの判断）。
    # 概要欄の上には出どころの1行だけ。表示義務は末尾の詳細で果たす
    from src.tts import image_details

    lines = image_credits(script, root=tmp_path)
    assert lines == ["画像: Wikimedia Commons"]

    details = image_details(script, root=tmp_path)
    assert len(details) == 1
    assert "CC BY 3.0" in details[0]
    assert "Jeollo" in details[0]          # HTML のタグは落とす
    assert "<a href" not in details[0]
    assert "commons.wikimedia.org" in details[0]   # source ではなく page_url を使う
