"""演出のリズムの見積もり(plan から)。clips/ が無い CI でも回るよう、キーだけの台本を使う。"""
from pathlib import Path

from stickfig import plan as planmod, rhythm

ROOT = Path(__file__).resolve().parent.parent


def test_plan_metrics_keys_and_ranges():
    pl = planmod.build_plan(planmod.load_scene(ROOT / "scenes" / "showpiece.yaml"))
    m = rhythm.plan_metrics(pl)
    assert set(m) == {"cuts_per_min", "dup_frame_ratio", "flash_groups_per_min", "shake_frame_ratio"}
    assert 0 <= m["dup_frame_ratio"] <= 1 and 0 <= m["shake_frame_ratio"] <= 1
    assert "演出のリズム" in rhythm.plan_report(pl)


def test_reference_ranges_are_ordered():
    for lo, hi, _ in rhythm.REFERENCE.values():
        assert lo < hi


def test_sfx_renders_and_peaks_at_events(tmp_path):
    import wave
    import numpy as np
    from stickfig import sfx
    pl = planmod.build_plan(planmod.load_scene(ROOT / "scenes" / "showpiece.yaml"))
    path = sfx.render(pl, tmp_path / "a.wav", "battle")
    w = wave.open(path)
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    assert not np.isnan(x).any() and np.abs(x).max() > 3000
    assert abs(w.getnframes() / w.getframerate() - pl["n"] / pl["fps"]) < 0.1
