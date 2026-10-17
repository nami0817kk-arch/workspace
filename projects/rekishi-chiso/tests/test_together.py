import wave
from array import array
from types import SimpleNamespace as NS

from chiso import tts
from chiso.voice import Voice


def _wav(path, values, rate=24000):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(array("h", values).tobytes())
    return path


def test_together_mixes_both_voices(tmp_path, monkeypatch):
    a = _wav(tmp_path / "a.wav", [10000] * 100)
    b = _wav(tmp_path / "b.wav", [10000] * 300)
    made = iter([tts.Spoken(a, 100 / 24000, []), tts.Spoken(b, 300 / 24000, ["x"])])
    monkeypatch.setattr(tts, "speak", lambda *args, **kw: next(made))
    line = NS(speaker="二人", text="また一緒に、掘りましょう！", tone="明るい")
    s = tts.speak_line(None, line, {"語り": Voice(21), "聞き": Voice(8)}, {}, tmp_path)
    with wave.open(str(s.wav)) as w:
        out = array("h"); out.frombytes(w.readframes(w.getnframes()))
    assert len(out) == 300 and abs(s.seconds - 300 / 24000) < 1e-9          # 長い方に合わせる
    assert out[0] == 13000 and out[200] == 6500                              # 重なるところは足し、割れない大きさ
    assert s.missing_emphasis == ["x"]
