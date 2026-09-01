"""Windows の画面出力まわり。

運用するPCが Windows なので、ここが落ちると `fetch --check` も `doctor` も
`today` も打てなくなる。実際に両方で落ちたので、戻り防止に置いておく。
"""

import io
from datetime import date
from pathlib import Path

from src import cli


def test_no_posix_only_strftime_directive():
    """`%-m` `%-d` は Windows の strftime に無く、ValueError で落ちる。"""
    source = Path(cli.__file__).read_text(encoding="utf-8")
    assert "%-" not in source


def test_month_and_day_have_no_leading_zero():
    day = date(2026, 9, 1)
    assert f"{day.year}年{day.month}月{day.day}日" == "2026年9月1日"


def test_output_is_switched_to_utf8(monkeypatch):
    """cp932 のままだと `✓` `×` `■` を出した時点で落ちる。"""
    calls = []

    class Stream(io.StringIO):
        def reconfigure(self, **kwargs):
            calls.append(kwargs)

    monkeypatch.setattr(cli.sys, "stdout", Stream())
    monkeypatch.setattr(cli.sys, "stderr", Stream())
    cli._use_utf8()

    expected = {"encoding": "utf-8", "errors": "replace"}
    assert calls == [expected, expected]


def test_survives_a_stream_that_refuses_to_reconfigure(monkeypatch):
    class Stream(io.StringIO):
        def reconfigure(self, **kwargs):
            raise ValueError("再設定できません")

    monkeypatch.setattr(cli.sys, "stdout", Stream())
    monkeypatch.setattr(cli.sys, "stderr", Stream())
    cli._use_utf8()  # 例外が出ないこと


def test_survives_a_stream_without_reconfigure(monkeypatch):
    monkeypatch.setattr(cli.sys, "stdout", io.StringIO())
    monkeypatch.setattr(cli.sys, "stderr", io.StringIO())
    cli._use_utf8()  # 例外が出ないこと


# 候補を選ぶ画面で、日本語の見出しだけ倍の幅になって折り返していた。
# 文字数で切っていたため。並べて比べる画面なので、幅をそろえる。


def test_全角は2桁として数える():
    assert cli._columns("abc") == 3
    assert cli._columns("移籍") == 4
    assert cli._columns("Man Utd と移籍") == 14   # 半角8 + 全角3×2


def test_短い見出しはそのまま():
    assert cli._fit("Arsenal latest", 60) == "Arsenal latest"


def test_日本語と英語が同じ幅に収まる():
    japanese = cli._fit("あ" * 60, 20)
    english = cli._fit("a" * 60, 20)
    assert cli._columns(japanese) <= 20
    assert cli._columns(english) <= 20
    assert japanese.endswith("…")
    assert english.endswith("…")


def test_全角の途中で半端に切らない():
    """1桁だけ残して全角を入れると、幅をはみ出す。"""
    fitted = cli._fit("あ" * 10, 7)
    assert cli._columns(fitted) <= 7
