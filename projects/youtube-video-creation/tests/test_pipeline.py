

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


def test_冒頭は8秒で写真に変える():
    """**崖は12秒→24秒**（2026-09-15 の実測）。維持率が82%から50%へ落ちる。

    そこは1枚目の絵が出っぱなしの区間で、`spread_long_cards` が写真を
    挟むのは20秒を超えてから。**落ちきってから変えていた。**
    """
    from src.pipeline import open_early

    script = _script([_talk(f"行{i}", 5.0) for i in range(6)], photo="p.jpg")
    assert open_early(script, within=25.0, limit=8.0) == 1
    # 5秒 + 5秒 = 10秒で8秒を超える。**超える行に先回りする**ので3行目
    # 5秒 + 5秒 = 10秒で8秒を超える。**超える行に先回りする**ので2行目、
    # つまり画面は**5秒で**変わる（崖の12秒より手前）
    assert [bool(line.image) for line in script.lines] == [
        False, True, False, False, False, False]


def test_絵の入れ替えは1本1回のまま():
    """**目的なく画面をコロコロ変えない**（2026-09-15 ユーザー指摘）。

    早く出すだけで、出す回数は増やさない。`hold_photo` が後ろへ引き継ぐので、
    下地 → 写真 の1回で終わる。`scan_switch.py` の数え方と同じにする。
    """
    from src.pipeline import hold_photo, open_early, spread_long_cards

    script = _script([_talk(f"行{i}", 5.0) for i in range(12)], photo="p.jpg")
    spread_long_cards(script, limit=20.0)
    open_early(script)
    hold_photo(script)

    switches, look = 0, None
    for line in script.lines:
        now = line.image or ""
        if look is not None and now != look:
            switches += 1
        look = now
    assert switches == 1, [l.image for l in script.lines]


def test_写真が無い回には何もしない():
    """エンブレムで作る回は下地を止める決まり（2026-09-15）。触らない。"""
    from src.pipeline import open_early

    script = _script([_talk(f"行{i}", 5.0) for i in range(6)], photo="")
    assert open_early(script) == 0
    assert not any(line.image for line in script.lines)


def test_冒頭を過ぎたら手を出さない():
    """25秒より後ろは `spread_long_cards` の持ち場。二重に挟まない。"""
    from src.pipeline import open_early

    # 1行目だけで30秒。**この時点で冒頭の窓を過ぎている**
    script = _script([_talk("長い行", 30.0)] + [_talk(f"行{i}", 5.0) for i in range(4)],
                     photo="p.jpg")
    assert open_early(script, within=25.0, limit=8.0) == 0


def test_数字が並ぶ節に表が無ければ言う():
    """**声だけで数字を並べても、聞く人は数えられない**（2026-09-15）。

    9/16 の本編5本のうち4本は、110秒のあいだ画面が2つしかなかった。
    表にすれば画面が1枚増え、耳で追えなかった人が目で追える。
    """
    from src.research import Notes, Section, _advise_cards

    numbered = Section(id="s", heading="数字の節", tier="報道", telop="",
                       say=["46分に1点", "74分に追いつく", "88分に2点目"])
    plain = Section(id="t", heading="言葉の節", tier="報道", telop="",
                    say=["こう話しました", "そのあとに続けています"])
    notes = Notes(date="2026年9月17日", title="t", question="q",
                  sections=[numbered, plain])

    hints = _advise_cards(notes)
    assert len(hints) == 1
    assert "数字の節" in hints[0]
    assert "言葉の節" not in "".join(hints)


def test_反応の節は表を求めない():
    """白い箱を並べる形が決まっているので、そこに表は出さない。"""
    from src.research import Notes, Section, _advise_cards

    voices = Section(id="v", heading="見ていた人", tier="未確認", telop="",
                     card={"type": "reactions"},
                     say=["1点目がひどい", "2点目もだめ", "3失点は重い"])
    notes = Notes(date="2026年9月17日", title="t", question="q", sections=[voices])
    assert _advise_cards(notes) == []
