"""10-08 の整理（見本の台本の通し確認・速さ）で直したもののテスト。"""
import json
from types import SimpleNamespace as NS

from PIL import Image, ImageFont

from chiso import check, figures, script, video


# --- 止まった背景（bg_motion: false）：動画にせず画像の並びにする ------------------------------

def test_blend_matches_xfade_endpoints():
    a, b = Image.new("RGB", (40, 4), (0, 0, 0)), Image.new("RGB", (40, 4), (200, 100, 50))
    for kind in ("fade", "smoothleft"):
        assert video.blend(a, b, kind, 1.0).tobytes() == a.tobytes()          # 進み 1 は前の絵だけ
        assert video.blend(a, b, kind, 0.0).tobytes() == b.tobytes()          # 0 は新しい絵だけ
    mid = video.blend(a, b, "smoothleft", 0.5)
    assert mid.getpixel((0, 0)) == (0, 0, 0) and mid.getpixel((39, 0))[0] > 150   # 新しい絵は右から入る
    assert video.blend(a, b, "fade", 0.5).getpixel((0, 0)) == (100, 50, 25)


def test_still_frames_hold_and_cross(tmp_path, monkeypatch):
    plates = {}

    def fake_plate(ffmpeg, painter, pic, work, size):
        p = work / f"plate_{pic}.png"
        if not p.exists():
            Image.new("RGB", (8, 4), {"a": (0, 0, 0), "b": (90, 90, 90), "c": (200, 0, 0)}[pic]).save(p)
        plates[pic] = p
        return p
    monkeypatch.setattr(video, "_plate", fake_plate)
    runs = [video.Run("a", 0.0, 2.0, 0), video.Run("b", 2.0, 5.0, 0), video.Run("c", 5.0, 9.0, 1)]
    items = video.still_frames("ffmpeg", None, runs, tmp_path, 30, (8, 4))
    assert abs(sum(d for _, d in items) - 9.0) < 1e-6                       # 長さは変わらない
    assert items[0] == (plates["a"], 2.0)
    mixes = [p for p, _ in items if p.name.startswith("mix_")]
    assert len(mixes) == 2 * (round(video.XFADE * 30) - 1)                   # 替わり目ごとに17コマ
    assert all(p.exists() for p in mixes)


# --- 見本の台本の通し確認で見つかった組み合わせ ------------------------------------------------

def _sc(lines, **more):
    return script.parse({"title": "t", "sections": [{"title": "a", "background": "bg.jpg", "lines": lines}], **more})


def test_detail_ends_the_figure():
    fig = {"type": "bars", "title": "x", "bars": [["a", 1], ["b", 2]]}
    sc = _sc([{"語り": "図。", "figure": fig}, {"語り": "絵の一部。", "detail": {"box": [0, 0, 0.5, 0.5]}},
              {"語り": "戻らない。"}])
    assert sc.lines[0].figure and sc.lines[1].figure is None and sc.lines[2].figure is None


def test_combo_rules():
    fig = {"type": "bars", "title": "x", "bars": [["a", 1]]}
    sc = _sc([{"語り": "図。", "figure": fig}, {"語り": "挿絵。", "icon": "coins"},
              {"聞き": "寄り。", "reaction": {"number": "1人"}, "icon": "coins", "figure": None}])
    w = check.combo_rules(sc)
    assert any("2行目" in x and "挿絵" in x for x in w)
    assert any("3行目" in x and "寄り" in x for x in w)


def test_era_words_are_not_places():
    sc = script.parse({"title": "t", "sections": [{"title": "a", "lines": [
        {"語り": "江戸時代の本に出てきます。"}, {"語り": "江戸の町です。"}]}]}, places={"江戸": (139.7, 35.7)})
    assert sc.lines[0].place is None and sc.lines[1].place[0] == "江戸"


def test_map_labels_avoid_each_other():
    f = ImageFont.load_default(28)
    taken = [(90, 90, 110, 110)]
    first = figures._label_spot(f, "清洲城", 100, 100, taken)
    taken.append((90, 100, 110, 120))
    second = figures._label_spot(f, "熱田", 100, 110, taken)
    assert first[2] == "lm" and second[2] != "lm"                             # 2つ目は右に置くと重なるので別の所


def test_small_map_bounds_are_tight():
    spec = figures.with_places({"places": [["a", 136.84, 35.22], ["b", 136.98, 35.06]], "route": ["a", "b"]})
    lon0, lon1, lat0, lat1 = spec["bounds"]
    assert lon1 - lon0 < 1.0                                                  # 前は最低でも経度3度の幅
    big = figures.with_places({"places": [["a", 0.0, 40.0], ["b", 10.0, 50.0]]})
    assert big["bounds"] == [-2.5, 12.5, 36.5, 53.5]                          # 広い地図は前と同じ


def test_soft_shadow_is_reused_and_same_as_before():
    from PIL import ImageDraw, ImageFilter
    a = figures.soft_shadow((200, 100), (10, 10, 120, 80), 12, 140, 8)
    assert figures.soft_shadow((200, 100), (10, 10, 120, 80), 12, 140, 8) is a      # 2回目はぼかさない
    ref = Image.new("RGBA", (200, 100), (0, 0, 0, 0))
    ImageDraw.Draw(ref).rounded_rectangle([10, 10, 120, 80], radius=12, fill=(0, 0, 0, 140))
    assert ref.filter(ImageFilter.GaussianBlur(8)).tobytes() == a.tobytes()          # 前の描き方と画素まで同じ


def test_text_room_warns_when_reactor_takes_the_text_side(tmp_path):
    from chiso import thumb
    t = {"layout": "face", "image": "x.jpg", "crop": [0, 0, 10, 10], "name": "n", "main": "m"}
    assert thumb.text_room(t, {}, tmp_path) == []                                   # reactor が無ければ広い
    narrow = dict(t, _reactor=(0, 200, 560, 720))                         # 左に大きな顔
    from unittest import mock
    with mock.patch.object(thumb, "_prepare", lambda t, c, a: t):
        assert thumb.text_room(narrow, {}, tmp_path)


def test_qc_reads_main_srt_for_draft(tmp_path, monkeypatch):
    from chiso import qc
    (tmp_path / "x.srt").write_text("1\n00:00:00,000 --> 00:00:02,000\nあ\n", encoding="utf-8")
    seen = {}
    monkeypatch.setattr(qc, "analyze", lambda ff, v: (qc.Report(duration=3.0), []))
    monkeypatch.setattr(qc, "sheet", lambda frames, sections, font: Image.new("RGB", (4, 4)))
    sc = NS(path=tmp_path / "x.yaml", lines=[NS(text="あ", section=0)], sections=[NS(title="t")])
    lines = qc.run("ffmpeg", sc, tmp_path / "x_draft.mp4", tmp_path / "q.png", tmp_path / "q.md")
    assert not any("見つかりません" in l for l in lines)
