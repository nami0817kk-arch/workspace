"""共有用の画像 static/og.png（1200×630）を作る。地図はサイトと同じ data/geo から描く。

    python tools/make_og.py

日本語フォントは Windows の BIZ UDゴシック を使うので、手元の PC で作ってコミットする（CI では作らない）。
国の数や色を変えたときだけ作り直す。
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "src"))

import geo  # noqa: E402

W, H = 1200, 630
BG = "#f6f7f4"
LAND = "#dfe4de"
WH = "#2a78d6"
JP = "#eb6834"
INK = "#1b1d1a"
MUTED = "#5f6a64"
FONT_B = "C:/Windows/Fonts/BIZ-UDGothicB.ttc"
FONT_R = "C:/Windows/Fonts/BIZ-UDGothicR.ttc"


def main() -> None:
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    frame = geo.Frame(-180, -58, 180, 84, 1020)
    ox, oy = 90, 172
    arcs, geoms = geo._topology()
    by_iso = {iso: cid for cid, iso in geo.ISO_NUM.items()}
    for g in geoms:
        gid = str(g.get("id", ""))
        if gid == geo.ANTARCTICA:
            continue
        color = WH if gid in by_iso else JP if gid == geo.JAPAN else LAND
        keep = geo.MAINLAND.get(gid)
        for poly in geo._polygons(g, arcs):
            ring = geo._unwrap(poly[0])
            if keep and not any(keep[0] <= lo <= keep[2] and keep[1] <= la <= keep[3] for lo, la in ring):
                continue
            pts = [(x + ox, y + oy) for x, y in (frame.xy(lo, la) for lo, la in ring)]
            if len(pts) >= 3:
                draw.polygon(pts, fill=color, outline=BG)
    for cid, (lo, la) in geo.MARKERS.items():
        x, y = frame.xy(lo, la)
        draw.ellipse((x + ox - 7, y + oy - 7, x + ox + 7, y + oy + 7), fill=WH, outline=BG, width=3)
    # 文字の下地（地図の上に半透明の帯）
    band = Image.new("RGBA", (W, 150), (246, 247, 244, 235))
    img.paste(band, (0, 0), band)
    title = ImageFont.truetype(FONT_B, 64)
    sub = ImageFont.truetype(FONT_R, 30)
    draw.text((56, 30), "ワーホリ条件くらべ", font=title, fill=INK)
    draw.text((60, 108), "32か国・地域の条件と、現地での手続き・病院・仕事探し", font=sub, fill=MUTED)
    out = ROOT / "static" / "og.png"
    img.save(out, optimize=True)
    print(f"{out}（{out.stat().st_size // 1024}KB）")


if __name__ == "__main__":
    main()
