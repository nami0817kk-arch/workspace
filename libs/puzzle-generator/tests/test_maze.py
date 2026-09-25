import pytest

from puzzle_generator import (
    DIFFICULTIES,
    build_puzzle,
    generate_batch,
    generate_maze,
    render_svg,
    solve,
    validate_record,
    verify_unique_solution,
)
from puzzle_generator.maze import E, N, S, W, to_record


def test_generate_maze_is_deterministic_for_same_seed():
    a = generate_maze(10, 10, seed=42)
    b = generate_maze(10, 10, seed=42)
    assert a.walls == b.walls


def test_generate_maze_differs_for_different_seed():
    a = generate_maze(10, 10, seed=1)
    b = generate_maze(10, 10, seed=2)
    assert a.walls != b.walls


@pytest.mark.parametrize("width,height", [(2, 2), (10, 10), (16, 16), (22, 30)])
def test_generated_maze_is_a_unique_solution_tree(width, height):
    maze = generate_maze(width, height, seed=123)
    assert verify_unique_solution(maze)


def test_verifier_rejects_a_maze_with_a_loop():
    # 手でループを1つ作る(0,0)-(1,0)-(1,1)-(0,1)-(0,0) を全部つなげて閉路にする。
    maze = generate_maze(4, 4, seed=1)
    maze.walls[0][0] &= ~E
    maze.walls[0][1] &= ~W
    maze.walls[0][1] &= ~S
    maze.walls[1][1] &= ~N
    maze.walls[1][1] &= ~W
    maze.walls[1][0] &= ~E
    maze.walls[1][0] &= ~N
    maze.walls[0][0] &= ~S
    assert not verify_unique_solution(maze)


def test_solve_returns_a_path_with_no_walls_crossed():
    maze = generate_maze(12, 9, seed=7)
    path = solve(maze)
    assert path[0] == maze.start
    assert path[-1] == maze.goal
    for (x1, y1), (x2, y2) in zip(path, path[1:]):
        dx, dy = x2 - x1, y2 - y1
        cell = maze.walls[y1][x1]
        if (dx, dy) == (0, -1):
            assert not cell & N
        elif (dx, dy) == (1, 0):
            assert not cell & E
        elif (dx, dy) == (0, 1):
            assert not cell & S
        elif (dx, dy) == (-1, 0):
            assert not cell & W
        else:
            raise AssertionError(f"隣接していないステップ: {(x1, y1)} -> {(x2, y2)}")


@pytest.mark.parametrize("difficulty", list(DIFFICULTIES))
def test_build_puzzle_produces_a_valid_record(difficulty):
    record = build_puzzle(difficulty, seed=99)
    validate_record(record)  # 例外を投げなければ通過
    assert record["difficulty"] == difficulty
    assert record["verified"] is True


def test_to_record_rejects_unknown_type_at_validation():
    maze = generate_maze(4, 4, seed=1)
    path = solve(maze)
    record = to_record(maze, "easy", path)
    record["type"] = "sudoku"  # まだ対応していない type
    with pytest.raises(ValueError):
        validate_record(record)


def test_generate_batch_gives_distinct_seeds():
    records = generate_batch(5, "easy", start_seed=1000)
    seeds = [r["seed"] for r in records]
    assert seeds == list(range(1000, 1005))
    assert len({r["id"] for r in records}) == 5


def test_render_svg_contains_expected_elements():
    record = build_puzzle("easy", seed=5)
    svg = render_svg(record, show_solution=False)
    assert svg.startswith("<svg")
    assert svg.endswith("</svg>")
    assert "<polyline" not in svg  # 解答を出していないので通り道は描かれない

    svg_with_answer = render_svg(record, show_solution=True)
    assert "<polyline" in svg_with_answer
