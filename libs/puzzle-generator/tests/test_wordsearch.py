import copy

import pytest

from puzzle_generator import (
    BLOCKED_WORDS,
    build_wordsearch,
    find_all,
    validate_record,
    verify_wordsearch,
)

VEGETABLES = [
    {"answer": "だいこん", "label": "だいこん（大根）"},
    {"answer": "にんじん", "label": "にんじん（人参）"},
    {"answer": "ごぼう", "label": "ごぼう（牛蒡）"},
    {"answer": "かぶ", "label": "かぶ（蕪）"},
    {"answer": "なす", "label": "なす（茄子）"},
    {"answer": "きゅうり", "label": "きゅうり（胡瓜）"},
]


def test_each_word_appears_exactly_once_for_many_seeds():
    for seed in range(40):
        rec = build_wordsearch(VEGETABLES, "easy", seed)
        assert verify_wordsearch(rec)
        validate_record(rec)
        for w in VEGETABLES:
            assert len(find_all(rec["board"]["grid"], w["answer"])) == 1


def test_uses_only_allowed_directions():
    for seed in range(20):
        rec = build_wordsearch(VEGETABLES, "medium", seed)
        assert {p["dir"] for p in rec["solution"]["placements"]} <= {"E", "S"}
    hard = build_wordsearch(VEGETABLES, "hard", 1)
    assert hard["params"]["directions"] == ["E", "S", "SE"]


def test_no_blocked_word_made_by_filler():
    for seed in range(40):
        grid = build_wordsearch(VEGETABLES, "easy", seed)["board"]["grid"]
        for bad in BLOCKED_WORDS:
            assert not find_all(grid, bad), (seed, bad)


def test_same_seed_same_board():
    a = build_wordsearch(VEGETABLES, "easy", 7)
    b = build_wordsearch(VEGETABLES, "easy", 7)
    assert a == b


def test_verify_rejects_duplicate_occurrence():
    rec = build_wordsearch(VEGETABLES, "medium", 3)
    broken = copy.deepcopy(rec)
    # 「かぶ」をもう1か所に書き込む
    grid = broken["board"]["grid"]
    p = next(p for p in broken["solution"]["placements"] if p["answer"] == "かぶ")
    for y in range(10):
        for x in range(9):
            if (x, y) != tuple(p["start"]) and (x + 1, y) != tuple(p["start"]):
                grid[y][x], grid[y][x + 1] = "か", "ぶ"
                break
        else:
            continue
        break
    assert not verify_wordsearch(broken)
    with pytest.raises(ValueError):
        validate_record(broken)


def test_rejects_word_inside_another():
    with pytest.raises(ValueError):
        build_wordsearch([{"answer": "なす", "label": "なす"}, {"answer": "おなすび", "label": "x"}], "easy", 0)


def test_katakana_script():
    words = [{"answer": a, "label": a} for a in ["コロッケ", "カレー", "オムライス", "ハンバーグ"]]
    rec = build_wordsearch(words, "medium", 5, script="katakana")
    assert verify_wordsearch(rec)
    hira = set("あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん")
    assert not any(ch in hira for row in rec["board"]["grid"] for ch in row)
