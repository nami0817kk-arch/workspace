

# カードは指定した行で差し替わり、それ以外では出たまま残る。そのため下のテロップ
# だけが変わって画面が20秒以上動かないことがあった（2026-09-07 実測）。

def _talk(text, seconds, card=None, image=None):
    from src.script_model import Line

    line = Line(speaker="キャスター", text=text, card=card, image=image)
    line.duration = seconds
    return line


def _script(lines, photo="assets/images/x/01.jpg"):
    from src.script_model import Scene, Script

    return Script(title="t", scenes=[Scene(title="章", lines=lines)],
                  meta={"thumbnail_photo": photo} if photo else {})


def test_長く止まる絵に写真を挟む():
    from src.pipeline import spread_long_cards

    script = _script([_talk(f"行{i}", 6.0, card="c1") for i in range(4)])
    assert spread_long_cards(script, limit=12.0) == 1
    # 12秒を「超える」3行目の手前で入れる。超えてから入れると超過が残る
    assert [bool(line.image) for line in script.lines] == [False, False, True, False]


def test_挟んだあとも上限を超えさせない():
    """後追いで挟むと、超過ぶんがそのまま残る（実測で23秒→16秒どまりだった）。"""
    from src.pipeline import spread_long_cards
    from src.review import CARD_HOLD_MAX

    lines = [_talk(f"行{i}", 5.0, card="c1") for i in range(10)]
    script = _script(lines)
    spread_long_cards(script, limit=CARD_HOLD_MAX)

    span, look, worst = 0.0, None, 0.0
    for line in script.lines:
        now = (line.card or "", line.image or "")
        span = span + line.duration if now == look else line.duration
        look = now
        worst = max(worst, span)
    assert worst <= CARD_HOLD_MAX


def test_短いままなら何もしない():
    from src.pipeline import spread_long_cards

    script = _script([_talk("行1", 4.0, card="c1"), _talk("行2", 4.0, card="c1")])
    assert spread_long_cards(script, limit=12.0) == 0
    assert not any(line.image for line in script.lines)


def test_カードが変われば数え直す():
    """絵が変わっているので挟む必要がない。"""
    from src.pipeline import spread_long_cards

    script = _script([_talk("行1", 8.0, card="c1"), _talk("行2", 8.0, card="c2"),
                      _talk("行3", 8.0, card="c3")])
    assert spread_long_cards(script, limit=12.0) == 0


def test_写真が無い台本では黙って直さない():
    """review の「カードの持ち」が × を出すので、人が判断する。"""
    from src.pipeline import spread_long_cards

    script = _script([_talk(f"行{i}", 6.0, card="c1") for i in range(4)], photo="")
    assert spread_long_cards(script, limit=12.0) == 0
