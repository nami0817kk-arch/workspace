"""入口（main() 経路）のテスト。

各コマンドの中身は見ない（DB・ネットワークが要る）。配線の確認まで。
一番効くのは、パーサに登録したサブコマンドと振り分け先のズレ検知。
sub.add_parser しただけで if/elif に足し忘れると、実行しても何も起きずに
ヘルプが出るだけになる。エラーにならないぶん気づきにくい。
"""

import argparse
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import main  # noqa: E402

# サブコマンド -> (渡す引数, 呼ばれるべきハンドラ名)
ROUTES = {
    "rank":     (["rank"],                "cmd_rank"),
    "update":   (["update"],              "cmd_update"),
    "report":   (["report"],              "cmd_report"),
    "backfill": (["backfill"],            "cmd_backfill"),
    "detect":   (["detect"],              "cmd_detect"),
    "query":    (["query", "SELECT 1"],   "cmd_query"),
}


def _build_parser(monkeypatch):
    """main() が組み立てたパーサを取り出す。

    パーサは main() の中で作られるので、parse_args を差し替えて捕まえる。
    返り値の command を None にしておけば、main() はヘルプを出して終わる。
    """
    captured = {}

    def spy(self, *args, **kwargs):
        captured.setdefault("parser", self)
        return argparse.Namespace(command=None)

    monkeypatch.setattr(argparse.ArgumentParser, "parse_args", spy)
    monkeypatch.setattr(sys, "argv", ["main.py"])
    main.main()
    return captured["parser"]


def _subcommand_names(parser) -> set[str]:
    """登録済みサブコマンド名。argparse に公開 API が無いため内部を見ている。"""
    for action in parser._actions:
        if isinstance(action, argparse._SubParsersAction):
            return set(action.choices)
    return set()


def test_registered_subcommands_all_have_a_route(monkeypatch):
    """登録したサブコマンドが、すべて振り分け先を持っていること。"""
    assert _subcommand_names(_build_parser(monkeypatch)) == set(ROUTES)


def test_every_handler_exists_and_is_callable():
    for _, handler in ROUTES.values():
        assert callable(getattr(main, handler))


def test_no_arguments_prints_help_without_failing(monkeypatch, capsys):
    monkeypatch.setattr(sys, "argv", ["main.py"])
    assert main.main() is None
    assert "usage" in capsys.readouterr().out


def test_unknown_command_exits_with_code_2(monkeypatch):
    monkeypatch.setattr(sys, "argv", ["main.py", "そんなコマンドは無い"])
    with pytest.raises(SystemExit) as e:
        main.main()
    assert e.value.code == 2


@pytest.mark.parametrize("name", sorted(ROUTES))
def test_subcommand_reaches_its_own_handler(name, monkeypatch):
    """他のハンドラが呼ばれていないことまで見る（取り違えの検知）。"""
    argv, expected = ROUTES[name]
    called = []
    for _, handler in ROUTES.values():
        monkeypatch.setattr(main, handler,
                            lambda args, h=handler: called.append(h))

    monkeypatch.setattr(sys, "argv", ["main.py"] + argv)
    main.main()

    assert called == [expected]
