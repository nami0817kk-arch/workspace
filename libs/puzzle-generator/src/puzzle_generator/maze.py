"""迷路パズルの生成。

生成AIには作らせず、アルゴリズムで作る。壁を1本ずつ壊しながら未訪問マスへ
進む「棒倒し法（recursive backtracker）」で、スタートからの spanning tree
（閉路のない木構造）だけを作る。木であれば任意の2点間の単純経路は必ず
ちょうど1本になるため、「解が一意である」という要件を構造そのもので満たす。

念のため verify_unique_solution() で機械検証もする。ループ（braiding）を
足す等、将来アルゴリズムを変えたときにこの不変条件が崩れていないかを
検出するためのもの。
"""

from __future__ import annotations

import random
from collections import deque
from dataclasses import dataclass
from typing import Literal

from .schema import SCHEMA_VERSION

Cell = tuple[int, int]

# 壁のビット（そのセルにまだ壁が残っている方向）
N, E, S, W = 1, 2, 4, 8
_OPPOSITE = {N: S, E: W, S: N, W: E}
_DELTA: dict[int, Cell] = {N: (0, -1), E: (1, 0), S: (0, 1), W: (-1, 0)}
_ALL_DIRECTIONS = (N, E, S, W)

Difficulty = Literal["easy", "medium", "hard"]

# 難易度は盤面の大きさで制御する（棒倒し法は盤面が大きいほど行き止まりと
# 折り返しが増え、自然に難しくなる）。具体的な冊子の紙面設計は
# projects/puzzle-book 側で決める。
DIFFICULTIES: dict[Difficulty, dict[str, int]] = {
    "easy": {"width": 10, "height": 10},
    "medium": {"width": 16, "height": 16},
    "hard": {"width": 22, "height": 30},
}


@dataclass
class Maze:
    width: int
    height: int
    # walls[y][x] : そのセルに残っている壁のビット和（N|E|S|W の組み合わせ）
    walls: list[list[int]]
    start: Cell
    goal: Cell
    seed: int


def generate_maze(
    width: int,
    height: int,
    seed: int,
    start: Cell | None = None,
    goal: Cell | None = None,
) -> Maze:
    if width < 2 or height < 2:
        raise ValueError("width と height はどちらも2以上にすること")

    rng = random.Random(seed)
    walls = [[N | E | S | W for _ in range(width)] for _ in range(height)]
    visited = [[False] * width for _ in range(height)]

    # 深さが盤面のマス数に達しうるので、再帰ではなく明示スタックで掘る
    # （大きな盤面で再帰上限に当たらないようにするため）。
    visited[0][0] = True
    stack: list[Cell] = [(0, 0)]
    while stack:
        x, y = stack[-1]
        directions = list(_ALL_DIRECTIONS)
        rng.shuffle(directions)
        carved = False
        for d in directions:
            dx, dy = _DELTA[d]
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height and not visited[ny][nx]:
                walls[y][x] &= ~d
                walls[ny][nx] &= ~_OPPOSITE[d]
                visited[ny][nx] = True
                stack.append((nx, ny))
                carved = True
                break
        if not carved:
            stack.pop()

    return Maze(
        width=width,
        height=height,
        walls=walls,
        start=start or (0, 0),
        goal=goal or (width - 1, height - 1),
        seed=seed,
    )


def solve(maze: Maze) -> list[Cell]:
    """start から goal への経路を1本返す（木構造なので必ず一意）。"""
    prev: dict[Cell, Cell | None] = {maze.start: None}
    queue: deque[Cell] = deque([maze.start])
    while queue:
        x, y = queue.popleft()
        if (x, y) == maze.goal:
            break
        cell = maze.walls[y][x]
        for d in _ALL_DIRECTIONS:
            if cell & d:
                continue  # 壁があって通れない
            dx, dy = _DELTA[d]
            nxt = (x + dx, y + dy)
            if nxt not in prev:
                prev[nxt] = (x, y)
                queue.append(nxt)

    if maze.goal not in prev:
        raise RuntimeError("start から goal に到達できない（生成器のバグ）")

    path = [maze.goal]
    while path[-1] != maze.start:
        path.append(prev[path[-1]])  # type: ignore[arg-type]
    path.reverse()
    return path


def verify_unique_solution(maze: Maze) -> bool:
    """生成した迷路が「木」であることを確かめる。

    木（頂点数 = 辺数 + 1 かつ連結）なら、任意の2点間の単純経路は
    数学的にちょうど1本しかない。逆に、これが崩れていれば
    （ループがあれば）複数の経路がありうるので、本には入れない。
    """
    total_cells = maze.width * maze.height
    edge_count = 0
    for y in range(maze.height):
        for x in range(maze.width):
            cell = maze.walls[y][x]
            # E と S だけ数えれば、隣接セルとの二重カウントを避けられる
            if not (cell & E):
                edge_count += 1
            if not (cell & S):
                edge_count += 1
    if edge_count != total_cells - 1:
        return False

    seen: set[Cell] = {(0, 0)}
    queue: deque[Cell] = deque([(0, 0)])
    while queue:
        x, y = queue.popleft()
        cell = maze.walls[y][x]
        for d in _ALL_DIRECTIONS:
            if cell & d:
                continue
            dx, dy = _DELTA[d]
            nxt = (x + dx, y + dy)
            if nxt not in seen:
                seen.add(nxt)
                queue.append(nxt)
    return len(seen) == total_cells


def to_record(maze: Maze, difficulty: Difficulty, path: list[Cell]) -> dict:
    """SCHEMA.md で定義した共通形式に変換する。"""
    return {
        "schema_version": SCHEMA_VERSION,
        "type": "maze",
        "id": f"maze-{maze.width}x{maze.height}-{maze.seed}",
        "seed": maze.seed,
        "difficulty": difficulty,
        "params": {"width": maze.width, "height": maze.height},
        "board": {
            "width": maze.width,
            "height": maze.height,
            "cell_walls": [row[:] for row in maze.walls],
            "start": list(maze.start),
            "goal": list(maze.goal),
        },
        "solution": {
            "path": [list(p) for p in path],
            "length": len(path) - 1,
        },
        "verified": True,
        "generator": {
            "name": "puzzle-generator",
            "algorithm": "backtracker",
        },
    }


def build_puzzle(difficulty: Difficulty, seed: int) -> dict:
    """難易度とシードから、検証済みの1問を組み立てる。

    verify_unique_solution が False になる盤面は例外にする
    （「通らない盤面は本に入れない」という要件を、呼び出し側で
    握りつぶせない形にするため）。
    """
    params = DIFFICULTIES[difficulty]
    maze = generate_maze(params["width"], params["height"], seed=seed)
    if not verify_unique_solution(maze):
        raise RuntimeError(
            f"seed={seed} の迷路が一意解の検証に落ちた。本に入れてはいけない。"
        )
    path = solve(maze)
    return to_record(maze, difficulty, path)


def generate_batch(count: int, difficulty: Difficulty, start_seed: int = 0) -> list[dict]:
    """本1冊・アプリの日替わり分などをまとめて作るときに使う。"""
    return [build_puzzle(difficulty, seed=start_seed + i) for i in range(count)]
