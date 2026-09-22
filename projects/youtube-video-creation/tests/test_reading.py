from src.reading import Hint, apply_dates, check, date_reading, load_dictionary


def test_irregular_day_readings():
    # 日付は読みが不規則。ここを外すと音声で一発で分かる
    assert date_reading(9, 1) == "くがつついたち"
    assert date_reading(8, 20) == "はちがつはつか"
    assert date_reading(12, 14) == "じゅうにがつじゅうよっか"
    assert date_reading(4, 8) == "しがつようか"
    assert date_reading(7, 1) == "しちがつついたち"   # 7月は「なながつ」ではない


def test_regular_days_fall_back_to_the_number():
    assert date_reading(3, 15) == "さんがつ15にち"


def test_dates_in_a_sentence_are_found():
    hints = check("移籍期限は9月1日です。")
    assert [(h.found, h.suggest) for h in hints] == [("9月1日", "くがつついたち")]


def test_impossible_dates_are_ignored():
    assert check("背番号は13月45日ではない") == []


def test_big_numbers_are_flagged_without_a_suggestion():
    (hint,) = check("移籍金は1.5億ユーロです。")
    assert hint.found == "1.5億"
    assert hint.suggest == ""      # 開き方は書き手が決める
    assert "読みを開く" in hint.why


def test_dictionary_words_are_reported():
    hints = check("鈴木彩艶が移籍", {"鈴木彩艶": "すずきざいおん"})
    assert hints[0].suggest == "すずきざいおん"


def test_the_longer_dictionary_entry_wins():
    # 「鈴木彩艶」と「彩艶」の両方を出すと同じ場所を二重に指す
    hints = check("鈴木彩艶が移籍", {"鈴木彩艶": "すずきざいおん", "彩艶": "ざいおん"})
    assert [h.found for h in hints] == ["鈴木彩艶"]


def test_a_short_entry_still_fires_on_its_own():
    hints = check("彩艶が好セーブ", {"鈴木彩艶": "すずきざいおん", "彩艶": "ざいおん"})
    assert [h.found for h in hints] == ["彩艶"]


def test_dates_can_be_opened_automatically():
    assert apply_dates("9月1日と8月20日") == "くがつついたちとはちがつはつか"
    # 人名は判断が要るので触らない
    assert apply_dates("鈴木彩艶") == "鈴木彩艶"


def test_the_shipped_dictionary_loads():
    dictionary = load_dictionary()
    assert dictionary["鈴木彩艶"] == "すずきざいおん"


def test_a_missing_dictionary_is_not_an_error(tmp_path):
    assert load_dictionary(tmp_path / "none.yaml") == {}


def test_hints_carry_a_reason():
    (hint,) = check("9月1日")
    assert isinstance(hint, Hint)
    assert hint.why


def test_draw_notation_is_flagged():
    """勝敗表記の「分」は「ふん」と読まれる（2026-09-13）。

    「1分3敗」は引き分けの数なのに、合成音声は時間の「いっぷん」で読む。
    **聞き返せないので、耳では直せない。**Gemini に台本を読ませて見つかった。
    9/10 のリヴァプール・PSG、9/12 の佐藤、9/13 のヴィラで実際に鳴っていた。
    """
    from src.reading import check

    def flagged(text):
        return [h for h in check(text) if "勝敗" in h.why]

    assert flagged("ヴィラは開幕から4試合、1分3敗。")
    assert flagged("プレミアリーグで1勝2分と勝ち切れていませんでした")
    assert flagged("開幕から2分1敗で、まだ勝ち星がありません")
    # **試合の時間は拾わない。**45分・後半30分は正しく読まれる
    assert not flagged("試合は45分で折り返し")
    assert not flagged("後半30分に交代")
    assert not flagged("アディショナルタイム7分")
    # すでに開いてあるものは拾わない
    assert not flagged("1分け3敗")


def test_辞書の読みを合成に渡す文へ開く():
    """2026-09-22 指示「日本人選手を読む時に読み仮名間違えているから改善して」。
    辞書は check で知らせるだけで、合成には使っていなかった。"""
    from src.reading import apply

    d = {"鈴木彩艶": "すずきざいおん", "彩艶": "ざいおん", "鎌田": "かまだ", "鎌田大地": "かまだだいち"}
    assert apply("鈴木彩艶と鎌田大地。鎌田は", d) == "すずきざいおんとかまだだいち。かまだは"
    assert apply("彩艶が", d) == "ざいおんが"


def test_辞書に無い漢字の人名は下書きで知らせる():
    from src.research import _advise_readings, build_notes

    raw = _raw_people(["冨安健洋", "架空太郎"])
    got = _advise_readings(build_notes(raw))
    assert any("架空太郎" in h for h in got) and not any("冨安健洋" in h for h in got)


def _raw_people(people):
    from tests.test_research import _raw

    raw = _raw()
    raw["people"] = people
    return raw
