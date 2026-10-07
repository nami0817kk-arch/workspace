import copy

import pytest

from puzzle_generator import (
    build_arithmetic,
    build_clock,
    build_number_search,
    build_pair_search,
    validate_record,
)

ICONS = [f"i{k:02d}" for k in range(60)]


@pytest.mark.parametrize("level", ["easy", "medium", "hard"])
def test_arithmetic_answers_and_no_negative(level):
    for seed in range(30):
        rec = build_arithmetic(level, seed)
        validate_record(rec)
        assert all(a >= 0 for a in rec["solution"]["answers"])
        assert len({(p["a"], p["op"], p["b"]) for p in rec["board"]["problems"]}) == 10


def test_arithmetic_rejects_wrong_answer():
    rec = build_arithmetic("medium", 1)
    bad = copy.deepcopy(rec)
    bad["solution"]["answers"][0] += 1
    with pytest.raises(ValueError):
        validate_record(bad)


def test_number_search_is_permutation():
    for seed in range(20):
        rec = build_number_search(5, seed)
        validate_record(rec)
    bad = copy.deepcopy(rec)
    bad["board"]["grid"][0][0], bad["board"]["grid"][0][1] = bad["board"]["grid"][0][1], bad["board"]["grid"][0][0]
    with pytest.raises(ValueError):
        validate_record(bad)


@pytest.mark.parametrize("level,step", [("easy", 30), ("medium", 15), ("hard", 5)])
def test_clock_step(level, step):
    rec = build_clock(level, 3)
    validate_record(rec)
    assert all(m % step == 0 for _, m in rec["board"]["times"])
    assert rec["solution"]["answers"][0].startswith(str(rec["board"]["times"][0][0]) + "時")


def test_pair_search_exactly_one_pair():
    for seed in range(40):
        rec = build_pair_search(ICONS, 6, 6, seed)
        validate_record(rec)
    bad = copy.deepcopy(rec)
    g = bad["board"]["grid"]
    g[0][0] = g[0][1] if (0, 0) not in map(tuple, bad["solution"]["pair"]) else g[5][5]
    with pytest.raises(ValueError):
        validate_record(bad)


def test_pair_search_needs_enough_icons():
    with pytest.raises(ValueError):
        build_pair_search(ICONS[:10], 6, 6, 0)
