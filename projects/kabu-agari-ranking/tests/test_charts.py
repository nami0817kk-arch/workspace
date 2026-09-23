"""グラフのテスト。

SVG は目で見ないと分からない部分が多いので、機械で見られるところ
（軸が値を覆っているか・文字がはみ出さないか・色の使い分け）は固定しておく。
実際に 2026-09-23 に、目盛りが最大値を覆えず棒が画の外にはみ出した。
"""
import xml.etree.ElementTree as ET

import charts


def _rows(values):
    return [{"label": f"銘柄{i}", "sub": f"{7200 + i}", "value": v} for i, v in enumerate(values)]


def _parse(svg: str) -> ET.Element:
    return ET.fromstring(svg)


# --- 軸 --------------------------------------------------------------------

def test_目盛りは最大値を覆う():
    # 27.94 で 0/10/20 までしか出さないと、棒が目盛りの外へ出る
    for peak in (27.94, 8.0, 65.63, 0.5, 120.0):
        assert charts._ticks(peak)[-1] >= peak, peak


def test_目盛りは切りのいい数で刻む():
    assert charts._ticks(27.94) == [0.0, 10.0, 20.0, 30.0]
    assert charts._ticks(15) == [0.0, 5.0, 10.0, 15.0]


def test_棒は描画領域の中に収まる():
    svg = charts.horizontal_bars(_rows([27.94, 20.0, 5.0]), aria_label="test")
    root = _parse(svg)
    width = float(root.get("viewBox").split()[2])
    for path in root.iter("{http://www.w3.org/2000/svg}path"):
        xs = [float(tok.split(",")[0].lstrip("MHVQZ")) for tok in path.get("d").split()
              if tok and tok[0] in "MH" and tok[1:]]
        assert max(xs) <= width + 0.5, path.get("d")


# --- 作らない場合 -----------------------------------------------------------

def test_棒1本ならグラフにしない():
    assert charts.horizontal_bars(_rows([12.0]), aria_label="test") == ""


def test_2点以下は推移にしない():
    pts = [{"label": "9/1", "value": 3}, {"label": "9/2", "value": 4}]
    assert charts.columns(pts, aria_label="test") == ""


def test_値が無い行は落とす():
    rows = _rows([10.0, 5.0]) + [{"label": "欠損", "sub": "9999", "value": None}]
    svg = charts.horizontal_bars(rows, aria_label="test")
    assert "欠損" not in svg


# --- 文字 ------------------------------------------------------------------

def test_長い銘柄名は切るが元の名前はツールチップに残る():
    long_name = "ミンカブ・ジ・インフォノイド"
    svg = charts.horizontal_bars(
        [{"label": long_name, "sub": "4436", "value": 20.0},
         {"label": "短い", "sub": "1234", "value": 10.0}],
        aria_label="test",
    )
    assert "…" in svg
    assert f"<title>{long_name}" in svg  # ホバーでは省略しない


def test_数値ラベルは最大の1本だけ():
    svg = charts.horizontal_bars(_rows([27.94, 20.0, 5.0]), aria_label="test")
    assert svg.count("+27.94%") == 2  # 直接ラベル1つ + ツールチップ1つ
    assert svg.count("+20.00%") == 1  # ツールチップだけ


def test_推移は直近と最大の2本に数値を書く():
    pts = [{"label": f"9/{i}", "value": v} for i, v in enumerate([3, 9, 4, 5], start=1)]
    root = _parse(charts.columns(pts, aria_label="test", unit="銘柄"))
    labels = [t.text for t in root.iter("{http://www.w3.org/2000/svg}text")]
    assert "9銘柄" in labels and "5銘柄" in labels
    assert "4銘柄" not in labels


def test_文字に系統の色を使わない():
    svg = charts.horizontal_bars(_rows([12.0, 3.0]), aria_label="test")
    for text in _parse(svg).iter("{http://www.w3.org/2000/svg}text"):
        assert text.get("fill") not in (charts.COLOR_GAIN, charts.COLOR_LOSS)


# --- 色と符号 ---------------------------------------------------------------

def test_下落は青で負号を付ける():
    svg = charts.horizontal_bars(_rows([-20.0, -5.0]), aria_label="test", negative=True)
    assert charts.COLOR_LOSS in svg and charts.COLOR_GAIN not in svg
    assert "-20.00%" in svg


def test_上昇は赤():
    svg = charts.horizontal_bars(_rows([20.0, 5.0]), aria_label="test")
    assert charts.COLOR_GAIN in svg and charts.COLOR_LOSS not in svg


# --- 読み上げ ---------------------------------------------------------------

def test_グラフに説明が付く():
    svg = charts.horizontal_bars(_rows([20.0, 5.0]), aria_label="上位の騰落率")
    root = _parse(svg)
    assert root.get("role") == "img"
    assert root.get("aria-label") == "上位の騰落率"


def test_特殊文字を含む銘柄名でも壊れない():
    svg = charts.horizontal_bars(
        [{"label": 'A&B<「">', "sub": "1234", "value": 10.0},
         {"label": "普通", "sub": "5678", "value": 5.0}],
        aria_label="test",
    )
    _parse(svg)  # XML として読めれば壊れていない
    assert "&amp;" in svg and "&lt;" in svg


# --- 明暗の切り替え ---------------------------------------------------------

def test_グラフの色は変数で渡す():
    # 生の色を焼き込むと、暗い地に切り替わったときだけ沈んで気づけない
    svg = charts.horizontal_bars(_rows([12.0, 3.0]), aria_label="test")
    assert "var(--chart-gain)" in svg
    assert "#" not in svg, "色を直接書かない（CSS変数で渡す）"
