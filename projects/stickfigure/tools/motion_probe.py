"""動画の「激しさ」を数字にする(参考の動画と並べて比べる用)。2026-10-22「バトルをもっと激しくして、参考動画みてね」。

測るもの(30fps・320x180 に落として、画面の幅を 1 とした値):
  meanDiff   コマ間の絵の変わり量の平均(参考 PVP の殴り合い 10 秒 = 15.9)
  dupRatio   ほぼ同じ絵が続くコマの割合
  speed      色で追った人物の中心の速さ(幅/秒)の p50/p90/p99
  pathPerSec 1 秒あたりに動いた道のり(幅)
  turns      左右の向きが反転した回数(殴り合いの行き来の多さ)
  activeRatio 動いているコマ(人物が 0.15 幅/秒より速い)の割合

参考の測り方はブラウザ側(動画をキャンバスに描いて同じ式で測る)。参考 PVP(z2sRTaa9lZU)の 156〜166 秒:
  meanDiff 15.9 / dupRatio 0.31 / 人物 speed p90 1.3・p99 4 / pathPerSec 0.2〜0.3 / turns 21〜24(10 秒)

使い方: python tools/motion_probe.py 動画.mp4 [--start 0 --end 10 --step 10] [--color green]
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

W, H, FPS = 320, 180, 30
COLORS = {
    "green": lambda a: (a[..., 1] > 120) & (a[..., 1] - np.maximum(a[..., 0], a[..., 2]) > 40),      # 自作(緑 128,217,77)。参考の緑は明るい黄緑なので同じ式で拾える
    "orange": lambda a: (a[..., 0] > 200) & (a[..., 1] > 80) & (a[..., 1] < 170) & (a[..., 2] < 70),
    "blue": lambda a: (a[..., 2] > 200) & (a[..., 0] < 100) & (a[..., 1] > 100) & (a[..., 1] < 200),
    "purple": lambda a: (a[..., 0] > 120) & (a[..., 0] < 190) & (a[..., 1] < 120) & (a[..., 2] > 180),
    "red": lambda a: (a[..., 0] > 200) & (a[..., 1] > 50) & (a[..., 1] < 120) & (a[..., 2] < 110) & (a[..., 0] - a[..., 1] > 110),
}


def frames(path: str, start: float, end: float):
    from stickfig import cli
    cmd = [cli.find_ffmpeg(), "-loglevel", "error", "-ss", str(start), "-t", str(end - start), "-i", path,
           "-vf", f"fps={FPS},scale={W}:{H}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    n = len(raw) // (W * H * 3)
    return np.frombuffer(raw[: n * W * H * 3], np.uint8).reshape(n, H, W, 3).astype(np.int16)


def measure(arr: np.ndarray, color: str) -> dict:
    n = len(arr)
    diffs = np.abs(arr[1:] - arr[:-1]).sum(-1).mean((1, 2))
    mask_fn = COLORS[color]
    cents = []
    for a in arr:
        m = mask_fn(a)
        c = int(m.sum())
        if 80 <= c <= 2500:
            ys, xs = np.nonzero(m)
            cents.append((xs.mean() / W, ys.mean() / H * 0.5625))
        else:
            cents.append(None)
    sp, path, turns, pd = [], 0.0, 0, 0
    for p, q in zip(cents, cents[1:]):
        if p is None or q is None:
            continue
        dx, dy = q[0] - p[0], q[1] - p[1]
        d = float(np.hypot(dx, dy))
        sp.append(d * FPS)
        path += d
        if abs(dx) > 0.002:
            sg = 1 if dx > 0 else -1
            if pd and sg != pd:
                turns += 1
            pd = sg
    sp = np.array(sp) if sp else np.array([0.0])
    return dict(frames=n, meanDiff=round(float(diffs.mean()), 2) if n > 1 else 0.0, dupRatio=round(float((diffs < 0.12).mean()), 2) if n > 1 else 0.0,
                speed_p50=round(float(np.percentile(sp, 50)), 2), speed_p90=round(float(np.percentile(sp, 90)), 2), speed_p99=round(float(np.percentile(sp, 99)), 2),
                pathPerSec=round(path / max(n / FPS, 1e-6), 2), turns=turns, activeRatio=round(float((sp > 0.15).mean()), 2))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--start", type=float, default=0.0)
    ap.add_argument("--end", type=float, default=None)
    ap.add_argument("--step", type=float, default=10.0, help="この秒数ごとに区切って出す")
    ap.add_argument("--color", default="green", choices=list(COLORS))
    a = ap.parse_args()
    end = a.end
    if end is None:
        from stickfig import cli
        r = subprocess.run([cli.find_ffmpeg(), "-i", a.video], capture_output=True, text=True)
        import re
        m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", r.stderr)
        end = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
    t = a.start
    while t < end - 0.5:
        e = min(end, t + a.step)
        res = measure(frames(a.video, t, e), a.color)
        print(f"{t:6.1f}-{e:6.1f}s  " + "  ".join(f"{k}={v}" for k, v in res.items() if k != "frames"))
        t = e


if __name__ == "__main__":
    main()
