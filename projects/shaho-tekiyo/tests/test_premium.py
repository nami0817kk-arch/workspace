from datetime import date
from fractions import Fraction

import pytest

import premium

_AS_OF = date(2026, 10, 1)


def test_収録は47都道府県():
    assert len(premium.PREFECTURES) == 47
    assert premium.PREFECTURES[0] == "北海道"
    assert premium.PREFECTURES[-1] == "沖縄"


@pytest.mark.parametrize(
    "amount, expected",
    [
        (Fraction(45232, 10), 4523),  # 4523.2 → 切り捨て
        (Fraction(1265, 10), 126),  # ちょうど50銭 → 切り捨て
        (Fraction(12651, 100), 127),  # 50銭を超える → 切り上げ
        (Fraction(8052), 8052),
    ],
)
def test_天引きの端数処理は50銭以下切り捨て(amount, expected):
    assert premium.payroll_round(amount) == expected


@pytest.mark.parametrize(
    "pay, health_std, pension_std",
    [
        (50_000, 58_000, 88_000),  # 厚生年金の1等級は93,000円未満すべて
        (62_999, 58_000, 88_000),
        (63_000, 68_000, 88_000),
        (92_999, 88_000, 88_000),
        (93_000, 98_000, 98_000),
        (700_000, 710_000, 650_000),  # 厚生年金は65万円が上限
        (2_000_000, 1_390_000, 650_000),
    ],
)
def test_標準報酬月額の等級(pay, health_std, pension_std):
    t = premium.table_for(_AS_OF)
    assert premium.standard_monthly(t.health_grades, pay)[1] == health_std
    assert premium.standard_monthly(t.pension_grades, pay)[1] == pension_std


# 協会けんぽ「令和8年度保険料額表」北海道支部の折半額（額表の数字を天引きの端数処理にかけたもの）。
# 額表: 88,000 → 健保 4,523.2 / 介護込み 5,236 / 支援金 101.2 / 厚年 8,052
#       110,000 → 健保 5,654 / 介護込み 6,545 / 支援金 126.5 / 厚年 10,065
@pytest.mark.parametrize(
    "pay, care, health, kodomo, pension",
    [
        (88_000, False, 4523, 101, 8052),
        (88_000, True, 5236, 101, 8052),
        (110_000, False, 5654, 126, 10065),
        (110_000, True, 6545, 126, 10065),
    ],
)
def test_額表の折半額と一致する_北海道(pay, care, health, kodomo, pension):
    r = premium.estimate(as_of=_AS_OF, prefecture="北海道", monthly_pay_yen=pay, age_40_to_64=care)
    assert (r.health_yen, r.kodomo_yen, r.pension_yen) == (health, kodomo, pension)
    assert r.total_yen == health + kodomo + pension
    assert r.take_home_yen == pay - r.total_yen


def test_都道府県で健康保険料が変わる():
    kw = dict(as_of=_AS_OF, monthly_pay_yen=150_000, age_40_to_64=False)
    tokyo = premium.estimate(prefecture="東京", **kw)
    saga = premium.estimate(prefecture="佐賀", **kw)
    assert tokyo.health_yen == 7387  # 150,000 × 9.85% ÷ 2 = 7,387.5 → 切り捨て
    assert saga.health_yen > tokyo.health_yen
    assert tokyo.pension_yen == saga.pension_yen == 13725  # 厚生年金は全国一律 18.3%


@pytest.mark.parametrize("d", [date(2026, 3, 31), date(2027, 3, 1), date(2030, 1, 1)])
def test_収録していない時点は黙って計算しない(d):
    with pytest.raises(premium.RatesOutOfRange):
        premium.estimate(as_of=d, prefecture="東京", monthly_pay_yen=100_000, age_40_to_64=False)


def test_料率表の全国一律の率():
    t = premium.table_for(_AS_OF)
    for rates in t.prefectures.values():
        assert rates["pension"] == 18300
        assert rates["care"] == 1620
        assert rates["kodomo"] == 230
