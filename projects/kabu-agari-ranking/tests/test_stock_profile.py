"""銘柄の基本属性（市場区分・業種・売買単位）の扱い。"""
import json

import pytest

import aggregate
import stock_profile


@pytest.fixture
def cache(tmp_path, monkeypatch):
    path = tmp_path / "stocks.json"
    monkeypatch.setattr(stock_profile, "CACHE_PATH", path)
    monkeypatch.setattr(stock_profile, "_DATA_DIR", tmp_path)
    return path


def test_無ければ空で返る(cache):
    assert stock_profile.load() == {}


def test_壊れたファイルは無視して空で返る(cache):
    cache.write_text("{壊れている", encoding="utf-8")
    assert stock_profile.load() == {}


def test_保存して読み直せる(cache):
    stock_profile.save({"4075": {"market": "東証グロース"}})
    assert stock_profile.load() == {"4075": {"market": "東証グロース"}}
    assert "stocks" in json.loads(cache.read_text(encoding="utf-8"))


def test_既に貯めてあるコードは取りに行かない(cache, monkeypatch):
    called = []
    monkeypatch.setattr(stock_profile, "fetch_stock_page", lambda c: called.append(c) or "")
    stock_profile.sync(["4075"], {"4075": {"market": "東証グロース"}})
    assert called == []


def test_未知のコードだけ取りに行く(cache, monkeypatch):
    called = []

    def fake_fetch(code):
        called.append(code)
        return f"<html>{code}</html>"

    monkeypatch.setattr(stock_profile, "fetch_stock_page", fake_fetch)
    monkeypatch.setattr(stock_profile, "parse_stock_profile", lambda h: {"market": "東証グロース"})
    out = stock_profile.sync(["4075", "7203"], {"4075": {}}, interval=0)
    assert called == ["7203"]
    assert out["7203"] == {"market": "東証グロース"}
    # 貯めた分はそのまま残る
    assert out["4075"] == {}


def test_1回の上限を超えた分は次回に回す(cache, monkeypatch):
    monkeypatch.setattr(stock_profile, "fetch_stock_page", lambda c: "<html></html>")
    monkeypatch.setattr(stock_profile, "parse_stock_profile", lambda h: {"unit": "100株"})
    out = stock_profile.sync(["1000", "2000", "3000"], {}, limit=2, interval=0)
    assert len(out) == 2


def test_取得に失敗したコードは記録しない(cache, monkeypatch):
    """記録すると、次の実行で永久に取り直さなくなる。"""
    monkeypatch.setattr(stock_profile, "fetch_stock_page", lambda c: None)
    out = stock_profile.sync(["4075"], {}, interval=0)
    assert out == {}


def test_読めなかったコードは空で記録する(cache, monkeypatch):
    """上場廃止などで永遠に読み取れないものを毎日叩かないため。"""
    monkeypatch.setattr(stock_profile, "fetch_stock_page", lambda c: "<html></html>")
    monkeypatch.setattr(stock_profile, "parse_stock_profile", lambda h: {})
    out = stock_profile.sync(["4075"], {}, interval=0)
    assert out == {"4075": {}}


def test_1行の表記(cache):
    assert stock_profile.label(
        {"market": "東証グロース", "industry": "情報・通信業", "unit": "100株"}
    ) == "東証グロース／情報・通信業／売買単位100株"
    assert stock_profile.label(
        {"market": "東証グロース", "industry": "情報・通信業", "unit": "100株"}, unit=False
    ) == "東証グロース／情報・通信業"
    assert stock_profile.label({"industry": "建設業"}) == "建設業"
    assert stock_profile.label({}) == ""
    assert stock_profile.label(None) == ""


def test_属性を出す対象は銘柄ページとストップ高だけ(cache):
    days = [{
        "rec_date": "2026-09-28",
        "gainers": [{"code": "9999", "name": "出さない", "change_pct": 5.0}],
        "stop_high": [
            {"code": "1111", "name": "引けまで上限", "at_limit": True},
            {"code": "2222", "name": "場中だけ", "at_limit": False},
        ],
    }]
    # ランキングの表には出さないので 9999 は入らない。
    # 場中につけて下げた 2222 も数えないので入らない。
    assert stock_profile.needed_codes(days, ["4075"]) == ["1111", "4075"]


def test_内訳は多い順(cache):
    profiles = {
        "1": {"market": "東証グロース"},
        "2": {"market": "東証グロース"},
        "3": {"market": "東証スタンダード"},
    }
    rows = aggregate.profile_breakdown(["1", "2", "3"], profiles, "market")
    assert [r["label"] for r in rows] == ["東証グロース", "東証スタンダード"]
    assert rows[0]["count"] == 2
    assert rows[0]["share"] == 66.7


def test_内訳は属性が取れていない銘柄を数えない(cache):
    """「不明」を1項目にすると、取得の進み具合が相場の話のように見える。"""
    rows = aggregate.profile_breakdown(
        ["1", "2"], {"1": {"market": "東証プライム"}}, "market"
    )
    assert rows == [{"label": "東証プライム", "count": 1, "share": 100.0}]


def test_内訳は1件も取れていなければ空(cache):
    assert aggregate.profile_breakdown(["1"], {}, "market") == []
