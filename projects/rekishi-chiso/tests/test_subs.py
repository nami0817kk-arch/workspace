from chiso import subs


class FakeFont:
    def getlength(self, s):
        return len(s) * 10


def test_chunks_split_at_sentence_end_but_not_inside_quotes():
    t = "彼女は言った。「パンがなければ。お菓子を」と書かれている。"
    cs = subs.chunks(t, limit=12)
    assert "「パンがなければ。お菓子を」と書かれている。" in cs   # 「」の中の。では切らない


def test_chunks_merge_tiny_tail():
    cs = subs.chunks("ところが彼女は、その首飾りを買っていないんです。え。", limit=40)
    assert cs == ["ところが彼女は、その首飾りを買っていないんです。え。"]


def test_chunks_respect_limit_by_commas():
    t = "当時のパリの日雇いの人の日当で数えると、休まず働いて、ざっと《3000年分》です。それどころか、一銭も得をしていない。"
    cs = subs.chunks(t, limit=30)
    assert all(len(subs.plain(c)) <= 30 for c in cs)
    assert "".join(cs) == t                                  # 文字は失われない


def test_emphasis_mask():
    body, mask = subs.emphasis_mask("ざっと《3000年分》です")
    assert body == "ざっと3000年分です"
    assert [c for c, m in zip(body, mask) if m] == list("3000年分")


def test_wrap_balanced_prefers_middle_and_good_breaks():
    rows = subs.wrap_balanced("あいうえおかきくけこ、さしすせそたち", FakeFont(), 120)
    assert len(rows) == 2 and rows[0].endswith("、")
    assert not rows[1].startswith(("、", "。"))
