import pytest
from PIL import Image, ImageDraw, ImageFont

from src.config import load_config
from src.render import Renderer, wrap_text
from src.script_model import parse_script

SCRIPT = "## 章1\n霊夢: あいうえお。\n  telop: テロップ\n魔理沙: かきくけこ。\n"


def _script_with_timing():
    script = parse_script(SCRIPT)
    for line in script.lines:
        line.duration = 2.0
        line.pause = 0.4
    return script


def test_wrap_text_respects_width():
    image = Image.new("RGB", (10, 10))
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(load_config().video.font_path()), 40)
    lines = wrap_text(draw, "あ" * 20, font, 200)
    assert len(lines) > 1
    assert "".join(lines) == "あ" * 20


def test_wrap_text_keeps_punctuation_off_line_head():
    image = Image.new("RGB", (10, 10))
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(load_config().video.font_path()), 40)
    lines = wrap_text(draw, "ああああ、いいいい。", font, 165)
    assert not any(line.startswith(("、", "。")) for line in lines)


@pytest.mark.parametrize("motion", [True, False])
def test_frame_entries_match_audio_duration(tmp_path, motion):
    """演出を入れても映像の尺は音声とずれない（演出は発話時間の内側で行う）。"""
    config = load_config()
    config.motion.enabled = motion
    script = _script_with_timing()
    renderer = Renderer(config, tmp_path)
    entries = renderer.frame_entries(script)
    total = sum(duration for _, duration in entries)
    assert total == pytest.approx(script.duration, abs=1e-6)


def test_frames_are_cached_by_content(tmp_path):
    config = load_config()
    config.motion.enabled = False
    config.video.show_characters = True
    script = _script_with_timing()
    renderer = Renderer(config, tmp_path)
    renderer.frame_entries(script)
    # 2行 x (口を閉じた絵 + 開けた絵) = 4枚だけ
    assert len(list((tmp_path / "frames").glob("*.png"))) == 4


def test_news_layout_skips_mouth_frames(tmp_path):
    """立ち絵を出さないなら口パクは絵に影響しないので、フレームは倍にならない。"""
    config = load_config()
    config.motion.enabled = False
    config.video.show_characters = False
    script = parse_script(
        "## S\n霊夢: 一つめ。\n  telop: 見出しA\n魔理沙: 二つめ。\n  telop: 見出しB\n"
    )
    for line in script.lines:
        line.duration, line.pause = 2.0, 0.4

    renderer = Renderer(config, tmp_path)
    renderer.frame_entries(script)
    # 見出し2種類ぶんだけ。口の開閉では増えない
    assert len(list((tmp_path / "frames").glob("*.png"))) == 2


def test_news_layout_keeps_previous_headline(tmp_path):
    """telop を書いていない行では、直前の見出しを出したままにする。"""
    config = load_config()
    config.motion.enabled = False
    config.video.show_characters = False
    script = parse_script(
        "## S\n霊夢: 見出しを出す行。\n  telop: 大きな見出し\n魔理沙: あいづちの行。\n"
    )
    for line in script.lines:
        line.duration, line.pause = 2.0, 0.4

    renderer = Renderer(config, tmp_path)
    entries = renderer.frame_entries(script)
    # 見出しが変わらないので、2行とも同じ絵を使い回す
    assert len({path for path, _ in entries}) == 1


def test_news_layout_clears_headline_on_no_telop(tmp_path):
    config = load_config()
    config.motion.enabled = False
    config.video.show_characters = False
    script = parse_script(
        "## S\n霊夢: 見出し。\n  telop: 見出し\n魔理沙: 消す。\n  no_telop: true\n"
    )
    for line in script.lines:
        line.duration, line.pause = 2.0, 0.4

    renderer = Renderer(config, tmp_path)
    entries = renderer.frame_entries(script)
    assert len({path for path, _ in entries}) == 2


def test_motion_adds_intro_frames(tmp_path):
    config = load_config()
    script = _script_with_timing()

    config.motion.enabled = False
    without = len(Renderer(config, tmp_path / "off").frame_entries(script))
    config.motion.enabled = True
    with_motion = len(Renderer(config, tmp_path / "on").frame_entries(script))
    assert with_motion > without


def test_scene_change_uses_crossfade(tmp_path):
    """2つ目のシーンの頭には、前の画面と混ざった中間フレームが入る。"""
    config = load_config()
    script = parse_script("## 章1\n霊夢: あいうえお。\n\n## 章2\n魔理沙: かきくけこ。\n")
    for line in script.lines:
        line.duration, line.pause = 2.0, 0.4
    renderer = Renderer(config, tmp_path)
    renderer.frame_entries(script)
    # blend() が作る中間フレームは x で始まる名前にしている
    assert list((tmp_path / "frames").glob("x*.png"))


def test_intro_is_capped_by_speaking_time(tmp_path):
    """発話が極端に短くても、演出が音声をはみ出さない。"""
    config = load_config()
    script = parse_script("## S\n霊夢: あ。\n")
    script.lines[0].duration, script.lines[0].pause = 0.2, 0.0
    renderer = Renderer(config, tmp_path)
    entries = renderer.frame_entries(script)
    assert sum(d for _, d in entries) == pytest.approx(0.2, abs=1e-6)


def test_is_video_detects_clip_extensions():
    from src.render import is_video

    assert is_video("assets/backgrounds/clip.mp4")
    assert is_video("CLIP.MOV")
    assert not is_video("assets/backgrounds/stadium.png")
    assert not is_video(None)


def test_video_background_frames_keep_alpha(tmp_path):
    """動画背景に重ねるフレームは、透過を残して書き出す。"""
    from PIL import Image

    config = load_config()
    script = parse_script("## S\n霊夢: あ。\n")
    script.background = "clip.mp4"
    script.lines[0].duration, script.lines[0].pause = 1.0, 0.0

    renderer = Renderer(config, tmp_path)
    renderer.frame_entries(script)
    frames = list((tmp_path / "frames").glob("*.png"))
    assert frames
    with Image.open(frames[0]) as image:
        assert image.mode == "RGBA"
        # 上端は完全に透過していて、下端は幕がかかっている
        assert image.getpixel((10, 10))[3] == 0
        assert image.getpixel((10, config.video.height - 10))[3] > 0


def test_news_headline_keeps_its_source_badge(tmp_path):
    """見出しを引き継いだ行では、確度バッジも一緒に残る。"""
    config = load_config()
    config.motion.enabled = False
    config.video.show_characters = False
    script = parse_script(
        "## S\n霊夢: 報道の話。\n  telop: 見出し\n  source: 報道\n魔理沙: あいづち。\n"
    )
    for line in script.lines:
        line.duration, line.pause = 2.0, 0.4

    renderer = Renderer(config, tmp_path)
    entries = renderer.frame_entries(script)
    # 見出しも確度も変わらないので、2行とも同じ絵になる
    assert len({path for path, _ in entries}) == 1


def _card_script():
    script = parse_script(
        "---\ncards:\n  c1: {type: quote, source: ESPN, text: hello}\n---\n\n"
        "## S\n霊夢: 見出し。\n  telop: 見出し\n  card: c1\n魔理沙: 続き。\n"
    )
    for line in script.lines:
        line.duration, line.pause = 2.0, 0.4
    return script


def test_card_persists_to_following_lines(tmp_path):
    """カードも見出しと同じく、指定した行以降そのまま出したままになる。"""
    config = load_config()
    config.motion.enabled = False
    config.video.show_characters = False
    renderer = Renderer(config, tmp_path)
    entries = renderer.frame_entries(_card_script())
    assert len({path for path, _ in entries}) == 1
    assert list((tmp_path / "cards").glob("*.png"))


def test_card_none_clears_it(tmp_path):
    config = load_config()
    config.motion.enabled = False
    config.video.show_characters = False
    script = parse_script(
        "---\ncards:\n  c1: {type: quote, source: ESPN, text: hello}\n---\n\n"
        "## S\n霊夢: 出す。\n  telop: 見出し\n  card: c1\n魔理沙: 消す。\n  card: none\n"
    )
    for line in script.lines:
        line.duration, line.pause = 2.0, 0.4

    renderer = Renderer(config, tmp_path)
    entries = renderer.frame_entries(script)
    assert len({path for path, _ in entries}) == 2


def test_balanced_wrap_evens_out_line_lengths():
    """折り返しで最後の行だけ極端に短くならない。"""
    from src.render import balanced_wrap, wrap_text

    image = Image.new("RGB", (10, 10))
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(load_config().video.font_path()), 40)
    text = "バルサ拒否／アーセナルか残留／決めるのは本人"

    greedy = wrap_text(draw, text, font, 700)
    balanced = balanced_wrap(draw, text, font, 700)

    assert len(balanced) == len(greedy)          # 行数は変えない
    assert "".join(balanced) == text             # 文字は落とさない
    assert len(balanced[-1]) >= len(greedy[-1])  # 最後の行が短くなっていない


# 幅だけで折り返していたので、単語や拗音の途中で改行されていた。
# 実測（作った動画を目視して発見）で「チェルシー」が「チ／ェルシー」に、
# 「成立」が「成／立」に割れ、行頭が小文字の「ェ」になっていた。


def _wrapped(text, width=900, size=58):
    from PIL import Image, ImageDraw, ImageFont

    from src.config import load_config
    from src.render import wrap_text

    font = ImageFont.truetype(str(load_config().video.font_path()), size)
    draw = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    return wrap_text(draw, text, font, width)


def test_小書き文字を行頭に置かない():
    """「チェルシー」が「チ」＋「ェルシー」に割れていた。"""
    for line in _wrapped("次の焦点: モナコの説明と、チェルシーが今後この件をどう扱うかです。"):
        assert line[0] not in "ぁぃぅぇぉっゃゅょァィゥェォッャュョ", line


def test_長音符を行頭に置かない():
    for line in _wrapped("サンダーランドとクリスタルパレスがフォファナの獲得を争っています。"):
        assert not line.startswith("ー"), line


def test_句読点は前の行にぶら下げる():
    for line in _wrapped("合意していた、はずの移籍が、期限の直前に、消えました。"):
        assert line[0] not in "、。", line


def test_開き括弧を行末に置かない():
    for line in _wrapped("モナコの説明はこうです「別の選手の退団が成立しなかった」ということです。"):
        assert not line.endswith("「"), line


def test_折り返しても文字は落ちない():
    """禁則の処理で1文字も消えたり増えたりしないこと。"""
    text = "チェルシーが激怒した、移籍期限最終日の破談劇「合意の重さ」をめぐる対立。"
    assert "".join(_wrapped(text)) == text


# 見出しの折り返しは行数をそろえることだけを見ていたので、幅が広いと
# 「チェルシーが激怒した、移／籍期限…」と熟語の途中で割れていた。
# 実際に作った動画を目視して見つけた。


def _balanced(text, width=1460, size=74):
    from PIL import Image, ImageDraw, ImageFont

    from src.config import load_config
    from src.render import balanced_wrap

    font = ImageFont.truetype(str(load_config().video.font_path()), size)
    draw = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    return balanced_wrap(draw, text, font, width)


def _splits_kanji(lines):
    def kanji(c):
        return "\u4e00" <= c <= "\u9fff"

    return any(
        kanji(a[-1]) and kanji(b[0])
        for a, b in zip(lines, lines[1:]) if a and b
    )


def test_熟語の途中で改行しない():
    assert not _splits_kanji(_balanced("チェルシーが激怒した、移籍期限最終日の破談劇"))
    assert not _splits_kanji(
        _balanced("今回の問い: なぜ、決まっていたはずの移籍が土壇場でひっくり返ったのか。")
    )


def test_句読点で切れるほうを選ぶ():
    from src.render import _break_score

    good = ["チェルシーが激怒した、", "移籍期限最終日の破談劇"]
    bad = ["チェルシーが激怒した、移", "籍期限最終日の破談劇"]
    assert _break_score(good) > _break_score(bad)


def test_見出しを折り返しても文字は落ちない():
    text = "モナコが、別の選手の退団が成立しなかったために、カマラを手放せなくなったからです。"
    assert "".join(_balanced(text)) == text
