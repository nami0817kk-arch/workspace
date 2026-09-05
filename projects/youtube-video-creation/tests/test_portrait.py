"""顔写真の取得。**ライセンスの判定は、方針をコードに移したもの。**

BY-SA を使わない決まりは前からあったが、docs と記憶にしか無かった。
実際、判定を入れる直前に BY-SA の1枚を落としている（2026-09-06）。
"""


def test_使ってよいライセンス():
    from src.portrait import license_ok

    for name in ["CC0", "Public domain", "CC BY 2.0", "CC BY 3.0", "CC BY 4.0"]:
        ok, why = license_ok(name)
        assert ok, f"{name} は使えるはず: {why}"


def test_継承や非営利や改変不可は断る():
    """**BY-SA を通すと、動画そのものに同じ条件が及ぶ。**"""
    from src.portrait import license_ok

    for name in ["CC BY-SA 4.0", "CC BY-SA 2.0", "CC BY-NC 3.0", "CC BY-ND 4.0"]:
        ok, why = license_ok(name)
        assert not ok, f"{name} を通してしまった"
        assert "継承" in why or "許可した一覧" in why


def test_読めないライセンスは断る():
    """分からないものを通さない。**間違えたときに困るのはこちら。**"""
    from src.portrait import license_ok

    for name in ["", "   ", "GFDL", "Fair use", "All rights reserved"]:
        assert not license_ok(name)[0], name


def test_撮影者名のHTMLを外す():
    """extmetadata には HTML と実体参照が混ざる。概要欄にそのまま出ていた。"""
    from src.portrait import _plain

    assert _plain({"value": "Prime Video AU &amp; NZ"}) == "Prime Video AU & NZ"
    assert _plain({"value": "<a href='x'>Carlo Bruil</a>"}) == "Carlo Bruil"
    assert _plain(None) == ""


def test_被写体を確かめられなければ落とさない(monkeypatch):
    """ファイル名に名前が入っているだけの集合写真を掴まない。"""
    import src.portrait as mod

    monkeypatch.setattr(mod, "candidates", lambda *a, **k: ["File:x.jpg"])
    monkeypatch.setattr(mod, "verify", lambda *a, **k: (False, "被写体の指定がありません"))
    try:
        mod.save(["Someone"], __import__("pathlib").Path("."))
    except mod.PortraitError as err:
        assert "使える写真がありません" in str(err)
    else:
        raise AssertionError("落としてはいけない写真を通した")


def test_ライセンスが駄目なら次の候補へ(monkeypatch, tmp_path):
    """1枚目が BY-SA でも、諦めずに次を見る。"""
    import src.portrait as mod

    seen = []
    monkeypatch.setattr(mod, "candidates", lambda *a, **k: ["File:sa.jpg", "File:by.jpg"])
    monkeypatch.setattr(mod, "verify", lambda t, *a, **k: (True, "被写体に明記"))

    class Few:
        names = ["その人"]        # 写っているものが少ない＝人物の写真

    monkeypatch.setattr(mod, "fetch", lambda *a, **k: Few())

    def fake_info(title, session=None):
        seen.append(title)
        lic = "CC BY-SA 4.0" if title == "File:sa.jpg" else "CC BY 2.0"
        return {"image_url": "http://x/y.jpg", "page_url": "http://x",
                "license": lic, "author": "誰か"}

    monkeypatch.setattr(mod, "info", fake_info)

    class Res:
        content = b"body"

        def raise_for_status(self):
            pass

    import requests

    monkeypatch.setattr(requests, "get", lambda *a, **k: Res())
    entry = mod.save(["Someone"], tmp_path)
    assert seen == ["File:sa.jpg", "File:by.jpg"]      # 1枚目を飛ばして2枚目
    assert entry["license"] == "CC BY 2.0"
    assert (tmp_path / "01.jpg").read_bytes() == b"body"

def test_写っているものが多い写真は場面として外す(monkeypatch, tmp_path):
    """引きの試合写真は顔が小さい。**被写体もライセンスも通るので、ここで外す。**"""
    import src.portrait as mod

    monkeypatch.setattr(mod, "candidates", lambda *a, **k: ["File:scene.jpg"])
    monkeypatch.setattr(mod, "verify", lambda *a, **k: (True, "被写体に明記"))

    class Many:
        names = ["a", "b", "c", "d", "e", "f"]

    monkeypatch.setattr(mod, "fetch", lambda *a, **k: Many())
    try:
        mod.save(["誰か"], tmp_path)
    except mod.PortraitError as err:
        assert "場面の写真" in str(err)
    else:
        raise AssertionError("引きの写真を通した")


def test_切り出しは割合で指定する(tmp_path):
    from PIL import Image

    from src.portrait import crop_to

    path = tmp_path / "a.jpg"
    Image.new("RGB", (400, 200), "white").save(path)
    assert crop_to(path, "0.5,0.0,0.5,0.5") == (200, 100)
