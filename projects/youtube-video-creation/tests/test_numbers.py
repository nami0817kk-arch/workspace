"""数字を取る口（2026-09-08）。表を行ごとの文字に起こす。"""
import pytest

from src import numbers


PAGE = (
    "<h2>今季の成績</h2>"
    "<table><tr><th>大会</th><th>試合</th><th>得点</th><th>アシスト</th></tr>"
    "<tr><td>ラ・リーガ</td><td>4</td><td>1</td><td>0</td></tr>"
    "<tr><td>合計</td><td>4</td><td>1</td><td>0</td></tr></table>"
    "<table><tr><td>1行だけの表</td></tr></table>"
    "<table><tr><td>国籍:</td><td>" + " ".join(["国" + str(n) for n in range(80)]) + "</td></tr>"
    "<tr><td>年:</td><td>" + " ".join(str(y) for y in range(1990, 2027)) + "</td></tr></table>"
)


def test_表を行と列の文字に起こす():
    tables = numbers.parse(PAGE)
    assert len(tables) == 1                       # 1行の表と、絞り込みフォームは落とす
    assert tables[0].caption == "今季の成績"
    assert tables[0].rows[1] == ["ラ・リーガ", "4", "1", "0"]
    text = numbers.render("https://www.transfermarkt.jp/x", tables)
    assert "ラ・リーガ｜4｜1｜0" in text


def test_読めないサイトは止める():
    assert numbers.readable("https://www.transfermarkt.jp/takefusa-kubo/profil/spieler/442740")
    assert not numbers.readable("https://fbref.com/en/players/x")   # 実測 403
    with pytest.raises(numbers.NumbersError):
        numbers.fetch("https://fbref.com/en/players/x")


def test_セルの中の入れ子の表で外の表が切れない():
    """transfermarkt は選手のセルに小さな表を入れる。外の表が2行で切れていた。"""
    page = (
        "<table class=\"items\"><tr><th>#</th><th>選手</th><th>市場価値</th></tr>"
        "<tr><td>1</td><td><table class=\"inline-table\"><tr><td>ハーランド</td></tr>"
        "<tr><td>CF</td></tr></table></td><td>220m</td></tr>"
        "<tr><td>2</td><td><table class=\"inline-table\"><tr><td>ヤマル</td></tr>"
        "<tr><td>RW</td></tr></table></td><td>200m</td></tr>"
        "<tr><td>3</td><td>ムバッペ</td><td>180m</td></tr></table>"
    )
    tables = numbers.parse(page)
    assert len(tables) == 1
    assert len(tables[0].rows) == 4
    assert tables[0].rows[1] == ["1", "ハーランド CF", "220m"]
    assert tables[0].rows[3] == ["3", "ムバッペ", "180m"]
