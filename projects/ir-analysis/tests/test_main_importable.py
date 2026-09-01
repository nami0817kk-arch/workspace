"""main を import しても標準出力が差し替わらないことのテスト。

main.py は Windows のコンソール向けに sys.stdout を UTF-8 の TextIOWrapper へ
差し替える。これを import 時に実行すると pytest の出力捕捉と噛み合わず、
「I/O operation on closed file」でこのファイル以外のテストまで巻き添えで落ちる。
（実際 ai-side-business では、そのせいで main を通るテストが1本も書けていなかった。）

差し替えは main() の中で行う。ここでは import 時に走っていないことを見る。
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import main  # noqa: E402

SWAP = 'sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")'


def test_capture_still_works_after_importing_main(capsys):
    """import が捕捉を壊していない（壊れていれば収集の時点で落ちる）。"""
    print("日本語も出せる")
    assert capsys.readouterr().out.strip() == "日本語も出せる"


def test_stdout_swap_is_not_at_module_level():
    """差し替え行がモジュール直下に戻されていないこと。"""
    source = Path(main.__file__).read_text(encoding="utf-8")
    assert SWAP in source, "差し替え自体は残っていること（コンソールの文字化け対策）"
    for line in source.splitlines():
        assert line != SWAP, "モジュール直下ではなく main() の中に置く"
