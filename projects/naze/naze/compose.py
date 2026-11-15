"""コマを 1 枚ずつ作る関数と語りの wav から mp4 を書き出す(ffmpeg に生の画素を流す)。"""
from __future__ import annotations

import os
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


VCODEC = ["-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p"]


def _free_gb() -> float:
    try:
        if os.name == "nt":
            import ctypes

            class MS(ctypes.Structure):
                _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong), ("ullTotalPhys", ctypes.c_ulonglong),
                            ("ullAvailPhys", ctypes.c_ulonglong), ("a", ctypes.c_ulonglong), ("b", ctypes.c_ulonglong),
                            ("c", ctypes.c_ulonglong), ("d", ctypes.c_ulonglong), ("e", ctypes.c_ulonglong)]
            m = MS()
            m.dwLength = ctypes.sizeof(MS)
            ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m))
            return m.ullAvailPhys / 2 ** 30
        return os.sysconf("SC_AVPHYS_PAGES") * os.sysconf("SC_PAGE_SIZE") / 2 ** 30
    except Exception:
        return 4.0


def jobs(n: int) -> int:
    """同時に描く数。NAZE_JOBS があればそれ。無ければ空きメモリ 0.9GB に 1 つ(ジオイドの回で 1 切れ約 0.8GB、2026-11-15)・芯の数の半分・6 まで。
    短い動画(20 秒未満)は分けても速くならないので 1。"""
    if os.environ.get("NAZE_JOBS"):
        return max(1, int(os.environ["NAZE_JOBS"]))
    if n < FPS * 20:
        return 1
    return max(1, min(6, (os.cpu_count() or 2) // 2, int(_free_gb() // 0.9)))


def render_video(frame: Callable[[int], Image.Image], a: int, b: int, out: Path) -> Path:
    """コマ a..b(両端を含む)を音なしの mp4 に書く。分けて描くときの 1 切れ。"""
    cmd = [ffmpeg(), "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
           *VCODEC, str(out)]
    pr = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for i in range(a, b + 1):
        pr.stdin.write(np.asarray(frame(i).convert("RGB")).tobytes())
    pr.stdin.close()
    if pr.wait() != 0:
        raise SystemExit("ffmpeg が失敗した")
    return out


def _parallel(folder: Path, n: int, j: int, out: Path) -> Path:
    """コマを j 切れに分け、切れごとに別のプロセス(python -m naze seg)で同時に描いて、音なしの 1 本につなぐ。
    コマは前のコマに頼らず描ける作り(各回の draw は時刻 t だけで決まる)なので、どこで切っても同じ絵になる。
    落ちた切れ(メモリ不足など)は、ほかが終わってから 1 つずつ描き直す。"""
    import sys
    import time
    tmp = out.parent / (out.stem + "_seg")
    tmp.mkdir(exist_ok=True)
    cuts = [round(n * k / j) for k in range(j + 1)]
    segs = [(cuts[k] + 1, cuts[k + 1], tmp / f"s{k:02d}.mp4") for k in range(j)]
    t0 = time.time()

    def run(a, b, p):
        return subprocess.Popen([sys.executable, "-m", "naze", "seg", str(folder), str(a), str(b), str(p)])

    procs = [(s, run(*s)) for s in segs]
    bad = [s for s, pr in procs if pr.wait() != 0 or not s[2].exists()]
    for s in bad:                                           # 描き直しは 1 つずつ(メモリを空けて)
        print(f"切れ {s[0]}-{s[1]} を描き直す")
        for _ in range(2):
            if run(*s).wait() == 0 and s[2].exists():
                break
        else:
            raise SystemExit(f"切れ {s[0]}-{s[1]} が描けなかった")
    lst = tmp / "list.txt"
    lst.write_text("".join(f"file '{s[2].as_posix()}'\n" for s in segs), encoding="utf-8")
    vid = tmp / "video.mp4"
    subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(vid)], check=True)
    print(f"{n} コマを {j} つに分けて描いた: {time.time() - t0:.0f} 秒")
    return vid


def write(frame: Callable[[int], Image.Image], n: int, audio: Path, out: Path, bgm: Path = None, bgm_gain: float = 0.12,
          folder: Path = None) -> Path:
    """frame(i) は 1 始まりのコマ番号 i の RGB 画像。音は語り(+ BGM)。音量は loudnorm でそろえる。
    folder(題材のフォルダ)を渡すと、長い動画はコマを分けて同時に描く(jobs() の数だけ)。"""
    import shutil
    out.parent.mkdir(parents=True, exist_ok=True)
    j = jobs(n) if folder is not None else 1
    vid = _parallel(Path(folder), n, j, out) if j > 1 else None
    vin = ["-i", str(vid)] if vid else ["-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-"]
    cmd = [ffmpeg(), "-y", "-loglevel", "error", *vin, "-i", str(audio)]
    if bgm:
        cmd += ["-stream_loop", "-1", "-i", str(bgm), "-filter_complex",
                f"[2:a]volume={bgm_gain}[b];[1:a][b]amix=inputs=2:duration=first:dropout_transition=0,loudnorm=I=-15:TP=-1.5[a]", "-map", "0:v", "-map", "[a]"]
    else:
        cmd += ["-af", _loudnorm(audio) + ",alimiter=limit=0.84:level=false"]      # 効果音の重なりでピークが上限を超えないように
    # veryfast: medium の 1/3 ほどの CPU とメモリ。本編は long で medium に圧縮し直すので画質の差は残らない(2026-11-14)
    cmd += [*(["-c:v", "copy"] if vid else VCODEC), "-c:a", "aac", "-b:a", "160k", "-ar", "48000",
            "-shortest", "-movflags", "+faststart", str(out)]
    if vid:
        r = subprocess.run(cmd)
        shutil.rmtree(vid.parent, ignore_errors=True)
        if r.returncode != 0:
            raise SystemExit("ffmpeg が失敗した")
        return out
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
