"""マニフェストによる一括生成のテスト。"""

from __future__ import annotations

import json
import wave

import pytest

from audiogen import manifest

SR = 11025


def _manifest_data(**overrides):
    data = {
        "sample_rate": SR,
        "sfx": [
            {"name": "coin", "as": "se/coin", "seed": 1},
            {"name": "footstep", "as": "se/step", "count": 3, "seed": 2},
        ],
        "bgm": [{"as": "bgm/title", "style": "menu", "bars": 1, "seed": 7}],
    }
    data.update(overrides)
    return data


def _write_manifest(tmp_path, data):
    path = tmp_path / "assets.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


# --- 読み込みと検証 -----------------------------------------------------------


def test_parse_collects_every_asset():
    parsed = manifest.parse(_manifest_data())
    assert [asset.path for asset in parsed.assets] == ["se/coin", "se/step", "bgm/title"]
    assert [asset.kind for asset in parsed.assets] == ["sfx", "sfx", "bgm"]
    assert parsed.sample_rate == SR


def test_a_counted_sfx_declares_numbered_outputs():
    parsed = manifest.parse(_manifest_data())
    assert parsed.assets[1].outputs() == ["se/step_1.wav", "se/step_2.wav", "se/step_3.wav"]


def test_names_default_to_the_preset_and_style():
    parsed = manifest.parse({"sfx": [{"name": "coin"}], "bgm": [{"style": "night"}]})
    assert [asset.path for asset in parsed.assets] == ["coin", "bgm_night"]


def test_load_reads_a_file(tmp_path):
    parsed = manifest.load(_write_manifest(tmp_path, _manifest_data()))
    assert len(parsed.assets) == 3


def test_invalid_json_is_reported(tmp_path):
    path = tmp_path / "broken.json"
    path.write_text("{not json", encoding="utf-8")
    with pytest.raises(manifest.ManifestError, match="invalid JSON"):
        manifest.load(path)


@pytest.mark.parametrize(
    "data,message",
    [
        ([], "must be a JSON object"),
        ({"sfx": [{"name": "coin"}], "colour": "red"}, "unknown top-level keys"),
        ({"sfx": [{"name": "kazoo"}]}, "unknown preset"),
        ({"sfx": [{"name": "coin", "volume": 2}]}, "unknown keys"),
        ({"sfx": [{"name": "coin", "count": 0}]}, "'count' must be >= 1"),
        ({"sfx": ["coin"]}, "must be an object"),
        ({"bgm": [{"style": "calm", "tempo": 120}]}, "unknown keys"),
        ({}, "no assets"),
        ({"sfx": [{"name": "coin"}], "sample_rate": 0}, "sample_rate must be positive"),
    ],
)
def test_bad_manifests_are_rejected(data, message):
    with pytest.raises(manifest.ManifestError, match=message):
        manifest.parse(data)


@pytest.mark.parametrize("path", ["/etc/passwd", "../escape", "a/../../b", ""])
def test_output_paths_cannot_escape_the_directory(path):
    with pytest.raises(manifest.ManifestError):
        manifest.parse({"sfx": [{"name": "coin", "as": path}]})


# --- 生成 ---------------------------------------------------------------------


def test_build_writes_every_declared_file(tmp_path):
    results = manifest.build(manifest.parse(_manifest_data()), str(tmp_path))
    assert manifest.summarise(results) == {"written": 3}
    for name in ("se/coin.wav", "se/step_1.wav", "se/step_3.wav", "bgm/title.wav"):
        assert (tmp_path / name).exists()


def test_build_honours_the_declared_sample_rate(tmp_path):
    manifest.build(manifest.parse(_manifest_data()), str(tmp_path))
    with wave.open(str(tmp_path / "se/coin.wav"), "rb") as fp:
        assert fp.getframerate() == SR


def test_stereo_bgm_is_written_with_two_channels(tmp_path):
    data = {"sample_rate": SR, "bgm": [{"as": "wide", "style": "menu", "bars": 1, "stereo": True}]}
    manifest.build(manifest.parse(data), str(tmp_path))
    with wave.open(str(tmp_path / "wide.wav"), "rb") as fp:
        assert fp.getnchannels() == 2


def test_bgm_options_are_passed_through(tmp_path):
    data = {
        "sample_rate": SR,
        "bgm": [
            {
                "as": "themed", "style": "battle", "key": "A", "bars": 2, "seed": 3,
                "structure": "verse_chorus", "drums": "march", "swing": 0.3,
                "lead_instrument": "marimba", "parts": ["lead", "drums"],
            }
        ],
    }
    assert manifest.summarise(manifest.build(manifest.parse(data), str(tmp_path))) == {"written": 1}
    assert (tmp_path / "themed.wav").exists()


# --- 差分ビルド ---------------------------------------------------------------


def test_a_second_build_skips_unchanged_assets(tmp_path):
    parsed = manifest.parse(_manifest_data())
    manifest.build(parsed, str(tmp_path))
    assert manifest.summarise(manifest.build(parsed, str(tmp_path))) == {"skipped": 3}


def test_changing_a_setting_rebuilds_only_that_asset(tmp_path):
    manifest.build(manifest.parse(_manifest_data()), str(tmp_path))

    changed = _manifest_data()
    changed["sfx"][0]["seed"] = 99
    results = manifest.build(manifest.parse(changed), str(tmp_path))
    assert manifest.summarise(results) == {"written": 1, "skipped": 2}
    assert next(r for r in results if r.status == "written").asset.path == "se/coin"


def test_force_rebuilds_everything(tmp_path):
    parsed = manifest.parse(_manifest_data())
    manifest.build(parsed, str(tmp_path))
    assert manifest.summarise(manifest.build(parsed, str(tmp_path), force=True)) == {"written": 3}


def test_a_deleted_file_is_regenerated(tmp_path):
    parsed = manifest.parse(_manifest_data())
    manifest.build(parsed, str(tmp_path))
    (tmp_path / "se/coin.wav").unlink()
    assert manifest.summarise(manifest.build(parsed, str(tmp_path))) == {"written": 1, "skipped": 2}


def test_dry_run_writes_nothing(tmp_path):
    parsed = manifest.parse(_manifest_data())
    results = manifest.build(parsed, str(tmp_path), dry_run=True)
    assert manifest.summarise(results) == {"planned": 3}
    assert not list(tmp_path.iterdir())


def test_a_damaged_index_falls_back_to_a_full_build(tmp_path):
    parsed = manifest.parse(_manifest_data())
    manifest.build(parsed, str(tmp_path))
    (tmp_path / manifest.INDEX_NAME).write_text("not json", encoding="utf-8")
    assert manifest.summarise(manifest.build(parsed, str(tmp_path))) == {"written": 3}


def test_the_index_records_one_entry_per_asset(tmp_path):
    manifest.build(manifest.parse(_manifest_data()), str(tmp_path))
    index = json.loads((tmp_path / manifest.INDEX_NAME).read_text(encoding="utf-8"))
    assert index["version"] == manifest.FORMAT_VERSION
    assert set(index["entries"]) == {"se/coin", "se/step", "bgm/title"}


def test_fingerprints_track_the_settings():
    a, b = manifest.parse(_manifest_data()).assets[0], manifest.parse(_manifest_data()).assets[0]
    assert a.fingerprint() == b.fingerprint()

    changed = _manifest_data()
    changed["sfx"][0]["pitch"] = 1.5
    assert manifest.parse(changed).assets[0].fingerprint() != a.fingerprint()


def test_the_sample_rate_is_part_of_the_fingerprint():
    low = manifest.parse(_manifest_data(sample_rate=8000)).assets[0]
    high = manifest.parse(_manifest_data(sample_rate=22050)).assets[0]
    assert low.fingerprint() != high.fingerprint()
