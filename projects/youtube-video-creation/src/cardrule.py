"""カードを入れる基準。

**それまでは勘で決めていた。**回によって4〜7枚とばらつき、
「なぜここに表を出すのか」を言葉にできなかった（2026-09-07）。

文が何をしているかで、出すカードを決める。判断の余地を残すと、
書く人（いまは私）の気分で変わる。
"""

from __future__ import annotations

# 誰かの発言。**引用が主役の回はいちばん強い**（実測: 残った場面は全部これ）
QUOTE_MARKS = ("「", "」", "と話し", "と語", "と述べ", "とコメント", "と伝え")
# 数の比較。棒で並べると、差がそのまま絵になる
BAR_MARKS = ("倍", "対して", "に対し", "％", "%", "パーセント", "上回", "下回")
# 時系列・並び。表にすると、順番が追える
TABLE_MARKS = ("分に", "分、", "節", "順", "そのあと", "続いて", "得点の流れ")
# 整理・列挙
POINT_MARKS = ("つあり", "つの", "まず", "ひとつ", "ふたつ", "以下の", "並べる")

# 画面が変わらない時間の上限（秒）。**20秒では長すぎた**ので詰める
SAME_LOOK_MAX = 8.0


def suggest(text: str, voice: str = "") -> str:
    """その文に合うカードの型。無ければ空。

    **順番に意味がある。**発言がいちばん強いので先に見る。
    """
    body = str(text or "")
    if voice and voice not in ("キャスター", "解説", "ナレーター"):
        return "quote"          # 代弁の行は、その人の言葉
    if any(m in body for m in QUOTE_MARKS):
        return "quote"
    # **数のかたまりを数える。**桁数ではなく「いくつ数字が出てくるか」。
    # 「8本、3.16、0」を桁で数えると4になり、閾値の意味がずれる（実測）
    import re

    numbers = re.findall(r"[0-9]+(?:[.,][0-9]+)?", body)
    if any(m in body for m in TABLE_MARKS) and len(numbers) >= 2:
        return "table"          # 時系列は表。棒より先に見る
    if len(numbers) >= 3 or (len(numbers) >= 2 and any(m in body for m in BAR_MARKS)):
        return "bars"           # 3つ以上並べば、それだけで比較になる
    if any(m in body for m in POINT_MARKS):
        return "points"
    return ""


def gaps(script) -> list[tuple[float, str]]:
    """見た目が変わらないまま続いた区間。(秒数, そのときのテロップ)。

    review の「見た目の変化」と同じ考え方だが、**上限が違う**。
    あちらは本編向けの20秒、こちらはカードを足す判断のための8秒。
    """
    out = []
    look = None
    span = 0.0
    telop = ""
    for scene in script.scenes:
        for line in scene.lines:
            now = (getattr(line, "telop", None) or "",
                   getattr(line, "card", None) or "",
                   getattr(line, "image", None) or "")
            length = line.duration or line.estimated_duration()
            if now == look:
                span += length
            else:
                if span > SAME_LOOK_MAX:
                    out.append((span, telop))
                look, span, telop = now, length, now[0]
    if span > SAME_LOOK_MAX:
        out.append((span, telop))
    return out
