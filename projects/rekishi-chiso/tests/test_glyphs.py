"""フォントに無い字の点検（10-09、始皇帝の回の「嫪毐」の「毐」が字幕・札・年表で□になった）。
CI には日本語フォントが無いので、Pillow 内蔵のフォント（ラテン文字だけ）を「フォント」として渡す。"""
import pytest
from PIL import ImageFont

from chiso import check, script


def _sc():
    return script.parse({
        "title": "Qin",
        "timeline": {"start": -259, "end": -210, "events": [[-238, "Lao 毐"]]},
        "shorts": {"s1": {"title": "Ai", "hook": "Who?", "tease": "Why?"}},
        "next": {"title": "Next", "teaser": "Soon."},
        "thumbnail": {"layout": "classic", "image": "x.jpg", "name": "毐"},
        "sections": [{"title": "One", "lines": [
            {"語り": "Lao 毐 came.", "card": {"head": "238", "body": "毐"}},
            {"聞き": "Who?"},
            {"語り": "Lao 毐 again.", "short": "s1"},
        ]}],
    })


@pytest.fixture
def builtin():
    f = ImageFont.load_default(40)
    if not isinstance(f, ImageFont.FreeTypeFont):
        pytest.skip("FreeType の無い Pillow")
    return f


def test_missing_glyph_is_an_error_with_rows_folded(builtin):
    errs = check.glyph_errors(_sc(), {"serif": builtin})
    assert len(errs) == 1                                     # 同じ字は1件にまとめる
    assert errs[0].startswith("1・3行目・年表：『毐』がフォント（明朝）に無く□で出ます")
    assert "かなで書くか言い換える" in errs[0]
    # report に通すと止める（×）に並ぶ
    assert check.report(errs, [])[0].startswith("× 1・3行目")


def test_thumbnail_is_checked_only_with_gothic(builtin):
    errs = check.glyph_errors(_sc(), {"gothic": builtin})
    assert errs and "サムネイル" in errs[0] and "ゴシック" in errs[0]
    assert "年表" not in errs[0]                              # 年表の名札は明朝で描く


def test_pillow_method_matches_tofu(builtin):
    assert check.missing_glyphs(set("Ab毐 　"), builtin) == {"毐"}   # 空白は形が無くてよい


def test_rewritten_text_passes(builtin):
    sc = _sc()                                                # 画面に出す所を書き換えれば止まらない
    for l in sc.lines:
        l.text = l.text.replace("毐", "ai")
        l.card = None
    sc.events.clear()
    sc.thumbnail["name"] = "Ai"
    assert check.glyph_errors(sc, {"serif": builtin, "gothic": builtin}) == []


def test_missing_font_file_is_skipped():
    assert check.glyph_errors(_sc(), {"serif": "/no/such/font.ttf"}) == []
