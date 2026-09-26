from .maze import (
    DIFFICULTIES,
    Maze,
    build_puzzle,
    generate_batch,
    generate_maze,
    solve,
    verify_unique_solution,
)
from .render import render_svg
from .schema import SCHEMA_VERSION, validate_record
from .wordsearch import (
    BLOCKED_WORDS,
    DIRS,
    WORDSEARCH_DIFFICULTIES,
    build_wordsearch,
    find_all,
    verify_wordsearch,
)

__version__ = "0.2.0"

__all__ = [
    "__version__",
    "SCHEMA_VERSION",
    "DIFFICULTIES",
    "Maze",
    "build_puzzle",
    "generate_batch",
    "generate_maze",
    "render_svg",
    "solve",
    "validate_record",
    "verify_unique_solution",
    "BLOCKED_WORDS",
    "DIRS",
    "WORDSEARCH_DIFFICULTIES",
    "build_wordsearch",
    "find_all",
    "verify_wordsearch",
]
