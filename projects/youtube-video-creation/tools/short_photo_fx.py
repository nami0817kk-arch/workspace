# -*- coding: utf-8 -*-
"""ショートの写真の使い方を変える素材を作る（2026-10-17。「色んなパターンを試したい」）。

    python tools/short_photo_fx.py --dir assets/images/20261016_xxx --mode B --src assets/images/20261016_xxx/01.jpg
    python tools/short_photo_fx.py --dir assets/images/20261016_xxx --mode G --src <写真> --club レアルソシエダ
    python tools/short_photo_fx.py --dir ... --mode G --src <写真> --club ... --bg assets/backgrounds/stadium_マラガ.png

**B（高速切り替え）**: 1枚の写真から、同じ人の別の切り出しを3〜5枚、縦 1080x1920 で `<dir>/NN_v.jpg` に書く。
アップ（細く・顔が大きい）→ 顔まわり → 上半身 → 胴（ユニフォームの番号）→ 引き（縦で取れる最大）。
どれも `faces.fits`（額〜顎）が入る範囲だけ。ほぼ同じ範囲になった切り出しは1枚にまとめる。
引き伸ばしすぎて粗くなる（元の写真で幅 360px 未満）切り出しは作らない。`--src` は複数渡せる（別の写真も足す）。
書いたら、取材メモに足す `short_photos:` の行を出す。写真の入れ替えは `shorts._rotate_photos`
（`ROTATE_EVERY`=3.5秒。行の切れ目で替わるので実際は 4〜5秒ごと）。

**G（切り抜き＋背景の入れ替え）**: 人物を rembg で切り抜き、クラブの色のグラデーション
（`--club`＝assets/crests/ のエンブレムの色。`--bg` でスタジアム写真）の上に、白い縁と影で浮かせて置く。
`<dir>/NN_g_v.jpg`。抜けが悪い写真（人の形が小さい・首だけ・体が欠けた・頭が元の写真の上端で切れている）は
**書かずに理由を出す**。

どちらも、`<dir>/credits.json` に**元の写真の行だけ**を file 名を変えて複製する
（元の置き場の credits.json を丸ごと写さない）。`--bg` を使ったときは背景の行も足す。
`no_derivatives`（CC BY-ND）の写真、出典の行が無い写真は加工しない（`--no-credits` で出典なしの試作だけ許す）。
書いたあと、必ず開いて目で見る（顔検出は横顔・帽子を取りこぼす）。
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

W, H = 1080, 1920
TALL = 9 / 16
QUALITY = 94
MIN_CROP_W = 360          # これより細い範囲を 1080 に伸ばすと粗い（3倍まで）
SAME_IOU = 0.60           # これ以上重なる切り出しは同じものとみなす
SHOW_SECONDS = 55         # ショートの長さの目安

# (名前, 顔の幅に対する切り出しの幅, 目の線を上から何割に置くか)
B_PLANS = [
    ("アップ", 1.45, 0.46),
    ("顔まわり", 2.4, 0.30),
    ("上半身", 3.6, 0.22),
    ("胴・番号", 5.2, 0.15),
    ("引き", None, None),
]


# --- 出典 -----------------------------------------------------------------------------------

class RightsError(Exception):
    pass


def source_row(src: Path) -> dict | None:
    book = src.parent / "credits.json"
    if not book.exists():
        return None
    try:
        rows = json.loads(book.read_text(encoding="utf-8"))
    except ValueError:
        return None
    if not isinstance(rows, list):
        return None
    return next((r for r in rows if isinstance(r, dict) and r.get("file") == src.name), None)


def check_rights(src: Path, allow_no_credits: bool) -> dict | None:
    row = source_row(src)
    if row is None:
        if allow_no_credits:
            return None
        raise RightsError(f"{src.name} の出典の行が {src.parent / 'credits.json'} にありません。"
                          "出典が分からない写真は加工しません（試作だけなら --no-credits）")
    if row.get("no_derivatives"):
        raise RightsError(f"{src.name} は改変不可（no_derivatives）です。切り出し・切り抜きに使いません")
    return row


def add_credits(out_dir: Path, rows: list[dict]) -> list[str]:
    """出力先の credits.json に行を足す。同じ file の行が既にあれば足さない。足した file 名を返す。"""
    if not rows:
        return []
    book = out_dir / "credits.json"
    existing = []
    if book.exists():
        try:
            existing = json.loads(book.read_text(encoding="utf-8"))
        except ValueError:
            existing = []
        if not isinstance(existing, list):
            existing = []
    have = {(r.get("file"), r.get("page_url")) for r in existing if isinstance(r, dict)}
    added = []
    for row in rows:
        if (row.get("file"), row.get("page_url")) in have:
            continue
        existing.append(row)
        added.append(row["file"])
    if added:
        book.write_text(json.dumps(existing, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return added


def background_row(bg: Path, new_name: str) -> dict | None:
    """背景に使った写真の出典の行（assets/backgrounds/credits.json から）。file 名だけ変えて返す。"""
    for book in (bg.parent / "credits.json", ROOT / "assets" / "backgrounds" / "credits.json"):
        if not book.exists():
            continue
        try:
            rows = json.loads(book.read_text(encoding="utf-8"))
        except ValueError:
            continue
        for r in rows if isinstance(rows, list) else []:
            if isinstance(r, dict) and r.get("file") == bg.name:
                return {**r, "file": new_name}
    return None


def next_numbers(out_dir: Path, count: int) -> list[int]:
    top = 0
    for p in out_dir.iterdir():
        m = re.match(r"(\d+)", p.stem)
        if m and p.suffix.lower() in (".jpg", ".jpeg", ".png"):
            top = max(top, int(m.group(1)))
    return [top + 1 + i for i in range(count)]


# --- B ---------------------------------------------------------------------------------------

def _iou(a, b) -> float:
    l, t = max(a[0], b[0]), max(a[1], b[1])
    r, bt = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, r - l) * max(0, bt - t)
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / union if union else 0.0


def _box(size, face, width: float | None, eye_frac: float | None):
    """9:16 の切り出し (l, t, r, b)。width=None は縦で取れる最大。顔の真ん中を左右の真ん中へ。"""
    w, h = size
    cw = min(w, h * TALL) if width is None else min(width, w, h * TALL)
    ch = cw / TALL
    cx = face[0] + face[2] / 2
    if eye_frac is None:
        top = 0.0
        # 引きは、頭の上に少し余白を残しつつ最大の範囲（高さいっぱい）
    else:
        eye_y = face[1] + face[3] * 0.40
        top = eye_y - ch * eye_frac
    left = min(max(0, cx - cw / 2), w - cw)
    top = min(max(0, top), h - ch)
    return (round(left), round(top), round(left + cw), round(top + ch))


def b_crops(image: Image.Image, face) -> list[tuple[str, tuple[int, int, int, int]]]:
    """作る切り出しの一覧 [(名前, 枠)]。顔が入らない・粗い・重なるものは除く。"""
    from src import faces

    out: list[tuple[str, tuple[int, int, int, int]]] = []
    for name, mult, eye in B_PLANS:
        width = None if mult is None else max(face[2] * mult, MIN_CROP_W)
        box = _box(image.size, face, width, eye)
        if box[2] - box[0] < MIN_CROP_W:
            continue
        if not faces.fits(box, face):
            continue
        if name != "アップ":
            moved = (face[0] - box[0], face[1] - box[1], face[2], face[3])
            if "top" in faces.cut_edges((box[2] - box[0], box[3] - box[1]), moved) \
                    and "top" not in faces.cut_edges(image.size, face):
                continue          # 頭のてっぺんが切れる（元の写真では切れていないのに）
        if any(_iou(box, kept) >= SAME_IOU for _, kept in out):
            continue
        out.append((name, box))
    return out


def run_b(srcs: list[Path], out_dir: Path, allow_no_credits: bool, dry_run: bool) -> int:
    from src import faces

    if not faces.available():
        print("× 顔の検出が使えません（opencv-python-headless）")
        return 1
    made: list[str] = []
    rows: list[dict] = []
    for src in srcs:
        try:
            row = check_rights(src, allow_no_credits)
        except RightsError as e:
            print(f"× {e}")
            continue
        with Image.open(src) as opened:
            image = opened.convert("RGB")
        found = faces.find_faces(image)
        if not found:
            print(f"× {src.name}: 顔が見つかりません。書きません")
            continue
        crops = b_crops(image, found[0])
        print(f"{src}  {image.size[0]}x{image.size[1]}  顔 {len(found)}件 → 切り出し {len(crops)}枚")
        numbers = next_numbers(out_dir, len(made) + len(crops))[len(made):]
        for (name, box), n in zip(crops, numbers):
            fname = f"{n:02d}_v.jpg"
            scale = W / (box[2] - box[0])
            print(f"  {fname} {name}: 左{box[0]} 上{box[1]} 右{box[2]} 下{box[3]}（元で幅{box[2] - box[0]}px・{scale:.1f}倍）")
            if dry_run:
                continue
            out_dir.mkdir(parents=True, exist_ok=True)
            image.crop(box).resize((W, H), Image.LANCZOS).save(out_dir / fname, quality=QUALITY)
            made.append(fname)
            if row:
                rows.append({**row, "file": fname})
    if dry_run:
        print("（--dry-run なので書いていません）")
        return 0
    added = add_credits(out_dir, rows)
    if added:
        print(f"credits.json に {len(added)} 行を足しました（元の写真の行だけ複製）")
    if made:
        _timing(out_dir, made)
    return 0 if made else 1


def _timing(out_dir: Path, made: list[str]) -> None:
    n = len(made)
    folder = out_dir.as_posix()
    print("\n取材メモに足す（`short_photos:`。縦版のパスを並べる）:")
    print("short_photos:")
    for f in made:
        print(f"  - {folder}/{f}")
    print(f"\n目安: 縦写真 {n}枚 + 主役の写真 = {n + 1}枚を回す。"
          f"{SHOW_SECONDS}秒なら 1枚あたり約 {SHOW_SECONDS / (n + 1):.1f} 秒で一巡"
          f"（`ROTATE_EVERY`=3.5秒。実際の入れ替えは行の切れ目なので 4〜5秒ごと、1分で 10〜14回）。")
    if n + 1 < 5:
        print("  △ 5枚未満です。別の写真（--src を足す・photopool）を足すと同じ絵の繰り返しが目立ちません")


# --- G ---------------------------------------------------------------------------------------

def _club_color(club: str) -> tuple[int, int, int] | None:
    sys.path.insert(0, str(ROOT / "tools"))
    from src import crest
    import crestbg

    path = crest.find(club, ROOT)
    if not path:
        return None
    return crestbg.club_color(Image.open(path).convert("RGBA"))


def gradient_bg(club: str | None) -> tuple[Image.Image, str]:
    """縦 1080x1920 の背景。クラブの色（エンブレムの主な色）の縦グラデーション＋薄い大きなエンブレム。"""
    color = _club_color(club) if club else None
    note = f"クラブの色 {color}" if color else "クラブの色が取れないので紺のグラデーション"
    base = color or (40, 70, 110)
    # 彩度は保ち、上は暗く・下は明るく（足元に光が溜まる形）
    top = tuple(int(c * 0.30) for c in base)
    mid = tuple(int(c * 0.80) for c in base)
    low = tuple(min(255, int(c + (255 - c) * 0.30)) for c in base)
    grad = Image.new("RGB", (1, 3))
    grad.putpixel((0, 0), top)
    grad.putpixel((0, 1), mid)
    grad.putpixel((0, 2), low)
    bg = grad.resize((W, H), Image.BICUBIC)
    # 頭の後ろに薄い光
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W * 0.1, H * 0.12, W * 0.9, H * 0.62), fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    bg = Image.composite(Image.new("RGB", (W, H), tuple(min(255, c + 70) for c in base)), bg, glow)
    if club:
        from src import crest
        path = crest.find(club, ROOT)
        if path:
            emblem = Image.open(path).convert("RGBA")
            side = 1500
            k = side / max(emblem.size)
            emblem = emblem.resize((int(emblem.width * k), int(emblem.height * k)), Image.LANCZOS)
            emblem = emblem.filter(ImageFilter.GaussianBlur(26))
            emblem.putalpha(emblem.getchannel("A").point(lambda v: int(v * 0.16)))
            bg = bg.convert("RGBA")
            bg.alpha_composite(emblem, (W // 2 - emblem.width // 2, int(H * 0.40) - emblem.height // 2))
            bg = bg.convert("RGB")
    return bg, note


def photo_bg(path: Path) -> Image.Image:
    """スタジアム写真を縦に切る（真ん中）。少しぼかして暗くし、人物を浮かせる。"""
    from PIL import ImageEnhance

    with Image.open(path) as im:
        im = im.convert("RGB")
    scale = max(W / im.width, H / im.height)
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    l, t = (im.width - W) // 2, (im.height - H) // 2
    im = im.crop((l, t, l + W, t + H)).filter(ImageFilter.GaussianBlur(6))
    return ImageEnhance.Brightness(im).enhance(0.62)


def cutout(image: Image.Image, face):
    """(mask, tile, face_in_tile, 理由)。使えない形なら mask=None と理由。"""
    from src import thumbfx

    if not thumbfx.available():
        return None, image, face, "rembg が入っていません"
    k = min(1.0, 1600 / max(image.size))
    tile = image.resize((round(image.width * k), round(image.height * k)), Image.LANCZOS) if k < 1 else image
    f = tuple(round(v * k) for v in face) if face else None
    key = thumbfx.key_of(tile, "short_photo_fx")
    mask = thumbfx.person_mask(tile, key, face=f)
    if mask is None:
        # usable() に落ちた理由を調べる
        seg = thumbfx._MEMO.get(key)
        return None, tile, f, "抜けが悪い（人の形が小さい・首だけ・体が欠けた・顔の所が抜けていない、のどれか）"
    return mask, tile, f, ""


def place_person(bg: Image.Image, tile: Image.Image, mask: Image.Image, scale_cap: float = 2.2) -> tuple[Image.Image, str]:
    """人物を背景に置く。白い縁と影つき。元の写真の下端で体が切れていれば、画面の下端へ突き抜ける。"""
    bbox = mask.point(lambda v: 255 if v > 128 else 0).getbbox()
    x0, y0, x1, y1 = bbox
    person = tile.convert("RGBA")
    person.putalpha(mask.filter(ImageFilter.GaussianBlur(0.8)))
    person = person.crop(bbox)
    pw, ph = person.size
    bleeds = y1 >= tile.height - 3          # 下端で切れた写真（腰から上など）
    # 拡大は、高さ 80%（下端へ突き抜けるときは 86%）・幅 96% のどちらか小さいほう。粗くなるので scale_cap まで
    target_h = H * (0.86 if bleeds else 0.80)
    scale = min(target_h / ph, W * 0.96 / pw, scale_cap)
    person = person.resize((max(1, round(pw * scale)), max(1, round(ph * scale))), Image.LANCZOS)
    px = (W - person.width) // 2
    if bleeds:
        py = H - person.height + 40         # 下端は画面の外へ
    else:
        py = int(H * 0.92) - person.height    # 足元を 92% に
    py = max(int(H * 0.07), py)             # 頭の上に余白
    alpha = Image.new("L", (W, H), 0)
    alpha.paste(person.getchannel("A"), (px, py))
    # 影（ぼかして右下へ）
    shadow = alpha.filter(ImageFilter.GaussianBlur(26)).point(lambda v: int(v * 0.60))
    shifted = ImageChops.offset(shadow, 14, 22)
    canvas = bg.convert("RGB")
    canvas = Image.composite(Image.new("RGB", (W, H), (0, 0, 0)), canvas, shifted)
    # 白い縁（9px）
    ring = alpha.point(lambda v: 255 if v > 100 else 0).filter(ImageFilter.MaxFilter(19)).filter(ImageFilter.GaussianBlur(1.2))
    canvas = Image.composite(Image.new("RGB", (W, H), (255, 255, 255)), canvas, ring)
    layer = Image.new("RGB", (W, H))
    layer.paste(person.convert("RGB"), (px, py))
    canvas = Image.composite(layer, canvas, alpha)
    return canvas, f"倍率 {scale:.2f}（{'下端へ突き抜け' if bleeds else '足元 92%'}）"


def run_g(src: Path, out_dir: Path, club: str | None, bg_path: Path | None,
          allow_no_credits: bool, dry_run: bool) -> int:
    from src import faces

    try:
        row = check_rights(src, allow_no_credits)
    except RightsError as e:
        print(f"× {e}")
        return 1
    with Image.open(src) as opened:
        image = opened.convert("RGB")
    found = faces.find_faces(image) if faces.available() else []
    face = found[0] if found else None
    print(f"{src}  {image.size[0]}x{image.size[1]}  顔 {len(found)}件")
    mask, tile, f_tile, why = cutout(image, face)
    if mask is None:
        print(f"× {src.name}: 切り抜きを使いません。{why}")
        return 2
    bbox = mask.point(lambda v: 255 if v > 128 else 0).getbbox()
    if bbox[1] <= 2:
        print(f"× {src.name}: 頭が元の写真の上端で切れています。使いません")
        return 2
    if f_tile is None:
        print("  △ 顔が検出できませんでした。頭・顎が入っているか目で確かめてください")
    if bg_path:
        bg, note = photo_bg(bg_path), f"背景の写真 {bg_path.name}"
    else:
        bg, note = gradient_bg(club)
    canvas, placed = place_person(bg, tile, mask)
    n = next_numbers(out_dir, 1)[0]
    name = f"{n:02d}_g_v.jpg"
    print(f"  {name}: {note}／{placed}")
    if dry_run:
        print("（--dry-run なので書いていません）")
        return 0
    out_dir.mkdir(parents=True, exist_ok=True)
    canvas.save(out_dir / name, quality=QUALITY)
    rows = [{**row, "file": name}] if row else []
    if bg_path:
        brow = background_row(bg_path, name)
        if brow:
            rows.append(brow)
        else:
            print(f"  △ 背景 {bg_path.name} の出典の行が見つかりません。出典を手で足してください")
    added = add_credits(out_dir, rows)
    if added:
        print(f"credits.json に {len(rows)} 行を足しました")
    print(f"取材メモの `short_photos:` に {out_dir.as_posix()}/{name} を並べる")
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", required=True, help="書き出す写真のフォルダ（assets/images/<フォルダ>）")
    ap.add_argument("--mode", required=True, choices=["B", "G"])
    ap.add_argument("--src", required=True, nargs="+", help="元の写真（Bは複数可。Gは先頭の1枚ずつ順に）")
    ap.add_argument("--club", help="G: クラブ名（assets/crests/ のエンブレムの色で背景を作る）")
    ap.add_argument("--bg", help="G: 背景にするスタジアム写真（assets/backgrounds/…）")
    ap.add_argument("--no-credits", action="store_true", help="出典の行が無い写真も試作として加工する（公開には使わない）")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)
    out_dir = Path(args.dir)
    srcs = [Path(s) for s in args.src]
    for s in srcs:
        if not s.exists():
            print(f"× 写真がありません: {s}")
            return 1
    if args.mode == "B":
        return run_b(srcs, out_dir, args.no_credits, args.dry_run)
    status = 0
    for s in srcs:
        status = max(status, run_g(s, out_dir, args.club, Path(args.bg) if args.bg else None,
                                   args.no_credits, args.dry_run))
    return status


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
