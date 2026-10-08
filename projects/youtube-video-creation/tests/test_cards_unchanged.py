"""**既存の図の見た目を1pxも変えない**ための控え（2026-10-08）。

折れ線（line）・増減の内訳（waterfall）・年表（timeline）を足すとき、`PAD` や
`_title_block`・`_note_blocks`・`nice_ticks` のような**共有の部品**をうっかり直すと、
既にある10種の図が全部ずれる。目で見ても1px は分からないので、画素の控えを取っておく。

**2026-10-08 夕方に、控えをわざと取り直した。**「板の字がスマホで読めない25件」を直したので、
画素が変わるのは意図したこと（`tools/typecheck.py --only-bad` の × を 0 にする直し）。
**26枚のうち5枚が変わった**（取り直す前後の sha1 を突き合わせて数えた）。

| 変わった控え | なぜ |
|---|---|
| `kit@1420` `kit@972` | 判定の印（OK・×）の字を白 → 板の地の色に。緑の丸地に白で 2.1:1（下限3:1）だった |
| `scatter@1420` `scatter@972` | 図の高さを**置き場から決める**ようにした。目盛り・軸・札の字を幅で変えない（27/29/33 → 28/30/34）。横軸の名前と添えを1行にまとめた |
| `convert@1420` | 本編の3段を**横に並べる**ようにした（縦に積むと 744px で、置き場 539px に収まらず 0.72 倍に縮んでいた）。ショート（`convert@972`）は置き場が 983px あるので縦のまま＝画素も同じ |

**残り21枚は1pxも変わっていない。**ここの見本は小さい（表は2行・出典なし・数字が大きい）ので、
今回入れた下限（出典28px・単位30px・行の高さ）に当たらなかった。
**当たるのは本物の分量の板**で、そちらは `tools/typecheck.py` が測っている。

控えは `tests/card_pixels.json`（型と幅ごとに、描いた RGBA の sha1）。
**フォントが違う環境では比べない**（CI は Ubuntu の Noto、手元は メイリオ。
同じ字でも字形が違うので画素は必ず変わる）。手元で直すときに効くのが狙い。

控えの作り直し（既存の図を**わざと**直したときだけ）::

    python -m tests.test_cards_unchanged
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest
from PIL import Image

from src import cards
from src.config import load_config

MANIFEST = Path(__file__).with_name("card_pixels.json")
MAIN = 1420          # 本編で写真の無い画面に置くときの幅
SHORT = 972          # ショートの幅
# **置き場の高さも控えに入れる**（2026-10-08）。表・散らばり図・折れ線・換算は
# 置き場に収まる高さで描くので、これを渡さないと本番と違う絵を控えることになる
SLOT = {MAIN: cards.SLOT_LANDSCAPE, SHORT: cards.SLOT_PORTRAIT}

# 2026-10-08 より前にあった図。**新しい3つ（line・waterfall・timeline）は入れない**
# （足した側が変わるのは当たり前なので、控えても意味がない）
LEGACY_SPECS: dict[str, dict] = {
    "quote": {"type": "quote", "label": "The Athletic", "text": "He is the best in the world",
              "translation": "いまの世界でいちばんだ"},
    "transfer": {"type": "transfer", "player": "ヴィルツ", "from": "レヴァークーゼン",
                 "to": "リヴァプール", "fee": "移籍金 1億1600万ポンド"},
    "score": {"type": "score", "competition": "プレミア第5節", "home": "アーセナル", "away": "マンC",
              "score": "1-1", "home_scorers": ["マルティネッリ 93分"], "away_scorers": ["ハーランド 9分"]},
    "points": {"type": "points", "title": "この夏に起きたこと",
               "items": ["主将が抜けた", "補強は2人", "開幕5戦で2勝"]},
    "bars": {"type": "bars", "title": "枠内シュート", "unit": "本",
             "items": [{"label": "アーセナル", "value": 8, "highlight": True},
                       {"label": "マンC", "value": 3}]},
    "table": {"type": "table", "title": "得点の流れ", "columns": ["分", "選手", "点差"],
              "rows": [["9分", "ハーランド", "0-1"], ["93分", "マルティネッリ", "1-1"]]},
    "reactions": {"type": "reactions", "title": "ネットの反応",
                  "items": [{"text": "最後まで分からなかった", "label": "X"},
                            {"text": "あの交代が効いた", "label": "X"}]},
    "kit": {"type": "kit", "title": "CL登録から外れた2人",
            "items": [{"player": "遠藤 航", "number": 3, "colors": ["#C8102E"], "mark": "×"},
                      {"player": "エキティケ", "number": 22, "colors": ["#C8102E"], "mark": "○"}]},
    "stats": {"type": "stats", "title": "メッシの代表",
              "items": [[208, "試合", "歴代最多"], [126, "点"], ["W杯", "優勝", "2022年"]]},
    "verdict": {"type": "verdict", "title": "夏の補強の答え合わせ", "columns": ["選手", "判定", "一言"],
                "rows": [["イサク", "◎", "8試合6点"], ["ヴィルツ", "△", "1点だけ"]],
                "highlight_row": 1},
    "calc": {"type": "calc", "title": "ケインの代表",
             "terms": [["125試合", "代表の出場"], ["11年", "2015〜2026"], ["年10.8試合", "1年あたり"]],
             "ops": ["÷", "＝"]},
    "scatter": {"type": "scatter", "title": "得点と期待値", "x": {"label": "期待値", "unit": "xG"},
                "y": {"label": "得点", "unit": "点"},
                "points": [["ハーランド", 4.4, 5], ["イサク", 3.5, 4], ["サカ", 3.2, 3],
                           ["ムベウモ", 3.1, 2]],
                "focus": "ハーランド", "diagonal": "期待値どおり", "source": "FotMob"},
    "convert": {"type": "convert", "title": "週給を円に直すと",
                "steps": [["30万", "ポンド", "週給"], ["1560万", "ポンド", "年俸（52週）"],
                          ["約30", "億円", "日本円で"]],
                "via": ["×52週", "1ポンド＝195円"]},
}


def _fonts() -> tuple[str, str]:
    video = load_config().video
    return str(video.font_path()), str(video.latin_font_path())


def _font_mark() -> str:
    """どのフォントで描いたか（名前と大きさ）。字形が違えば画素は必ず変わる。"""
    return "|".join(f"{Path(p).name}:{Path(p).stat().st_size}" for p in _fonts())


def _digest(spec: dict, width: int, fonts: tuple[str, str], work: Path) -> str:
    path = cards.render(spec, width, fonts[0], work / "x.png", fonts[1], slot=SLOT[width])
    with Image.open(path) as image:
        raw = image.convert("RGBA")
        return hashlib.sha1(f"{raw.size}|".encode() + raw.tobytes()).hexdigest()[:16]


def build(work: Path) -> dict:
    fonts = _fonts()
    return {"font": _font_mark(),
            "pixels": {f"{name}@{width}": _digest(spec, width, fonts, work)
                       for name, spec in LEGACY_SPECS.items() for width in (MAIN, SHORT)}}


def test_控えに全部の型が入っている():
    """**足し忘れを止める。**新しい型を足したら、古い型の控えは全部そろっているはず。"""
    saved = json.loads(MANIFEST.read_text(encoding="utf-8"))
    missing = [t for t in cards.CARD_TYPES
               if t not in LEGACY_SPECS and t not in ("versus", "line", "waterfall", "timeline")]
    assert missing == [], f"控えの無い型があります: {missing}"
    assert len(saved["pixels"]) == len(LEGACY_SPECS) * 2


def test_既存の図は画素が1つも変わっていない(tmp_path):
    saved = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if saved["font"] != _font_mark():
        pytest.skip(f"フォントが控えと違うので画素は比べません（控え {saved['font']} / いま {_font_mark()}）")
    found = build(tmp_path)["pixels"]
    changed = [key for key, value in saved["pixels"].items() if found.get(key) != value]
    assert changed == [], (
        f"既存の図の見た目が変わりました: {'・'.join(changed)}。"
        "共有の部品（PAD・_title_block・_note_blocks・nice_ticks・_wrap など）を直していないか見てください。"
        "わざと直したのなら python -m tests.test_cards_unchanged で控えを作り直します")


if __name__ == "__main__":          # 控えの作り直し
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        MANIFEST.write_text(json.dumps(build(Path(tmp)), ensure_ascii=False, indent=2) + "\n",
                            encoding="utf-8")
    print(f"控えを作り直しました: {MANIFEST}")
