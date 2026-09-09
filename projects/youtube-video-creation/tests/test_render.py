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
    config.video.channel_name = ""   # 冒頭の登録カードは1行目だけ変える。ここでは見ない
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
    config.video.channel_name = ""   # 冒頭の登録カードは1行目だけ変える。ここでは見ない
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
    config.video.channel_name = ""   # 冒頭の登録カードは1行目だけ変える。ここでは見ない
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


# 漢字の分断だけ見ていたので、かなの語が割れるのを止められなかった。
# 実測（2026-09-04 の動画を目視）で「なぜ12月ま／で戻らない」と
# 「動くかど／うかです」の2箇所が割れていた。どちらも前後がひらがなで、
# 熟語の判定には引っかからない。


def _splits_run(lines, lo, hi):
    return any(
        lo <= a[-1] <= hi and lo <= b[0] <= hi
        for a, b in zip(lines, lines[1:]) if a and b
    )


def test_かなの語の途中で改行しない():
    assert not _splits_run(
        _balanced("遠藤航がCL登録外 なぜ12月まで戻らない選手が選ばれたのか", width=1100, size=72),
        "ぁ", "ん",
    )
    assert not _splits_run(
        _balanced("次の焦点: 冬の移籍市場で遠藤選手が動くかどうかです", width=1100),
        "ぁ", "ん",
    )


def test_かなの分断より熟語の分断を重く見る():
    from src.render import _break_score

    # 助詞の切れ目（「が／外れた」）まで避けると、かえって収まりが悪くなる。
    # ひらがなを漢字と同点にしないのは、そのため。
    kana = ["遠藤選手が動くかど", "うかです"]
    kanji = ["遠藤選手が動く移", "籍市場です"]
    assert _break_score(kana) > _break_score(kanji)


def test_カタカナの語の途中で改行しない():
    assert not _splits_run(
        _balanced("チャンピオンズリーグの登録メンバーが確定しました", width=900),
        "ァ", "ヴ",
    )


def test_送り仮名を置き去りにしない():
    """「戻／らない」のように、動詞の送り仮名だけ次の行に残さない。"""
    from src.render import _break_score

    assert _break_score(["12月まで", "戻らない選手"]) > _break_score(["12月まで戻", "らない選手"])


def test_助詞は行頭に来てよい():
    """「選手／が外れた」は読める。漢字＋ひらがなを一律に減点しない。"""
    from src.render import _break_score

    assert _break_score(["遠藤選手", "が外れた"]) == 0


def test_良い切れ目の幅を飛ばさない():
    """幅の刻みが粗いと、良い切れ目そのものが候補に入らない。

    実測（2026-09-04）で、上限1250のとき「12月まで／戻らない」で切れる幅は
    約0.88倍。5段階（0.62/0.7/0.78/0.86/0.94）では、その間を飛ばしていた。
    """
    lines = _balanced("遠藤航がCL登録外 なぜ12月まで戻らない選手が選ばれたのか", width=1250, size=72)
    assert len(lines) == 2
    assert lines[0].endswith("まで")


def test_動きクリップの名前は元画像の中身で変わる(tmp_path):
    """背景を描き直したのに動画が前のままだった（2026-09-05 実測）。

    クリップの名前が元画像の**中身**に依存していなかったため、キャッシュが
    そのまま使われていた。名前を手で版上げして逃げるのではなく、指紋で決める。
    """
    import hashlib

    a = (tmp_path / "bg.png")
    a.write_bytes(b"first")
    first = hashlib.sha1(a.read_bytes()).hexdigest()[:8]
    a.write_bytes(b"second")
    second = hashlib.sha1(a.read_bytes()).hexdigest()[:8]

    assert first != second


def test_1枚の絵を見せ続ける上限():
    """絵が変わらない時間が長いと間が持たない（2026-09-05 に 12秒→7秒）。"""
    from src.render import Renderer

    assert Renderer.MAX_STILL_SECONDS <= 8.0

# ショートの質（2026-09-07）。公開済みの維持率は
# 「視聴を継続 9.4% / スワイプして消去 90.7%」だった。

def test_縦型では写真を大きく出す():
    """**縦1920では高さ側が先に頭打ちになり、幅を使い切っていなかった。**

    実測で写真の幅が画面の3割。縦画面は顔が主役で、
    「サムネに顔を必ず入れる」方針とも揃う。**横型の値は変えない。**
    """
    from src.render import Layout

    tall = Layout(width=1080, height=1920)
    wide = Layout(width=1920, height=1080)
    assert tall.is_portrait
    assert not wide.is_portrait


def test_縦型では制作側のラベルを出さない():
    """「オープニング」「まとめ」は章の目印で、視聴者には意味が無い。

    一等地の左上を、本編の作業用ラベルで埋めない。
    **中身のある節名は残す。**
    """
    from src.render import INTERNAL_LABELS

    assert "オープニング" in INTERNAL_LABELS
    assert "まとめ" in INTERNAL_LABELS
    # 中身のある節名は隠さない
    for keep in ("監督は何と言ったか", "試合はどう動いたか", "何が起きたか"):
        assert keep not in INTERNAL_LABELS

def test_制作側の節名は画面に出さない():
    """「オープニング」は台本の構造の名前で、視聴者には情報にならない。

    しかも冒頭のいちばん見られる位置に出ていた（2026-09-07 に書き出して確認）。
    本文側の節名（「監督は何と言ったか」など）は残す。
    """
    from src.render import INTERNAL_SCENE_TITLES

    assert "オープニング" in INTERNAL_SCENE_TITLES
    assert "まとめ" in INTERNAL_SCENE_TITLES
    assert "監督は何と言ったか" not in INTERNAL_SCENE_TITLES


# 反応を画面に積む（2026-09-07）。参考チャンネルは白い吹き出しを4〜5件残していて、
# 途中から見た人も文脈を拾える。こちらは1行ずつ消えていた。

def _stack_script():
    from src.script_model import parse_script

    return parse_script("""---
title: T
---

## 何が起きたか

キャスター: 何が起きたかです。
  telop: 何が起きたか

ネット民: 完全に別チームだった。

ネット民: 中盤の圧力がすごい。

ネット民: これは優勝を狙える。
""")


def test_前の反応が画面に残る(tmp_path):
    from PIL import Image

    from src.config import load_config
    from src.render import Renderer

    script = _stack_script()
    renderer = Renderer(load_config(), tmp_path)
    renderer.script_background = script.background
    scene = script.scenes[0]
    plain = renderer.frame(scene.lines[3], scene, mouth_open=False)
    piled = renderer.frame(scene.lines[3], scene, mouth_open=False,
                           stack=("完全に別チームだった。", "中盤の圧力がすごい。"))
    assert plain != piled, "積んでも同じ絵になっている"

    top, box_top = 0, renderer.layout.headline_box[1]
    with Image.open(piled) as image:
        area = image.convert("RGB").crop((0, box_top // 2, image.width, box_top))
        white = sum(1 for r, g, b in area.getdata() if r > 200 and g > 200 and b > 200)
    assert white > 2000, "見出しの上に白い吹き出しが無い"


def test_積むのは匿名の反応だけ(tmp_path):
    """語り（キャスター）が入ったら積み直す。"""
    from src.config import load_config
    from src.render import Renderer

    script = _stack_script()
    renderer = Renderer(load_config(), tmp_path)
    renderer.script_background = script.background
    entries = renderer.frame_entries(script)
    assert entries, "フレームが作られていない"
    # キャスターの行には積まない＝素の絵と同じものが使われる
    scene = script.scenes[0]
    bare = renderer.frame(scene.lines[0], scene, mouth_open=False,
                          panel=("何が起きたか", None, None))
    assert bare in [path for path, _ in entries]


def test_冒頭の1行目にだけ登録カードが乗る(tmp_path):
    """参考チャンネルは冒頭0.5〜2.5秒にチャンネル名と登録ボタンを出す（2026-09-08）。"""
    config = load_config()
    config.motion.enabled = False
    config.video.show_characters = False
    config.video.channel_name = "海外サッカーの理由"
    script = parse_script(
        "## S" + chr(10) + "霊夢: 見出しを出す行。" + chr(10) + "  telop: 大きな見出し"
        + chr(10) + "魔理沙: あいづちの行。" + chr(10)
    )
    for line in script.lines:
        line.duration, line.pause = 2.0, 0.4
    entries = Renderer(config, tmp_path).frame_entries(script)
    # 1行目（カード付き）と2行目（カード無し）で絵が分かれる
    assert len({path for path, _ in entries}) == 2

    config.video.channel_name = ""
    entries = Renderer(config, tmp_path / "plain").frame_entries(script)
    assert len({path for path, _ in entries}) == 1


def test_縦型の冒頭は写真を画面いっぱいに敷く(tmp_path):
    """**ショートの一覧が出しているのは `oar2.jpg`**（2026-09-09 に判明）。

    こちらが設定したサムネイルではなく、YouTube が動画から自動で作る
    縦の1コマ。一覧の img の src を読んで確かめた。つまり
    **冒頭の絵がそのまま一覧の絵になる。**それまで `_photo_stage` は
    `is_portrait` を素通ししていて、冒頭は枠付きの小さな写真カードだった。
    """
    from PIL import Image

    from src.config import load_config
    from src.render import Renderer
    from src.shorts import portrait

    photo = tmp_path / "p.png"
    Image.new("RGB", (900, 1400), (200, 30, 30)).save(photo)

    tall = Renderer(portrait(load_config()), tmp_path)
    stage = tall._photo_stage(str(photo))
    assert stage is not None, "縦型で下地が作られていない"
    assert stage.size == (1080, 1920)
    # 画面の上半分は写真そのもの（ぼかした敷き布ではない）＝彩度が残る
    middle = stage.convert("RGB").getpixel((540, 400))
    assert middle[0] > 120 and middle[1] < 90, f"上半分が写真でない: {middle}"

    wide = Renderer(load_config(), tmp_path)
    wide_stage = wide._photo_stage(str(photo))
    assert wide_stage.width > wide_stage.height, "横型はこれまでどおり横長"
