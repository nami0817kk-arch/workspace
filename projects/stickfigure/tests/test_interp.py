import math

import pytest

from stickfig.interp import Curve, Spring, build_timeline, pchip_tangents, smoothstep


def test_pchip_passes_through_keys():
    c = Curve([0, 1, 2, 3], [0, 2, 1, 5])
    for t, y in zip([0, 1, 2, 3], [0, 2, 1, 5]):
        assert c(t) == pytest.approx(y)


def test_pchip_does_not_overshoot():
    c = Curve([0, 1, 2], [0, 1, 1])
    assert all(c(t / 100) <= 1.0 + 1e-9 for t in range(0, 201))


def test_pchip_velocity_is_continuous_at_keys():
    """区間ごとのイーズだと、要の姿勢で速度が0になる(カクカクの原因)。PCHIP は途切れない。"""
    c = Curve([0, 1, 2, 3], [0, 1, 2, 3])
    h = 1e-4
    for t in (1.0, 2.0):
        v_before = (c(t) - c(t - h)) / h
        v_after = (c(t + h) - c(t)) / h
        assert v_before == pytest.approx(v_after, abs=1e-3)
        assert v_before > 0.5


def test_pchip_flat_at_turning_point():
    c = Curve([0, 1, 2], [0, 1, 0])
    assert pchip_tangents([0, 1, 2], [0, 1, 0])[1] == 0.0


def test_curve_rejects_unsorted_times():
    with pytest.raises(ValueError):
        Curve([0, 2, 1], [0, 1, 2])


def test_spring_overshoots_then_settles():
    sp = Spring(0.0, k=500, zeta=0.4)
    xs = [sp.step(1.0, 1 / 30) for _ in range(120)]
    assert max(xs) > 1.0           # 行き過ぎる
    assert xs[-1] == pytest.approx(1.0, abs=0.02)


def test_spring_frozen_when_dt_zero():
    sp = Spring(0.0, k=500, zeta=0.4)
    sp.step(1.0, 1 / 30)
    x = sp.x
    assert sp.step(1.0, 0.0) == x


def test_timeline_holds_at_hits():
    taus, ev = build_timeline(2.0, 30, hits=[dict(tau=1.0, hold=0.1, kind="kick")])
    assert ev[0]["kind"] == "kick" and ev[0]["hold_frames"] == 3
    f = ev[0]["frame"]
    assert taus[f] == pytest.approx(1.0)
    assert taus[f + 1] == taus[f]          # 止まっている
    assert taus[f + 4] > taus[f]           # また進み出す


def test_timeline_slow_motion_is_smooth():
    taus, _ = build_timeline(3.0, 30, hits=[], slow=[dict(start=1.0, end=1.5, rate=0.3)])
    steps = [b - a for a, b in zip(taus, taus[1:])]
    assert min(steps) < 0.5 / 30           # スローの中は遅い
    assert max(abs(b - a) for a, b in zip(steps, steps[1:])) < 0.7 / 30   # 速度が急に飛ばない


def test_smoothstep_bounds():
    assert smoothstep(-1, 0, 1) == 0.0 and smoothstep(2, 0, 1) == 1.0
    assert smoothstep(0.5, 0, 1) == pytest.approx(0.5)
