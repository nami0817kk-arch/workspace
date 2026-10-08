"""折れ線（line）・増減の内訳（waterfall）・年表（timeline）。2026-10-08。

別チャンネル（世の中の断面図 charts2.line / charts2.waterfall / charts4.schedule）から、
こちらの作り（縦に積むブロック＋`reveal`）に合わせて移した。壊れた例（点9つ・数でない値・
知らない鍵・知らない focus）が止まること、1つずつ出ること、光らせても開き直さないこと、
本編（1420）とショート（972）のどちらでも枠からはみ出さず字が28px を切らないことを見る。
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
MIN_PX = 28           # これより小さい字は作らない（断面図の typo.py。スマホで 5.7pt）

# 見本と同じ並び（デロイトのフットボール・マネー・リーグ、百万ユーロ）
LINE = {"type": "line", "title": "収益の5年", "x": [2021, 2022, 2023, 2024, 2025],
        "series": [["バルセロナ", [631, 638, 800, 859, 1045]],
                   ["レアル・マドリード", [653, 714, 831, 843, 1046]]],
        "unit": "百万ユーロ", "focus": "バルセロナ", "highlight": 2023,
        "note": "デロイトのフットボール・マネー・リーグ（収益、移籍金を除く）", "source": "Deloitte"}
WATERFALL = {"type": "waterfall", "title": "移籍金の中身", "start": ["固定", 7500],
             "steps": [["出場ボーナス", 1500], ["再売却の歩合", -500]],
             "total": ["合計", 8500], "unit": "万ユーロ"}
TIMELINE = {"type": "timeline", "title": "エンブレムの変遷",
            "rows": [["1899", "創立。市の紋章をそのまま使う"], ["1910", "盾の形に。公募で決まった"],
                     ["2002", "外周の文字を外した"], ["2026", "線を細くし、色を1つ減らした"]],
            "focus": "2002", "source": "クラブ公式"}


@pytest.fixture(scope="module")
def fonts():
    video = load_config().video
    return str(video.font_path()), str(video.latin_font_path())


def _opaque_inside(path) -> bool:
    """板の中が透けていないか（半透明の塗りを RGBA に直接描くと白く抜ける）。"""
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


def _gold(image) -> int:
    rgb = image.convert("RGB")
    gold = cards.BRAND_GOLD[:3]
    return sum(1 for p in rgb.crop((20, 0, rgb.width, rgb.height)).getdata()
               if abs(p[0] - gold[0]) < 12 and abs(p[1] - gold[1]) < 12 and abs(p[2] - gold[2]) < 24)


def _mean(image) -> float:
    return ImageStat.Stat(image.convert("L")).mean[0]


def _overlap(a, b) -> bool:
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


ALL = [LINE, WATERFALL, TIMELINE]


# ------------------------------------------------------------------ 3つに共通


@pytest.mark.parametrize("width", [WIDTH, PHOTO, PORTRAIT])
@pytest.mark.parametrize("spec", ALL, ids=lambda s: s["type"])
def test_板は不透明で枠からはみ出さない(tmp_path, fonts, spec, width):
    path = render(spec, width, fonts[0], tmp_path / f"c{width}.png", fonts[1])
    with Image.open(path) as image:
        assert image.mode == "RGBA" and image.width == width
        assert image.getpixel((2, 2))[3] == 0          # 角は透過（丸い板）
    assert _opaque_inside(path), (spec["type"], width)
    assert _right_margin_is_empty(path), f"{spec['type']} が幅{width}で右にはみ出した"


@pytest.mark.parametrize("width", [WIDTH, PHOTO, PORTRAIT])
@pytest.mark.parametrize("spec", ALL, ids=lambda s: s["type"])
def test_項目は1つずつ出て_出ていない場所も空けておく(tmp_path, fonts, spec, width):
    """`reveal` で1つずつ。軸・目盛り・行の場所は動かない（表が開き直して見えない）。"""
    count = row_count(spec)
    assert count == cards.mark_units(spec) >= 3
    full = render(spec, width, fonts[0], tmp_path / "a.png", fonts[1])
    none = render(spec, width, fonts[0], tmp_path / "b.png", fonts[1], reveal=0)
    half = render(spec, width, fonts[0], tmp_path / "c.png", fonts[1], reveal=count - 1)
    with Image.open(full) as a, Image.open(none) as b, Image.open(half) as c:
        assert a.size == b.size == c.size, spec["type"]
        assert _mean(b) < _mean(c) < _mean(a), spec["type"]


@pytest.mark.parametrize("spec", ALL, ids=lambda s: s["type"])
def test_項目は上から下へ_または左から右へ並ぶ(fonts, spec):
    geo = cards.layout(spec, PORTRAIT, *fonts)
    boxes = [u["box"] for u in geo["units"]]
    width, height = geo["size"]
    for box in boxes:
        assert 0 <= box[0] and box[2] <= width and 0 <= box[1] and box[3] <= height, (spec["type"], box)
    if spec["type"] == "line":
        assert all(a[2] <= b[0] + 1 for a, b in zip(boxes, boxes[1:]))     # 左から右へ
    else:
        assert all(a[3] <= b[1] + 1 for a, b in zip(boxes, boxes[1:]))     # 上から下へ


@pytest.mark.parametrize("spec", ALL, ids=lambda s: s["type"])
def test_字を小さくしない(fonts, spec):
    """注記の枠の高さから、いちばん小さい字が 28px を割っていないかを見る。"""
    geo = cards.layout(spec, PORTRAIT, *fonts)
    for unit in geo["units"]:
        for box in unit["cells"]:
            if box and box[3] - box[1] > 0:
                assert box[3] - box[1] >= MIN_PX * 0.7, (spec["type"], box)


# ------------------------------------------------------------------ 折れ線


def test_折れ線は主役だけ黄で_値も主役だけ出す(tmp_path, fonts):
    assert row_count(LINE) == 5
    full = render(LINE, PORTRAIT, fonts[0], tmp_path / "a.png", fonts[1])
    axes = render(LINE, PORTRAIT, fonts[0], tmp_path / "b.png", fonts[1], reveal=0)
    with Image.open(full) as a, Image.open(axes) as b:
        assert _gold(a) > 2000              # 主役の線・値・話している位置の縦線
        assert _gold(b) < _gold(a) / 4      # 軸と話している位置の札だけ（線はまだ無い）
    # 主役を替えると黄になる線が替わる（値の札も替わる）
    other = render(dict(LINE, focus="レアル・マドリード"), PORTRAIT, fonts[0], tmp_path / "c.png", fonts[1])
    with Image.open(other) as c, Image.open(full) as a:
        assert c.tobytes() != a.tobytes()


def test_折れ線は1本でも凡例なしで描ける(tmp_path, fonts):
    one = {"type": "line", "title": "得点の推移", "x": ["1節", "2節", "3節", "4節"],
           "series": [["ハーランド", [1, 3, 4, 7]]], "unit": "得点（通算）"}
    assert cards.check_line(one) == []
    tall = render(one, WIDTH, fonts[0], tmp_path / "a.png", fonts[1])
    two = render(dict(one, series=one["series"] + [["イサク", [0, 1, 3, 4]]]),
                 WIDTH, fonts[0], tmp_path / "b.png", fonts[1])
    with Image.open(tall) as a, Image.open(two) as b:
        assert b.height - a.height == 44          # 凡例の1行ぶんだけ高い


def test_折れ線の縦軸は0から始めなくてよいが印を出す(tmp_path, fonts):
    """推移が潰れるので 0 から始めない。始めなかったら斜線2本と破線の目盛りで知らせる。"""
    assert cards._line_range([631, 1045])[0] > 0        # 低いほうが高いほうの1/4を超える
    assert cards._line_range([1, 14])[0] == 0           # 0 に近ければ 0 から
    ticks = cards.nice_ticks(*cards._line_range([631, 1046]))
    assert ticks[0] > 0 and ticks[0] <= 631 and ticks[-1] >= 1046
    # 印（斜線）は 0 から始めた図には出ない
    zero = dict(LINE, series=[["ハーランド", [1, 3, 4, 7, 9]]], focus=None, highlight=None)
    a = render(LINE, WIDTH, fonts[0], tmp_path / "a.png", fonts[1])
    b = render(zero, WIDTH, fonts[0], tmp_path / "b.png", fonts[1])
    strip = lambda p: Image.open(p).convert("L").crop((80, 0, 200, Image.open(p).height))
    assert _mean(strip(a)) != _mean(strip(b))


def test_折れ線の軸の札は隣とぶつかるなら間引く(fonts):
    """札が重なるくらい詰まったら、1つおきにする。**縮めて入れない**（28px を割る）。"""
    def ticks(spec, width):
        return [u["cells"][2] for u in cards.layout(spec, width, *fonts)["units"]]

    eight = dict(LINE, x=[2018 + k for k in range(8)], highlight=None,
                 series=[["バルセロナ", [600 + k * 50 for k in range(8)]]])
    assert cards.check_line(eight) == []
    for width in (WIDTH, PHOTO, PORTRAIT):
        shown = [t for t in ticks(eight, width) if t]
        assert len(shown) == 8, (width, len(shown))       # 4桁の年8つはショートでも入る
        for a, b in zip(shown, shown[1:]):
            assert not _overlap(a, b), (width, a, b)
    # 長い札（節と相手）はショートでは入らないので間引く。両端は必ず残す
    long_x = dict(eight, x=[f"第{k + 1}節・{'ホーム' if k % 2 else 'アウェー'}" for k in range(8)])
    shown = [t for t in ticks(long_x, PORTRAIT) if t]
    assert 2 <= len(shown) < 8, len(shown)
    for a, b in zip(shown, shown[1:]):
        assert not _overlap(a, b), (a, b)
    assert ticks(long_x, PORTRAIT)[0] and ticks(long_x, PORTRAIT)[-1]


def test_話している位置を光らせても開き直さない(fonts):
    a = dict(LINE, highlight=2024)
    b = dict(LINE, highlight=3)
    assert cards.same_table(a, LINE) and cards.same_table(a, b)
    assert not cards.same_table(a, dict(LINE, focus="レアル・マドリード"))
    assert [u["cells"][0] for u in cards.layout(a, PORTRAIT, *fonts)["units"]] != \
        [u["cells"][0] for u in cards.layout(LINE, PORTRAIT, *fonts)["units"]]   # 点は大きくなる
    assert cards.layout(a, PORTRAIT, *fonts)["size"] == cards.layout(LINE, PORTRAIT, *fonts)["size"]


@pytest.mark.parametrize("spec, words", [
    (dict(LINE, x=[2018 + k for k in range(9)]), "8つまで"),
    (dict(LINE, series=[[f"club{i}", [1, 2, 3, 4, 5]] for i in range(4)]), "3本まで"),
    (dict(LINE, series=[["バルセロナ", [631, "638点", 800, 859, 1045]]]), "数だけ"),
    (dict(LINE, series=[["バルセロナ", [631, 638, 800]]]), "同じ数"),
    (dict(LINE, series=[["バルセロナ"]]), "[名前, [数, …]]"),
    (dict(LINE, x=[2021]), "2つ以上"),
    (dict(LINE, serie=[]), "知らない鍵"),
    (dict(LINE, focus="アトレティコ"), "focus"),
    (dict(LINE, highlight=1999), "highlight"),
    (dict(LINE, series=[["バルサ", [1, 2, 3, 4, 5]], ["バルサ", [1, 2, 3, 4, 5]]]), "重なって"),
])
def test_壊れた折れ線は止める(tmp_path, fonts, spec, words):
    problems = cards.check_line(spec)
    assert problems and any(words in p for p in problems), problems
    with pytest.raises(CardError):
        render(spec, WIDTH, fonts[0], tmp_path / "x.png", fonts[1])


# ------------------------------------------------------------------ 増減の内訳


def test_増減は段が前の段の先から始まり_合計だけ黄(tmp_path, fonts):
    assert row_count(WATERFALL) == 4             # もと・2段・合計
    rows = cards.waterfall_rows(WATERFALL)
    assert [r["kind"] for r in rows] == ["base", "up", "down", "total"]
    full = render(WATERFALL, WIDTH, fonts[0], tmp_path / "a.png", fonts[1])
    without = render(WATERFALL, WIDTH, fonts[0], tmp_path / "b.png", fonts[1], reveal=3)
    with Image.open(full) as a, Image.open(without) as b:
        assert _gold(a) > 3000 and _gold(b) < _gold(a) / 3     # 合計の棒と字が黄


def test_合計を書かなければ足し算で埋める():
    auto = {k: v for k, v in WATERFALL.items() if k != "total"}
    rows = cards.waterfall_rows(auto)
    assert rows[-1]["name"] == "合計" and rows[-1]["value"] == 8500
    assert cards.check_waterfall(auto) == []
    assert cards.waterfall_mismatch(auto) == ""          # 自分で埋めた値はずれない


def test_合計が足し算と合わなければ知らせるが止めない():
    wrong = dict(WATERFALL, total=["合計", 9000])
    assert cards.check_waterfall(wrong) == []            # 止めない
    assert "8500" in cards.waterfall_mismatch(wrong) and "9000" in cards.waterfall_mismatch(wrong)
    assert cards.waterfall_mismatch(WATERFALL) == ""


def test_もとが無くても描ける(tmp_path, fonts):
    """収入の内訳のように 0 から積む形。"""
    spec = {"type": "waterfall", "title": "収入の内訳", "unit": "百万ユーロ",
            "steps": [["放映権", 300], ["試合日", 180], ["商業", 420]]}
    assert cards.check_waterfall(spec) == []
    assert row_count(spec) == 4                 # 3段＋合計
    assert cards.waterfall_rows(spec)[-1]["value"] == 900
    path = render(spec, PORTRAIT, fonts[0], tmp_path / "a.png", fonts[1])
    assert _opaque_inside(path) and _right_margin_is_empty(path)


def test_段を光らせても開き直さない(fonts):
    a = dict(WATERFALL, highlight="出場ボーナス")
    b = dict(WATERFALL, highlight=1)
    assert cards.same_table(a, b) and cards.same_table(a, WATERFALL)
    assert [u["cells"] for u in cards.layout(a, WIDTH, *fonts)["units"]] == \
        [u["cells"] for u in cards.layout(WATERFALL, WIDTH, *fonts)["units"]]


@pytest.mark.parametrize("spec, words", [
    (dict(WATERFALL, steps=[[f"段{i}", 100] for i in range(7)], total=None), "6段まで"),
    (dict(WATERFALL, steps=[["ボーナス", "1500万"]]), "数だけ"),
    (dict(WATERFALL, steps=[]), "steps"),
    (dict(WATERFALL, start=["固定"]), "start"),
    (dict(WATERFALL, base=["固定", 7500]), "知らない鍵"),
    (dict(WATERFALL, highlight="広告料"), "highlight"),
    (dict(WATERFALL, start=["合計", 7500]), "重なって"),
])
def test_壊れた増減は止める(tmp_path, fonts, spec, words):
    spec = {k: v for k, v in spec.items() if v is not None}
    problems = cards.check_waterfall(spec)
    assert problems and any(words in p for p in problems), problems
    with pytest.raises(CardError):
        render(spec, WIDTH, fonts[0], tmp_path / "x.png", fonts[1])


# ------------------------------------------------------------------ 年表


def test_年表は線が1行ずつ伸びて注目だけ黄(tmp_path, fonts):
    assert row_count(TIMELINE) == 4
    full = render(TIMELINE, WIDTH, fonts[0], tmp_path / "a.png", fonts[1])
    one = render(TIMELINE, WIDTH, fonts[0], tmp_path / "b.png", fonts[1], reveal=1)
    with Image.open(full) as a, Image.open(one) as b:
        assert a.size == b.size
        assert _gold(a) > 600                   # 2002 の点・輪・年が黄
        assert _gold(b) == 0                    # 1行目は注目ではないので黄は無い
    plain = render({k: v for k, v in TIMELINE.items() if k != "focus"},
                   WIDTH, fonts[0], tmp_path / "c.png", fonts[1])
    with Image.open(plain) as c:
        assert _gold(c) == 0                    # focus を書かなければ黄は無い


def test_年表の行は年でも番号でも指せる(fonts):
    years = [r[0] for r in TIMELINE["rows"]]
    assert cards._pick_by_name("2002", years) == 2
    assert cards._pick_by_name(2002, years) == 2        # 年を数で書いても番号と読み違えない
    assert cards._pick_by_name(1, years) == 1           # 行の数より小さい数は番号
    assert cards._pick_by_name(None, years) is None
    assert cards._pick_by_name("1950", years) == -1


def test_年表は行が多いと縦に詰める(fonts):
    six = dict(TIMELINE, rows=[[str(1900 + k * 20), f"できごと{k}"] for k in range(6)], focus=None)
    six = {k: v for k, v in six.items() if v is not None}
    assert cards.check_timeline(six) == []
    four = cards.layout(TIMELINE, PORTRAIT, *fonts)["size"][1]
    many = cards.layout(six, PORTRAIT, *fonts)["size"][1]
    assert many / 6 < four / 4, "行が増えても1行の高さが変わっていない"


def test_話している行を光らせても開き直さない(fonts):
    a = dict(TIMELINE, highlight_row="1910")
    b = dict(TIMELINE, highlight_row=1)
    assert cards.same_table(a, b) and cards.same_table(a, TIMELINE)
    assert [u["cells"] for u in cards.layout(a, PORTRAIT, *fonts)["units"]] == \
        [u["cells"] for u in cards.layout(TIMELINE, PORTRAIT, *fonts)["units"]]


@pytest.mark.parametrize("spec, words", [
    (dict(TIMELINE, rows=[[str(1900 + k), f"x{k}"] for k in range(7)]), "6行まで"),
    (dict(TIMELINE, rows=[["1899", "創立", "注記"], ["1910", "盾"]]), "[年, できごと]"),
    (dict(TIMELINE, rows=[["1899", ""], ["1910", "盾"]]), "[年, できごと]"),
    (dict(TIMELINE, rows=[["1899", "創立"]]), "2行以上"),
    (dict(TIMELINE, row=[]), "知らない鍵"),
    (dict(TIMELINE, focus="1950"), "focus"),
    (dict(TIMELINE, highlight_row="1950"), "highlight_row"),
    (dict(TIMELINE, rows=[["1899", "創立"], ["1899", "もう一度"]]), "重なって"),
])
def test_壊れた年表は止める(tmp_path, fonts, spec, words):
    problems = cards.check_timeline(spec)
    assert problems and any(words in p for p in problems), problems
    with pytest.raises(CardError):
        render(spec, WIDTH, fonts[0], tmp_path / "x.png", fonts[1])


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

    for card in ALL + [dict(LINE, highlight=2021), dict(TIMELINE, highlight_row=0)]:
        assert _check_card(_section(card)) == [], card["title"]
    nine = dict(LINE, x=[2018 + k for k in range(9)],
                series=[["バルセロナ", [600 + k for k in range(9)]]])
    assert any("8つまで" in p for p in _check_card(_section(nine)))
    assert any("知らない鍵" in p for p in _check_card(_section(dict(WATERFALL, steps_=[]))))
    assert any("6行まで" in p for p in
               _check_card(_section(dict(TIMELINE, rows=[[str(1900 + k), "x"] for k in range(7)]))))
    # 行ごとのカード（話している段を光らせる形）も見る
    bad = dict(WATERFALL, highlight="広告料")
    assert any("highlight" in p for p in _check_card(_section(None, line_cards=[bad, None], say=["a", "b"])))


def test_増減のずれは_draftが知らせるが止めない():
    from src.research import Notes, _advise_waterfall_math, _check_card

    wrong = dict(WATERFALL, total=["合計", 9000])
    section = _section(wrong, heading="移籍金の中身")
    assert _check_card(section) == []
    hints = _advise_waterfall_math(Notes(date="2026-10-08", title="t", question="", sections=[section]))
    assert len(hints) == 1 and "移籍金の中身" in hints[0] and "8500" in hints[0]
    ok = _section(WATERFALL)
    assert _advise_waterfall_math(Notes(date="2026-10-08", title="t", question="", sections=[ok])) == []


def test_見立ての節の表に数える():
    from src.research import _has_count_table

    for card in ALL:
        assert _has_count_table(_section(card)), card["type"]


def test_背の高い図は長いテロップとぶつかると知らせる():
    from src.research import Notes, _advise_card_telop_overlap

    for spec, word in ((LINE, "折れ線"), (TIMELINE, "年表"), (WATERFALL, "増減の内訳")):
        section = _section(spec, say=["あ" * 45, "い"])
        hints = _advise_card_telop_overlap(Notes(date="2026-10-08", title="t", question="",
                                                 sections=[section]))
        assert hints and word in hints[0], (spec["type"], hints)


def test_書き込みは点と段と行を番号で指す():
    assert cards.mark_units(LINE) == 5
    assert cards.mark_units(WATERFALL) == 4 and cards.mark_units(TIMELINE) == 4
    assert marks.check_target({"kind": "circle", "item": 4}, LINE) == []
    assert "0〜4" in marks.check_target({"kind": "circle", "item": 5}, LINE)[0]
    assert marks.check_target({"kind": "circle", "item": 2, "col": "年"}, LINE) == []
    assert marks.check_target({"kind": "underline", "item": 1, "col": "値"}, WATERFALL) == []
    assert marks.check_target({"kind": "strike", "row": 0, "col": "できごと"}, TIMELINE) == []
    assert "行は 0〜3" in marks.check_target({"kind": "circle", "row": 4}, TIMELINE)[0]
    assert "列『判定』はありません" in marks.check_target({"kind": "circle", "item": 0, "col": "判定"}, LINE)[0]


def test_書き込みの丸は指さなければ点そのもの(fonts):
    geo = cards.layout(LINE, PORTRAIT, *fonts)
    target = marks.card_target({"kind": "circle", "item": 2}, LINE, geo, (0, 0), 1.0)
    assert target["box"] == geo["units"][2]["cells"][0]
    named = marks.card_target({"kind": "circle", "item": 2, "col": "値"}, LINE, geo, (0, 0), 1.0)
    assert named["box"] == geo["units"][2]["cells"][1]
    # 年表・増減は行まるごと（表と同じ）
    geo = cards.layout(TIMELINE, PORTRAIT, *fonts)
    target = marks.card_target({"kind": "circle", "row": 2}, TIMELINE, geo, (0, 0), 1.0)
    assert target["box"] == geo["units"][2]["text"]


def test_台本で書き込みと光らせる行を使える():
    from src.script_model import parse_script

    spec = json.dumps(TIMELINE, ensure_ascii=False)
    lit = json.dumps(dict(TIMELINE, highlight_row=2), ensure_ascii=False)
    text = (f"---\ntitle: t\ncards:\n  tl: {spec}\n  tl1: {lit}\n---\n# 見立て\n"
            "キャスター: 1行目\n  card: tl\n  mark: {kind: circle, row: 0}\n"
            "キャスター: 2行目\n  card: tl1\n  mark: {kind: underline, row: 3}\n")
    rows = parse_script(text).to_dict()["scenes"][0]["lines"]
    assert [r["card_type"] for r in rows] == ["timeline", "timeline"]
    assert len(rows[1]["marks"]) == 2          # 光らせる行だけ違う同じ年表なので、書き込みは残る
    with pytest.raises(Exception) as err:
        parse_script(text.replace("row: 3", "row: 9"))
    assert "0〜3" in str(err.value)


def test_カードの基準は年と内訳の行に勧める():
    from src.cardrule import suggest

    assert suggest("2021年は631、2023年は800、2025年は1045まで伸びました") == "line"
    assert suggest("1899年に創立し、1910年に盾の形になり、2002年に文字を外しました") == "timeline"
    assert suggest("移籍金の内訳は、固定が7500万、ボーナスが1500万です") == "waterfall"
    assert suggest("収入900のうち、放映権が300、商業が420です") == "waterfall"
    # 既にある基準は変わらない
    assert suggest("枠内シュートは8本、期待ゴールは3.16、得点は0でした") == "bars"
    assert suggest("6分にヤマル、22分にロペス、50分にラフィーニャが決めています") == "table"
    assert suggest("前半は2点、後半は3点で、合計5点") == "bars"
    assert suggest("週給30万ポンド、年俸にすると1560万ポンドです") == "convert"


def test_ショートの強さは数字のカードとして数える():
    from src import shorts
    from src.script_model import Line, Scene

    def score(card):
        line = Line(speaker="キャスター", text="x", card="c" if card else None)
        return shorts.strength(Scene(title="節", lines=[line]), {"c": card} if card else {})

    # shorts.strength の一覧には入れていない（別の作業が同じファイルを触っている）。
    # カードがあること自体は数えるので、カードの無い節よりは強い
    for spec in ALL:
        assert score(spec) > score(None), spec["type"]


# ------------------------------------------------------------------ 画面に置いた形


@pytest.mark.parametrize("portrait", [False, True])
@pytest.mark.parametrize("spec", ALL, ids=lambda s: s["type"])
def test_写真の上に置いても画面と見出しの帯の内に収まる(tmp_path, spec, portrait):
    """書き出しと同じ Renderer.frame で描く。板は画面の中・見出しの帯より上に置かれる。"""
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
    telop = "この5年で、何がどれだけ変わったのか"
    line = Line(speaker="キャスター", text=telop, telop=telop, image=str(photo), card="c")
    renderer.frame(line, Scene(title="見立て", lines=[line]), False, panel=(telop, None, "c"))
    x0, y0, x1, y1 = renderer._card_place[2]
    floor = renderer.headline_band_top(telop, compact=not portrait)
    assert 0 <= x0 and x1 <= config.video.width, spec["type"]
    assert y0 >= 0 and y1 <= floor, (spec["type"], y1, floor)
    if portrait:
        assert (x1 - x0) >= config.video.width * 0.7
