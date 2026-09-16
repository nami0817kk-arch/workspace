"""draft が、動画を作らなくても分かる点検を出すか（2026-09-16）。"""
import io
from pathlib import Path


def test_draft_が背番号とタイトルの主語をその場で知らせる(tmp_path, monkeypatch, capsys):
    """**review にしかなかった検査を draft でも出す。**

    プレミア20クラブの回で、背番号（4本）と「頭14字に名前が無い」（20本）が
    素通りした。review は動画を書き出したあとに走るので、
    **20本つくってから止まる**ところだった。
    """
    from src import review
    from src.script_model import parse_script

    script = parse_script(
        "---\ntitle: プレミアリーグ20クラブ紹介 ⑬リーズ\nformat: news\n---\n\n"
        "## 本編\nキャスター: 田中碧がいます。背番号は22です。\n"
    )
    filler = review.check_filler(script)
    subject = review.check_title_subject(script)
    assert filler.ok is False and "背番号" in filler.detail
    assert subject.ok is False

    ok = parse_script(
        "---\ntitle: リーズとはどんなクラブか ⑬プレミア20クラブ紹介\nformat: news\n---\n\n"
        "## 本編\nキャスター: 田中碧がいます。2024年に加入しました。\n"
    )
    assert review.check_filler(ok).ok is True
