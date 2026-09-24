"""v2 で足した章（ストップ高・月まとめ・同日の顔ぶれ・ハイライト）のテスト。

いずれも「毎日ためているから出せる」情報で、当日のランキングだけを見ている
サイトには作れない。数え方を間違えるとそこが崩れるので固定する。
"""
import json

import pytest

import aggregate
import render


def _row(code, name, close=163.0, pct=44.25, rank=1):
    """既定は 113円 → 163円（値幅50円）＝ストップ高。"""
    return {"rank": rank, "code": code, "name": name, "close": close,
            "change_pct": pct, "metric_value": 100}


def _day(rec_date, rows):
    return {"rec_date": rec_date, "gainers": rows, "losers": [], "active": []}


# --- ストップ高 -------------------------------------------------------------

def test_ストップ高だけを日ごとに数える():
    days = [
        _day("2026-09-18", [_row("5131", "リンカーズ"),
                            _row("7203", "トヨタ", close=2500.0, pct=1.5, rank=2)]),
        _day("2026-09-17", [_row("5131", "リンカーズ")]),
    ]
    h = aggregate.stop_high_history(days)
    assert h["total"] == 2                       # トヨタは上限に届いていない
    assert h["per_day"][0]["rec_date"] == "2026-09-18"
    assert h["per_day"][0]["count"] == 1
    assert [s["code"] for s in h["stocks"]] == ["5131"]
    assert h["stocks"][0]["streak"] == 2          # 掲載日の並びで連続


def test_1回だけの銘柄は一覧に出さない():
    days = [_day("2026-09-18", [_row("5131", "リンカーズ")])]
    assert aggregate.stop_high_history(days)["stocks"] == []


def test_ストップ高が無い日も記録に残す():
    days = [_day("2026-09-18", [_row("7203", "トヨタ", close=2500.0, pct=1.5)])]
    h = aggregate.stop_high_history(days)
    assert h["total"] == 0
    assert h["per_day"][0]["count"] == 0          # 「無かった」ことも記録


# --- 月まとめ ---------------------------------------------------------------

def test_月ごとに区切る():
    days = [
        _day("2026-09-01", [_row("1001", "アルファ")]),
        _day("2026-08-31", [_row("1002", "ベータ")]),
        _day("2026-08-28", [_row("1003", "ガンマ")]),
    ]
    months = aggregate.monthly_summaries(days)
    assert [m["slug"] for m in months] == ["2026-09", "2026-08"]
    assert months[1]["day_count"] == 2
    assert months[1]["from"] == "2026-08-28" and months[1]["to"] == "2026-08-31"


def test_月まとめはストップ高の件数を持つ():
    days = [_day("2026-09-01", [_row("1001", "アルファ"),
                                _row("1002", "ベータ", close=2500.0, pct=1.5, rank=2)])]
    assert aggregate.monthly_summaries(days)[0]["stop_highs"] == 1


# --- 同じ日に一緒にランクインした銘柄 ---------------------------------------

def test_同じ日の顔ぶれを数える():
    days = [
        _day("2026-09-18", [_row("1001", "アルファ"), _row("1002", "ベータ", rank=2),
                            _row("1003", "ガンマ", rank=3)]),
        _day("2026-09-17", [_row("1001", "アルファ"), _row("1002", "ベータ", rank=2)]),
    ]
    out = aggregate.co_occurring(days, "1001")
    # ベータは2回一緒、ガンマは1回だけなので出さない
    assert [(e["code"], e["count"]) for e in out] == [("1002", 2)]


def test_自分自身は数えない():
    days = [_day("2026-09-18", [_row("1001", "アルファ")]),
            _day("2026-09-17", [_row("1001", "アルファ")])]
    assert aggregate.co_occurring(days, "1001") == []


# --- 生成物 -----------------------------------------------------------------

@pytest.fixture
def site(tmp_path, monkeypatch):
    data_dir = tmp_path / "data"
    out_dir = tmp_path / "output"
    data_dir.mkdir()
    monkeypatch.setattr(render, "_DATA_DIR", data_dir)
    monkeypatch.setattr(render, "_OUTPUT_DIR", out_dir)
    monkeypatch.setattr(render, "_ROOT", tmp_path)
    for d in ("2026-09-16", "2026-09-17", "2026-09-18"):
        (data_dir / f"{d}.json").write_text(json.dumps({
            "rec_date": d,
            "gainers": [_row("5131", "リンカーズ"), _row("7203", "トヨタ", 2500.0, 1.5, 2)],
            "losers": [], "active": [],
        }, ensure_ascii=False), encoding="utf-8")
    render.build_all()
    return out_dir


def test_ストップ高の章が作られる(site):
    html = (site / "stop-high" / "index.html").read_text(encoding="utf-8")
    assert "ストップ高の記録" in html
    # 上位30銘柄に限られることを必ず断る（全ストップ高だと誤解させない）
    assert "上位30銘柄です" in html
    assert "リンカーズ" in html


def test_月まとめが作られる(site):
    assert (site / "monthly" / "2026-09.html").exists()
    assert (site / "monthly" / "index.html").exists()


def test_トップにハイライトが出る(site):
    html = (site / "index.html").read_text(encoding="utf-8")
    assert 'class="highlights"' in html
    assert "ストップ高" in html and "連続ランクイン" in html


def test_新しい章がsitemapに載る(site):
    sitemap = (site / "sitemap.xml").read_text(encoding="utf-8")
    assert "/stop-high/" in sitemap
    assert "/monthly/" in sitemap and "/monthly/2026-09" in sitemap
