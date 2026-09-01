"""ffmpeg の場所の決め方と、長さの測り方。"""

import subprocess
import sys

import pytest

from videogen import ffmpeg
from videogen.errors import FfmpegMissingError, VideogenError


class FakeCompleted:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


@pytest.fixture
def fake_run(monkeypatch):
    """subprocess.run を差し替える（conftest が塞いでいるものを、意図した形で開ける）。"""
    calls = []

    def runner(result):
        def fake(args, **kwargs):
            calls.append(args)
            return result

        monkeypatch.setattr(subprocess, "run", fake)
        return calls

    return runner


# --- 場所を決める -----------------------------------------------------
def test_explicit_path_wins(monkeypatch, tmp_path):
    exe = tmp_path / "ffmpeg.exe"
    exe.write_bytes(b"x")
    monkeypatch.setenv(ffmpeg.ENV_NAME, str(exe))
    assert ffmpeg.find_ffmpeg() == str(exe)


def test_explicit_path_must_exist(monkeypatch, tmp_path):
    monkeypatch.setenv(ffmpeg.ENV_NAME, str(tmp_path / "nope"))
    with pytest.raises(FfmpegMissingError, match=ffmpeg.ENV_NAME):
        ffmpeg.find_ffmpeg()


def test_falls_back_to_the_path(monkeypatch):
    monkeypatch.setattr(ffmpeg.shutil, "which", lambda name: "/usr/bin/ffmpeg")
    assert ffmpeg.find_ffmpeg() == "/usr/bin/ffmpeg"


def test_missing_ffmpeg_explains_how_to_get_it(monkeypatch):
    monkeypatch.setattr(ffmpeg.shutil, "which", lambda name: None)
    monkeypatch.setitem(sys.modules, "imageio_ffmpeg", None)  # import を失敗させる
    with pytest.raises(FfmpegMissingError) as error:
        ffmpeg.find_ffmpeg()
    assert "video" in str(error.value)  # 入れ方を必ず案内する
    assert not ffmpeg.is_available()


def test_uses_the_bundled_binary(monkeypatch):
    class Bundled:
        @staticmethod
        def get_ffmpeg_exe():
            return "/site-packages/ffmpeg"

    monkeypatch.setattr(ffmpeg.shutil, "which", lambda name: None)
    monkeypatch.setitem(sys.modules, "imageio_ffmpeg", Bundled)
    assert ffmpeg.find_ffmpeg() == "/site-packages/ffmpeg"


# --- 実行 -------------------------------------------------------------
def test_run_reports_the_tail_of_the_error(monkeypatch, fake_run):
    monkeypatch.setattr(ffmpeg, "find_ffmpeg", lambda: "ffmpeg")
    fake_run(FakeCompleted(returncode=1, stderr="行1\n本当の理由はここ"))
    with pytest.raises(VideogenError, match="本当の理由はここ"):
        ffmpeg.run(["-i", "a.png"])


def test_run_passes_overwrite_and_quiet(monkeypatch, fake_run):
    monkeypatch.setattr(ffmpeg, "find_ffmpeg", lambda: "ffmpeg")
    calls = fake_run(FakeCompleted())
    ffmpeg.run(["-i", "a.png"])
    assert calls[0][:4] == ["ffmpeg", "-y", "-loglevel", "error"]


def test_version_reads_the_first_line(monkeypatch, fake_run):
    monkeypatch.setattr(ffmpeg, "find_ffmpeg", lambda: "ffmpeg")
    fake_run(FakeCompleted(stdout="ffmpeg version 7.1\nbuilt with"))
    assert ffmpeg.version() == "ffmpeg version 7.1"


# --- 長さ -------------------------------------------------------------
def test_parse_duration():
    assert ffmpeg.parse_duration("  Duration: 00:01:02.50, start: 0.0") == 62.5
    assert ffmpeg.parse_duration("なにもない") is None


def test_wav_is_measured_without_ffmpeg(tmp_path, make_wav):
    """WAV は標準ライブラリで測る。conftest が塞いだ subprocess を通らない。"""
    path = make_wav(tmp_path / "a.wav", seconds=2.0)
    assert ffmpeg.probe_seconds(path) == pytest.approx(2.0)


def test_broken_wav_falls_back_to_ffmpeg(tmp_path, monkeypatch, fake_run):
    path = tmp_path / "broken.wav"
    path.write_bytes(b"not a wav")
    monkeypatch.setattr(ffmpeg, "find_ffmpeg", lambda: "ffmpeg")
    fake_run(FakeCompleted(stderr="  Duration: 00:00:03.00, start: 0.0"))
    assert ffmpeg.probe_seconds(path) == pytest.approx(3.0)


def test_probe_reports_a_missing_file(tmp_path):
    with pytest.raises(VideogenError, match="ファイルがありません"):
        ffmpeg.probe_seconds(tmp_path / "nope.mp3")


def test_probe_reports_an_unreadable_file(tmp_path, monkeypatch, fake_run):
    path = tmp_path / "a.mp3"
    path.write_bytes(b"x")
    monkeypatch.setattr(ffmpeg, "find_ffmpeg", lambda: "ffmpeg")
    fake_run(FakeCompleted(stderr="Invalid data"))
    with pytest.raises(VideogenError, match="長さを読み取れません"):
        ffmpeg.probe_seconds(path)
