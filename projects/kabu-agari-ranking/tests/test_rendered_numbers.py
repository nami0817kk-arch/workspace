"""**画面に出ている数**と、データから数え直した数が合っているか。

集計と表示のあいだに手が入る場所（要約の文・一覧の1行・日別の案内）は、
計算が正しくても書き方でずれる。ここは出来上がった HTML を読んで突き合わせる。
"""
import json
import re

import pytest

import aggregate
import render


@pytest.fixture(scope="module")
def built(tmp_path_factory):
    tmp_path = tmp_path_factory.mktemp("numbers")
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    # 記録がある日と無い日、上位30銘柄の外のストップ高、ストップ安を混ぜる
    payloads = {
        "2026-09-25": {          # 推定しか無い日
            "gainers": [_row(i, 44.25) for i in range(1, 31)],
            "losers": [_low(1)], "active": [],
        },
        "2026-09-28": {          # 記録がある日。31件目は上位30の外
            "gainers": [_row(i, 44.25) for i in range(1, 31)],
            "losers": [_low(1)], "active": [],
            "stop_high": [_rec(i) for i in range(1, 32)],
            "stop_low": [_rec_low(1)],
        },
    }
    orig = (render._DATA_DIR, render._OUTPUT_DIR, render._ROOT)
    render._DATA_DIR, render._OUTPUT_DIR, render._ROOT = data_dir, tmp_path / "output", tmp_path
    try:
        for rec_date, body in payloads.items():
            (data_dir / f"{rec_date}.json").write_text(
                json.dumps({"rec_date": rec_date, **body}, ensure_ascii=False), encoding="utf-8")
        render.build_all()
        yield render._OUTPUT_DIR, render.load_days()
    finally:
        render._DATA_DIR, render._OUTPUT_DIR, render._ROOT = orig


def _row(i, pct):
    return {"rank": i, "code": f"{1000 + i}", "name": f"銘柄{i}", "close": 163.0,
            "change_pct": pct, "metric_value": 100}


def _low(i):
    return {"rank": i, "code": f"{4000 + i}", "name": f"下落{i}", "close": 239.0,
            "change_pct": -25.08, "metric_value": 100}


def _rec(i):
    return {"rank": i, "code": f"{1000 + i}", "name": f"銘柄{i}", "close": 163.0,
            "change_pct": 44.25, "at_limit": True}


def _rec_low(i):
    return {"rank": i, "code": f"{4000 + i}", "name": f"下落{i}", "close": 239.0,
            "change_pct": -25.08, "at_limit": True}


def test_章の要約の件数がデータと合う(built):
    out, days = built
    for kind, spec in render.LIMIT_PAGES.items():
        history = aggregate.limit_history(days, kind)
        html = (out / spec["dir"] / "index.html").read_text(encoding="utf-8")
        m = re.search(rf"のべ(\d+)銘柄が{spec['term']}になりました", html)
        assert m, f"{spec['dir']} に件数の一文が無い"
        assert int(m.group(1)) == history["total"]


def test_月まとめの一覧の件数がデータと合う(built):
    out, days = built
    html = (out / "monthly" / "index.html").read_text(encoding="utf-8")
    for month in aggregate.monthly_summaries(days):
        m = re.search(
            rf"{month['year']}年{month['month']}月</span>\s*<span[^>]*>\s*"
            rf"(\d+)営業日 ／ ストップ高 のべ(\d+)銘柄 ／ ストップ安 のべ(\d+)銘柄", html)
        assert m, f"{month['slug']} の行が見つからない"
        assert (int(m.group(1)), int(m.group(2)), int(m.group(3))) == (
            month["day_count"], month["stop_highs"], month["stop_lows"])


def test_日別ページの案内が記録と合う(built):
    out, days = built
    for day in days:
        note = render.day_stop_note(day, "gainers")
        html = (out / "archive" / "gainers" / f"{day['rec_date']}.html").read_text(encoding="utf-8")
        m = re.search(r"この日ストップ高になったのは<strong>(\d+)銘柄", html)
        if note is None:
            assert m is None, f"{day['rec_date']}: 推定しか無い日に件数を書いている"
        else:
            assert m and int(m.group(1)) == note["count"]


def test_上位30銘柄の外にいた数も合う(built):
    """31件目は値上がりランキングに載らない。「この表の外」と書けているか。"""
    out, _ = built
    html = (out / "archive" / "gainers" / "2026-09-28.html").read_text(encoding="utf-8")
    assert "この日ストップ高になったのは<strong>31銘柄" in html
    assert "（うち1銘柄はこの表の外）" in html


def test_相場の振り返りの表がデータと合う(built):
    out, days = built
    html = (out / "market.html").read_text(encoding="utf-8")
    for row in render.market_rows(days):
        m = re.search(
            rf'{row["rec_date"]}\.html">{row["rec_date"]}</a></th>\s*'
            rf"<td>(\d+)銘柄</td>\s*<td>(\d+)銘柄", html)
        assert m, f"{row['rec_date']} の行が見つからない"
        assert (int(m.group(1)), int(m.group(2))) == (row["big"], row["stop_high"])


def test_推定の日には札が出て記録の日には出ない(built):
    out, _ = built
    html = (out / "market.html").read_text(encoding="utf-8")
    estimated = re.search(r'2026-09-25\.html">2026-09-25</a></th>.*?</tr>', html, re.S).group(0)
    recorded = re.search(r'2026-09-28\.html">2026-09-28</a></th>.*?</tr>', html, re.S).group(0)
    assert estimated.count("推定") == 2, "上下どちらの列にも札が要る"
    assert "推定" not in recorded
