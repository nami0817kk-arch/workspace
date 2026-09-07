import wave

import pytest

from src.config import build_config
from src.inserts import Inserts, apply_timing, audio_segments, plan, realize_audio
from src.script_model import parse_script

CAST = {"キャスター": {"key": "anchor", "style_id": 2}}
SCRIPT = "## 章1\nキャスター: あ。\nキャスター: い。\n\n## 章2\nキャスター: う。\n\n## 章3\nキャスター: え。\n"


def _script():
    script = parse_script(SCRIPT)
    for line in script.lines:
        line.duration = 2.0
    return script


def _config(**titles):
    base = {"intro": 2.6, "chapter": 1.4, "outro": 3.0}
    return build_config({"cast": CAST, "titles": {**base, **titles}})


def test_plan_puts_chapter_cards_after_the_first_scene():
    inserts = plan(_script(), _config())
    assert inserts.intro == 2.6
    # 冒頭タイトルの直後になるので、1つ目の章には章タイトルを入れない
    assert inserts.chapters == {1: 1.4, 2: 1.4}
    assert inserts.outro == 3.0
    assert inserts.total == pytest.approx(2.6 + 1.4 * 2 + 3.0)


def test_最初の章にはカードを入れない_冒頭タイトルの有無によらず():
    """2026-09-07 に方針を変えた。

    元は「冒頭タイトルが無いときは最初の章にカードを入れる」だった。
    ところが冒頭タイトルを 0 にしたとたん、代わりに章タイトル（「オープニング 1/6」）が
    1.4秒出るようになり、**静止したカードの種類が入れ替わっただけ**になった
    （書き出して初めて気づいた）。狙いは0秒目から本編を始めることなので、
    どちらのカードも冒頭には置かない。
    """
    inserts = plan(_script(), _config(intro=0))
    assert inserts.intro == 0.0
    assert set(inserts.chapters) == {1, 2}


def test_titles_can_be_switched_off():
    inserts = plan(_script(), _config(intro=0, chapter=0, outro=0))
    assert inserts.total == 0.0


def test_outro_does_not_shift_any_line():
    """末尾のカードは全セリフの後ろなので、開始時刻には影響しない。"""
    script = _script()
    apply_timing(script, plan(script, _config(outro=5.0)))
    assert script.lines[0].start == pytest.approx(2.6)
    assert script.lines[-1].start == pytest.approx(11.4)


def test_apply_timing_shifts_every_line():
    script = _script()
    apply_timing(script, plan(script, _config()))

    first, second, third, fourth = script.lines
    assert first.start == pytest.approx(2.6)          # 冒頭タイトルのぶん
    assert second.start == pytest.approx(4.6)
    assert third.start == pytest.approx(8.0)          # + 章タイトル 1.4
    assert fourth.start == pytest.approx(11.4)


def test_timing_without_inserts_starts_at_zero():
    script = _script()
    apply_timing(script, Inserts())
    assert script.lines[0].start == 0.0


def test_audio_segments_interleave_silence(tmp_path):
    script = _script()
    for index, line in enumerate(script.lines):
        line.audio_path = tmp_path / f"{index}.wav"
    inserts = plan(script, _config())

    segments = audio_segments(script, inserts)
    gaps = [seconds for path, seconds in segments if path is None]
    assert gaps == [2.6, 1.4, 1.4, 3.0]      # 冒頭・章2つ・末尾
    assert segments[-1][0] is None            # 最後は無音（エンディングカード）
    assert len(segments) == len(script.lines) + 4


def test_realize_audio_matches_the_voice_format(tmp_path):
    voice = tmp_path / "voice.wav"
    with wave.open(str(voice), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(24000)
        out.writeframes(b"\x00" * 2 * 24000)

    paths = realize_audio([(None, 1.0), (voice, 1.0)], tmp_path / "gaps")
    with wave.open(str(paths[0]), "rb") as silence:
        assert silence.getframerate() == 24000
        assert silence.getnchannels() == 1
        assert silence.getnframes() == 24000


def test_最初の章にはカードを入れない():
    """冒頭タイトルの有無に関係なく入れない。

    以前は「冒頭タイトルがあるときだけ飛ばす」だったので、冒頭タイトルを 0 に
    したら代わりに章タイトルが1.4秒出た（2026-09-07、書き出して気づいた）。
    静止したカードの種類が入れ替わるだけで、0秒目から本編を始められない。
    """
    from dataclasses import replace

    from src.config import load_config
    from src.inserts import plan
    from src.script_model import Line, Scene, Script

    script = Script(
        title="t",
        scenes=[Scene(title=f"章{i}", lines=[Line(speaker="キャスター", text="本文")])
                for i in range(3)],
    )
    config = load_config()
    for intro in (0.0, 2.6):
        tuned = replace(config, titles=replace(config.titles, intro=intro, chapter=1.4))
        inserts = plan(script, tuned)
        assert 0 not in inserts.chapters, f"intro={intro} で最初の章にカードが入っている"
        assert inserts.chapters.get(1) == 1.4
