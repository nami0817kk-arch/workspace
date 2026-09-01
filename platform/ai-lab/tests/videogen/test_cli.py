"""videogen コマンド。"""

import json

import pytest

from videogen import cli, ffmpeg


@pytest.fixture
def project(tmp_path, make_wav):
    (tmp_path / "a.png").write_bytes(b"x")
    (tmp_path / "b.png").write_bytes(b"x")
    make_wav(tmp_path / "n.wav", seconds=1.0)
    path = tmp_path / "news.json"
    path.write_text(
        json.dumps(
            {
                "scenes": [
                    {"image": str(tmp_path / "a.png"), "audio": str(tmp_path / "n.wav"), "text": "見出し"},
                    {"image": str(tmp_path / "b.png"), "seconds": 2, "motion": "pan_left"},
                ],
                "size": "1280x720",
            }
        ),
        encoding="utf-8",
    )
    return path


def test_build_dry_run_shows_the_command(project, capsys):
    assert cli.main(["build", str(project), "--dry-run"]) == 0
    out = capsys.readouterr().out
    assert out.startswith("[ドライラン]")
    assert "ffmpeg -loop 1" in out
    assert "libx264" in out


def test_build_writes_the_subtitles_next_to_the_video(project, capsys):
    cli.main(["build", str(project), "--dry-run"])
    assert (project.with_suffix(".srt")).is_file()
    assert "字幕:" in capsys.readouterr().out


def test_build_can_override_the_size_for_vertical_video(project, capsys):
    """同じ構成から縦動画を作れる（Shorts 用）。"""
    assert cli.main(["build", str(project), "--dry-run", "--size", "1080x1920"]) == 0
    assert "1080:1920" in capsys.readouterr().out


def test_build_rejects_a_bad_size(project, capsys):
    assert cli.main(["build", str(project), "--dry-run", "--size", "たて"]) == 1
    assert "エラー" in capsys.readouterr().err


def test_build_can_override_the_fps(project, capsys):
    cli.main(["build", str(project), "--dry-run", "--fps", "24"])
    assert "fps=24" in capsys.readouterr().out


def test_build_runs_ffmpeg_when_not_a_dry_run(project, monkeypatch, capsys):
    calls = []
    monkeypatch.setattr("videogen.build.ffmpeg_module.run", lambda args: calls.append(args))
    assert cli.main(["build", str(project)]) == 0
    assert len(calls) == 1
    assert "書き出しました" in capsys.readouterr().out


def test_srt_writes_only_the_subtitles(project, tmp_path, capsys):
    assert cli.main(["srt", str(project), "-o", str(tmp_path / "sub.srt")]) == 0
    assert "見出し" in (tmp_path / "sub.srt").read_text(encoding="utf-8")
    assert "書き出しました" in capsys.readouterr().out


def test_srt_says_when_there_is_nothing_to_write(tmp_path, capsys):
    path = tmp_path / "t.json"
    path.write_text(json.dumps({"scenes": [{"image": "a.png"}]}), encoding="utf-8")
    assert cli.main(["srt", str(path)]) == 1
    assert "字幕のあるシーンがありません" in capsys.readouterr().out


def test_probe_measures_a_wav(tmp_path, make_wav, capsys):
    path = make_wav(tmp_path / "a.wav", seconds=1.5)
    assert cli.main(["probe", str(path)]) == 0
    assert "1.500秒" in capsys.readouterr().out


def test_doctor_reports_a_missing_ffmpeg(monkeypatch, capsys):
    monkeypatch.setattr(ffmpeg, "is_available", lambda: False)
    assert cli.main(["doctor"]) == 1
    assert "video" in capsys.readouterr().err  # 入れ方を案内する


def test_doctor_reports_the_binary(monkeypatch, capsys):
    monkeypatch.setattr(ffmpeg, "is_available", lambda: True)
    monkeypatch.setattr(ffmpeg, "find_ffmpeg", lambda: "/usr/bin/ffmpeg")
    monkeypatch.setattr(ffmpeg, "version", lambda: "ffmpeg version 7.1")
    assert cli.main(["doctor"]) == 0
    assert "7.1" in capsys.readouterr().out


def test_missing_timeline_is_an_error(tmp_path, capsys):
    assert cli.main(["build", str(tmp_path / "nope.yaml"), "--dry-run"]) == 1
    assert "構成ファイルがありません" in capsys.readouterr().err
