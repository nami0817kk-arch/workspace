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


def test_これから何を言うかの説明は埋め草(tmp_path):
    """**語り手が自分の段取りを説明しない**（2026-09-17 ユーザー指摘
    「得点の形も書いておきます。こう言うのはいらない」
    「あなたが何を書くかは言う必要ない」）。

    「ここから本題です」は 2026-09-10 に読み上げから外したのに、
    **書く側が別の言い方で戻していた**。言い回しを変えれば通る状態だった。
    """
    from src import review
    from src.script_model import parse_script

    head = "---\ntitle: リーズとはどんなクラブか\nformat: news\n---\n\n## 本編\n"
    for line in ("得点の形も書いておきます。",
                 "最後に、ここまでの数字を置いておきます。",
                 "得点の数も並べておきます。",
                 "ここから本題です。",
                 "なぜ1年も空いたのか。ここがこの話の中身です。"):
        found = review.check_filler(parse_script(head + f"キャスター: {line}\n"))
        assert found.ok is False, line
        assert "これから何を言うか" in found.detail, line

    ok = parse_script(head + "キャスター: 左サイドから中へ切れ込み、右足で決めました。\n")
    assert review.check_filler(ok).ok is True


def test_自分のチャンネルの過去回への言及は埋め草():
    """**自分のチャンネルの過去回に触れない**（2026-09-17 ユーザー指示「その文章は消して」）。

    ベンフィカの回に「このチャンネルでは9月6日に、アモリム監督のミランを
    扱いました」と書いていた。その回を見ていない人には通じず、見た人にも
    中身が増えない。「まとめサイトでは」を落としたのと同じ筋。
    """
    from src.review import check_filler
    from src.script_model import parse_script

    body = ("---\ntitle: T\n---\n\n## 何が起きたか\n\n"
            "キャスター: このチャンネルでは9月6日に、アモリム監督のミランを扱いました。\n")
    found = check_filler(parse_script(body))
    assert found.ok is False
    assert "過去回" in found.detail

    clean = ("---\ntitle: T\n---\n\n## 何が起きたか\n\n"
             "キャスター: ミランは本拠地での公式戦6試合で4敗しています。\n")
    assert check_filler(parse_script(clean)).ok is True
