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

__version__ = "0.1.0"

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
]
