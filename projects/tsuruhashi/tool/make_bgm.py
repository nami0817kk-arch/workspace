"""BGM を作る（2026-10-04、hikari7 の tool/make_bgm.py と同じ作り）。

platform/ai-lab の audiogen（手続き的合成。生成AIではない・依存なし）で場面ごとの曲を合成し、
ループできる MP3 にして prototype/audio/ に置く。同じ設定なら同じ曲になる（seed 固定）。

    python tool/make_bgm.py            # 全曲
    python tool/make_bgm.py deep       # 1曲だけ

MP3 への変換は ffmpeg（なければ imageio_ffmpeg に同梱のもの）を使う。
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, '..', '..', 'platform', 'ai-lab', 'src'))
from audiogen import bgm  # noqa: E402
from audiogen.core import write_wav  # noqa: E402

OUT = os.path.join(ROOT, 'prototype', 'audio')
SR = 32000

# 場面ごとの曲。surface＝地上と浅い層、mine＝2〜5層、deep＝6層より下
TRACKS = {
    'surface': dict(style='adventure', key='D', bpm=108, bars=16, seed=811, lead_instrument='bell'),
    'mine':    dict(style='calm', key='F', bpm=90, bars=16, seed=812),
    'deep':    dict(style='night', key='A', bpm=70, bars=12, seed=813),
}


def ffmpeg():
    exe = shutil.which('ffmpeg')
    if exe:
        return exe
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def make(name):
    cfg = dict(TRACKS[name], sr=SR, structure='loop', loop=True)
    buf = bgm.generate_stereo(**cfg)
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, name + '.wav')
        write_wav(wav, buf, sr=SR, channels=2)
        mp3 = os.path.join(OUT, name + '.mp3')
        subprocess.run([ffmpeg(), '-y', '-loglevel', 'error', '-i', wav, '-codec:a', 'libmp3lame', '-b:a', '80k', mp3], check=True)
    sec = len(buf) / 2 / SR
    print(f'{name}: {sec:.1f}秒 {os.path.getsize(mp3) // 1024}KB')


if __name__ == '__main__':
    for n in (sys.argv[1:] or TRACKS):
        make(n)
