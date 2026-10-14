# -*- coding: utf-8 -*-
"""写真の顔の位置から、頭が切れない `_w.jpg`（16:9）と `_v.jpg`（9:16）を書く（2026-10-03）。

    python tools/facecrop.py assets/images/20261003_kubo_marriage/01.jpg --dry-run   # 枠だけ見る
    python tools/facecrop.py assets/images/20261003_kubo_marriage/01.jpg             # 書く
    python tools/facecrop.py <写真> --top 0.02          # 16:9 の上端を手で決める（画像の高さに対する割合）
    python tools/facecrop.py <写真> --center 0.62       # 9:16 の左右の真ん中を手で決める（画像の幅に対する割合）
    python tools/facecrop.py <写真> --face 1            # 2番目に大きい顔を主役にする（2人写った写真）

**なぜ要るか。**4:3 の写真を 16:9 に切ると上が落ち、横長の写真をショートに敷くと
真ん中しか映らない。それまでは人が `_w.jpg`・`_v.jpg` を手で切っていて、
09-29「本編の顔がキレてる」、09-25「子供が主役になってる」と言われた。

切り方（`src/faces.crop_box`）：
- 16:9 は、顔を左右の真ん中寄り・上から 1/3 あたりへ。**頭のてっぺんの上に少し余白を残す**
- 9:16 は、顔を左右の真ん中へ（ショートの冒頭は `shorts` が `_v.jpg` を見て差し替える）
- 写真は縮めも伸ばしもしない（切るだけ）

同じフォルダの `credits.json` に元の写真の行があれば、file 名だけ変えた行を足す
（出典は消さない。既存の行は消さない。同じ file の行が既にあれば足さない）。
**顔が見つからなければ書かずに知らせる**（`--top` / `--center` を渡せば、それで切る）。
すでに `_w.jpg` / `_v.jpg` があるときは上書きしない（人が手で切ったものを消さない）。`--force` で上書き。

切ったら、必ず開いて見る。顔の検出は横顔・帽子・手で隠れた顔を取りこぼす。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

# Windows のコンソールは cp932 なので「✓」で落ちる（pressphoto.py と同じ手当て）
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):      # 差し替えられている場合は触らない
        pass

from src import faces  # noqa: E402

WIDE = 16 / 9
TALL = 9 / 16
QUALITY = 94


def plan(photo: Path, top: float | None = None, center: float | None = None,
         face_index: int = 0) -> dict:
    """切り方を決める（書かない）。

    返すのは {"size", "faces", "face", "w": (l,t,r,b), "v": (l,t,r,b),
    "cut_w": [...], "cut_v": [...], "fit_w": bool, "fit_v": bool, "cut_src": [...]}。
    顔も手の指定も無ければ "w"/"v" は None。
    `cut_*` は、切ったあとの絵で頭の推定の枠がはみ出す端（空なら切れていない）。
    `fit_*` は、顔の枠（額〜顎）がまるごと入っているか。`cut_src` は元の写真の時点ではみ出している端。
    """
    with Image.open(photo) as opened:
        image = opened.convert("RGB")
    found = faces.find_faces(image)
    face = found[face_index] if len(found) > face_index else None
    out: dict = {"size": image.size, "faces": found, "face": face,
                 "w": None, "v": None, "cut_w": [], "cut_v": [], "fit_w": True, "fit_v": True,
                 "cut_src": faces.cut_edges(image.size, face) if face else []}
    if face is None and top is None and center is None:
        return out
    out["w"] = faces.crop_box(image.size, WIDE, face, top=top, center=center)
    out["v"] = faces.crop_box(image.size, TALL, face, top=top, center=center)
    if face is not None:
        for key in ("w", "v"):
            l, t, r, b = out[key]
            moved = (face[0] - l, face[1] - t, face[2], face[3])
            out["cut_" + key] = faces.cut_edges((r - l, b - t), moved)
            out["fit_" + key] = faces.fits(out[key], face)
    return out


def add_credits(photo: Path, new_names: list[str]) -> list[str]:
    """credits.json に、元の写真の行を複製して file 名だけ変えた行を足す。

    足した file 名を返す。元の写真の行が無い・控えが無い・形が違うときは何もしない（空を返す）。
    既存の行は消さない。同じ file の行が既にあれば足さない（何度実行しても増えない）。
    """
    book = photo.parent / "credits.json"
    if not book.exists():
        return []
    rows = json.loads(book.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        return []
    source = next((r for r in rows if isinstance(r, dict) and r.get("file") == photo.name), None)
    if source is None:
        return []
    have = {r.get("file") for r in rows if isinstance(r, dict)}
    added = []
    for name in new_names:
        if name in have:
            continue
        rows.append({**source, "file": name})
        added.append(name)
    if added:
        book.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return added


def _fmt(box) -> str:
    l, t, r, b = box
    return f"左{l} 上{t} 右{r} 下{b}（{r - l}x{b - t}）"


def run(photo: Path, dry_run: bool = False, top: float | None = None, center: float | None = None,
        face_index: int = 0, force: bool = False) -> int:
    if not photo.exists():
        print(f"× 写真がありません: {photo}")
        return 1
    if not faces.available():
        print("× 顔の検出が使えません（`pip install opencv-python-headless==4.14.0.94`）")
        return 1
    p = plan(photo, top=top, center=center, face_index=face_index)
    w, h = p["size"]
    print(f"{photo}  {w}x{h}  顔 {len(p['faces'])}件")
    for i, f in enumerate(p["faces"]):
        hb = faces.head_box(f)
        mark = "  ← 主役" if f == p["face"] else ""
        print(f"  顔{i}: x{f[0]} y{f[1]} {f[2]}x{f[3]}  頭の推定: 上{hb[1]} 下{hb[1] + hb[3]}{mark}")
    if p["w"] is None:
        print("× 顔が見つかりません。書きません（`--top` / `--center` で手で決められます）")
        return 1
    if p["face"] is None:
        print("  顔が見つからないので、手の指定だけで切ります")
    names = {"w": photo.with_name(photo.stem + "_w.jpg"), "v": photo.with_name(photo.stem + "_v.jpg")}
    for key, label in (("w", "16:9"), ("v", "9:16")):
        cut = p["cut_" + key]
        note = ""
        if not p["fit_" + key]:
            note = ("  × 顔が入りきりません。この縦横比に切るのは解になりません"
                    "（横長の写真を探すか、tools/pairphoto.py で2枚並べる）")
        elif cut:
            src = [e for e in cut if e in p["cut_src"]]
            note = f"  △ 頭が切れているかもしれません（{'・'.join(cut)}）"
            if src:
                note += f"。{'・'.join(src)} は元の写真の時点で端に寄っています"
        print(f"  {names[key].name} {label}: {_fmt(p[key])}{note}")
    if dry_run:
        print("  （--dry-run なので書いていません）")
        return 0

    written = []
    with Image.open(photo) as opened:
        image = opened.convert("RGB")
    for key in ("w", "v"):
        out = names[key]
        if not p["fit_" + key] and not force:
            print(f"  {out.name} は顔が入りきらないので書きません（--force で書く）")
            continue
        if out.exists() and not force:
            print(f"  {out.name} は既にあります。上書きしません（--force で上書き）")
            continue
        image.crop(p[key]).save(out, quality=QUALITY)
        written.append(out.name)
        print(f"  書いた: {out}")
    if written:
        added = add_credits(photo, written)
        if added:
            print(f"  credits.json に {', '.join(added)} の行を足しました（{photo.name} の行を複製）")
        elif (photo.parent / "credits.json").exists():
            print(f"  credits.json は足していません（{photo.name} の行が無いか、既に行があります）")
    print("  切った絵を開いて、頭と顎が入っているか目で見てください")
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("photo", help="元の写真")
    ap.add_argument("--dry-run", action="store_true", help="書かずに、切る枠だけ出す")
    ap.add_argument("--top", type=float, help="切り出しの上端（画像の高さに対する割合、0.0=上端）")
    ap.add_argument("--center", type=float, help="切り出しの左右の真ん中（画像の幅に対する割合）")
    ap.add_argument("--face", type=int, default=0, help="主役にする顔（0=いちばん大きい顔）")
    ap.add_argument("--force", action="store_true", help="既にある _w.jpg / _v.jpg を上書きする")
    args = ap.parse_args(argv)
    return run(Path(args.photo), dry_run=args.dry_run, top=args.top, center=args.center,
               face_index=args.face, force=args.force)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
