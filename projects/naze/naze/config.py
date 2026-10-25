"""置き場所と外の道具(ffmpeg・Blender・VOICEVOX・字体)。"""
from __future__ import annotations

import os
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "cache"                  # 標高タイルなど(gitignore)
OUT = ROOT / "out"                      # 書き出し(gitignore)
VOICEVOX = os.environ.get("VOICEVOX_URL", "http://127.0.0.1:50021")
FONT = "C:/Windows/Fonts/YuGothB.ttc"
FONT_REG = "C:/Windows/Fonts/YuGothM.ttc"
W, H, FPS = 1080, 1920, 30


def ffmpeg() -> str:
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        p = shutil.which("ffmpeg")
        if p:
            return p
    raise SystemExit("ffmpeg が見つからない")


def blender() -> str:
    for p in (os.environ.get("NAZE_BLENDER"), r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe", shutil.which("blender")):
        if p and Path(p).exists():
            return p
    raise SystemExit("Blender が見つからない(NAZE_BLENDER に場所を入れる)")
