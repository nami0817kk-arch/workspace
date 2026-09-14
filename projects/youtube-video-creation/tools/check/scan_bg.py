"""動画の**背景がいつ変わるか**を数える（2026-09-14 ユーザー指示
「ちゃんと他にもおかしな切り替えがないか確認して」）。

目で追うのは無理なので、0.4秒ごとに1コマ取って比べる。
**テロップとカードが載る下半分は見ない。**文字が変わるたびに差が出てしまうので、
上の帯（高さの8〜38%）だけを見る。ここは下地がそのまま出る場所。

    python scan_bg.py output/20260914b_ueda_short/video.mp4 [...]
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

def _ffmpeg() -> str:
    """venv に入っている ffmpeg を引く。**置き場所を決め打ちしない**（2026-09-15）。
    scratchpad に置いていた頃は絶対パスを書いていて、別のセッションでは動かなかった。
    """
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


FF = _ffmpeg()
STEP = 0.4
# これ以上ちがったら「変わった」とみなす（0〜255 の平均差）
THRESHOLD = 14.0


def frames(video: str, out: Path) -> list[Path]:
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.png"):
        old.unlink()
    subprocess.run(
        [FF, "-v", "error", "-i", video,
         # 上の帯だけを 96px 幅に縮めて取る
         "-vf", f"fps={1/STEP},crop=iw:ih*0.30:0:ih*0.08,scale=96:-2",
         str(out / "f%05d.png")],
        check=True, capture_output=True)
    return sorted(out.glob("*.png"))


def main() -> int:
    from PIL import Image, ImageChops, ImageStat

    work = Path(__file__).resolve().parent / "_scan"
    bad = 0
    for video in sys.argv[1:]:
        shots = frames(video, work)
        changes: list[tuple[float, float]] = []
        previous = None
        for index, shot in enumerate(shots):
            image = Image.open(shot).convert("L")
            if previous is not None:
                diff = ImageStat.Stat(ImageChops.difference(previous, image)).mean[0]
                if diff >= THRESHOLD:
                    changes.append((index * STEP, diff))
            previous = image
        name = Path(video).parent.name
        print(f"{name:26} 背景の変化 {len(changes)}回", end="")
        if changes:
            print("　" + " / ".join(f"{t:.1f}秒({d:.0f})" for t, d in changes[:8]))
        else:
            print()
        if len(changes) > 1:
            bad += 1
    print(f"\n2回以上変わっている動画: {bad}本")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
