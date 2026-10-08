from chiso import script


def _d(**line):
    return {"title": "t", "sections": [{"title": "見立て", "lines": [dict({"語り": "a"}, **line), {"語り": "b"}]}]}


def test_bubble_and_icon_only_on_that_line():
    sc = script.parse(_d(bubble="ひとこと", icon="crown"))
    assert sc.lines[0].bubble and sc.lines[0].icon == "crown"
    assert sc.lines[1].bubble is None and sc.lines[1].icon is None


def test_compare_is_a_figure_type():
    sc = script.parse(_d(figure={"type": "compare", "people": [["A", "a.jpg"]]}))
    assert "compare" in sc.lines[0].figure


def test_format_yen():
    from chiso.extras import format_yen
    assert format_yen(10_000_000_000) == "約100億円"
    assert format_yen(250_000_000) == "約2.5億円"
    assert format_yen(300_000_000) == "約3億円"
    assert format_yen(30_000_000) == "約3,000万円"
    assert format_yen(5000) == "約5,000円"


def test_money_needs_basis():
    import pytest
    from chiso import script
    def sc(fig):
        return {"title": "t", "sections": [{"title": "一", "lines": [{"語り": "a", "figure": fig}]}]}
    with pytest.raises(script.ScriptError):
        script.parse(sc({"type": "money", "then": "160万リーヴル", "yen": 1e10}))
    ok = script.parse(sc({"type": "money", "then": "160万リーヴル", "yen": 1e10, "basis": "日雇いの年収で置き換え"}))
    assert '"money"' in ok.lines[0].figure


def test_still_background_has_no_motion():
    """背景を動かさない（10-06）。止めた絵は拡大率も位置も時刻に依らない。"""
    from chiso import video
    f = video.motion_filter("still", 12.0, (1920, 1080))
    assert "t+" not in f and "eval=frame" not in f
    assert f.startswith("scale=1920:1080")
    assert "eval=frame" in video.motion_filter("in", 12.0, (1920, 1080))


def test_loudnorm_filter_falls_back_when_not_measurable(tmp_path):
    """測れないとき（ffmpeg が無い・壊れた音）は、1回で掛ける形に戻る。"""
    from chiso import video
    f = video.loudnorm_filter("ffmpeg-does-not-exist", tmp_path / "none.wav")
    assert f.startswith("loudnorm=" + video.LOUD)


def test_still_frames_makes_each_picture_once(tmp_path, monkeypatch):
    """同じ絵が何度出ても、止まった背景は1回だけ作る（10-09 並列で同じ一時ファイルを奪い合って落ちた）。"""
    from chiso import video
    calls = []
    def fake_plate(ffmpeg, painter, pic, work, size):
        calls.append(pic)
        p = work / f"plate_{pic}.png"
        from PIL import Image
        Image.new("RGB", (8, 8)).save(p)
        return p
    monkeypatch.setattr(video, "_plate", fake_plate)
    runs = [video.Run(picture=x, start=i, end=i + 1, section=0) for i, x in enumerate(["a", "b", "a", "b", "a"])]
    video.still_frames("ffmpeg", None, runs, tmp_path, 30, (8, 8), workers=4)
    assert sorted(calls) == ["a", "b"]
