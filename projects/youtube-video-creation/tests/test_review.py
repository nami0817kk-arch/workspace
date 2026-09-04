import json

import pytest

from src.review import built_duration, inspect, manual_checks
from src.script_model import parse_script

BODY = (
    "---\ntitle: T\nsources: [https://example.com/a]\n"
    "tags: [サッカー, 海外サッカー]\n---\n\n"
    "## 章1\n\nキャスター: いちぎょうめ。\n  source: 確定\n\n"
    "## 章2\n\nキャスター: にぎょうめ。\n  source: 報道\n"
)


def _built(tmp_path, seconds=150.0):
    for name in ("video.mp4", "thumbnail.png"):
        (tmp_path / name).write_bytes(b"x")
    (tmp_path / "subtitles.srt").write_text(
        "1\n00:00:01,000 --> 00:00:03,000\n字幕\n", encoding="utf-8"
    )
    (tmp_path / "description.txt").write_text("概要", encoding="utf-8")
    (tmp_path / "script.json").write_text(
        json.dumps({"scenes": [{"lines": [{"start": seconds - 10, "duration": 10}]}]}),
        encoding="utf-8",
    )
    return tmp_path


def _by_label(findings):
    return {f.label: f for f in findings}


def test_a_finished_build_passes_everything(tmp_path):
    findings = inspect(parse_script(BODY), _built(tmp_path), 100.0)
    assert all(f.ok for f in findings), [f.line() for f in findings if not f.ok]


def test_missing_files_are_named(tmp_path):
    (tmp_path / "video.mp4").write_bytes(b"x")
    result = _by_label(inspect(parse_script(BODY), tmp_path))
    assert result["書き出し"].ok is False
    assert "thumbnail.png" in result["書き出し"].detail
    assert "video.mp4" not in result["書き出し"].detail


def test_a_script_without_sources_fails(tmp_path):
    body = BODY.replace("sources: [https://example.com/a]\n", "")
    result = _by_label(inspect(parse_script(body), _built(tmp_path)))
    assert result["出典"].ok is False


def test_a_script_without_any_tier_fails(tmp_path):
    body = BODY.replace("  source: 確定\n", "").replace("  source: 報道\n", "")
    result = _by_label(inspect(parse_script(body), _built(tmp_path)))
    assert result["確度"].ok is False


def test_a_single_chapter_fails(tmp_path):
    body = "---\ntitle: T\nsources: [https://example.com/a]\n---\n\n## 章1\n\nキャスター: あ。\n  source: 確定\n"
    result = _by_label(inspect(parse_script(body), _built(tmp_path)))
    assert result["チャプター"].ok is False


@pytest.mark.parametrize(
    "seconds, ok",
    # 1〜2分（2026-09-04 に 90〜240秒 から変更）。参考3チャンネルは 1:01〜1:59
    [(50.0, False), (60.0, True), (95.0, True), (130.0, True), (150.0, False), (235.0, False)],
)
def test_the_length_has_a_floor_and_a_ceiling(tmp_path, seconds, ok):
    result = _by_label(inspect(parse_script(BODY), _built(tmp_path), seconds))
    assert result["尺"].ok is ok


def test_the_length_is_skipped_before_a_build(tmp_path):
    labels = [f.label for f in inspect(parse_script(BODY), tmp_path, None)]
    assert "尺" not in labels


def test_an_over_long_title_fails(tmp_path):
    body = BODY.replace("title: T", "title: " + "あ" * 120)
    result = _by_label(inspect(parse_script(body), _built(tmp_path)))
    assert result["タイトル"].ok is False


def test_the_duration_is_read_from_the_build(tmp_path):
    assert built_duration(_built(tmp_path, 165.0)) == 165.0


def test_a_missing_or_broken_build_file_gives_no_duration(tmp_path):
    assert built_duration(tmp_path) is None
    (tmp_path / "script.json").write_text("{ broken", encoding="utf-8")
    assert built_duration(tmp_path) is None


def test_manual_checks_are_listed():
    checks = manual_checks()
    assert len(checks) >= 4
    assert any("確度バッジ" in c for c in checks)


def test_タグが無ければ止める(tmp_path):
    body = BODY.replace("tags: [サッカー, 海外サッカー]\n", "")
    result = _by_label(inspect(parse_script(body), _built(tmp_path), 150.0))
    assert result["タグ"].ok is False


def test_タグの合計が上限を超えたら止める(tmp_path):
    from src import tags as tags_mod

    many = ", ".join(f"タグ{n:03d}あいうえおかきくけこ" for n in range(40))
    body = BODY.replace("tags: [サッカー, 海外サッカー]", f"tags: [{many}]")
    script = parse_script(body)
    assert tags_mod.text_length(script.tags) > tags_mod.MAX_TAGS_TEXT
    result = _by_label(inspect(script, _built(tmp_path), 150.0))
    assert result["タグ"].ok is False


# 手引きには「出典URLを開いて確認しろ」とだけ書いてあったが、人は5本を毎回は
# 開かない。開かないまま upload に進むと、消えた記事を出典に載せた動画が出る。
# 生死だけは機械で見る。実測で kicker が生きている記事に 403 を返したので、
# ボット判定と「消えた」は区別する。


def test_生きている出典はそのまま通る():
    from src.review import check_sources

    (f,) = check_sources(["https://a.com/1"], fetch=lambda u: 200)
    assert f.ok


def test_消えた出典は止める():
    from src.review import check_sources

    (f,) = check_sources(["https://a.com/gone"], fetch=lambda u: 404)
    assert not f.ok
    assert "404" in f.detail


def test_ボット判定は消えた扱いにしない():
    """kicker は生きている記事にも 403 を返す（実測）。止めずに目視に回す。"""
    from src.review import check_sources

    (f,) = check_sources(["https://kicker.de/a"], fetch=lambda u: 403)
    assert f.ok
    assert "目で確かめる" in f.detail


def test_つながらない出典は止める():
    from src.review import check_sources

    def boom(url):
        raise OSError("dns")

    (f,) = check_sources(["https://nowhere.example/1"], fetch=boom)
    assert not f.ok


# 字幕の逆行やゼロ秒表示は、プレイヤーでは黙って飛ばされるので投稿してからしか
# 気づけない。書き出した srt をそのまま読んで確かめる。


def _srt(tmp_path, body):
    path = tmp_path / "subtitles.srt"
    path.write_text(body, encoding="utf-8")
    return path


def test_正しい字幕は枚数を数えて通す(tmp_path):
    from src.review import check_subtitles

    f = check_subtitles(_srt(tmp_path, """1
00:00:01,000 --> 00:00:03,000
一枚目

2
00:00:03,500 --> 00:00:05,000
二枚目
"""))
    assert f.ok
    assert "2枚" in f.detail


def test_ゼロ秒の表示を止める(tmp_path):
    from src.review import check_subtitles

    f = check_subtitles(_srt(tmp_path, """1
00:00:03,000 --> 00:00:03,000
消えている字幕
"""))
    assert not f.ok
    assert "0秒" in f.detail


def test_前の字幕と重なっていたら止める(tmp_path):
    from src.review import check_subtitles

    f = check_subtitles(_srt(tmp_path, """1
00:00:01,000 --> 00:00:04,000
一枚目

2
00:00:03,000 --> 00:00:05,000
重なっている
"""))
    assert not f.ok
    assert "重なって" in f.detail


def test_srtが無ければ止める(tmp_path):
    from src.review import check_subtitles

    assert not check_subtitles(tmp_path / "subtitles.srt").ok


# 2026-09-04 に見つけた不具合は、ぜんぶ目視か実測で出た。書式の点検は
# 1件も拾えていない。**同じものを次に機械が拾えるか**を、ここで確かめる。
# 通る例だけのテストは、点検が壊れていても気づけない。


def _script(body: str):
    from src.script_model import parse_script

    return parse_script(body)


def test_字幕に確度バッジが混ざっていたら弾く(tmp_path):
    from src.review import _caption_badges

    srt = tmp_path / "subtitles.srt"
    srt.write_text(
        "1\n00:00:01,000 --> 00:00:04,000\nキャスター: [報道] 登録を確定させました。\n\n",
        encoding="utf-8",
    )
    assert not _caption_badges(srt).ok


def test_字幕1枚が長すぎたら弾く(tmp_path):
    from src.review import _caption_load

    srt = tmp_path / "subtitles.srt"
    srt.write_text(
        "1\n00:00:01,000 --> 00:00:06,000\n" + "あ" * 60 + "\n\n", encoding="utf-8"
    )
    assert not _caption_load(srt).ok


def test_止まりすぎる画面を弾く(tmp_path):
    import json

    from src.review import _still_length

    path = tmp_path / "script.json"
    path.write_text(json.dumps({"scenes": [{"lines": [
        {"duration": 15.7, "text": "まとめます。"},
        {"duration": 4.0, "text": "次の焦点です。"},
    ]}]}), encoding="utf-8")
    assert not _still_length(path).ok


def test_写真のクレジットが足りなければ弾く(tmp_path):
    from src.review import _photo_credits

    (tmp_path / "description.txt").write_text("本文だけ", encoding="utf-8")
    script = _script("## S\nキャスター: 遠藤選手です。\n  image: assets/images/endo/03.jpg\n")
    assert not _photo_credits(script, tmp_path).ok

    (tmp_path / "description.txt").write_text(
        "本文\n画像: File:Wataru endo.jpg / Jeollo / CC BY 3.0", encoding="utf-8"
    )
    assert _photo_credits(script, tmp_path).ok


def test_句読点の二重を弾く():
    from src.review import _double_marks

    assert not _double_marks(_script("## S\nキャスター: 外れたのか。。25人枠の話です。\n")).ok
    assert _double_marks(_script("## S\nキャスター: 外れたのか。25人枠の話です。\n")).ok


def test_見た目が変わらない場面を弾く(tmp_path):
    """1枚あたりが短くても、カードもテロップも同じなら画面は止まって見える。"""
    import json

    from src.review import _screen_change

    path = tmp_path / "script.json"
    same = [{"duration": 6.0, "telop": "同じ見出し", "card": "why", "image": None}] * 5
    path.write_text(json.dumps({"scenes": [{"lines": same}]}), encoding="utf-8")
    assert not _screen_change(path).ok

    varied = [
        {"duration": 6.0, "telop": f"見出し{i}", "card": "why", "image": None}
        for i in range(5)
    ]
    path.write_text(json.dumps({"scenes": [{"lines": varied}]}), encoding="utf-8")
    assert _screen_change(path).ok
