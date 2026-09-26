"""生成器が出力する共通レコードの検証。

詳しい説明は SCHEMA.md にある。ここでは「利用側（KDP本・Reddit日替わり）が
壊れたレコードを黙って通さない」ための最小限の検査だけを持つ。
"""

from __future__ import annotations

SCHEMA_VERSION = 1

_REQUIRED_TOP_LEVEL_KEYS = {
    "schema_version",
    "type",
    "id",
    "seed",
    "difficulty",
    "params",
    "board",
    "solution",
    "verified",
    "generator",
}


def validate_record(record: dict) -> None:
    """必須キーの欠落と、verified=False のレコードの混入を検出する。

    通らなければ例外を投げる。呼び出し側（本の入稿データ・アプリの配信データを
    組み立てる側）は、この関数を通してから使うこと。
    """
    missing = _REQUIRED_TOP_LEVEL_KEYS - record.keys()
    if missing:
        raise ValueError(f"必須キーが無い: {sorted(missing)}")

    if record["schema_version"] != SCHEMA_VERSION:
        raise ValueError(
            f"schema_version が想定と違う: {record['schema_version']} != {SCHEMA_VERSION}"
        )

    if not record["verified"]:
        raise ValueError(f"verified=False のレコードは使えない: id={record['id']!r}")

    if record["type"] == "maze":
        _validate_maze(record)
    else:
        raise ValueError(f"未知の type: {record['type']!r}")


def _validate_maze(record: dict) -> None:
    board = record["board"]
    solution = record["solution"]
    width, height = board["width"], board["height"]

    walls = board["cell_walls"]
    if len(walls) != height or any(len(row) != width for row in walls):
        raise ValueError("board.cell_walls の縦横がparamsと一致しない")

    path = solution["path"]
    if not path:
        raise ValueError("solution.path が空")
    if list(path[0]) != list(board["start"]):
        raise ValueError("solution.path が start から始まっていない")
    if list(path[-1]) != list(board["goal"]):
        raise ValueError("solution.path が goal で終わっていない")
