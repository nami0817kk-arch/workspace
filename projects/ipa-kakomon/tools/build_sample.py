"""1問ぶんの完成形を1枚だけ書き出す（見せて判断してもらうためのもの）。

サイト全体の生成はまだ無い。**形を先に見てから作る**ため、
実物の PDF から1問を通しで組み立てるところまでを、この1本で確かめられるようにした。

    python tools/build_sample.py <PDFを置いたディレクトリ> [出力先]
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

import answers   # noqa: E402
import questions  # noqa: E402
import pages  # noqa: E402

BASE = "2025r07_sg"
PDF_URL = (
    "https://www.ipa.go.jp/shiken/mondai-kaiotu/sg_fe/koukai/"
    "tbl5kb0000005r9r-att/2025r07_sg_qs.pdf"
)

# 解説は人（または Claude）が書く。ここは見本の1問ぶん。
# **公式の正解と矛盾していないかを機械で検査する**仕組みは別途入れる。
EXPLANATION = """\
JIS Q 31000:2019 は，リスクマネジメントのプロセスを「リスク特定」「リスク分析」
「リスク評価」「リスク対応」などの活動に分けて定義している。この問題は，
それぞれの活動の意義を取り違えていないかを問うている。

正解のエは，リスク分析の説明そのものである。リスク分析は，リスクの性質と特徴を
理解し，必要に応じてリスクのレベル（起こりやすさと結果の組合せ）を定める活動を指す。

アは，リスク対応の説明ではなく「モニタリング及びレビュー」の説明になっている。
プロセスの設計・実施・結末の質および効果を保証し改善するのは，監視と見直しの役割である。

イは，リスク特定ではなくリスク対応の説明。選択肢を選定して実施するのは，
特定されたリスクにどう手を打つかを決める段階の活動である。

ウは，リスク評価ではなくリスク特定の説明。リスクを発見し，認識し，記述するのが
リスク特定で，リスク評価はその結果を基準と比べて対応が必要かどうかを決める活動である。
"""


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    pdf_dir = Path(sys.argv[1])
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("output/sample.html")

    qs = questions.extract(pdf_dir / f"{BASE}_qs.pdf")
    ans = {a.number: a.choice for a in answers.extract(pdf_dir / f"{BASE}_ans.pdf")}

    target = qs[0]
    source = pages.Source(
        year_label="令和7年度", exam="sg", number=target.number, pdf_url=PDF_URL
    )
    html = pages.question_page(target, ans[target.number], EXPLANATION, source)

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")

    review = [q.number for q in qs if q.needs_review]
    print(f"{out} を書きました（{len(qs)}問中1問）")
    print(f"要確認の問: {review}（この見本には出していない）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
