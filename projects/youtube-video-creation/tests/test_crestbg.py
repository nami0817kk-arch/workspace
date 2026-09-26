"""エンブレムから作る下地（`tools/crestbg.py`）。プレミア20クラブ紹介のための特例。"""
import importlib.util
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("crestbg_tool", ROOT / "tools" / "crestbg.py")
crestbg = importlib.util.module_from_spec(spec)
sys.modules["crestbg_tool"] = crestbg
spec.loader.exec_module(crestbg)


def test_エンブレムはテロップにもカードにも重ならない():
    """**書き出して1枚見るまで気づかなかった**ので、位置を数字で縛る。

    最初は上半分の真ん中に大きく置いていた。カードの地が半透明なので、
    アーセナルの大砲が表の「The Gunners」に透けていた。
    テロップは画面の下 58〜88%、カードは幅の64%を真ん中に取る。
    """
    half = crestbg.CREST_HEIGHT // 2
    top = crestbg.CREST_CENTER_Y - half
    bottom = crestbg.CREST_CENTER_Y + half
    left = crestbg.CREST_CENTER_X - crestbg.CREST_MAX_WIDTH // 2

    # テロップの帯（y は画面の58%から）に入らない
    assert bottom < crestbg.HEIGHT * 0.58, "テロップに重なる"
    # カードの右端（幅の64%を中央に取る）より右にある
    card_right = crestbg.WIDTH / 2 + crestbg.WIDTH * 0.64 / 2
    assert left >= card_right, "カードに重なる"
    # 画面からはみ出さない
    assert crestbg.CREST_CENTER_X + crestbg.CREST_MAX_WIDTH // 2 <= crestbg.WIDTH
    assert top > 0


def test_白は下地の色に数えない():
    """白を数えると、**どのクラブも同じ薄い灰色**になる（実測で2クラブが同じ色になった）。"""
    image = Image.new("RGBA", (40, 40), (255, 255, 255, 255))
    for x in range(40):
        for y in range(12):          # 一部だけ濃い青
            image.putpixel((x, y), (20, 40, 160, 255))
    r, g, b = crestbg.club_color(image)
    assert b > r and b > g, (r, g, b)


def test_透けたところは数えない():
    image = Image.new("RGBA", (40, 40), (10, 200, 10, 0))   # 全部が透明な緑
    for x in range(40):
        for y in range(8):
            image.putpixel((x, y), (200, 30, 30, 255))      # 見えているのは赤だけ
    r, g, b = crestbg.club_color(image)
    assert r > g and r > b, (r, g, b)


def test_下地は明るいほうへ寄せる():
    """**そのままの色だと暗すぎて、白いテロップ以外が沈む。**"""
    image = crestbg.gradient((20, 20, 20))
    assert image.size == (crestbg.WIDTH, crestbg.HEIGHT)
    assert min(image.getpixel((5, 5))) > 120, image.getpixel((5, 5))
