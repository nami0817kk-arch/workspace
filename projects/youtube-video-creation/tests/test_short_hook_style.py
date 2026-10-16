"""ショート冒頭の3秒の型 X（強い一言）・Y（本人の言葉から）。2026-10-17。"""
from types import SimpleNamespace

import pytest

from src.config import load_config
from src.render import Renderer
from src.research import SHORT_STYLES, _check_short_style, _hook_quote_text
from src.script_model import HOOK_SECONDS, parse_script
from src.shorts import ShortError, trim
from src.subtitles import to_srt

BODY = (
    "---\ntitle: 中村敬斗、ELで2アシスト\n{extra}---\n\n"
    "## オープニング\n\nキャスター: 中村敬斗、ELで2アシスト\n  se: assets/audio/se_pon.wav\n\n"
    "## 何が起きたか\n\nキャスター: 中村が2アシストでした。\n"
    "キャスター: 本人はこう話しました。\n"
    "中村敬斗: 次は自分がゴールを決めたいです。\n"
    "キャスター: 次は22日です。\n"
)


def _short(extra):
    return trim(parse_script(BODY.format(extra=extra)), "何が起きたか", max_seconds=60.0)


def test_型Xは先頭に無音の1拍を置き強い一言と効果音を付ける():
    short = _short("short_style: X\nshort_hook_word: 2アシスト！\n")
    beat, title = short.scenes[0].lines[:2]
    assert beat.hook_word == "2アシスト！"
    assert beat.text == "" and beat.no_telop
    assert beat.se == "assets/audio/se_pon.wav"
    assert title.text == "中村敬斗、ELで2アシスト"      # そのあとは通常どおり題を読む
    assert title.se is None                              # 効果音を続けて2度鳴らさない
    assert HOOK_SECONDS <= 1.2


def test_型の指定が無いショートは今までと同じ():
    short = _short("")
    assert not any(l.hook_word for sc in short.scenes for l in sc.lines)
    assert short.scenes[0].lines[0].text == "中村敬斗、ELで2アシスト"


def test_型Xで一言が無い_長いと止まる():
    with pytest.raises(ShortError):
        _short("short_style: X\n")
    with pytest.raises(ShortError):
        _short("short_style: X\nshort_hook_word: " + "あ" * 11 + "\n")


def test_型Yは本人の発言を1行目に置き本文から外す():
    short = _short("short_style: Y\nshort_hook_quote: 次は自分がゴールを決めたい\n")
    first = short.scenes[0].lines[0]
    assert first.speaker == "中村敬斗"
    assert first.text == "次は自分がゴールを決めたいです。"     # 原文のまま
    assert short.scenes[0].lines[1].text == "中村敬斗、ELで2アシスト"   # そのあとに題
    body = [l.text for l in short.scenes[1].lines]
    assert "次は自分がゴールを決めたいです。" not in body        # 二度出さない
    assert "本人はこう話しました。" not in body               # 宙に浮く振りも外す


def test_型Yで発言が見つからない_語りを指すと止まる():
    with pytest.raises(ShortError):
        _short("short_style: Y\nshort_hook_quote: 存在しない\n")
    with pytest.raises(ShortError):
        _short("short_style: Y\nshort_hook_quote: 2アシストでした\n")      # 語りの行


def test_冒頭の一言の行は字幕に出ない():
    short = _short("short_style: X\nshort_hook_word: 2アシスト！\n")
    for n, l in enumerate(short.lines):
        l.start, l.duration = n * 2.0, 2.0
    assert "2アシスト！" not in to_srt(short)


def test_型Xの一言を描くと黄の太字が画面いっぱいに出る(tmp_path):
    from PIL import Image
    from src.shorts import portrait
    config = portrait(load_config())
    config.motion.enabled = False
    renderer = Renderer(config, tmp_path)
    canvas = Image.new("RGBA", (config.video.width, config.video.height), (20, 30, 40, 255))
    renderer._draw_hookword(canvas, "2アシスト！")
    px = canvas.convert("RGB")
    w, h = px.size
    yellow = [(x, y) for x in range(0, w, 4) for y in range(0, h, 4)
              if px.getpixel((x, y))[0] > 230 and px.getpixel((x, y))[1] > 180 and px.getpixel((x, y))[2] < 120]
    assert len(yellow) > 1500
    xs = [x for x, _ in yellow]
    assert max(xs) - min(xs) > w * 0.55, "画面の幅いっぱいに出ていない"


def _notes(**kw):
    base = dict(short_style="", short_hook_word="", short_hook_quote="", short_title="", sections=[],
                video_title="題")
    base.update(kw)
    return SimpleNamespace(**base)


def _sec(*pairs):
    return SimpleNamespace(id="s", say=[t for _v, t in pairs], voices=[v for v, _t in pairs])


def test_検証_知らない値_指定漏れ_長さ超過を止める():
    assert _check_short_style(_notes()) == []
    assert any("知らない値" in p for p in _check_short_style(_notes(short_style="Q")))
    assert set(SHORT_STYLES) == {"B", "G", "X", "Y"}
    assert any("short_hook_word" in p for p in _check_short_style(_notes(short_style="X")))
    assert any("10字まで" in p for p in _check_short_style(_notes(short_style="X", short_hook_word="あ" * 11)))
    assert _check_short_style(_notes(short_style="X", short_hook_word="2アシスト！")) == []
    assert any("X のときだけ" in p for p in _check_short_style(_notes(short_hook_word="強い")))


def test_検証_Yは本人の発言の行だけを指せる():
    sec = _sec(("", "語りの行です。"), ("中村敬斗", "次はゴールを決めたいです。"))
    ok = _notes(short_style="Y", short_hook_quote="ゴールを決めたい", sections=[sec])
    assert _check_short_style(ok) == []
    narr = _notes(short_style="Y", short_hook_quote="語りの行", sections=[sec])
    assert any("本人の発言" in p for p in _check_short_style(narr))
    none = _notes(short_style="Y", short_hook_quote="無い", sections=[sec])
    assert any("当たる say の行がありません" in p for p in _check_short_style(none))
    assert any("short_hook_quote" in p for p in _check_short_style(_notes(short_style="Y")))


def test_検証_Yの番号指定は台本の文に直る():
    sec = _sec(("", "語りの行です。"), ("中村敬斗", "次はゴールを決めたいです。"))
    notes = _notes(short_style="Y", short_hook_quote="2", sections=[sec])
    assert _check_short_style(notes) == []
    assert _hook_quote_text(notes) == "次はゴールを決めたいです。"
