from datetime import date

import kabe

_AS_OF = date(2026, 10, 1)


def test_月収は時給x週の時間x52_12を四捨五入():
    assert kabe.monthly_pay(1100, 190) == 90_567  # 90,566.67
    assert kabe.monthly_pay(1100, 200) == 95_333  # 95,333.33
    assert kabe.monthly_pay(1000, 225) == 97_500


def test_時給1100円_東京():
    k = kabe.analyze(_AS_OF, 1100)
    # 週19時間: 90,567円、所得税0円（控除のほうが大きい）
    assert (k.pay_19, k.net_19) == (90_567, 90_567)
    # 週20時間: 95,333円 − 社会保険料13,906（標準報酬98,000）− 雇用保険477 − 所得税0
    assert (k.pay_20, k.net_20) == (95_333, 80_950)
    assert k.loss_at_20 == 9_617
    assert k.breakeven_hours_x10 == 225


def test_どの時給でも元に戻るのは週22_5時間前後():
    for h in range(1050, 1301, 50):
        assert kabe.analyze(_AS_OF, h).breakeven_hours_x10 in (220, 225, 230), h


def test_料率がない時点は出さない():
    assert kabe.analyze(date(2027, 3, 1), 1100) is None
