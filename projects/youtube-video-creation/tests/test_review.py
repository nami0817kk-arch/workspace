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


# 2026-09-07 に構成の点検を足したので、「全部 ✓ になる見本」も新しい型に直した。
#   1行目がタイトル / 他人の声が4割以上 / 1件30字以内 / 最後の節は1割まで
# 伸びている3チャンネルの実測（他人の声58%・19件・1件3.1秒）に寄せた形
GOOD_BODY = """---
title: アーセナルが勝った理由
sources: [https://example.com/a]
tags: [サッカー, 海外サッカー]
---

## 何が起きたか

キャスター: アーセナルが勝った理由。
  source: 確定

キャスター: 前半に2点が入りました。
  source: 報道

ネット民: 完全に別チームだった。
  source: 未確認

ネット民: 中盤の圧力がすごい。
  source: 未確認

ネット民: これは優勝を狙える。
  source: 未確認

ネット民: 見ていて楽しい。
  source: 未確認

ネット民: この調子で頼む。
  source: 未確認

ネット民: 来週も楽しみだ。
  source: 未確認

ネット民: 守備も良かった。
  source: 未確認

## まとめ

解説: 中盤の改善が答えです。
  source: 背景
"""


def _built(tmp_path, seconds=150.0):
    for name in ("video.mp4", "thumbnail.png"):
        (tmp_path / name).write_bytes(b"x")
    (tmp_path / "subtitles.srt").write_text(
        "1\n00:00:01,000 --> 00:00:03,000\n字幕\n", encoding="utf-8"
    )
    # サムネの写真もクレジットが要る（2026-09-06）。見本にも1行入れておく
    (tmp_path / "description.txt").write_text(
        "概要" + chr(10) + "画像: File:x / 撮影者 / CC BY 3.0 / https://example.org",
        encoding="utf-8")
    (tmp_path / "script.json").write_text(
        json.dumps({"scenes": [{"lines": [{"start": seconds - 10, "duration": 10}]}]}),
        encoding="utf-8",
    )
    return tmp_path


def _by_label(findings):
    return {f.label: f for f in findings}


def test_a_finished_build_passes_everything(tmp_path, monkeypatch):
    # サムネの顔は必須になった（2026-09-05）。見本にも写真を持たせる
    from src import review as review_mod

    face = tmp_path / "face.jpg"
    face.write_bytes(b"x")
    monkeypatch.setattr(review_mod, "_resolve", lambda value: face)
    body = GOOD_BODY.replace(
        "title: アーセナルが勝った理由\n",
        "title: アーセナルが勝った理由\nthumbnail_photo: assets/images/x/face.jpg\n")
    findings = inspect(parse_script(body), _built(tmp_path), 100.0)
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
    # 下限60秒・上限210秒。**上限は 2026-09-07 に 130秒 から緩めた**
    # （ユーザー「長くても良い」）。1〜2分は参考チャンネルの実測から決めた
    # 目安であって上限ではなかった。引用が主役の回は3分でも成立する。
    # 短くするために発言を削るのは本末転倒
    [(50.0, False), (60.0, True), (95.0, True), (130.0, True),
     (150.0, True), (171.0, True), (211.0, False), (300.0, False)],
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


# サムネイルには顔を必ず入れる（2026-09-05 ユーザーの指示）。
# **人の注意に頼ると忘れる。**実際、3本目で忘れた。仕組みのほうで止める。


def test_サムネに写真が無ければ弾く():
    from src.review import _thumbnail_face

    script = _script("## S\nキャスター: 見出しです。\n")
    assert not _thumbnail_face(script).ok


def test_サムネの写真が実在しなければ弾く():
    from src.script_model import parse_script
    from src.review import _thumbnail_face

    body = "---\ntitle: 見出し\nthumbnail_photo: assets/images/ない/ない.jpg\n---\n\n## S\nキャスター: あ。\n"
    assert not _thumbnail_face(parse_script(body)).ok


def test_サムネに実在する写真があれば通る(tmp_path, monkeypatch):
    from src import review
    from src.script_model import parse_script

    photo = tmp_path / "face.jpg"
    photo.write_bytes(b"x")
    monkeypatch.setattr(review, "_resolve", lambda value: photo)

    body = "---\ntitle: 見出し\nthumbnail_photo: assets/images/x/face.jpg\n---\n\n## S\nキャスター: あ。\n"
    assert review._thumbnail_face(parse_script(body)).ok

def test_サムネの写真もクレジットが要る(tmp_path):
    """**サムネイルも配布物。**動画本体に出ないからと数えていなかった。

    2026-09-06 に、公開済みの5本がクレジット無しで出ていた。
    """
    from src.review import _photo_credits

    nl = chr(10)

    class Line:
        image = None

    class Script:
        lines = [Line()]
        meta = {"thumbnail_photo": "assets/images/arteta/01.jpg"}

    out = tmp_path
    (out / "description.txt").write_text(
        "■ クレジット" + nl + "音声: VOICEVOX" + nl, encoding="utf-8")
    finding = _photo_credits(Script(), out)
    assert not finding.ok, "サムネの写真が数えられていない"

    (out / "description.txt").write_text(
        "■ クレジット" + nl
        + "画像: File:x / 撮影者 / CC BY 3.0 / https://example.org" + nl,
        encoding="utf-8")
    assert _photo_credits(Script(), out).ok


# ショートは冒頭で捨てられる。2026-09-07 の実測で、公開済みショートは
# 「視聴を継続 9.4% / スワイプして消去 90.7%」。先頭フレームを抜くと
# 最初の2.6秒が無音の静止タイトルカードだった。

def test_ショートの冒頭に喋りが無ければ落とす():
    from pathlib import Path

    from src.review import check_short_opening

    finding = check_short_opening(
        Path("video.mp4"), measure=lambda video, seconds: (1080, 1920, -31.5, -18.7)
    )
    assert finding is not None
    assert not finding.ok
    assert "静か" in finding.detail


def test_ショートの冒頭から喋っていれば通す():
    from pathlib import Path

    from src.review import check_short_opening

    finding = check_short_opening(
        Path("video.mp4"), measure=lambda video, seconds: (1080, 1920, -19.0, -18.7)
    )
    assert finding is not None and finding.ok


def test_音量が読めなければ黙る():
    """測れないものを×にはしない。誤検知は点検全体を信用されなくする。"""
    from pathlib import Path

    from src.review import check_short_opening

    finding = check_short_opening(
        Path("video.mp4"), measure=lambda video, seconds: (1080, 1920, None, -18.7)
    )
    assert finding is None


def test_横型は冒頭が無音でも落とさない():
    """本編は冒頭にタイトルカードを置く設計で、そこは無音でよい。"""
    from pathlib import Path

    from src.review import check_short_opening

    assert check_short_opening(
        Path("video.mp4"), measure=lambda video, seconds: (1920, 1080, -31.5, -18.7)
    ) is None


def test_測れなければ黙る():
    from pathlib import Path

    from src.review import check_short_opening

    assert check_short_opening(Path("video.mp4"), measure=lambda video, seconds: None) is None


# 伸びている参考チャンネルはネット民のコメントを常に画面の層として出している。
# こちらは reactions カードの型も数える道具もあるのに、出力8本で1枚も使われて
# いなかった（2026-09-07 実測）。節があるのにカードが無いときだけ言う。

def _script_with(title, card_type=None):
    from src.script_model import Line, Scene, Script

    line = Line(speaker="キャスター", text="本文", card="c1" if card_type else None)
    return Script(
        title="見出し",
        scenes=[Scene(title=title, lines=[line])],
        cards={"c1": {"type": card_type}} if card_type else {},
    )


def test_反応の節にカードが無ければ落とす():
    from src.review import check_reaction_layer

    finding = check_reaction_layer(_script_with("どう受け止められたか"))
    assert finding is not None and not finding.ok
    assert "reactions" in finding.detail


def test_反応カードがあれば通す():
    from src.review import check_reaction_layer

    finding = check_reaction_layer(_script_with("どう受け止められたか", "reactions"))
    assert finding is not None and finding.ok


def test_反応の節が無い回では黙る():
    """毎回うるさく言わない。移籍の回に反応を強要しない。"""
    from src.review import check_reaction_layer

    assert check_reaction_layer(_script_with("何が起きたか")) is None


def test_ショートは同じ絵の上限が短い():
    """31秒の動画で12秒動かないと尺の4割が同じ絵になる（2026-09-07 に確認）。"""
    from src.review import CARD_HOLD_MAX, SHORT_CARD_HOLD_MAX, hold_limit

    assert hold_limit(portrait=True) == SHORT_CARD_HOLD_MAX
    assert hold_limit(portrait=False) == CARD_HOLD_MAX
    assert SHORT_CARD_HOLD_MAX < CARD_HOLD_MAX


# 構成の点検（2026-09-07）。伸びている3チャンネルの直近4本を文字起こしで測ったら、
# 他人の声が尺の58%・19.2件・1件3.1秒で、こちらは14%・2.2件・1件39字だった。
# **✓ しか出ない点検は、壊れていても気づけない**ので、壊れた例を1つずつ食わせる。

def test_語りだけの台本は他人の声で止まる(tmp_path):
    body = GOOD_BODY.replace("ネット民:", "解説:")
    result = _by_label(inspect(parse_script(body), _built(tmp_path)))
    assert result["他人の声の量"].ok is False
    assert "0%" in result["他人の声の量"].detail


def test_長い引用は刻みで止まる(tmp_path):
    body = GOOD_BODY.replace(
        "ネット民: 完全に別チームだった。",
        "ネット民: 完全に別のチームになっていて見ていて本当に気持ちがよかった一戦だった。")
    result = _by_label(inspect(parse_script(body), _built(tmp_path)))
    assert result["反応の刻み"].ok is False


def test_1行目がタイトルと違うと止まる(tmp_path):
    body = GOOD_BODY.replace(
        "キャスター: アーセナルが勝った理由。", "キャスター: さて、今日の話題です。")
    result = _by_label(inspect(parse_script(body), _built(tmp_path)))
    assert result["1行目"].ok is False


def test_タイトルの一部だけ読んでも通らない(tmp_path):
    """「アーセナル」とだけ読んで本題に入らない形は通さない。"""
    body = GOOD_BODY.replace(
        "キャスター: アーセナルが勝った理由。", "キャスター: アーセナル。")
    result = _by_label(inspect(parse_script(body), _built(tmp_path)))
    assert result["1行目"].ok is False


def test_長いまとめは止まる(tmp_path):
    body = GOOD_BODY.replace(
        "解説: 中盤の改善が答えです。",
        """解説: 中盤の改善が答えです。

解説: つまり今日の試合は中盤の入れ替えで決まったということになります。

解説: 次の焦点は来週の一戦です。動きがあり次第またお伝えします。""")
    result = _by_label(inspect(parse_script(body), _built(tmp_path)))
    assert result["まとめの長さ"].ok is False


def test_縦型には構成の点検を当てない(tmp_path, monkeypatch):
    """ショートは本編から1節を切り出したもの。割合を測っても元の話にならない。"""
    from src import review as review_mod

    monkeypatch.setattr(review_mod, "_dimensions", lambda path: (1080, 1920))
    body = GOOD_BODY.replace("ネット民:", "解説:")      # 他人の声をゼロにしても
    labels = {f.label for f in inspect(parse_script(body), _built(tmp_path))}
    assert "他人の声の量" not in labels
    assert "1行目" not in labels
