"""クラブのエンブレム画像(300枚)をアプリの素材と色の表にする。

    python tool/art/build_crests.py --cut <切り抜き済みPNGのフォルダ> \
        --table <crest_table.json>

- 材料: <cut>/000.png〜299.png(透明の地・正方形)と crest_table.json
  (300要素。並びは cut の番号と同じで、lib/data/club_names.dart の
  _data の並び=国 england→spain→germany→italy→france、部 1→3、行の順)。
- 出力: assets/crests/NNN.webp(既定 160px・品質80)と
  lib/data/crest_hues.dart(エンブレムの2色の色相の表。-1 は白黒灰)。
- 表の名前と club_names.dart の並びが1件でも食い違えば、何も書かずに止まる
  (番号がずれると、全クラブが別のクラブのエンブレムになる)。

Pillow と numpy が要る。プロジェクト直下(projects/soccer-manager)で実行する。
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
CLUB_NAMES = ROOT / "lib" / "data" / "club_names.dart"
ORDER = ["england", "spain", "germany", "italy", "france"]


def club_names_in_order() -> list[tuple[str, str, str, int]]:
    """club_names.dart の _data を (国, 日本語, 英語, 部) の並びで読む。"""
    src = CLUB_NAMES.read_text(encoding="utf-8")
    body = src[src.index("_data = {"):]
    out: list[tuple[str, str, str, int]] = []
    # 国ごとの塊: "LeagueTheme.xxx: [" から次の国まで。
    starts = [(m.start(), m.group(1)) for m in re.finditer(r"LeagueTheme\.(\w+): \[", body)]
    if [c for _, c in starts] != ORDER:
        sys.exit(f"club_names.dart の国の並びが想定と違う: {[c for _, c in starts]}")
    for k, (pos, country) in enumerate(starts):
        end = starts[k + 1][0] if k + 1 < len(starts) else len(body)
        blocks = re.findall(r"'''\n(.*?)'''", body[pos:end], flags=re.S)
        if len(blocks) != 3:
            sys.exit(f"{country} の部が3つではない({len(blocks)})")
        for tier, block in enumerate(blocks, start=1):
            for line in block.split("\n"):
                if "|" not in line:
                    continue
                ja, en = (s.strip() for s in line.split("|")[:2])
                out.append((country, ja, en, tier))
    return out


def check_table(table: list[dict]) -> None:
    names = club_names_in_order()
    if len(names) != len(table):
        sys.exit(f"件数が違う: club_names {len(names)} / 表 {len(table)}")
    bad = []
    for i, ((country, ja, en, tier), row) in enumerate(zip(names, table)):
        if (row["country"], row["ja"], row["en"], row["tier"]) != (country, ja, en, tier):
            bad.append(f"{i:03d}: {country}/{tier} {en} != 表 {row['country']}/{row['tier']} {row['en']}")
    if bad:
        sys.exit("並びが食い違う:\n" + "\n".join(bad[:20]))
    for i, row in enumerate(table):
        hue = row["hue"]
        if len(hue) != 2 or any(not (h == -1 or 0 <= h < 360) for h in hue):
            sys.exit(f"{i:03d} の hue が不正: {hue}")
        if hue == [-1, -1]:
            # ClubPalette.fromCrest は色のある方を使う。両方とも無いと決まらない。
            sys.exit(f"{i:03d} の hue が両方とも白黒灰")


def _dilate(mask: np.ndarray) -> np.ndarray:
    """8近傍に1画素ふくらませる。"""
    out = mask.copy()
    out[1:, :] |= mask[:-1, :]
    out[:-1, :] |= mask[1:, :]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    out[1:, 1:] |= mask[:-1, :-1]
    out[:-1, :-1] |= mask[1:, 1:]
    out[1:, :-1] |= mask[:-1, 1:]
    out[:-1, 1:] |= mask[1:, :-1]
    return out


def defringe(im: Image.Image, depth: int) -> Image.Image:
    """白い地から切り抜いたときに残った、外周の白いふちを外す。

    外(透明)から白っぽい画素だけをたどって [depth] 画素以内に届き、かつ
    その内側 [depth] 画素以内に色のある画素がある所を消す。地そのものが
    白いエンブレム(白の奥に色が無い)は、白の縁ごと残す。暗い画面で
    白い輪が浮いて見えていた(2026-11-25)。
    """
    a = np.asarray(im, dtype=np.uint8).copy()
    rgb = a[:, :, :3].astype(np.int16)
    alpha = a[:, :, 3]
    lo = rgb.min(axis=2)
    hi = rgb.max(axis=2)
    clear = alpha <= 12
    white = (lo >= 232) & (hi - lo <= 40) & ~clear
    reach = clear.copy()
    for _ in range(depth):
        reach |= _dilate(reach) & white
    ring = reach & white
    colored = ~clear & ~white
    near = colored.copy()
    for _ in range(depth):
        near = _dilate(near)
    strip = ring & near
    alpha = alpha.copy()
    alpha[strip] = 0
    alpha[clear] = 0
    # 消した境目がぎざぎざにならないよう、縁だけ少しぼかす。
    mask = Image.fromarray(np.where(alpha > 0, 255, 0).astype(np.uint8), "L")
    soft = np.asarray(mask.filter(ImageFilter.GaussianBlur(0.8)), dtype=np.uint8)
    a[:, :, 3] = np.minimum(alpha, soft)
    return Image.fromarray(a, "RGBA")


def convert(src: Path, dst: Path, size: int, quality: int, depth: int) -> int:
    im = Image.open(src).convert("RGBA")
    if depth > 0:
        im = defringe(im, depth)
    # 透明の地のまま縮めると、色の無い透明画素(多くは白)が縁に混ざって
    # 白いふちになる。乗算済みアルファ(RGBa)で縮めてから戻す。
    im = im.convert("RGBa").resize((size, size), Image.LANCZOS).convert("RGBA")
    # 完全に透明な画素の色は黒にそろえる(圧縮で縁ににじみ出さない)。
    a = np.asarray(im, dtype=np.uint8).copy()
    a[a[:, :, 3] == 0] = 0
    Image.fromarray(a, "RGBA").save(dst, "WEBP", quality=quality, alpha_quality=100, method=4)
    return dst.stat().st_size


def write_dart(table: list[dict], out: Path) -> None:
    lines = [
        "// 生成物。手で直さない(tool/art/build_crests.py が crest_table.json から作る)。",
        "",
        "/// クラブのエンブレム画像(assets/crests/NNN.webp)の2色の色相。",
        "/// 番号 i の色は [i * 2](地)と [i * 2 + 1](差し色)。-1 は白・黒・灰。",
        "/// 並びは ClubNames の _data の並び(国 → 部 → 行)。",
        "const List<int> kCrestHues = [",
    ]
    for i, row in enumerate(table):
        lines.append(f"  {row['hue'][0]}, {row['hue'][1]}, // {i:03d}")
    lines += ["];", "", f"const int kCrestCount = {len(table)};", ""]
    out.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cut", required=True, type=Path)
    ap.add_argument("--table", required=True, type=Path)
    ap.add_argument("--size", type=int, default=160)
    ap.add_argument("--quality", type=int, default=80)
    ap.add_argument("--defringe", type=int, default=5,
                    help="外周の白いふちを外す深さ(元の画像の画素。0 で外さない)")
    ap.add_argument("--assets-out", type=Path, default=ROOT / "assets" / "crests")
    ap.add_argument("--dart-out", type=Path, default=ROOT / "lib" / "data" / "crest_hues.dart")
    args = ap.parse_args()

    table = json.loads(args.table.read_text(encoding="utf-8"))
    check_table(table)
    missing = [i for i in range(len(table)) if not (args.cut / f"{i:03d}.png").exists()]
    if missing:
        sys.exit(f"画像が無い: {missing[:10]}")

    args.assets_out.mkdir(parents=True, exist_ok=True)
    total = 0
    for i in range(len(table)):
        total += convert(args.cut / f"{i:03d}.png", args.assets_out / f"{i:03d}.webp",
                         args.size, args.quality, args.defringe)
    write_dart(table, args.dart_out)
    print(f"{len(table)} 枚 / 合計 {total / 1024:.1f} KiB -> {args.assets_out}")
    print(f"色の表 -> {args.dart_out}")


if __name__ == "__main__":
    main()
