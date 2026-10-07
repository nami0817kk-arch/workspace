"""出来上がった PDF の紙面だけを見て、全問を解く（生成データは使わない）。

読者と同じ条件で確かめる:
1. 問題ページから盤面の文字と語の一覧を読み取る
2. 一覧の語を盤面から探し、遊び方に書いた向き（よこ・たて／むずかしいは ななめ も）で
   ちょうど1回見つかること。書いていない向き（逆向きなど）では見つからないこと
3. 答えのページの色の帯が、自分で見つけた位置と一致すること

projects/puzzle-book で  python tools/solve_from_pdf.py [本文PDF]
"""

from __future__ import annotations

import sys

import pymupdf

PDF = sys.argv[1] if len(sys.argv) > 1 else "output/kotoba-vol1-interior.pdf"
DIRS = {"E": (1, 0), "S": (0, 1), "SE": (1, 1), "W": (-1, 0), "N": (0, -1), "NW": (-1, -1), "NE": (1, -1), "SW": (-1, 1)}
ALLOWED = {"やさしい": {"E", "S"}, "ふつう": {"E", "S"}, "むずかしい": {"E", "S", "SE"}}


def chars_of(page: pymupdf.Page):
    """ページの文字を1文字ずつ（中心の座標・文字・大きさ）で返す。
    PDF の読み取りは同じ行の文字を1つの文字列にまとめるので、rawdict で1文字ずつ見る。"""
    out = []
    for b in page.get_text("rawdict")["blocks"]:
        for ln in b.get("lines", []):
            for s in ln["spans"]:
                for ch in s["chars"]:
                    if ch["c"].strip():
                        x0, y0, x1, y1 = ch["bbox"]
                        out.append(((x0 + x1) / 2, (y0 + y1) / 2, ch["c"], s["size"]))
    return out


def read_grid(chars, min_size: float):
    """盤面の文字（大きな文字）を拾い、行・列にならべる。"""
    cells = [c for c in chars if c[3] >= min_size]
    if not cells:
        return None, None
    # 盤面の文字は同じ大きさで、個数が n×n（8・10・12 など）になる。その大きさを選ぶ
    sizes = {}
    for c in cells:
        sizes[round(c[3], 1)] = sizes.get(round(c[3], 1), 0) + 1
    square = [sz for sz, k in sizes.items() if k in (25, 36, 49, 64, 81, 100, 121, 144, 169, 196)]
    main = max(square) if square else max(sizes, key=sizes.get)
    cells = [c for c in cells if abs(round(c[3], 1) - main) < 0.05]  # テーマ名（26pt）とます目（25.9pt）が近いので厳しく

    def cluster(vals):
        vals = sorted(vals)
        groups = [[vals[0]]]
        for v in vals[1:]:
            (groups[-1] if v - groups[-1][-1] < main * 0.5 else groups.append([v]) or groups[-1]).append(v)
        return [sum(g) / len(g) for g in groups]

    xs, ys = cluster([c[0] for c in cells]), cluster([c[1] for c in cells])
    n = len(xs)
    if n != len(ys) or n * n != len(cells):
        return None, None
    grid = [[""] * n for _ in range(n)]
    for cx, cy, t, _ in cells:
        i = min(range(n), key=lambda k: abs(xs[k] - cx))
        j = min(range(n), key=lambda k: abs(ys[k] - cy))
        grid[j][i] = t
    return grid, (xs, ys)


def find(grid, word):
    n = len(grid)
    hits = []
    for y in range(n):
        for x in range(n):
            for d, (dx, dy) in DIRS.items():
                ex, ey = x + dx * (len(word) - 1), y + dy * (len(word) - 1)
                if 0 <= ex < n and 0 <= ey < n and all(grid[y + dy * k][x + dx * k] == word[k] for k in range(len(word))):
                    hits.append((x, y, d))
    uniq, seen = [], set()
    for x, y, d in hits:  # 回文などを同じマスの組で重複して数えない
        dx, dy = DIRS[d]
        key = frozenset((x + dx * k, y + dy * k) for k in range(len(word)))
        if key not in seen:
            seen.add(key)
            uniq.append((x, y, d))
    return uniq


def words_on_page(page: pymupdf.Page, grid_bottom: float):
    """盤面より下の「□ 語（漢字）」から、読み（かな）の部分を拾う。"""
    words = []
    for b in page.get_text("dict")["blocks"]:
        for ln in b.get("lines", []):
            spans = [s for s in ln["spans"] if s["text"].strip()]
            if not spans or spans[0]["bbox"][1] < grid_bottom:
                continue
            text = "".join(s["text"] for s in spans).strip()
            if text.startswith(("見つけた", "できた", "思い出", "はなまる")) or text.isdigit() or text.endswith("？"):
                continue
            words.append(spans[0]["text"].strip().split("（")[0])
    return [w for w in words if w]


def answer_bands(page: pymupdf.Page):
    """答えのページの太い帯（丸い端の線）を、端点の座標で返す。"""
    bands = []
    for d in page.get_drawings():
        if d.get("type") == "s" and (d.get("width") or 0) > 8:
            for it in d["items"]:
                if it[0] == "l":
                    bands.append((it[1], it[2]))
    return bands


def main() -> int:
    doc = pymupdf.open(PDF)
    problems, answers_pages = [], []
    for p in doc:
        t = p.get_text()
        if "テーマ" in t and "問題" in t and "見つけた数" in t:
            problems.append(p)
        elif t.lstrip().startswith("答え"):
            answers_pages.append(p)
    failures, solved = [], 0
    for idx, p in enumerate(problems, start=1):
        text = p.get_text()
        level = next(k for k in ALLOWED if k in text)
        grid, geo = read_grid(chars_of(p), min_size=10)
        if grid is None:
            failures.append((idx, "盤面を読み取れない"))
            continue
        grid_bottom = max(geo[1]) + 10
        words = words_on_page(p, grid_bottom)
        expected = {6: "やさしい", 8: "ふつう", 10: "むずかしい"}.get(len(words))
        if expected != level:
            failures.append((idx, f"語の数 {len(words)} が難易度 {level} と合わない"))
        found = {}
        for w in words:
            hits = find(grid, w)
            ok_dir = [h for h in hits if h[2] in ALLOWED[level]]
            if len(hits) != 1 or len(ok_dir) != 1:
                failures.append((idx, w, hits))
            else:
                found[w] = ok_dir[0]
        # 答えのページ（4問ずつ）で、帯の位置を照合
        ap = answers_pages[(idx - 1) // 4]
        agrid, ageo = None, None
        # 答えページの盤面は4つ。問題ページの1行目と一致する盤面を探す
        row0 = "".join(grid[0])
        allc = chars_of(ap)
        w_, h_ = ap.rect.width, ap.rect.height
        for qx in (0, 1):
            for qy in (0, 1):
                clip = pymupdf.Rect(qx * w_ / 2, qy * h_ / 2, (qx + 1) * w_ / 2, (qy + 1) * h_ / 2)
                sub = [c for c in allc if clip.contains(pymupdf.Point(c[0], c[1])) and c[3] < 20]
                # 区画の中の見出し（問題 N など）の文字を除くため、いちばん多い大きさだけを使う（read_grid の中で）
                g, geo2 = read_grid(sub, min_size=5) if sub else (None, None)
                if g and "".join(g[0]) == row0 and len(g) == len(grid):
                    agrid, ageo = g, geo2
        if agrid is None:
            failures.append((idx, "答えのページに同じ盤面が見つからない"))
            continue
        xs, ys = ageo
        step = (xs[-1] - xs[0]) / (len(xs) - 1)
        band_cells = set()
        for p1, p2 in answer_bands(ap):
            if not (xs[0] - step <= p1.x <= xs[-1] + step and ys[0] - step <= p1.y <= ys[-1] + step):
                continue
            i1 = min(range(len(xs)), key=lambda k: abs(xs[k] - p1.x))
            j1 = min(range(len(ys)), key=lambda k: abs(ys[k] - p1.y))
            i2 = min(range(len(xs)), key=lambda k: abs(xs[k] - p2.x))
            j2 = min(range(len(ys)), key=lambda k: abs(ys[k] - p2.y))
            band_cells.add(((i1, j1), (i2, j2)))
        mine = set()
        for w, (x, y, d) in found.items():
            dx, dy = DIRS[d]
            mine.add(((x, y), (x + dx * (len(w) - 1), y + dy * (len(w) - 1))))
        if mine != band_cells:
            failures.append((idx, "答えの帯が自分で解いた位置と違う", sorted(mine ^ band_cells)[:3]))
        else:
            solved += 1
    print(f"問題ページ {len(problems)} / 答えのページ {len(answers_pages)}")
    print(f"紙面から解いて、答えの帯とも一致した問題: {solved}/{len(problems)}")
    for f in failures:
        print("  NG:", f)
    return 0 if not failures and solved == len(problems) == 60 else 1


if __name__ == "__main__":
    sys.exit(main())
