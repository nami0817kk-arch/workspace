"""パターン検出の純粋なヘルパのテスト。ネットワーク・DB不要。"""
import pandas as pd

from src.analysis.pattern_detector import _cv, _nearest_round


def test_cv_is_zero_for_flat_prices():
    assert _cv(pd.Series([100.0, 100.0, 100.0])) == 0.0


def test_cv_grows_with_volatility():
    calm = _cv(pd.Series([100, 101, 99, 100], dtype=float))
    wild = _cv(pd.Series([100, 130, 70, 100], dtype=float))
    assert wild > calm


def test_nearest_round_snaps_within_tolerance():
    assert _nearest_round(498.0) == 500.0
    assert _nearest_round(1010.0) == 1000.0


def test_nearest_round_returns_none_when_far_from_round_number():
    assert _nearest_round(475.0) is None
