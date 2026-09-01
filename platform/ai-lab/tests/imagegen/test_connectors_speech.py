"""音声合成コネクタ（voicevox / openai_tts / elevenlabs / beep）。"""

import io
import wave

import pytest
from fakes import FakeResponse, FakeSession

from imagegen.connectors.speech_beep import BeepSpeech, estimate_seconds
from imagegen.connectors.speech_elevenlabs import ElevenLabsSpeech
from imagegen.connectors.speech_openai import OpenAISpeech
from imagegen.connectors.speech_voicevox import VoicevoxSpeech
from imagegen.core.errors import AuthError, ConfigError, ConnectorError

SPEAKERS = [{"name": "ずんだもん", "styles": [{"name": "ノーマル", "id": 3}]}]


def wav_bytes(seconds=0.1, rate=24000):
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(rate)
        writer.writeframes(b"\x00\x00" * int(rate * seconds))
    return buffer.getvalue()


# --- voicevox ---------------------------------------------------------
def test_voicevox_synthesizes_and_carries_the_credit():
    session = FakeSession(
        [
            FakeResponse(json_data={"speedScale": 1.0}),  # audio_query
            FakeResponse(content=wav_bytes()),  # synthesis
            FakeResponse(json_data=SPEAKERS),  # credit_for
        ]
    )
    clip = VoicevoxSpeech(session=session).synthesize("こんにちは", speed=1.2)

    assert clip.mime == "audio/wav"
    assert clip.voice == "3"
    assert clip.credit == "VOICEVOX:ずんだもん（ノーマル）"
    assert clip.seconds == pytest.approx(0.1, abs=0.01)
    # 速度は audio_query の結果に載せて synthesis へ渡す
    assert session.calls[1][2]["json"]["speedScale"] == 1.2


def test_voicevox_uses_the_speaker_from_the_environment(monkeypatch):
    monkeypatch.setenv("VOICEVOX_SPEAKER", "8")
    assert VoicevoxSpeech().resolve_voice() == 8


def test_voicevox_rejects_a_non_numeric_speaker():
    with pytest.raises(ConfigError, match="数字のID"):
        VoicevoxSpeech().resolve_voice("ずんだもん")


def test_voicevox_rejects_formats_it_cannot_produce():
    with pytest.raises(ConfigError, match="wav"):
        VoicevoxSpeech(session=FakeSession()).synthesize("あ", fmt="mp3")


def test_voicevox_falls_back_when_the_credit_cannot_be_read():
    """表記が引けなくても合成そのものは失敗させない。"""
    session = FakeSession(
        [
            FakeResponse(json_data={}),
            FakeResponse(content=wav_bytes()),
            FakeResponse(json_data=[]),  # 話者一覧が空（ENGINE の版が古いなど）
        ]
    )
    clip = VoicevoxSpeech(session=session).synthesize("あ")
    assert clip.credit == "VOICEVOX"  # /speakers が無くても製品名は残す


def test_voicevox_check_reports_a_stopped_engine(monkeypatch):
    connector = VoicevoxSpeech()

    def refuse(*_args, **_kwargs):
        from imagegen.core.errors import NetworkError

        raise NetworkError("接続できません")

    monkeypatch.setattr(connector, "request", refuse)
    result = connector.check()
    assert not result.ok
    assert result.skipped  # 用意がまだなだけなので doctor 全体は失敗にしない
    assert "起動しているか" in result.detail


def test_voicevox_uses_the_url_from_the_environment(monkeypatch):
    monkeypatch.setenv("VOICEVOX_URL", "http://192.168.0.2:50021/")
    assert VoicevoxSpeech().base_url() == "http://192.168.0.2:50021"


def test_voicevox_lists_voices():
    connector = VoicevoxSpeech(session=FakeSession([FakeResponse(json_data=SPEAKERS)]))
    voices = connector.list_voices()
    assert [voice.id for voice in voices] == ["3"]
    assert voices[0].name == "ずんだもん（ノーマル）"


# --- openai_tts -------------------------------------------------------
def test_openai_tts_sends_the_expected_payload(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    session = FakeSession([FakeResponse(content=b"ID3mp3")])
    clip = OpenAISpeech(session=session).synthesize("hello", voice="nova", speed=1.5)

    method, url, kwargs = session.calls[0]
    assert (method, url) == ("POST", "https://api.openai.com/v1/audio/speech")
    assert kwargs["json"] == {
        "model": "gpt-4o-mini-tts",
        "input": "hello",
        "voice": "nova",
        "response_format": "mp3",
        "speed": 1.5,
    }
    assert clip.mime == "audio/mpeg"
    assert clip.ext == ".mp3"
    assert clip.seconds is None  # WAV 以外は長さが分からない


def test_openai_tts_honours_the_format(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    session = FakeSession([FakeResponse(content=wav_bytes())])
    clip = OpenAISpeech(session=session).synthesize("hello", fmt="wav")
    assert clip.mime == "audio/wav"


def test_openai_tts_requires_a_key():
    with pytest.raises(AuthError):
        OpenAISpeech(session=FakeSession()).synthesize("hello")


def test_openai_tts_lists_its_fixed_voices():
    assert "alloy" in [voice.id for voice in OpenAISpeech().list_voices()]


# --- elevenlabs -------------------------------------------------------
def test_elevenlabs_resolves_the_voice_from_the_account(monkeypatch):
    monkeypatch.setenv("ELEVENLABS_API_KEY", "el-test")
    session = FakeSession(
        [
            FakeResponse(json_data={"voices": [{"voice_id": "v1", "name": "Aoi", "category": "premade"}]}),
            FakeResponse(content=b"mp3"),
        ]
    )
    clip = ElevenLabsSpeech(session=session).synthesize("こんばんは")

    assert clip.voice == "v1"  # 既定の voice_id をコードに埋め込まない
    assert session.calls[1][1].endswith("/text-to-speech/v1")
    assert session.calls[1][2]["params"]["output_format"] == "mp3_44100_128"


def test_elevenlabs_prefers_the_configured_voice(monkeypatch):
    monkeypatch.setenv("ELEVENLABS_API_KEY", "el-test")
    monkeypatch.setenv("ELEVENLABS_VOICE_ID", "fixed")
    session = FakeSession([FakeResponse(content=b"mp3")])
    clip = ElevenLabsSpeech(session=session).synthesize("あ")
    assert clip.voice == "fixed"  # 一覧を引かずに済む
    assert len(session.calls) == 1


def test_elevenlabs_reports_an_empty_account(monkeypatch):
    monkeypatch.setenv("ELEVENLABS_API_KEY", "el-test")
    session = FakeSession([FakeResponse(json_data={"voices": []})])
    with pytest.raises(ConnectorError, match="ELEVENLABS_VOICE_ID"):
        ElevenLabsSpeech(session=session).synthesize("あ")


def test_elevenlabs_requires_a_key():
    with pytest.raises(AuthError):
        ElevenLabsSpeech(session=FakeSession()).synthesize("あ")


def test_elevenlabs_check_counts_the_voices(monkeypatch):
    monkeypatch.setenv("ELEVENLABS_API_KEY", "el-test")
    session = FakeSession([FakeResponse(json_data={"voices": [{"voice_id": "v1", "name": "A"}]})])
    result = ElevenLabsSpeech(session=session).check()
    assert result.ok and "1" in result.detail


# --- beep -------------------------------------------------------------
def test_beep_needs_no_key_and_produces_playable_wav():
    clip = BeepSpeech().synthesize("これはプレースホルダです")
    assert BeepSpeech().is_available()
    assert clip.mime == "audio/wav"
    with wave.open(io.BytesIO(clip.data)) as reader:
        assert reader.getnchannels() == 1
        assert reader.getframerate() == 24_000


def test_beep_length_follows_the_text():
    short = BeepSpeech().synthesize("あ" * 20).seconds
    long = BeepSpeech().synthesize("あ" * 200).seconds
    assert long > short


def test_beep_is_deterministic():
    assert BeepSpeech().synthesize("同じ文章").data == BeepSpeech().synthesize("同じ文章").data


def test_beep_speed_shortens_the_clip():
    assert BeepSpeech().synthesize("あ" * 100, speed=2.0).seconds < (
        BeepSpeech().synthesize("あ" * 100).seconds
    )


def test_beep_reading_speed_is_configurable(monkeypatch):
    monkeypatch.setenv("IMAGEGEN_BEEP_CPS", "3")
    assert estimate_seconds("あ" * 30) == pytest.approx(10.0)


def test_beep_ignores_a_broken_reading_speed(monkeypatch):
    monkeypatch.setenv("IMAGEGEN_BEEP_CPS", "はやい")
    assert estimate_seconds("あ" * 70) == pytest.approx(10.0)


def test_beep_check_is_always_ok():
    assert BeepSpeech().check().ok
