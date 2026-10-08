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


# --- 冒頭の疑問と最後のもう一つの疑問（10-08）---------------------------------------------------
from chiso import shorts
from chiso.script import Line


def _lines():
    return [Line(index=4, section=2, speaker="語り", text="一行目。", tone="重い", shorts=("s1",), pause=1.0),
            Line(index=9, section=3, speaker="語り", text="最後。", shorts=("s1",), reaction='{"x":1}')]


def test_extra_lines_are_spoken_by_listener_with_neighbours_screen():
    hook, tease = shorts.extra_lines(_lines(), {"hook": "本当に／低かったの？", "tease": "じゃあ誰？"}, True)
    assert (hook.index, hook.speaker, hook.text, hook.tone, hook.pause) == (-1, "聞き", "本当に低かったの？", "疑問", None)
    assert hook.section == 2 and hook.shorts == ("s1",)              # 画面の状態は1行目のまま
    assert (tease.index, tease.speaker, tease.text, tease.pause) == (-2, "聞き", "じゃあ誰？", shorts.TEASE_GAP)
    assert tease.section == 3 and tease.reaction is None             # 寄りは引き継がない


def test_extra_lines_off_or_missing():
    hook, tease = shorts.extra_lines(_lines(), {"hook": "問い？", "tease": "次？"}, False)
    assert hook is None and tease is not None                        # hook_say: false は声だけ切る
    assert shorts.extra_lines(_lines(), {"title": "題"}, True) == (None, None)
    assert shorts.extra_lines([], {"hook": "a？"}, True) == (None, None)


def test_hook_say_default_and_question_helpers():
    assert shorts.hook_say({"short": {}}) is True
    assert shorts.hook_say({"short": {"hook_say": False}}) is False
    assert shorts.is_question("誰が／描いた？") and not shorts.is_question("描いた。")
    assert shorts.tease_text({"tease": " 誰？ "}) == "誰？"


def test_tease_size_keeps_parts_whole():
    # いちばん長い区切りは「『チビの独裁者』の絵を」（11字）：11×size が 960 に収まる最大は 84（94 だと 1034）
    size = shorts.tease_size("じゃあ、／『チビの独裁者』の絵を／描き続けたのは誰？", lambda n: _Font(n), 960)
    assert size == 84
    assert len(shorts._wrap("じゃあ、／『チビの独裁者』の絵を／描き続けたのは誰？", _Font(size), 960)) == 3


class _Font:
    def __init__(self, n):
        self.n = n

    def getlength(self, s):
        return len(s) * self.n


def test_tease_items_cached(tmp_path):
    from PIL import Image

    class P:
        W, H = 10, 20
        calls = 0

        def tease_card(self, bg, text):
            P.calls += 1
            return Image.new("RGB", (10, 20))

        def with_cast(self, img, who, hop, text, tone):
            assert who == shorts.TEASER and tone == "疑問"
            return img
    a = shorts.tease_items(P(), None, "誰？", 4.5, tmp_path)
    b = shorts.tease_items(P(), None, "誰？", 4.5, tmp_path)
    assert a == b and a[0][1] == 4.5 and P.calls == 1
