# -*- coding: utf-8 -*-
"""シリーズ名は公開する題の後ろにだけ付く（2026-09-23 指示「サブタイトルにプレミアリーグチーム紹介として」）。"""
from src.script_model import parse_script, published_title
from src import subtitles


SCRIPT = """---
title: 借金で解散命令。マンチェスター・ユナイテッドが生き延びたのは
series: プレミアリーグチーム紹介
---

## 冒頭
キャスター: 借金で解散命令。マンチェスター・ユナイテッドが生き延びたのは。
"""


def test_公開する題にはシリーズ名が後ろに付く(tmp_path):
    script = parse_script(SCRIPT)
    assert published_title(script) == "借金で解散命令。マンチェスター・ユナイテッドが生き延びたのは｜プレミアリーグチーム紹介"
    files = subtitles.write_outputs(script, tmp_path)
    first = files["description"].read_text(encoding="utf-8").partition("\n")[0]
    assert first.endswith("｜プレミアリーグチーム紹介")


def test_読み上げの1行目はシリーズ名を含まない():
    script = parse_script(SCRIPT)
    assert "プレミアリーグチーム紹介" not in script.scenes[0].lines[0].text
    assert script.title == "借金で解散命令。マンチェスター・ユナイテッドが生き延びたのは"


def test_seriesが無ければ題はそのまま(tmp_path):
    script = parse_script(SCRIPT.replace("series: プレミアリーグチーム紹介\n", ""))
    assert published_title(script) == script.title


def test_手順書の題にもシリーズ名が付く(tmp_path):
    import json
    from src.handoff import build_sheet

    for name in ("video.mp4", "thumbnail.png"):
        (tmp_path / name).write_bytes(b"x")
    (tmp_path / "subtitles.srt").write_text("1\n00:00:01,000 --> 00:00:03,000\nあ\n\n", encoding="utf-8")
    (tmp_path / "description.txt").write_text("見出し\n\n■ 目次\n0:00 オープニング\n", encoding="utf-8")
    (tmp_path / "script.json").write_text(
        json.dumps({"title": "借金で解散命令", "series": "プレミアリーグチーム紹介", "tags": []},
                   ensure_ascii=False), encoding="utf-8")
    assert "借金で解散命令｜プレミアリーグチーム紹介" in build_sheet(tmp_path)


def test_続き物は別の再生リストへ():
    """**プレミア20クラブ紹介は専用の再生リスト**（2026-09-24 指示）。

    20本が1つのシリーズで並ぶので、ニュースの再生リストに混ぜると
    自動再生が紹介ものだけになる。振り分けは**公開する題の後ろ書き**で見る。
    """
    from src.cli import MAIN_PLAYLIST, SERIES_PLAYLIST

    title = "ボーンマスに何があったのか｜プレミアリーグチーム紹介"
    series = title.rsplit("｜", 1)[-1]
    assert SERIES_PLAYLIST.get(series) and SERIES_PLAYLIST[series] != MAIN_PLAYLIST
    assert SERIES_PLAYLIST.get("久保建英が8番を返した日") is None
