"""タグと概要欄の制限。

タグは4つ固定だった（サッカー / 海外サッカー / サッカーニュース / 解説）。
どの動画にも同じ4つが付くので、検索から見つけてもらう役に立たない。
"""

from src import tags


def test_土台は毎回入る():
    """**並びを変えた**（2026-09-10）。土台の3語を先頭に固めていたが、
    参考4チャンネルのハッシュタグを実測したら中身はほぼ選手名だった。
    あふれたら後ろから落ちるので、名前を前・分類語を後ろにした。
    ただし「サッカー」だけは先頭に残す（うわさのフットボールも先頭がこれ）。
    """
    found = tags.build("何かのニュース")
    assert found[0] == tags.BASE[0]
    for word in tags.BASE:
        assert word in found


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


def test_人の名前を先に置く():
    """**参考4チャンネルのハッシュタグはほぼ選手名だった**（2026-09-10 実測）。

    向こうは10〜34個。こちらは7〜8個で、リヴァプール対アトレティコの回は
    「リバプール／アトレティコマドリード」だけで**選手名が1つも無かった**。
    人は選手名で検索する。あふれたら後ろから落ちるので、名前を前に置く。
    """
    from src.tags import build

    got = build("リヴァプールが逆転でCL初戦を制す", league_name="プレミアリーグ",
                kind="match", extra=["リバプール"],
                people=["マクアリスター", "ソボスライ"])
    # **先頭の3つは動画の上に丸いボタンとして出る**（2026-09-10 に Chrome で確認）。
    # 「サッカー ／ クラブ ／ 人」の順。分類語で3枠を埋めない
    assert got[:2] == ["サッカー", "リバプール"]
    assert got[2] == "マクアリスター"
    assert got.index("マクアリスター") < got.index("海外サッカー")
    assert got.index("マクアリスター") < got.index("試合結果")


def test_表記ゆれを両方入れる():
    """サッカー知恵袋は同じ動画に #リバプール と #リヴァプール を貼っていた。"""
    from src.tags import build

    got = build("リヴァプール", extra=["リバプール"], kind="match")
    assert "リバプール" in got and "リヴァプール" in got


def test_ハイライトとは書かない():
    """試合映像は使えないので、こちらの動画はハイライトではない。"""
    from src.tags import build

    assert "ハイライト" not in build("バルセロナ", kind="match")


def test_クラブにいる日本人選手を足す(tmp_path):
    """**話に出てこなくても入れる**（2026-09-10 実測）。

    サッカー知恵袋はアラウホ（ウルグアイ人）の回に #遠藤航 を貼っていた。
    日本語圏の検索は選手名で起きる。表に無いクラブでは何も足さない。
    """
    from src.tags import japanese_players

    book = tmp_path / "players.yaml"
    book.write_text("players:\n  フェイエノールト: [渡辺剛]\n", encoding="utf-8")
    assert japanese_players(["フェイエノールト"], str(book)) == ["渡辺剛"]
    assert japanese_players(["バルセロナ"], str(book)) == []
    # 表が無くても壊れない
    assert japanese_players(["バルセロナ"], str(tmp_path / "ない.yaml")) == []


def test_主役のクラブを2枠目に置く():
    """**見出しに出てくる順ではない**（2026-09-10 実測）。

    アーセナルの回の見出しが「ウーデゴールが敵地ナポリで決勝弾」で、
    2枠目（動画の上に出る2つめのボタン）が #ナポリ になっていた。
    """
    from src.tags import build

    got = build("ウーデゴールが敵地ナポリで決勝弾", topic="アーセナル", kind="match")
    assert got[:2] == ["サッカー", "アーセナル"]
    assert "ナポリ" in got


def test_相手クラブの日本人も拾う(tmp_path):
    """**相手クラブはサムネの札にしか出ないことがある**（2026-09-10 実測）。

    バルサ対フェイエノールトの見出しに「フェイエノールト」が無く、
    渡辺剛が日本人枠から漏れていた。
    """
    from src.tags import build

    book = tmp_path / "players.yaml"
    book.write_text("players:\n  フェイエノールト: [渡辺剛]\n", encoding="utf-8")
    got = build("バルセロナ、CL初戦で5得点", topic="バルセロナ", kind="match",
                extra=["バルセロナ", "フェイエノールト"], players_path=str(book))
    assert got[:3] == ["サッカー", "バルセロナ", "渡辺剛"]
