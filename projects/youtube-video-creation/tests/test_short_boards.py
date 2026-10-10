# -*- coding: utf-8 -*-
"""山場が発言ばかりで板が1枚も無い回を、`draft` が知らせるか（2026-10-10）。

ショートは山場（`main: true`）の節だけを切り出すので、そこに板が無いと
**50秒まるごと同じ写真1枚**になる。原因は決まりどうしの噛み合わせで、
「代弁の行に引用カードを出さない」（2026-09-14）が効くと
**発言の行には板が1枚も付かない**。

2026-10-10 に**1日で5本**出た（キャリック51秒・コンパニ53秒・モイーズ35秒・
代表ウィーク11秒・佐野8秒）。10月から**ニュースはショートだけ**作る形にしたので、
会見の発言が主役の回は毎日この型になる。

**`tools/preview4.py`（書き出す前の4コマ）では見つからない**——見る4つの時点が
たまたま板の無い所に当たる。見つかるのは `tools/qc.py`（通しで見る）だけで、
それは書き出したあとなので、`draft` の段階で知らせる。
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.research import Notes, Section, _advise_short_boards  # noqa: E402


def _section(**kw) -> Section:
    base = dict(
        id="words", heading="会見で答えたこと", main=True, tier="報道", telop="",
        say=["判定について、監督は会見でこう答えました。",
             "そのことを話すのにふさわしいのは、",
             "この上訴に勝つときだ。",
             "彼らは正直な形で考えている。",
             "最後には勝つと、彼らは確信していると思う。",
             "まったく、そんなことはない。"],
        voices=["", "監督", "監督", "監督", "監督", "監督"],
        line_cards=[None] * 6,
        line_images=[""] * 6,
    )
    base.update(kw)
    return Section(**base)


def _notes(section: Section) -> Notes:
    return Notes(date="2026-10-10", title="会見で答えたこと",
                 question="監督は何を言ったのか", sections=[section])


def test_山場が発言ばかりで板が無ければ知らせる():
    hints = _advise_short_boards(_notes(_section()))
    assert hints, "板が1枚も無い山場を見逃しています"
    assert "板が1枚もありません" in hints[0]


def test_行ごとの板があれば知らせない():
    card = {"type": "table", "columns": ["問われたこと", "答え"],
            "rows": [["判定をどう見るか", "とても言いにくい"]]}
    s = _section(line_cards=[None, card, card, None, card, card])
    assert not _advise_short_boards(_notes(s)), "板を置いた回で鳴っています"


def test_節に板があれば知らせない():
    s = _section(card={"type": "quote", "text": "この上訴に勝つときだ"})
    assert not _advise_short_boards(_notes(s)), "節の板を数えていません"


def test_写真を入れ替えていれば知らせない():
    """板の代わりに写真を替えても画面は動く。

    フリックとヤマルの回は板を入れると顔が潰れたので、2枚並べ↔ヤマル1枚を
    3往復させた。通しの点検（qc）でも最長6.6秒で通っている。
    """
    s = _section(line_images=["a/01.jpg", "b/01.jpg", "b/01.jpg",
                              "a/01.jpg", "a/01.jpg", "b/01.jpg"])
    assert not _advise_short_boards(_notes(s)), "写真の入れ替えを数えていません"


def test_card_none_は板として数えない():
    """`card: none` は板を**下ろす**指定なので、置いたことにはならない。"""
    s = _section(line_cards=[None, "none", "none", None, "none", "none"])
    assert _advise_short_boards(_notes(s)), "`card: none` を板と数えています"


def test_発言が半分に満たなければ知らせない():
    """語りが主役の回は、この型ではない。"""
    s = _section(voices=["", "", "", "", "", "監督"])
    assert not _advise_short_boards(_notes(s)), "語りが主役の回で鳴っています"


def test_行の少ない山場では知らせない():
    s = _section(say=["監督はこう答えました。", "この上訴に勝つときだ。"],
                 voices=["", "監督"], line_cards=[None, None], line_images=["", ""])
    assert not _advise_short_boards(_notes(s)), "3行以下の山場で鳴っています"


def test_山場が無ければ知らせない():
    s = _section(main=False)
    assert not _advise_short_boards(_notes(s))
