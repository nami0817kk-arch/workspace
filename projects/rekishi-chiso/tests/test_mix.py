import wave
from types import SimpleNamespace as NS

from chiso import mix, render


def _wav(path, seconds, rate=24000):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(b"\x01\x00" * int(seconds * rate))
    return path


def _line(i, speaker, section=0, text="あ"):
    return NS(index=i, speaker=speaker, text=text, tone="普通", section=section, pause=None)


def test_plan_audio_srt_chapters(tmp_path):
    lines = [_line(0, "語り"), _line(1, "聞き", text="《え》？"), _line(2, "語り", section=1)]
    spoken = {i: NS(wav=_wav(tmp_path / f"{i}.wav", 1.0), seconds=1.0) for i in range(3)}
    cues, total = mix.plan(lines, spoken)
    assert cues[0].start == 0.3
    assert cues[1].start > cues[0].end and cues[2].start - cues[1].end >= 1.0
    out = tmp_path / "all.wav"
    mix.write_audio(cues, total, out)
    with wave.open(str(out)) as w:
        assert abs(w.getnframes() / w.getframerate() - total) < 0.01
    s = mix.srt(cues, {"語り": "剣崎雌雄", "聞き": "春日部つむぎ"})
    assert "春日部つむぎ：え？" in s and "00:00:00,300 -->" in s
    assert mix.chapters(cues, ["始まり", "次"]) == ["0:00 始まり", f"0:{int(cues[2].start):02} 次"]


def test_concat_list_repeats_last():
    from pathlib import Path
    txt = render.concat_list([(Path("a.png"), 1.0), (Path("b.png"), 0.5)])
    assert txt.strip().splitlines()[-1] == "file 'b.png'"
    assert "duration 0.5000" in txt
