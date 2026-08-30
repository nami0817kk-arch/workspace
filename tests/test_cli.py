"""CLI のテスト。"""

from __future__ import annotations

import wave

import pytest

from audiogen import cli

SR = "11025"


def test_sfx_writes_a_wav_file(tmp_path):
    out = tmp_path / "coin.wav"
    assert cli.main(["--rate", SR, "sfx", "coin", "-o", str(out)]) == 0
    with wave.open(str(out), "rb") as fp:
        assert fp.getnchannels() == 1
        assert fp.getnframes() > 0


def test_sfx_defaults_to_the_output_directory(tmp_path):
    assert cli.main(["--rate", SR, "sfx", "jump", "-d", str(tmp_path)]) == 0
    assert (tmp_path / "jump.wav").exists()


def test_sfx_rejects_an_unknown_preset(tmp_path, capsys):
    assert cli.main(["sfx", "kazoo", "-d", str(tmp_path)]) == 2
    assert "unknown sfx preset" in capsys.readouterr().err


def test_sfx_rejects_pitch_on_a_preset_without_it(tmp_path, capsys):
    assert cli.main(["sfx", "explosion", "--pitch", "2.0", "-d", str(tmp_path)]) == 2
    assert "--pitch" in capsys.readouterr().err


def test_bgm_writes_a_wav_file(tmp_path):
    out = tmp_path / "theme.wav"
    args = ["--rate", SR, "bgm", "--style", "menu", "--bars", "1", "--seed", "1", "-o", str(out)]
    assert cli.main(args) == 0
    with wave.open(str(out), "rb") as fp:
        assert fp.getnchannels() == 1
        assert fp.getnframes() > 0


def test_bgm_stereo_flag_writes_two_channels(tmp_path):
    out = tmp_path / "stereo.wav"
    args = ["--rate", SR, "bgm", "--bars", "1", "--seed", "1", "--stereo", "-o", str(out)]
    assert cli.main(args) == 0
    with wave.open(str(out), "rb") as fp:
        assert fp.getnchannels() == 2


def test_bgm_default_filename_uses_the_style(tmp_path):
    args = ["--rate", SR, "bgm", "--style", "chiptune", "--bars", "1", "-d", str(tmp_path)]
    assert cli.main(args) == 0
    assert (tmp_path / "bgm_chiptune.wav").exists()


def test_bgm_without_drops_parts(tmp_path):
    args = [
        "--rate", SR, "bgm", "--bars", "1", "--seed", "1",
        "--without", "drums", "lead", "-d", str(tmp_path),
    ]
    assert cli.main(args) == 0


def test_bgm_reports_an_unknown_style(tmp_path, capsys):
    args = ["bgm", "--style", "polka", "--bars", "1", "-d", str(tmp_path)]
    assert cli.main(args) == 2
    assert "unknown bgm style" in capsys.readouterr().err


def test_list_prints_presets(capsys):
    assert cli.main(["list"]) == 0
    out = capsys.readouterr().out
    assert "coin" in out
    assert "chiptune" in out
    assert "pentatonic_major" in out


def test_demo_writes_every_preset(tmp_path):
    args = ["--rate", SR, "demo", "-d", str(tmp_path), "--bars", "1"]
    assert cli.main(args) == 0
    written = {path.name for path in tmp_path.glob("*.wav")}
    assert "sfx_coin.wav" in written
    assert "bgm_calm.wav" in written


def test_missing_subcommand_exits_with_an_error():
    with pytest.raises(SystemExit):
        cli.main([])


def test_bgm_structure_option_is_accepted(tmp_path):
    args = ["--rate", SR, "bgm", "--bars", "8", "--seed", "1", "--structure", "full", "-d", str(tmp_path)]
    assert cli.main(args) == 0
    assert (tmp_path / "bgm_calm.wav").exists()


def test_bgm_reports_an_unknown_structure(tmp_path, capsys):
    args = ["bgm", "--bars", "4", "--structure", "sonata", "-d", str(tmp_path)]
    assert cli.main(args) == 2
    assert "unknown structure" in capsys.readouterr().err


def test_list_prints_song_structures(capsys):
    assert cli.main(["list"]) == 0
    out = capsys.readouterr().out
    assert "Song structures" in out
    assert "verse_chorus" in out
