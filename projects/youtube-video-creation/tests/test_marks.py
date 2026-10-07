"""書き込み（赤ペン）：表・判定表・数字の板の項目や写真の顔に、手書き風の印を足す（2026-10-07）。

座標は書かせず、項目の番号・列で指す。前の行から積もり、カードが替われば消える。1画面2つまで。
壊れた例（知らない kind・ありえない row・3つ目の書き込み）が止まることを見る。
"""
import json

import pytest
from PIL import Image

from src import cards, marks
from src.config import load_config
from src.marks import MarkError
from src.research import ResearchError, build_notes, to_script, verify
from src.script_model import ScriptError, parse_script
from tests.test_research import _plan, _raw, _section

TABLE = {"type": "table", "title": "「1月に別れ」の中身", "columns": ["", "日本で広がった話", "記事"],
         "rows": [["1月", "1月に去る？", "1月にクラブを離れる"], ["理由", "序列", "アジアカップ"],
                  ["長さ", "移籍", "最大11試合"]]}
VERDICT = {"type": "verdict", "title": "答え合わせ", "columns": ["選手", "判定", "ここまで"],
           "rows": [["イサク", "◎", "8試合6点"], ["ヴィルツ", "△", "1点"], ["ディオマンデ", "×", "41%"]]}
STATS = {"type": "stats", "title": "メッシの代表", "items": [["208", "試合"], ["126", "点"], ["W杯", "優勝"]]}


# ------------------------------------------------------------------ 書き方


def test_書き方を読む():
    got = marks.parse("{kind: strike, row: 0}")
    assert got == [{"kind": "strike", "row": 0}]
    got = marks.parse([{"kind": "note", "row": 0, "col": "記事", "text": "アジアカップで抜ける"},
                       {"kind": "circle", "on": "photo", "face": 1}])
    assert got[0]["col"] == "記事" and got[1] == {"kind": "circle", "on": "photo", "face": 1}


@pytest.mark.parametrize("bad, words", [
    ({"kind": "wave", "row": 0}, "kind"),                         # 知らない kind
    ({"kind": "circle", "row": 0, "x": 120}, "知らない鍵"),          # 座標は書かせない
    ({"kind": "circle"}, "row"),                                  # 指す先が無い
    ({"kind": "circle", "row": 0, "item": 1}, "どちらか"),
    ({"kind": "circle", "row": -1}, "番号"),
    ({"kind": "circle", "row": True}, "番号"),
    ({"kind": "note", "row": 0}, "text"),                         # 添え書きに字が無い
    ({"kind": "note", "row": 0, "text": "あ" * 17}, "字"),
    ({"kind": "strike", "on": "photo"}, "写真"),                   # 顔に取り消し線は引けない
    ({"kind": "circle", "on": "photo", "row": 0}, "face"),
    ({"kind": "circle", "row": 0, "face": 0}, "face"),
])
def test_壊れた書き方は止める(bad, words):
    with pytest.raises(MarkError) as err:
        marks.parse(bad)
    assert words in str(err.value)


def test_指す先がカードに無ければ止める():
    assert marks.check_target({"kind": "circle", "row": 2}, TABLE) == []
    assert "0〜2" in marks.check_target({"kind": "circle", "row": 3}, TABLE)[0]       # ありえない row
    assert "列" in marks.check_target({"kind": "circle", "row": 0, "col": "監督"}, TABLE)[0]
    assert "col 5" in marks.check_target({"kind": "circle", "row": 0, "col": 5}, TABLE)[0]
    assert marks.check_target({"kind": "circle", "row": 0, "col": "判定"}, VERDICT) == []
    assert marks.check_target({"kind": "circle", "item": 1}, STATS) == []
    assert "カードがありません" in marks.check_target({"kind": "circle", "row": 0}, None)[0]
    assert "書き込みを足せません" in marks.check_target({"kind": "circle", "row": 0},
                                                       {"type": "quote", "text": "x"})[0]


# ------------------------------------------------------------------ 積もる・消える・2つまで


def _step(card, spec, new, image=None):
    return {"where": "w", "card": card, "spec": spec, "image": image, "marks": new}


def test_同じ表のあいだは積もり_カードが替われば消える():
    board = marks.Board()
    a = {"kind": "strike", "row": 0}
    b = {"kind": "note", "row": 0, "text": "移籍ではない"}
    assert board.step("t0", TABLE, None, [a]) == [a]
    # 光らせる行だけ違う同じ表（行ごとのカード）なら残る
    assert board.step("t1", dict(TABLE, highlight_row=1), None, [b]) == [a, b]
    assert board.step("t1", dict(TABLE, highlight_row=1), None, []) == [a, b]
    # 別のカードに替われば消える
    assert board.step("v", VERDICT, None, []) == []
    # 写真の上の書き込みは、写真が替われば消える（カードの上のものは残る）
    c = {"kind": "circle", "row": 2}
    p = {"kind": "circle", "on": "photo"}
    assert board.step("v", VERDICT, "a.jpg", [c, p]) == [c, p]
    assert board.step("v", VERDICT, "b.jpg", []) == [c]


def test_3つ目の書き込みは止める():
    a, b, c = ({"kind": "strike", "row": 0}, {"kind": "note", "row": 0, "text": "x"},
               {"kind": "circle", "row": 2})
    assert marks.check_steps([_step("t", TABLE, [a]), _step("t", TABLE, [b])]) == []
    found = marks.check_steps([_step("t", TABLE, [a]), _step("t", TABLE, [b]), _step("t", TABLE, [c])])
    assert found and "3つ" in found[0]
    # カードが替わったあとなら、また2つまで書ける
    assert marks.check_steps([_step("t", TABLE, [a, b]), _step("v", VERDICT, [c])]) == []


# ------------------------------------------------------------------ 台本


SCRIPT = ("---\ntitle: t\ncards:\n"
          "  t0: " + json.dumps(dict(TABLE, highlight_row=0), ensure_ascii=False) + "\n"
          "  t1: " + json.dumps(dict(TABLE, highlight_row=1), ensure_ascii=False) + "\n---\n"
          "## 節\nキャスター: 1行目\n  card: t0\n  mark: {kind: strike, row: 0, col: 1}\n"
          "キャスター: 2行目\n  mark: {kind: note, row: 0, col: 1, text: アジアカップで抜ける}\n"
          "キャスター: 3行目\n  card: t1\n")


def test_台本の書き込みを読み_記録に残す():
    script = parse_script(SCRIPT)
    assert script.lines[0].marks == [{"kind": "strike", "row": 0, "col": 1}]
    rows = script.to_dict()["scenes"][0]["lines"]
    # 3行目は光らせる行だけ違う同じ表なので、書き込みは残っている
    assert [len(r["marks"]) for r in rows] == [1, 2, 2]


def test_台本の3つ目の書き込みとありえない行は読み込みで止める():
    with pytest.raises(ScriptError, match="3つ"):
        parse_script(SCRIPT + "  mark: {kind: circle, row: 2}\n")
    with pytest.raises(ScriptError, match="0〜2"):
        parse_script(SCRIPT.replace("{kind: strike, row: 0, col: 1}", "{kind: strike, row: 7}"))
    with pytest.raises(ScriptError, match="kind"):
        parse_script(SCRIPT.replace("kind: strike", "kind: wave"))


def test_書き込みを足した行は同じ絵と数えない(tmp_path):
    from src.review import check_card_hold

    lines = [{"card": "t", "image": "a.jpg", "duration": 12.0, "marks": []},
             {"card": "t", "image": "a.jpg", "duration": 12.0, "marks": ["取り消し線（row 0）"]}]
    path = tmp_path / "script.json"
    path.write_text(json.dumps({"scenes": [{"lines": lines}]}, ensure_ascii=False), encoding="utf-8")
    assert check_card_hold(path).ok
    for line in lines:
        line["marks"] = []
    path.write_text(json.dumps({"scenes": [{"lines": lines}]}, ensure_ascii=False), encoding="utf-8")
    assert not check_card_hold(path).ok        # 書き込みが無ければ、今までどおり 24秒で ×


# ------------------------------------------------------------------ 取材メモ


def _notes_with(say):
    raw = _raw()
    raw["sections"][0] = _section(say=say)
    return build_notes(raw)


def test_取材メモの書き込みは台本に渡る():
    say = [{"text": "えーからびーへうつりました。", "card": dict(TABLE, highlight_row=0),
            "mark": {"kind": "strike", "row": 0, "col": 1}},
           {"text": "なかみはべつのはなしでした。", "card": dict(TABLE, highlight_row=0),
            "mark": {"kind": "note", "row": 0, "col": 1, "text": "アジアカップで抜ける"}}]
    notes = _notes_with(say)
    assert verify(notes, _plan()) == []
    script = parse_script(to_script(notes, _plan()))
    assert [m["kind"] for line in script.lines for m in line.marks] == ["strike", "note"]


def test_取材メモの3つ目とありえない行は_draftが止める():
    card = dict(TABLE, highlight_row=0)
    say = [{"text": f"ぎょう{i}のはなしです。", "card": card, "mark": {"kind": "circle", "row": i}}
           for i in range(3)]
    found = verify(_notes_with(say), _plan())
    assert any("書き込み" in p and "3つ" in p for p in found)
    say = [{"text": "ひとつめのはなしです。", "card": card, "mark": {"kind": "circle", "row": 9}}]
    found = verify(_notes_with(say), _plan())
    assert any("書き込み" in p and "0〜2" in p for p in found)
    # 書き込みの先にカードが無い（表を下ろした行）
    say = [{"text": "ひとつめのはなしです。", "card": "none", "mark": {"kind": "circle", "row": 0}}]
    assert any("カードがありません" in p for p in verify(_notes_with(say), _plan()))


def test_取材メモの知らない書き込みは読み込みで止める():
    with pytest.raises(ResearchError, match="kind"):
        _notes_with([{"text": "あ。", "mark": {"kind": "wave", "row": 0}}])


# ------------------------------------------------------------------ 的の位置・描画


@pytest.fixture(scope="module")
def fonts():
    video = load_config().video
    return str(video.font_path()), str(video.latin_font_path())


@pytest.mark.parametrize("spec", [TABLE, VERDICT, STATS,
                                  {"type": "calc", "terms": [["125試合"], ["11年"], ["年10.8試合"]], "ops": ["÷", "＝"]},
                                  {"type": "bars", "items": [{"label": "a", "value": 3}, {"label": "b", "value": 1}]},
                                  {"type": "points", "items": ["一つ目", "二つ目"]}])
def test_項目の位置はカードの中にあり_数は指せる数と同じ(fonts, spec):
    geo = cards.layout(spec, 1420, *fonts)
    assert len(geo["units"]) == cards.mark_units(spec)
    w, h = geo["size"]
    for unit in geo["units"]:
        x0, y0, x1, y1 = unit["text"]
        assert 0 <= x0 < x1 <= w and 0 <= y0 < y1 <= h
    # 行は上から順（表）か、左から順（数字の板・式）
    firsts = [(u["text"][1], u["text"][0]) for u in geo["units"]]
    assert firsts == sorted(firsts) or [f[1] for f in firsts] == sorted(f[1] for f in firsts)


def _frame(tmp_path, spec, ink, t=1.0, portrait=False):
    from src import shorts
    from src.render import Renderer
    from src.script_model import Line, Scene

    config = load_config()
    if portrait:
        config = shorts.portrait(config)
    photo = tmp_path / "p.jpg"
    Image.new("RGB", (1600, 900), (90, 110, 130)).save(photo)
    renderer = Renderer(config, tmp_path / ("s" if portrait else "m"))
    renderer.script_cards = {"c": spec}
    parsed = marks.parse(ink)
    line = Line(speaker="キャスター", text="x", telop="見出し", image=str(photo), card="c", marks=parsed)
    scene = Scene(title="見立て", lines=[line])
    return renderer, renderer.frame(line, scene, False, panel=("見出し", None, "c"),
                                    marks=tuple(parsed), mark_new=len(parsed), mark_t=t)


def _red(image) -> int:
    px = list(image.convert("RGB").getdata())
    return sum(1 for r, g, b in px if r > 200 and g < 90 and b < 70)


@pytest.mark.parametrize("portrait", [False, True])
def test_書き込みは朱で描かれ_途中のコマは少なく描く(tmp_path, portrait):
    ink = [{"kind": "strike", "row": 0, "col": 1}, {"kind": "note", "row": 0, "col": 1, "text": "アジアカップで抜ける"}]
    _, plain = _frame(tmp_path, TABLE, [], portrait=portrait)
    _, full = _frame(tmp_path, TABLE, ink, portrait=portrait)
    _, half = _frame(tmp_path, TABLE, ink, t=0.4, portrait=portrait)
    with Image.open(plain) as a, Image.open(full) as b, Image.open(half) as c:
        assert _red(a) < 50
        assert _red(b) > 2000
        assert _red(a) < _red(c) < _red(b)


def test_透明の画面でも黒い枠を出さない(tmp_path):
    """背景が動画の回は透過の絵に描く。書き込みの外は透明のまま（断面図の apply は RGB に落として黒い枠が出た）。"""
    from src.render import Renderer
    from src.script_model import Line, Scene

    def draw(ink, where):
        renderer = Renderer(load_config(), tmp_path / where)
        renderer.over_video = True
        renderer.script_cards = {"c": VERDICT}
        parsed = marks.parse(ink)
        line = Line(speaker="キャスター", text="x", telop="見出し", card="c", marks=parsed)
        return renderer, renderer.frame(line, Scene(title="節", lines=[line]), False,
                                        panel=("見出し", None, "c"), marks=tuple(parsed),
                                        mark_new=len(parsed), mark_t=1.0)

    _, plain = draw([], "plain")
    renderer, frame = draw({"kind": "circle", "row": 2}, "ink")
    with Image.open(plain) as base:
        base_alpha = base.getchannel("A")
    with Image.open(frame) as image:
        assert image.mode == "RGBA"
        alpha = image.getchannel("A")
        rgb = image.convert("RGB")
        place = renderer._card_place[2]
        # 丸はカードの外にも少しはみ出す。はみ出したところは朱で、黒ではない
        ring = [(x, y) for x in range(int(place[0]) - 30, int(place[0]) + 4)
                for y in range(int(place[1]), int(place[3])) if alpha.getpixel((x, y)) > 200]
        assert ring, "丸が描かれていない"
        assert all(sum(rgb.getpixel(p)) > 120 for p in ring if alpha.getpixel(p) == 255)
        # 書き込みから離れたところの透明さは、書き込みの無い絵と同じ（層ごと不透明にしていない）
        for point in ((5, 5), (1910, 500), (1700, 300), (960, 1070)):
            assert alpha.getpixel(point) == base_alpha.getpixel(point)


def test_指す行が今のカードに無ければ描かない(tmp_path):
    _, plain = _frame(tmp_path, VERDICT, [])
    renderer, frame = _frame(tmp_path, dict(VERDICT, rows=VERDICT["rows"][:1]), [{"kind": "circle", "row": 2}])
    with Image.open(frame) as image:
        assert _red(image) < 400            # 判定表の×の印（赤）だけ。丸は無い


def _timed(text):
    script = parse_script(text)
    for line in script.lines:
        line.duration, line.pause = 3.0, 0.0
    return script


def test_書き込みを足しても表は開き直さず_描き進めるコマが入る(tmp_path):
    from src.render import MARK_STEPS, Renderer

    config = load_config()
    config.video.show_characters = False
    config.video.channel_name = ""
    with_ink = Renderer(config, tmp_path / "a").frame_entries(_timed(SCRIPT))
    without = Renderer(config, tmp_path / "b").frame_entries(_timed(
        SCRIPT.replace("  mark: {kind: strike, row: 0, col: 1}\n", "").replace(
            "  mark: {kind: note, row: 0, col: 1, text: アジアカップで抜ける}\n", "")))
    # 書き込みを描き進めるコマが2行ぶん入る（尺は口パクの側から取る）
    from src.render import MARK_IN
    step = MARK_IN / MARK_STEPS
    assert sum(1 for _, s in with_ink if s == pytest.approx(step)) == 2 * (MARK_STEPS - 1)
    assert not [s for _, s in without if s == pytest.approx(step)]
    # 表の行が1本ずつ出るコマは、書き込みがあっても1行目の1回だけ（3行目の t1 は同じ表なので開き直さない）
    class Spy(Renderer):
        def __init__(self, *a):
            super().__init__(*a)
            self.reveals = []

        def frame(self, line, scene, *a, **k):
            if k.get("reveal") is not None:
                self.reveals.append(line.text)
            return super().frame(line, scene, *a, **k)

    spy = Spy(config, tmp_path / "c")
    spy.frame_entries(_timed(SCRIPT))
    assert spy.reveals and set(spy.reveals) == {"1行目"}
    assert sum(s for _, s in with_ink) == pytest.approx(sum(s for _, s in without))


def test_下見は写真の顔を丸で囲んでも顔に板とは言わない(tmp_path):
    """preview4 は写真だけの絵とコマの差で「顔に板」を見る。顔のまわりの丸は顔の枠の外を通る。"""
    from src import faces
    from src.render import Renderer
    from src.script_model import Line, Scene
    from tools.preview4 import covered

    if not faces.available():
        pytest.skip("OpenCV が無い")
    from pathlib import Path
    sample = Path("assets/images/20261007_kubo_january/01_side_w.jpg")
    if not sample.exists():
        pytest.skip("写真が手元に無い")
    renderer = Renderer(load_config(), tmp_path)
    parsed = marks.parse([{"kind": "circle", "on": "photo"}, {"kind": "note", "on": "photo", "text": "本人"}])
    line = Line(speaker="キャスター", text="x", telop="見出し", image=str(sample), marks=parsed)
    frame = renderer.frame(line, Scene(title="節", lines=[line]), False, panel=("見出し", None, None),
                           marks=tuple(parsed), mark_new=2, mark_t=1.0)
    stage = renderer._photo_stage(str(sample)).convert("RGB")
    heads = renderer.mark_heads(str(sample), renderer._photo_stage(str(sample)))
    assert heads
    with Image.open(frame) as image:
        assert _red(image) > 1500
        boxes = faces.find_faces(stage)
        assert not [m for m in covered(image.convert("RGB"), stage, boxes, []) if m[0] == "×"]
