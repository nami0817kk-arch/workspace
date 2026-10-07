from chiso.shorts import _wrap


class FakeFont:
    def getlength(self, s):
        return len(s) * 10


def test_wrap_keeps_punctuation_off_line_heads():
    rows = _wrap("あいうえ、かき", FakeFont(), 40)
    assert all(not r.startswith("、") for r in rows)
    assert rows[0] == "あいうえ、"


def test_wrap_forced_break():
    assert _wrap("あい／うえ", FakeFont(), 1000) == ["あい", "うえ"]
