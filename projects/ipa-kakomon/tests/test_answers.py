import pytest

from src.answers import Answer, missing_numbers, parse_text

# 実物（令和7年度秋期 応用情報 午前）の冒頭。4問ぶんが横に並ぶ形をそのまま使う。
REAL_ROW = "問1 エ テ 問21 イ テ 問41 イ テ 問61 イ ス"


def test_1行から4問ぶん拾える():
    answers = parse_text(REAL_ROW)
    assert [(a.number, a.choice) for a in answers] == [
        (1, "エ"),
        (21, "イ"),
        (41, "イ"),
        (61, "イ"),
    ]


def test_問番号の順に並べ直す():
    answers = parse_text("問10 ア\n問2 イ\n問33 ウ")
    assert [a.number for a in answers] == [2, 10, 33]


def test_分野記号が無い年度でも拾える():
    answers = parse_text("問1 ア 問2 イ")
    assert len(answers) == 2


def test_同じ問番号が同じ正解なら重複しない():
    answers = parse_text("問5 ウ\n問5 ウ")
    assert [(a.number, a.choice) for a in answers] == [(5, "ウ")]


def test_同じ問番号で正解が食い違ったら例外():
    # 黙って上書きすると、誤った正解を載せたまま公開してしまう。
    with pytest.raises(ValueError, match="問5 の正解が二通り"):
        parse_text("問5 ウ\n問5 エ")


def test_選択肢以外の記号は正解として拾わない():
    # 分野記号（テ・ス など）を正解と取り違えないこと。
    assert parse_text("問1 テ") == []


def test_空文字なら空リスト():
    assert parse_text("") == []


def test_欠番を報告する():
    answers = [Answer(number=1, choice="ア"), Answer(number=3, choice="イ")]
    assert missing_numbers(answers, expected=4) == [2, 4]


def test_欠番が無ければ空():
    answers = [Answer(number=n, choice="ア") for n in range(1, 5)]
    assert missing_numbers(answers, expected=4) == []


@pytest.mark.parametrize("number", [0, 101])
def test_問番号が範囲外なら作れない(number):
    with pytest.raises(ValueError, match="問番号が範囲外"):
        Answer(number=number, choice="ア")


def test_正解の記号が不正なら作れない():
    with pytest.raises(ValueError, match="正解の記号が不正"):
        Answer(number=1, choice="テ")
