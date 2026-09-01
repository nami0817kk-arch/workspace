"""サイト生成まわりのテスト。

過去データの読み込み（旧形式の変換を含む）が壊れると、
アーカイブから古い日付が音もなく消える。そこを固定しておく。
"""

import json

import pytest

import render


@pytest.fixture
def site(tmp_path, monkeypatch):
    """data/ と output/ を一時ディレクトリに差し替える。"""
    data_dir = tmp_path / "data"
    out_dir = tmp_path / "output"
    data_dir.mkdir()
    monkeypatch.setattr(render, "_DATA_DIR", data_dir)
    monkeypatch.setattr(render, "_OUTPUT_DIR", out_dir)
    monkeypatch.setattr(render, "_ROOT", tmp_path)
    return data_dir, out_dir


def _row(rank=1, code="7203", name="トヨタ自動車"):
    return {"rank": rank, "code": code, "name": name,
            "close": 2500.0, "change_pct": 12.5, "metric_value": 1000}


def _write_day(data_dir, rec_date, payload=None):
    payload = payload or {"rec_date": rec_date, "gainers": [_row()], "losers": [], "active": []}
    (data_dir / f"{rec_date}.json").write_text(
        json.dumps(payload, ensure_ascii=False), encoding="utf-8"
    )


# --- 旧形式の取り込み -----------------------------------------------------

def test_legacy_payload_is_converted_to_the_current_shape():
    legacy = {
        "rec_date": "2026-01-05",
        "rows": [{"rank": 1, "code": "7203", "name": "トヨタ自動車",
                  "close": 2500.0, "gain_pct": 12.5, "volume": 1000}],
    }
    out = render._normalize_day(legacy)

    assert out["rec_date"] == "2026-01-05"
    assert out["gainers"][0]["change_pct"] == 12.5   # gain_pct -> change_pct
    assert out["gainers"][0]["metric_value"] == 1000  # volume -> metric_value
    assert out["losers"] == [] and out["active"] == []


def test_current_payload_passes_through_untouched():
    current = {"rec_date": "2026-01-05", "gainers": [_row()], "losers": [], "active": []}
    assert render._normalize_day(current) is current


def test_legacy_payload_without_rows_does_not_raise():
    assert render._normalize_day({"rec_date": "2026-01-05"})["gainers"] == []


# --- 読み込み -------------------------------------------------------------

def test_days_are_returned_newest_first(site):
    data_dir, _ = site
    for d in ("2026-01-05", "2026-01-07", "2026-01-06"):
        _write_day(data_dir, d)
    assert [d["rec_date"] for d in render._load_all_days()] == \
        ["2026-01-07", "2026-01-06", "2026-01-05"]


def test_latest_json_is_not_mistaken_for_a_daily_file(site):
    data_dir, _ = site
    _write_day(data_dir, "2026-01-05")
    (data_dir / "latest.json").write_text("{}", encoding="utf-8")
    assert len(render._load_all_days()) == 1


# --- ビルド ---------------------------------------------------------------

def test_build_refuses_to_run_with_no_data(site):
    with pytest.raises(RuntimeError):
        render.build_all()


def test_build_generates_every_expected_page(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-01-05", {
        "rec_date": "2026-01-05",
        "gainers": [_row()],
        "losers": [_row(code="9984", name="ソフトバンクG")],
        "active": [_row(code="3990", name="UUUM")],
    })
    render.build_all()

    for name in ("index.html", "losers.html", "active.html",
                 "about.html", "privacy.html", "robots.txt", "ads.txt", "sitemap.xml"):
        assert (out_dir / name).exists(), name
    for kind in ("gainers", "losers", "active"):
        assert (out_dir / "archive" / kind / "2026-01-05.html").exists()
        assert (out_dir / "archive" / kind / "index.html").exists()

    assert "トヨタ自動車" in (out_dir / "index.html").read_text(encoding="utf-8")
    assert "2026-01-05" in (out_dir / "sitemap.xml").read_text(encoding="utf-8")


def test_build_starts_from_a_clean_output_dir(site):
    """前回のビルドで消えたページが残り続けないこと。"""
    data_dir, out_dir = site
    _write_day(data_dir, "2026-01-05")
    render.build_all()
    stale = out_dir / "stale.html"
    stale.write_text("古い", encoding="utf-8")

    render.build_all()
    assert not stale.exists()


def test_days_without_rows_are_skipped_in_the_archive(site):
    data_dir, out_dir = site
    _write_day(data_dir, "2026-01-05")
    _write_day(data_dir, "2026-01-06",
               {"rec_date": "2026-01-06", "gainers": [_row()], "losers": [], "active": []})
    render.build_all()

    # losers が空の日は losers アーカイブに出さない
    assert not (out_dir / "archive" / "losers" / "2026-01-06.html").exists()
    assert (out_dir / "archive" / "gainers" / "2026-01-06.html").exists()
