"""入口（main() 経路）のテスト。

各コマンドの中身は見ない。「入口が壊れたら気づける」ことだけを担保する。
一番効くのは、パーサに登録したコマンドと COMMANDS のキーのズレ検知。
サブコマンドを足して COMMANDS に足し忘れると、実行時に KeyError で落ちる。
"""

import argparse
import sys
from pathlib import Path
from unittest.mock import Mock

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import main  # noqa: E402


def _subcommand_names(parser) -> set[str]:
    """パーサに登録されたサブコマンド名を取り出す。

    argparse は登録済みサブコマンドの公開 API を持たないため、内部の
    _SubParsersAction を見ている。テストの中だけの割り切り。
    """
    for action in parser._actions:
        if isinstance(action, argparse._SubParsersAction):
            return set(action.choices)
    return set()


def test_parser_commands_and_handler_table_match():
    """登録コマンドと COMMANDS のキーが一致すること。

    ズレると「パーサは受け付けるのに実行時 KeyError」か「実装したのに呼ばれない」
    のどちらかになる。どちらも入口が黙って壊れる形。
    """
    assert _subcommand_names(main.build_parser()) == set(main.COMMANDS)


def test_every_handler_is_callable():
    for name, handler in main.COMMANDS.items():
        assert callable(handler), name


def test_no_arguments_prints_help_without_failing(monkeypatch, capsys):
    """引数なしはエラーにせず使い方を出す。"""
    monkeypatch.setattr(sys, "argv", ["main.py"])
    assert main.main() is None
    assert "usage" in capsys.readouterr().out


def test_unknown_command_exits_with_code_2(monkeypatch):
    """存在しないコマンドは argparse の作法どおり終了コード2。"""
    monkeypatch.setattr(sys, "argv", ["main.py", "そんなコマンドは無い"])
    with pytest.raises(SystemExit) as e:
        main.main()
    assert e.value.code == 2


def test_bare_subcommands_reach_their_own_handler(monkeypatch):
    """追加引数なしで通るコマンドが、それぞれ対応するハンドラへ行くこと。

    追加引数が必須のコマンドはここでは対象外。配線のズレは上のテストが見ている。
    """
    checked = []
    for name in sorted(_subcommand_names(main.build_parser())):
        try:
            main.build_parser().parse_args([name])
        except SystemExit:
            continue        # 追加引数が要るコマンド

        mocks = {k: Mock(name=k) for k in main.COMMANDS}
        monkeypatch.setattr(main, "COMMANDS", mocks)
        monkeypatch.setattr(sys, "argv", ["main.py", name])
        try:
            main.main()
        except SystemExit:
            continue        # 引数の追加チェックで弾かれるものは対象外

        called = [k for k, m in mocks.items() if m.called]
        assert called == [name], f"{name} が {called} に振り分けられた"
        checked.append(name)

    assert checked, "引数なしで通るコマンドが1つも無い"
