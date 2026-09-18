"""報道写真の取り込み（2026-09-17 に方針を C まで開けた）。"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def test_出典を控えに残す(tmp_path):
    """**どこから来た写真かを隠さない。**

    許諾は得ていないので権利は晴れないが、記事URL・媒体名・写真の表記を
    控えに残し、概要欄に出す。`tts.image_details` がこの行から作る。
    """
    from tools.pressphoto import record

    folder = tmp_path / "nakamura_press"
    folder.mkdir()
    record(folder, {"file": "01.jpg", "source": "press",
                    "page_url": "https://example.jp/a", "author": "©Koki N/GEKISAKA",
                    "license": "報道写真（許諾は得ていない／出典を明示して使用）",
                    "outlet": "ゲキサカ"})
    rows = json.loads((folder / "credits.json").read_text(encoding="utf-8"))
    assert rows[0]["file"] == "01.jpg"
    assert rows[0]["outlet"] == "ゲキサカ"
    assert "許諾は得ていない" in rows[0]["license"]

    # 同じファイルを取り直しても増えない
    record(folder, dict(rows[0], author="別の表記"))
    rows = json.loads((folder / "credits.json").read_text(encoding="utf-8"))
    assert len(rows) == 1


def test_報道写真の行は概要欄に出さないがCC_BYは残す():
    """**2026-09-17 ユーザー指示「概要への出典記載も不要」。**

    報道写真・ネット画像は**許諾を得ていない＝守るべき表示条件が無い**ので落とす。
    **CC BY / BY-SA は別。**あれはライセンスの条件そのもので、消すと
    いま合法に使えている写真が無許諾になる。**消して得るものが無い。**
    出どころは credits.json に残るので、こちらの手元では辿れる。
    """
    from src.tts import credit_line

    press = credit_line("", "©Koki NAGAHAMA/GEKISAKA",
                        "ネット上の画像（許諾は得ていない／出どころを明示して使用）",
                        "https://web.gekisaka.jp/news/x")
    assert press == "", "報道写真の行が概要欄に出ている"

    cc = credit_line("", "Ed g2s", "CC BY-SA 3.0",
                     "https://commons.wikimedia.org/wiki/File:X")
    assert "Ed g2s" in cc and "CC BY-SA 3.0" in cc, "ライセンスの条件を落としている"


def test_放送局からは取り込まない():
    """**動画はだめ**（2026-09-17 ユーザー）。静止画に切り出したものも含めて入れない。

    報道写真の権利者は日本の媒体だが、放送局（UEFA・DAZN・プレミアリーグ）は
    専門の部署が機械的に巡回する。**逃げ道は置かない。**
    """
    from tools.pressphoto import BROADCASTERS

    for host in ("dazn", "uefa.com", "premierleague.com", "nhk.or.jp"):
        assert host in BROADCASTERS
    assert not any("gekisaka" in b or "footballchannel" in b for b in BROADCASTERS), \
        "報道媒体まで止めている"


def test_取り込みの注意書きはcp932でも落ちない(capsys):
    """**注意書きが一度も出なかった**（2026-09-18）。

    Windows のコンソールは cp932 で、「\u00a9Getty Images」の \u00a9 を出そうとして
    UnicodeEncodeError で落ちる。落ちた場所が
    「必ず開いて見てください」の途中だったので、**いちばん読ませたい行が消えた**。
    取り込み自体は成功しているので、失敗にも見えない。
    """
    from tools.articlephoto import _notice

    _notice()
    out = capsys.readouterr().out
    assert "必ず開いて見てください" in out
    assert "写っているのが本当にその人か" in out
    # **cp932 に流しても落ちないこと。**errors は replace で化けてよい
    out.encode("cp932", errors="replace")


def test_取り込みの注意書きは取り込みの前にも出す():
    """後ろだけに置くと、印字が落ちたときに一度も表示されない（2026-09-18）。"""
    import inspect

    from tools import articlephoto

    body = inspect.getsource(articlephoto.main)
    before, _, after = body.partition("pressphoto.main()")
    assert "_notice()" in before, "取り込みの前に注意書きが無い"
    assert "_notice()" in after, "取り込みの後に注意書きが無い"
