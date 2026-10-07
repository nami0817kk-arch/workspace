"""世の中の断面図から移した道具（10-07）：1項目ずつ増える図（upto）・数字の図4種・つむぎの寄り・左右の全画面比べ。

CI には日本語フォントも素材も無いので、Pillow の内蔵フォントと、その場で作った絵で描いて確かめる。
"""
from types import SimpleNamespace as NS

import json

import pytest
from PIL import Image, ImageChops, ImageFont

from chiso import check, figures, render, script, sfx


class FakePainter(render.Painter):
    """フォントだけ Pillow の内蔵のものに差し替えた Painter（字形は豆腐でも位置と大きさは測れる）。"""
    def font(self, kind, size, bold=False):
        return ImageFont.load_default(size)


def _config():
    return {"cast": {"語り": {"name": "剣崎雌雄", "image": "k.png", "side": "left"},
                     "聞き": {"name": "春日部つむぎ", "image": "t.png", "side": "right"}},
            "subtitles": True}


def _painter(tmp_path, sc=None):
    for name, color in (("k.png", (90, 110, 160, 255)), ("t.png", (220, 150, 50, 255)),
                        ("a.png", (200, 200, 200, 255)), ("b.png", (30, 30, 30, 255))):
        im = Image.new("RGBA", (300, 900), (0, 0, 0, 0))
        im.paste(Image.new("RGBA", (200, 860), color), (50, 20))
        im.save(tmp_path / name)
    sc = sc or script.parse({"title": "t", "sections": [{"title": "一", "lines": [{"語り": "a"}]}]})
    return FakePainter(_config(), sc, tmp_path, (1920, 1080))


def _fig_lines(*figs):
    lines = [{"語り": f"行{i}", "figure": f} for i, f in enumerate(figs)]
    return script.parse({"title": "t", "sections": [{"title": "一", "lines": lines}]}).lines


BARS = {"type": "bars", "title": "兵の数", "bars": [["桶狭間", 2000], ["長篠", 30000], ["本能寺", 100]]}


# --- 1. 1項目ずつ増える図 ----------------------------------------------------------
def test_upto_steps_get_grow_from():
    ls = _fig_lines(dict(BARS, upto=1), dict(BARS, upto=2), dict(BARS, upto=3), dict(BARS, upto=3))
    got = [json.loads(l.figure).get("grow_from") for l in ls]
    assert got == [None, 1, 2, 2]
    assert ls[2].figure == ls[3].figure          # 同じ upto を書き直しただけなら、描き直さない（同じ図のまま）


def test_upto_on_a_different_figure_starts_over():
    other = dict(BARS, title="別の図", upto=2)
    ls = _fig_lines(dict(BARS, upto=1), other)
    assert "grow_from" not in json.loads(ls[1].figure)


def test_no_upto_keeps_the_figure_as_written():
    ls = _fig_lines(BARS, BARS)
    assert ls[0].figure == ls[1].figure and "grow_from" not in ls[0].figure


@pytest.mark.parametrize("bad", [0, -1, "2", 1.5])
def test_upto_must_be_positive_int(bad):
    with pytest.raises(script.ScriptError):
        _fig_lines(dict(BARS, upto=bad))


def test_grow_from_is_not_written_by_hand():
    with pytest.raises(script.ScriptError):
        _fig_lines(dict(BARS, upto=2, grow_from=1))


def test_grow_and_steps():
    assert figures._grow({}, 4) == (0, 4)
    assert figures._grow({"upto": 2}, 4) == (0, 2)
    assert figures._grow({"upto": 9, "grow_from": 3}, 4) == (3, 4)
    assert figures._steps(0.0, 1, 3) == [1.0, 0.0, 0.0]          # 前からある項目は描き終えたまま
    assert figures._steps(1.0, 1, 3) == [1.0, 1.0, 1.0]
    assert figures.base_key(dict(BARS, upto=1)) == figures.base_key(dict(BARS, upto=3, grow_from=1))


def _draw(p, spec, t):
    canvas = Image.new("RGBA", (1920, 1080), (0, 0, 0, 0))
    return figures.draw(p, canvas, spec, t)


def _diff_box(a, b):
    return ImageChops.difference(a, b).getbbox()


def test_upto_n_looks_the_same_as_no_upto(tmp_path):
    """upto に全部の数を書いた図は、upto を書かない図と同じ絵（既存の5本の見た目を変えない）。"""
    p = _painter(tmp_path)
    people = {"type": "people", "title": "関係", "nodes": [["A", "a"], ["B", "b"], ["C", "c"]],
              "edges": [["A", "B", "x"], ["B", "C", "y"]], "cross": ["C"]}
    for spec in (BARS, people):
        for t in (0.2, 0.6, 1.0):
            assert _diff_box(_draw(p, spec, t), _draw(p, dict(spec, upto=3), t)) is None


def test_only_the_new_bar_moves(tmp_path):
    p = _painter(tmp_path)
    grow = dict(BARS, upto=2, grow_from=1)
    still = dict(BARS, upto=1)
    ay0 = figures.PANEL[1] + 18 + 58                       # 題の下
    row = (figures.PANEL[3] - 24 - ay0) / 3
    for t in (0.2, 0.5, 1.0):
        box = _diff_box(_draw(p, grow, t), _draw(p, still, 1.0))
        assert box is not None and box[1] >= ay0 + row * 0.8     # 1本目の行は動かない
        assert box[3] <= ay0 + row * 2                          # 3本目はまだ出ない


def test_growth_step_animates_without_whoosh(tmp_path):
    ls = _fig_lines(dict(BARS, upto=1), dict(BARS, upto=2))
    cues = [NS(line=ls[0], start=0.0, end=2.0), NS(line=ls[1], start=2.2, end=4.0)]
    evs = sfx.events(cues)
    assert [n for _, n in evs].count("whoosh") == 1          # 図が出たときの1回だけ


def test_growth_counts_as_one_figure_but_as_new_on_screen():
    data = {"title": "t", "sections": [{"title": "一", "lines": [
        {"語り": "あ" * 80, "figure": dict(BARS, upto=k)} for k in (1, 2, 3)] * 2}]}
    sc = script.parse(data)
    figs = {figures.base_key(l.figure) for l in sc.lines if l.figure}
    assert len(figs) == 1
    assert not [w for w in check.pacing(sc) if "新しいもの" in w]


# --- 2. 数字の図 ------------------------------------------------------------------
NUMBER_FIGS = [
    {"type": "stats", "title": "数字", "items": [["生涯", "49年", "満"], ["元服", "13歳"], ["石高", "約700万石"]]},
    {"type": "calc", "title": "式", "terms": [["200km", "距離"], ["7日"], ["約29km/日", "1日あたり"]], "ops": ["÷", "＝"]},
    {"type": "numberline", "title": "享年", "items": [["A", 48], ["B", 61], ["C", 73]], "unit": "歳", "focus": "A"},
    {"type": "line", "title": "石高", "points": [["1560", 57], ["1568", 120], ["1582", 700]], "unit": "万石",
     "note": "目安"},
]


@pytest.mark.parametrize("spec", NUMBER_FIGS, ids=lambda s: s["type"])
def test_number_figures_draw_and_keep_alpha(tmp_path, spec):
    p = _painter(tmp_path)
    sc = _fig_lines(spec)
    assert json.loads(sc[0].figure)["type"] == spec["type"]
    half, done = _draw(p, spec, 0.5), _draw(p, spec, 1.0)
    assert half.mode == done.mode == "RGBA"
    assert done.getpixel((5, 5))[3] == 0                    # 板の外は透明のまま（断面図の finish は落としていた）
    assert _diff_box(half, done) is not None                 # 途中と完成で違う（描き進む）


@pytest.mark.parametrize("spec", NUMBER_FIGS, ids=lambda s: s["type"])
def test_number_figures_grow_one_by_one(tmp_path, spec):
    p = _painter(tmp_path)
    one, two = _draw(p, dict(spec, upto=1), 1.0), _draw(p, dict(spec, upto=2, grow_from=1), 0.0)
    assert _diff_box(one, two) is None                       # 増える行の頭（t=0）は、前の行の完成と同じ


def test_number_figure_needs_its_items():
    with pytest.raises(script.ScriptError):
        _fig_lines({"type": "stats", "title": "x"})
    with pytest.raises(script.ScriptError):
        _fig_lines({"type": "line", "title": "x"})


def test_put_number_makes_units_small(tmp_path):
    p = _painter(tmp_path)
    assert figures.number_width(p, "100人", 200) < figures.number_width(p, "100", 200) + 200 * 0.75
    assert [m.group(0) for m in figures.NUM.finditer("約1,200万石")] == ["約", "1,200", "万石"]


# --- 4. 左右の全画面比べ ---------------------------------------------------------------
VS = {"type": "versus", "title": "2人", "left": {"image": "a.png", "name": "A", "number": "49歳", "note": "x"},
      "right": {"image": "b.png", "name": "B", "number": "55歳?"}}


def test_versus_needs_two_images():
    with pytest.raises(script.ScriptError):
        _fig_lines({"type": "versus", "left": {"image": "a.png"}, "right": {"name": "B"}})
    assert '"versus"' in _fig_lines(VS)[0].figure


def test_versus_fills_the_screen_and_evens_brightness(tmp_path):
    p = _painter(tmp_path)
    im = _draw(p, VS, 1.0)
    assert im.getpixel((5, 5))[3] == 255 and im.getpixel((1914, 5))[3] == 255     # 全面
    from chiso import numbers
    assert im.getpixel((960, 540))[:3] == numbers.GOLD                            # 真ん中に金の縦線
    # 白い絵と黒い絵でも、真ん中の高さの明るさは近づく
    l = im.crop((100, 500, 400, 560)).convert("L").resize((1, 1)).getpixel((0, 0))
    r = im.crop((1060, 500, 1360, 560)).convert("L").resize((1, 1)).getpixel((0, 0))
    assert abs(l - r) < 120


def test_versus_images_are_checked_as_assets(tmp_path):
    ls = _fig_lines(VS)
    sc = NS(lines=ls)
    assert check.missing_assets(sc, tmp_path) == ["a.png", "b.png"]


# --- 3. つむぎの寄り ----------------------------------------------------------------
def _react_script(n):
    lines = [{"語り": "前置き"}]
    for k in range(n):
        lines += [{"聞き": "少なっ！", "reaction": {"number": f"{k + 1}00人", "lead": "供は"}}, {"語り": "あいだ"}]
    return script.parse({"title": "t", "sections": [{"title": "一", "lines": lines}]})


def test_reaction_only_on_that_line_and_needs_number():
    sc = _react_script(1)
    assert sc.lines[1].reaction and sc.lines[0].reaction is None and sc.lines[2].reaction is None
    with pytest.raises(script.ScriptError):
        script.parse({"title": "t", "sections": [{"title": "一", "lines": [{"聞き": "x", "reaction": {"say": "x"}}]}]})


def test_reaction_twice_ok_three_times_warned():
    assert check.reaction_rules(_react_script(2)) == []
    w = check.reaction_rules(_react_script(3))
    assert w and "3回" in w[0]


def test_reaction_hides_the_small_two_and_shows_tsumugi_big(tmp_path):
    sc = _react_script(1)
    p = _painter(tmp_path, sc)
    p.layered = True
    st = render.state_of(sc.lines[1])
    assert st.reaction
    plain = p.with_cast(p.base(render.state_of(sc.lines[0])), "語り", 0, "")
    react = p.with_cast(p.base(st), "聞き", 0, "", reaction=st.reaction)
    # いつもの剣崎（左下、青）は出ない。つむぎ（橙）は右に大きく
    assert plain.getpixel((150, 1000))[:3] == (90, 110, 160)
    assert react.getpixel((150, 1000))[:3] != (90, 110, 160)
    orange = sum(1 for x in range(1000, 1920, 20) for y in range(150, 1080, 20)
                 if react.getpixel((x, y))[:3] == (220, 150, 50))
    small = sum(1 for x in range(1000, 1920, 20) for y in range(150, 1080, 20)
                if plain.getpixel((x, y))[:3] == (220, 150, 50))
    assert orange > small * 2


def test_reaction_is_new_on_screen_for_pacing():
    data = {"title": "t", "sections": [{"title": "一", "lines": [{"語り": "あ" * 80} for _ in range(5)]}]}
    assert [w for w in check.pacing(script.parse(data)) if "新しいもの" in w]
    data["sections"][0]["lines"][3]["reaction"] = {"number": "1人"}
    assert not [w for w in check.pacing(script.parse(data)) if "新しいもの" in w]
