"""media サブコマンドの振り分けのテスト。

cmd_media は長かったので、分岐ごとに名前を付けて切り出した。
切り出しで配線が狂うと「別の処理が動く」という気づきにくい壊れ方をするため、
どの action がどの処理に行くかをここで固定する。

  python -m unittest discover -s tests
"""
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

# main は import 時に sys.stdout を UTF-8 の TextIOWrapper へ差し替える
# （Windows のコンソール向け）。pytest の捕捉と噛み合わず後続テストが
# 「I/O operation on closed file」で落ちるため、import の前後で退避・復元する。
_stdout = sys.stdout
import main  # noqa: E402
_wrapper, sys.stdout = sys.stdout, _stdout
# detach しないと、差し替えられた TextIOWrapper が回収されるときに
# pytest 側のバッファまで閉じてしまう。閉じずに切り離す。
_wrapper.detach()

# action -> 呼ばれるべき main の属性名
ROUTES = {
    "params":    "_media_params",
    "plan":      "_media_plan",
    "simulate":  "_media_simulate",
    "genre":     "_media_genre",
    "keywords":  "_media_keywords",
    "write":     "_media_write",
    "publish":   "_media_publish",
    "stats":     "_media_stats",
}


class MediaDispatchTest(unittest.TestCase):

    def test_each_action_routes_to_its_own_handler(self):
        for action, handler in ROUTES.items():
            with self.subTest(action=action):
                args = SimpleNamespace(media_command=action)
                with patch.object(main, handler) as called:
                    main.cmd_media(args)
                called.assert_called_once_with(args)

    def test_no_action_falls_back_to_status(self):
        """media_command が無いときは status（一覧＋リライト待ち）。"""
        for empty in (None, ""):
            with self.subTest(media_command=empty):
                args = SimpleNamespace(media_command=empty)
                with patch.object(main, "_media_status") as called:
                    main.cmd_media(args)
                called.assert_called_once_with(args)

    def test_unknown_action_falls_back_to_status(self):
        args = SimpleNamespace(media_command="そんなコマンドは無い")
        with patch.object(main, "_media_status") as called:
            main.cmd_media(args)
        called.assert_called_once_with(args)

    def test_rewrite_and_check_call_analytics_directly(self):
        with patch.object(main.media_analytics, "print_rewrite_queue") as rewrite:
            main.cmd_media(SimpleNamespace(media_command="rewrite"))
        rewrite.assert_called_once_with()

        with patch.object(main.media_analytics, "print_calibration") as check:
            main.cmd_media(SimpleNamespace(media_command="check"))
        check.assert_called_once_with()

    def test_status_shows_articles_then_rewrite_queue(self):
        """既定表示は「記事一覧 → リライト待ち」の順。"""
        with patch.object(main.media_analytics, "print_articles") as articles, \
             patch.object(main.media_analytics, "print_rewrite_queue") as rewrite:
            main.cmd_media(SimpleNamespace(media_command=None))
        articles.assert_called_once_with()
        rewrite.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
