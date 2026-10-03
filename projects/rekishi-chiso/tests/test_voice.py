from types import SimpleNamespace as NS

from chiso import voice
from chiso.voice import Voice


def test_tone_params_combines_base_and_tone():
    v = Voice(style_id=8, speed=1.1, pitch=0.01, intonation=1.2, volume=1.0)
    t = voice.TONES["疑問"]
    p = voice.tone_params(v, "疑問")
    assert p["speedScale"] == round(1.1 * t["speed"], 4)
    assert p["pitchScale"] == round(0.01 + t["pitch"], 4)
    assert p["intonationScale"] == round(1.2 * t["intonation"], 4)
    assert "end_rise" not in p                            # VOICEVOX には渡さない
    assert voice.tone_params(v, "普通")["intonationScale"] == 1.2


def test_tone_params_clamped_to_voicevox_range():
    p = voice.tone_params(Voice(style_id=8, intonation=1.9, pitch=0.12), "驚き")
    assert p["intonationScale"] == 2.0 and p["pitchScale"] == 0.15


def test_end_rise_lifts_last_word_only():
    mk = lambda t, p: {"text": t, "pitch": p, "vowel_length": 0.1}
    q = {"accent_phrases": [{"moras": [mk("エ", 5.5)]}, {"moras": [mk("ホ", 5.6), mk("ン", 5.5), mk("ト", 5.4)]}]}
    out = voice.end_rise(q, 0.3)
    last = out["accent_phrases"][-1]["moras"]
    assert last[0]["pitch"] == 5.6                       # 最後の2モーラだけ
    assert last[1]["pitch"] == round(5.5 + 0.15, 4) and last[2]["pitch"] == round(5.4 + 0.3, 4)
    assert out["accent_phrases"][0]["moras"][0]["pitch"] == 5.5
    assert voice.end_rise(q, 0) is q


def test_split_emphasis_and_display():
    text, words = voice.split_emphasis("ざっと《3000年分》です")
    assert text == "ざっと3000年分です" and words == ["3000年分"]
    assert voice.display_text("《地表》") == "地表"


def test_readings_longest_first():
    r = {"マリー": "X", "マリー・アントワネット": "Y"}
    assert voice.apply_readings("マリー・アントワネットとマリー", r) == "YとX"


def _q():
    mk = lambda t, p: {"text": t, "pitch": p, "vowel_length": 0.1}
    return {"accent_phrases": [
        {"moras": [mk("ザ", 5.5), mk("ッ", 0.0), mk("ト", 5.6)]},
        {"moras": [mk("サン", 5.8), mk("ゼン", 5.7), mk("ネン", 5.6)]},
    ], "volumeScale": 1.0}


def test_emphasize_raises_only_the_word():
    q, missing = voice.emphasize(_q(), ["サンゼン"])
    moras = [m for p in q["accent_phrases"] for m in p["moras"]]
    assert missing == []
    assert moras[3]["pitch"] == round(5.8 + voice.EMPHASIS_PITCH, 4)
    assert moras[4]["pitch"] == round(5.7 + voice.EMPHASIS_PITCH, 4)
    assert moras[5]["pitch"] == 5.6                       # 語の外は変えない
    assert moras[1]["pitch"] == 0.0                       # 無声のモーラは触らない
    assert q["volumeScale"] > 1.0


def test_emphasize_reports_missing():
    _, missing = voice.emphasize(_q(), ["ナイ"])
    assert missing == ["ナイ"]


def L(speaker, text="あ", tone="普通", section=0, pause=None):
    return NS(speaker=speaker, text=text, tone=tone, section=section, pause=pause)


def test_gaps_follow_the_conversation():
    assert voice.gap_before(L("語り"), L("聞き", tone="驚き")) == voice.GAP_REACTION
    assert voice.gap_before(L("聞き", "本当？"), L("語り")) == voice.GAP_ANSWER
    assert voice.gap_before(L("語り"), L("語り")) == voice.GAP_SAME_SPEAKER
    assert voice.gap_before(L("語り"), L("聞き")) == voice.GAP_TURN
    assert voice.gap_before(L("語り", section=0), L("聞き", section=1)) == voice.GAP_SECTION
    assert voice.gap_before(L("語り", tone="重い"), L("聞き")) == voice.GAP_AFTER_HEAVY
    assert voice.gap_before(L("語り"), L("聞き", pause=2.0)) == 2.0
