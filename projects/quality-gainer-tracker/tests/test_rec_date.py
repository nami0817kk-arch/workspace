"""記録日の決め方のテスト。

記録日は d01〜d14（記録日から n 営業日後の終値）の起点で、1日ずれると
追跡の検証が丸ごと狂う。実行日ではなく**ページ上の終値日**を使う。
kabu-agari-ranking では、ここを取り違えて1営業日ぶんのデータを
上書きしたことがある（2026-09-07）。
"""
from datetime import date

import pytest

from src.data import ranking_fetcher


def _row(cells):
    return "<tr>" + "".join(f"<td>{c}</td>" for c in cells) + "</tr>"


# プライム市場の並び（13列）。共有パッケージ側のテストと同じ形。
_ROW = _row(["7203", "テスト銘柄", "プライム", "-", "-", "1,591",
             "-", "+300", "+23.24%", "1,000,000", "-", "-", "-"])

# ランキング表自身が持つ日付（meigara_count の近く）。
_PAGE = (
    '<html><div>meigara_count 2026年9月18日 16:00現在</div>'
    f'<table class="stock_table">{_ROW}</table></html>'
)


@pytest.fixture
def offline(monkeypatch):
    monkeypatch.setattr(ranking_fetcher.time, "sleep", lambda *_: None)
    monkeypatch.setattr(ranking_fetcher, "_fill_names_kabutan", lambda df: df)

    def _serve(html):
        monkeypatch.setattr(
            ranking_fetcher, "_kabutan_fetch_market", lambda market, retries=3: html
        )
    return _serve


def test_記録日はページ上の終値日を使う(offline):
    offline(_PAGE)
    df = ranking_fetcher._fetch_kabutan(top_n=10)
    assert not df.empty
    # 実行日ではなくページの日付
    assert df["記録日"].iloc[0] == "2026-09-18"
    assert df["記録日"].iloc[0] != str(date.today())


def test_日付が読めないときだけ実行日に落とす(offline, capsys):
    offline(_PAGE.replace("meigara_count 2026年9月18日 16:00現在", ""))
    df = ranking_fetcher._fetch_kabutan(top_n=10)
    if not df.empty:
        assert df["記録日"].iloc[0] == str(date.today())
        assert "[WARN]" in capsys.readouterr().out
