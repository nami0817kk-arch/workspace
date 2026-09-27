"""上限側（ストップ高）と下限側（ストップ安）を、片側だけ直さないための検査。

2026-09-28 のレビューで、**ストップ安を対にしたときに片側しか見ていない箇所**が
4つ見つかった（属性の取得・出どころの判定・相場の振り返りの札・語彙の対応表）。
向きの対応表を `aggregate.LIMIT_SIDES` と `render.LIMIT_PAGES` の2つに絞り、
どちらも両側を持つことをここで固定する。
"""
import re
from pathlib import Path

import aggregate
import render
import stock_profile


def _day(rec_date="2026-09-28", *, high=None, low=None):
    day = {
        "rec_date": rec_date,
        "gainers": [{"rank": 1, "code": "5131", "name": "リンカーズ", "close": 163.0,
                     "change_pct": 44.25, "metric_value": 1}],
        "losers": [{"rank": 1, "code": "4599", "name": "ステムリム", "close": 239.0,
                    "change_pct": -25.08, "metric_value": 1}],
        "active": [],
    }
    if high is not None:
        day["stop_high"] = high
    if low is not None:
        day["stop_low"] = low
    return day


def _rec(code, pct, *, at_limit=True):
    return {"rank": 1, "code": code, "name": f"銘柄{code}", "close": 163.0,
            "change_pct": pct, "at_limit": at_limit}


# --- 対応表そのもの -----------------------------------------------------------

def test_向きの対応表は2つだけで中身が揃っている():
    """データ側（aggregate）と表示側（render）で、扱う向きが同じであること。
    別々に増やすと、片方にしか無い向きが黙って落ちる。"""
    assert set(aggregate.LIMIT_SIDES) == set(render.LIMIT_PAGES)
    for kind, side in aggregate.LIMIT_SIDES.items():
        assert render.LIMIT_PAGES[kind]["kind"] == kind
        assert side["kind"] == kind


def test_記録のキーの一覧は対応表から作る():
    """保存・欠落の監視・属性の取得が、それぞれ別の一覧を持たないようにする。"""
    assert aggregate.LIMIT_KEYS == ("stop_high", "stop_low")
    assert set(aggregate.LIMIT_KEYS) == {s["key"] for s in aggregate.LIMIT_SIDES.values()}


def test_記録のキーを並べて書く場所を増やさない():
    """`("stop_high", "stop_low")` と並べる箇所が増えるほど、片方を足し忘れる。
    並べたい場所は `aggregate.LIMIT_KEYS` を使う（2026-09-28 に1本化）。"""
    src = Path(__file__).resolve().parents[1] / "src"
    pair = re.compile(r"""["']stop_high["']\s*,\s*["']stop_low["']""")
    offenders = []
    for path in sorted(src.glob("*.py")):
        if path.name == "aggregate.py":      # 対応表そのものを持つファイル
            continue
        for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if pair.search(line):
                offenders.append(f"{path.name}:{i} {line.strip()[:70]}")
    assert not offenders, "記録のキーを並べて書いている:\n" + "\n".join(offenders)


# --- 属性の取得 ---------------------------------------------------------------

def test_属性はストップ安の銘柄も取りに行く():
    """取りに行かないと /stop-low/ の市場別・業種別の内訳が丸ごと出ない。"""
    day = _day(high=[_rec("5131", 44.25)], low=[_rec("4599", -25.08)])
    codes = stock_profile.needed_codes([day], [])
    assert codes == ["4599", "5131"]


def test_引けまで保たなかった銘柄は属性を取りに行かない():
    """数えない銘柄の属性を取っても、取得元への回数が増えるだけ。"""
    day = _day(high=[_rec("5131", 44.25, at_limit=False)])
    assert stock_profile.needed_codes([day], []) == []


# --- 出どころの判定 -----------------------------------------------------------

def test_片側だけ推定でもそう断る():
    """ストップ高は記録できたが、ストップ安のページが1枚も取れなかった日。
    上限側だけを見ていたため「推定が混じる」と断らなかった。"""
    counts = aggregate.stop_counts([_day(high=[_rec("5131", 44.25)])])
    assert counts["has_estimated"] is True
    assert counts["stop_highs"] == 1
    assert counts["stop_lows"] == 1      # 値下がり上位30からの推定


def test_両側とも記録があれば推定は混じらない():
    counts = aggregate.stop_counts([
        _day(high=[_rec("5131", 44.25)], low=[_rec("4599", -25.08)])])
    assert counts["has_estimated"] is False


def test_相場の振り返りは上下それぞれの札を出せる():
    row = render.market_rows([_day(high=[_rec("5131", 44.25)])])[0]
    assert row["stop_high_source"] == "recorded"
    assert row["stop_low_source"] == "estimated"


# --- 0件の言い方 ---------------------------------------------------------------

def test_記録が無い期間の0件は範囲を断る():
    """上位30銘柄の中しか見ていないのに「ありませんでした」と言い切ると、
    同じページの注意書きと矛盾する。"""
    history = {"total": 0, "per_day": [], "stocks": [],
               "has_estimated": True, "has_recorded": False}
    text = render.limit_summary(history, 20, render.LIMIT_PAGES["gainers"])
    assert "上位30銘柄の中に" in text


def test_記録がある期間の0件は言い切ってよい():
    history = {"total": 0, "per_day": [], "stocks": [],
               "has_estimated": False, "has_recorded": True}
    text = render.limit_summary(history, 20, render.LIMIT_PAGES["losers"])
    assert "上位30銘柄" not in text
    assert "ストップ安になった銘柄はありませんでした" in text


# --- 壊れたデータの扱い -------------------------------------------------------

def test_latest_jsonが壊れていても何をすればよいか分かる(tmp_path, monkeypatch, capsys):
    """「無い」は丁寧に扱うのに「壊れている」は素の traceback、では
    ログを見た人が動けない。"""
    import check_freshness
    monkeypatch.setattr(check_freshness, "_DATA_DIR", tmp_path)
    (tmp_path / "latest.json").write_text("{壊れている", encoding="utf-8")
    monkeypatch.setattr("sys.argv", ["check_freshness.py"])
    assert check_freshness.main() == 1
    out = capsys.readouterr().out
    assert "読めません" in out
    assert "作り直して" in out
