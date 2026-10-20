"""2 本の動画を上下に並べ、ラベルを付けて 1 本にする(短い方は最後の絵で止めて長さをそろえる)。音は上の動画。

使い方: python tools/compare_videos.py 上.mp4 下.mp4 --labels 手付け 自動 --out out/compare.mp4
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stickfig import cli  # noqa: E402

FONT = "C\\:/Windows/Fonts/meiryob.ttc"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("top")
    ap.add_argument("bottom")
    ap.add_argument("--labels", nargs=2, default=["A", "B"])
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    ff = cli.find_ffmpeg()
    lab = lambda t: f"drawtext=fontfile='{FONT}':text='{t}':x=24:y=20:fontsize=40:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=12"
    fc = (f"[0:v]scale=960:540,tpad=stop_mode=clone:stop_duration=30,{lab(a.labels[0])}[t];"
          f"[1:v]scale=960:540,tpad=stop_mode=clone:stop_duration=30,{lab(a.labels[1])}[b];"
          f"[t][b]vstack=inputs=2[v]")
    import re

    def dur(p):
        m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", subprocess.run([ff, "-i", p], capture_output=True, text=True, errors="ignore").stderr)
        return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))

    T = max(dur(a.top), dur(a.bottom))                    # 長い方にそろえる(短い方は最後の絵で止め、音は無音で延ばす)
    fc += ";[0:a]apad[a]"
    r = subprocess.run([ff, "-y", "-i", a.top, "-i", a.bottom, "-filter_complex", fc, "-map", "[v]", "-map", "[a]",
                        "-t", f"{T:.2f}", "-c:v", "libx264", "-crf", "24", "-pix_fmt", "yuv420p", "-c:a", "aac", a.out], capture_output=True, text=True, errors="ignore")
    if r.returncode:
        print(r.stderr[-1500:])
        raise SystemExit(1)
    print(a.out)


if __name__ == "__main__":
    main()
