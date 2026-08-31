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


def test_sfx_pitch_works_on_every_preset(tmp_path):
    assert cli.main(["--rate", SR, "sfx", "explosion", "--pitch", "2.0", "-d", str(tmp_path)]) == 0
    assert (tmp_path / "explosion.wav").exists()


def test_sfx_count_writes_numbered_variations(tmp_path):
    args = ["--rate", SR, "sfx", "footstep", "--count", "4", "--seed", "1", "-d", str(tmp_path)]
    assert cli.main(args) == 0
    written = sorted(path.name for path in tmp_path.glob("*.wav"))
    assert written == ["footstep_1.wav", "footstep_2.wav", "footstep_3.wav", "footstep_4.wav"]


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


def test_describe_prints_a_readable_summary(capsys):
    args = ["describe", "--style", "battle", "--key", "A", "--bars", "4", "--seed", "3"]
    assert cli.main(args) == 0
    out = capsys.readouterr().out
    assert "battle" in out
    assert "harmonic_minor" in out
    assert "sections:" in out
    assert "melody:" in out


def test_describe_json_is_machine_readable(capsys):
    import json

    assert cli.main(["describe", "--bars", "4", "--seed", "1", "--json"]) == 0
    summary = json.loads(capsys.readouterr().out)
    assert summary["bars"] == 4
    assert summary["seed"] == 1
    assert summary["melody"]


def test_describe_reports_an_unknown_style(capsys):
    assert cli.main(["describe", "--style", "polka"]) == 2
    assert "unknown bgm style" in capsys.readouterr().err


def test_describe_writes_no_files(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    assert cli.main(["describe", "--bars", "2"]) == 0
    assert list(tmp_path.iterdir()) == []


def test_bgm_swing_and_humanize_options(tmp_path):
    args = [
        "--rate", SR, "bgm", "--bars", "2", "--seed", "1",
        "--swing", "0.5", "--humanize", "0.0", "-d", str(tmp_path),
    ]
    assert cli.main(args) == 0
    assert (tmp_path / "bgm_calm.wav").exists()


def test_bgm_instrument_options(tmp_path):
    args = [
        "--rate", SR, "bgm", "--bars", "2", "--seed", "1",
        "--lead-instrument", "marimba", "--chord-instrument", "organ",
        "-d", str(tmp_path),
    ]
    assert cli.main(args) == 0
    assert (tmp_path / "bgm_calm.wav").exists()


def test_bgm_reports_an_unknown_instrument(tmp_path, capsys):
    args = ["bgm", "--bars", "2", "--lead-instrument", "kazoo", "-d", str(tmp_path)]
    assert cli.main(args) == 2
    assert "unknown instrument" in capsys.readouterr().err


def test_list_prints_instruments(capsys):
    assert cli.main(["list"]) == 0
    out = capsys.readouterr().out
    assert "Instruments:" in out
    assert "marimba" in out


def _sample_manifest(tmp_path):
    import json

    path = tmp_path / "assets.json"
    path.write_text(
        json.dumps(
            {
                "sample_rate": 11025,
                "sfx": [{"name": "coin", "as": "se/coin", "seed": 1}],
                "bgm": [{"as": "bgm/title", "style": "menu", "bars": 1, "seed": 2}],
            }
        ),
        encoding="utf-8",
    )
    return path


def test_build_generates_the_declared_assets(tmp_path, capsys):
    out = tmp_path / "assets"
    assert cli.main(["build", str(_sample_manifest(tmp_path)), "-d", str(out)]) == 0
    assert (out / "se" / "coin.wav").exists()
    assert (out / "bgm" / "title.wav").exists()
    assert "written: 2" in capsys.readouterr().out


def test_build_skips_unchanged_assets_on_a_second_run(tmp_path, capsys):
    out = tmp_path / "assets"
    path = _sample_manifest(tmp_path)
    assert cli.main(["build", str(path), "-d", str(out)]) == 0
    capsys.readouterr()
    assert cli.main(["build", str(path), "-d", str(out)]) == 0
    assert "skipped: 2" in capsys.readouterr().out


def test_build_dry_run_writes_nothing(tmp_path, capsys):
    out = tmp_path / "assets"
    assert cli.main(["build", str(_sample_manifest(tmp_path)), "-d", str(out), "--dry-run"]) == 0
    assert "planned: 2" in capsys.readouterr().out
    assert not out.exists()


def test_build_reports_a_bad_manifest(tmp_path, capsys):
    import json

    path = tmp_path / "bad.json"
    path.write_text(json.dumps({"sfx": [{"name": "kazoo"}]}), encoding="utf-8")
    assert cli.main(["build", str(path), "-d", str(tmp_path / "out")]) == 2
    assert "unknown preset" in capsys.readouterr().err


def test_build_reports_a_missing_manifest(tmp_path, capsys):
    assert cli.main(["build", str(tmp_path / "nope.json")]) == 2
    assert "error:" in capsys.readouterr().err


def test_preview_writes_a_page(tmp_path, capsys):
    assert cli.main(["--rate", SR, "sfx", "coin", "-d", str(tmp_path)]) == 0
    assert cli.main(["preview", "-d", str(tmp_path)]) == 0
    assert "index.html" in capsys.readouterr().out
    assert "<audio" in (tmp_path / "index.html").read_text(encoding="utf-8")


def test_preview_reports_an_empty_directory(tmp_path, capsys):
    assert cli.main(["preview", "-d", str(tmp_path)]) == 2
    assert "no .wav files" in capsys.readouterr().err


def test_demo_writes_a_preview_page(tmp_path):
    assert cli.main(["--rate", SR, "demo", "-d", str(tmp_path), "--bars", "1"]) == 0
    assert (tmp_path / "index.html").exists()


def test_demo_can_skip_the_preview_page(tmp_path):
    args = ["--rate", SR, "demo", "-d", str(tmp_path), "--bars", "1", "--no-preview"]
    assert cli.main(args) == 0
    assert not (tmp_path / "index.html").exists()


def test_bgm_midi_option_writes_a_score(tmp_path):
    args = ["--rate", SR, "bgm", "--bars", "2", "--seed", "1", "--midi", "-d", str(tmp_path)]
    assert cli.main(args) == 0
    score = tmp_path / "bgm_calm.mid"
    assert score.exists()
    assert score.read_bytes()[:4] == b"MThd"
    assert (tmp_path / "bgm_calm.wav").exists()


def test_bgm_without_midi_writes_only_audio(tmp_path):
    assert cli.main(["--rate", SR, "bgm", "--bars", "2", "-d", str(tmp_path)]) == 0
    assert not list(tmp_path.glob("*.mid"))


def test_bgm_ritardando_option(tmp_path):
    args = [
        "--rate", SR, "bgm", "--bars", "4", "--seed", "1",
        "--ritardando", "2", "--final-tempo", "0.6", "--ending", "-d", str(tmp_path),
    ]
    assert cli.main(args) == 0
    assert (tmp_path / "bgm_calm.wav").exists()


def test_describe_works_without_the_ritardando_flags(capsys):
    assert cli.main(["describe", "--bars", "2"]) == 0
    assert "sections:" in capsys.readouterr().out
