"""問題冊子 PDF から、1問ずつ問題文と選択肢を取り出す。

**CBT 方式の区分（SG・FE・IT パスポート）だけが対象**。筆記試験の問題冊子は
スキャン画像を PDF に包んだだけで文字層を持たず、ここでは扱えない
（2026-09-24 に令和7年度・令和5年度の AP で実測した。README 参照）。

図や表は**画像ではなく線で描かれている**。テキストだけを取ると、表の中身が
丸ごと落ちたまま「問題文は取れた」ように見えてしまう。それを防ぐため、
問の範囲に線が引かれていたら `has_figure` を立てる。**印が立った問は、
人が見るまで公開しない**（資格試験のサイトで問題文が欠けるのは致命的）。
"""
import re
from dataclasses import dataclass
from pathlib import Path

# 問番号は1〜9が全角、10以降が半角で出る（令和7年度 SG で実測）。両方受ける。
_QUESTION_HEAD = re.compile(r"^問\s*([0-9０-９]{1,3})\s*(.*)$")

# 選択肢の記号。**この順でしか現れない**ことを前提に読む。
# 記号だけを見ていると、本文の途中で行頭に来た「ア」を選択肢と誤読する。
# 次に来るはずの記号だけを待てば、その取り違えが構造的に起きない。
_CHOICE_MARKS = ("ア", "イ", "ウ", "エ")

# 選択肢が短いと「ア 0.6 イ 0.72 ウ 0.8 エ 0.9」と1行に並ぶ（令和7年度 SG 問9）。
# 行頭だけを見ていると、この形の問は選択肢が1つしか取れない。
# 記号の手前は行頭か空白に限る（「エラー」の「エ」を拾わないため）。
_CHOICE_MARK = re.compile(r"(?:^|(?<=[ 　]))([アイウエ])[ 　]+")

# ページ下部のノンブル（「－ 2 －」）。問題文に混ざると読めなくなる。
_PAGE_NUMBER = re.compile(r"^[－\-‐―ー]\s*[0-9０-９]+\s*[－\-‐―ー]$")

# 巻末（メモ用紙・商標の断り・著作権表示）。ここから先は問題ではない。
# 最後の問はこれで閉じないと、**巻末が丸ごと最後の選択肢にくっつく**
# （令和7年度 FE 科目A の問20 で実際にそうなった）。
_BACK_MATTER = re.compile(
    r"^(?:〔\s*メ\s*モ\s*用\s*紙\s*〕|試験問題に記載されている会社名|©\s*[0-9]{4}\s*独立行政法人)"
)

_ZEN_TO_HAN = str.maketrans("０１２３４５６７８９", "0123456789")

# ルビは必ず仮名で組まれる。**仮名以外の小さい文字は捨てない。**
# 「CO₂」の下付きの 2 も小さい文字として1行に分かれて出てくるので、
# 「小さい行は捨てる」だけにすると、黙って「CO」になる（実測）。
_RUBY = re.compile(r"^[ぁ-ゖァ-ヺー\s]+$")


@dataclass(frozen=True)
class Line:
    """PDF から取り出した1行。ページと上からの位置を持つ。

    位置を持たせているのは、図や表がどの問に属するかを決めるため。
    テキストだけでは、線で描かれた表がどこに挟まっているか分からない。
    """

    page: int
    top: float
    text: str
    #: 本文より小さい文字が混ざっている行。下付き文字（CO₂ の 2）などで、
    #: 取り出す順が本文とずれることがある。**人が見るまで信用しない。**
    has_small_text: bool = False


@dataclass(frozen=True)
class Shape:
    """線で描かれたもの（表の罫線・図）の位置。中身は読まない。"""

    page: int
    top: float


@dataclass(frozen=True)
class Question:
    number: int
    text: str
    choices: tuple[str, ...]
    #: 図や表が含まれている可能性（線が引かれている）。
    has_figure: bool
    #: 本文より小さい文字が混ざっている（下付き・上付き）。
    has_small_text: bool
    #: この問が載っているページ（0起点）。出典の確認に使う。
    pages: tuple[int, ...]

    @property
    def needs_review(self) -> bool:
        """人が見るまで公開してはいけない問。

        図・表はテキストに出ないので落ちる。小さい文字は取り出す順が
        本文とずれる（`CO₂` が `CO 量…表2示` のように割れる実例がある）。
        どちらも**間違った問題文を載せる**形の壊れ方なので、機械の判断で公開しない。
        """
        return self.has_figure or self.has_small_text


def _join(parts: list[str]) -> str:
    """折り返された行をつなぐ。**間に空白を入れない。**

    日本語は単語の区切りに空白を使わないので、素直に連結すると
    「リスクマネジメントプロ」＋「セスに関する」が正しくつながる。
    英単語の途中で折り返された場合も、PDF 側が行末にハイフンを置かない
    （実測）ので、ここで補う必要はない。
    """
    return "".join(p.strip() for p in parts)


def parse(lines: list[Line], shapes: list[Shape] | None = None) -> list[Question]:
    """行の並びから問を組み立てる。

    読み落としを黙って通さないため、次の場合は例外にする。

    - 問番号が1から始まる連番になっていない
    - 選択肢がアイウエの4つ揃っていない

    公開する側が「たぶん大丈夫」で進めると、欠けた問がそのまま世に出る。
    """
    shapes = shapes or []
    starts: list[tuple[int, float, int]] = []   # (page, top, number)
    collected: list[dict] = []
    current: dict | None = None

    for line in lines:
        text = line.text.strip()
        if _BACK_MATTER.match(text):
            break
        if not text or _PAGE_NUMBER.match(text):
            continue

        head = _QUESTION_HEAD.match(text)
        if head:
            number = int(head.group(1).translate(_ZEN_TO_HAN))
            current = {
                "number": number,
                "body": [head.group(2)],
                "choices": [],
                "pages": {line.page},
                "small": line.has_small_text,
            }
            collected.append(current)
            starts.append((line.page, line.top, number))
            continue

        if current is None:
            # 最初の問より前（表紙・注意事項）。捨てる。
            continue

        current["pages"].add(line.page)
        current["small"] = current["small"] or line.has_small_text
        prefix, segments = _choice_segments(text, len(current["choices"]))
        if prefix:
            # 記号より前にある文字は、直前に読んでいたものの続き。
            target = current["choices"][-1] if current["choices"] else current["body"]
            target.append(prefix)
        for body in segments:
            current["choices"].append([body])
        if not prefix and not segments:
            target = current["choices"][-1] if current["choices"] else current["body"]
            target.append(text)

    questions = _finalize(collected, starts, shapes)
    _check_numbering(questions)
    return questions


def _choice_segments(text: str, next_index: int) -> tuple[str, list[str]]:
    """1行を「記号より前の部分」と「選択肢の本文」に割る。

    期待している記号（次に来るはずのもの）から順に、その行に並んでいるぶんだけ
    拾う。順番が違うもの・先走ったものは**選択肢として扱わない**ので、
    本文中の「ア」で選択肢が始まってしまう取り違えが起きない。
    """
    if next_index >= len(_CHOICE_MARKS):
        return "", []

    found: list[tuple[int, int, str]] = []   # (開始, 本文の開始, 記号)
    index = next_index
    for match in _CHOICE_MARK.finditer(text):
        if index >= len(_CHOICE_MARKS) or match.group(1) != _CHOICE_MARKS[index]:
            continue
        found.append((match.start(), match.end(), match.group(1)))
        index += 1

    if not found:
        return "", []

    prefix = text[: found[0][0]].strip()
    bodies = []
    for i, (_, body_start, _mark) in enumerate(found):
        end = found[i + 1][0] if i + 1 < len(found) else len(text)
        bodies.append(text[body_start:end].strip())
    return prefix, bodies


def _finalize(collected: list[dict], starts: list[tuple[int, float, int]],
              shapes: list[Shape]) -> list[Question]:
    figures = _questions_with_shapes(starts, shapes)
    out = []
    for item in collected:
        if len(item["choices"]) != len(_CHOICE_MARKS):
            got = len(item["choices"])
            raise ValueError(
                f"問{item['number']}: 選択肢が{got}個しか取れていない"
                f"（アイウエの4つが要る）。PDF の形が変わった可能性がある"
            )
        out.append(Question(
            number=item["number"],
            text=_join(item["body"]),
            choices=tuple(_join(c) for c in item["choices"]),
            has_figure=item["number"] in figures,
            has_small_text=item["small"],
            pages=tuple(sorted(item["pages"])),
        ))
    return out


def _questions_with_shapes(starts: list[tuple[int, float, int]],
                           shapes: list[Shape]) -> set[int]:
    """線が引かれている範囲にかかる問の番号。

    ある問は、自分の開始位置から**次の問の開始位置の手前まで**を占める。
    ページをまたぐので、(ページ, 上からの位置) の組で大小を比べる。
    """
    marked: set[int] = set()
    for shape in shapes:
        here = (shape.page, shape.top)
        owner = None
        for page, top, number in starts:
            if (page, top) <= here:
                owner = number
            else:
                break
        if owner is not None:
            marked.add(owner)
    return marked


def _check_numbering(questions: list[Question]) -> None:
    """問番号が1からの連番であること。

    途中が抜けていても、抜けたまま公開できてしまうのが怖い。
    「問7が無い過去問サイト」は、あることに気づかれないまま信用を失う。
    """
    numbers = [q.number for q in questions]
    if not numbers:
        raise ValueError("問が1つも取れていない。テキスト層の無い PDF の可能性がある")
    expected = list(range(1, len(numbers) + 1))
    if numbers != expected:
        missing = sorted(set(expected) - set(numbers))
        raise ValueError(f"問番号が連番になっていない: {numbers}（欠番: {missing}）")


def extract(pdf_path: Path) -> list[Question]:
    """問題冊子 PDF を読んで問の一覧を返す。

    `pdfplumber` が要る。テキスト層が無ければ `_check_numbering` が例外にする
    （筆記試験の PDF をうっかり渡したときに、静かに空を返さないため）。
    """
    import pdfplumber

    lines: list[Line] = []
    shapes: list[Shape] = []
    with pdfplumber.open(str(pdf_path)) as pdf:
        for page_no, page in enumerate(pdf.pages):
            lines.extend(_page_lines(page, page_no))
            for obj in list(page.rects) + list(page.curves):
                shapes.append(Shape(page=page_no, top=float(obj.get("top", 0.0))))
    return parse(lines, shapes)


def _body_size(page) -> float:
    """そのページの本文の文字の大きさ（いちばん多く使われている大きさ）。

    ルビや下付き文字を見分けるための基準。ページごとに求めるのは、
    表紙や事例問題で本文の大きさが変わることがあるため。
    """
    counts: dict[float, int] = {}
    for char in page.chars:
        size = round(float(char.get("size", 0.0)), 1)
        counts[size] = counts.get(size, 0) + 1
    if not counts:
        return 0.0
    return max(counts.items(), key=lambda kv: (kv[1], kv[0]))[0]


#: 本文に対してこれより小さい文字は、ルビか下付き・上付きとみなす。
#: 実測: 本文 10.0 に対してルビ 5.0、商標記号 8.0。8.0 は本文の一部として残す。
_SMALL_RATIO = 0.75


def _page_lines(page, page_no: int) -> list[Line]:
    """1ページを行に割る。**ルビの行は落とす。**

    ルビは本文の上に別の行として置かれているので、そのまま読むと
    「ゼロトラストの説明として，最も適切なものはどれか。ぜい」のように
    本文の後ろにくっつく（令和7年度 SG 問3 で実際に出た）。

    捨てるのは**仮名だけでできた小さい行**に限る。ルビは必ず仮名で組まれるため。
    「小さい行は捨てる」とだけ決めると、`CO₂` の下付きの `2` も1行として
    出てくるので黙って落ち、`CO` に化ける（令和7年度 FE 科目A 問20 で実測）。

    仮名以外の小さい文字は残したうえで `has_small_text` を立てる。
    位置から組み直しているので大抵は正しく並ぶが、保証はできないので人に回す。
    """
    body = _body_size(page)
    if not body:
        return []
    threshold = body * _SMALL_RATIO

    out: list[Line] = []
    for row in page.extract_text_lines():
        sizes = [round(float(c.get("size", 0.0)), 1) for c in row["chars"]]
        all_small = bool(sizes) and max(sizes) < threshold
        if all_small and _RUBY.match(row["text"]):
            continue        # ルビ。本文にくっつくと読めなくなるので捨てる
        out.append(Line(
            page=page_no,
            top=float(row["top"]),
            text=row["text"],
            has_small_text=any(s < threshold for s in sizes),
        ))
    return out
