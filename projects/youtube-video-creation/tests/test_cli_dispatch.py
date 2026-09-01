"""サブコマンドの振り分けと、切り出したハンドラ。

1本の長い if の連なりだったものを、コマンドごとの関数に切り出した。
切り出しで振る舞いが変わっていないこと（特に終了コード）をここで押さえる。
"""

import re
from pathlib import Path
from types import SimpleNamespace

from src import cli
from src.config import load_config


def test_全てのサブコマンドに処理がある():
    """main() の add_parser と HANDLERS がずれていないこと。

    ずれると「引数は受け付けるのに何も起きず 1 で終わる」という、
    いちばん気づきにくい壊れ方をする。
    """
    source = Path(cli.__file__).read_text(encoding="utf-8")
    declared = set(re.findall(r'add_parser\(\s*"([^"]+)"', source))
    assert declared == set(cli.HANDLERS), declared ^ set(cli.HANDLERS)


def test_知らないコマンドは1を返す():
    args = SimpleNamespace(command="そんなコマンドは無い")
    assert cli._dispatch(args, None) == 1


def test_終了コードを返さない処理は1になる(monkeypatch):
    """切り出す前は、return せずに抜けると最後の `return 1` に落ちていた。"""
    monkeypatch.setitem(cli.HANDLERS, "check", lambda args, config: None)
    assert cli._dispatch(SimpleNamespace(command="check"), None) == 1


def test_処理が返した終了コードをそのまま返す(monkeypatch):
    monkeypatch.setitem(cli.HANDLERS, "check", lambda args, config: 3)
    assert cli._dispatch(SimpleNamespace(command="check"), None) == 3


def test_check_は台本の書式と尺を出して0を返す(capsys):
    args = SimpleNamespace(command="check", script="scripts/sample.md")
    assert cli._cmd_check(args, load_config(None)) == 0
    out = capsys.readouterr().out
    assert "タイトル:" in out
    assert "想定尺:" in out
    assert out.rstrip().endswith("書式OK")


def test_clubs_は見出しからクラブとリーグを読み取る(capsys):
    args = SimpleNamespace(command="clubs", text="Arsenal close to signing")
    assert cli._cmd_clubs(args, None) == 0
    out = capsys.readouterr().out
    assert "アーセナル" in out
    assert "リーグ: england" in out


def test_clubs_は辞書に無ければ足し方を言って0で終わる(capsys):
    args = SimpleNamespace(command="clubs", text="どこのクラブでもない話")
    assert cli._cmd_clubs(args, None) == 0
    assert "aka に足して" in capsys.readouterr().out
