"""公開済みの概要欄を、記事から作ったと読めない形に直すところ（2026-09-30）。"""
import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("fix_old_descriptions", ROOT / "tools" / "fix_old_descriptions.py")
tool = importlib.util.module_from_spec(spec)
sys.modules["fix_old_descriptions"] = tool
spec.loader.exec_module(tool)

OLD = """アップ中の負傷で急きょデビュー

この動画が答える問い: 準備のないデビューで、彼は何をしたのか

※各社の報道をもとにしています。クラブが発表した「確定」、
報道機関が伝える「報道」、SNS段階の「未確認」、
経緯の説明である「背景」を画面上で分けています。

■ 目次
0:00 オープニング
0:13 試合はどう動いたか

■ 出典
https://www.espn.com/soccer/report/_/gameId/401879287
https://x.com/FabrizioRomano/status/2096236342128566659

■ クレジット
音声: VOICEVOX（四国めたん・青山龍星）
画像: Wikimedia Commons

#サッカー #海外サッカー

────────────
※ 画像: File:Enzo.jpg / Hossein / CC BY 4.0 / https://commons.wikimedia.org/wiki/File:Enzo.jpg
"""


def test_記事から作ったと読める行を消し_条件の表示は残す():
    new = tool.fix(OLD)
    assert "■ 出典" not in new and "espn.com" not in new and "x.com" not in new
    assert "各社の報道をもとに" not in new
    assert "※画面の札で、クラブが発表した「確定」" in new
    assert "\n画像: " not in new
    # 残すもの
    assert "■ 目次\n0:00 オープニング\n0:13 試合はどう動いたか" in new
    assert "音声: VOICEVOX（四国めたん・青山龍星）" in new
    assert "※ 画像: File:Enzo.jpg / Hossein / CC BY 4.0" in new
    assert "#サッカー #海外サッカー" in new
    assert "\n\n\n" not in new


def test_本人の言葉の回の注記も消す():
    text = "題\n\n※発言は下の記事から引いています。\n\n■ 目次\n0:00 オープニング\n"
    assert "記事" not in tool.fix(text)


def test_直すところが無ければそのまま():
    text = "題\n\n■ 目次\n0:00 オープニング\n\n■ クレジット\n音声: VOICEVOX（…）\n"
    assert tool.fix(text) == text
