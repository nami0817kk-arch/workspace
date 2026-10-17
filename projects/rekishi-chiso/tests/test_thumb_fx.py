"""サムネイルの作り込み（10-07 ユーザー「もう少し作り込んだサムネにしたい」）。

構図（face・scene・versus・number・map）にだけ、文字の二重の縁取り・光・朱・ぼかし・小物・紙の質感を重ねる。
classic と3案の b・c は今と画素まで同じ。人物の切り抜き（rembg）は入っていなければ切り抜かない（CI はこちら）。
"""
import importlib.util

import pytest
from PIL import Image, ImageChops, ImageDraw, ImageFont

from chiso import thumb, thumbfx
from test_thumb_layouts import SPECS, _assets, _render


def _same(a, b):
    return ImageChops.difference(a, b).getbbox() is None


def test_classic_and_variants_ignore_fx_keys(tmp_path):
    assets = _assets(tmp_path)
    extra = {"light": "right", "tint": "right", "badge": "1582年", "circle": [10, 10, 200, 200],
             "arrow": {"from": [10, 10], "to": [300, 300]}, "cutout": True}
    t = SPECS["classic"]
    assert _same(_render(t, assets), _render(dict(t, **extra), assets))           # classic は今と同じ
    assert thumbfx.options(thumb.variant_spec(dict(SPECS["face"], **extra), "b", (1600, 900)), "b") == {"on": False}


def test_every_layout_is_dressed_up_and_fx_false_turns_it_off(tmp_path):
    assets = _assets(tmp_path)
    for k in ("face", "scene", "versus", "number", "map"):
        on, off = _render(SPECS[k], assets), _render(dict(SPECS[k], fx=False), assets)
        assert not _same(on, off), k
        assert [on.getpixel((x, 712)) for x in (10, 640, 1270)] == [off.getpixel((x, 712)) for x in (10, 640, 1270)], k


@pytest.mark.parametrize("layout,key,value", [
    ("face", "badge", "1582年"), ("face", "badge", {"text": "記録", "at": [700, 40], "angle": 4}),
    ("face", "arrow", {"from": [300, 600], "to": [800, 300]}), ("number", "circle", [100, 200, 600, 500]),
    ("scene", "light", "none"), ("versus", "tint", "none"), ("versus", "tint", {"side": "left", "color": [30, 60, 160]}),
    ("number", "rays", False), ("scene", "torn", False), ("face", "texture", False), ("face", "blur", False),
    ("map", "arrow", [{"from": [100, 300], "to": [400, 500]}, {"from": [900, 300], "to": [700, 600], "bend": -0.3}]),
])
def test_each_element_can_be_switched(tmp_path, layout, key, value):
    assets = _assets(tmp_path)
    assert not _same(_render(SPECS[layout], assets), _render(dict(SPECS[layout], **{key: value}), assets))


def test_light_brightens_the_subject_side(tmp_path):
    assets = _assets(tmp_path)
    t = dict(SPECS["number"], cast=False, rays=False, blur=False, texture=False)
    left, right = _render(dict(t, light="left"), assets), _render(dict(t, light="right"), assets)
    assert sum(left.getpixel((60, 300))) > sum(right.getpixel((60, 300)))
    assert sum(left.getpixel((1220, 300))) < sum(right.getpixel((1220, 300)))


def test_tint_turns_one_side_vermilion(tmp_path):
    assets = _assets(tmp_path)
    t = dict(SPECS["versus"], rays=False, torn=False, texture=False, main="")
    plain, red = _render(dict(t, tint="none"), assets), _render(dict(t, tint="right"), assets)
    r0, g0, b0 = plain.getpixel((1000, 300))
    r1, g1, b1 = red.getpixel((1000, 300))
    assert r1 - g1 > r0 - g0                                          # 右は朱に寄る
    assert plain.getpixel((200, 300)) == red.getpixel((200, 300))      # 左はそのまま


def test_fancy_text_has_double_outline_gradient_and_tilt():
    f = ImageFont.load_default(120)
    img = Image.new("RGB", (900, 300), (0, 128, 0))
    thumbfx.text(img, (40, 150), "IIII", f, (255, 214, 40), (255, 120, 10), (0, 0, 0), 10, (255, 255, 255), 6, anchor="lm")
    colors = {c for _, c in img.getcolors(900 * 300)}
    assert (255, 255, 255) in colors and (0, 0, 0) in colors           # 外側の白・内側の黒
    fill = [(y, img.getpixel((x, y))[1]) for y in range(300) for x in range(0, 900, 3)
            if img.getpixel((x, y))[0] == 255 and img.getpixel((x, y))[2] < 60 and img.getpixel((x, y))[1] > 90]
    y0, y1 = min(y for y, _ in fill), max(y for y, _ in fill)
    top = [g for y, g in fill if y < y0 + 8]
    bottom = [g for y, g in fill if y > y1 - 8]
    assert sum(top) / len(top) > sum(bottom) / len(bottom) + 40        # 上は黄・下は橙
    flat, tilted = Image.new("RGB", (900, 300)), Image.new("RGB", (900, 300))
    thumbfx.text(flat, (40, 150), "IIII", f, anchor="lm")
    thumbfx.text(tilted, (40, 150), "IIII", f, anchor="lm", angle=-8)
    assert not _same(flat, tilted)


def test_problems_for_fx_keys():
    base = SPECS["face"]
    assert thumb.problems(base) == []
    assert any("light" in p for p in thumb.problems(dict(base, light="up")))
    assert any("tint" in p for p in thumb.problems(dict(base, tint="middle")))
    assert any("arrow" in p for p in thumb.problems(dict(base, arrow={"from": [1, 2]})))
    assert any("circle" in p for p in thumb.problems(dict(base, circle=[1, 2, 3])))
    assert any("badge" in p for p in thumb.problems(dict(base, badge={"at": [1, 2]})))
    assert thumb.problems(dict(base, circle=[[1, 2, 3, 4], [5, 6, 7, 8]], arrow=[{"from": [0, 0], "to": [9, 9]}])) == []
    assert thumb.problems(dict(SPECS["classic"], light="up")) == []      # classic は見ない（使わない）


# --- 人物の切り抜き ------------------------------------------------------------------------

def _body(size=(400, 400), speck=True, hole=True):
    """胸像らしい形（頭＋肩）に、離れた小さな残り（椅子の端）と、衣の半透明の穴。"""
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.ellipse([150, 40, 250, 160], fill=255)
    d.rectangle([60, 150, 340, 400], fill=255)
    if hole:
        d.rectangle([150, 250, 220, 320], fill=30)
    if speck:
        d.rectangle([370, 20, 395, 45], fill=255)
    return m


def test_largest_blob_drops_specks_and_fills_holes():
    m = thumbfx.largest_blob(_body())
    assert m.getpixel((382, 32)) < 30                                  # 離れた残りは落ちる
    assert m.getpixel((185, 285)) > 200                                # 衣の穴は埋まる
    assert m.getpixel((200, 100)) > 200 and m.getpixel((200, 380)) > 200
    assert thumbfx.usable(m)


def test_usable_rejects_neck_only_cutouts():
    neck = Image.new("L", (400, 400), 0)
    ImageDraw.Draw(neck).ellipse([160, 40, 240, 160], fill=255)
    ImageDraw.Draw(neck).rectangle([180, 150, 220, 400], fill=255)
    assert not thumbfx.usable(neck)                                    # 衣が抜けて首だけ → 使わない
    assert not thumbfx.usable(Image.new("L", (400, 400), 0))


def test_cutout_pops_the_person_and_is_cached(tmp_path, monkeypatch):
    assets = _assets(tmp_path)
    calls = []

    def fake(tile):
        calls.append(tile.size)
        return _body(tile.size, hole=False).resize(tile.size)

    plain = _render(SPECS["face"], assets)                             # rembg が無い＝切り抜かない
    assert _same(plain, _render(dict(SPECS["face"], cutout=False), assets))
    monkeypatch.setattr(thumbfx, "_segment", fake)
    cache = tmp_path / "work" / "x"
    spec = thumb.variant_spec(SPECS["face"], "a")
    popped = thumb.render_spec(spec, {"fonts": {}}, assets, cache)
    assert not _same(plain, popped)
    files = list(cache.glob("cutout_*.png"))
    assert len(files) == 1 and Image.open(files[0]).mode == "RGBA"
    thumbfx._MEMO.clear()
    again = thumb.render_spec(spec, {"fonts": {}}, assets, cache)       # 2回目は控えを読む（切り抜かない）
    assert len(calls) == 1 and _same(popped, again)


def test_versus_cuts_out_both_sides(tmp_path, monkeypatch):
    assets = _assets(tmp_path)
    plain = _render(SPECS["versus"], assets)
    monkeypatch.setattr(thumbfx, "_segment", lambda tile: _body(tile.size, hole=False))
    assert not _same(plain, _render(SPECS["versus"], assets))


def test_bad_cutout_falls_back_to_the_plain_picture(tmp_path, monkeypatch):
    assets = _assets(tmp_path)
    plain = _render(SPECS["face"], assets)
    neck = Image.new("L", (720, 720), 0)
    ImageDraw.Draw(neck).rectangle([340, 100, 380, 720], fill=255)
    monkeypatch.setattr(thumbfx, "_segment", lambda tile: neck.resize(tile.size))
    assert _same(plain, _render(SPECS["face"], assets))


def test_given_transparent_png_is_put_in_front(tmp_path):
    assets = _assets(tmp_path)
    person = Image.new("RGBA", (300, 600), (0, 0, 0, 0))
    ImageDraw.Draw(person).ellipse([20, 20, 280, 580], fill=(0, 0, 255, 255))
    person.save(assets / "x_cutout.png")
    img = _render(dict(SPECS["scene"], cutout="x_cutout.png"), assets)
    r, g, b = img.getpixel((1100, 300))
    assert b > 150 and r < 80
    img = _render(dict(SPECS["scene"], cutout={"image": "x_cutout.png", "x": 20, "height": 500}), assets)
    assert img.getpixel((150, 400))[2] > 150


@pytest.mark.skipif(importlib.util.find_spec("rembg") is None, reason="rembg が入っていない（CI）")
def test_real_rembg_returns_a_mask(monkeypatch):
    monkeypatch.undo()                                                 # conftest の「切り抜かない」を外す
    tile = Image.new("RGB", (320, 320), (230, 230, 230))
    ImageDraw.Draw(tile).ellipse([110, 30, 210, 140], fill=(200, 160, 130))
    ImageDraw.Draw(tile).rectangle([60, 140, 260, 320], fill=(40, 40, 120))
    m = thumbfx._segment(tile)
    assert m is not None and m.mode == "L" and m.size == tile.size


def test_missing_assets_include_the_given_cutout(tmp_path):
    from chiso import check, script
    sc = script.parse({"title": "x", "thumbnail": dict(SPECS["face"], cutout="paintings/x_cutout.png"),
                       "sections": [{"title": "一", "lines": [{"語り": "a"}]}]})
    assert "paintings/x_cutout.png" in check.missing_assets(sc, tmp_path)
