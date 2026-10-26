"""コマを 1 枚ずつ作る関数と語りの wav から mp4 を書き出す(ffmpeg に生の画素を流す)。"""
from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Callable

import numpy as np
from PIL import Image

from .config import FPS, H, W, ffmpeg


def _loudnorm(audio: Path) -> str:
    """音量を -15 LUFS にそろえる。1 回目で測った値を 2 回目に渡す(1 回だけだと 2〜3 dB ずれる)。"""
    import json
    import re
    base = "loudnorm=I=-15:TP=-1.5:LRA=11"
    r = subprocess.run([ffmpeg(), "-hide_banner", "-i", str(audio), "-af", base + ":print_format=json", "-f", "null", "-"],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    m = re.search(r"\{[^{}]*\"input_i\"[^{}]*\}", r.stderr)
    if not m:
        return base
    j = json.loads(m.group(0))
    return (f"{base}:measured_I={j['input_i']}:measured_TP={j['input_tp']}:measured_LRA={j['input_lra']}"
            f":measured_thresh={j['input_thresh']}:offset={j['target_offset']}:linear=true")


def write(frame: Callable[[int], Image.Image], n: int, audio: Path, out: Path, bgm: Path = None, bgm_gain: float = 0.12) -> Path:
    """frame(i) は 1 始まりのコマ番号 i の RGB 画像。音は語り(+ BGM)。音量は loudnorm でそろえる。"""
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = [ffmpeg(), "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-i", str(audio)]
    if bgm:
        cmd += ["-stream_loop", "-1", "-i", str(bgm), "-filter_complex",
                f"[2:a]volume={bgm_gain}[b];[1:a][b]amix=inputs=2:duration=first:dropout_transition=0,loudnorm=I=-15:TP=-1.5[a]", "-map", "0:v", "-map", "[a]"]
    else:
        cmd += ["-af", _loudnorm(audio) + ",alimiter=limit=0.84:level=false"]      # 効果音の重なりでピークが上限を超えないように
    cmd += ["-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k", "-ar", "48000",
            "-shortest", "-movflags", "+faststart", str(out)]
    pr = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for i in range(1, n + 1):
        pr.stdin.write(np.asarray(frame(i).convert("RGB")).tobytes())
    pr.stdin.close()
    if pr.wait() != 0:
        raise SystemExit("ffmpeg が失敗した")
    return out


def sheet(video: Path, times, out: Path, size=None) -> Path:
    """動画から時刻 times(秒)のコマを抜いて横に並べる(目で確かめる用)。"""
    size = size or (W // 3, H // 3)
    ims = []
    for i, t in enumerate(times):
        p = out.with_name(f"_s{i}.png")
        subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-ss", f"{t:.2f}", "-i", str(video), "-frames:v", "1", str(p)], check=True)
        ims.append(Image.open(p).resize(size))
        p.unlink()
    s = Image.new("RGB", (size[0] * len(ims), size[1]))
    for i, im in enumerate(ims):
        s.paste(im, (i * size[0], 0))
    s.save(out)
    return out
