"""手で投稿するときの手順書。"""

import json

import pytest


def _built(tmp_path):
    for name in ("video.mp4", "thumbnail.png"):
        (tmp_path / name).write_bytes(b"x")
    (tmp_path / "subtitles.srt").write_text("1\n00:00:01,000 --> 00:00:03,000\nあ\n\n", encoding="utf-8")
    (tmp_path / "description.txt").write_text("見出し\n\n■ 目次\n0:00 オープニング\n", encoding="utf-8")
    (tmp_path / "script.json").write_text(
        json.dumps({"title": "遠藤航がCL登録外", "tags": ["サッカー", "海外サッカー"]},
                   ensure_ascii=False), encoding="utf-8")
    return tmp_path


def test_貼るものが投稿画面の順に並ぶ(tmp_path):
    from src.handoff import build_sheet

    sheet = build_sheet(_built(tmp_path))

    order = [sheet.index(k) for k in ("【1】", "【2】", "【3】", "【4】", "【5】", "【6】", "【7】")]
    assert order == sorted(order)


def test_タイトルとタグと説明がそのまま入る(tmp_path):
    from src.handoff import build_sheet

    sheet = build_sheet(_built(tmp_path))

    assert "遠藤航がCL登録外" in sheet
    assert "サッカー, 海外サッカー" in sheet      # カンマ区切りで貼れる
    assert "0:00 オープニング" in sheet           # 説明は中身ごと入る


def test_ファイルの場所は絶対パスで出す(tmp_path):
    """Studio のファイル選択に貼るので、相対パスでは使えない。"""
    from src.handoff import build_sheet

    sheet = build_sheet(_built(tmp_path))

    assert str((tmp_path / "video.mp4").resolve()) in sheet
    assert str((tmp_path / "thumbnail.png").resolve()) in sheet
    assert str((tmp_path / "subtitles.srt").resolve()) in sheet


def test_足りないファイルがあれば名前を出して止まる(tmp_path):
    """黙って不完全な手順書を出すと、貼る段になって気づく。"""
    from src.handoff import HandoffError, build_sheet

    _built(tmp_path)
    (tmp_path / "thumbnail.png").unlink()

    with pytest.raises(HandoffError) as caught:
        build_sheet(tmp_path)
    assert "thumbnail.png" in str(caught.value)


def test_手順書をファイルに書き出す(tmp_path):
    from src.handoff import write_sheet

    target = write_sheet(_built(tmp_path))

    assert target.name == "投稿手順.txt"
    assert "【1】" in target.read_text(encoding="utf-8")
