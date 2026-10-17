import json
import wave
from array import array
from types import SimpleNamespace as NS

from chiso import mix, sfx


def _cue(start, end, section=0, speaker="語り", tone="普通", figure=None):
    return NS(start=start, end=end, line=NS(section=section, speaker=speaker, tone=tone, figure=figure))


def test_events_follow_the_screen():
    money = json.dumps({"type": "money"})
    cues = [_cue(0, 2), _cue(2.5, 3, speaker="聞き", tone="驚き"), _cue(4, 5, speaker="聞き", tone="驚き"),
            _cue(7, 8, section=1, figure=money), _cue(9, 10, section=1, figure=money)]
    evs = sfx.events(cues)
    names = [n for _, n in evs]
    assert names.count("pop") == 1                       # 20秒以内の2回目の驚きは鳴らさない
    assert (5, "rumble") in evs                          # 節の頭のワイプは前の行の話し終わりから
    assert (7, "whoosh") in evs and (7 + sfx.FIG_SECONDS, "coin") in evs
    assert names.count("whoosh") == 1                    # 同じ図が続くあいだは鳴らさない


def test_overlay_is_quiet_and_clipped(tmp_path):
    rate = 24000
    w = tmp_path / "a.wav"
    with wave.open(str(w), "wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(rate)
        f.writeframes(b"\x00\x00" * rate)
    out = tmp_path / "o.wav"
    mix.write_audio([NS(start=0.0, end=1.0, wav=w, line=None)], 2.0, out, effects=[(0.5, "rumble"), (1.9, "coin")])
    with wave.open(str(out)) as f:
        s = array("h"); s.frombytes(f.readframes(f.getnframes()))
    assert len(s) == 2 * rate                             # はみ出した効果音は切る
    assert 0 < max(abs(x) for x in s) < 32767 * 0.5       # 声より小さい
