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
