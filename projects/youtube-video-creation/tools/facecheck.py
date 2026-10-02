# -*- coding: utf-8 -*-
"""書き出した動画のコマで、顔が切れていないか・顔に板がかかっていないかを機械で見る（2026-10-03）。

    python tools/facecheck.py output/20261003_kubo_marriage_short
    python tools/facecheck.py output/20261003_*                      # まとめて
    python tools/facecheck.py output/20261003_kubo_marriage --scan   # 1秒ごとに全部見る（本編で1〜2分）

**なぜ要るか。**`tools/frames.py` の4コマは人が目で見ていて、見落としがあった
（09-29「本編の顔がキレてる」は4コマを見たのに見落とした。10-03 は久保の結婚のショートで、
最後に反応の白い箱が久保の顎にかかっていた）。

見るコマは `tools/frames.py` と同じ（冒頭 0:03／山場の頭／60秒／最後の5秒前）。
ショート（70秒以下）は「中ほど」も足す。`frames.png` ではなく**動画から直接**コマを取る
（縮小した4コマでは表が透けて見えた見間違いがある）。各コマで知らせるのは3つ:

- (a) **冒頭 0:03 に顔が1つも見つからない**
- (b) **頭のてっぺんが画面の上端で切れている**（顔の枠から推定した頭の枠で見る。
  × は額まで切れている、△ は髪が切れているかもしれない）
- (c) **顔の上に文字の板がかかっている**（反応の白い箱・表・テロップの帯。`faces.overlay_on_face`）。
  × は顔の枠の中までかかっている、△ は顎のすぐ下（首）に接しているだけ

**板で隠れた顔は検出できない**（口元が箱に隠れると Haar は顔と取らない）。そこで、
そのコマの前（20秒まで）と後ろ（2秒）を1秒ごとに見て、同じ写真のまま見つかった顔を借りて (c) を見る。
**表が顔を丸ごと覆っているコマは見逃す**（まわりの写真が見えないので、同じ写真か確かめられない。
10-03 の本編の山場・60秒がこれ）。そこは frames.png を目で見る。

結果の絵は `output/<名前>/facecheck.png`（赤＝そのコマで見つけた顔、橙＝前後のコマから借りた顔、
緑＝頭の推定の枠）。**× が無くても、最後は frames.png を目で見る決まりは変わらない。**
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

# Windows のコンソールは cp932 なので「✓」で落ちる（pressphoto.py と同じ手当て）
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):      # 差し替えられている場合は触らない
        pass

from src import faces  # noqa: E402
from src.ffmpeg import ffmpeg_exe, grab_frame  # noqa: E402
from tools.frames import _duration, _main_start  # noqa: E402

SHORT_MAX = 70.0      # これ以下の尺はショートとして「中ほど」を足す（frames.py の「60秒」の境と同じ）
LOOK_BACK = 20.0      # 隠れた顔を探しに戻る秒数
LOOK_AHEAD = 2.0
ENOUGH_FRAMES = 3     # 顔を借りられたコマがこれだけあれば探すのをやめる
COVER_SURE = 0.05     # 顔の枠の中の行のこの割合以上に板がかかっていたら ×。未満なら顎のすぐ下に接しているだけ（△）
CUT_SURE = 0.25       # 頭の推定の枠が顔の高さ×これ以上はみ出したら ×（額まで切れている）
SIDE_FACE = 0.5       # いちばん大きい顔の幅のこれ未満の顔は (b)(c) で見ない（奥の小さい人）
KIND = {"white": "白い箱", "dark": "濃い板（表・テロップの帯）"}


def marks(build_dir: Path, total: float) -> list[tuple[str, float]]:
    """見るコマの時刻。frames.py と同じ4つ（ショートは中ほども）。"""
    out = [("冒頭 0:03", 3.0)]
    main = _main_start(build_dir)
    if main is not None:
        out.append(("山場の頭", main + 1.0))
    if total > SHORT_MAX:
        out.append(("60秒", 60.0))
    elif total > 10:
        out.append(("中ほど", total / 2))
    if total > 10:
        out.append(("最後の5秒前", total - 5.0))
    kept: list[tuple[str, float]] = []
    for label, at in sorted(out, key=lambda m: m[1]):
        if at < total and all(abs(at - k[1]) >= 1.5 for k in kept):
            kept.append((label, at))
    return kept


def _window(video: Path, start: float, end: float, folder: Path, tag: str) -> list[tuple[float, Path]]:
    """start〜end を1秒ごとに書き出す（ffmpeg を1回だけ呼ぶ）。"""
    start = max(0.0, start)
    if end <= start:
        return []
    # PNG で書くと1本20秒のうち半分が書き出しだった。比べるだけなので JPEG（高画質）で足りる
    pattern = folder / f"{tag}_%03d.jpg"
    subprocess.run([ffmpeg_exe(), "-y", "-loglevel", "error", "-ss", f"{start:.2f}", "-i", str(video),
                    "-t", f"{end - start:.2f}", "-vf", "fps=1", "-q:v", "2", str(pattern)], capture_output=True)
    return [(start + i, p) for i, p in enumerate(sorted(folder.glob(f"{tag}_*.jpg")))]


def _overlaps(box, others) -> bool:
    return any(faces._iou(box, o) >= 0.4 for o in others)


def borrow(frame: Image.Image, at: float, window: list[tuple[float, Path]], own: list) -> list[tuple]:
    """前後のコマで見つけた顔のうち、同じ写真のまま（板で隠れているかもしれない）ものを借りる。"""
    got: list[tuple] = []
    hit_frames = 0
    for t, path in sorted(window, key=lambda w: abs(w[0] - at)):
        with Image.open(path) as opened:
            ref = opened.convert("RGB")
        if ref.size != frame.size:
            continue
        seen = False   # このコマに、同じ写真のままの顔があったか（借りた顔でも、このコマで見えている顔でも）
        for box in faces.find_faces(ref):
            if _overlaps(box, [g[0] for g in got]):
                continue
            if not faces.same_picture(frame, ref, box):
                continue
            seen = True
            if not _overlaps(box, own):
                got.append((box, t))
        hit_frames += seen
        if hit_frames >= ENOUGH_FRAMES:
            break
    return got


def judge(frame: Image.Image, label: str, own: list, borrowed: list[tuple]) -> list[tuple[str, str]]:
    """1コマの判定。[(印, 文), ...]（印は × / △）。"""
    out: list[tuple[str, str]] = []
    cands = [(b, None) for b in own] + list(borrowed)
    if label.startswith("冒頭") and not cands:
        # 傾いた顔・強い影の顔は Haar が取りこぼす（10-02 のアギーレ・ヤマルのショートで実際に起きた）。
        # それでも × にするのは、冒頭は相手がスマホで最初に見る1コマで、一度目で見れば済むから
        out.append(("×", "(a) 冒頭に顔が1つも見つかりません（傾いた顔・強い影の顔は取りこぼすので、"
                         "facecheck.png で誰の顔が映っているか目で見る）"))
    if not cands:
        return out
    biggest = max(b[2] for b, _ in cands)
    for box, src in cands:
        if box[2] < biggest * SIDE_FACE:
            continue
        where = f"顔 x{box[0]} y{box[1]} {box[2]}px" + (f"（{src:.0f}秒のコマから借りた顔）" if src is not None else "")
        if faces.cut_edges(frame.size, box, ("top",), slack=CUT_SURE):
            out.append(("×", f"(b) 頭が画面の上端で切れています（額まで）: {where}"))
        elif faces.cut_edges(frame.size, box, ("top",)):
            out.append(("△", f"(b) 頭のてっぺんが上端で切れているかもしれません: {where}"))
        over = faces.overlay_on_face(frame, box)
        if over["hit"] and over["cover"] >= COVER_SURE:
            out.append(("×", f"(c) 顔に{KIND[over['hit']]}がかかっています（顔の枠の{over['cover']:.0%}）: {where}"))
        elif over["hit"]:
            out.append(("△", f"(c) 顎のすぐ下に{KIND[over['hit']]}が接しています: {where}"))
    return out


def _draw(frame: Image.Image, own: list, borrowed: list[tuple]) -> Image.Image:
    im = frame.copy()
    d = ImageDraw.Draw(im)
    for box, color in [(b, (255, 40, 40)) for b in own] + [(b, (255, 160, 0)) for b, _ in borrowed]:
        x, y, w, h = box
        d.rectangle([x, y, x + w, y + h], outline=color, width=6)
        hx, hy, hw, hh = faces.head_box(box)
        d.rectangle([hx, hy, hx + hw, hy + hh], outline=(40, 220, 40), width=3)
    return im


def _sheet(tiles: list[tuple[str, Image.Image]], path: Path) -> None:
    for _, im in tiles:
        im.thumbnail((640, 640))
    w = max(im.width for _, im in tiles)
    h = max(im.height for _, im in tiles) + 28
    cols = 2
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGB", (w * cols + 8 * (cols + 1), h * rows + 8 * (rows + 1)), (12, 12, 12))
    draw = ImageDraw.Draw(out)
    try:
        from src.config import load_config

        font = ImageFont.truetype(str(load_config().video.font_path()), 18)
    except Exception:
        font = ImageFont.load_default()
    for i, (label, im) in enumerate(tiles):
        x = 8 + (i % cols) * (w + 8)
        y = 8 + (i // cols) * (h + 8)
        draw.text((x + 4, y + 2), label, fill=(240, 240, 240), font=font)
        out.paste(im, (x, y + 24))
    out.save(path)


def check(build_dir: Path, sheet: bool = True) -> list[tuple[str, str, str]] | None:
    """[(コマの名前, 印, 文), ...]。動画が無ければ None。"""
    video = build_dir / "video.mp4"
    if not video.exists():
        print(f"× 動画がありません: {video}")
        return None
    total = _duration(video)
    found: list[tuple[str, str, str]] = []
    tiles: list[tuple[str, Image.Image]] = []
    with tempfile.TemporaryDirectory(prefix="facecheck_") as tmp:
        folder = Path(tmp)
        for n, (label, at) in enumerate(marks(build_dir, total)):
            shot = folder / f"mark_{n}.png"
            try:
                grab_frame(video, shot, at)
            except Exception as exc:  # 取れないコマは知らせて次へ
                found.append((label, "×", f"コマが取れません: {exc}"))
                continue
            with Image.open(shot) as opened:
                frame = opened.convert("RGB")
            own = faces.find_faces(frame)
            window = _window(video, at - LOOK_BACK, min(total, at + LOOK_AHEAD), folder, f"w{n}")
            borrowed = borrow(frame, at, window, own)
            name = f"{label}（{at:.1f}秒）"
            for mark, text in judge(frame, label, own, borrowed):
                found.append((name, mark, text))
            tiles.append((f"{build_dir.name}  {name}", _draw(frame, own, borrowed)))
    if sheet and tiles:
        _sheet(tiles, build_dir / "facecheck.png")
    return found


def scan(build_dir: Path) -> list[tuple[float, str, str]]:
    """1秒ごとに全部のコマを見る（(b)(c) だけ）。前のコマで見つけた顔を、同じ写真のあいだ持ち越す。"""
    video = build_dir / "video.mp4"
    total = _duration(video)
    out: list[tuple[float, str, str]] = []
    with tempfile.TemporaryDirectory(prefix="facescan_") as tmp:
        known: list[tuple] = []   # (box, そのコマの絵, 秒)
        for t, path in _window(video, 0.0, total, Path(tmp), "s"):
            with Image.open(path) as opened:
                frame = opened.convert("RGB")
            own = faces.find_faces(frame)
            borrowed = [(box, seen) for box, ref, seen in known
                        if not _overlaps(box, own) and faces.same_picture(frame, ref, box)]
            for mark, text in judge(frame, "", own, borrowed):
                out.append((t, mark, text))
            known = [(b, frame, t) for b in own] + [k for k in known
                                                    if not _overlaps(k[0], own) and (k[0], k[2]) in borrowed]
    return out


def _ranges(hits: list[tuple[float, str, str]]) -> list[str]:
    """同じ種類の知らせを、続いた秒の区間にまとめる。"""
    groups: dict[tuple[str, str], list[float]] = {}
    for t, mark, text in hits:
        key = (mark, re.sub(r"（顔の枠の\d+%）", "", text.split(":")[0]))
        groups.setdefault(key, []).append(t)
    lines = []
    for (mark, head), times in sorted(groups.items(), key=lambda g: g[1][0]):
        spans: list[list[float]] = []
        for t in sorted(set(times)):
            if spans and t - spans[-1][1] <= 1.01:
                spans[-1][1] = t
            else:
                spans.append([t, t])
        where = "、".join(f"{a:.0f}〜{b:.0f}秒" if b > a else f"{a:.0f}秒" for a, b in spans)
        lines.append(f"  {mark} {head}: {where}")
    return lines


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dirs", nargs="+", help="build の出力先")
    ap.add_argument("--scan", action="store_true", help="4コマに加えて、1秒ごとに全部のコマを見る")
    ap.add_argument("--no-sheet", action="store_true", help="facecheck.png を書かない")
    args = ap.parse_args(argv)
    if not faces.available():
        print("× 顔の検出が使えません（`pip install opencv-python-headless==4.14.0.94`）")
        return 2
    bad = 0
    for d in args.dirs:
        build_dir = Path(d)
        found = check(build_dir, sheet=not args.no_sheet)
        if found is None:
            bad += 1
            continue
        print(f"{build_dir.name}")
        for label, at in marks(build_dir, _duration(build_dir / "video.mp4")):
            name = f"{label}（{at:.1f}秒）"
            mine = [(m, t) for n, m, t in found if n == name]
            if not mine:
                print(f"  ✓ {name}")
            for mark, text in mine:
                print(f"  {mark} {name} {text}")
        if args.scan:
            print("  1秒ごと:")
            lines = _ranges(scan(build_dir))
            print("\n".join(lines) if lines else "  ✓ 1秒ごとでも見つかりませんでした")
        if (build_dir / "facecheck.png").exists() and not args.no_sheet:
            print(f"  絵: {build_dir / 'facecheck.png'}")
        bad += any(m == "×" for _, m, _ in found)
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
