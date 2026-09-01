"""docparse の例外。CLI が人間向けの日本語で出せるように1箇所へ集める。"""

from __future__ import annotations


class DocparseError(RuntimeError):
    """docparse のエラーの基底。"""


class DependencyMissing(DocparseError):
    """PDF を読むライブラリが入っていない。"""


class NoTextLayer(DocparseError):
    """PDF に文字が入っていない（紙をスキャンしただけの画像）。

    黙って空文字を返すと「本文が無い書類」と区別がつかず、
    読み落としたことに気づけないので、はっきり失敗させる。
    """
