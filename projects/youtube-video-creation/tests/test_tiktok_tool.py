"""TikTok の説明欄を作るところ（`tools/tiktok.py`）。"""
import importlib.util
import io
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("tiktok_tool", ROOT / "tools" / "tiktok.py")
tiktok = importlib.util.module_from_spec(spec)
sys.modules["tiktok_tool"] = tiktok
spec.loader.exec_module(tiktok)


DESCRIPTION = """16歳が並んだ相手はルーニー

16歳のダウマンが並んだのは、ルーニーの記録だった

#サッカー #アーセナル #マックス・ダウマン

■ 出典
https://www.espn.com/soccer/story/_/id/1234
https://www.espn.com/soccer/story/_/id/5678

■ クレジット
音声: VOICEVOX（四国めたん・離途）
写真: Some Photographer / CC BY-SA 4.0
────────────
※この動画は報道をもとに構成しています
"""


def caption_of(tmp_path) -> str:
    io.open(tmp_path / "description.txt", "w", encoding="utf-8").write(DESCRIPTION)
    return tiktok.caption(tmp_path)


def test_YouTubeへの行き方を説明欄の上のほうに置く(tmp_path):
    """**TikTok から YouTube へ渡す道を、説明欄にも書く**（2026-09-16 指示）。

    それまでは出典やクレジットと一緒に**いちばん下**にあり、しかも
    `@kaigai-soccer-riyuu` とだけ書いていた。TikTok で @ から始まる文字列は
    TikTok の利用者のことなので、YouTube のチャンネル名だと読めない。
    """
    text = caption_of(tmp_path)
    lines = text.splitlines()

    assert "チャンネル名「海外サッカーの理由」" in text
    assert "youtube.com/@kaigai-soccer-riyuu" in text

    # **ハッシュタグより先に出す。**下に置くと、説明欄を開いた人にしか見えない
    where_yt = next(i for i, x in enumerate(lines) if "YouTube" in x)
    where_tag = next(i for i, x in enumerate(lines) if x.startswith("#"))
    assert where_yt < where_tag, text

    # 出典とクレジットは、これまでどおり下に残す（表示が利用の条件）
    where_credit = next(i for i, x in enumerate(lines) if x.startswith("音声:"))
    assert where_tag < where_credit, text
    assert "CC BY-SA 4.0" in text


def test_説明欄の中身はこれまでどおり(tmp_path):
    """題名・本編の題・ハッシュタグ・出典の媒体名・注記が、順に並ぶ。"""
    text = caption_of(tmp_path)

    assert text.startswith("16歳が並んだ相手はルーニー\n")
    assert "16歳のダウマンが並んだのは、ルーニーの記録だった" in text
    # 出典は媒体名だけ（TikTok の説明欄ではURLが押せないので、長いURLは邪魔）
    assert "出典: espn.com" in text
    assert "espn.com/soccer" not in text
    # ハッシュタグは「海外サッカー」を足して4つまで
    tags = next(x for x in text.splitlines() if x.startswith("#")).split()
    assert tags == ["#サッカー", "#アーセナル", "#マックス・ダウマン", "#海外サッカー"]
    assert "※この動画は報道をもとに構成しています" in text
    assert len(text) <= tiktok.CAPTION_MAX
