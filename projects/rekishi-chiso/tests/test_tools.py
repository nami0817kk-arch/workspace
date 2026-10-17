"""画面の質を上げる道具（10-07）：絵の一部を大きく（detail）・赤ペン（mark）・紙の質感（texture）・
ここまでの地層（recap）・出来上がった動画の点検（qc）。

CI には日本語フォントも素材も無いので、Pillow の内蔵フォントと、その場で作った絵で描いて確かめる。
"""
import json

import pytest
from PIL import Image, ImageChops

from chiso import check, figures, pen, qc, render, script, texture

from test_port import FakePainter, _config


def _assets(tmp_path):
    (tmp_path / "paintings").mkdir(exist_ok=True)
    im = Image.new("RGB", (800, 400), (60, 90, 120))
    im.paste((230, 40, 40), (400, 100, 600, 300))           # 右寄りに赤い四角（ここを大きく見せる）
    im.save(tmp_path / "paintings" / "bg.png")
    Image.new("RGB", (300, 400), (200, 180, 150)).save(tmp_path / "paintings" / "face.png")
    for name, color in (("k.png", (90, 110, 160, 255)), ("t.png", (220, 150, 50, 255))):
        ch = Image.new("RGBA", (300, 900), (0, 0, 0, 0))
        ch.paste(Image.new("RGBA", (200, 860), color), (50, 20))
        ch.save(tmp_path / name)


BG = {"image": "paintings/bg.png", "credit": "見本"}
BARS = {"type": "bars", "title": "数", "bars": [["甲", 10], ["乙", 30]]}


def _parse(lines, **top):
    return script.parse({"title": "t", **top, "sections": [{"title": "一", "background": BG, "lines": lines}]})


def _painter(tmp_path, sc, **cfg):
    _assets(tmp_path)
    return FakePainter({**_config(), **cfg}, sc, tmp_path, (1920, 1080))


# --- 1. 絵の一部を大きく -----------------------------------------------------------------
def test_detail_is_parsed_with_the_background_image():
    sc = _parse([{"語り": "a", "detail": {"box": [400, 100, 600, 300], "label": "鉄砲隊"}}, {"語り": "b"}])
    d = json.loads(sc.lines[0].detail)
    assert d == {"image": "paintings/bg.png", "box": [400.0, 100.0, 600.0, 300.0], "label": "鉄砲隊"}
    assert sc.lines[1].detail is None                        # その行だけ


@pytest.mark.parametrize("bad", [{"label": "x"}, {"box": [1, 2, 3]}, {"box": [5, 5, 1, 1]}, {"box": [0, 0, 1, 1], "zoom": 2}])
def test_detail_must_be_well_formed(bad):
    with pytest.raises(script.ScriptError):
        _parse([{"語り": "a", "detail": bad}])


def test_crop_box_accepts_fractions_and_pixels():
    assert pen.crop_box({"box": [0.5, 0.25, 0.75, 0.75]}, (800, 400)) == (400, 100, 600, 300)
    assert pen.crop_box({"box": [400, 100, 900, 300]}, (800, 400)) == (400, 100, 800, 300)   # 絵の外は切る


def test_detail_draws_the_part_large_and_hides_the_portrait(tmp_path):
    sc = _parse([{"語り": "a", "portrait": {"image": "paintings/face.png", "caption": "人"},
                  "detail": {"box": [400, 100, 600, 300], "label": "赤"}}])
    p = _painter(tmp_path, sc)
    img = p.base(render.state_of(sc.lines[0]))
    x0, y0, x1, y1 = p.DETAIL_BOX
    r, g, b, _ = img.getpixel(((x0 + x1) // 2, (y0 + y1) // 2))
    assert r > 200 and g < 80                                # 真ん中に赤い四角が大きく（暗くしていない）
    assert img.getpixel((1500, 120))[:3] != (200, 180, 150)  # 肖像は出ない


def test_detail_keeps_alpha_in_layered_mode(tmp_path):
    sc = _parse([{"語り": "a", "detail": {"box": [400, 100, 600, 300]},
                  "mark": {"type": "circle", "at": [0.2, 0.2, 0.8, 0.8]}}], texture=True)
    p = _painter(tmp_path, sc)
    p.layered = True
    img = p.base(render.state_of(sc.lines[0]))
    assert img.mode == "RGBA"
    assert img.getpixel((960, 540))[3] == 0                  # 額の外は透明のまま（黒い枠にならない）
    assert img.getpixel((1285, 533))[3] == 255


def test_pacing_counts_detail_and_new_marks():
    long = "あ" * 120                                         # 1行で約18秒
    base = [{"語り": long}] * 3
    sc = _parse(base)
    assert any("新しいもの" in w for w in check.pacing(sc))
    sc = _parse([{"語り": long}, {"語り": long, "detail": {"box": [0, 0, 0.5, 0.5]}},
                 {"語り": long, "detail": {"box": [0, 0, 0.5, 0.5]}, "mark": {"type": "circle", "at": [0.5, 0.5]}}])
    assert not any("新しいもの" in w for w in check.pacing(sc))


def test_missing_assets_includes_detail_image(tmp_path):
    sc = _parse([{"語り": "a", "detail": {"box": [0, 0, 1, 1], "image": "paintings/none.png"}}])
    assert "paintings/none.png" in check.missing_assets(sc, tmp_path)


# --- 2. 赤ペン -------------------------------------------------------------------------
def test_marks_accumulate_on_the_same_target_and_reset_on_change():
    d = {"box": [0, 0, 0.5, 0.5]}
    sc = _parse([
        {"語り": "1", "detail": d, "mark": {"type": "circle", "at": [0.5, 0.5]}},
        {"語り": "2", "detail": d, "mark": {"type": "note", "at": [0.1, 0.1], "text": "ここ"}},
        {"語り": "3", "detail": d},
        {"語り": "4", "figure": BARS, "mark": {"type": "strike", "at": 2}},
        {"語り": "5", "mark": None},
    ])
    got = [pen.spec_of(l.mark) for l in sc.lines]
    assert [len(i) for i, _ in got] == [1, 2, 2, 1, 0]
    assert [f for _, f in got[:4]] == [0, 1, 2, 0]           # 新しく足した印だけが描き進む


@pytest.mark.parametrize("bad", [{"type": "box", "at": 1}, {"type": "circle"}, {"type": "note", "at": [0.1, 0.1]},
                                 {"type": "circle", "at": 0}, {"type": "circle", "at": [1, 2, 3]}])
def test_marks_must_be_well_formed(bad):
    with pytest.raises(script.ScriptError):
        _parse([{"語り": "a", "figure": BARS, "mark": bad}])


def test_item_number_needs_a_figure():
    with pytest.raises(script.ScriptError):
        _parse([{"語り": "a", "mark": {"type": "circle", "at": 1}}])


def test_item_boxes_follow_the_bars(tmp_path):
    sc = _parse([{"語り": "a"}])
    p = _painter(tmp_path, sc)
    boxes = figures.item_boxes(p, BARS)
    assert set(boxes) == {0, 1}
    assert boxes[0][1] < boxes[1][1]                         # 2本目は1本目より下
    x0, y0, x1, y1 = figures.PANEL
    assert all(x0 <= b[0] and b[2] <= x1 and y0 <= b[1] and b[3] <= y1 for b in boxes.values())


def test_marks_draw_red_on_the_figure_item_and_progress(tmp_path):
    sc = _parse([{"語り": "a", "figure": BARS, "mark": {"type": "strike", "at": 2}}])
    p = _painter(tmp_path, sc)
    st = render.state_of(sc.lines[0])
    plain = p.base(render.State(**{**st.__dict__, "mark": None}))
    done = p.base(st)
    half = p.base(st, mark_t=0.5)
    diff = ImageChops.difference(plain.convert("RGB"), done.convert("RGB")).getbbox()
    b = figures.item_boxes(p, BARS)[1]
    assert diff is not None and diff[1] <= (b[1] + b[3]) / 2 <= diff[3]     # 2番目の項目の高さに線
    d_half = ImageChops.difference(plain.convert("RGB"), half.convert("RGB")).getbbox()
    assert d_half is not None and d_half[2] < diff[2]        # 途中は線が短い


def test_resolve_maps_pixels_through_the_crop():
    view = (100, 100, 400, 200)
    assert pen.resolve([0.5, 0.5], view) == (300, 200, 300, 200)
    assert pen.resolve([500, 200, 600, 300], view, (400, 100, 600, 300)) == (300, 200, 500, 300)


def test_marks_keep_alpha(tmp_path):
    layer = Image.new("RGBA", (400, 300), (0, 0, 0, 0))
    mark = json.dumps({"items": [{"type": "circle", "at": [0.3, 0.3, 0.6, 0.6]}], "from": 0})
    p = _painter(tmp_path, _parse([{"語り": "a"}]))
    out = pen.draw_marks(p, layer, mark, lambda at: pen.resolve(at, (0, 0, 400, 300)), (0, 0, 400, 300))
    assert out.mode == "RGBA" and out.getpixel((5, 5))[3] == 0 and out.getbbox() is not None


# --- 3. 紙の質感 ------------------------------------------------------------------------
def test_texture_changes_only_inside_and_keeps_alpha():
    img = Image.new("RGBA", (300, 200), (232, 218, 186, 250))
    img.paste((0, 0, 0, 0), (0, 0, 300, 50))
    before = img.copy()
    texture.apply(img, (20, 60, 280, 180), radius=8)
    assert img.getchannel("A").tobytes() == before.getchannel("A").tobytes()
    assert img.crop((0, 0, 300, 55)).tobytes() == before.crop((0, 0, 300, 55)).tobytes()
    inside = ImageChops.difference(img.convert("RGB"), before.convert("RGB")).getbbox()
    assert inside is not None and inside[0] >= 20 and inside[3] <= 180
    lo, hi = ImageChops.difference(img.convert("RGB"), before.convert("RGB")).getextrema()[0]
    assert hi <= texture.STRENGTH                            # うっすら


def test_texture_is_off_unless_asked(tmp_path):
    sc = _parse([{"語り": "a", "figure": BARS}])
    off = _painter(tmp_path, sc).base(render.state_of(sc.lines[0]))
    sc2 = _parse([{"語り": "a", "figure": BARS}], texture=True)
    on = _painter(tmp_path, sc2).base(render.state_of(sc2.lines[0]))
    assert sc.look == {} and sc2.look == {"texture": True}
    assert off.tobytes() != on.tobytes()
    p = _painter(tmp_path, sc, texture=True)                 # config.yaml でも入る
    assert p.look("texture") and not _painter(tmp_path, sc2, texture=False).look("recap")


def test_grain_is_made_once():
    a = texture.grain((64, 32))
    assert texture.grain((64, 32)) is a


# --- 4. ここまでの地層 ---------------------------------------------------------------------
def _sections(n_cards):
    secs = []
    for s in range(4):
        lines = [{"語り": f"{s}-{k}", "card": {"head": f"{1500 + s}年", "body": f"札{s}-{k}"}} for k in range(n_cards)]
        secs.append({"title": f"節{s}", "lines": lines or [{"語り": "x"}]})
    secs[-1]["title"] = "まとめ：見本"
    return script.parse({"title": "t", "sections": secs})


def test_recap_cards_come_from_the_previous_section():
    sc = _sections(5)
    assert render.recap_cards(sc, 0) == ()
    got = render.recap_cards(sc, 1)
    assert [c.body for c in got] == ["札0-0", "札0-2", "札0-4"]     # 最初・真ん中・最後
    assert render.recap_cards(sc, 3) == ()                    # まとめの節の頭は出さない
    assert render.recap_cards(_sections(1), 2) == ()          # 2枚に満たない節は出さない


def test_recap_draws_only_when_turned_on(tmp_path):
    sc = _sections(3)
    p = _painter(tmp_path, sc)
    base = Image.new("RGBA", (1920, 1080), (30, 30, 30, 255))
    out = p.recap(base, 1, render.recap_cards(sc, 1))
    assert ImageChops.difference(out, base).getbbox() is not None
    assert p.recap(base, 1, ()) is base


# --- 5. 動画の点検 ------------------------------------------------------------------------
ERR = """
[Parsed_showinfo_3 @ 0000] n:   0 pts:   1500 pts_time:3.0    duration: 1
[Parsed_showinfo_3 @ 0000] n:   1 pts:   9000 pts_time:61.5   duration: 1
[silencedetect @ 0001] silence_start: 10.2
[silencedetect @ 0001] silence_end: 13.4 | silence_duration: 3.2
[silencedetect @ 0001] silence_start: 88
[Parsed_loudnorm_1 @ 0002]
{
	"input_i" : "-15.99",
	"input_tp" : "-1.10",
	"input_lra" : "3.50",
	"input_thresh" : "-26.0"
}
"""


def test_parse_ffmpeg_output():
    assert qc.parse_scenes(ERR) == [3.0, 61.5]
    assert qc.parse_silences(ERR) == [(10.2, 3.2), (88.0, -1.0)]
    assert qc.parse_loudnorm(ERR)["input_i"] == -15.99


def test_summary_finds_long_still_runs_and_tail():
    rep = qc.Report(duration=100.0, scenes=[3.0, 61.5], loud={"input_i": -14.2, "input_tp": -1.5, "input_lra": 4},
                    silences=qc.parse_silences(ERR), subs_end=87.5, sections=[(0.0, "第1節 一"), (50.0, "第2節 二")])
    text = "\n".join(qc.summarize(rep))
    assert "3区間" in text and "0:03〜1:02（58秒）第1節 一　← 長い" in text
    assert "1か所（ほかに最後の次回予告 12秒）" in text      # 最後の無音は次回予告として別に数える
    assert "基準" not in text                                 # -14.2 は基準のうち
    assert "差 12.5秒" in text and "←" not in text.split("差 12.5秒")[1].split("\n")[0]


def test_srt_and_section_starts():
    srt = "1\n00:00:00,300 --> 00:00:04,890\nA：あ。\n\n2\n00:01:02,000 --> 00:01:05,500\nB：い。\n"
    cues = qc.parse_srt(srt)
    assert cues == [(0.3, 4.89), (62.0, 65.5)]
    sc = script.parse({"title": "t", "sections": [{"title": "一", "lines": [{"語り": "あ。"}]},
                                                  {"title": "二", "lines": [{"聞き": "い。"}]}]})
    assert qc.section_starts(sc, cues) == [(0.0, "第1節 一"), (4.89, "第2節 二")]
    assert qc.section_starts(sc, cues[:1]) == []              # 数が合わなければ読まない


def test_sheet_groups_rows_by_section():
    frames = [(t, Image.new("RGB", qc.THUMB, (t * 2 % 255, 0, 0))) for t in range(0, 200, 20)]
    one = qc.sheet(frames, [])
    two = qc.sheet(frames, [(0.0, "第1節"), (100.0, "第2節")])
    assert two.height > one.height
