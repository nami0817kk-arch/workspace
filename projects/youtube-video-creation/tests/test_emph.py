"""山を作る行（2026-10-03「動画の質を上げる仕組み ④」）。"""
from src.config import CastMember
from src.research import to_script
from src.script_model import parse_script
from src.tts import _digest, voice_params


def test_台本のemphが行に入る():
    s = parse_script("## オープニング\n\nキャスター: 題です。\n\n## 本編\n\n解説: なんと2.2億ユーロ。\n  emph: true\n")
    line = s.scenes[1].lines[0]
    assert line.emph is True
    assert s.scenes[0].lines[0].emph is False


def test_emphの行だけ抑揚を強める():
    member = CastMember(name="解説", key="kaisetsu", style_id=13, speed=1.2, pitch=0.0, intonation=1.0)
    s = parse_script("## a\n\n解説: 普通の行。\n\n解説: 山の行。\n  emph: true\n")
    plain, emph = s.scenes[0].lines
    assert voice_params(plain, member) == (1.2, 0.0, 1.0)
    speed, pitch, intonation = voice_params(emph, member)
    assert intonation > 1.0 and speed < 1.2 and pitch > 0.0
    # 山の行は別の鍵で合成し直す。山の無い行の鍵は変わらない
    assert _digest(plain, member, 0.0, "x") != _digest(emph, member, 0.0, "x")


def test_取材メモのemphが台本に出る():
    import yaml
    from pathlib import Path
    from src.plan import load_plan
    from src.research import build_notes

    raw = yaml.safe_load(Path("research/20261003_kubo_marriage.yaml").read_text(encoding="utf-8"))
    say = raw["sections"][2]["say"]           # 見立ての節
    say[0] = {"text": say[0]["text"] if isinstance(say[0], dict) else say[0], "emph": True}
    text = to_script(build_notes(raw), load_plan())
    assert text.count("  emph: true") == 1
    script = parse_script(text)
    assert sum(1 for line in script.lines if line.emph) == 1
