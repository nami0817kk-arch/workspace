from datetime import date

import pytest

import eligibility as elig


def test_2024年10月時点は賃金要件あり_51人以上():
    r = elig.regime_for(date(2025, 1, 1))
    assert r.company_size_threshold == 51
    assert r.wage_requirement_yen == 88_000


def test_2026年10月に賃金要件が消える():
    before = elig.regime_for(date(2026, 9, 30))
    after = elig.regime_for(date(2026, 10, 1))
    assert before.wage_requirement_yen == 88_000
    assert after.wage_requirement_yen is None
    # 企業規模要件はこの段階では変わらない
    assert after.company_size_threshold == 51


@pytest.mark.parametrize(
    "d, expected_threshold",
    [
        (date(2027, 9, 30), 51),
        (date(2027, 10, 1), 36),
        (date(2029, 9, 30), 36),
        (date(2029, 10, 1), 21),
        (date(2032, 10, 1), 11),
        (date(2035, 10, 1), None),
        (date(2040, 1, 1), None),  # 撤廃後は将来もそのまま
    ],
)
def test_企業規模要件の段階(d, expected_threshold):
    assert elig.regime_for(d).company_size_threshold == expected_threshold


def test_範囲外の日付は例外():
    with pytest.raises(elig.ScheduleOutOfRange):
        elig.regime_for(date(2024, 9, 30))


def test_全部満たせば加入対象():
    result = elig.evaluate(
        as_of=date(2026, 10, 1),
        weekly_hours=20,
        monthly_wage_yen=90_000,
        is_student=False,
        employer_size=60,
    )
    assert result.eligible is True
    assert result.hours_ok and result.wage_ok and result.not_student_ok and result.employer_size_ok


def test_週19時間は対象外():
    result = elig.evaluate(
        as_of=date(2026, 10, 1),
        weekly_hours=19,
        monthly_wage_yen=200_000,
        is_student=False,
        employer_size=1000,
    )
    assert result.eligible is False
    assert result.hours_ok is False


def test_2026年10月より前は賃金8_8万未満だと対象外():
    result = elig.evaluate(
        as_of=date(2026, 9, 1),
        weekly_hours=25,
        monthly_wage_yen=80_000,
        is_student=False,
        employer_size=100,
    )
    assert result.eligible is False
    assert result.wage_ok is False


def test_2026年10月以降は賃金が低くても賃金要件はクリアする():
    """賃金要件が撤廃されるので、他が満たされていれば8.8万円未満でも対象になりうる。"""
    result = elig.evaluate(
        as_of=date(2026, 10, 1),
        weekly_hours=20,
        monthly_wage_yen=50_000,
        is_student=False,
        employer_size=51,
    )
    assert result.wage_ok is True
    assert result.eligible is True


def test_学生は対象外():
    result = elig.evaluate(
        as_of=date(2026, 10, 1),
        weekly_hours=30,
        monthly_wage_yen=100_000,
        is_student=True,
        employer_size=200,
    )
    assert result.eligible is False
    assert result.not_student_ok is False


def test_従業員数が要件未満だと対象外():
    result = elig.evaluate(
        as_of=date(2027, 10, 1),
        weekly_hours=25,
        monthly_wage_yen=100_000,
        is_student=False,
        employer_size=35,  # 2027年10月時点の要件は36人以上
    )
    assert result.eligible is False
    assert result.employer_size_ok is False


def test_2035年10月以降は企業規模を問わない():
    result = elig.evaluate(
        as_of=date(2035, 10, 1),
        weekly_hours=20,
        monthly_wage_yen=90_000,
        is_student=False,
        employer_size=1,
    )
    assert result.employer_size_ok is True
    assert result.eligible is True


def test_境界値ちょうどは満たす扱い():
    """「以上」は境界を含む。20時間ちょうど・要件人数ちょうどでも対象。"""
    result = elig.evaluate(
        as_of=date(2027, 10, 1),
        weekly_hours=20,
        monthly_wage_yen=88_000,
        is_student=False,
        employer_size=36,
    )
    assert result.eligible is True


def test_MILESTONESは2026年10月以降の5件():
    assert len(elig.MILESTONES) == 5
    assert [m.effective_from.isoformat() for m in elig.MILESTONES] == [
        "2026-10-01", "2027-10-01", "2029-10-01", "2032-10-01", "2035-10-01",
    ]


def test_SCHEDULEは古い順():
    dates = [r.effective_from for r in elig.SCHEDULE]
    assert dates == sorted(dates)
