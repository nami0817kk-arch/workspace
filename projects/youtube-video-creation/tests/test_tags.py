"""タグと概要欄の制限。

タグは4つ固定だった（サッカー / 海外サッカー / サッカーニュース / 解説）。
どの動画にも同じ4つが付くので、検索から見つけてもらう役に立たない。
"""

from src import tags


def test_土台は毎回入る():
    found = tags.build("何かのニュース")
    assert found[:3] == list(tags.BASE)


def test_リーグと話の種類から足す():
    found = tags.build("何かのニュース", "プレミアリーグ", "match")
    assert "プレミアリーグ" in found
    assert "試合結果" in found
    assert "移籍情報" not in found


def test_見出しのクラブ名を入れる():
    found = tags.build("トッテナムがアルバレスを獲得", "プレミアリーグ", "transfer")
    assert "トッテナム" in found


def test_中黒を抜いた形も入れる():
    # 「マンチェスターシティ」でも探される
    found = tags.build("マンチェスター・シティが獲得")
    assert "マンチェスター・シティ" in found
    assert "マンチェスターシティ" in found


def test_同じタグは1つにする():
    found = tags.build("サッカーのニュース", extra=["サッカー", "サッカー"])
    assert found.count("サッカー") == 1


def test_長すぎるタグは落とす():
    found = tags.build("x", extra=["あ" * (tags.MAX_TAG_LENGTH + 1)])
    assert all(len(t) <= tags.MAX_TAG_LENGTH for t in found)


def test_合計が上限を超えたら後ろから落とす():
    extra = [f"タグ{n:03d}あいうえおかきくけこ" for n in range(80)]
    found = tags.build("x", extra=extra)
    assert tags.text_length(found) <= tags.MAX_TAGS_TEXT
    # 大事なものは前に残る
    assert found[0] == "サッカー"


def test_長さの数え方はカンマ区切り():
    assert tags.text_length(["あい", "うえ"]) == 5


def test_公開前に引っかかるところを挙げる():
    found = tags.problems("あ" * 101, "本文", ["ok"])
    assert any("タイトル" in note for note in found)

    found = tags.problems("題", "あ" * (tags.MAX_DESCRIPTION + 1), ["ok"])
    assert any("概要欄" in note for note in found)

    found = tags.problems("題", "<b>", ["ok"])
    assert any("< >" in note for note in found)


def test_問題が無ければ何も言わない():
    assert tags.problems("題", "本文", ["サッカー"]) == []
