"""シリーズの回のサムネ：大きい字・エンブレム・補足の吹き出し（2026-10-15）。

参考2チャンネル（pltalkshowjp・crack-football）の実測に合わせる。**効かせるのは「series が付いた回で、
クラブ紹介でなく、構図が face・scene・number・versus」のときだけ。**

- クラブ紹介・classic・series なし・`bold: false` の回は、画素まで今と同じ
- 主役の語は画面高さの約22%以上（字数が多ければ縮むが下限は BOLD_MAIN_MIN）
- エンブレムは顔・文字と重ならない（左下、だめなら右下）
- 吹き出し（thumbnail.callouts）は2個まで・12字まで・空でない・答えを入れない
"""

from pathlib import Path
from types import SimpleNamespace

import pytest
from PIL import Image, ImageChops, ImageDraw

from src import research, thumbfx
from src import thumbnail as thumb
from src.config import load_config
from src.thumbnail import SIZE, build_thumbnail

MAIN_MIN = int(SIZE[1] * 0.22)          # 画面高さの22%＝158px


def _config():
    config = load_config()
    config.video.background = "assets/backgrounds/stadium.png"
    return config


def _photo(path: Path, size=(1600, 900), seed: int = 0) -> str:
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


@pytest.fixture(autouse=True)
def _no_models(monkeypatch):
    monkeypatch.setattr(thumbfx, "_segment", lambda tile: None)      # 切り抜きは別
    monkeypatch.setattr(thumb, "_main_face", lambda image: None)     # 顔の検出は各テストで決める
    monkeypatch.setattr(thumb, "_face_rects", lambda image: [])


def _render(tmp_path, name, spec, lines=("アンダーソン", "●●●●回触った"), photos=None, **kw):
    photo = kw.pop("photo", None) or _photo(tmp_path / f"{name}_p.jpg")
    if spec.get("layout") == "versus":
        photos = photos or [_photo(tmp_path / f"{name}_l.jpg", seed=0), _photo(tmp_path / f"{name}_r.jpg", seed=1)]
    return build_thumbnail(_config(), lines[0], tmp_path / f"{name}.png", style="band",
                           background=photo, lines=lines, layout=spec, photos=photos or [], **kw)


def _meta(photo, layout, **extra):
    return {"thumbnail_line1": "アンダーソン", "thumbnail_line2": "●●●●回触った",
            "thumbnail_photo": photo, "thumbnail_layout": layout, **extra}


# ---------------------------------------------------------------- 判定は1か所


@pytest.mark.parametrize("layout", ["face", "scene", "number", "versus"])
def test_シリーズの回だけ大きい字になる(layout):
    meta = {"series": "有名選手の紹介", "thumbnail_layout": {"layout": layout}}
    assert thumb.series_style(meta) is True
    assert thumb.series_style({"thumbnail_layout": {"layout": layout}}) is False       # series なし（ニュース）
    assert thumb.series_style({"series": "", "thumbnail_layout": layout}) is False
    assert thumb.series_style({"series": "有名選手の紹介"}) is False                   # classic（layout を書かない）
    assert thumb.series_style({"series": "有名選手の紹介", "thumbnail_layout": "classic"}) is False


@pytest.mark.parametrize("series", ["プレミアリーグチーム紹介", "ラ・リーガチーム紹介", "プレミアリーグ20クラブ紹介"])
def test_クラブ紹介は対象外(series):
    assert thumb.series_style({"series": series, "thumbnail_layout": {"layout": "face"}}) is False


def test_boldをfalseと書けばその回だけ今の見た目に戻る():
    meta = {"series": "比べる", "thumbnail_layout": {"layout": "versus", "bold": False}}
    assert thumb.series_style(meta) is False
    assert thumb.from_meta(dict(meta, thumbnail_photo="x"), "題")["layout"] == {"layout": "versus", "bold": False}
    on = thumb.from_meta({"series": "比べる", "thumbnail_layout": {"layout": "versus"}}, "題")
    assert on["layout"] == {"layout": "versus", "bold": True}
    assert on["lines"].layout["bold"] is True


def test_crest_mainとboardの回は対象外():
    base = {"series": "比べる", "thumbnail_layout": {"layout": "face"}}
    assert thumb.series_style(dict(base, thumbnail_crest_main=["アーセナル"])) is False
    assert thumb.series_style(dict(base, thumbnail_board="assets/stats/x.png")) is False


def test_取材メモのboldとcalloutsは台本へ持ち越す():
    t = {"layout": "face", "photo": "p", "bold": False, "callouts": ["金融費用は？"], "line1": "x"}
    assert thumb.notes_layout(t) == {"layout": "face", "bold": False, "callouts": ["金融費用は？"]}
    # クラブ紹介でも持ち越しは同じ（効かせるかは series_style が決める）
    assert thumb.notes_layout({"line1": "x", "callouts": ["a"]}) is None


# ---------------------------------------------------------------- 画素まで今と同じ


@pytest.mark.parametrize("layout", ["face", "scene", "number", "versus"])
def test_クラブ紹介とseriesなしと_bold_falseは画素まで今と同じ(tmp_path, layout):
    photo = _photo(tmp_path / "p.jpg")
    spec = {"layout": layout, "number": "●●位", "names": ["A", "B"], "callouts": ["どこで赤字に"]}
    base = thumb.from_meta(_meta(photo, spec), "題")                     # series なし
    assert base["layout"] == spec
    outs = {}
    for name, extra in (("none", {}),
                        ("club", {"series": "ラ・リーガチーム紹介"}),
                        ("club2", {"series": "プレミアリーグチーム紹介"}),
                        ("off", {"series": "比べる", "thumbnail_layout": dict(spec, bold=False)})):
        look = thumb.from_meta({**_meta(photo, spec), **extra}, "題")
        assert "bold" not in (look["layout"] or {}) or look["layout"]["bold"] is False
        outs[name] = build_thumbnail(
            _config(), "題", tmp_path / f"{name}.png", style="band", background=photo,
            lines=look["lines"], crests=["アーセナル"], photos=[photo, photo] if layout == "versus" else [])
    for name in ("club", "club2", "off"):
        assert _same(outs["none"], outs[name]), name
    # 吹き出しは bold のときだけ（series なしの絵には出ない）。出ていれば bold のほうと絵が変わる
    bold = build_thumbnail(
        _config(), "題", tmp_path / "bold.png", style="band", background=photo,
        lines=thumb.from_meta({**_meta(photo, spec), "series": "比べる"}, "題")["lines"],
        crests=["アーセナル"], photos=[photo, photo] if layout == "versus" else [])
    assert not _same(outs["none"], bold)


def test_classicとseries付きでも画素まで今と同じ(tmp_path):
    photo = _photo(tmp_path / "p.jpg")
    a = thumb.from_meta({"thumbnail_line1": "a", "thumbnail_line2": "b", "thumbnail_photo": photo}, "題")
    b = thumb.from_meta({"thumbnail_line1": "a", "thumbnail_line2": "b", "thumbnail_photo": photo,
                         "series": "有名選手の紹介"}, "題")
    assert a["layout"] is None and b["layout"] is None and type(b["lines"]) is tuple
    x = build_thumbnail(_config(), "題", tmp_path / "x.png", style="band", background=photo, lines=a["lines"])
    y = build_thumbnail(_config(), "題", tmp_path / "y.png", style="band", background=photo, lines=b["lines"])
    assert _same(x, y)


# ---------------------------------------------------------------- 主役の語の大きさ


def test_faceの主役は画面高さの22パーセント以上(tmp_path):
    _render(tmp_path, "f", {"layout": "face", "bold": True})
    r = thumb.bold_report()
    assert r["main_size"] >= MAIN_MIN and r["main_size"] <= 200
    assert r["sub_size"] <= 72                  # 補足は画面高さの約10%まで
    assert r["sub_size"] < r["main_size"]


def test_sceneの主役は画面高さの22パーセント以上(tmp_path):
    _render(tmp_path, "s", {"layout": "scene", "bold": True}, lines=("ブライトン本拠地", "席が●●●増えた"))
    r = thumb.bold_report()
    assert r["main_size"] >= MAIN_MIN
    assert r["sub_size"] <= 72


def test_numberの主役は画面高さの22パーセント以上(tmp_path):
    _render(tmp_path, "n", {"layout": "number", "number": "49試合", "bold": True},
            lines=("リーグ戦で負けなかった", "アーセナルの上にある記録"))
    assert thumb.bold_report()["main_size"] >= MAIN_MIN
    _render(tmp_path, "n2", {"layout": "number", "number": "●●●●万ポンド", "bold": True},
            lines=("チェルシーのユニフォーム契約", "途中で切った2度の違約金は"))
    assert thumb.bold_report()["main_size"] >= MAIN_MIN


def test_versusの主役は2行まで大きく出る(tmp_path):
    _render(tmp_path, "v", {"layout": "versus", "bold": True, "names": ["バレバ", "カマラ"]},
            lines=("バレバとカマラ", "差は●●●分"))
    r = thumb.bold_report()
    assert r["main_size"] >= MAIN_MIN
    assert r["sub_size"] <= 72


def test_字数が多ければ縮むが下限より小さくならない(tmp_path):
    short = "●●●回触った"
    long = "リーグ戦で一度も負けなかったのはどのクラブか"
    _render(tmp_path, "a", {"layout": "face", "bold": True}, lines=("名前", short))
    big = thumb.bold_report()["main_size"]
    _render(tmp_path, "b", {"layout": "face", "bold": True}, lines=("名前", long))
    small = thumb.bold_report()["main_size"]
    assert thumb.BOLD_MAIN_MIN <= small < big


def test_bold_の主役は今の見た目より大きい(tmp_path):
    """今の face の主役は156pxまで（字数が多いと60〜90px）。8字なら bold はそれより大きい。"""
    _render(tmp_path, "b", {"layout": "face", "bold": True})
    assert thumb.bold_report()["main_size"] > 156


def test_幅に収まらない長い字は今までどおり縮める(tmp_path):
    _render(tmp_path, "w", {"layout": "scene", "bold": True},
            lines=("a", "これはとても長い一行で画面の幅にどうしても入りきらないくらい長い" * 2))
    assert thumb.bold_report()["main_size"] == thumb.BOLD_MAIN_MIN


# ---------------------------------------------------------------- エンブレム


def _overlap(a, b) -> bool:
    return thumb._inter(a, b) > 0


@pytest.mark.parametrize("layout", ["face", "scene", "number"])
def test_エンブレムは左下に大きく置く(tmp_path, layout):
    kw = {"number": "49試合"} if layout == "number" else {}
    _render(tmp_path, layout, {"layout": layout, "bold": True, **kw}, crests=["アーセナル"],
            lines=("リーグ戦で負けなかった", "記録"))
    crest = thumb.bold_report()["crest"]
    assert crest is not None
    height = crest[3] - crest[1]
    assert SIZE[1] * 0.12 <= height <= SIZE[1] * 0.25 + 1      # 画面高さの12〜25%（今までの180pxを上回らない）
    assert crest[0] < SIZE[0] / 3 and crest[3] > SIZE[1] * 0.8       # 左下


@pytest.mark.parametrize("layout", ["face", "scene", "number"])
def test_エンブレムが顔の枠と重ならない(tmp_path, monkeypatch, layout):
    left_face = (0, 380, 420, 700)            # 左下に顔がある写真
    monkeypatch.setattr(thumb, "_face_rects", lambda image: [left_face])
    kw = {"number": "49試合"} if layout == "number" else {}
    _render(tmp_path, layout, {"layout": layout, "bold": True, **kw}, crests=["アーセナル"],
            lines=("リーグ戦で負けなかった", "記録"))
    r = thumb.bold_report()
    assert r["crest"] is not None
    assert not _overlap(r["crest"], left_face)
    for rect in r["text"]:
        assert not _overlap(r["crest"], rect)
    assert r["crest"][0] > SIZE[0] / 2        # 顔が左下なら右下へ回る


def test_faceで顔が左のときエンブレムは右下(tmp_path):
    _render(tmp_path, "l", {"layout": "face", "side": "left", "bold": True}, crests=["アーセナル"])
    crest = thumb.bold_report()["crest"]
    assert crest is not None and crest[0] > SIZE[0] / 2 and crest[3] > SIZE[1] * 0.8


def test_エンブレムが無ければ出さない(tmp_path):
    _render(tmp_path, "n", {"layout": "face", "bold": True}, crests=[])
    assert thumb.bold_report()["crest"] is None
    _render(tmp_path, "n2", {"layout": "face", "bold": True}, crests=["存在しないクラブ名"])
    assert thumb.bold_report()["crest"] is None


def test_エンブレムは文字の下に入りきらなければ縮めるが86px未満は出さない(tmp_path):
    _render(tmp_path, "c", {"layout": "face", "bold": True}, crests=["アーセナル"])
    crest = thumb.bold_report()["crest"]
    assert crest[3] - crest[1] >= thumb.BOLD_CREST_MIN


# ---------------------------------------------------------------- 吹き出し


def test_吹き出しは顔と文字を避けて置く(tmp_path, monkeypatch):
    face = (700, 40, 1100, 480)
    monkeypatch.setattr(thumb, "_face_rects", lambda image: [face])
    _render(tmp_path, "c", {"layout": "face", "bold": True, "callouts": ["どこで消えた", "ボールに触れず"]},
            crests=["アーセナル"])
    r = thumb.bold_report()
    assert 1 <= len(r["callouts"]) <= 2
    for box in r["callouts"]:
        assert not _overlap(box, face)
        for rect in r["text"] + [r["crest"]]:
            assert not _overlap(box, rect)
    if len(r["callouts"]) == 2:
        assert not _overlap(*r["callouts"])


def test_吹き出しは出る(tmp_path):
    a = _render(tmp_path, "a", {"layout": "scene", "bold": True}, lines=("本拠地", "席が増えた"))
    b = _render(tmp_path, "b", {"layout": "scene", "bold": True, "callouts": ["なぜ増席できた？"]},
                lines=("本拠地", "席が増えた"))
    assert not _same(a, b)
    assert len(thumb.bold_report()["callouts"]) == 1


def test_吹き出しはboldのときだけ出る(tmp_path):
    a = _render(tmp_path, "a", {"layout": "scene"}, lines=("本拠地", "席が増えた"))
    b = _render(tmp_path, "b", {"layout": "scene", "callouts": ["なぜ増席できた？"]}, lines=("本拠地", "席が増えた"))
    assert _same(a, b)


def test_吹き出しの検証():
    assert thumb.callout_problems(None) == [] and thumb.callout_problems([]) == []
    assert thumb.callout_problems(["金融費用は？", "どこで赤字に"]) == []
    assert any("2個まで" in p for p in thumb.callout_problems(["a", "b", "c"]))
    assert any("13字" in p for p in thumb.callout_problems(["あ" * 13]))
    assert thumb.callout_problems(["あ" * 12]) == []                       # 12字ちょうどは通る
    assert any("空" in p for p in thumb.callout_problems(["", "a"]))
    assert any("空" in p for p in thumb.callout_problems(["  "]))
    assert any("並び" in p for p in thumb.callout_problems("金融費用は？"))


def test_draftの検証が吹き出しの不備で止まる(tmp_path):
    wide = _photo(tmp_path / "w.jpg")
    base = {"layout": "number", "photo": wide, "number": "●.●倍"}
    assert thumb.layout_problems(dict(base, callouts=["a", "b"])) == []
    assert any("2個まで" in p for p in thumb.layout_problems(dict(base, callouts=["a", "b", "c"])))
    assert any("12字" in p for p in thumb.layout_problems(dict(base, callouts=["あ" * 20])))
    assert any("空" in p for p in thumb.layout_problems(dict(base, callouts=[""])))
    assert any("bold" in p for p in thumb.layout_problems(dict(base, bold="yes")))


def test_伏せ字の答えが吹き出しに入っていたら止まる():
    thumb_notes = {"layout": "number", "number": "●.●倍", "line2": "金融費用は", "callouts": ["4.5倍の差"]}
    notes = SimpleNamespace(thumbnail=thumb_notes, answer="営業の黒字の4.5倍が金融費用", takeaway="")
    problems = research._check_thumbnail_layout(notes)
    assert any("答え" in p and "4.5倍の差" in p for p in problems)
    # 答えに無い数字・言い回しは通る
    ok = SimpleNamespace(thumbnail=dict(thumb_notes, callouts=["どこで赤字に"]), answer="4.5倍", takeaway="")
    assert not any("答え" in p for p in research._check_thumbnail_layout(ok))
    # 伏せていない（● が無い）サムネなら、数字を言ってもよい
    open_ = SimpleNamespace(thumbnail={"layout": "number", "number": "49試合", "callouts": ["49試合の中身"]},
                            answer="49試合", takeaway="")
    assert not any("答え" in p for p in research._check_thumbnail_layout(open_))
    # 見立て（takeaway）の数字も答えに数える
    tk = SimpleNamespace(thumbnail=thumb_notes, answer="", takeaway="倍率は4.5倍")
    assert any("答え" in p for p in research._check_thumbnail_layout(tk))


def test_callout_leaksの突き合わせ():
    assert thumb.callout_leaks(["47分の差"], "差は47分")
    assert thumb.callout_leaks(["全角４７分"], "47分")                       # 全角の数字も同じ数
    assert thumb.callout_leaks(["金融費用が膨らんだ"], "金融費用が膨らんだ")      # 4字以上の言い回し
    assert not thumb.callout_leaks(["どこで赤字に"], "営業の黒字の4.5倍")
    assert not thumb.callout_leaks([], "")
