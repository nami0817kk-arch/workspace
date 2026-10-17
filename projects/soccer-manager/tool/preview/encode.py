"""書き出したコマを App Store のプレビュー動画にまとめる。

    flutter test tool/preview/capture_frames_test.dart
    python tool/preview/encode.py

App Preview の決まり（2026-10 時点）:

- 長さ 15〜30秒、H.264、500MB 以内
- iPhone 6.5インチ以上は 886x1920（縦）
- **無音の音声トラックを入れる。** 音声トラックが無い動画を弾かれた
  事例があるため、無音を1本足して確実に通す

言語ごとに1本作る（ストアの掲載は言語ごとにプレビューを持てる）。

ffmpeg は PATH にあるものを使い、無ければ imageio-ffmpeg が持っている
実行ファイルを使う（この PJT に Python の依存を増やさないため、
どちらも無ければそのことだけを言って終わる）。
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

FRAMES_ROOT = "build/preview_frames"
OUT_DIR = "marketing/preview"
LOCALES = ("ja", "en")
FPS = 30  # capture_frames_test.dart の _fps と合わせる


def find_ffmpeg() -> str:
    found = shutil.which("ffmpeg")
    if found:
        return found
    try:
        import imageio_ffmpeg
    except ImportError:
        sys.exit(
            "ffmpeg が見つかりません。PATH に通すか、"
            "pip install imageio-ffmpeg を入れてください。"
        )
    return imageio_ffmpeg.get_ffmpeg_exe()


def encode(ffmpeg: str, locale: str) -> None:
    frames_dir = os.path.join(FRAMES_ROOT, locale)
    out = os.path.join(OUT_DIR, f"app_preview_{locale}.mp4")
    if not os.path.isdir(frames_dir):
        sys.exit(
            f"{frames_dir} がありません。先に\n"
            "  flutter test tool/preview/capture_frames_test.dart\n"
            "を実行してください。"
        )
    frames = sorted(f for f in os.listdir(frames_dir) if f.endswith(".png"))
    if not frames:
        sys.exit(f"{frames_dir} にコマがありません。")
    seconds = len(frames) / FPS
    if not 15 <= seconds <= 30:
        sys.exit(f"{locale}: 長さが {seconds:.1f} 秒。App Preview は 15〜30秒です。")

    os.makedirs(OUT_DIR, exist_ok=True)
    cmd = [
        ffmpeg, "-y",
        "-framerate", str(FPS),
        "-i", os.path.join(frames_dir, "%05d.png"),
        # 無音の音声トラック。音声が無いと弾かれることがある。
        "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
        "-shortest",
        "-c:v", "libx264",
        "-profile:v", "high",
        "-pix_fmt", "yuv420p",   # これを外すと再生できない端末が出る
        "-crf", "20",
        "-c:a", "aac", "-b:a", "96k",
        "-movflags", "+faststart",
        out,
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL)

    size = os.path.getsize(out)
    if size > 500 * 1024 * 1024:
        sys.exit(f"{out} が {size / 1024 / 1024:.0f}MB。500MB を超えています。")
    print(f"[preview] {out}  {len(frames)}コマ / {seconds:.1f}秒 / "
          f"{size / 1024 / 1024:.1f}MB")


def main() -> None:
    ffmpeg = find_ffmpeg()
    for locale in LOCALES:
        encode(ffmpeg, locale)


if __name__ == "__main__":
    main()
