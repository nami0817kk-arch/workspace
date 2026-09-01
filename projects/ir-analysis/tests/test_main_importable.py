"""標準出力の差し替えが、テストの邪魔をしない位置にあることのテスト。

main.py は Windows のコンソール向けに sys.stdout を UTF-8 の TextIOWrapper へ
差し替える。これが import 時や main() の中で走ると pytest の出力捕捉と噛み合わず、
「I/O operation on closed file」でこのファイル以外のテストまで巻き添えで落ちる。
（実際 ai-side-business では、そのせいで main を通るテストが1本も書けていなかった。）

差し替えるのはコンソールから起動したときだけ、つまり
`if __name__ == "__main__":` ブロックの中。ここではその位置を固定する。
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import main  # noqa: E402

SWAP = 'sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")'
ENTRY = 'if __name__ == "__main__":'


def test_capture_still_works_after_importing_main(capsys):
    """import が捕捉を壊していない（壊れていれば収集の時点で落ちる）。"""
    print("日本語も出せる")
    assert capsys.readouterr().out.strip() == "日本語も出せる"


def test_capture_survives_calling_main(capsys, monkeypatch):
    """main() を呼んでも捕捉が壊れない。

    差し替えが main() の中にあると、ここから先の出力が読めなくなる。
    引数なしのときの振る舞い（ヘルプ表示か終了か）は PJT ごとに違うので問わない。
    """
    monkeypatch.setattr(sys, "argv", ["main.py"])
    try:
        main.main()
    except SystemExit:
        pass

    capsys.readouterr()
    print("捕捉は生きている")
    assert capsys.readouterr().out.strip() == "捕捉は生きている"


def test_stdout_swap_lives_in_the_script_entry_block():
    """差し替えが import 時や main() の中へ戻されていないこと。"""
    source = Path(main.__file__).read_text(encoding="utf-8")
    assert SWAP in source, "差し替え自体は残っていること（コンソールの文字化け対策）"
    assert source.index(SWAP) > source.index(ENTRY), (
        "差し替えは __main__ ブロックの中に置く"
    )
