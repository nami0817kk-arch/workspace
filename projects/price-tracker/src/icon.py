"""サイトの印を PNG / ICO で書き出す。標準ライブラリだけで作る。

これまでは `data:image/svg+xml,...` を `<link rel="icon">` に直接書いていた。
ブラウザのタブには出るが、**Google の検索結果には出ない**。検索結果の印は
クロールできるURLから取りに行く決まりで、data: は取りに行けないため、
携帯の検索結果では3件とも地球儀の代替アイコンになっていた
（2026-09-26 にユーザーの画面で確認）。

図柄はヘッダの印と同じ。緑の角丸四角に、白い下向きの矢印（値下がり）。
"""
import struct
import zlib

# 検索結果の印は 48px の倍数の正方形が求められる。
# 大きめに作って縮小させる方が、どの場所でも荒れない。
SIZE = 192
# style.css の --accent と同じ緑。印だけ別の色にする理由がない。
ACCENT = (31, 111, 92)
WHITE = (255, 255, 255)


def _rounded(size: int, radius: int) -> list:
    """角丸四角の内側かどうかを、画素ごとに返す。"""
    mask = []
    for y in range(size):
        row = []
        for x in range(size):
            dx = max(radius - x, x - (size - 1 - radius), 0)
            dy = max(radius - y, y - (size - 1 - radius), 0)
            row.append(dx * dx + dy * dy <= radius * radius)
        mask.append(row)
    return mask


def _arrow(size: int) -> list:
    """下向きの矢印。縦棒と、その先の三角。"""
    mask = [[False] * size for _ in range(size)]
    bar_w = max(size // 12, 2)
    cx = size // 2
    top, bottom = int(size * 0.24), int(size * 0.58)
    for y in range(top, bottom):
        for x in range(cx - bar_w, cx + bar_w):
            mask[y][x] = True
    # 三角。下へ行くほど幅が狭くなる
    head_top, head_bottom = bottom - bar_w, int(size * 0.78)
    half = int(size * 0.20)
    span = head_bottom - head_top
    for i in range(span):
        y = head_top + i
        w = int(half * (1 - i / span))
        for x in range(cx - w, cx + w + 1):
            mask[y][x] = True
    return mask


def _chunk(kind: bytes, data: bytes) -> bytes:
    return (struct.pack(">I", len(data)) + kind + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))


def png(size: int = SIZE) -> bytes:
    """RGBA の PNG を組む。外は透明、中は緑、矢印は白。"""
    box = _rounded(size, max(size // 5, 1))
    arrow = _arrow(size)
    raw = bytearray()
    for y in range(size):
        raw.append(0)   # フィルタなし
        for x in range(size):
            if not box[y][x]:
                raw += bytes((0, 0, 0, 0))
            elif arrow[y][x]:
                raw += bytes(WHITE) + b"\xff"
            else:
                raw += bytes(ACCENT) + b"\xff"
    return (b"\x89PNG\r\n\x1a\n"
            + _chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
            + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + _chunk(b"IEND", b""))


def ico(size: int = 48) -> bytes:
    """PNG をそのまま包んだ ICO。

    ブラウザは指定が無くても /favicon.ico を取りに来る（実測で404が出ていた）。
    256px までなら ICO の中身は PNG のままでよい。
    """
    body = png(size)
    header = struct.pack("<HHH", 0, 1, 1)
    entry = struct.pack("<BBBBHHII", size % 256, size % 256, 0, 0, 1, 32,
                        len(body), 22)
    return header + entry + body
