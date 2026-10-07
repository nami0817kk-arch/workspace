"""サムネの構図（face・scene・versus・number）と作り込み・人物の切り抜き（2026-10-08）。

- 構図を書かない台本は、今の形（classic）と**画素まで同じ**
- 構図の名前の誤り・要る項目の不足は止める
- rembg（切り抜き）が無くても描ける。抜けの悪い形は使わない
- 同じ構図が3回続いたら draft が知らせる
"""

import json
from pathlib import Path
from types import SimpleNamespace

import pytest
from PIL import Image, ImageChops, ImageDraw

from src import research, thumbfx
from src import thumbnail as thumb
from src.config import load_config
from src.thumbnail import SIZE, build_thumbnail


def _config():
    config = load_config()
    config.video.background = "assets/backgrounds/stadium.png"
    return config


def _photo(path: Path, size=(1600, 900), seed: int = 0) -> str:
    """人の形（頭と肩）を描いた横長の写真。"""
    image = Image.new("RGB", size, (40 + seed * 30, 90, 140))
    draw = ImageDraw.Draw(image)
    w, h = size
    cx = int(w * (0.4 + 0.1 * seed))
    draw.ellipse([cx - 90, int(h * 0.18), cx + 90, int(h * 0.18) + 200], fill=(230, 190, 160))
    draw.rectangle([cx - 260, int(h * 0.18) + 190, cx + 260, h], fill=(250, 250, 250))
    for x in range(0, w, 80):
        draw.line([(x, 0), (x, h)], fill=(250, 250, 120), width=6)
    image.save(path)
    return str(path)


def _same(a: Path, b: Path) -> bool:
    with Image.open(a) as x, Image.open(b) as y:
        return x.size == y.size and ImageChops.difference(x.convert("RGB"), y.convert("RGB")).getbbox() is None


def _render(tmp_path, name, layout, lines=("ケイン 125試合目で2得点", "シルトンより●年早く並んだ"), **kw):
    photo = kw.pop("photo", None) or _photo(tmp_path / f"{name}_p.jpg")
    return build_thumbnail(_config(), lines[0], tmp_path / f"{name}.png", style="band",
                           background=photo, lines=lines, layout=layout, **kw)


# ---------------------------------------------------------------- classic は今のまま


def test_構図を書かない台本は今と画素まで同じ(tmp_path):
    photo = _photo(tmp_path / "p.jpg")
    meta = {"thumbnail_line1": "メッシ 代表最後の夜", "thumbnail_line2": "最後のパスを託した相手は●●",
            "thumbnail_photo": photo}
    look = thumb.from_meta(meta, "題")
    assert look["layout"] is None
    assert type(look["lines"]) is tuple            # 構図を書かない回は、ただの2つ組のまま
    base = build_thumbnail(_config(), look["title"], tmp_path / "a.png", style="band",
                           background=photo, lines=look["lines"])
    for name, extra in (("b", {"layout": {"layout": "classic"}}),
                        ("c", {"lines": thumb.ThumbLines(look["lines"], None)}),
                        ("d", {"lines": thumb.from_meta(dict(meta, thumbnail_layout="classic"), "題")["lines"]})):
        args = {"lines": look["lines"], **extra}
        out = build_thumbnail(_config(), look["title"], tmp_path / f"{name}.png", style="band",
                              background=photo, **args)
        assert _same(base, out), name


def test_台本の構図は2行に載って書き出しまで届く(tmp_path):
    """pipeline.py は lines を渡すだけ。ThumbLines に載せれば構図が届く。"""
    photo = _photo(tmp_path / "p.jpg")
    meta = {"thumbnail_line1": "主将・堂安 国立で決勝弾", "thumbnail_line2": "0本だったシュートは●本に",
            "thumbnail_photo": photo, "thumbnail_layout": {"layout": "scene"}}
    look = thumb.from_meta(meta, "題")
    assert look["layout"] == {"layout": "scene"} and look["lines"].layout == {"layout": "scene"}
    assert look["lines"] == ("主将・堂安 国立で決勝弾", "0本だったシュートは●本に")
    via_lines = build_thumbnail(_config(), "x", tmp_path / "a.png", style="band", background=photo,
                                lines=look["lines"])
    via_arg = build_thumbnail(_config(), "x", tmp_path / "b.png", style="band", background=photo,
                              lines=tuple(look["lines"]), layout=look["layout"])
    classic = build_thumbnail(_config(), "x", tmp_path / "c.png", style="band", background=photo,
                              lines=tuple(look["lines"]))
    assert _same(via_lines, via_arg)
    assert not _same(via_lines, classic)


def test_名前だけの構図も読める():
    assert thumb.layout_spec({"thumbnail_layout": "face"}) == {"layout": "face"}
    assert thumb.layout_spec({"thumbnail_layout": "classic"}) is None
    assert thumb.layout_spec({}) is None


# ---------------------------------------------------------------- 構図ごとに描ける


@pytest.mark.parametrize("name", ["face", "scene", "number", "versus"])
@pytest.mark.parametrize("fx", [True, False])
def test_構図ごとに描ける(tmp_path, monkeypatch, name, fx):
    monkeypatch.setattr(thumbfx, "_segment", lambda tile: None)    # 切り抜きは別に見る
    spec = {"layout": name, "fx": fx}
    kw = {}
    if name == "number":
        spec["number"] = "●●位"
    if name == "versus":
        kw["photos"] = [_photo(tmp_path / "l.jpg", seed=0), _photo(tmp_path / "r.jpg", seed=1)]
        spec["names"] = ["ケイン", "シルトン"]
    path = _render(tmp_path, f"{name}_{fx}", spec, **kw)
    with Image.open(path) as image:
        assert image.size == SIZE
        # どの構図も同じ目印：下端に蛍光イエローの細い線
        r, g, b = image.convert("RGB").getpixel((SIZE[0] // 2, SIZE[1] - 3))
        assert r > 190 and g > 230 and b < 80


def test_作り込みを外すと絵が変わる(tmp_path, monkeypatch):
    monkeypatch.setattr(thumbfx, "_segment", lambda tile: None)
    photo = _photo(tmp_path / "p.jpg")
    on = _render(tmp_path, "on", {"layout": "face"}, photo=photo)
    off = _render(tmp_path, "off", {"layout": "face", "fx": False}, photo=photo)
    assert not _same(on, off)
    assert thumb.fx_options({"layout": "face", "fx": False})["on"] is False
    assert thumb.fx_options({"layout": "versus"})["tint"] == "right"
    assert thumb.fx_options({"layout": "number"})["rays"] is True
    assert thumb.fx_options({"layout": "face", "cutout": False})["cutout"] is False


def test_構図の左はぼかさない(tmp_path, monkeypatch):
    """**左がぼやけるのは禁止**（2026-09-20）。face の字の側は暗くするだけで、写真の縞は残る。"""
    monkeypatch.setattr(thumbfx, "_segment", lambda tile: None)
    path = _render(tmp_path, "face", {"layout": "face", "fx": False}, lines=("", ""))
    with Image.open(path) as image:
        row = [image.convert("L").getpixel((x, 40)) for x in range(0, 400)]
    # 縞（80px おきの黄色い線）が、ぼけずに段差として残っている
    jumps = sum(1 for a, b in zip(row, row[1:]) if abs(a - b) >= 6)
    assert jumps >= 4


def test_伏せ字は赤で描く(tmp_path, monkeypatch):
    monkeypatch.setattr(thumbfx, "_segment", lambda tile: None)
    path = _render(tmp_path, "num", {"layout": "number", "number": "●●位", "fx": False},
                   lines=("FIFAランキング", "日本代表"))
    with Image.open(path) as image:
        raw = image.convert("RGB").crop((40, 180, 700, 480)).tobytes()
    pixels = zip(raw[0::3], raw[1::3], raw[2::3])
    assert sum(1 for r, g, b in pixels if r > 190 and g < 60 and b < 70) > 5000


# ---------------------------------------------------------------- 壊れた指定は止める


def test_構図の名前の誤りは止める():
    assert "分かりません" in thumb.layout_problems({"layout": "closeup"})[0]
    assert thumb.layout_problems({"layout": "classic"}) == []
    assert thumb.layout_problems({}) == []


def test_構図に要る項目が無ければ止める(tmp_path):
    wide = _photo(tmp_path / "w.jpg")
    tall = _photo(tmp_path / "t.jpg", size=(600, 900))
    assert any("thumbnail.photo" in p for p in thumb.layout_problems({"layout": "face"}))
    assert any("横に広くありません" in p for p in thumb.layout_problems({"layout": "scene", "photo": tall}))
    assert thumb.layout_problems({"layout": "scene", "photo": wide}) == []
    assert any("thumbnail.number" in p for p in thumb.layout_problems({"layout": "number", "photo": wide}))
    assert any("数字も伏せ字" in p
               for p in thumb.layout_problems({"layout": "number", "photo": wide, "number": "たくさん"}))
    assert any("2枚" in p for p in thumb.layout_problems({"layout": "versus", "photos": [wide]}))
    assert any("[左, 右]" in p for p in thumb.layout_problems(
        {"layout": "versus", "photos": [wide, wide], "names": ["ケイン"]}))
    assert any("crest_main" in p for p in thumb.layout_problems(
        {"layout": "face", "photo": wide, "crest_main": ["アーセナル"]}))
    assert any("board" in p for p in thumb.layout_problems(
        {"layout": "face", "photo": wide, "board": "assets/stats/x.png"}))
    assert any("side" in p for p in thumb.layout_problems({"layout": "face", "photo": wide, "side": "up"}))
    assert any("fx" in p for p in thumb.layout_problems({"layout": "face", "photo": wide, "fx": "no"}))
    assert any("alt" in p for p in thumb.layout_problems(
        {"photo": wide, "alt": [{"layout": "number"}]}))


def test_draftの検証が構図の不備で止まる():
    notes = SimpleNamespace(thumbnail={"layout": "number", "photo": ""})
    problems = research._check_thumbnail_layout(notes)
    assert problems and all("構図 number" in p for p in problems)


def test_取材メモの構図だけを台本へ持ち越す():
    t = {"layout": "versus", "photos": ["a", "b"], "names": ["A", "B"], "line1": "x", "fx": False}
    assert thumb.notes_layout(t) == {"layout": "versus", "names": ["A", "B"], "fx": False}
    assert thumb.notes_layout({"line1": "x"}) is None
    assert thumb.notes_layout({"layout": "classic", "side": "left"}) is None


def test_案ごとに構図を替えられる():
    meta = {"thumbnail_line1": "a", "thumbnail_alt": [{"layout": {"layout": "number", "number": "3"}}]}
    found = thumb.variants(meta, "題")
    assert found[0]["layout"] is None
    assert found[1]["layout"] == {"layout": "number", "number": "3"}
    assert found[1]["lines"].layout == found[1]["layout"]


# ---------------------------------------------------------------- 人物の切り抜き


def _body_mask(size=(400, 400)) -> Image.Image:
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.ellipse([150, 40, 250, 150], fill=255)            # 頭
    d.rectangle([80, 150, 320, 400], fill=255)          # 肩から下
    return m


def test_抜けの悪い形は使わない():
    assert thumbfx.usable(_body_mask())
    neck = Image.new("L", (400, 400), 0)
    ImageDraw.Draw(neck).ellipse([150, 40, 250, 160], fill=255)        # 頭だけ（体が抜けた）
    assert not thumbfx.usable(neck)
    narrow = Image.new("L", (400, 400), 0)
    ImageDraw.Draw(narrow).rectangle([170, 40, 230, 400], fill=255)    # 首から下が頭と同じ幅
    assert not thumbfx.usable(narrow)
    assert not thumbfx.usable(Image.new("L", (400, 400), 0))
    # 顔の真ん中が人の形の外にあれば、別の人を抜いている
    assert not thumbfx.usable(_body_mask(), face=(10, 10, 40, 40))
    assert thumbfx.usable(_body_mask(), face=(170, 60, 60, 60))


def test_切り抜きが無くても描ける(tmp_path, monkeypatch):
    """rembg が入っていない環境（CI）では、切り抜かずに描く。"""
    monkeypatch.setattr(thumbfx, "_segment", lambda tile: None)
    monkeypatch.setattr(thumbfx, "_MEMO", {})
    monkeypatch.setattr(thumbfx, "CACHE", tmp_path / "cache")
    photo = _photo(tmp_path / "p.jpg")
    with_cut = _render(tmp_path, "a", {"layout": "face"}, photo=photo)
    without = _render(tmp_path, "b", {"layout": "face", "cutout": False}, photo=photo)
    assert _same(with_cut, without)
    assert not (tmp_path / "cache").exists()


def test_切り抜けたら前に浮かせて控える(tmp_path, monkeypatch):
    monkeypatch.setattr(thumbfx, "_MEMO", {})
    monkeypatch.setattr(thumbfx, "CACHE", tmp_path / "cache")
    calls = []

    def fake(tile):
        calls.append(tile.size)
        return _body_mask(tile.size)

    monkeypatch.setattr(thumbfx, "_segment", fake)
    monkeypatch.setattr(thumb, "_main_face", lambda image: None)
    photo = _photo(tmp_path / "p.jpg")
    cut = _render(tmp_path, "a", {"layout": "face"}, photo=photo)
    plain = _render(tmp_path, "b", {"layout": "face", "cutout": False}, photo=photo)
    assert not _same(cut, plain)
    assert len(list((tmp_path / "cache").glob("cutout_*.png"))) == 1
    # 2回目は控えを読む（rembg を呼ばない）
    monkeypatch.setattr(thumbfx, "_MEMO", {})
    again = _render(tmp_path, "c", {"layout": "face"}, photo=photo)
    assert len(calls) == 1 and _same(cut, again)


# ---------------------------------------------------------------- 同じ構図が続いたら知らせる


def _ledger(tmp_path, builds_and_layouts):
    research_dir = tmp_path / "research"
    research_dir.mkdir()
    entries = []
    for index, (build, layout) in enumerate(builds_and_layouts):
        thumb_block = {"line1": "x"} if layout is None else {"line1": "x", "layout": layout}
        (research_dir / f"{build}.yaml").write_text(
            json.dumps({"thumbnail": thumb_block}, ensure_ascii=False), encoding="utf-8")
        entries.append({"build": build, "publish_at": f"2026-10-0{index + 1}T09:00:00Z"})
        entries.append({"build": f"{build}_short", "publish_at": f"2026-10-0{index + 1}T09:30:00Z"})
    ledger = tmp_path / "posted.json"
    ledger.write_text(json.dumps(entries), encoding="utf-8")
    return ledger, research_dir


def test_同じ構図が3回続いたら知らせる(tmp_path):
    ledger, rdir = _ledger(tmp_path, [("a", None), ("b", "face"), ("c", "face")])
    notes = SimpleNamespace(stem="d", thumbnail={"layout": "face"})
    hints = research._advise_layout_streak(notes, ledger, rdir)
    assert len(hints) == 1 and "「face」が3回" in hints[0] and "b→c→d" in hints[0]
    other = SimpleNamespace(stem="d", thumbnail={"layout": "number"})
    assert research._advise_layout_streak(other, ledger, rdir) == []


def test_書かない回はclassicとして数える(tmp_path):
    ledger, rdir = _ledger(tmp_path, [("a", "face"), ("b", None), ("c", None)])
    notes = SimpleNamespace(stem="d", thumbnail={})
    assert "「classic」が3回" in research._advise_layout_streak(notes, ledger, rdir)[0]


def test_投稿済みの回はその手前までで数える(tmp_path):
    ledger, rdir = _ledger(tmp_path, [("a", "face"), ("b", "number"), ("c", "face"), ("d", "face")])
    notes = SimpleNamespace(stem="c", thumbnail={"layout": "face"})
    assert research._advise_layout_streak(notes, ledger, rdir) == []


# ---------------------------------------------------------------- 字の割り方


def test_2行は語の途中で割らない():
    assert thumb._natural_split("最後のパスを託した相手は●●")[0] == ("最後のパスを", "託した相手は●●")
    assert thumb._natural_split("メッシ 代表最後の夜")[0] == ("メッシ", "代表最後の夜")
    assert thumb._natural_split("シルトンより●年早く並んだ")[0][0] == "シルトンより"


def test_切る位置が変われば控えも別にする():
    """写真と大きさだけで鍵を作ると、寄せ方を変えたときに前の形を読んで縁取りがずれた（10-08）。"""
    a = Image.new("RGB", (64, 36), (10, 20, 30))
    b = a.copy()
    b.putpixel((5, 5), (200, 0, 0))
    assert thumbfx.key_of(a) == thumbfx.key_of(a.copy())
    assert thumbfx.key_of(a) != thumbfx.key_of(b)
    assert thumbfx.key_of(a, "versus", 0) != thumbfx.key_of(a, "versus", 1)
