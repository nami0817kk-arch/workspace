"""videogen - 画像・音声・字幕を1本の動画にまとめるツールキット。

imagegen（画）と audiogen / imagegen say（音）で作った素材を、
ffmpeg のコマンド1本に組み立てて mp4 にする。

**Python の依存は増やさない。** 必要なのは ffmpeg の実行ファイルだけで、
システムに入っていなければ `pip install -e ".[video]"`（imageio-ffmpeg 同梱）で足りる。
"""

__version__ = "0.1.0"
