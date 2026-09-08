"""その日の台本を**横に並べて**見る点検。

`review` は1本ずつしか見ない。だから**個々は正常なのに、並べると異常**という
型は構造上ひとつも拾えなかった。実際 2026-09-06 に11本を作り、
9本が「何が起きたか」で始まり7本が「これからどうなる」で終わっていたが、
review は11本すべて合格を出していた。**検査の粒度が、見つけられる問題の
種類を決めている。**

1本ずつ見て分かるのは「壊れているか」。並べて分かるのは「似すぎていないか」。
"""

from __future__ import annotations

from collections import Counter

from .review import Finding
from .script_model import Script

# 同じ形がこの割合を超えたら知らせる。3本に1本までは同じ形でよい
# （型が5つあるので、11本なら2〜3本ずつ同じ形になるのが自然）
SAME_SHAPE = 0.34
# 同じ接頭辞（【速報】など）がこの割合を超えたら知らせる
# 札が付いている本数の上限。半分を超えたら知らせる
BADGE_SHARE = 0.5
SAME_PREFIX = 0.5


def _skeleton(script: Script) -> tuple:
    """節の見出しの並び。オープニングとまとめは全本共通なので外す。"""
    return tuple(
        s.title for s in script.scenes
        if s.title not in ("オープニング", "まとめ")
    )


def _prefix(script: Script) -> str:
    title = str((script.meta or {}).get("title") or "").strip()
    if title.startswith("【") and "】" in title:
        return title[1:title.index("】")]
    return ""


def _opening(script: Script) -> str:
    """最初に読む1文。ここが毎回同じだと、開いた瞬間に同じ番組に見える。"""
    for scene in script.scenes:
        for line in scene.lines:
            text = (getattr(line, "text", "") or "").strip()
            if text:
                return text[:12]
    return ""


NARRATORS = ("キャスター", "解説", "ナレーター")


def _spoken_for(script: Script) -> tuple[int, int]:
    """(引用カードの数, 代弁で読ませた発言の数)。

    **決まりはキャスター1人で説明し、誰かの発言のときだけ別の声**
    （2026-09-06 ユーザー）。だから話者が1人でも正しい回はある。
    見るのは人数ではなく、**引用を本人の声で読ませているか**。
    キャスターが「〇〇はこう話しました」と地の文で読むだけでは、
    せっかくの代弁が効かない。
    """
    quotes = sum(
        1 for spec in (script.cards or {}).values()
        if str((spec or {}).get("type", "")).lower() == "quote")
    voiced = len({
        (getattr(line, "speaker", "") or "").strip()
        for scene in script.scenes for line in scene.lines
        if (getattr(line, "speaker", "") or "").strip() not in NARRATORS
        and (getattr(line, "speaker", "") or "").strip()})
    return quotes, voiced


def _share(counts: Counter, total: int) -> tuple[object, float]:
    if not counts:
        return None, 0.0
    top, hits = counts.most_common(1)[0]
    return top, hits / total


def inspect_day(scripts: list[Script]) -> list[Finding]:
    """その日ぶんをまとめて見る。**1本では分からないことだけ**を見る。"""
    total = len(scripts)
    if total < 2:
        return [Finding(True, "並べて点検", "2本以上でないと比べられません")]

    findings: list[Finding] = []

    # **並び全体ではなく、最初と最後を見る。**節の名前は回ごとに書き換えるので
    # 三つ組が丸ごと一致することは少ない。実際に問題として出たのは
    # 「9本が『何が起きたか』で始まり、7本が『これからどうなる』で終わる」
    # という**入口と出口の一致**だった（2026-09-06）
    for label, pick in (("入り方", lambda s: _skeleton(s)[:1]),
                        ("締め方", lambda s: _skeleton(s)[-1:])):
        counts = Counter(pick(s) for s in scripts if pick(s))
        top, share = _share(counts, total)
        if share > SAME_SHAPE:
            findings.append(Finding(
                False, label,
                f"{total}本中{int(share * total)}本が「{top[0]}」です。"
                "--shape で型を分けてください"))
        else:
            findings.append(Finding(
                True, label,
                f"いちばん多いもので{int(share * total)}本"))

    shapes = Counter(_skeleton(s) for s in scripts)
    top, share = _share(shapes, total)
    if share > SAME_SHAPE:
        findings.append(Finding(
            False, "話の型",
            f"{int(share * total)}本が同じ並びです（{' → '.join(top[:3])}）"))
    else:
        findings.append(Finding(True, "話の型", f"同じ並びは最大{int(share * total)}本"))

    starts = Counter(_opening(s) for s in scripts if _opening(s))
    top, share = _share(starts, total)
    if share > SAME_SHAPE:
        findings.append(Finding(
            False, "出だし",
            f"{int(share * total)}本が同じ書き出しです（「{top}…」）"))
    else:
        findings.append(Finding(True, "出だし", "書き出しは散らばっています"))

    # **札は毎回付けない**（2026-09-08 ユーザー指示）。付いている本数そのものを見る
    with_badge = [s for s in scripts if _prefix(s)]
    if total and len(with_badge) / total > BADGE_SHARE:
        findings.append(Finding(
            False, "札の数",
            f"{len(with_badge)}/{total}本に【】が付いています。"
            "毎回付けると一覧で効かなくなります"))
    else:
        findings.append(Finding(
            True, "札の数", f"【】は{len(with_badge)}/{total}本です"))

    prefixes = Counter(p for p in (_prefix(s) for s in scripts) if p)
    top, share = _share(prefixes, total)
    if share > SAME_PREFIX:
        findings.append(Finding(
            False, "接頭辞",
            f"{int(share * total)}本が【{top}】です。全部が速報だと速報に見えません"))
    else:
        findings.append(Finding(True, "接頭辞", "偏っていません"))

    # **人数は見ない。**キャスター1人で説明する回は正しい。
    # 見るのは「引用カードを出しているのに、本人の声で読ませていないか」
    silent = []
    for script in scripts:
        quotes, voiced = _spoken_for(script)
        if quotes and not voiced:
            silent.append(script)
    if silent:
        names = ", ".join(str((s.meta or {}).get("title") or "")[:16] for s in silent[:3])
        findings.append(Finding(
            False, "代弁",
            f"{len(silent)}本が、引用を出しているのに本人の声で読ませていません"
            f"（{names}）"))
    else:
        findings.append(Finding(True, "代弁", "引用は本人の声で読ませています"))

    return findings
