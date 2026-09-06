import pytest

from src.config import load_config
from src.script_model import parse_script
from src.shorts import MAX_SECONDS, SIZE, ShortError, _estimate, portrait, trim

BODY = (
    "---\ntitle: T\n---\n\n"
    "## オープニング\n\nキャスター: つかみです。\n\n"
    "## 何が起きたか\n\nキャスター: いち。\n解説: に。\n解説: さん。\n\n"
    "## 数字で見ると\n\nキャスター: すうじ。\n\n"
    "## まとめ\n\nキャスター: まとめ。\n"
)


def test_portrait_flips_the_frame_and_shrinks_the_text():
    wide = load_config()
    tall = portrait(wide)
    assert (tall.video.width, tall.video.height) == SIZE
    assert tall.video.telop_size < wide.video.telop_size
    assert wide.video.width == 1920      # 元の設定は変えない


def test_the_default_cut_is_the_opening_plus_the_next_section():
    short = trim(parse_script(BODY))
    assert [scene.title for scene in short.scenes] == ["オープニング", "何が起きたか"]


def test_a_named_section_can_be_used_instead():
    short = trim(parse_script(BODY), "数字で見ると")
    assert [scene.title for scene in short.scenes] == ["オープニング", "数字で見ると"]


def test_an_unknown_section_lists_the_choices():
    with pytest.raises(ShortError, match="数字で見ると"):
        trim(parse_script(BODY), "存在しない節")


def test_the_original_script_is_left_alone():
    script = parse_script(BODY)
    trim(script)
    assert len(script.scenes) == 4       # 元の台本は削らない


def test_lines_are_dropped_from_the_back_until_it_fits():
    script = parse_script(BODY)
    short = trim(script, "何が起きたか", max_seconds=1.0)
    # 冒頭は削らず、掘る節から後ろを落とす
    assert len(short.scenes[0].lines) == 1
    assert len(short.scenes[1].lines) == 1
    assert short.scenes[1].lines[0].text == "いち。"


def test_a_one_scene_script_is_refused():
    with pytest.raises(ShortError, match="節が1つ"):
        trim(parse_script("---\ntitle: T\n---\n\n## だけ\n\nキャスター: あ。\n"))


def test_the_estimate_uses_the_pre_build_guess():
    short = trim(parse_script(BODY))
    assert _estimate(short) > 0          # ビルド前でも尺が出る
    assert _estimate(short) < MAX_SECONDS

# **いちばん強い場面を使う**（2026-09-06 ユーザーの指示）。
# 11本を振り返ると、残ったのは全部「誰かの言葉」だった。

def _built(sections):
    """sections は [(見出し, [(話者, カード名)])]。"""
    from src.script_model import parse_script

    nl = chr(10)
    head = ["---", "title: T", "cards:",
            "  q:", "    type: quote", "    source: X", "    text: hello",
            "  n:", "    type: bars", "    title: 数字", "    items: []",
            "---", ""]
    body = ["## オープニング", "", "キャスター: つかみ。", ""]
    for title, lines in sections:
        body += [f"## {title}", ""]
        for who, card in lines:
            body.append(f"{who}: {title}の話。")
            if card:
                body.append(f"  card: {card}")
        body.append("")
    return parse_script(nl.join(head + body))


def test_誰かの言葉がある節を選ぶ():
    """**事実の説明より、本人の口から出た一言が強い。**"""
    from src.shorts import _pick

    script = _built([
        ("何が起きたか", [("キャスター", None), ("キャスター", None)]),
        ("監督は何と言ったか", [("キャスター", None), ("アルテタ", "q")]),
        ("これからどうなる", [("キャスター", None)]),
    ])
    assert _pick(script, "").title == "監督は何と言ったか"


def test_数字のカードは次点で効く():
    from src.shorts import _pick

    script = _built([
        ("何が起きたか", [("キャスター", None)]),
        ("数字で見ると", [("キャスター", "n"), ("キャスター", None)]),
    ])
    assert _pick(script, "").title == "数字で見ると"


def test_まとめは選ばない():
    """**答えを先に言ってしまう。**ショートは本編への入口にする。"""
    from src.shorts import _pick

    script = _built([
        ("何が起きたか", [("キャスター", None)]),
        ("まとめ", [("解説", "q"), ("解説", "q")]),
    ])
    assert _pick(script, "").title == "何が起きたか"


def test_節を名前で指定できる():
    from src.shorts import _pick

    script = _built([
        ("何が起きたか", [("キャスター", None)]),
        ("監督は何と言ったか", [("アルテタ", "q")]),
    ])
    assert _pick(script, "何が起きたか").title == "何が起きたか"


def test_知らない節は弾く():
    from src.shorts import ShortError, _pick

    script = _built([("何が起きたか", [("キャスター", None)])])
    try:
        _pick(script, "存在しない節")
    except ShortError as err:
        assert "ありません" in str(err)
    else:
        raise AssertionError("知らない節を通した")
