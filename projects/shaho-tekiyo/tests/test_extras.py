from datetime import date

import pytest

import extras

_AS_OF = date(2026, 10, 1)


def test_雇用保険料は5_1000で50銭以下切り捨て():
    assert extras.employment_yen(_AS_OF, 100_000) == 500
    assert extras.employment_yen(_AS_OF, 100_100) == 500  # 500.5 → 切り捨て
    assert extras.employment_yen(_AS_OF, 100_101) == 501  # 500.505 → 切り上げ


def test_収録外の時点は出さない():
    assert extras.employment_yen(date(2027, 4, 1), 100_000) is None
    assert extras.kokumin_nenkin_yen(date(2026, 3, 31)) is None


def test_国民年金は令和8年度17920円():
    assert extras.kokumin_nenkin_yen(_AS_OF) == 17_920


def test_将来の年金は標準報酬x5481_1000x12():
    assert extras.pension_increase_per_year(98_000) == 6_445  # 6,445.656 → 切り捨て


@pytest.mark.parametrize("standard, expected", [(170_000, 3_780), (98_000, 2_180)])
def test_傷病手当金の日額(standard, expected):
    # 17万円 → 5,670円（÷30、10円未満四捨五入）× 2/3 = 3,780円（協会けんぽの計算例）
    assert extras.sickness_daily_yen(standard) == expected


@pytest.mark.parametrize("short, full", [("北海道", "北海道"), ("東京", "東京都"), ("大阪", "大阪府"), ("京都", "京都府"), ("沖縄", "沖縄県")])
def test_都道府県の正式名(short, full):
    assert extras.pref_full(short) == full
