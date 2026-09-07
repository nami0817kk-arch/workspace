"""カードを入れる基準（2026-09-07）。

**それまでは勘で決めていた。**回によって4〜7枚とばらついた。
"""


def test_代弁の行は引用カード():
    """**引用が主役の回がいちばん強い**（実測: 残った場面は全部これ）。"""
    from src.cardrule import suggest

    assert suggest("引き分け以上に褒める言葉はない", "ムスリッチ監督") == "quote"
    assert suggest("こう話しました", "キャスター") != "quote"


def test_鉤括弧があれば引用カード():
    from src.cardrule import suggest

    assert suggest("監督は「まだ最善ではない」と話した") == "quote"


def test_数が3つ以上並べば棒グラフ():
    """**桁数ではなく、数のかたまりを数える。**

    「8本、3.16、0」を桁で数えると4になり、閾値の意味がずれる。
    """
    from src.cardrule import suggest

    assert suggest("枠内シュートは8本、期待ゴールは3.16、得点は0でした") == "bars"
    assert suggest("3試合で16得点、無失点です") == ""      # 2つでは足りない
    assert suggest("前半は2点、後半は3点で、合計5点") == "bars"


def test_時系列は表():
    """順番が追えることが要る場面。**棒より先に見る。**"""
    from src.cardrule import suggest

    assert suggest("6分にヤマル、22分にロペス、50分にラフィーニャが決めています") == "table"


def test_列挙は箇条書き():
    from src.cardrule import suggest

    assert suggest("この夏に起きたことは、ふたつあります") == "points"


def test_ただの繋ぎにはカードを出さない():
    """**出しすぎない。**画面が文字だらけになる"""
    from src.cardrule import suggest

    for text in ("つぎに見るべきは次節です", "監督はこう話しました",
                 "その直後のことでした", ""):
        assert suggest(text) == "", text


def test_8秒以上変わらない区間を見つける():
    """**上限が review と違う。**あちらは本編向けの20秒、こちらは8秒。"""
    from src.cardrule import SAME_LOOK_MAX, gaps
    from src.script_model import parse_script

    nl = chr(10)
    script = parse_script(nl.join(
        ["## 章", "", "キャスター: あ。" + "あ" * 200,
         "キャスター: い。" + "い" * 200, ""]))
    found = gaps(script)
    assert SAME_LOOK_MAX == 8.0
    assert found, "長い静止を拾えていない"
