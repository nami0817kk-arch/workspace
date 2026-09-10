"""顔写真の取得。**ライセンスの判定は、方針をコードに移したもの。**

BY-SA を使わない決まりは前からあったが、docs と記憶にしか無かった。
実際、判定を入れる直前に BY-SA の1枚を落としている（2026-09-06）。
"""


def test_使ってよいライセンス():
    from src.portrait import license_ok

    for name in ["CC0", "Public domain", "CC BY 2.0", "CC BY 3.0", "CC BY 4.0"]:
        ok, why = license_ok(name)
        assert ok, f"{name} は使えるはず: {why}"


def test_非営利と改変不可は断る():
    """NC は商用不可、ND は切り抜きができない。どちらも使えない。"""
    from src.portrait import license_ok

    for name in ["CC BY-NC 3.0", "CC BY-ND 4.0", "CC BY-NC-SA 4.0"]:
        ok, why = license_ok(name)
        assert not ok, f"{name} を通してしまった"


def test_継承つきは通す():
    """**BY-SA を許可した（2026-09-06 ユーザーの判断）。**

    日本人選手は CC BY で顔の写った写真が見つからず、
    「サムネの顔は必須」と両立しなかった。継承条件を受け入れる側を選んだ。
    """
    from src.portrait import license_ok

    for name in ["CC BY-SA 4.0", "CC BY-SA 3.0", "CC BY-SA 2.0"]:
        assert license_ok(name)[0], f"{name} が通らない"


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
    """1枚目が使えないライセンスでも、諦めずに次を見る。"""
    import src.portrait as mod

    seen = []
    monkeypatch.setattr(mod, "candidates", lambda *a, **k: ["File:sa.jpg", "File:by.jpg"])
    monkeypatch.setattr(mod, "verify", lambda t, *a, **k: (True, "被写体に明記"))

    class Few:
        names = ["その人"]        # 写っているものが少ない＝人物の写真

    monkeypatch.setattr(mod, "fetch", lambda *a, **k: Few())

    def fake_info(title, session=None):
        seen.append(title)
        lic = "CC BY-NC 4.0" if title == "File:sa.jpg" else "CC BY 2.0"
        return {"image_url": "http://x/y.jpg", "page_url": "http://x",
                "license": lic, "author": "誰か"}

    monkeypatch.setattr(mod, "info", fake_info)

    class Res:
        status_code = 200        # _download が見る（2026-09-10 に足した）
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


def test_透過つきの写真も切り出せる(tmp_path):
    """**Commons の PNG は透過を持っていることがある。**

    落とした中身は拡張子に関わらず 01.jpg に書くので、RGBA のままだと
    JPEG で保存できずに落ちる。2026-09-09 に南野拓実のモナコ時代の写真
    （CC0 の PNG）で実際に「cannot write mode RGBA as JPEG」が出た。
    """
    from PIL import Image

    from src.portrait import crop_to

    path = tmp_path / "a.jpg"
    Image.new("RGBA", (400, 200), (255, 255, 255, 128)).save(path, "PNG")
    assert crop_to(path, "0.0,0.0,0.5,1.0") == (200, 200)
    with Image.open(path) as saved:
        assert saved.mode == "RGB"


def test_改変不可は切る用途では断り_そのまま出すなら通す():
    """**ND は「改変しなければ使える」。**（2026-09-06 ユーザーの案）

    CC 4.0 は、媒体や形式を変えるための技術的な変更は改変物を生まないと
    明記している。本文の image: は min で縮めるだけで、切り取りもズームも
    していないので条件を満たす。サムネイルは16:9に切って文字を重ねるので不可。
    """
    from src.portrait import license_ok

    assert not license_ok("CC BY-ND 4.0", modify=True)[0]
    assert license_ok("CC BY-ND 4.0", modify=False)[0]
    # 非営利が付いたら、切らなくても使えない
    assert not license_ok("CC BY-NC-ND 4.0", modify=False)[0]
    assert not license_ok("CC BY-NC 3.0", modify=False)[0]


def test_改変不可の写真はサムネに使えない(tmp_path, monkeypatch):
    """取得時の印を review が見て止める。**印だけあっても見ていなければ意味がない。**"""
    import json

    from src import review as review_mod

    folder = tmp_path / "someone"
    folder.mkdir()
    (folder / "01.jpg").write_bytes(b"x")
    (folder / "credits.json").write_text(json.dumps(
        [{"file": "01.jpg", "license": "CC BY-ND 4.0", "no_derivatives": True}]),
        encoding="utf-8")
    monkeypatch.setattr(review_mod, "_resolve", lambda value: folder / "01.jpg")

    class Script:
        meta = {"thumbnail_photo": "assets/images/someone/01.jpg"}

    finding = review_mod._thumbnail_face(Script())
    assert not finding.ok
    assert "改変不可" in finding.detail

    # 印が無ければ通る（外しすぎていないことも確かめる）
    (folder / "credits.json").write_text(json.dumps(
        [{"file": "01.jpg", "license": "CC BY 4.0", "no_derivatives": False}]),
        encoding="utf-8")
    assert review_mod._thumbnail_face(Script()).ok

def test_音声や動画は写真として選ばない():
    """**Commons には音声も動画もある。**

    実測（2026-09-07）で、久保建英の候補に .ogg（音声）が混ざり、
    被写体もライセンスも通って選ばれてしまった。
    """
    from src.portrait import is_image

    for bad in ["File:Takefusa kubo.ogg", "File:x.webm", "File:y.svg",
                "File:z.pdf", "File:w.mp3", "File:拡張子なし"]:
        assert not is_image(bad), bad
    for good in ["File:Kubo 2024.jpg", "File:x.JPEG", "File:y.png"]:
        assert is_image(good), good

# 試合の場面の写真（2026-09-07）。放送映像は使えないので、Commons にある
# 実際の試合の写真で置き換える。顔写真とは探し方も確かめ方も違う。

def test_試合の場面を上に並べる():
    from src.portrait import scene_rank

    assert scene_rank("File:Arsenal vs Chelsea 2024 goal.jpg") < scene_rank(
        "File:Bukayo Saka portrait cropped.jpg")


def test_建物や物の写真は落とす():
    """実測: Arsenal Chelsea の1件目がロッカールームの写真だった。"""
    from src.portrait import scene_ok

    assert scene_ok("File:Arsenal dressing room Emirates Stadium.jpg") is False
    assert scene_ok("File:Chelsea badge.jpg") is False
    assert scene_ok("File:Chelsea players training before the final.jpg") is True


def test_探す言葉が無ければ止まる(tmp_path):
    from src.portrait import PortraitError, save_scene

    try:
        save_scene([], tmp_path)
    except PortraitError as error:
        assert "探す言葉" in str(error)
        return
    raise AssertionError("止まっていない")


def test_同じ名前の犬や銅像を人の写真として掴まない():
    """**犬を掴んだ**（2026-09-09 実測）。

    「メッシ」で引いたら `File:Messi (dog) (28045247387) (cropped).jpg` が
    1位に来て、被写体の照合も「メッシ / Lionel Messi が明記されています」と
    通した。**照合は名前しか見ておらず、種類を見ていない。**
    名前は人にも犬にも銅像にも壁画にも付く。
    """
    from src.portrait import looks_like_person

    assert not looks_like_person("File:Messi (dog) (28045247387) (cropped).jpg")
    assert not looks_like_person("File:Statue of Lionel Messi.jpg")
    assert not looks_like_person("File:Mural of Marcus Rashford.jpg")
    assert looks_like_person("File:Lionel Messi NYCFC Miami 24 Sep 2025-079.jpg")
    assert looks_like_person("File:Takumi Minamino Stefan Lainer.JPG")


def test_画像URLの計測用パラメータを落とす():
    """控えに残すURLを短くするためだけ。**429 の原因ではない**（2026-09-10）。

    最初「utm を外したら通った」と書いたが、同じURLが少しあとに
    utm 付きでも200で返った。User-Agent の違いでもなかった。
    **正体は本物の速度制限で、数秒〜1分で解ける。**
    """
    from src.portrait import _plain_url

    dirty = ("https://upload.wikimedia.org/wikipedia/commons/3/3f/x.jpg"
             "?utm_source=commons.wikimedia.org&utm_campaign=imageinfo")
    assert _plain_url(dirty) == "https://upload.wikimedia.org/wikipedia/commons/3/3f/x.jpg"
    assert _plain_url("https://x/y.jpg") == "https://x/y.jpg"
    assert _plain_url("") == ""
    assert _plain_url(None) == ""



def test_429は待って試し直す(monkeypatch):
    """**1回で諦めると「写真が無い」ように見える**（2026-09-10）。

    鎌田・ハーランド・アラウホ・ロジャースで4回引っかかり、そのたびに
    別の原因（utm・User-Agent）を疑って回り道した。正体は速度制限で、
    数秒〜1分で解ける。**待って試し直すのが正しい直し方。**
    """
    import src.portrait as mod

    monkeypatch.setattr(mod, "DOWNLOAD_WAIT", 0)
    calls = []

    class Res:
        def __init__(self, code, body=b""):
            self.status_code = code
            self.content = body

        def raise_for_status(self):
            raise AssertionError("200 で返るはずなのに呼ばれた")

    class Client:
        def get(self, url, **k):
            calls.append(k.get("headers", {}).get("User-Agent"))
            return Res(429) if len(calls) < 3 else Res(200, b"gazou")

    assert mod._download("http://x/y.jpg", Client()) == b"gazou"
    assert len(calls) == 3
    # **連絡先を入れた User-Agent で名乗る**（Wikimedia の求め）。
    # 公開リポジトリなのでメールアドレスは書かない
    assert "+https://" in calls[0]


def test_429が続いたら諦める(monkeypatch):
    """待っても解けないときに、無言で空の画像を書かない。"""
    import src.portrait as mod

    monkeypatch.setattr(mod, "DOWNLOAD_WAIT", 0)

    class Res:
        status_code = 429
        content = b""

        def raise_for_status(self):
            raise RuntimeError("429")

    class Client:
        def get(self, url, **k):
            return Res()

    try:
        mod._download("http://x/y.jpg", Client(), tries=2)
    except Exception as err:
        assert "429" in str(err) or "取れません" in str(err)
    else:
        raise AssertionError("止まっていない")


def test_逮捕写真と紋章を人として掴まない():
    """**逮捕写真を掴んだ**（2026-09-10 実測）。

    「チアゴ・シウヴァ」で引いたら、1位が
    `File:Thiago-Silva-mug-shot.jpg`（同名のUFC選手が逮捕されたときのもの）。
    候補に2枚あり、**被写体の照合もライセンスも通っていた。**
    サッカー選手の回に、無関係な人の逮捕写真を出すところだった。
    犬のメッシ・Deb Haaland と同じ「名前は誰にでも付く」問題。
    """
    from src.portrait import looks_like_person

    assert not looks_like_person("File:Thiago-Silva-mug-shot.jpg")
    assert not looks_like_person("File:Thiago Silva (Fighter) Mugshot.jpg")
    assert not looks_like_person("File:The First Araujo Coat Of Arms.jpg")
    assert not looks_like_person(
        "File:20180610 FIFA Friendly Match Austria vs. Brazil Gruppenfoto Brasilien.jpg")
    # 本人の写真は通る（外しすぎていないことも確かめる）
    assert looks_like_person("File:Thiago Silva (cropped).jpg")
    assert looks_like_person("File:Thiago Silva & Marquinhos.jpg")
