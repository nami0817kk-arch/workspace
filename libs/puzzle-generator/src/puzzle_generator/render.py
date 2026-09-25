"""迷路をSVG（ベクター）で描く。

紙の本に使うので、ビットマップではなくベクターにしてある
（拡大・解像度変換でにじまない）。KDPの入稿サイズ・余白に合わせた
実際のページ組みは projects/puzzle-book-maze 側の責務で、ここでは
1問分の絵だけを返す。
"""

from __future__ import annotations

N, E, S, W = 1, 2, 4, 8


def render_svg(
    record: dict,
    *,
    cell_size: int = 24,
    stroke_width: int = 2,
    show_solution: bool = False,
) -> str:
    if record["type"] != "maze":
        raise ValueError(f"maze 以外は未対応: {record['type']!r}")

    board = record["board"]
    width, height = board["width"], board["height"]
    walls = board["cell_walls"]
    margin = cell_size / 2
    svg_w = width * cell_size + margin * 2
    svg_h = height * cell_size + margin * 2

    parts: list[str] = [
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="0 0 {svg_w} {svg_h}" width="{svg_w}" height="{svg_h}">',
        f'<rect x="0" y="0" width="{svg_w}" height="{svg_h}" fill="white"/>',
    ]

    def line(x1: float, y1: float, x2: float, y2: float, color: str = "black") -> None:
        parts.append(
            f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" '
            f'stroke="{color}" stroke-width="{stroke_width}" stroke-linecap="square"/>'
        )

    for y in range(height):
        for x in range(width):
            cell = walls[y][x]
            cx, cy = margin + x * cell_size, margin + y * cell_size
            if cell & N:
                line(cx, cy, cx + cell_size, cy)
            if cell & W:
                line(cx, cy, cx, cy + cell_size)
            if cell & E:
                line(cx + cell_size, cy, cx + cell_size, cy + cell_size)
            if cell & S:
                line(cx, cy + cell_size, cx + cell_size, cy + cell_size)

    def cell_center(cell_xy: list[int]) -> tuple[float, float]:
        cx, cy = cell_xy
        return margin + cx * cell_size + cell_size / 2, margin + cy * cell_size + cell_size / 2

    if show_solution:
        path = record["solution"]["path"]
        points = " ".join(f"{x},{y}" for x, y in (cell_center(p) for p in path))
        parts.append(
            f'<polyline points="{points}" fill="none" stroke="#3366cc" '
            f'stroke-width="{cell_size * 0.3}" stroke-linecap="round" stroke-linejoin="round" opacity="0.6"/>'
        )

    start_x, start_y = cell_center(board["start"])
    goal_x, goal_y = cell_center(board["goal"])
    radius = cell_size * 0.25
    parts.append(f'<circle cx="{start_x}" cy="{start_y}" r="{radius}" fill="#2e7d32"/>')
    parts.append(f'<circle cx="{goal_x}" cy="{goal_y}" r="{radius}" fill="#c62828"/>')

    parts.append("</svg>")
    return "\n".join(parts)
