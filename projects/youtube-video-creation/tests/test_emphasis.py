"""テロップの強調（2026-09-15）。"""


def test_強調の囲みを外して範囲を返す():
    from src import emphasis
    assert emphasis.split("未勝利が**4試合**になりました") == ("未勝利が4試合になりました", [(4, 7)])
    assert emphasis.split("ふつう") == ("ふつう", [])
    assert emphasis.strip("**7点**と**6点**") == "7点と6点"


def test_折り返した行ごとに範囲を切り直す():
    from src import emphasis
    # 「4試合」が行をまたいだとき、両方の行に下線が引ける
    assert emphasis.spans_in("未勝利が4", 0, [(4, 7)]) == [(4, 5)]
    assert emphasis.spans_in("試合です", 5, [(4, 7)]) == [(0, 2)]


def test_セリフの囲みは読み上げに渡らない():
    """VOICEVOX が「アスタリスク」と読むのを防ぐ。囲みはテロップへ移す。"""
    from src.script_model import Line
    line = Line(speaker="キャスター", text="未勝利が**4試合**になりました")
    assert line.text == "未勝利が4試合になりました"
    assert line.telop_text() == "未勝利が**4試合**になりました"


def test_字幕に囲みを出さない():
    from src.script_model import Line, Scene, Script
    from src.subtitles import to_srt
    line = Line(speaker="キャスター", text="未勝利が**4試合**になりました")
    line.duration = 3.0
    srt = to_srt(Script(title="t", scenes=[Scene(title="章", lines=[line])]))
    assert "**" not in srt and "4試合" in srt


def test_強調しても折り返しは変わらない(tmp_path):
    """囲みで行の割れ方が変わると、同じ字数でも枠の高さがずれる。"""
    from PIL import Image, ImageDraw
    from src.config import load_config
    from src.render import Renderer, balanced_wrap
    r = Renderer(load_config(), tmp_path)
    draw = ImageDraw.Draw(Image.new("RGBA", (1920, 1080)))
    plain = "1対2で負けて、開幕からの未勝利が4試合になりました。"
    from src import emphasis
    marked = "1対2で負けて、開幕からの未勝利が**4試合**になりました。"
    assert balanced_wrap(draw, emphasis.strip(marked), r.font_headline, 1500) ==         balanced_wrap(draw, plain, r.font_headline, 1500)
    # 描いても落ちない
    r._draw_headline(Image.new("RGBA", (1920, 1080)), marked)
