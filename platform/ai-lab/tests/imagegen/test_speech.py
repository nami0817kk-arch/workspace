"""音声合成の入口（コネクタ選択・長文の分割・つなぎ直し・クレジット・記録）。"""

import io
import json
import wave

import pytest

from imagegen import speech, usage
from imagegen.core.errors import ConfigError, ConnectorError
from imagegen.core.types import SynthesizedSpeech


def wav(seconds=0.2, rate=24000, channels=1):
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as writer:
        writer.setnchannels(channels)
        writer.setsampwidth(2)
        writer.setframerate(rate)
        writer.writeframes(b"\x00\x00" * int(rate * seconds) * channels)
    return buffer.getvalue()


def clip(text="あ", *, data=None, mime="audio/wav", credit="", provider="beep"):
    return SynthesizedSpeech(
        data=data if data is not None else wav(),
        mime=mime,
        provider=provider,
        model="test",
        voice="mid",
        text=text,
        credit=credit,
    )


# --- コネクタの選択 ---------------------------------------------------
def test_auto_falls_back_to_the_placeholder():
    """キーもENGINEも無い環境でも必ず音声が作れる。"""
    assert speech.auto_provider().name in {"voicevox", "beep"}


def test_auto_prefers_a_configured_api(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    assert speech.auto_provider().name == "openai_tts"


def test_get_provider_rejects_a_connector_without_the_capability():
    with pytest.raises(ConnectorError, match="音声合成に対応していません"):
        speech.get_provider("iconify")


def test_available_providers_lists_every_speech_connector():
    names = [name for name, _ok, _reason in speech.available_providers()]
    assert {"openai_tts", "elevenlabs", "voicevox", "beep"} <= set(names)


def test_list_voices_goes_through_the_connector():
    assert [voice.id for voice in speech.list_voices("beep")] == ["low", "mid", "high"]


# --- 長文の分割 -------------------------------------------------------
def test_split_keeps_short_text_whole():
    assert speech.split_text("短い文章です。", 100) == ["短い文章です。"]


def test_split_cuts_at_sentence_boundaries():
    text = "一つ目の文です。二つ目の文です。三つ目の文です。"
    chunks = speech.split_text(text, 10)
    assert chunks == ["一つ目の文です。", "二つ目の文です。", "三つ目の文です。"]
    assert "".join(chunks) == text  # 文字を落とさない


def test_split_hard_cuts_a_single_long_sentence():
    chunks = speech.split_text("あ" * 25, 10)
    assert [len(chunk) for chunk in chunks] == [10, 10, 5]


def test_split_ignores_an_empty_text():
    assert speech.split_text("   ", 10) == []


def test_split_without_a_limit_returns_one_chunk():
    assert speech.split_text("あ" * 50, 0) == ["あ" * 50]


# --- つなぎ直し -------------------------------------------------------
def test_join_concatenates_wav_clips():
    joined = speech.join_wav([clip("前半"), clip("後半")])
    assert joined.text == "前半後半"
    assert joined.seconds == pytest.approx(0.4)
    assert joined.meta["chunks"] == 2


def test_join_returns_the_only_clip_unchanged():
    single = clip()
    assert speech.join_wav([single]) is single


def test_join_refuses_mismatched_formats():
    with pytest.raises(ConfigError, match="形式の違う"):
        speech.join_wav([clip(data=wav(rate=24000)), clip(data=wav(rate=44100))])


def test_join_refuses_non_wav_data():
    with pytest.raises(ConfigError, match="WAV として読めません"):
        speech.join_wav([clip(data=b"not-a-wav"), clip()])


def test_join_needs_at_least_one_clip():
    with pytest.raises(ConfigError):
        speech.join_wav([])


def test_can_join_only_applies_to_wav():
    assert speech.can_join([clip(), clip()])
    assert not speech.can_join([clip(mime="audio/mpeg"), clip(mime="audio/mpeg")])
    assert not speech.can_join([clip()])  # 1本なら つなぐ必要がない


# --- 合成 -------------------------------------------------------------
def test_synthesize_splits_long_text_and_joins_it_back(monkeypatch):
    monkeypatch.setattr("imagegen.connectors.speech_beep.BeepSpeech.max_chars", 10, raising=False)
    clips = speech.synthesize("あ" * 45, provider="beep")

    assert len(clips) == 1  # WAV なので1本につながっている
    assert clips[0].meta["chunks"] == 5
    assert clips[0].text == "あ" * 45


def test_synthesize_can_keep_the_chunks_separate(monkeypatch):
    monkeypatch.setattr("imagegen.connectors.speech_beep.BeepSpeech.max_chars", 10, raising=False)
    assert len(speech.synthesize("あ" * 45, provider="beep", join=False)) == 5


def test_synthesize_rejects_empty_text():
    with pytest.raises(ConfigError, match="空です"):
        speech.synthesize("   ", provider="beep")


def test_synthesize_records_the_usage(tmp_path, monkeypatch):
    monkeypatch.setenv("IMAGEGEN_OUTPUT_DIR", str(tmp_path))
    speech.synthesize("記録される文章です", provider="beep")

    entries = usage.load()
    assert len(entries) == 1
    assert entries[0]["kind"] == "speech"
    assert entries[0]["provider"] == "beep"
    assert entries[0]["chars"] == len("記録される文章です")


def test_usage_counts_speech_separately_from_images(tmp_path, monkeypatch):
    monkeypatch.setenv("IMAGEGEN_OUTPUT_DIR", str(tmp_path))
    (tmp_path / "costs.json").write_text(
        json.dumps({"speech": {"beep": {"": 2.0}}}), encoding="utf-8"
    )
    speech.synthesize("あ" * 500, provider="beep")

    summary = usage.summarize()
    assert summary["clips"] == 1
    assert summary["chars"] == 500
    assert summary["images"] == 0
    assert summary["cost_usd"] == pytest.approx(1.0)  # 2.0 USD / 1000文字 × 500文字
    assert summary["breakdown"][0]["kind"] == "speech"


def test_old_records_without_a_kind_still_count_as_images(tmp_path, monkeypatch):
    monkeypatch.setenv("IMAGEGEN_OUTPUT_DIR", str(tmp_path))
    usage.log_path().write_text(
        json.dumps({"ts": "2026-08-01T00:00:00", "provider": "openai", "model": "m", "images": 2})
        + "\n",
        encoding="utf-8",
    )
    summary = usage.summarize()
    assert summary["images"] == 2
    assert summary["breakdown"][0]["kind"] == "image"


# --- 保存とクレジット -------------------------------------------------
def test_save_all_numbers_multiple_files(tmp_path):
    saved = speech.save_all([clip("前"), clip("後")], tmp_path, basename="narration")
    assert [path.name for path in saved] == ["narration_1.wav", "narration_2.wav"]
    assert all(path.is_file() for path in saved)


def test_save_all_uses_the_default_name(tmp_path):
    saved = speech.save_all([clip("ひとつ")], tmp_path)
    assert saved[0].suffix == ".wav"
    assert "beep" in saved[0].name


def test_credits_are_written_once(tmp_path):
    clips = [clip(credit="VOICEVOX:ずんだもん"), clip(credit="VOICEVOX:ずんだもん")]
    path = speech.write_credits(clips, tmp_path)
    speech.write_credits(clips, tmp_path)  # 2回書いても増えない

    text = path.read_text(encoding="utf-8")
    assert text.count("VOICEVOX:ずんだもん") == 1
    assert "## 音声" in text


def test_no_credits_file_when_none_is_required(tmp_path):
    assert speech.write_credits([clip()], tmp_path) is None
    assert not (tmp_path / "CREDITS.md").exists()
