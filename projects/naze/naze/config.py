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
FPS = 30
# 縦(ショート)か横(本編)か。題材の ep.py の aspect="landscape" を __main__ が読んで、ほかを import する前に環境変数に入れる
ASPECT = os.environ.get("NAZE_ASPECT", "portrait")
W, H = (1920, 1080) if ASPECT == "landscape" else (1080, 1920)
# 字幕・見出し・問い・結びの帯の位置(y は画素、size は字の大きさ)
LAYOUT = dict(
    portrait=dict(maxw=980, header=(150, 56), question=(380, 104), end_band=(1180, 1700), end_text=(1440, 92), sub=(1470, 70), profile=(110, 1000, 970, 1330),
                  sim_question=(520, 104), sim_band=(1380, 1780), sim_end=(1580, 88), sim_sub=(1640, 64)),
    landscape=dict(maxw=1700, header=(70, 44), question=(470, 96), end_band=(760, 1010), end_text=(885, 80), sub=(960, 54), profile=(1150, 520, 1860, 860),
                   sim_question=(470, 96), sim_band=(760, 1010), sim_end=(885, 80), sim_sub=(975, 52)),
)[ASPECT]


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
