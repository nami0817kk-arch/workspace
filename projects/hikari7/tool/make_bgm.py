"""BGM を作る（2026-10-03 ユーザー選択「BGM は audiogen で作って同梱」）。

platform/ai-lab の audiogen（手続き的合成。生成AIではない・依存なし）で場面ごとの曲を合成し、
ループできる MP3 にして app/assets/audio/bgm/ に置く（Web 版は組み立てのときに写す）。同じ設定なら同じ曲になる（seed 固定）。

    python tool/make_bgm.py            # 全曲
    python tool/make_bgm.py title      # 1曲だけ

MP3 への変換は imageio_ffmpeg に同梱の ffmpeg を使う（pip install imageio-ffmpeg）。
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, '..', '..', 'platform', 'ai-lab', 'src'))
from audiogen import bgm  # noqa: E402
from audiogen.core import write_wav  # noqa: E402

OUT = os.path.join(ROOT, 'app', 'assets', 'audio', 'bgm')
SR = 32000

# 場面ごとの曲。bars は小節数（ループの長さ）
TRACKS = {
    'title':    dict(style='adventure', key='D', bpm=120, bars=16, seed=701, lead_instrument='bell'),
    'practice': dict(style='menu', key='F', bpm=100, bars=16, seed=702),
    'night':    dict(style='night', key='A', bpm=68, bars=12, seed=703),
    'stage':    dict(style='adventure', key='E', bpm=138, bars=16, seed=704),
    'judge':    dict(style='tension', key='C', bpm=92, bars=12, seed=705),
    'ending':   dict(style='calm', key='G', bpm=82, bars=16, seed=706),
}


def ffmpeg():
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
        subprocess.run([ffmpeg(), '-y', '-loglevel', 'error', '-i', wav, '-codec:a', 'libmp3lame', '-b:a', '96k', mp3], check=True)
    sec = len(buf) / 2 / SR
    print(f'{name}: {sec:.1f}秒 {os.path.getsize(mp3) // 1024}KB')


if __name__ == '__main__':
    for n in (sys.argv[1:] or TRACKS):
        make(n)
