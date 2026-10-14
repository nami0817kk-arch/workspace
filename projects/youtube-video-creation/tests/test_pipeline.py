

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


def _screen_runs(script, specs=None):
    """**画面に出ている絵**が変わらないまま続く秒数の並び（2026-10-08）。

    カードも写真も「書いた行で替わり、次の行からは引き継がれて残る」ので、
    生の `line.card` / `line.image` で数えると、引き継いでいる行が
    「絵が戻った」ように見えて区間が切れる。`spread_long_cards` と同じ数え方。
    """
    from src.pipeline import _stage_of
    from src.review import card_look

    runs = []
    for scene in script.scenes:
        showing, stage, look, span = None, "", None, 0.0
        for line in scene.lines:
            if line.card is not None:
                showing = None if line.card in ("none", "なし") else line.card
            stage = _stage_of(line, stage)
            now = (card_look(showing, specs or script.cards or {}), stage)
            if now != look:
                if look is not None:
                    runs.append(span)
                look, span = now, float(line.duration or 0)
            else:
                span += float(line.duration or 0)
        if look is not None:
            runs.append(span)
    return runs


def _long_screens(script, limit, specs=None):
    """上限を超えて止まっている区間の (秒数, そのとき出ている写真)。"""
    from src.pipeline import _stage_of
    from src.review import card_look

    out = []
    for scene in script.scenes:
        showing, stage, look, span = None, "", None, 0.0
        for line in scene.lines:
            if line.card is not None:
                showing = None if line.card in ("none", "なし") else line.card
            stage = _stage_of(line, stage)
            now = (card_look(showing, specs or script.cards or {}), stage)
            if now != look:
                if look is not None and span > limit:
                    out.append((span, look[1]))
                look, span = now, float(line.duration or 0)
            else:
                span += float(line.duration or 0)
        if look is not None and span > limit:
            out.append((span, look[1]))
    return out


def test_挟んだあとも上限を超えさせない():
    """後追いで挟むと、超過ぶんがそのまま残る（実測で23秒→16秒どまりだった）。

    **画面に出ている絵で数える**（2026-10-08）。それまでは生の `line.image` で
    数えていたので、挟んだ次の行で「絵が戻った」ように見えて区間が切れ、
    **実際には写真を挟んだあとも30秒止まっている画面が通っていた**。
    サムネの写真は1枚しか無いので替えられるのは1回で、**残りは機械では縮まない**。
    そこは `review` の「カードの持ち」が × を出し、人がカードを2枚に割る
    （CLAUDE.md の直し方の1つめ）。
    """
    from src.pipeline import spread_long_cards
    from src.review import CARD_HOLD_MAX

    lines = [_talk(f"行{i}", 5.0, card="c1") for i in range(10)]
    script = _script(lines)
    assert spread_long_cards(script, limit=CARD_HOLD_MAX) == 1

    runs = _screen_runs(script)
    # **超える行に先回りする**ので、1つめの区間は上限に収まる
    assert runs[0] <= CARD_HOLD_MAX, runs
    assert len(runs) >= 2, runs


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


def test_板は次の行へ引き継がない():
    """**板を引き継ぐと、そのあとの節のカードが全部消える**（2026-09-20）。

    プレミア20クラブ紹介のボーンマスで、基礎DATAの板が20秒から165秒まで
    出っぱなしになり、歩んできた道・名選手・宿敵のカードが1枚も画面に
    出ていなかった。板の上には何も重ねない決まりと噛み合って、
    節が進んでも絵が変わらない。引き継ぐのは写真だけ。
    """
    from src.pipeline import hold_photo
    from src.script_model import parse_script

    nl = chr(10)
    body = ["---", "title: T", "---", "", "## 章", ""]
    body += ["キャスター: いち。", "  image: assets/stats/pl_bournemouth_data.png", ""]
    body += ["キャスター: に。", ""]
    body += ["キャスター: さん。", ""]
    script = parse_script(nl.join(body))
    assert hold_photo(script) == 0
    got = [line.image for line in script.scenes[0].lines]
    assert got == ["assets/stats/pl_bournemouth_data.png", None, None], got


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


def _row_cards(prefix: str, rows: int):
    """**実物と同じ形**：中身が同じ表を行ごとに分け、光らせる行だけ替えたカード。

    2026-10-07 から `research` がこの形を作る（`rivals_0_card`〜`rivals_9_card`）。
    """
    table = {"type": "table", "title": "在任の長さと年俸",
             "columns": ["監督", "在任", "年俸"],
             "rows": [[f"監督{i}", f"{i}年", f"{i}00万"] for i in range(rows)]}
    return {f"{prefix}_{i}_card": dict(table, highlight_row=i) for i in range(rows)}


def test_光らせる行だけ違う同じ表は同じ絵として数える():
    """**実物4本の点検（`tools/qc.py`）で出た停滞**（2026-10-08）。

    `output/20261008_finance_arteta` 第4節は、同じ散らばり図のまま**37秒**動いて
    いなかった。`spread_long_cards` は「カードの名前」で絵を見分けていたので、
    行ごとにカードを分けた節では**行が替わるたびに数え直して**いて、
    20秒に一度も届かず、写真を挟む処理が走らなかった。
    """
    from src.pipeline import spread_long_cards
    from src.review import CARD_HOLD_MAX

    specs = _row_cards("rivals", 10)
    lines = [_talk(f"行{i}", 4.0, card=f"rivals_{i}_card",
                   image="assets/images/x/04_w.jpg") for i in range(10)]
    script = _script(lines)
    script.cards = specs

    # 直す前の数え方（カードの名前）では、どの区間も4秒にしか見えない
    names = [(l.card, l.image) for l in script.lines]
    assert len(set(names)) == len(names)

    assert spread_long_cards(script, limit=CARD_HOLD_MAX) == 1, "40秒の停滞に手が入っていない"
    runs = _screen_runs(script, specs)
    assert max(runs) <= CARD_HOLD_MAX, runs


def test_替えられる写真が無ければ黙って直さない():
    """同じ写真を切り直しただけ（`_w` と `_v`）では画面が変わらない。

    手を出さずに `review` の「カードの持ち」に × を出させ、人がカードを2枚に割る。
    """
    from src.pipeline import spread_long_cards
    from src.review import CARD_HOLD_MAX

    specs = _row_cards("after", 10)
    lines = [_talk(f"行{i}", 4.0, card=f"after_{i}_card",
                   image="assets/images/x/03_chelsea_v.jpg") for i in range(10)]
    script = _script(lines, photo="assets/images/x/03_chelsea_w.jpg")
    script.cards = specs
    assert spread_long_cards(script, limit=CARD_HOLD_MAX) == 0
    assert {l.image for l in script.lines} == {"assets/images/x/03_chelsea_v.jpg"}


def test_写真を替えたら台本の次の指定まで持ち越す():
    """**1行だけ替えると明滅する**（2026-09-15 に `hold_photo` を作った理由と同じ）。"""
    from src.pipeline import spread_long_cards
    from src.review import CARD_HOLD_MAX

    specs = _row_cards("rivals", 8)
    lines = [_talk(f"行{i}", 4.0, card=f"rivals_{i}_card",
                   image="assets/images/x/04_w.jpg") for i in range(8)]
    lines += [_talk("別の絵", 4.0, card="none", image="assets/images/x/03_w.jpg")]
    script = _script(lines, photo="assets/images/x/01.jpg")
    script.cards = specs
    spread_long_cards(script, limit=CARD_HOLD_MAX)

    got = [l.image for l in script.lines]
    assert got[-1] == "assets/images/x/03_w.jpg", "台本が指定した写真を上書きしている"
    swapped = [i for i, p in enumerate(got) if p == "assets/images/x/01.jpg"]
    assert swapped, got
    # 替えたところから、台本が次の写真を指定する手前まで続いている（1行だけにしない）
    assert swapped == list(range(swapped[0], len(got) - 1)), got


def test_実物の台本でも同じ板が20秒を超えない():
    """**作り物ではなく、実際に37秒止まった台本で試す**（2026-10-08）。

    `scripts/` にある本編の台本を、書き出しと同じ順
    （`spread_long_cards` → `open_early` → `hold_photo`）で通し、画面に出ている絵が
    上限を超えて止まる区間に**手が入っているか**を見る。替える写真が無い回
    （サムネの写真が、その節で出ている写真と同じ）は `review` に任せるので数えない。
    """
    from pathlib import Path

    import pytest

    from src.pipeline import (drop_short_only, hold_photo, open_early, photo_key,
                              spread_long_cards)
    from src.review import CARD_HOLD_MAX
    from src.script_model import load_script

    root = Path(__file__).resolve().parents[1] / "scripts"
    target = root / "20261008_finance_arteta.md"
    if not target.exists():
        pytest.skip("実物の台本がありません")

    script = drop_short_only(load_script(target))
    for line in script.lines:                   # 実測の平均（書き出し済みの script.json より）
        line.duration = 3.7

    photo = str((script.meta or {}).get("thumbnail_photo") or "")
    before = _long_screens(script, CARD_HOLD_MAX)
    assert before, "この台本では停滞が起きない"

    spread_long_cards(script, limit=CARD_HOLD_MAX)
    open_early(script)
    hold_photo(script)
    after = _long_screens(script, CARD_HOLD_MAX)
    assert len(after) < len(before), f"{before} -> {after}"
    # 残ってよいのは「替える写真が無い」区間だけ（すでにサムネの写真が出ている）
    for seconds, stage in after:
        assert photo_key(stage) == photo_key(photo), f"{seconds:.1f}秒 の停滞が残っている: {stage}"


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


def test_縦の画面では挟む写真も縦版を使う(tmp_path, monkeypatch):
    """**縦の画面では、板と顔は共存できない**（2026-10-08 夜に実測）。

    板は画面の 11〜62% を占めるので、顔を上へ逃がすと頭が切れ、下へ逃がすと板が乗る。
    ところが `spread_long_cards` は縦横の別を見ずにサムネの写真（たいてい顔が主役）を
    差し込むので、**板の長い節があるショートでは誰の回でも顔が板に潰される**
    （ネイマールの回の 39.0〜50.4秒で見つけた。4コマは27.7秒を見るので当たらなかった）。
    隣に縦版（`_v`）があれば、そちらを挟む。
    """
    from src import pipeline

    root = tmp_path
    (root / "assets" / "images" / "x").mkdir(parents=True)
    (root / "assets" / "images" / "x" / "01_w.jpg").write_bytes(b"wide")
    (root / "assets" / "images" / "x" / "01_w_v.jpg").write_bytes(b"tall")
    monkeypatch.setattr(pipeline, "__file__", str(root / "src" / "pipeline.py"))

    assert pipeline.tall_twin("assets/images/x/01_w.jpg") == "assets/images/x/01_w_v.jpg"
    # 縦版が無ければそのまま。すでに縦版ならそのまま
    assert pipeline.tall_twin("assets/images/x/02_w.jpg") == "assets/images/x/02_w.jpg"
    assert pipeline.tall_twin("assets/images/x/01_w_v.jpg") == "assets/images/x/01_w_v.jpg"
    assert pipeline.tall_twin("") == ""
