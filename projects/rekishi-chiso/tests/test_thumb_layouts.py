"""サムネイルの構図（10-07 ユーザー決定「量産型に見せない」）：目印だけそろえ、構図は台本の thumbnail.layout で選ぶ。

CI には日本語フォントも素材も無いので、内蔵のフォント・その場で作った絵・小さな地図で確かめる。
"""
import json

from PIL import Image, ImageChops

from chiso import check, script, thumb

CROP = [0, 0, 1600, 900]


def _assets(tmp_path):
    a = tmp_path / "assets"
    (a / "maps").mkdir(parents=True)
    for name, color in (("p.jpg", (120, 90, 60)), ("l.jpg", (200, 180, 140)), ("r.jpg", (150, 40, 30))):
        im = Image.new("RGB", (1600, 900), color)
        im.paste((230, 200, 170), (600, 200, 1000, 600))
        im.save(a / name)
    land = {"type": "FeatureCollection", "features": [{"type": "Feature", "geometry": {
        "type": "Polygon", "coordinates": [[[-10, 35], [20, 35], [20, 55], [-10, 55], [-10, 35]]]}}]}
    (a / "maps" / "land_50m.geojson").write_text(json.dumps(land), encoding="utf-8")
    return a


BASE = {"name": "ナポレオン", "lead": "本当に", "main": "小男？"}
SPECS = {
    "classic": {**BASE, "image": "p.jpg", "crop": CROP},
    "face": {**BASE, "layout": "face", "image": "p.jpg", "crop": CROP},
    "scene": {**BASE, "layout": "scene", "image": "p.jpg", "crop": CROP},
    "versus": {"layout": "versus", "main": "なぜ？", "left": {"image": "l.jpg", "name": "織田信長"},
               "right": {"image": "r.jpg", "name": "明智光秀"}},
    "number": {**BASE, "layout": "number", "image": "p.jpg", "crop": CROP, "number": "約168cm"},
    "map": {**BASE, "layout": "map", "map": {"route": ["コルシカ島", "パリ", "エルバ島"]}},
}


def _render(t, assets):
    return thumb.render_spec(thumb.variant_spec(t, "a"), {"fonts": {}}, assets)


def test_every_layout_draws_a_different_picture_with_the_same_strata(tmp_path):
    assets = _assets(tmp_path)
    imgs = {k: _render(t, assets) for k, t in SPECS.items()}
    assert all(im.size == (1280, 720) for im in imgs.values())
    keys = list(imgs)
    for i, a in enumerate(keys):
        for b in keys[i + 1:]:
            assert ImageChops.difference(imgs[a], imgs[b]).getbbox() is not None, (a, b)
    strata = [imgs["classic"].getpixel((x, 712)) for x in (10, 640, 1270)]
    for k, im in imgs.items():                                         # 目印（下端の地層の帯）は全構図で同じ
        assert [im.getpixel((x, 712)) for x in (10, 640, 1270)] == strata, k


def test_no_layout_is_classic_and_same_as_before(tmp_path):
    assets = _assets(tmp_path)
    t = SPECS["classic"]
    assert thumb.variant_spec(t, "a")["layout"] == "a"                  # 書いていなければ今までの形（内部では a）
    explicit = dict(t, layout="classic")
    assert ImageChops.difference(_render(t, assets), _render(explicit, assets)).getbbox() is None
    sc = script.parse({"title": "x", "thumbnail": t, "sections": [{"title": "一", "lines": [{"語り": "a"}]}]})
    assert ImageChops.difference(thumb.make(sc, {"fonts": {}}, assets), _render(t, assets)).getbbox() is None


def test_layout_colors_are_placed_differently(tmp_path):
    assets = _assets(tmp_path)
    scene = _render(SPECS["scene"], assets)
    r, g, b = scene.getpixel((1150, 640))[:3]                          # scene：下の黒い帯
    assert max(r, g, b) < 40
    face = _render(SPECS["face"], assets)
    assert sum(face.getpixel((20, 40))[:3]) < sum(face.getpixel((1200, 400))[:3])   # face：文字の側は暗く、肖像の側は明るい
    number = _render(SPECS["number"], assets)
    assert sum(number.getpixel((1100, 250))[:3]) < sum(scene.getpixel((1100, 250))[:3]) * 0.6   # number：絵は暗く後ろに


def test_cast_can_be_switched_per_script(tmp_path):
    assets = _assets(tmp_path)
    chars = assets / "characters"
    chars.mkdir()
    Image.new("RGBA", (200, 600), (0, 200, 0, 255)).save(chars / "kenzaki_helmet.png")
    Image.new("RGBA", (200, 600), (0, 0, 200, 255)).save(chars / "tsumugi_helmet.png")
    for k in ("face", "number"):
        on, off = _render(dict(SPECS[k], cast=True), assets), _render(dict(SPECS[k], cast=False), assets)
        assert ImageChops.difference(on, off).getbbox() is not None
    assert ImageChops.difference(_render(SPECS["face"], assets), _render(dict(SPECS["face"], cast=False), assets)).getbbox() is None
    assert ImageChops.difference(_render(SPECS["number"], assets), _render(dict(SPECS["number"], cast=True), assets)).getbbox() is None


def test_versus_numbers_replace_vs(tmp_path):
    assets = _assets(tmp_path)
    t = SPECS["versus"]
    nums = dict(t, left=dict(t["left"], number="49歳"), right=dict(t["right"], number="55歳"))
    assert ImageChops.difference(_render(t, assets), _render(nums, assets)).getbbox() is not None


def test_number_parts():
    assert thumb._number_parts("約168cm") == [("約", False), ("168", True), ("cm", False)]
    assert thumb._number_parts("700両") == [("700", True), ("両", False)]
    assert thumb._number_parts("十一日") == [("十一日", False)]


def test_problems_by_layout():
    for t in SPECS.values():
        assert thumb.problems(t) == [], t
    assert "分かりません" in thumb.problems({"layout": "zoom"})[0]
    assert any("number" in p for p in thumb.problems({k: v for k, v in SPECS["number"].items() if k != "number"}))
    bad = dict(SPECS["versus"], right={"image": "r.jpg"})
    assert any("right.name" in p for p in thumb.problems(bad))
    assert any("left" in p for p in thumb.problems({"layout": "versus", "right": {"image": "r.jpg", "name": "x"}}))
    assert any("places.yaml" in p for p in thumb.problems(dict(SPECS["map"], map={"route": ["どこにもない町"]})))
    assert any("route" in p for p in thumb.problems(dict(SPECS["map"], map={"note": "x"})))
    assert any("map" in p for p in thumb.problems(dict(SPECS["map"], map={})))
    assert thumb.problems(dict(SPECS["face"], side="up"))
    assert thumb.problems(dict(SPECS["scene"], band="middle"))
    assert any("crop" in p for p in thumb.problems({"name": "x", "main": "y", "image": "p.jpg"}))   # classic は今までどおり


def _episode_sc(t):
    return script.parse({"title": "x", "thumbnail": t, "next": {"title": "a", "teaser": "b"},
                         "sections": [{"title": "まとめ：x", "lines": [{"語り": "a"}]}]})


def test_episode_marks_layout_problems_as_errors():
    errors, _ = check.episode(_episode_sc({"layout": "zoom", "name": "x", "main": "y"}))
    assert any("構図" in e for e in errors)
    errors, _ = check.episode(_episode_sc(SPECS["map"]))
    assert not any("サムネイル" in e for e in errors)


def test_missing_assets_include_layout_pictures(tmp_path):
    sc = _episode_sc(SPECS["versus"])
    assert check.missing_assets(sc, tmp_path) == ["l.jpg", "r.jpg"]
    assert check.missing_assets(_episode_sc(SPECS["classic"]), tmp_path) == []      # classic は今までどおり見ない


def test_make_variants_for_versus_is_only_a(tmp_path):
    assets = _assets(tmp_path)
    sc = _episode_sc(SPECS["versus"])
    assert list(thumb.make_variants(sc, {"fonts": {}}, assets)) == ["a"]
    sc = _episode_sc(SPECS["face"])
    assert list(thumb.make_variants(sc, {"fonts": {}}, assets)) == ["a", "b", "c"]


# --- 同じ構図が3回続いたら知らせる -----------------------------------------------------

def _posted(tmp_path, entries, layouts):
    log = tmp_path / "posted.json"
    log.write_text(json.dumps([{"key": k, "publish_at": at} for k, at in entries], ensure_ascii=False), encoding="utf-8")
    sd = tmp_path / "scripts"
    sd.mkdir(exist_ok=True)
    for name, lay in layouts.items():
        thumb_yaml = f"thumbnail: {{layout: {lay}}}\n" if lay else "thumbnail: {name: x}\n"
        (sd / f"{name}.yaml").write_text("title: x\n" + thumb_yaml, encoding="utf-8")
    return log, sd


def test_layout_streak_warns_on_the_third(tmp_path):
    # 投稿の順は publish_at で並べる（posted.json の並びではない）。ショートは数えない
    log, sd = _posted(tmp_path, [("b:main", "2026-10-09 19:00"), ("a:main", "2026-10-08 19:00"),
                                 ("a:short:s1", "2026-10-09 11:00")], {"a": None, "b": "face"})
    assert check.layout_streak(log, sd, "c", "face") == []                         # classic → face → face
    log, sd = _posted(tmp_path, [("a:main", "2026-10-08 19:00"), ("b:main", "2026-10-09 19:00")], {"a": "face", "b": "face"})
    w = check.layout_streak(log, sd, "c", "face")
    assert len(w) == 1 and "3回" in w[0] and "a→b→c" in w[0]
    assert check.layout_streak(log, sd, "c", "map") == []


def test_layout_streak_for_a_posted_script_counts_up_to_it(tmp_path):
    log, sd = _posted(tmp_path, [("a:main", "2026-10-08 19:00"), ("b:main", "2026-10-09 19:00"), ("c:main", "2026-10-10 19:00")],
                      {"a": None, "b": None, "c": "map"})
    assert check.layout_streak(log, sd, "b", "classic") == []                      # a → b の2回だけ
    assert check.layout_streak(log, sd, "d", "map") == []
    log, sd = _posted(tmp_path, [("a:main", "2026-10-08 19:00"), ("b:main", "2026-10-09 19:00")], {"a": None, "b": None})
    assert "classic" in check.layout_streak(log, sd, "c", "classic")[0]            # 書いていない台本は classic と数える
    assert check.layout_streak(tmp_path / "none.json", sd, "c", "classic") == []    # 控えが無くても止まらない
