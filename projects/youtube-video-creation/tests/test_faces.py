"""写真の顔の位置を機械で見る（2026-10-03）。

冒頭やショートで頭のてっぺんが切れる（09-29「本編の顔がキレてる」）、
反応の白い箱が顎にかかる（10-03 久保の結婚のショート）を、人の目の前に機械で拾う。
切り方の計算と credits の複製は OpenCV なしで確かめる。顔の検出と板の判定は
OpenCV が要るので、入っていない環境では飛ばす（`pytest.importorskip("cv2")`）。
"""
import json
import sys
from pathlib import Path

import pytest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src import faces  # noqa: E402

PHOTO = ROOT / "assets/images/20261003_kubo_marriage/01.jpg"   # 800x600、久保の上半身（gitignore。無ければ飛ばす）


def _ratio(crop):
    l, t, r, b = crop
    return (r - l) / (b - t)


def _moved(face, crop):
    return (face[0] - crop[0], face[1] - crop[1], face[2], face[3])


# ---- OpenCV なしで確かめるもの ------------------------------------------------

def test_cv2が無くても落ちずに検出できないを返す(monkeypatch):
    monkeypatch.setattr(faces, "cv2", None)
    assert faces.available() is False
    assert faces.find_faces(Image.new("RGB", (64, 64))) == []
    assert faces.main_face(Image.new("RGB", (64, 64))) is None
    assert faces.overlay_on_face(Image.new("RGB", (64, 64)), (0, 0, 32, 32))["hit"] is None


def test_16対9と9対16の縦横比で切る():
    face = (336, 80, 121, 121)
    wide = faces.crop_box((800, 600), 16 / 9, face)
    tall = faces.crop_box((800, 600), 9 / 16, face)
    assert wide[2] - wide[0] == 800 and abs(_ratio(wide) - 16 / 9) < 0.01
    assert tall[3] - tall[1] == 600 and abs(_ratio(tall) - 9 / 16) < 0.01
    # 縦は顔を左右の真ん中へ
    assert abs((tall[0] + tall[2]) / 2 - (face[0] + face[2] / 2)) <= 1
    # 写真の外へははみ出さない
    for crop in (wide, tall):
        assert crop[0] >= 0 and crop[1] >= 0 and crop[2] <= 800 and crop[3] <= 600


def test_頭のてっぺんの上に余白を残して切る():
    """横長の写真の下のほうに顔がある 16:9。顔を上から1/3へ寄せつつ、頭の上を残す。"""
    face = (900, 700, 200, 200)
    crop = faces.crop_box((2000, 1500), 16 / 9, face)
    head = faces.head_box(face)
    assert crop[1] <= head[1]                        # 頭のてっぺんが入る
    assert faces.cut_edges((crop[2] - crop[0], crop[3] - crop[1]), _moved(face, crop)) == []
    assert faces.fits(crop, face)


def test_上端を手で決めて頭を落とすと切れていると出る():
    """**壊れた例。**手で上端を下げすぎると、頭の推定の枠が上ではみ出す。"""
    face = (336, 80, 121, 121)
    crop = faces.crop_box((800, 600), 16 / 9, face, top=0.2)   # 上を120px落とす
    assert crop[1] == 120
    assert "top" in faces.cut_edges((crop[2] - crop[0], crop[3] - crop[1]), _moved(face, crop))
    assert faces.head_cut((800, 450), faces=[_moved(face, crop)]) is True
    # 切らない元の写真なら切れていない
    assert faces.head_cut((800, 600), faces=[face]) is False


def test_顔が見つからなければ切れているかは分からない():
    assert faces.head_cut((800, 600), faces=[]) is False


def test_顔の枠が入らない縦長の写真は入らないと出る():
    """**壊れた例。**600x1200 の縦写真を 16:9（600x338）に切っても、372px の顔は入らない。"""
    face = (31, 226, 372, 372)
    crop = faces.crop_box((600, 1200), 16 / 9, face)
    assert faces.fits(crop, face) is False


def test_元の写真の出典の行を複製してfile名だけ変える(tmp_path):
    from tools.facecrop import add_credits

    photo = tmp_path / "01.jpg"
    Image.new("RGB", (10, 10)).save(photo)
    rows = [{"file": "01.jpg", "source": "press", "outlet": "ゲキサカ", "author": "©A/B"},
            {"file": "02.jpg", "source": "press", "outlet": "別"}]
    (tmp_path / "credits.json").write_text(json.dumps(rows, ensure_ascii=False), encoding="utf-8")

    assert add_credits(photo, ["01_w.jpg", "01_v.jpg"]) == ["01_w.jpg", "01_v.jpg"]
    got = json.loads((tmp_path / "credits.json").read_text(encoding="utf-8"))
    assert [r["file"] for r in got] == ["01.jpg", "02.jpg", "01_w.jpg", "01_v.jpg"]   # 既存の行は残る
    assert got[2] == {**rows[0], "file": "01_w.jpg"}                                  # 出典はそのまま
    # 何度やっても増えない
    assert add_credits(photo, ["01_w.jpg", "01_v.jpg"]) == []
    assert len(json.loads((tmp_path / "credits.json").read_text(encoding="utf-8"))) == 4


def test_元の写真の行が無ければ出典を作らない(tmp_path):
    from tools.facecrop import add_credits

    photo = tmp_path / "09.jpg"
    Image.new("RGB", (10, 10)).save(photo)
    (tmp_path / "credits.json").write_text(json.dumps([{"file": "01.jpg"}]), encoding="utf-8")
    assert add_credits(photo, ["09_w.jpg"]) == []
    assert add_credits(tmp_path / "x.jpg", ["x_w.jpg"]) == []          # 写真の行が無い
    assert add_credits(Path(tmp_path / "none" / "a.jpg"), ["a_w.jpg"]) == []   # 控えが無い


def test_見るコマはframesと同じでショートは中ほども足す(tmp_path):
    from tools.facecheck import marks

    assert [m[0] for m in marks(tmp_path, 193.4)] == ["冒頭 0:03", "60秒", "最後の5秒前"]
    assert [m[0] for m in marks(tmp_path, 55.9)] == ["冒頭 0:03", "中ほど", "最後の5秒前"]
    (tmp_path / "script.json").write_text(json.dumps({"scenes": [
        {"lines": [{"duration": 5.0}]}, {"main": True, "lines": [{"duration": 9.0}]}]}), encoding="utf-8")
    got = marks(tmp_path, 55.9)
    assert ("山場の頭", 6.0) in got


# ---- OpenCV が要るもの --------------------------------------------------------

def _texture(w=400, h=400, seed=0):
    """写真の代わりの、平らなところの無い絵（顔の枠の中身として使う）。"""
    np = pytest.importorskip("numpy")
    rng = np.random.default_rng(seed)
    base = rng.integers(60, 200, size=(h, w, 3), dtype=np.uint8)
    return Image.fromarray(base)


def test_顔に白い箱がかかると当たる():
    """**壊れた例。**10-03 のショートで反応の白い箱が久保の顎にかかった形。"""
    pytest.importorskip("cv2")
    face = (100, 100, 200, 200)
    clean = _texture()
    assert faces.overlay_on_face(clean, face)["hit"] is None

    boxed = clean.copy()
    boxed.paste((250, 250, 250), (60, 250, 380, 330))     # 口元から顎にかけて白い箱
    got = faces.overlay_on_face(boxed, face)
    assert got["hit"] == "white"
    assert got["cover"] >= 0.05


def test_顔に濃い板がかかると当たり顎の下だけなら浅いと出る():
    pytest.importorskip("cv2")
    face = (100, 100, 200, 200)
    banded = _texture()
    banded.paste((24, 26, 30), (0, 240, 400, 400))       # テロップの帯が口元まで上がってきた
    got = faces.overlay_on_face(banded, face)
    assert got["hit"] == "dark" and got["cover"] >= 0.05

    below = _texture()
    below.paste((24, 26, 30), (0, 305, 400, 400))        # 顎のすぐ下（首）に接しているだけ
    got = faces.overlay_on_face(below, face)
    assert got["hit"] == "dark" and got["cover"] < 0.05


def test_文字の板の上の顔らしきものは顔に数えない():
    """10-03 の本編で、テロップの字を顔と取った。顔の真ん中が板の画素なら落とす。"""
    pytest.importorskip("cv2")
    np = pytest.importorskip("numpy")
    plate = np.full((300, 300, 3), 250, dtype=np.uint8)
    assert faces._on_plate(plate, (50, 50, 200, 200)) is True
    assert faces._on_plate(np.asarray(_texture(300, 300)), (50, 50, 200, 200)) is False


def test_肌色の無いところは顔に数えない():
    """10-02 の本編で、反応の箱のすきまのぼやけた背景を顔と取った（肌色 29%）。"""
    pytest.importorskip("cv2")
    np = pytest.importorskip("numpy")
    skin = np.zeros((200, 200, 3), dtype=np.uint8)
    skin[...] = (224, 172, 140)
    blue = np.zeros((200, 200, 3), dtype=np.uint8)
    blue[...] = (60, 90, 160)
    assert faces._skin_ok(skin, (0, 0, 200, 200)) is True
    assert faces._skin_ok(blue, (0, 0, 200, 200)) is False
    gray = np.full((200, 200, 3), 128, dtype=np.uint8)
    assert faces._skin_ok(gray, (0, 0, 200, 200)) is True      # 白黒の写真では見ない


def test_隠れた顔は同じ写真のときだけ借りる():
    pytest.importorskip("cv2")
    face = (100, 100, 200, 200)
    ref = _texture(seed=1)
    covered = ref.copy()
    covered.paste((250, 250, 250), (60, 180, 380, 330))   # 箱で口元が隠れた同じ写真
    assert faces.same_picture(covered, ref, face) is True
    assert faces.same_picture(_texture(seed=2), ref, face) is False   # 写真が替わった


def test_コマの判定で冒頭の顔なしと頭切れと板かぶりを知らせる():
    pytest.importorskip("cv2")
    from tools.facecheck import judge

    frame = _texture(1080, 1920)
    # (a) 冒頭に顔が無い
    assert [m for m, _ in judge(frame, "冒頭 0:03", [], [])] == ["×"]
    assert judge(frame, "中ほど", [], []) == []
    # (b) 額まで上端で切れている
    got = judge(frame, "中ほど", [(400, 10, 240, 240)], [])
    assert any(m == "×" and t.startswith("(b)") for m, t in got)
    # 頭の上に余白がある顔は何も出ない
    assert judge(frame, "中ほど", [(400, 400, 240, 240)], []) == []
    # (c) 前後のコマから借りた顔に白い箱
    boxed = frame.copy()
    boxed.paste((250, 250, 250), (300, 520, 900, 640))
    got = judge(boxed, "最後の5秒前", [], [((400, 400, 240, 240), 42.0)])
    assert any(m == "×" and t.startswith("(c)") and "42秒" in t for m, t in got)


@pytest.mark.skipif(not PHOTO.exists(), reason="手元の写真が無い（assets/images は gitignore）")
def test_実物の写真で顔を見つけて頭が切れない16対9に切る():
    pytest.importorskip("cv2")
    from tools.facecrop import plan

    found = faces.find_faces(PHOTO)
    assert found, "久保の顔が見つからない"
    p = plan(PHOTO)
    assert p["cut_w"] == [] and p["fit_w"]
    assert p["cut_v"] == [] and p["fit_v"]
    assert abs(_ratio(p["w"]) - 16 / 9) < 0.01 and abs(_ratio(p["v"]) - 9 / 16) < 0.01
    # **壊れた例。**上を3割落とすと頭が切れる（手で切った 01_w.jpg が髪を少し落としていたのと同じ向き）
    assert "top" in plan(PHOTO, top=0.3)["cut_w"]
