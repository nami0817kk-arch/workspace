"""取得の失敗を、止めるべきところで止め、止めてはいけないところで止めないか。

**黙って止まるのが最悪の壊れ方**なので、どの失敗で exit 1 にするかは
運用の要になる。ここは `main()` の分岐そのものを見る（取得はしない）。
"""
import json

import pandas as pd
import pytest

import build_site
import fetcher
import validate


def _rec_date() -> str:
    """`validate` が「この時点で出るはずの相場日」と認める日付。

    見本を "2026-09-28" と固定で書いていたため、**書いた翌日から必ず落ちた**
    （2026-09-29 に master が赤くなり、サイトの公開が1日止まった。
    データの取得自体は成功していたのに、テストが落ちて公開まで進まなかった）。
    日付を跨いで走るテストに、その日にしか通らない値を埋め込まない。
    """
    from datetime import datetime
    expected = validate.expected_rec_dates(datetime.now(validate.JST))
    if expected:
        # 古いほうを採る。場中は {今日, 前営業日} が返るが、その時刻に
        # 実際に出ているのは前営業日の終値。大引け後は {今日} だけなので
        # どちらを採っても同じになる。
        return sorted(expected)[0]
    # 祝日表の範囲外では validate が日付を見ない（何を入れても通る）
    return datetime.now(validate.JST).date().isoformat()


REC_DATE = _rec_date()


@pytest.fixture(autouse=True)
def clean(monkeypatch, tmp_path):
    monkeypatch.setattr(build_site, "_DATA_DIR", tmp_path)
    monkeypatch.setattr(build_site.render, "build_all", lambda: None)
    monkeypatch.setattr(build_site.stock_profile, "sync", lambda *a, **k: {})
    monkeypatch.setattr(build_site.render, "load_days", lambda: [])
    monkeypatch.setattr(build_site.aggregate, "stock_histories", lambda days: [])
    monkeypatch.setattr("sys.argv", ["build_site.py"])
    fetcher.fetch_errors.clear()
    fetcher.parse_failures.clear()
    fetcher.pages_fetched.clear()
    yield tmp_path
    fetcher.fetch_errors.clear()
    fetcher.parse_failures.clear()
    fetcher.pages_fetched.clear()


def _rows(n=30, rec_date=None):
    return pd.DataFrame([
        {"rank": i, "code": f"{1000 + i}", "name": f"銘柄{i}", "close": 100.0,
         "change_pct": 5.0, "metric_value": 1,
         "rec_date": rec_date or REC_DATE}
        for i in range(1, n + 1)
    ])


def _patch_fetch(monkeypatch, *, gainers=None, stop_high=None, stop_low=None):
    empty = pd.DataFrame()
    monkeypatch.setattr(build_site, "fetch_gainers",
                        lambda **k: _rows() if gainers is None else gainers)
    monkeypatch.setattr(build_site, "fetch_losers", lambda **k: empty)
    monkeypatch.setattr(build_site, "fetch_active", lambda **k: empty)
    monkeypatch.setattr(build_site, "fetch_stop_high",
                        lambda: empty if stop_high is None else stop_high)
    monkeypatch.setattr(build_site, "fetch_stop_low",
                        lambda: empty if stop_low is None else stop_low)


def test_取得に失敗して当日分が無ければ落とす(monkeypatch, clean):
    """黙って通すと、CI は緑のままサイトの更新だけが止まる。"""
    _patch_fetch(monkeypatch, gainers=pd.DataFrame())
    fetcher.fetch_errors.append("通信に失敗")
    with pytest.raises(SystemExit) as e:
        build_site.main()
    assert e.value.code == 1


def test_解析が壊れていても当日分が保存できていれば止めない(monkeypatch, clean, capsys):
    """止めると run-daily.ps1 が commit の手前で終わり、取れている
    値上がり・値下がりまでその日公開されなくなる。"""
    _patch_fetch(monkeypatch)
    fetcher.parse_failures.append("活況銘柄ランキング: 1行も解析できませんでした")
    build_site.main()          # SystemExit にならない
    out = capsys.readouterr().out
    assert "[WARN]" in out
    assert "[ERROR]" not in out
    assert (clean / f"{REC_DATE}.json").exists()


def test_解析が壊れて当日分も無ければ落とす(monkeypatch, clean):
    _patch_fetch(monkeypatch, gainers=pd.DataFrame())
    fetcher.parse_failures.append("値上がりランキング: 1行も解析できませんでした")
    with pytest.raises(SystemExit) as e:
        build_site.main()
    assert e.value.code == 1


def test_妥当でないデータは保存せずに落とす(monkeypatch, clean):
    """data/ は取り直しがきかない。疑わしいものを弾いてその日を落とすほうがまし。"""
    _patch_fetch(monkeypatch, gainers=_rows(rec_date="2099-01-01"))
    with pytest.raises(SystemExit) as e:
        build_site.main()
    assert e.value.code == 1
    assert not list(clean.glob("*.json")), "弾いたのに書き込んでいる"


def test_属性の取得が失敗してもサイトは作る(monkeypatch, clean, capsys):
    """属性は飾りで、無ければその行を出さないだけ。
    ランキングが出ないほうが損が大きい。"""
    _patch_fetch(monkeypatch)
    built = []
    monkeypatch.setattr(build_site.render, "build_all", lambda: built.append(True))

    def boom(*a, **k):
        raise RuntimeError("取得元が応答しない")

    monkeypatch.setattr(build_site.stock_profile, "sync", boom)
    build_site.main()
    assert built, "属性の失敗でサイトのビルドまで止まっている"
    assert "[WARN] 銘柄属性" in capsys.readouterr().out


def test_ストップ高が取れた日は記録が入る(monkeypatch, clean):
    _patch_fetch(monkeypatch, stop_high=pd.DataFrame([
        {"rank": 1, "code": "5131", "name": "リンカーズ", "close": 163.0,
         "change_pct": 44.25, "at_limit": True, "rec_date": REC_DATE}]))
    fetcher.pages_fetched[fetcher.STOP_HIGH_LABEL] = 3
    build_site.main()
    saved = json.loads((clean / f"{REC_DATE}.json").read_text(encoding="utf-8"))
    assert saved["stop_high"][0]["code"] == "5131"
    assert "stop_low" not in saved, "取れなかった側をキーごと残している"


def test_片方が取れなかった日でも保存の報告で落ちない(monkeypatch, clean, capsys):
    """取れなかったランキングはキーごと消してあるので、メッセージで
    直に読むと KeyError になる。保存は済んでいるのにサイトのビルドまで
    行かず、その日が公開されなくなる（2026-09-28 に気づいた）。"""
    _patch_fetch(monkeypatch)
    build_site.main()
    out = capsys.readouterr().out
    assert "に保存しました" in out
    assert "ストップ高取得なし" in out
    assert "ストップ安取得なし" in out
