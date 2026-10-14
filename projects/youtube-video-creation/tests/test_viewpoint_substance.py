"""見立ての節に「比べ」か「次に起きること」が入っているか（2026-10-03「動画の質を上げる仕組み ⑥」）。"""
from src.research import Notes, Section, _check_viewpoint_substance


def _notes(say, voices=None):
    sec = Section(id="v", heading="右の攻撃の位置", tier="背景", telop="", say=say,
                  voices=voices or [], viewpoint=True)
    return Notes(date="2026-10-03", title="t", question="", sections=[sec])


def test_感想だけの見立ては止める():
    assert _check_viewpoint_substance(_notes(["素晴らしい活躍でした。", "今後も楽しみです。"]))


def test_代弁の行は数えない():
    # 発言の中に日付があっても、こちらの見立てにはならない
    n = _notes(["素晴らしい活躍でした。", "5日の決勝で決めたい"], voices=["", "久保建英"])
    assert _check_viewpoint_substance(n)


def test_数字の比べがあれば通す():
    assert _check_viewpoint_substance(_notes(["合計すると、堂安149分、久保139分です。"])) == []


def test_過去との比べがあれば通す():
    assert _check_viewpoint_substance(_notes(["ワールドカップ以来の先発でした。"])) == []


def test_次の予定があれば通す():
    assert _check_viewpoint_substance(_notes(["発表から3日後の5日には、決勝が待っています。"])) == []


def test_見立てでない節は見ない():
    sec = Section(id="a", heading="発表", tier="報道", telop="", say=["おめでとう。"])
    assert _check_viewpoint_substance(Notes(date="d", title="t", question="", sections=[sec])) == []


def test_次はで始まる予定も通す():
    # カーボベルデのGKの回「次はチリで…目指すと話しています」が誤って止まった
    assert _check_viewpoint_substance(_notes(["次はチリで、南米の王者を目指すと話しています。"])) == []
