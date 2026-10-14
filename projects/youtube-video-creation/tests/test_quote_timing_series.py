"""言葉の早さの点検（2026-10-06「その人の発言を何秒以内に入れるって制約のせいで流れおかしくない？」）。"""
from src.research import Notes, Section, _check_quote_timing

LONG = ["語りの一文です。数字と経緯を、ゆっくりと順に伝えていきます。"] * 12


def _notes(series=""):
    sec1 = Section(id="data", heading="基礎DATA", tier="報道", telop="", say=LONG, voices=[""] * len(LONG))
    sec2 = Section(id="q", heading="本人の言葉", tier="報道", telop="", say=["こう話しました。", "うれしいです"],
                   voices=["", "本人"], main=True)
    return Notes(date="2026-10-06", title="題", question="", sections=[sec1, sec2], people=["本人"], series=series)


def test_ニュースの本編は言葉が遅ければ知らせる():
    assert any("本編で誰かの言葉" in p for p in _check_quote_timing(_notes()))


def test_シリーズの本編は言葉の早さを見ない():
    assert not any("本編で誰かの言葉" in p for p in _check_quote_timing(_notes(series="監督の経歴")))
