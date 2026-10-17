"""文体の点検・章の題の点検・ショートの頭の問いとループ（10-08）。"""
from types import SimpleNamespace as NS

from PIL import Image

from chiso import check, shorts, style


def L(i, text, speaker="語り", section=0):
    return NS(index=i, text=text, speaker=speaker, section=section, place=None, term=None)


def S(lines, sections=("節",), people=None):
    return NS(lines=lines, sections=[NS(index=i, title=t) for i, t in enumerate(sections)],
              people=people or {}, thumbnail={}, title="")


# --- 文体 ---------------------------------------------------------------------

def test_sentences_keep_quotes_and_merge_marks():
    assert style.sentences("彼は「行け。戻るな。」と言いました。えっ！？") == ["彼は「行け。戻るな。」と言いました。", "えっ！？"]


def test_ending_run_counts_host_sentences_across_listener():
    sc = S([L(0, "生まれました。育ちました。"), L(1, "へえ。", "聞き"), L(2, "学びました。戦いました。")])
    w = style.ending_runs(sc)
    assert len(w) == 1 and "ました" in w[0] and "4文" in w[0]
    sc2 = S([L(0, "生まれました。育ちました。"), L(1, "戦いです。"), L(2, "学びました。")])
    assert style.ending_runs(sc2) == []


def test_ending_run_resets_at_section():
    sc = S([L(0, "あります。あります。", section=0), L(1, "あります。あります。", section=1)], ("a", "b"))
    assert style.ending_runs(sc) == []


def test_repeated_phrase_found_and_names_skipped():
    lines = [L(i, f"話{i}は、と言われています。") for i in range(4)]
    w = style.repeated_phrases(S(lines))
    assert w and "と言われています" in w[0] and "4回" in w[0]
    names = [L(i, f"マリー・アントワネットが{i}回。") for i in range(5)]
    assert style.repeated_phrases(S(names), ["マリー・アントワネット"]) == []


def test_stiff_words_skip_quotes_and_made():
    sc = S([L(0, "これは重要である。"), L(1, "本に「天下である」とあります。"), L(2, "言い回しまであった。")])
    w = style.stiff_words(sc)
    assert len(w) == 1 and "である" in w[0] and "[1]" in w[0]


def test_listener_heads():
    lines = [L(0, "a"), L(1, "え、うそ。", "聞き"), L(2, "b"), L(3, "へえ、そう。", "聞き"), L(4, "c"),
             L(5, "えっ、ほんと？", "聞き")]
    assert style.listener_heads(S(lines))
    assert style.listener_heads(S(lines[:4])) == []


def test_long_sentence():
    assert style.is_long("あ、い、う、え、お、か。")                               # 読点5つ
    assert not style.is_long("あ、い、う、え、お。")                               # 4つで短い
    assert style.is_long("あ" * 30 + "、い、う、え、" + "お" * 30 + "。")           # 4つで60字以上


def test_notes_prefix():
    sc = S([L(0, "これは重要である。")])
    assert all(w.startswith("文体：") for w in style.notes(sc))


# --- 章の題 -------------------------------------------------------------------

def test_chapter_titles():
    sc = S([L(0, "x")], ("地表：悪女？", "1582年の朝", "信長と堺", "大うつけの若殿", "パリへ", "「天下布武」", "首飾り事件",
                         "本能寺の朝", "まとめ：何者だったのか"), people={"織田信長": {}})
    w = check.chapter_titles(sc, places=["パリ"])
    assert len(w) == 1
    for bad in ("地表：悪女？", "大うつけの若殿", "まとめ：何者だったのか"):
        assert bad in w[0]
    for ok in ("1582年の朝", "信長と堺", "パリへ", "天下布武", "首飾り事件", "本能寺の朝"):
        assert f"「{ok}」" not in w[0]


# --- ショートの頭の問いとループ -----------------------------------------------------

class FakeFont:
    def __init__(self, n):
        self.n = n

    def getlength(self, s):
        return len(s) * self.n


def test_hook_text_and_options():
    assert shorts.hook_text({"title": "a／b"}) == "a／b"
    assert shorts.hook_text({"title": "a", "hook": "問い？"}) == "問い？"
    assert shorts.options({"short": {}}) == (True, True)
    assert shorts.options({"short": {"hook_intro": False, "loop": False}}) == (False, False)
    assert shorts.end_seconds(True) < shorts.END_SECONDS


def test_hook_size_keeps_each_part_on_one_line():
    # 8字の行は 132px では 1056px で収まらず、118px（944px）なら収まる
    assert shorts.hook_size("ナポレオンは／背が低くなかった", FakeFont, 980) == 118


def test_intro_cuts_keeps_total_length():
    items = [("a", 0.5), ("b", 3.0), ("c", 1.0)]
    head, tail = shorts.intro_cuts(items, 30)
    total = sum(d for _p, d, _t in head) + sum(d for _p, d in tail)
    assert abs(total - 4.5) < 1e-6
    assert head[0] == ("a", 0.5, 0.0)
    assert all(t == 0.0 for _p, _d, t in head if _p == "a")
    ts = [t for _p, _d, t in head]
    assert ts == sorted(ts) and 0 < ts[-1] < 1
    assert tail[0][0] == "b" and tail[-1] == ("c", 1.0)


class FakePainter:
    W, H, title = 20, 30, "x"

    def __init__(self):
        self.calls = []

    def hook_overlay(self, img, text, t):
        self.calls.append(t)
        return img


def test_finish_overlays_head_and_loops(tmp_path):
    src = tmp_path / "f.png"
    Image.new("RGB", (20, 30)).save(src)
    p = FakePainter()
    out = shorts.finish([(src, 3.0), (src, 1.0)], p, "問い", tmp_path / "hook", 30, loop=True)
    assert out[0][0] != src and out[-1] == (out[0][0], shorts.LOOP_TAIL)     # 最後のコマ＝最初のコマ
    assert abs(sum(d for _p, d in out) - (4.0 + shorts.LOOP_TAIL)) < 1e-6
    assert p.calls and min(p.calls) == 0.0
    plain = shorts.finish([(src, 3.0)], p, "", tmp_path / "hook", 30, loop=False)
    assert plain == [(src, 3.0)]                                              # 切れば今までと同じ
