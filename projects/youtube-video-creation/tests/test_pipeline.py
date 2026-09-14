

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


def test_写真は一度出たら残す():
    """**挟んだ写真が次の行で下地へ戻っていた**（2026-09-15）。

    フォーデンの回の本編が スタジアム → 写真 → スタジアム → 写真 と
    3回入れ替わり、2026-09-14 の指摘「一つの章で背景を変えるのやめて」が
    そのまま再発していた。`spread_long_cards` が挟んだ1枚を引き継ぐ。
    """
    from src.pipeline import hold_photo
    from src.script_model import parse_script

    nl = chr(10)
    body = ["---", "title: T", "---", "", "## 章", ""]
    body += ["キャスター: いちぎょうめ。", ""]
    body += ["キャスター: にぎょうめ。", "  image: assets/photos/x/01.jpg", ""]
    body += ["キャスター: さんぎょうめ。", ""]
    script = parse_script(nl.join(body))
    assert hold_photo(script) == 1
    got = [line.image for line in script.scenes[0].lines]
    assert got == [None, "assets/photos/x/01.jpg", "assets/photos/x/01.jpg"], got


def test_別の写真が指定されていればそちらに替える():
    from src.pipeline import hold_photo
    from src.script_model import parse_script

    nl = chr(10)
    body = ["---", "title: T", "---", "", "## 章", ""]
    body += ["キャスター: いち。", "  image: assets/photos/x/01.jpg", ""]
    body += ["キャスター: に。", ""]
    body += ["キャスター: さん。", "  image: assets/photos/y/01.jpg", ""]
    body += ["キャスター: よん。", ""]
    script = parse_script(nl.join(body))
    hold_photo(script)
    got = [line.image for line in script.scenes[0].lines]
    assert got[1] == "assets/photos/x/01.jpg"
    assert got[3] == "assets/photos/y/01.jpg", got
