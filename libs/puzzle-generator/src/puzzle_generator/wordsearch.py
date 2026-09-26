"""ことば探し（ワードサーチ）の生成と検証。

盤面の形は SCHEMA.md の「type: wordsearch」。文字は1マス1文字の文字列として扱うので、
日本語（ひらがな・カタカナ）でも英語でも同じ関数で作れる。

正しさの条件（`verify_wordsearch`）:
- どの語も、8方向すべてを数えて盤面にちょうど1回だけ現れ、その位置が解答と一致する
- 埋め草の文字で不適切な語（BLOCKED_WORDS）が8方向のどこにもできていない

生成は「語を置く → 埋め草で埋める → 条件に当たったマスの埋め草だけを引き直す」の順。
語どうしが同じ文字で交差するのは許す。
"""

from __future__ import annotations

import random
from typing import Iterable, Literal

from .schema import SCHEMA_VERSION

Difficulty = Literal["easy", "medium", "hard"]

DIRS: dict[str, tuple[int, int]] = {
    "E": (1, 0),
    "S": (0, 1),
    "SE": (1, 1),
    "W": (-1, 0),
    "N": (0, -1),
    "NW": (-1, -1),
    "NE": (1, -1),
    "SW": (-1, 1),
}

# 高齢者向けの紙面が先なので、既定は逆向きを使わない。
WORDSEARCH_DIFFICULTIES: dict[Difficulty, dict] = {
    "easy": {"size": 8, "directions": ["E", "S"]},
    "medium": {"size": 10, "directions": ["E", "S"]},
    "hard": {"size": 12, "directions": ["E", "S", "SE"]},
}

HIRAGANA = list(
    "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん"
    "がぎぐげござじずぜぞだでどばびぶべぼぱぴぷぺぽ"
)
KATAKANA = [chr(ord(c) + 0x60) for c in HIRAGANA]

# 埋め草で偶然できてはいけない語。ひらがな・カタカナの両方で調べる。
# 盤面の読者は高齢者と介護の現場。死・暴言・下品な語を避ける。
_BLOCKED_HIRAGANA = [
    "しね", "しぬ", "しんだ", "ころす", "ころせ", "きえろ", "ばか", "あほ", "くそ", "ぶす", "でぶ",
    "はげ", "ぼけ", "うざい", "きもい", "ちんこ", "まんこ", "うんこ", "おしっこ", "えろ", "やりまん",
    "ちかん", "れいぷ", "じさつ", "ぼっき", "せっくす",
]
BLOCKED_WORDS: list[str] = _BLOCKED_HIRAGANA + [
    "".join(chr(ord(c) + 0x60) if "ぁ" <= c <= "ゖ" else c for c in w) for w in _BLOCKED_HIRAGANA
]


def _in(size: int, x: int, y: int) -> bool:
    return 0 <= x < size and 0 <= y < size


def find_all(grid: list[list[str]], word: str) -> list[tuple[int, int, str]]:
    """盤面の8方向すべてで word が現れる (x, y, dir) を返す。"""
    size = len(grid)
    hits = []
    if not word:
        return hits
    for y in range(size):
        for x in range(size):
            if grid[y][x] != word[0]:
                continue
            for name, (dx, dy) in DIRS.items():
                ex, ey = x + dx * (len(word) - 1), y + dy * (len(word) - 1)
                if not _in(size, ex, ey):
                    continue
                if all(grid[y + dy * i][x + dx * i] == word[i] for i in range(len(word))):
                    hits.append((x, y, name))
    # 1文字の語や回文は同じ位置を別方向で数えてしまうので、占めるマスの集合で重複を除く
    seen = set()
    unique = []
    for x, y, name in hits:
        dx, dy = DIRS[name]
        cells = frozenset((x + dx * i, y + dy * i) for i in range(len(word)))
        if cells in seen:
            continue
        seen.add(cells)
        unique.append((x, y, name))
    return unique


def _cells(word: str, x: int, y: int, d: str) -> list[tuple[int, int]]:
    dx, dy = DIRS[d]
    return [(x + dx * i, y + dy * i) for i in range(len(word))]


def verify_wordsearch(record: dict) -> bool:
    board = record["board"]
    grid = board["grid"]
    size = board["size"]
    if len(grid) != size or any(len(row) != size for row in grid):
        return False
    if any(len(ch) != 1 for row in grid for ch in row):
        return False
    placements = {p["answer"]: p for p in record["solution"]["placements"]}
    for w in board["words"]:
        ans = w["answer"]
        hits = find_all(grid, ans)
        if len(hits) != 1:
            return False
        p = placements.get(ans)
        if p is None or (hits[0][0], hits[0][1], hits[0][2]) != (p["start"][0], p["start"][1], p["dir"]):
            return False
    answer_cells = [set(_cells(p["answer"], p["start"][0], p["start"][1], p["dir"])) for p in placements.values()]
    for bad in BLOCKED_WORDS:
        for x, y, d in find_all(grid, bad):
            if not _inside_answer(set(_cells(bad, x, y, d)), answer_cells):
                return False
    return True


def _inside_answer(cells: set, answer_cells: list[set]) -> bool:
    """その並びが1つの語の中に収まっているか（例: 「かすてら」の中の「かす」は埋め草のせいではない）。"""
    return any(cells <= own for own in answer_cells)


def _place_words(
    words: list[str], size: int, directions: list[str], rng: random.Random
) -> tuple[list[list[str | None]], list[dict]] | None:
    grid: list[list[str | None]] = [[None] * size for _ in range(size)]
    placements: list[dict] = []
    for word in sorted(words, key=len, reverse=True):
        options = [
            (x, y, d)
            for d in directions
            for y in range(size)
            for x in range(size)
            if _in(size, *(_cells(word, x, y, d)[-1]))
        ]
        rng.shuffle(options)
        for x, y, d in options:
            cells = _cells(word, x, y, d)
            if all(grid[cy][cx] in (None, word[i]) for i, (cx, cy) in enumerate(cells)):
                for i, (cx, cy) in enumerate(cells):
                    grid[cy][cx] = word[i]
                placements.append({"answer": word, "start": [x, y], "dir": d})
                break
        else:
            return None
    return grid, placements


def _problems(grid: list[list[str]], words: Iterable[str], placements: dict[str, dict]) -> list[set]:
    """条件に当たっている箇所ごとに、そのマスの集合を返す。"""
    bad_cells = []
    for word in words:
        own = placements[word]
        for x, y, d in find_all(grid, word):
            if (x, y, d) != (own["start"][0], own["start"][1], own["dir"]):
                bad_cells.append(set(_cells(word, x, y, d)))
    answer_cells = [set(_cells(w, p["start"][0], p["start"][1], p["dir"])) for w, p in placements.items()]
    for bad in BLOCKED_WORDS:
        for x, y, d in find_all(grid, bad):
            cells = set(_cells(bad, x, y, d))
            if not _inside_answer(cells, answer_cells):
                bad_cells.append(cells)
    return bad_cells


def build_wordsearch(
    words: list[dict],
    difficulty: Difficulty,
    seed: int,
    *,
    theme: str = "",
    script: Literal["hiragana", "katakana"] = "hiragana",
    size: int | None = None,
    directions: list[str] | None = None,
    max_attempts: int = 200,
) -> dict:
    """語の一覧から、検証済みのことば探しを1問作る。

    words は [{"answer": "だいこん", "label": "だいこん（大根）"}, ...]。
    作れなければ例外（検証に通らない盤面を返さない）。
    """
    params = WORDSEARCH_DIFFICULTIES[difficulty]
    size = size or params["size"]
    directions = directions or params["directions"]
    answers = [w["answer"] for w in words]
    if len(set(answers)) != len(answers):
        raise ValueError("同じ語が2回入っている")
    for a in answers:
        if len(a) > size:
            raise ValueError(f"盤面 {size} マスに入らない語: {a}")
        if len(a) < 2:
            raise ValueError(f"1文字の語は使えない: {a}")
    # ある語が別の語の中に含まれていると「ちょうど1回」にならない
    for a in answers:
        for b in answers:
            if a != b and (a in b or a[::-1] in b):
                raise ValueError(f"「{a}」が「{b}」の中に含まれている")

    alphabet = KATAKANA + ["ー"] if script == "katakana" else HIRAGANA
    word_chars = [c for a in answers for c in a]
    rng = random.Random(seed)
    for _ in range(max_attempts):
        placed = _place_words(answers, size, directions, rng)
        if placed is None:
            continue
        base, placements = placed
        fixed = {(x, y) for y in range(size) for x in range(size) if base[y][x] is not None}

        def draw() -> str:
            # 半分は語に出てくる文字から選ぶ（語の文字だけが目立たないように）
            return rng.choice(word_chars) if rng.random() < 0.5 else rng.choice(alphabet)

        grid = [[base[y][x] if base[y][x] is not None else draw() for x in range(size)] for y in range(size)]
        by_answer = {p["answer"]: p for p in placements}
        for _repair in range(2000):
            problems = _problems(grid, answers, by_answer)
            if not problems:
                break
            repairable = [cells - fixed for cells in problems]
            if any(not cells for cells in repairable):
                break  # 語のマスだけで条件に当たっている。置き直す
            for cells in repairable:
                x, y = rng.choice(sorted(cells))
                grid[y][x] = draw()
        record = {
            "schema_version": SCHEMA_VERSION,
            "type": "wordsearch",
            "id": f"wordsearch-{size}x{size}-{seed}",
            "seed": seed,
            "difficulty": difficulty,
            "params": {"size": size, "directions": list(directions)},
            "board": {"size": size, "grid": grid, "words": [dict(w) for w in words], "theme": theme},
            "solution": {"placements": sorted(placements, key=lambda p: answers.index(p["answer"]))},
            "verified": True,
            "generator": {"name": "puzzle-generator", "algorithm": "place-and-repair"},
        }
        if verify_wordsearch(record):
            return record
    raise RuntimeError(f"seed={seed} で検証に通る盤面を作れなかった（語が多すぎるか長すぎる）")
