"""制限値幅からの判定のテスト。

表は東証のもの（出典は price_limit.py の冒頭）。**取引所が変えうる数字**なので、
区分の境目をテストで固定しておき、書き換えたら気づけるようにする。
実データで確認した銘柄をそのまま入れてある。
"""
import price_limit as pl


# --- 表の読み方 -------------------------------------------------------------

def test_区分の境目():
    assert pl.limit_width(99) == 30
    assert pl.limit_width(100) == 50    # 100円は「200円未満」の側
    assert pl.limit_width(199) == 50
    assert pl.limit_width(200) == 80
    assert pl.limit_width(499) == 80
    assert pl.limit_width(500) == 100
    assert pl.limit_width(1_000) == 300
    assert pl.limit_width(1_499) == 300
    assert pl.limit_width(1_500) == 400


def test_表の外は最大の値幅():
    assert pl.limit_width(60_000_000) == 10_000_000


# --- 実データ ---------------------------------------------------------------

def test_ストップ高を当てる():
    # 2026-09-14 リンカーズ(5131): 113円 → 163円（値幅50円ちょうど）
    assert pl.classify(163.0, 44.25) == pl.STOP_HIGH
    # 2026-09-04 カイオム(4583): 82円 → 112円（値幅30円）
    assert pl.classify(112.0, 36.59) == pl.STOP_HIGH
    # 2026-09-07 北川鉄工所(6203): 1,512円 → 1,912円（値幅400円）
    assert pl.classify(1912.0, 26.46) == pl.STOP_HIGH


def test_ストップ安を当てる():
    # 2026-09-10 ステムリム(4599): 319円 → 239円（値幅80円）
    assert pl.classify(239.0, -25.08) == pl.STOP_LOW


def test_制限値幅を超える動きは言い切らない():
    # 2026-09-18 エスポア(3260): 311円 → 70円。1日では起こりえない幅
    assert pl.classify(70.0, -77.49) == pl.OVER_LIMIT
    # 2026-09-14 エアトリ(6191): 1,073円 → 1,665円。値幅拡大の可能性
    assert pl.classify(1665.0, 55.17) == pl.OVER_LIMIT


def test_途中で止まった値動きには印を付けない():
    # 2026-09-18 アドバンスクリエイト(8798): 136円 → 174円（値幅50円に届かない）
    assert pl.classify(174.0, 27.94) == ""
    assert pl.classify(2500.0, 1.5) == ""


# --- 端 ---------------------------------------------------------------------

def test_値が無ければ判定しない():
    assert pl.classify(None, 10.0) == ""
    assert pl.classify(100.0, None) == ""


def test_下落率が100パーセント以上なら判定しない():
    # 前日終値が0以下になる入力。壊れたデータで例外を出さない
    assert pl.classify(100.0, -100.0) == ""
    assert pl.classify(100.0, -120.0) == ""


def test_丸め誤差でストップ高を取りこぼさない():
    # 騰落率は小数2桁しか無いので、逆算した前日終値に誤差が乗る
    assert pl.classify(163.0, 44.24) == pl.STOP_HIGH
    assert pl.classify(163.0, 44.26) == pl.STOP_HIGH


def test_印には説明が対応している():
    for key in (pl.STOP_HIGH, pl.STOP_LOW, pl.OVER_LIMIT):
        assert pl.LABELS[key] and pl.DESCRIPTIONS[key]
