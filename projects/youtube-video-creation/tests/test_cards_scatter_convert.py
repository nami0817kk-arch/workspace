"""2軸の散らばり図（scatter）と換算の板（convert）。2026-10-07 夜、ユーザーが「3.5」を選んだ。

世の中の断面図の charts5.matrix と figures.convert から、こちらの作り（縦に積むブロック＋reveal）に
合わせて移した。壊れた例（点11個・数でない値・知らない鍵）が止まること、札が重ならないこと、
縦型（1080幅）で字が切れないことを見る。
"""
import json

import pytest
from PIL import Image, ImageStat

from src import cards, marks
from src.cards import CardError, render, row_count
from src.config import load_config

WIDTH = 1420          # 本編で写真の無い画面に置くときの幅（1920 × 0.74）
PHOTO = 1113          # 本編で写真の上に置くときの幅（1920 × 0.58）
PORTRAIT = 972        # ショートの幅（1080 × 0.90）

# 見本と同じ並び（FotMob 2026-10-07 時点のプレミア第5節まで。xG の上位8人）。点が近い3人
# （サカ 3.2/3・キャルバート＝ルーウィン 3.1/3・ムベウモ 3.1/2）で札の逃がし方を試す
SCATTER = {"type": "scatter", "title": "得点と期待値（プレミア第5節まで）",
           "x": {"label": "期待値", "unit": "xG"}, "y": {"label": "得点", "unit": "点"},
           "points": [["ハーランド", 4.4, 5], ["イサク", 3.5, 4], ["バリー", 3.5, 2], ["サカ", 3.2, 3],
                      ["キャルバート＝ルーウィン", 3.1, 3], ["ムベウモ", 3.1, 2], ["イゴール・チアゴ", 3.1, 1],
                      ["ジョアン・ペドロ", 2.2, 3]],
           "focus": "ハーランド", "diagonal": "期待値どおり", "source": "FotMob"}
CONVERT3 = {"type": "convert", "title": "週給30万ポンドは日本円でいくら？",
            "steps": [["30万", "ポンド", "週給"], ["1560万", "ポンド", "年俸（52週）"], ["約30", "億円", "日本円で"]],
            "via": ["×52週", "1ポンド＝195円"]}
CONVERT2 = {"type": "convert", "title": "移籍金を円にすると", "from": ["1億", "ユーロ", "移籍金（推定）"],
            "to": ["約174", "億円", "日本円で"], "via": "1ユーロ＝174円"}


@pytest.fixture(scope="module")
def fonts():
    video = load_config().video
    return str(video.font_path()), str(video.latin_font_path())


def _opaque_inside(path) -> bool:
    with Image.open(path) as image:
        alpha = image.getchannel("A")
        w, h = image.size
        inner = alpha.crop((cards.RADIUS, cards.RADIUS, w - cards.RADIUS, h - cards.RADIUS))
        return min(inner.getdata()) >= cards.PANEL[3]


def _right_margin_is_empty(path) -> bool:
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        w, h = rgb.size
        strip = rgb.crop((w - cards.PAD + 10, cards.RADIUS, w - 6, h - cards.RADIUS))
        return max(sum(px) for px in strip.getdata()) < 400


def _gold(image, box=None) -> int:
    rgb = image.convert("RGB")
    if box:
        rgb = rgb.crop(box)
    gold = cards.BRAND_GOLD[:3]
    return sum(1 for p in rgb.crop((20, 0, rgb.width, rgb.height)).getdata()
               if abs(p[0] - gold[0]) < 12 and abs(p[1] - gold[1]) < 12 and abs(p[2] - gold[2]) < 24)


def _overlap(a, b) -> bool:
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


# ------------------------------------------------------------------ scatter


@pytest.mark.parametrize("width", [WIDTH, PHOTO, PORTRAIT])
def test_散らばり図は不透明で右にはみ出さない(tmp_path, fonts, width):
    path = render(SCATTER, width, fonts[0], tmp_path / f"s{width}.png", fonts[1])
    with Image.open(path) as image:
        assert image.mode == "RGBA" and image.width == width
        assert image.getpixel((2, 2))[3] == 0
    assert _opaque_inside(path), width
    assert _right_margin_is_empty(path), f"幅{width}で右にはみ出した"


@pytest.mark.parametrize("width", [WIDTH, PHOTO, PORTRAIT])
def test_名前の札は点にもほかの札にも重ならず枠の中(fonts, width):
    """点が近い3人（サカ・キャルバート＝ルーウィン・ムベウモ）でも、札どうし・札と点がぶつからない。"""
    geo = cards.layout(SCATTER, width, *fonts)
    w, h = geo["size"]
    units = geo["units"]
    assert len(units) == len(SCATTER["points"]) == cards.mark_units(SCATTER)
    labels = [u["cells"][1] for u in units]
    dots = [u["cells"][0] for u in units]
    for i, a in enumerate(labels):
        assert 0 < a[0] and a[2] < w - cards.PAD and 0 < a[1] and a[3] < h, (width, i, a)
        for j, b in enumerate(labels):
            if i < j:
                assert not _overlap(a, b), (width, SCATTER["points"][i][0], SCATTER["points"][j][0])
        for j, d in enumerate(dots):
            # 点の枠は書き込みのために12px広げてある。札は点そのもの（半径19まで）にかからなければよい
            core = (d[0] + 10, d[1] + 10, d[2] - 10, d[3] - 10)
            assert not _overlap(a, core), (width, SCATTER["points"][i][0], "の札が", SCATTER["points"][j][0], "の点に")


def test_散らばり図は点が1つずつ出て注目だけ黄(tmp_path, fonts):
    assert row_count(SCATTER) == 8
    full = render(SCATTER, PORTRAIT, fonts[0], tmp_path / "a.png", fonts[1])
    none = render(SCATTER, PORTRAIT, fonts[0], tmp_path / "b.png", fonts[1], reveal=0)
    some = render(SCATTER, PORTRAIT, fonts[0], tmp_path / "c.png", fonts[1], reveal=3)
    with Image.open(full) as a, Image.open(none) as b, Image.open(some) as c:
        assert a.size == b.size == c.size            # 出ていない点の場所も空けておく（軸は動かない）
        assert _gold(a) > 300                        # ハーランド（注目）の点と札は黄
        assert _gold(b) == 0                         # 軸だけで、点はまだ無い
        mean = lambda im: ImageStat.Stat(im.convert("L")).mean[0]
        assert mean(b) < mean(c) < mean(a)
    # 注目を書かなければ黄は無い（ほかの点は緑）
    plain = render(dict(SCATTER, focus=None), PORTRAIT, fonts[0], tmp_path / "d.png", fonts[1])
    with Image.open(plain) as d:
        assert _gold(d) == 0


def test_話している点を光らせても開き直さず_札は動かない(tmp_path, fonts):
    from src.render import Renderer

    a = dict(SCATTER, highlight="イゴール・チアゴ")
    b = dict(SCATTER, highlight=2)
    assert cards.same_table(a, b) and cards.same_table(a, SCATTER)
    assert not cards.same_table(a, dict(SCATTER, focus="サカ"))
    renderer = Renderer.__new__(Renderer)
    renderer.script_cards = {"a": a, "b": b}
    assert renderer.same_table("a", "b")
    # 光らせても札の置き場は同じ（行ごとに分けたカードで札が跳ねない）
    assert [u["cells"] for u in cards.layout(a, PORTRAIT, *fonts)["units"]] == \
        [u["cells"] for u in cards.layout(SCATTER, PORTRAIT, *fonts)["units"]]
    lit = render(a, PORTRAIT, fonts[0], tmp_path / "lit.png", fonts[1])
    plain = render(SCATTER, PORTRAIT, fonts[0], tmp_path / "plain.png", fonts[1])
    with Image.open(lit) as x, Image.open(plain) as y:
        assert _gold(x) > _gold(y)                   # 光らせた点の輪と札が黄


def test_目盛りは切りのよい数():
    assert cards.nice_ticks(0, 5.3) == [0, 2, 4, 6]
    assert cards.nice_ticks(0, 4.8) == [0, 1, 2, 3, 4, 5]
    assert cards.nice_ticks(0, 1240) == [0, 250, 500, 750, 1000, 1250]
    assert cards.nice_ticks(0, 0.48) == [0, 0.1, 0.2, 0.3, 0.4, 0.5]
    ticks = cards.nice_ticks(12, 37)
    assert ticks[0] <= 12 and ticks[-1] >= 37 and len(ticks) <= 7


def test_数字は字でも数でも書ける():
    assert cards.to_number("9.8") == 9.8 and cards.to_number(14) == 14.0 and cards.to_number("1,240") == 1240
    assert cards.to_number("１４") == 14.0
    for bad in ("14点", "約3", "", None, True):
        assert cards.to_number(bad) is None


@pytest.mark.parametrize("spec, words", [
    (dict(SCATTER, points=[[f"選手{i}", i, i] for i in range(11)]), "10まで"),         # 点11個
    (dict(SCATTER, points=[["ハーランド", "9.8", "14点"], ["サカ", 1, 1]]), "数だけ"),     # 数でない値
    (dict(SCATTER, points=[["ハーランド", 9.8], ["サカ", 1, 1]]), "[名前, x, y]"),        # 欄が足りない
    (dict(SCATTER, point=[["a", 1, 1]]), "知らない鍵"),                                    # 知らない鍵
    (dict(SCATTER, x={"label": "期待値", "max": 6}), "知らない鍵"),
    (dict(SCATTER, y=None), "軸の名前"),
    (dict(SCATTER, focus="メッシ"), "focus"),
    (dict(SCATTER, highlight=8), "highlight"),
    (dict(SCATTER, points=[["サカ", 1, 1], ["サカ", 2, 2]]), "重なって"),
    (dict(SCATTER, points=[["サカ", 1, 1]]), "2つ以上"),
    (dict(SCATTER, diagonal=1.0), "diagonal"),
])
def test_壊れた散らばり図は止める(tmp_path, fonts, spec, words):
    problems = cards.check_scatter(spec)
    assert problems and any(words in p for p in problems), problems
    with pytest.raises(CardError):
        render(spec, WIDTH, fonts[0], tmp_path / "x.png", fonts[1])


# ------------------------------------------------------------------ convert


def test_換算は元から順に出て最後が黄(tmp_path, fonts):
    assert row_count(CONVERT2) == 3          # 元 → 矢印 → 換算
    assert row_count(CONVERT3) == 5          # 週給 → ×52 → 年俸 → ×195 → 円
    for spec in (CONVERT2, CONVERT3):
        for width in (WIDTH, PHOTO, PORTRAIT):
            full = render(spec, width, fonts[0], tmp_path / f"f{width}.png", fonts[1])
            first = render(spec, width, fonts[0], tmp_path / f"o{width}.png", fonts[1], reveal=1)
            arrow = render(spec, width, fonts[0], tmp_path / f"a{width}.png", fonts[1], reveal=2)
            assert _opaque_inside(full) and _right_margin_is_empty(full), (spec["title"], width)
            with Image.open(full) as a, Image.open(first) as b, Image.open(arrow) as c:
                assert a.size == b.size == c.size
                assert _gold(a) > 1500               # 換算した数字は黄で大きく
                assert _gold(b) == 0 and _gold(c) == 0   # 元の数字・矢印のあいだは、まだ答えが出ていない
                mean = lambda im: ImageStat.Stat(im.convert("L")).mean[0]
                assert mean(b) < mean(c)             # 矢印と式が出る


def test_本編の2段は横に_3段とショートは縦に積む(fonts):
    def boxes(spec, width):
        return [u["box"] for u in cards.layout(spec, width, *fonts)["units"]]

    a, b = boxes(CONVERT2, WIDTH)
    assert a[1] == b[1] and a[2] < b[0]          # 横に並ぶ
    for spec, width in ((CONVERT3, WIDTH), (CONVERT3, PORTRAIT), (CONVERT2, PORTRAIT)):
        found = boxes(spec, width)
        assert all(x[3] < y[1] for x, y in zip(found, found[1:])), (spec["title"], width)   # 上から下へ


@pytest.mark.parametrize("spec, words", [
    (dict(CONVERT2, to=["約百七十四", "億円"]), "数字がありません"),                     # 数字でない値
    (dict(CONVERT2, rate="174"), "知らない鍵"),                                          # 知らない鍵
    ({"type": "convert", "from": ["1", "億ユーロ"]}, "to"),
    (dict(CONVERT3, to=["1", "円"]), "どちらか一方"),
    (dict(CONVERT3, steps=CONVERT3["steps"] + [["1", "円"]], via=["a", "b", "c"]), "2〜3段"),
    (dict(CONVERT3, via=["×52週"]), "via"),
    (dict(CONVERT3, via="×52週・1ポンド＝195円"), "並び"),
])
def test_壊れた換算は止める(tmp_path, fonts, spec, words):
    problems = cards.check_convert(spec)
    assert problems and any(words in p for p in problems), problems
    with pytest.raises(CardError):
        render(spec, WIDTH, fonts[0], tmp_path / "x.png", fonts[1])


def test_量と倍率を読む():
    assert cards.amount("30万ポンド") == 300000
    assert cards.amount("約30億円") == 3e9
    assert cards.amount("1億2000万") == 120000000
    assert cards.amount("1,560万") == 15600000
    assert cards.amount("年俸") is None
    assert cards.via_factor("×52週・1ポンド＝195円") == 52 * 195
    assert cards.via_factor("1ユーロ＝約0.86ポンド") == pytest.approx(0.86)
    assert cards.via_factor("÷12か月") == pytest.approx(1 / 12)
    assert cards.via_factor("週給を年俸に") is None


def test_式と合わない換算だけ知らせる():
    assert cards.convert_mismatches(CONVERT3) == []
    assert cards.convert_mismatches(CONVERT2) == []
    wrong = dict(CONVERT3, steps=[["30万", "ポンド"], ["1560万", "ポンド"], ["約3", "億円"]])
    found = cards.convert_mismatches(wrong)
    assert len(found) == 1 and "30.4億" in found[0]
    # 倍率が数で書いていなければ確かめない（書いた人が計算する）
    assert cards.convert_mismatches(dict(CONVERT2, via="いまの為替で")) == []


# ------------------------------------------------------------------ 取材メモ・台本・書き込み・ショート


def _section(card=None, line_cards=None, say=None, viewpoint=False, heading="h"):
    from src.research import Section

    say = say or ["a"]
    return Section(id="s", heading=heading, tier="報道", telop="t", say=say,
                   sources=["https://example.com/1"], card=card,
                   line_cards=line_cards if line_cards is not None else [None] * len(say),
                   viewpoint=viewpoint)


def test_取材メモの段階で形を見る():
    from src.research import _check_card

    for card in (SCATTER, CONVERT2, CONVERT3, dict(SCATTER, highlight="サカ")):
        assert _check_card(_section(card)) == [], card["title"]
    eleven = dict(SCATTER, points=[[f"選手{i}", i, i] for i in range(11)])
    assert any("10まで" in p for p in _check_card(_section(eleven)))
    assert any("知らない鍵" in p and "points_" in p for p in _check_card(_section(dict(SCATTER, points_=[]))))
    assert any("数字がありません" in p for p in _check_card(_section(dict(CONVERT2, to=["約", "億円"]))))
    # 行ごとのカード（話している選手を光らせる形）も見る
    bad = dict(SCATTER, highlight="メッシ")
    assert any("highlight" in p for p in _check_card(_section(None, line_cards=[bad, None], say=["a", "b"])))


def test_換算のずれは_draftが知らせるが止めない():
    from src.research import Notes, _advise_convert_math, _check_card

    wrong = dict(CONVERT3, steps=[["30万", "ポンド", "週給"], ["1560万", "ポンド", "年俸"], ["約3", "億円", "円"]])
    section = _section(wrong, heading="週給の中身")
    assert _check_card(section) == []                 # 止めない
    hints = _advise_convert_math(Notes(date="2026-10-07", title="t", question="", sections=[section]))
    assert len(hints) == 1 and "週給の中身" in hints[0] and "30.4億" in hints[0]
    ok = _section(CONVERT3)
    assert _advise_convert_math(Notes(date="2026-10-07", title="t", question="", sections=[ok])) == []


def test_見立ての節の表と比べに数える():
    from src.research import _has_calc, _has_count_table

    assert _has_count_table(_section(SCATTER)) and _has_count_table(_section(CONVERT2))
    assert _has_calc(_section(CONVERT2)) and not _has_calc(_section(SCATTER))


def test_散らばり図は長いテロップとぶつかると知らせる():
    from src.research import Notes, _advise_card_telop_overlap

    section = _section(SCATTER, say=["あ" * 45, "い"])
    hints = _advise_card_telop_overlap(Notes(date="2026-10-07", title="t", question="", sections=[section]))
    assert hints and "散らばり図" in hints[0]


def test_書き込みは点と換算の数字を番号で指す():
    assert cards.mark_units(SCATTER) == 8 and cards.mark_units(CONVERT3) == 3
    assert marks.check_target({"kind": "circle", "item": 7}, SCATTER) == []
    assert "0〜7" in marks.check_target({"kind": "circle", "item": 8}, SCATTER)[0]
    assert marks.check_target({"kind": "circle", "item": 0, "col": "名前"}, SCATTER) == []
    assert marks.check_target({"kind": "underline", "item": 2, "col": "注記"}, CONVERT3) == []
    assert "0〜2" in marks.check_target({"kind": "circle", "item": 3}, CONVERT3)[0]


def test_書き込みの丸は指さなければ点そのもの(fonts):
    geo = cards.layout(SCATTER, PORTRAIT, *fonts)
    target = marks.card_target({"kind": "circle", "item": 0}, SCATTER, geo, (0, 0), 1.0)
    assert target["box"] == geo["units"][0]["cells"][0]
    named = marks.card_target({"kind": "circle", "item": 0, "col": "名前"}, SCATTER, geo, (0, 0), 1.0)
    assert named["box"] == geo["units"][0]["cells"][1]
    geo = cards.layout(CONVERT3, PORTRAIT, *fonts)
    target = marks.card_target({"kind": "circle", "item": 2}, CONVERT3, geo, (0, 0), 1.0)
    assert target["box"] == geo["units"][2]["cells"][0]


def test_台本で書き込みと光らせる点を使える():
    from src.script_model import parse_script

    spec = json.dumps(SCATTER, ensure_ascii=False)
    lit = json.dumps(dict(SCATTER, highlight="イゴール・チアゴ"), ensure_ascii=False)
    text = (f"---\ntitle: t\ncards:\n  sc: {spec}\n  sc1: {lit}\n---\n# 見立て\n"
            "キャスター: 1行目\n  card: sc\n  mark: {kind: circle, item: 0}\n"
            "キャスター: 2行目\n  card: sc1\n  mark: {kind: circle, item: 6}\n")
    rows = parse_script(text).to_dict()["scenes"][0]["lines"]
    assert [r["card_type"] for r in rows] == ["scatter", "scatter"]
    assert len(rows[1]["marks"]) == 2                # 光らせる点だけ違う同じ図なので、書き込みは残る
    with pytest.raises(Exception) as err:
        parse_script(text.replace("item: 6", "item: 8"))
    assert "0〜7" in str(err.value)


def test_ショートの強さは数字のカードとして数える():
    from src import shorts
    from src.script_model import Line, Scene

    def score(card):
        line = Line(speaker="キャスター", text="x", card="c" if card else None)
        return shorts.strength(Scene(title="節", lines=[line]), {"c": card} if card else {})

    assert score(SCATTER) == score({"type": "table"}) == score(CONVERT2) > score({"type": "points"})


def test_カードの基準は外貨と円の行に換算を勧める():
    from src.cardrule import suggest

    assert suggest("週給30万ポンド、年俸にすると1560万ポンドです") == "convert"
    assert suggest("移籍金は1億ユーロ、日本円で約174億円") == "convert"
    assert suggest("枠内シュートは8本、期待ゴールは3.16、得点は0でした") == "bars"
    assert suggest("移籍金は1億ユーロでした") == ""


# ------------------------------------------------------------------ 画面に置いた形


@pytest.mark.parametrize("portrait", [False, True])
@pytest.mark.parametrize("spec", [SCATTER, CONVERT3, CONVERT2])
def test_写真の上に置いても画面と見出しの帯の内に収まる(tmp_path, spec, portrait):
    """書き出しと同じ Renderer.frame で描く。板は画面の中・見出しの帯より上に置かれる（字が切れない）。"""
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
    telop = "期待値より多く決めているのは誰か"
    line = Line(speaker="キャスター", text=telop, telop=telop, image=str(photo), card="c")
    renderer.frame(line, Scene(title="見立て", lines=[line]), False, panel=(telop, None, "c"))
    x0, y0, x1, y1 = renderer._card_place[2]
    floor = renderer.headline_band_top(telop, compact=not portrait)
    assert 0 <= x0 and x1 <= config.video.width
    assert y0 >= 0 and y1 <= floor, (y1, floor)
    # 縮めても字が読める大きさ（ショートは板の幅を 0.9 倍より縮めない）
    if portrait:
        assert (x1 - x0) >= config.video.width * 0.7


def test_下見は散らばり図の行も写真だけの絵と比べる(tmp_path):
    """散らばり図は画面いっぱいの絵ではなく板。preview4 は今までどおり顔に板がかかっていないかを見る。"""
    from src.script_model import Line, Scene
    from tools import preview4

    photo = tmp_path / "p.jpg"
    Image.new("RGB", (1600, 900), (100, 100, 100)).save(photo)
    renderer = preview4.PreviewRenderer(load_config(), tmp_path / "work")
    renderer.script_cards = {"sc": SCATTER, "cv": CONVERT2}
    line = Line(speaker="キャスター", text="x", image=str(photo), card="sc")
    scene = Scene(title="節", lines=[line])
    for name in ("sc", "cv"):
        item = renderer.frame(line, scene, False, panel=("", None, name))
        base, exact = renderer.photo_layer(item, [], 0.0)
        assert base is not None and exact, name
