"""検索結果に出る見出しと説明文。

ここが読まれるのは**1ページ目に出たとき**だけで、いまは平均13.9位なので
すぐにクリックが増えるものではない。それでも、

- 周りに並ぶのは「◯◯の株価・チャート」ばかりで、同じことを名乗っても勝てない
- 説明文は2行ぶんしか出ないので、冒頭に数字が無いと「何が分かるページか」が
  伝わらないまま切れる

ので、**このサイトが答えられる問いと、その場で分かる数字**を前に出す。
本文と違う数を書いてしまうと、押した先で食い違うので、ここで固定する。
"""
import json
import re

import pytest

import render


@pytest.fixture(scope="module")
def site(tmp_path_factory):
    tmp_path = tmp_path_factory.mktemp("snippet")
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    orig = (render._DATA_DIR, render._OUTPUT_DIR, render._ROOT)
    render._DATA_DIR, render._OUTPUT_DIR, render._ROOT = data_dir, tmp_path / "output", tmp_path
    try:
        for d in ("2026-09-28", "2026-09-29", "2026-09-30"):
            (data_dir / f"{d}.json").write_text(json.dumps({
                "rec_date": d,
                "gainers": [{"rank": 1, "code": "5131", "name": "リンカーズ", "close": 163.0,
                             "change_pct": 44.25, "metric_value": 100}],
                "losers": [{"rank": 1, "code": "4599", "name": "ステムリム", "close": 239.0,
                            "change_pct": -25.08, "metric_value": 100}],
                "active": [],
                "stop_high": [{"rank": 1, "code": "5131", "name": "リンカーズ", "close": 163.0,
                               "change_pct": 44.25, "at_limit": True}],
                "stop_low": [],
            }, ensure_ascii=False), encoding="utf-8")
        render.build_all()
        yield render._OUTPUT_DIR
    finally:
        render._DATA_DIR, render._OUTPUT_DIR, render._ROOT = orig


def _title(path):
    return re.search(r"<title>(.*?)</title>", path.read_text(encoding="utf-8"), re.S).group(1)


def _desc(path):
    return re.search(r'<meta name="description" content="(.*?)"',
                     path.read_text(encoding="utf-8"), re.S).group(1)


def test_銘柄ページは答えられる問いを名乗る(site):
    """「◯◯の株価」と同じことを名乗っても、Yahoo! や株探には勝てない。"""
    title = _title(site / "stock" / "5131" / "index.html")
    assert "はいつ動いたか" in title
    assert "リンカーズ（5131）" in title
    assert "回ランクイン" in title


def test_銘柄ページの説明は数字から始まる(site):
    """検索結果に出るのは2行ぶん。冒頭に数字が無いと切れて伝わらない。"""
    desc = _desc(site / "stock" / "5131" / "index.html")
    assert desc.startswith("直近3営業日のうち3回ランクイン")
    assert "ストップ高3回" in desc


def test_記録の章は中にある章を名乗る(site):
    """「一覧」だけだと、同じことを出している所と区別が付かない。
    連続・翌営業日・業種別は、毎日ためていないと出せない。"""
    title = _title(site / "stop-high" / "index.html")
    for word in ("ストップ高の記録", "連続", "翌営業日", "業種別"):
        assert word in title, title


def test_説明の件数が本文と食い違わない(site):
    """押した先で数が違うと、どちらが正しいか読み手には決められない。"""
    for rel, term in (("stop-high", "ストップ高"), ("stop-low", "ストップ安")):
        path = site / rel / "index.html"
        html = path.read_text(encoding="utf-8")
        body = re.search(r'<p class="summary">(.*?)</p>', html, re.S).group(1)
        m_body = re.search(rf"のべ(\d+)銘柄が{term}になりました（(\d+)銘柄）", body)
        if not m_body:          # 0件の日は別の文になる
            continue
        desc = _desc(path)
        assert f"のべ{m_body.group(1)}銘柄（{m_body.group(2)}銘柄）" in desc, desc


def test_見出しが長くなりすぎない(site):
    """検索結果で表示されるのは日本語でおよそ30文字前後。
    長いぶんは切れるので、**後ろに回したものは読まれない前提**で書く。"""
    too_long = []
    for path in sorted(site.rglob("*.html")):
        title = _title(path)
        if len(title) > 40:
            too_long.append(f"{path.relative_to(site).as_posix()}: {len(title)}字")
    assert not too_long, "\n".join(too_long)


def test_見出しの先頭に固有の言葉が来る(site):
    """「値上がり株ランキング｜◯◯」のようにサイト名から始めると、
    どのページも同じ出だしになって見分けが付かない。"""
    for rel in ("index.html", "stop-high/index.html", "stock/5131/index.html",
                "monthly/2026-09.html"):
        title = _title(site / rel)
        assert not title.startswith("値上がり株ランキング"), f"{rel}: {title}"
