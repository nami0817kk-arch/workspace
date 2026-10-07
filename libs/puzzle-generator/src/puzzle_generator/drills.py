"""脳トレ用の小さなパズル（計算・数字さがし・時計・同じ絵さがし）。

形は SCHEMA.md の「脳トレ用の小さなパズル」。どれも答えを計算で出せるので、
検証は「形が崩れていないか」と「答えが問題から再計算して一致するか」を見る。
"""

from __future__ import annotations

import random

from .schema import SCHEMA_VERSION


def _envelope(kind: str, seed: int, difficulty: str, params: dict, board: dict, solution: dict) -> dict:
    return {
        "schema_version": SCHEMA_VERSION,
        "type": kind,
        "id": f"{kind}-{seed}",
        "seed": seed,
        "difficulty": difficulty,
        "params": params,
        "board": board,
        "solution": solution,
        "verified": True,
        "generator": {"name": "puzzle-generator", "algorithm": "drills"},
    }


# --- 計算 -------------------------------------------------------------------

ARITHMETIC_LEVELS = {
    # 高齢者向けの紙面なので、答えは3桁まで。引き算は答えが0以上
    "easy": {"digits": 1, "ops": ["+", "-"]},
    "medium": {"digits": 2, "ops": ["+", "-"]},
    "hard": {"digits": 2, "ops": ["+", "-", "×"]},
}


def _calc(a: int, op: str, b: int) -> int:
    return a + b if op == "+" else a - b if op == "-" else a * b


def build_arithmetic(difficulty: str, seed: int, count: int = 10) -> dict:
    lv = ARITHMETIC_LEVELS[difficulty]
    rng = random.Random(seed)
    lo, hi = (1, 9) if lv["digits"] == 1 else (10, 99)
    problems, seen = [], set()
    while len(problems) < count:
        op = rng.choice(lv["ops"])
        if op == "×":
            a, b = rng.randint(11, 49), rng.randint(2, 9)  # 2桁×1桁
        else:
            a, b = rng.randint(lo, hi), rng.randint(lo, hi)
            if op == "-" and b > a:
                a, b = b, a
        if (a, op, b) in seen or (op == "-" and a == b):
            continue
        seen.add((a, op, b))
        problems.append({"a": a, "op": op, "b": b})
    answers = [_calc(p["a"], p["op"], p["b"]) for p in problems]
    return _envelope("arithmetic", seed, difficulty, {"count": count, **lv},
                     {"problems": problems}, {"answers": answers})


def verify_arithmetic(rec: dict) -> bool:
    probs, ans = rec["board"]["problems"], rec["solution"]["answers"]
    return len(probs) == len(ans) and all(
        _calc(p["a"], p["op"], p["b"]) == a and a >= 0 for p, a in zip(probs, ans)
    )


# --- 数字さがし ---------------------------------------------------------------


def build_number_search(size: int, seed: int, difficulty: str = "easy") -> dict:
    rng = random.Random(seed)
    nums = list(range(1, size * size + 1))
    rng.shuffle(nums)
    grid = [nums[y * size:(y + 1) * size] for y in range(size)]
    pos = {grid[y][x]: [x, y] for y in range(size) for x in range(size)}
    order = [pos[k] for k in range(1, size * size + 1)]
    return _envelope("number_search", seed, difficulty, {"size": size},
                     {"size": size, "grid": grid}, {"order": order})


def verify_number_search(rec: dict) -> bool:
    size, grid = rec["board"]["size"], rec["board"]["grid"]
    flat = sorted(v for row in grid for v in row)
    if flat != list(range(1, size * size + 1)):
        return False
    return all(grid[y][x] == k + 1 for k, (x, y) in enumerate(rec["solution"]["order"]))


# --- 時計 --------------------------------------------------------------------

CLOCK_LEVELS = {"easy": 30, "medium": 15, "hard": 5}


def clock_label(h: int, m: int) -> str:
    return f"{h}時" if m == 0 else f"{h}時{m}分"


def build_clock(difficulty: str, seed: int, count: int = 3) -> dict:
    step = CLOCK_LEVELS[difficulty]
    rng = random.Random(seed)
    times, seen = [], set()
    while len(times) < count:
        t = (rng.randint(1, 12), rng.randrange(0, 60, step))
        if t not in seen:
            seen.add(t)
            times.append(list(t))
    return _envelope("clock", seed, difficulty, {"count": count, "step": step},
                     {"times": times}, {"answers": [clock_label(h, m) for h, m in times]})


def verify_clock(rec: dict) -> bool:
    step = rec["params"]["step"]
    return all(
        1 <= h <= 12 and 0 <= m < 60 and m % step == 0 and a == clock_label(h, m)
        for (h, m), a in zip(rec["board"]["times"], rec["solution"]["answers"])
    )


# --- 同じ絵さがし --------------------------------------------------------------


def build_pair_search(icons: list[str], rows: int, cols: int, seed: int, difficulty: str = "easy") -> dict:
    """icons から rows×cols の盤面を作る。ちょうど1組だけ同じ絵が入る。"""
    n = rows * cols
    if len(set(icons)) < n - 1:
        raise ValueError(f"絵が足りない: {len(set(icons))} < {n - 1}")
    rng = random.Random(seed)
    chosen = rng.sample(sorted(set(icons)), n - 1)
    cells = chosen + [rng.choice(chosen)]
    rng.shuffle(cells)
    grid = [cells[y * cols:(y + 1) * cols] for y in range(rows)]
    dup = next(c for c in cells if cells.count(c) == 2)
    pair = [[x, y] for y in range(rows) for x in range(cols) if grid[y][x] == dup]
    return _envelope("pair_search", seed, difficulty, {"rows": rows, "cols": cols},
                     {"rows": rows, "cols": cols, "grid": grid}, {"pair": pair})


def verify_pair_search(rec: dict) -> bool:
    grid = rec["board"]["grid"]
    cells = [c for row in grid for c in row]
    counts = {c: cells.count(c) for c in set(cells)}
    dups = [c for c, k in counts.items() if k > 1]
    if len(dups) != 1 or counts[dups[0]] != 2:
        return False
    (x1, y1), (x2, y2) = rec["solution"]["pair"]
    return grid[y1][x1] == grid[y2][x2] == dups[0] and (x1, y1) != (x2, y2)


VERIFIERS = {
    "arithmetic": verify_arithmetic,
    "number_search": verify_number_search,
    "clock": verify_clock,
    "pair_search": verify_pair_search,
}
