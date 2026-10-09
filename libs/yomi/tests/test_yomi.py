"""yomi の点検（チャンネルに依存しない部分）。エンジンのカナは固定の文字列で渡す（CI に VOICEVOX は無い）。
例の多くは rekishi-chiso の10/12〜13 の4本で実際に起きた誤読（2026-10-10）。"""
import pytest

import yomi
from yomi import Case, Lexicon, check, check_kana, norm

needs_fugashi = pytest.mark.skipif(not yomi.available(), reason="fugashi・unidic-lite が入っていない")


# --- カナ・置き換え ---------------------------------------------------------------

def test_norm():
    assert norm("トーキョー") == "トオキョオ"
    assert norm("トウキョウ", long=True) == "トオキョオ"
    assert norm("トウキョウ") == "トウキョウ"          # エンジンの列には長音の置き換えを掛けない（語をまたぐため）
    assert norm("を") == "オ"


def test_apply_tracked_is_the_same_replacement():
    readings = {"露": "つゆ", "披露": "ひろう", "の都": "のみやこ", "都へ向けて": "みやこへむけて", "清の": "しんの",
                "粛清": "しゅくせい"}
    for text in ("妹として披露した。露と消えた。", "京の都へ向けて", "粛清の嵐と清の国", "何もない"):
        out, origin = yomi.apply_tracked(text, readings)
        assert out == yomi.apply_readings(text, readings)
        assert len(origin) == len(out)
        assert all(text[o] == out[i] for i, o in enumerate(origin) if o is not None)


def test_replacements_positions():
    assert yomi.replacements("披露と露", {"露": "つゆ"}) == [("露", 1, 2), ("露", 3, 4)]
    assert yomi.replacements("披露と露", {"露": "つゆ", "披露": "ひろう"}) == [("披露", 0, 2), ("露", 3, 4)]


# --- ① 辞書との食い違い ----------------------------------------------------------

@needs_fugashi
def test_diff_finds_misread_word():
    assert [d.surface for d in yomi.diff_line("栗や柿や瓜をかじる。", "クリヤ／カキヤ／フリオ／カジル")] == ["瓜"]
    assert [d.surface for d in yomi.diff_line("京都のすぐ隣なんだ。", "キョオトノ／スグ／トナンダ")] == ["隣"]
    assert [d.surface for d in yomi.diff_line("人々の怒りは", "ヒトビトノ／オコリワ")] == ["怒り"]
    got = yomi.diff_line("対馬が朝鮮。", "タイウマガ／チョオセン")
    assert got and got[0].proper                                        # 人名・地名は別にまとめられる


@needs_fugashi
def test_diff_ignores_long_vowels_particles_numbers():
    assert yomi.diff_line("東京へ行こう。", "トオキョオエ／イコオ") == []
    assert yomi.diff_line("東京へ行こう。", "トオキョオヘ／イコオ") == []          # 助詞「へ」はヘでもエでも
    assert yomi.diff_line("そういう人は、1582年6月2日に。", "ソオユウ／ヒトワ／センゴヒャクハチジュウニネン／ロクガツフツカニ") == []
    assert yomi.diff_line("3本の矢と5人の兵。", "サンボンノ／ヤト／ゴニンノ／ヘエ") == []
    assert yomi.diff_line("賤ヶ岳の戦い", "シズガダケノ／タタカイ") == []              # 濁りだけの違い
    assert yomi.diff_line("それ、悪女っていうより", "ソレ／アクジョッテ／イウヨリ") == []


@needs_fugashi
def test_diff_skips_ambiguous_and_fixed_text():
    assert yomi.diff_line("年が明けた。", "ネンガ／アケタ") == []                  # 「年」は ② が受け持つ
    text = "ちょうそかべがたは"
    assert yomi.diff_line(text, "チョオ／ソカベガタワ", fixed=frozenset(range(len(text) - 1))) == []


@needs_fugashi
def test_both_dictionaries_wrong_is_not_found():
    # 分かっている穴：UniDic も「織田家＝オダカ」と読むので、① では拾えない（② の型で止める）
    assert yomi.diff_line("織田家の娘", "オダカノ／ムスメ") == []


# --- ② 読みが割れる語と型 ------------------------------------------------------------

def _rule(text: str, lex=None):
    toks = yomi.tokens(text)
    return [yomi.rule_of(toks, i, lex)[0] for i in range(len(toks)) if yomi.rule_of(toks, i, lex)]


@needs_fugashi
def test_rules_hit():
    assert _rule("織田家の娘です。") == ["名字＋家"]
    assert _rule("今川家の家臣") == ["名字＋家"]
    assert _rule("約12万石の大名") == ["数字＋石"]
    assert _rule("4200石の旗本") == ["数字＋石"]
    assert _rule("「小谷の方」と書かれている") == ["名前＋の方"]
    assert _rule("お市の方") == ["名前＋の方"]
    assert _rule("表のことは秀長") == ["表＋の/に/と"]
    assert _rule("表と内の二本柱") == ["表＋の/に/と"]


@needs_fugashi
def test_rules_do_not_hit_other_uses():
    for text in ("国家の大事と実家の母", "徳川家康が来た", "東の方へ逃げた", "こっちの方が早い", "この表の数字を見て",
                 "年表の印", "石を投げた"):
        assert _rule(text) == [], text


@needs_fugashi
def test_channel_extra_rules_and_words():
    # チャンネル側の一覧（歴史の「都」）は Lexicon.load に dict か yaml のパスで足す
    assert _rule("都へ向けて") == []
    lex = Lexicon.load({"ambiguous": {"都": ["ミヤコ", "ト"]},
                        "rules": [{"name": "都＋助詞", "surface": ["都"], "want": ["ミヤコ"], "when": {1: {"pos1": "助詞"}}}]})
    assert _rule("都へ向けて", lex) == ["都＋助詞"]
    assert _rule("首都に戻る", lex) == []
    assert "家" in lex.ambiguous and "都" in lex.ambiguous            # 共通の一覧も残る


@needs_fugashi
def test_rule_passes_when_engine_reads_it_right():
    ok = yomi.ambiguous_hits("1行目", "徳川家の旗本。", "トクガワケノ／ハタモト")
    assert [(h.rule, h.ok) for h in ok if h.rule] == [("名字＋家", True)]
    ng = yomi.ambiguous_hits("1行目", "織田家の娘。", "オダカノ／ムスメ")
    assert [(h.rule, h.ok, h.got) for h in ng if h.rule] == [("名字＋家", False, "カ")]
    blind = yomi.ambiguous_hits("1行目", "織田家の娘。", None)          # エンジンが無いと確かめられない（止める）
    assert [h.ok for h in blind if h.rule] == [False]


# --- ③ 巻き込み -----------------------------------------------------------------------

@needs_fugashi
def test_collision_found():
    cols = yomi.collisions({"露": "つゆ"}, [("24行目", "妹として披露した")])
    assert [(c.key, c.word) for c in cols] == [("露", "披露")]
    cols = yomi.collisions({"都のまわり": "みやこのまわり"}, [("63行目", "京都のまわりを固めた")])
    assert [(c.key, c.word) for c in cols] == [("都のまわり", "京都のまわり")]
    assert "披露" in yomi.collision_lines(yomi.collisions({"露": "つゆ"}, [("1行目", "披露した")]))[0]


@needs_fugashi
def test_collision_not_for_word_boundaries():
    assert yomi.collisions({"露": "つゆ"}, [("1行目", "露と落ち露と消えにし")]) == []
    assert yomi.collisions({"「秀」": "「ヒデ」"}, [("1行目", "名前の「秀」の字")]) == []
    assert yomi.collisions({"都を落と": "みやこをおと"}, [("1行目", "都を落とした")]) == []   # 活用の途中で切るのはよい
    assert yomi.collisions({"露": "つゆ", "披露": "ひろう"}, [("1行目", "披露した")]) == []    # 長い語が先に当たる


# --- まとめて回す --------------------------------------------------------------------

@needs_fugashi
def test_review_lines():
    items = [("1行目", "織田家の娘です。"), ("2行目", "栗や柿や瓜をかじる。"), ("3行目", "上を見た。"),
             ("4行目", "妹として披露した。")]
    kana = {"織田家の娘です。": "オダケノ／ムスメデス", "栗や柿や瓜をかじる。": "クリヤ／カキヤ／フリオ／カジル",
            "上を見た。": "ジョオオ／ミタ", "妹として披つゆした。": "イモオトト／シテ／ツユシタ"}
    errors, warns = yomi.review(items, {"露": "つゆ"}, kana.get).lines()
    assert len(errors) == 1 and "披露" in errors[0]                  # 織田家はケと読めているので止めない
    assert "読み：2行目「瓜」エンジン フリ／辞書 ウリ" in warns
    assert any(w.startswith("読みが割れる語") and "上＝ジョオ（3）" in w for w in warns)


@needs_fugashi
def test_review_without_engine_stops_rule_hits():
    errors, warns = yomi.review([("1行目", "織田家の娘です。")], {}, None).lines()
    assert any("名字＋家" in e and "確かめられません" in e for e in errors)
    assert any("動いていない" in w for w in warns)


# --- ⑤ 既知の誤読のテスト ---------------------------------------------------------------

def test_cases():
    readings = {"万石": "万ゴク", "織田家": "おだけ"}
    cases = [Case("約12万石の大名", said="万ゴク", kana="マンゴク"), Case("織田家の娘", said="おだけ", kana="オダケ")]
    assert check(cases, readings) == []
    assert check(cases, {}) and len(check(cases, {})) == 2
    fake = {"約12万ゴクの大名": "ヤク／ジュウニマンゴクノ／ダイミョオ", "おだけの娘": "オダケノ／ムスメ"}
    assert check_kana(cases, readings, fake.get) == []
    assert check_kana([Case("勝家", kana="／カツイエ")], {}, lambda t: "トカ／ツイエ")


@pytest.mark.voicevox
@pytest.mark.skipif(not yomi.engine_up(), reason="VOICEVOX が動いていない（手元だけで回す）")
def test_voicevox_kana():
    assert yomi.voicevox_kana("東京へ行こう").replace("／", "") == "トオキョオエイコオ"
