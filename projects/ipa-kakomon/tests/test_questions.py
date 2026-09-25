"""問題冊子の読み取りのテスト。

PDF も通信も使わない。壊れ方はどれも「間違った問題文を黙って公開する」形なので、
実物の PDF で見つけたものを1件ずつ固定してある。
"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

import questions  # noqa: E402
from questions import Line, Shape, parse  # noqa: E402


def _q(number: int, body: str, choices=("あ", "い", "う", "え"), page=0, top=0.0):
    """1問ぶんの行を作る。top は行ごとに10ずつ下がる。"""
    out = [Line(page=page, top=top, text=f"問{number} {body}")]
    for mark, text in zip("アイウエ", choices):
        top += 10
        out.append(Line(page=page, top=top, text=f"{mark} {text}"))
    return out


def test_問と選択肢を取り出す():
    lines = _q(1, "これは何か。", ("赤", "青", "緑", "黄"))
    got = parse(lines)
    assert len(got) == 1
    assert got[0].number == 1
    assert got[0].text == "これは何か。"
    assert got[0].choices == ("赤", "青", "緑", "黄")


def test_折り返された行は空白を入れずにつなぐ():
    """日本語は単語を空白で区切らない。空白を挟むと原文と変わる。"""
    lines = [
        Line(0, 0, "問1 リスクマネジメントプロ"),
        Line(0, 10, "セスに関する記述はどれか。"),
        Line(0, 20, "ア 機器やソフトウェアの脆弱性のうち，対策方法が"),
        Line(0, 30, "提供されていない状態のこと"),
        Line(0, 40, "イ い"),
        Line(0, 50, "ウ う"),
        Line(0, 60, "エ え"),
    ]
    got = parse(lines)
    assert got[0].text == "リスクマネジメントプロセスに関する記述はどれか。"
    assert got[0].choices[0] == "機器やソフトウェアの脆弱性のうち，対策方法が提供されていない状態のこと"


def test_選択肢が1行に並んでいても取れる():
    """短い選択肢は「ア 0.6 イ 0.72 ウ 0.8 エ 0.9」と横に並ぶ（令和7年度 SG 問9）。"""
    lines = [
        Line(0, 0, "問1 目標達成率は幾らか。"),
        Line(0, 10, "ア 0.6 イ 0.72 ウ 0.8 エ 0.9"),
    ]
    got = parse(lines)
    assert got[0].choices == ("0.6", "0.72", "0.8", "0.9")


def test_本文の途中で行頭に来たアは選択肢にしない():
    """記号は必ずアイウエの順に出る。順番を待てば取り違えが起きない。"""
    lines = [
        Line(0, 0, "問1 次のうち適切なものはどれか。"),
        Line(0, 10, "ウ の記号から始まる行が本文に紛れている。"),
        Line(0, 20, "ア あ"),
        Line(0, 30, "イ い"),
        Line(0, 40, "ウ う"),
        Line(0, 50, "エ え"),
    ]
    got = parse(lines)
    assert got[0].text == "次のうち適切なものはどれか。ウ の記号から始まる行が本文に紛れている。"
    assert got[0].choices == ("あ", "い", "う", "え")


def test_全角の問番号も半角の問番号も読む():
    """1〜9は全角、10以降は半角で出る（令和7年度 SG で実測）。"""
    lines = _q("９", "ここは全角。") + _q(10, "ここは半角。", top=100)
    # 問9 の前に1〜8が無いと連番の検査で落ちるので、番号だけを見る
    with pytest.raises(ValueError, match="連番"):
        parse(lines)


def test_ページ番号は問題文に混ぜない():
    lines = [
        Line(0, 0, "問1 これは何か。"),
        Line(0, 10, "ア あ"),
        Line(0, 20, "イ い"),
        Line(0, 30, "ウ う"),
        Line(0, 40, "エ え"),
        Line(0, 50, "－ 2 －"),
    ]
    assert parse(lines)[0].choices[3] == "え"


def test_巻末は最後の問にくっつけない():
    """メモ用紙や著作権表示が最後の選択肢に丸ごと入っていた（FE 科目A 問20）。"""
    lines = _q(1, "これは何か。") + [
        Line(0, 100, "〔 メ モ 用 紙 〕"),
        Line(0, 110, "試験問題に記載されている会社名又は製品名は，それぞれ各社の商標です。"),
        Line(0, 120, "©2025 独立行政法人情報処理推進機構"),
    ]
    assert parse(lines)[0].choices[3] == "え"


def test_選択肢が4つ揃っていなければ落とす():
    """足りないまま通すと、選べない問がそのまま公開される。"""
    lines = [
        Line(0, 0, "問1 これは何か。"),
        Line(0, 10, "ア あ"),
        Line(0, 20, "イ い"),
    ]
    with pytest.raises(ValueError, match="選択肢が2個"):
        parse(lines)


def test_問番号が飛んでいたら落とす():
    """欠番は気づかれないまま信用を失う壊れ方。黙って通さない。"""
    lines = _q(1, "ひとつめ。") + _q(3, "みっつめ。", top=100)
    with pytest.raises(ValueError, match="欠番"):
        parse(lines)


def test_問が1つも無ければ落とす():
    """テキスト層の無い PDF（筆記試験）を渡したときに、静かに空を返さない。"""
    with pytest.raises(ValueError, match="テキスト層"):
        parse([Line(0, 0, "－ 1 －")])


def test_線が引かれている問に印を付ける():
    """図や表はテキストに出ない。落ちたまま公開しないための印。"""
    lines = _q(1, "表を見て答えよ。") + _q(2, "表は無い。", top=100)
    got = parse(lines, [Shape(page=0, top=25.0)])
    assert got[0].has_figure is True
    assert got[1].has_figure is False
    assert got[0].needs_review is True


def test_線がページをまたいでも持ち主を間違えない():
    lines = _q(1, "1ページ目。", page=0, top=0) + _q(2, "2ページ目。", page=1, top=0)
    got = parse(lines, [Shape(page=1, top=5.0)])
    assert got[0].has_figure is False
    assert got[1].has_figure is True


def test_小さい文字が混ざる問は要確認にする():
    """下付き文字は並ぶ順がずれることがある（CO₂ の 2）。機械の判断で公開しない。"""
    lines = _q(1, "これは何か。")
    lines[1] = Line(0, 10, "ア CO2 に換算する", has_small_text=True)
    got = parse(lines)
    assert got[0].has_small_text is True
    assert got[0].needs_review is True


def test_印が何も無ければ要確認にしない():
    got = parse(_q(1, "これは何か。"))
    assert got[0].needs_review is False


class _FakePage:
    """`_page_lines` に渡す最小限のページ。pdfplumber は使わない。"""

    def __init__(self, rows):
        self._rows = [
            {"text": text, "top": float(top),
             "chars": [{"size": size} for _ in text]}
            for text, top, size in rows
        ]

    @property
    def chars(self):
        return [c for row in self._rows for c in row["chars"]]

    def extract_text_lines(self):
        return self._rows


def test_ルビの行は捨てる():
    """ルビが本文の後ろにくっついて読めなくなっていた（SG 問3 の「ぜい」）。"""
    page = _FakePage([
        ("問3 ゼロトラストの説明はどれか。", 69.6, 10.0),
        ("ぜい", 105.0, 5.0),
        ("ア 脆弱性のうち，対策方法が提供されていないもの", 109.7, 10.0),
    ])
    got = questions._page_lines(page, 0)
    assert [line.text for line in got] == [
        "問3 ゼロトラストの説明はどれか。",
        "ア 脆弱性のうち，対策方法が提供されていないもの",
    ]


def test_仮名以外の小さい文字は捨てずに印を付ける():
    """`CO₂` の下付きの 2 を捨てると `CO` になる。意味が変わるので残す。"""
    page = _FakePage([
        ("排出量を，CO", 380.0, 10.0),
        ("2", 383.2, 7.0),
        ("量に換算する", 386.0, 10.0),
    ])
    got = questions._page_lines(page, 0)
    assert [line.text for line in got] == ["排出量を，CO", "2", "量に換算する"]
    assert got[1].has_small_text is True


def test_本文の大きさはページごとに数えて決める():
    """表紙や事例問題で本文の大きさが変わる。決め打ちにしない。"""
    page = _FakePage([
        ("見出し", 10.0, 14.0),                      # 3文字
        ("ここが本文でいちばん字数が多い行です", 30.0, 9.0),   # 18文字
    ])
    assert questions._body_size(page) == 9.0
