"""1問1ページの HTML を組み立てる。

**ファイル名は `site.py` にしない。** Python の標準ライブラリに `site` があり、
`import site` がそちらを拾って静かに別物を読み込む（実際に踏んだ）。

**出典の表記は IPA が付けている利用条件**（年度・期・試験区分・問番号）。
欠けたまま公開すると条件違反になるので、テンプレートに埋め込むのではなく
`question_page` が必ず書く。書けない情報が来たら例外にする。

`needs_review` が立った問は**ここで弾く**。図や表が落ちた問題文や、
下付き文字の並びがずれた問題文を出すのは、資格試験のサイトとして致命的。
弾くのを呼び出し側の心がけに任せない。
"""
import html
from dataclasses import dataclass

from questions import Question

#: 試験区分のコードと表示名。URL のスラッグにも使う。
EXAMS = {
    "sg": "情報セキュリティマネジメント試験",
    "fe": "基本情報技術者試験",
    "ip": "ITパスポート試験",
}

_CHOICE_MARKS = "アイウエオカキク"


@dataclass(frozen=True)
class Source:
    """出典。IPA の利用条件が求める4つを必ず持つ。"""

    year_label: str      # 例: 令和7年度
    exam: str            # EXAMS のキー
    number: int
    pdf_url: str
    #: 科目（FE の「科目A」など）。無い区分は空でよい。
    section: str = ""

    def __post_init__(self) -> None:
        if self.exam not in EXAMS:
            raise ValueError(f"試験区分が不明です: {self.exam!r}")
        for name in ("year_label", "pdf_url"):
            if not getattr(self, name):
                raise ValueError(f"出典に{name}がありません。出典なしでは公開できません")

    @property
    def exam_name(self) -> str:
        return EXAMS[self.exam]

    def text(self) -> str:
        """画面に出す出典の一文。"""
        section = f" {self.section}" if self.section else ""
        return f"{self.year_label} {self.exam_name}{section} 問{self.number}"


def question_page(question: Question, answer: str, explanation: str,
                  source: Source) -> str:
    """1問ぶんのページ。

    正解は最初から見せない。過去問サイトに来る人は**まず自分で解きたい**ので、
    開いた瞬間に答えが目に入ると、そのページの用が済んでしまう。
    JavaScript は使わない（`<details>` だけで足りる。切っていても読める）。
    """
    if question.needs_review:
        raise ValueError(
            f"問{question.number} は要確認（図={question.has_figure} "
            f"小さい文字={question.has_small_text}）。人が見るまで公開しない"
        )
    if answer not in _CHOICE_MARKS[:len(question.choices)]:
        raise ValueError(f"問{question.number}: 正解の記号が選択肢の範囲外です: {answer!r}")
    if not explanation.strip():
        raise ValueError(f"問{question.number}: 解説が空です")

    title = f"{source.text()}｜過去問と解説"
    items = "\n".join(
        _choice_html(mark, text, correct=(mark == answer))
        for mark, text in zip(_CHOICE_MARKS, question.choices)
    )
    return _TEMPLATE.format(
        title=html.escape(title),
        heading=html.escape(source.text()),
        exam_name=html.escape(source.exam_name),
        question=html.escape(question.text),
        choices=items,
        answer=html.escape(answer),
        explanation=_paragraphs(explanation),
        source=html.escape(source.text()),
        pdf_url=html.escape(source.pdf_url, quote=True),
    )


def _choice_html(mark: str, text: str, correct: bool) -> str:
    # 正解だけ class を変える。色だけで示すと、色が見えない人に伝わらないので
    # 「正解」の文字も併せて出す（details を開いたときだけ現れる）。
    cls = " class=\"correct\"" if correct else ""
    return f'  <li{cls}><b>{mark}</b> {html.escape(text)}</li>'


def _paragraphs(body: str) -> str:
    """空行で区切られた文章を段落にする。"""
    blocks = [b.strip() for b in body.strip().split("\n\n") if b.strip()]
    return "\n".join(f"<p>{html.escape(b)}</p>" for b in blocks)


_TEMPLATE = """<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="color-scheme" content="light dark">
<title>{title}</title>
<meta name="description" content="{heading} の問題文・正解・解説。出典は IPA の公開問題。">
<style>
  :root {{
    --bg: #f7f8fa; --card: #fff; --text: #1a1a1a; --muted: #6b7280;
    --line: #e5e7eb; --accent: #1f6f5c; --correct-bg: #eaf6f1;
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{
      --bg: #14161a; --card: #1b1e24; --text: #e6e8ea; --muted: #9aa3ad;
      --line: #2b313a; --accent: #5cbfa3; --correct-bg: #1d2b27;
    }}
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; background: var(--bg); color: var(--text); line-height: 1.75;
    font-family: "Hiragino Kaku Gothic ProN", "Yu Gothic", Meiryo, sans-serif;
  }}
  main {{ max-width: 720px; margin: 0 auto; padding: 1rem; }}
  .crumbs {{ font-size: .8rem; color: var(--muted); margin: .25rem 0 .75rem; }}
  .crumbs a {{ color: var(--muted); }}
  h1 {{ font-size: 1.25rem; line-height: 1.45; margin: .4rem 0 1rem; }}
  .card {{
    background: var(--card); border: 1px solid var(--line);
    border-radius: 8px; padding: 1rem 1.1rem; margin: 1rem 0;
  }}
  .question {{ font-size: 1.05rem; }}
  ol.choices {{ list-style: none; margin: 1rem 0 0; padding: 0; }}
  ol.choices li {{
    border: 1px solid var(--line); border-radius: 6px;
    padding: .6rem .8rem; margin: .5rem 0; background: var(--card);
  }}
  ol.choices li b {{ color: var(--accent); margin-right: .5rem; }}
  details {{ margin: 1rem 0; }}
  summary {{
    cursor: pointer; font-weight: bold; color: var(--accent);
    border: 1px solid var(--accent); border-radius: 6px;
    padding: .6rem .9rem; list-style: none; text-align: center;
  }}
  summary::-webkit-details-marker {{ display: none; }}
  details[open] summary {{ border-style: dashed; }}
  .answer {{ font-size: 1.1rem; font-weight: bold; margin: 1rem 0 .5rem; }}
  details ol.choices li.correct {{
    background: var(--correct-bg); border-color: var(--accent);
  }}
  details ol.choices li.correct::after {{
    content: "　← 正解"; color: var(--accent); font-weight: bold; font-size: .85rem;
  }}
  .source {{
    font-size: .85rem; color: var(--muted);
    border-top: 1px solid var(--line); margin-top: 2rem; padding-top: 1rem;
  }}
  .disclaimer {{ font-size: .8rem; color: var(--muted); margin-top: 1rem; }}
  a {{ color: var(--accent); }}
</style>
</head>
<body>
<main>
  <p class="crumbs"><a href="../">{exam_name}</a> ＞ {heading}</p>
  <h1>{heading}</h1>

  <div class="card question">
    <p>{question}</p>
    <ol class="choices">
{choices}
    </ol>
  </div>

  <details>
    <summary>正解と解説を見る</summary>
    <div class="card">
      <p class="answer">正解: {answer}</p>
      <ol class="choices">
{choices}
      </ol>
      {explanation}
    </div>
  </details>

  <p class="source">
    出典: {source}（独立行政法人情報処理推進機構）<br>
    問題文と正解は<a href="{pdf_url}" rel="noopener">公開されている PDF</a>から
    機械的に取り出したもので、改変していません。解説は当サイトが作成したものです。
  </p>
  <p class="disclaimer">
    本サイトは IPA および試験実施機関とは関係ありません。
    掲載内容の正確性を保証するものではなく、受験にあたっては必ず公式の発表をご確認ください。
  </p>
</main>
</body>
</html>
"""
