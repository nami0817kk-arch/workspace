"""サムネイルの引きの要素（10-08 ユーザー「サムネにもう少し人を惹きつける要素を入れたい！」、chiso/hooks.py）。

reactor（聞き手の驚き顔を大きく）・hide（隠して「？」）・contrast（落差の二語）・flip（視線の向き）・flash（赤い光）。
書かなければ今と画素まで同じ。CI には rembg も立ち絵も無いので、その場で作った絵で確かめる。
"""
import pytest
from PIL import Image, ImageChops, ImageDraw, ImageOps

from chiso import check, hooks, thumb, thumbfx
from test_thumb_layouts import CROP, SPECS, _assets, _episode_sc, _render


def _same(a, b):
    return ImageChops.difference(a, b).getbbox() is None


def _cast_assets(tmp_path):
    """左へ腕を出した立ち絵（左半分だけ色が濃い）を、つむぎの「驚き」の顔として置く。"""
    a = _assets(tmp_path)
    faces = a / "characters" / "tsumugi_faces"
    faces.mkdir(parents=True)
    fig = Image.new("RGBA", (400, 1000), (0, 0, 0, 0))
    d = ImageDraw.Draw(fig)
    d.rectangle([100, 0, 300, 1000], fill=(250, 200, 40, 255))
    d.rectangle([0, 300, 100, 360], fill=(20, 200, 20, 255))         # 左へ出した腕（緑）
    fig.save(faces / "驚き_open.png")
    return a, {"fonts": {}, "cast": {"聞き": {"faces": "characters/tsumugi_faces", "image": "characters/x.png"}}}


def _go(t, assets, config):
    hooks._FIG.clear()
    return thumb.render_spec(thumb.variant_spec(t, "a"), config, assets)


@pytest.fixture(autouse=True)
def _no_rembg(monkeypatch):
    monkeypatch.setattr(thumbfx, "_segment", lambda tile: None)          # 手元に rembg があっても CI と同じに
    thumbfx._MEMO.clear()


def test_without_hooks_every_layout_is_unchanged(tmp_path):
    assets, config = _cast_assets(tmp_path)
    for k, t in SPECS.items():
        assert hooks.used(t) == []
        assert thumb._prepare(t, config, assets) is t                      # 下ごしらえも素通り
        assert _same(_go(t, assets, config), _render(t, assets)), k
    off = dict(SPECS["face"], reactor=False, hide=None, flip=False, flash=False)
    assert _same(_go(off, assets, config), _render(SPECS["face"], assets))


def test_reactor_is_big_on_the_side_and_faces_the_middle(tmp_path):
    assets, config = _cast_assets(tmp_path)
    t = dict(SPECS["number"], reactor={"who": "tsumugi", "face": "驚き", "side": "right", "size": "large"})
    box = hooks.reactor_box(t, config, assets)
    assert box[2] > thumb.W and box[3] == thumb.H and box[3] - box[1] == int(thumb.H * hooks.SIZES["large"])
    img = _go(t, assets, config)
    assert not _same(img, _go(SPECS["number"], assets, config))
    fig = hooks.reactor_figure(hooks.reactor_spec(t["reactor"]), config, assets)
    assert fig.getpixel((20, int(fig.height * 330 / 420)))[1] > 150                              # 右に置くと、腕（緑）は左＝真ん中の側
    left = hooks.reactor_figure(hooks.reactor_spec({"side": "left"}), config, assets)
    assert left.getpixel((left.width - 20, int(left.height * 330 / 420)))[1] > 150                # 左に置くと反転して右（真ん中）を向く
    medium = hooks.reactor_box(dict(t, reactor={"size": "medium"}), config, assets)
    assert medium[3] - medium[1] < box[3] - box[1]


def test_reactor_replaces_the_small_cast_and_pushes_text_away(tmp_path):
    assets, config = _cast_assets(tmp_path)
    t = dict(SPECS["classic"], reactor=True)
    p = thumb._prepare(t, config, assets)
    assert p["cast"] is False and p["_reactor"]
    assert thumb._hi(p, 1000) < 1000 and thumb._hi(SPECS["classic"], 1000) == 1000
    assert thumb._lo(thumb._prepare(dict(t, reactor={"side": "left"}), config, assets), 30) > 30
    assert thumb._prepare(dict(t, cast=True), config, assets)["cast"] is True     # 書けば2人も出せる


def test_reactor_without_picture_draws_nothing(tmp_path):
    assets = _assets(tmp_path)
    t = dict(SPECS["face"], reactor=True)
    assert hooks.reactor_box(t, {"fonts": {}}, assets) is None
    assert _same(_go(t, assets, {"fonts": {}}), _render(SPECS["face"], assets))


@pytest.mark.parametrize("style", hooks.HIDE_STYLES)
def test_hide_changes_only_the_box(tmp_path, style):
    assets = _assets(tmp_path)
    box = [700, 100, 1000, 500]
    t = dict(SPECS["scene"], hide={"box": box, "style": style, "mark": "？"}, fx=False)
    diff = ImageChops.difference(_render(t, assets), _render(dict(SPECS["scene"], fx=False), assets)).getbbox()
    assert diff is not None
    m = 40                                                               # 影・縁の光の分
    assert diff[0] >= box[0] - m and diff[1] >= box[1] - m and diff[2] <= box[2] + m and diff[3] <= box[3] + m


def test_hide_silhouette_is_dark_and_mark_is_optional(tmp_path):
    assets = _assets(tmp_path)
    t = dict(SPECS["scene"], fx=False, hide={"box": [700, 100, 1000, 500], "mark": ""})
    img = _render(t, assets)
    assert sum(img.getpixel((850, 250))) < 60                            # 影絵の頭のあたりは黒
    assert sum(img.getpixel((705, 105))) > 60                            # 四隅は絵のまま（人の形の外）
    with_mark = _render(dict(t, hide=dict(t["hide"], mark="？")), assets)
    assert not _same(img, with_mark)


def test_contrast_takes_the_place_of_lead_and_main(tmp_path):
    assets = _assets(tmp_path)
    for k in ("classic", "face", "scene", "number", "versus", "map"):
        t = dict(SPECS[k], contrast=["天下人", "供は100人"])
        p = thumb._prepare(t, {"fonts": {}}, assets)
        assert p["lead"] is None and p["main"] is None and p["_contrast"], k
        assert not _same(_render(t, assets), _render(SPECS[k], assets)), k
        z = thumb.contrast_zone(p, thumb.variant_spec(t, "a")["layout"])
        assert z[0] < z[2] and z[1] < z[3], k
    t = {k: v for k, v in SPECS["classic"].items() if k not in ("lead", "main")}
    assert thumb.problems(dict(t, contrast=["a", "b"])) == []          # main が無くてもよい
    assert any("main" in e for e in thumb.problems(t))


def test_contrast_style_follows_the_room():
    zone = (40, 220, 680, 650)
    assert hooks.contrast_plan(hooks.contrast_spec(["天下人", "供は100人"]), (40, 500, 1100, 700), None)[0] == "arrow"
    long = hooks.contrast_spec(["背の低い独裁者だった", "平均並みの身長"])
    assert hooks.contrast_plan(long, zone, None)[0] == "strike"         # 狭くて高い所は2段に
    assert hooks.contrast_plan(dict(long, style="arrow"), zone, None)[0] == "arrow"


def test_contrast_spec_forms():
    assert hooks.contrast_spec(["a", "b"]) == {"from": "a", "to": "b", "style": "auto"}
    assert hooks.contrast_spec({"from": "a", "to": "b", "style": "strike"})["style"] == "strike"
    for bad in (["a"], ["a", ""], {"from": "a"}, {"from": "a", "to": "b", "style": "zigzag"}, "a→b"):
        with pytest.raises(ValueError):
            hooks.contrast_spec(bad)


def test_want_flip_and_mirror():
    assert hooks.want_flip({"flip": True}, "left")
    assert not hooks.want_flip({}, "left") and not hooks.want_flip({"flip": False}, "left")
    assert hooks.want_flip({"flip": "auto", "facing": "right"}, "left")
    assert not hooks.want_flip({"flip": "auto", "facing": "left"}, "left")
    assert not hooks.want_flip({"flip": "auto"}, "left")                 # 向きが書いてなければ反転しない
    im = Image.new("RGB", (100, 50))
    assert hooks.mirror(im, [10, 5, 40, 45])[1] == [60, 5, 90, 45]


def test_face_flip_is_the_mirrored_picture(tmp_path):
    assets = _assets(tmp_path)
    with Image.open(assets / "p.jpg") as im:
        ImageOps.mirror(im).save(assets / "p_m.jpg")
    t = dict(SPECS["face"], crop=[100, 0, 1500, 800], fx=False)
    flipped = _render(dict(t, flip=True), assets)
    by_hand = _render(dict(t, image="p_m.jpg", crop=[100, 0, 1500, 800]), assets)
    assert _same(flipped, by_hand)
    auto = _render(dict(t, flip="auto", facing="right"), assets)        # 肖像は右、文字は左 → 右向きの人は反転
    assert _same(auto, flipped)
    assert _same(_render(dict(t, flip="auto", facing="left"), assets), _render(t, assets))


def test_versus_sides_flip_to_face_the_middle(tmp_path):
    assets = _assets(tmp_path)
    t = dict(SPECS["versus"], fx=False)
    left = dict(t, left=dict(t["left"], flip="auto", facing="left"))
    assert not _same(_render(left, assets), _render(t, assets))
    already = dict(t, left=dict(t["left"], flip="auto", facing="right"))
    assert _same(_render(already, assets), _render(t, assets))


def test_flash_warms_the_spot(tmp_path):
    assets = _assets(tmp_path)
    t = dict(SPECS["scene"], fx=False)
    on = _render(dict(t, flash={"at": [640, 200], "sparks": 0}), assets)
    off = _render(t, assets)
    from PIL import ImageStat
    box = (440, 60, 840, 340)
    r1, g1, b1 = ImageStat.Stat(on.crop(box)).mean
    r0, g0, b0 = ImageStat.Stat(off.crop(box)).mean
    assert r1 > r0 + 5 and r1 - r0 > b1 - b0


def test_problems_and_notes():
    t = dict(SPECS["face"])
    assert hooks.problems(dict(t, reactor={"who": "x", "side": "up", "size": "huge"})).__len__() == 3
    assert hooks.problems(dict(t, hide={"box": [10, 10]})) and hooks.problems(dict(t, hide={"box": [0, 0, 9, 9], "style": "x"}))
    assert hooks.problems(dict(t, flip="yes")) and hooks.problems(dict(t, facing="up"))
    assert hooks.problems(dict(SPECS["versus"], left=dict(SPECS["versus"]["left"], flip="yes")))
    assert hooks.problems(dict(t, flash={"at": [1]}))
    assert hooks.problems(dict(t, contrast=["a"]))
    ok = dict(t, reactor=True, hide={"box": [0, 0, 9, 9]}, contrast=["a", "b"], flip="auto", facing="left", flash=True)
    assert hooks.problems(ok) == []
    notes = " ".join(hooks.notes(ok))
    for word in ("5つ", "答え", "事実", "左右反転", "左前"):
        assert word in notes, word
    assert any("facing" in n for n in hooks.notes(dict(t, flip="auto")))
    assert hooks.notes(t) == []


def test_episode_reports_hooks(tmp_path):
    errors, warns = check.episode(_episode_sc(dict(SPECS["face"], hide={"box": [0, 0, 9, 9]}, reactor={"side": "up"})))
    assert any("reactor.side" in e for e in errors)
    assert any("hide" in w for w in warns)


def test_variants_b_and_c_ignore_hooks(tmp_path):
    t = dict(SPECS["classic"], reactor=True, hide={"box": [0, 0, 9, 9]}, contrast=["a", "b"], flash=True)
    for k in ("b", "c"):
        assert hooks.used(thumb.variant_spec(t, k, (1600, 900))) == []
