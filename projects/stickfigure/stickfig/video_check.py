"""書き出した動画を、画像から点検する(plan の点検とは別。見た目の側から二重に見る)。

見つけるもの: 意図しない静止、1コマで大きく変わった所(ワープ・ガタつき)、白黒の切り替わり(衝撃のコマ)。
出力: コマごとの動きの量の折れ線(energy.png)と、報告(report.md)。
"""
from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT = "C:/Windows/Fonts/YuGothB.ttc"


def decode_gray(ffmpeg: str, path, w: int = 320, h: int = 180) -> np.ndarray:
    p = subprocess.run([ffmpeg, "-v", "error", "-i", str(path), "-vf", f"scale={w}:{h}", "-pix_fmt", "gray",
                        "-f", "rawvideo", "-"], capture_output=True, check=True)
    arr = np.frombuffer(p.stdout, dtype=np.uint8)
    n = arr.size // (w * h)
    return arr[: n * w * h].reshape(n, h, w).astype(np.float32)


def runs(mask: Sequence[bool], min_len: int) -> List[Tuple[int, int]]:
    out, start = [], None
    for i, v in enumerate(mask):
        if v and start is None:
            start = i
        if (not v or i == len(mask) - 1) and start is not None:
            end = i if not v else i + 1
            if end - start >= min_len:
                out.append((start, end))
            start = None
    return out


def analyze(gray: np.ndarray, fps: float, hold_frames: Sequence[int] = ()) -> Dict[str, object]:
    n = len(gray)
    diff = np.zeros(n, dtype=np.float32)
    diff[1:] = np.abs(gray[1:] - gray[:-1]).mean(axis=(1, 2))
    bright = gray.mean(axis=(1, 2))
    still = diff < 0.02
    holds = set(hold_frames)
    st = [(a, b) for a, b in runs(still, 4) if not all(i in holds for i in range(a, b))]
    med = np.array([np.median(diff[max(0, i - 6): i + 7]) for i in range(n)])
    spikes = [i for i in range(1, n) if diff[i] > max(6.0, 6 * med[i])]
    flash = [i for i in spikes if abs(bright[i] - bright[i - 1]) > 40]
    pops = [i for i in spikes if i not in flash]
    return dict(n=n, fps=fps, diff=diff, static=st, flashes=flash, pops=pops)


def chart(values: np.ndarray, fps: float, marks: Sequence[Tuple[int, int, tuple]], title: str, path, w: int = 1400, h: int = 360) -> None:
    im = Image.new("RGB", (w, h), (255, 255, 255))
    d = ImageDraw.Draw(im)
    try:
        f = ImageFont.truetype(FONT, 18)
    except OSError:
        f = ImageFont.load_default()
    ml, mr, mt, mb = 60, 20, 40, 40
    vmax = max(1e-6, float(np.max(values)))
    n = len(values)
    d.text((ml, 8), title, font=f, fill=(0, 0, 0))
    d.rectangle([ml, mt, w - mr, h - mb], outline=(180, 180, 180))
    for s in range(0, int(n / fps) + 1):
        x = ml + (w - ml - mr) * (s * fps) / max(1, n - 1)
        d.line([x, mt, x, h - mb], fill=(230, 230, 230))
        d.text((x - 8, h - mb + 6), f"{s}s", font=f, fill=(90, 90, 90))
    for a, b, col in marks:
        x0 = ml + (w - ml - mr) * a / max(1, n - 1)
        x1 = ml + (w - ml - mr) * b / max(1, n - 1)
        d.rectangle([x0, mt, x1, h - mb], fill=col)
    pts = [(ml + (w - ml - mr) * i / max(1, n - 1), h - mb - (h - mt - mb) * float(v) / vmax) for i, v in enumerate(values)]
    d.line(pts, fill=(40, 90, 200), width=2)
    im.save(path)


def check_video(ffmpeg: str, video, out_dir, hold_frames: Sequence[int] = (), fps: float = 30.0) -> Dict[str, object]:
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    gray = decode_gray(ffmpeg, video)
    res = analyze(gray, fps, hold_frames)
    diff = res["diff"]
    cap = float(np.percentile(diff, 97)) * 1.4 + 1e-6      # 白黒反転の巨大な山で他が潰れないよう頭打ち
    marks = [(a, b, (255, 235, 200)) for a, b in res["static"]] + [(i, i + 1, (255, 190, 190)) for i in res["flashes"]]
    chart(np.minimum(diff, cap), fps, marks, f"コマごとの動きの量(橙=静止、赤=白黒の切り替わり。{cap:.0f}で頭打ち)", out_dir / "energy.png")
    lines = ["# 動画の点検(画像から)", "", f"- 長さ {res['n'] / fps:.2f}秒 / {res['n']}コマ", "", "## 意図しない静止(4コマ以上)"]
    lines += [f"- {a / fps:.2f}〜{b / fps:.2f}秒" for a, b in res["static"]] or ["- なし"]
    lines += ["", "## 1コマで大きく変わった所(ワープ・ガタつきの疑い)"]
    lines += [f"- {i / fps:.2f}秒" for i in res["pops"]] or ["- なし"]
    lines += ["", "## 白黒の切り替わり(衝撃のコマ)"]
    lines += [f"- {i / fps:.2f}秒" for i in res["flashes"]] or ["- なし"]
    (out_dir / "video_report.md").write_text("\n".join(lines), encoding="utf-8")
    res["report"] = str(out_dir / "video_report.md")
    return res
