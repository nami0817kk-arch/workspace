"""数字の板・判定表・計算の式・左右の比べ（2026-10-07 に足した4つの型）。

歴史の地層（chiso/numbers.py）と世の中の断面図（charts3〜5・news4）から、こちらの作り
（縦に積むブロック＋reveal で行を出す）に合わせて移した。壊れた例が × になることも見る。
"""
import json

import pytest
from PIL import Image, ImageStat

from src import cards
from src.cards import CardError, render, render_versus, row_count
from src.config import load_config

WIDTH = 1420          # 本編で写真の上に置くときの幅（1920 × 0.74）
PORTRAIT = 972        # ショートの幅（1080 × 0.90）

STATS = {"type": "stats", "title": "メッシの代表",
         "items": [["208", "試合", "代表の出場（歴代最多）"], ["126", "点", "代表の得点"],
                   ["W杯", "優勝", "2022年"]], "focus": 0}
VERDICT = {"type": "verdict", "title": "移籍金1〜5位の答え合わせ",
           "columns": ["選手", "判定", "ここまで"],
           "rows": [["エンソ", "○", "4試合で1点"], ["ロジャーズ", "◎", "7試合で3点4アシスト"],
                    ["アンダーソン", "△", "得点は0"], ["ディオマンデ", "×", "出場時間の41%"]],
           "highlight_row": 1}
CALC = {"type": "calc", "title": "ケインの代表",
        "terms": [["125試合", "代表の出場"], ["11年193日", "デビューから"], ["年10.8試合", "1年あたり"]],
        "ops": ["÷", "＝"]}


@pytest.fixture(scope="module")
def fonts():
    video = load_config().video
    return str(video.font_path()), str(video.latin_font_path())


def _opaque_inside(path) -> bool:
    """板の内側（角と縁を除く）が不透明か。**半透明の塗りを RGBA に直接描くと白く抜ける**（09-28）。"""
    with Image.open(path) as image:
        alpha = image.getchannel("A")
        w, h = image.size
        inner = alpha.crop((cards.RADIUS, cards.RADIUS, w - cards.RADIUS, h - cards.RADIUS))
        return min(inner.getdata()) >= cards.PANEL[3]


def _right_margin_is_empty(path) -> bool:
    """右の余白（PAD の内側）に字がはみ出していないか。明るい画素が無ければ空。"""
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        w, h = rgb.size
        strip = rgb.crop((w - cards.PAD + 10, cards.RADIUS, w - 6, h - cards.RADIUS))
        return max(sum(px) for px in strip.getdata()) < 400


# ------------------------------------------------------------------ stats


def test_数字の板は横幅どおりで中が不透明(tmp_path, fonts):
    font, latin = fonts
    for width in (WIDTH, PORTRAIT):
        path = render(STATS, width, font, tmp_path / f"s{width}.png", latin)
        with Image.open(path) as image:
            assert image.mode == "RGBA" and image.width == width
            assert image.getpixel((2, 2))[3] == 0          # 角は透過
        assert _opaque_inside(path), width
        assert _right_margin_is_empty(path), f"幅{width}で右にはみ出した"


def test_数字の板の注目は黄でほかは白(tmp_path, fonts):
    font, latin = fonts
    path = render(STATS, PORTRAIT, font, tmp_path / "s.png", latin)
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        w = rgb.width
        gold = cards.BRAND_GOLD[:3]

        def has_gold(x0, x1):
            box = rgb.crop((int(x0), 80, int(x1), rgb.height - 40))
            return any(abs(p[0] - gold[0]) < 12 and abs(p[1] - gold[1]) < 12 and abs(p[2] - gold[2]) < 20
                       for p in box.getdata())

        col = (w - cards.PAD * 2 - 12) / 3
        left = cards.PAD + 12
        assert has_gold(left, left + col)                  # focus: 0（208試合）
        assert not has_gold(left + col, left + col * 2)    # 126点は白
        assert not has_gold(left + col * 2, w - cards.PAD)


def test_数字の板は3つまで(tmp_path, fonts):
    font, latin = fonts
    four = dict(STATS, items=STATS["items"] + [["1", "回"]])
    with pytest.raises(CardError):
        render(four, WIDTH, font, tmp_path / "x.png", latin)
    with pytest.raises(CardError):
        render({"type": "stats", "items": []}, WIDTH, font, tmp_path / "y.png", latin)


def test_注目は番号でも字でも指せて無ければ最後():
    assert cards.focus_index({"items": [["1"], ["2"], ["3"]]}, 3) == 2
    assert cards.focus_index({"items": [["1"], ["2"], ["3"]], "focus": 1}, 3) == 1
    assert cards.focus_index({"items": [["208", "試合"], ["126", "点"]], "focus": "126点"}, 2) == 1
    assert cards.focus_index({"items": [["1"], ["2"]], "focus": 9}, 2) == 1


def test_数字は大きく単位は半分():
    segments = cards._segments("年10.8試合")
    assert segments == [("年", cards.UNIT_RATIO), ("10.8", 1.0), ("試合", cards.UNIT_RATIO)]
    # 数字を含まない値（「W杯」）は全体を少し小さく
    assert cards._segments("W杯") == [("W杯", cards.WORD_RATIO)]


# ------------------------------------------------------------------ verdict


def test_判定表は表と同じく1行ずつ出て話している行が光る(tmp_path, fonts):
    font, latin = fonts
    assert row_count(VERDICT) == 4
    full = render(VERDICT, WIDTH, font, tmp_path / "v.png", latin)
    half = render(VERDICT, WIDTH, font, tmp_path / "v2.png", latin, reveal=2)
    with Image.open(full) as a, Image.open(half) as b:
        assert a.size == b.size                 # 出ていない行の場所は空けておく
        assert ImageStat.Stat(a.convert("L")).mean[0] > ImageStat.Stat(b.convert("L")).mean[0]
    assert _opaque_inside(full)
    assert _right_margin_is_empty(full)
    # 光らせる行だけ違うカードは「同じ表」（行を出し直さない）
    from src.render import Renderer
    renderer = Renderer.__new__(Renderer)
    renderer.script_cards = {"a": dict(VERDICT, highlight_row=0), "b": dict(VERDICT, highlight_row=2)}
    assert renderer.same_table("a", "b")


def test_判定表はショートの幅でも右にはみ出さない(tmp_path, fonts):
    font, latin = fonts
    long = dict(VERDICT, rows=[["ディオマンデ（レアル・マドリード）", "×", "出場時間の41%、得点もアシストもまだ0"]] * 3)
    path = render(long, PORTRAIT, font, tmp_path / "v.png", latin)
    assert _right_margin_is_empty(path)


def test_チェックリストの形も描ける(tmp_path, fonts):
    font, latin = fonts
    spec = {"type": "verdict", "title": "記録にある？", "rows": [["本人の発言", "✓"], ["移籍金の額", "✗"]]}
    path = render(spec, PORTRAIT, font, tmp_path / "c.png", latin)
    assert _opaque_inside(path)


def test_判定の字の揺れは寄せる():
    assert cards.verdict_mark("〇") == "○"
    assert cards.verdict_mark("✔") == "✓"
    assert cards.verdict_mark("x") == "×"
    assert cards.verdict_mark("A") == ""


@pytest.mark.parametrize("rows", [
    [["イサク", "A", "8試合6点"]],                       # 知らない判定
    [["イサク", "◎", "8試合6点"], ["ヴィルツ", "△"]],     # 行の長さがばらばら
    [["イサク"]],                                        # 判定が無い
])
def test_壊れた判定表は止める(tmp_path, fonts, rows):
    font, latin = fonts
    with pytest.raises(CardError):
        render({"type": "verdict", "rows": rows}, WIDTH, font, tmp_path / "x.png", latin)


# ------------------------------------------------------------------ calc


def test_計算の式は項が順に出て答えが黄(tmp_path, fonts):
    font, latin = fonts
    assert row_count(CALC) == 3
    for width in (WIDTH, PORTRAIT):
        full = render(CALC, width, font, tmp_path / f"c{width}.png", latin)
        first = render(CALC, width, font, tmp_path / f"c{width}_1.png", latin, reveal=1)
        assert _opaque_inside(full) and _right_margin_is_empty(full), width
        with Image.open(full) as a, Image.open(first) as b:
            assert a.size == b.size
            gold = cards.BRAND_GOLD[:3]
            # 左端の縦帯（同じ黄）は数えない
            count = lambda im: sum(1 for p in im.convert("RGB").crop((20, 0, im.width, im.height)).getdata()
                                   if abs(p[0] - gold[0]) < 10 and abs(p[1] - gold[1]) < 10)
            assert count(a) > 500          # 答えは黄
            assert count(b) == 0           # 1項目だけのときは、まだ答えが出ていない


def test_記号の数が合わない式は止める(tmp_path, fonts):
    font, latin = fonts
    with pytest.raises(CardError):
        render(dict(CALC, ops=["÷"]), WIDTH, font, tmp_path / "x.png", latin)
    with pytest.raises(CardError):
        render({"type": "calc", "terms": [["125試合"]]}, WIDTH, font, tmp_path / "y.png", latin)


# ------------------------------------------------------------------ versus


def _photo(path, shade):
    Image.new("RGB", (800, 1000), (shade, shade, shade)).save(path)
    return str(path)


def test_左右の比べは画面いっぱいの不透明な絵で明るさをそろえる(tmp_path, fonts):
    font, latin = fonts
    dark, bright = _photo(tmp_path / "d.jpg", 40), _photo(tmp_path / "b.jpg", 210)
    spec = {"type": "versus", "title": "代表125試合に届くまで",
            "left": {"image": dark, "name": "ケイン", "number": "11年193日"},
            "right": {"image": bright, "name": "シルトン", "number": "19年224日"}}
    for size in ((1920, 1080), (1080, 1920)):
        out = render_versus(spec, size, font, tmp_path / f"v{size[0]}.png", latin)
        with Image.open(out) as image:
            assert image.size == size
            assert min(image.getchannel("A").getdata()) == 255     # 透ける所が無い
            gray = image.convert("L")
            w, h = size
            # 字の無い上のほう（横は左右の上、縦は上下それぞれの端）の明るさで比べる
            if w > h:
                a = gray.crop((40, 200, w // 2 - 200, 400))
                b = gray.crop((w // 2 + 200, 200, w - 40, 400))
            else:
                a = gray.crop((40, 300, w - 40, 500))
                b = gray.crop((40, h - 300, w - 40, h - 120))
            diff = abs(ImageStat.Stat(a).mean[0] - ImageStat.Stat(b).mean[0])
            assert diff < (210 - 40) * 0.5, f"{size} 明るさの差 {diff:.0f}"


def test_左右の比べは写真と名前が無ければ止める(tmp_path, fonts):
    font, latin = fonts
    with pytest.raises(CardError):
        render_versus({"type": "versus", "left": {"name": "ケイン"}, "right": {"name": "シルトン"}},
                      (1920, 1080), font, tmp_path / "x.png", latin)
    with pytest.raises(CardError):
        render_versus({"type": "versus", "left": {"image": "ない.jpg", "name": "a"},
                       "right": {"image": "ない.jpg", "name": "b"}},
                      (1920, 1080), font, tmp_path / "y.png", latin)


def test_左右の比べは板として描かない(tmp_path, fonts):
    font, latin = fonts
    assert cards.is_full_screen({"type": "versus"})
    assert not cards.is_full_screen({"type": "table"})
    with pytest.raises(CardError):
        render({"type": "versus", "left": {}, "right": {}}, WIDTH, font, tmp_path / "x.png", latin)


def test_左右の比べの行は見出しも節の名前も重ねない(tmp_path):
    """versus は下地そのもの。板と同じく上に何も描かない（名前と数字が画面の字）。"""
    from src.render import Renderer
    from src.script_model import Line, Scene

    config = load_config()
    left, right = _photo(tmp_path / "l.jpg", 90), _photo(tmp_path / "r.jpg", 120)
    renderer = Renderer(config, tmp_path / "work")
    # 画素を1つずつ比べるので、可逆の PNG で保存させる（下地が静止画の回の途中の画像は JPEG。2026-10-08）
    renderer.over_video = True
    spec = {"type": "versus", "left": {"image": left, "name": "ケイン", "number": "125試合"},
            "right": {"image": right, "name": "シルトン", "number": "125試合"}}
    renderer.script_cards = {"vs": spec}
    line = Line(speaker="キャスター", text="ケインとシルトン。", telop="ケインとシルトン。", card="vs")
    scene = Scene(title="2人の比べ", lines=[line])
    frame = renderer.frame(line, scene, mouth_open=False)
    alone = render_versus(spec, (config.video.width, config.video.height),
                          str(config.video.font_path()), tmp_path / "alone.png",
                          str(config.video.latin_font_path()))
    with Image.open(frame) as a, Image.open(alone) as b:
        # 見出しの帯・節の名前が乗っていれば、下のほう・左上が変わる
        assert list(a.convert("RGB").crop((0, 0, 400, 140)).getdata()) == \
            list(b.convert("RGB").crop((0, 0, 400, 140)).getdata())
        assert list(a.convert("RGB").crop((0, 900, 1920, 1080)).getdata()) == \
            list(b.convert("RGB").crop((0, 900, 1920, 1080)).getdata())


def test_左右の比べの行は画面に出る字に数える(tmp_path):
    from src.review import _telop_coverage

    path = tmp_path / "script.json"
    path.write_text(json.dumps({"scenes": [{"lines": [
        {"text": "あ" * 30, "telop": "あ" * 30},
        {"text": "い" * 40, "telop": "", "card": "vs", "card_type": "versus"},
    ]}]}, ensure_ascii=False), encoding="utf-8")
    assert _telop_coverage(path).ok
    # 型が無ければ、同じ行は声だけに数える（壊れたときに × になる）
    path.write_text(json.dumps({"scenes": [{"lines": [
        {"text": "あ" * 30, "telop": "あ" * 30},
        {"text": "い" * 40, "telop": "", "card": "vs"},
    ]}]}, ensure_ascii=False), encoding="utf-8")
    assert not _telop_coverage(path).ok


def test_台本の記録にカードの型が残る():
    from src.script_model import parse_script

    text = ("---\ntitle: t\ncards:\n  vs: {type: versus, left: {image: a.jpg, name: a}, "
            "right: {image: b.jpg, name: b}}\n  t: {type: verdict, rows: [[a, ◎]]}\n---\n"
            "# 節\nキャスター: 1行目\n  card: vs\nキャスター: 2行目\n  card: t\nキャスター: 3行目\n")
    rows = parse_script(text).to_dict()["scenes"][0]["lines"]
    assert [r["card_type"] for r in rows] == ["versus", "verdict", "verdict"]


def test_下見は左右の比べの行で顔に板が掛かったと言わない(tmp_path):
    """preview4 は写真だけの絵とコマの差で「顔に板」を見る。versus は全面が違うので、板と同じく外す。"""
    from src.script_model import Line, Scene
    from tools import preview4

    photo = _photo(tmp_path / "p.jpg", 100)
    renderer = preview4.PreviewRenderer(load_config(), tmp_path / "work")
    renderer.script_cards = {"vs": {"type": "versus", "left": {"image": photo, "name": "a"},
                                    "right": {"image": photo, "name": "b"}},
                             "t": {"type": "table", "columns": ["a"], "rows": [["1"]]}}
    line = Line(speaker="キャスター", text="x", image=photo, card="vs")
    scene = Scene(title="節", lines=[line])
    item = renderer.frame(line, scene, False, panel=("", None, "vs"))
    assert renderer.photo_layer(item, [], 0.0) == (None, False)
    # ふつうの表の行は今までどおり写真だけの絵と比べる
    item = renderer.frame(line, scene, False, panel=("", None, "t"))
    base, exact = renderer.photo_layer(item, [], 0.0)
    assert base is not None and exact
