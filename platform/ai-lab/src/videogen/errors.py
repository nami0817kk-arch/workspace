"""videogen の例外。CLI が人間向けの日本語で出せるように1箇所へ集める。"""

from __future__ import annotations


class VideogenError(RuntimeError):
    """videogen のエラーの基底。"""


class TimelineError(VideogenError):
    """構成（タイムライン）の書き方が違う。"""


class FfmpegMissingError(VideogenError):
    """ffmpeg の実行ファイルが見つからない。"""
