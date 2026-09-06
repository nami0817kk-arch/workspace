from src.script_model import parse_script
from src.subtitles import _clock, _timestamp, chapters, description, to_srt


def _timed_script():
    script = parse_script(
        "---\ntitle: T\ntags: [a]\ndescription: 説明文\n---\n\n"
        "## 章1\n霊夢: あいうえお。\n\n## 章2\n魔理沙: かきくけこ。\n"
    )
    start = 0.0
    for line in script.lines:
        line.duration = 3.0
        line.pause = 0.5
        line.start = start
        start += line.duration
    return script


def test_timestamp_format():
    assert _timestamp(0) == "00:00:00,000"
    assert _timestamp(3661.5) == "01:01:01,500"


def test_clock_format():
    assert _clock(9) == "0:09"
    assert _clock(75) == "1:15"
    assert _clock(3725) == "1:02:05"


def test_srt_excludes_trailing_pause():
    srt = to_srt(_timed_script())
    # 3.0秒 - 0.5秒の無音 = 2.5秒で字幕を消す
    assert "00:00:00,000 --> 00:00:02,500" in srt
    assert srt.count("-->") == 2


def test_chapters_start_at_zero():
    marks = chapters(_timed_script())
    assert marks[0] == (0.0, "章1")
    assert marks[1][0] == 3.0


def test_chapters_follow_actual_line_starts():
    """タイトルカードで時刻がずれても、チャプターは実際の開始時刻に追従する。"""
    script = _timed_script()
    # 冒頭に2.6秒、2章の前に1.4秒のタイトルカードが入った状態
    script.scenes[0].lines[0].start = 2.6
    script.scenes[1].lines[0].start = 7.0

    marks = chapters(script)
    assert marks[0] == (0.0, "章1")   # 先頭は必ず 0:00
    assert marks[1] == (7.0, "章2")


def test_description_contains_toc_and_tags():
    text = description(_timed_script())
    assert "説明文" in text
    assert "0:00 章1" in text
    assert "#a" in text


def test_subtitles_carry_the_spoken_line_not_the_shortened_telop():
    from src.script_model import parse_script
    from src.subtitles import to_srt

    script = parse_script(
        "---\ntitle: T\n---\n\n## S\n\n"
        "キャスター: 移籍期限まであと2日。ヨーロッパで最大の焦点になっています。\n"
        "  telop: 今回の問い: 金額で折り合えるのに、なぜアトレティコ…\n"
    )
    srt = to_srt(script)
    assert "ヨーロッパで最大の焦点になっています。" in srt
    assert "…" not in srt          # 画面用に切った文字列は字幕に出さない


# 字幕に画面用の確度バッジが入り、1枚45文字・10文字/秒になっていた
# （2026-09-04 実測）。読み上げていない文字が字幕に出ると音と食い違うし、
# 日本語の字幕は1秒に4文字前後でないと読み切れない。


def test_字幕に確度バッジを入れない():
    from src.script_model import parse_script
    from src.subtitles import to_srt

    srt = to_srt(parse_script(
        "## S\nキャスター: リバプールが登録を確定させました。\n  source: 報道\n"
    ))
    assert "[報道]" not in srt
    assert "リバプールが登録を確定させました。" in srt


def test_長い字幕は意味の切れ目で分ける():
    from src.subtitles import CAPTION_LIMIT, split_caption

    text = "リバプールが、チャンピオンズリーグの登録メンバーを確定させました。この中に遠藤航選手の名前はありません。"
    chunks = split_caption(text)

    assert len(chunks) >= 2
    assert all(len(c) <= CAPTION_LIMIT for c in chunks)
    assert "".join(chunks) == text          # 文字は落とさない
    assert all(len(c) >= 10 for c in chunks)  # 「リバプールが、」のような断片を作らない


def test_短い字幕はそのまま():
    from src.subtitles import split_caption

    assert split_caption("遠藤航選手が外れました。") == ["遠藤航選手が外れました。"]


def test_話者は1枚目にだけ付ける():
    from src.script_model import parse_script
    from src.subtitles import to_srt

    srt = to_srt(parse_script(
        "## S\nキャスター: " + "あいうえお、" * 8 + "。\n"
    ))
    assert srt.count("キャスター: ") == 1


def test_語の途中で字幕を割らない():
    """読点が無い長文でも、カタカナ語や熟語の途中では割らない。"""
    from src.subtitles import split_caption

    chunks = split_caption("チャンピオンズリーグの登録メンバーが確定してリバプールの構成が固まりました")

    def kana(c):
        return "ァ" <= c <= "ヴ"

    def kanji(c):
        return "一" <= c <= "鿿"

    for a, b in zip(chunks, chunks[1:]):
        assert not (kana(a[-1]) and kana(b[0]))
        assert not (kanji(a[-1]) and kanji(b[0]))

def test_写真の詳細はハッシュタグより下に置く():
    """**上は1行、義務は末尾**（2026-09-06 ユーザーの判断）。

    CC BY は表示が条件なので消せないが、概要欄の頭に長い行が並ぶと
    読むところが埋まる。YouTube は最初の3行しか初期表示しない。
    """
    from src.script_model import parse_script
    from src.subtitles import description

    nl = chr(10)
    script = parse_script(nl.join(
        ["---", "title: T", "tags: [サッカー]", "---", "", "## 章", "",
         "キャスター: あ。"]))
    body = description(script, ["画像: Wikimedia Commons"],
                       ["※ 画像: File:X / 撮影者 / CC BY 3.0 / https://example.org"])
    上 = body.index("画像: Wikimedia Commons")
    タグ = body.index("#サッカー")
    詳細 = body.index("※ 画像: File:X")
    assert 上 < タグ < 詳細, "詳細がハッシュタグより上に出ている"


def test_詳細が無ければ区切り線も出さない():
    from src.script_model import parse_script
    from src.subtitles import description

    nl = chr(10)
    script = parse_script(nl.join(["---", "title: T", "---", "", "## 章", "", "キャスター: あ。"]))
    assert "─" not in description(script, ["音声: VOICEVOX"], [])
