"""audiogen - BGM と効果音を手続き的に生成する、依存ライブラリなしのツールキット。

使い方の例::

    from audiogen import bgm, sfx, write_wav

    write_wav("output/coin.wav", sfx.generate("coin"))
    write_wav("output/theme.wav", bgm.generate(bgm.BGMConfig(style="adventure", seed=1)))

コマンドラインからは ``python -m audiogen --help`` を参照。
"""

from . import bgm, drums, effects, envelope, notes, oscillators, sfx
from .bgm import BGMConfig
from .core import SAMPLE_RATE, duration_of, mix, normalize, to_stereo, write_wav

__version__ = "0.1.0"

__all__ = [
    "BGMConfig",
    "SAMPLE_RATE",
    "__version__",
    "bgm",
    "drums",
    "duration_of",
    "effects",
    "envelope",
    "mix",
    "normalize",
    "notes",
    "oscillators",
    "sfx",
    "to_stereo",
    "write_wav",
]
