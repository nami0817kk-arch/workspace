"""videogen のテスト共通設定。"""

import wave

import pytest


@pytest.fixture(autouse=True)
def no_ffmpeg(monkeypatch):
    """テストから ffmpeg を起動しない。

    組み立てたコマンドを検証するのがこのツールのテストの主眼で、
    実行してしまうと環境によって結果が変わる（そもそも入っていない環境もある）。
    """
    import subprocess

    def refuse(*args, **kwargs):
        raise AssertionError(f"テストから外部プロセスを起動しようとしました: {args[:1]}")

    monkeypatch.setattr(subprocess, "run", refuse)


@pytest.fixture(autouse=True)
def no_ffmpeg_env(monkeypatch):
    """開発機の設定をテストに持ち込まない。"""
    monkeypatch.delenv("VIDEOGEN_FFMPEG", raising=False)


@pytest.fixture
def make_wav():
    """長さの分かる WAV を作る（ffmpeg なしで長さを測れる）。"""

    def build(path, seconds=1.0, rate=8000):
        with wave.open(str(path), "wb") as writer:
            writer.setnchannels(1)
            writer.setsampwidth(2)
            writer.setframerate(rate)
            writer.writeframes(bytes(2 * int(rate * seconds)))
        return path

    return build
