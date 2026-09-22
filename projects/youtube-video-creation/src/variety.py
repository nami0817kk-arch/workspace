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
# タイトルの結び方が揃ってよい上限
SAME_TAIL = 0.5
SAME_PREFIX = 0.5


def _skeleton(script: Script) -> tuple:
    """節の見出しの並び。オープニングとまとめは全本共通なので外す。"""
    return tuple(
        s.title for s in script.scenes
        if s.title not in ("オープニング", "まとめ")
    )


def _bare(title: str) -> str:
    """札と記号を落とす。結び方を比べるため。"""
    import re

    return re.sub(r"[\s。！!？?]", "", re.sub(r"【[^】]*】", "", title or ""))


# 言いさしで切る結び（「〜のは」「〜言葉は」）。**末尾の字面が違っても同じ形**
DANGLING = "はがをにともへで"


def _tail_kind(title: str) -> str:
    """結び方の形。末尾6字の一致では、言いさしの揃いを見落とした。

    2026-09-22 に7本中7本が「〜のは」「〜言葉は」で終わっていたのに、
    末尾の字面が1本ずつ違うので「散らばっています」と出た。
    **助詞で切っているなら、その助詞で1つにまとめる**
    """
    bare = _bare(title)
    if bare and bare[-1] in DANGLING:
        return f"〜{bare[-1]}（言いさし）"
    return bare[-6:]


# 本のあいだで重なってよい長さ。1本の中（8字）より長め。人名や大会名は重なって当然
CROSS_REPEAT_MIN = 10
NARRATORS = ("キャスター", "解説", "ナレーター")


def _cross_repeats(scripts: list[Script]) -> list[str]:
    """語りの行どうしで、10字以上続けて重なるところ。反応（他人の文）は見ない。"""
    import itertools
    import re

    def bare(text: str) -> str:
        # 句読点は空白に置き換える。消すと「勝ち点21。31点」が「2131点」に繋がる
        return re.sub(r"[「」『』*・]", "", re.sub(r"[。、！？!?\s　]+", " ", text or ""))

    def lines(script: Script) -> list[str]:
        return [bare(l.text) for sc in script.scenes for l in sc.lines
                if (getattr(l, "speaker", "") or "") in NARRATORS
                and (getattr(l, "only", "") or "") != "short"]

    # 同じ数字＋単位を2本で読んでいないか（「31得点7失点」）。research.NUMBER_TOKEN と同じ
    number = re.compile(r"\d[\d,.]*(?:万|億|点|ゴール|試合|本|人|回|位|歳|分|秒|月|日|戦|失点|得点|勝|敗|ユーロ|ポンド|円|%)")

    def numbers(script: Script) -> set[str]:
        # **偶然そろう数字は見ない**。クラブ紹介20本で「20点」「10人」が2本ずつ重なり、
        # 123か所になった。3桁以上か、金額・割合だけを見る（「1500万ユーロ」「63.5%」）
        found = {tok.replace("得点", "点") for text in lines(script) for tok in number.findall(text)}
        def digits(tok: str) -> int:
            return len(re.match(r"[\d,.]+", tok).group(0).replace(",", "").replace(".", ""))

        return {tok for tok in found
                if (digits(tok) >= 4
                    or (digits(tok) >= 2 and tok.endswith(("万", "億", "ユーロ", "ポンド", "円", "%"))))
                and not re.fullmatch(r"\d{4}年?", tok)}

    # **3本以上に出る言い回しは型の文**（2026-09-22）。プレミア20クラブ紹介は
    # 「リーグは5試合を終えて」「ミッドフィールダーは6人」を全本で読むので、
    # 対で数えると162か所になった。同じ日の7本でも、決まり文句は同じ。
    # 2本だけに出る重なりが、言い直し
    def windows(script: Script) -> set[str]:
        got: set[str] = set()
        for x in lines(script):
            for i in range(len(x) - CROSS_REPEAT_MIN + 1):
                g = x[i:i + CROSS_REPEAT_MIN]
                if re.search(r"[ぁ-ん]", re.sub(r"[のとやからまでにはがをでも]", "", g)):
                    got.add(g)
        return got

    per_script = [(s, lines(s), windows(s), numbers(s)) for s in scripts]
    count_w: dict[str, int] = {}
    count_n: dict[str, int] = {}
    for _, _, ws, ns in per_script:
        for w in ws:
            count_w[w] = count_w.get(w, 0) + 1
        for n in ns:
            count_n[n] = count_n.get(n, 0) + 1
    # 10本を超える並び（シリーズ）は決まり文句が多いので、長い重なりだけ見る
    least = CROSS_REPEAT_MIN if len(scripts) < 10 else CROSS_REPEAT_MIN + 6

    out: list[str] = []
    seen: set[str] = set()
    for (a, la, wa, na), (b, lb, wb, nb) in itertools.combinations(per_script, 2):
        for tok in sorted(na & nb):
            if count_n.get(tok, 0) == 2 and tok not in seen:
                seen.add(tok)
                out.append(f"『{tok}』（{_short_name(a)} と {_short_name(b)}）")
        if not (wa & wb):
            continue
        # 行どうしで、いちばん長く続けて重なる部分を1つ（窓を並べると1字ずつずれて何度も鳴る）
        for x in la:
            for y in lb:
                shared = _longest_common(x, y)
                if len(shared) < least or shared in seen:
                    continue
                if not re.search(r"[ぁ-ん]", re.sub(r"[のとやからまでにはがをでも]", "", shared)):
                    continue
                # 3本以上に出る言い回しを含むなら型の文
                if any(count_w.get(shared[i:i + CROSS_REPEAT_MIN], 0) >= 3
                       for i in range(len(shared) - CROSS_REPEAT_MIN + 1)):
                    continue
                seen.add(shared)
                out.append(f"『{shared}』（{_short_name(a)} と {_short_name(b)}）")
    return out


def _longest_common(left: str, right: str) -> str:
    best = ""
    for start in range(len(left)):
        for end in range(len(left), start + len(best), -1):
            if left[start:end] in right:
                best = left[start:end]
                break
    return best


def _short_name(script: Script) -> str:
    return str((script.meta or {}).get("title") or script.title or "")[:12]


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

    # **タイトルの結び方が揃っていないか**（2026-09-08 ユーザー指摘）。
    # 9本中7本が「〜がこちらです」で終わっていた。1本ずつの点検は
    # 「答えを隠しているか」しか見ないので、**並べないと気づけない**
    tails = Counter(_tail_kind(s.title) for s in scripts if _bare(s.title))
    top_tail, tail_share = _share(tails, total)
    if tail_share > SAME_TAIL:
        findings.append(Finding(
            False, "結び方",
            f"{int(tail_share * total)}本が『…{top_tail}』で終わっています。"
            "毎回同じ結び方だと、一覧で見分けが付きません"))
    else:
        findings.append(Finding(True, "結び方", "結び方は散らばっています"))

    # **本と本のあいだで同じことを言っていないか**（2026-09-22）。
    # ラフィーニャとシメオネの回が、どちらも「バルセロナは7戦全勝、31得点7失点」を
    # 読んでいた。同じ日に出すので、続けて見た人には二度聞こえる。
    # 1本の中の重複は draft が見るが、本のあいだは並べないと見えない
    crossed = _cross_repeats(scripts)
    if crossed:
        findings.append(Finding(
            False, "本のあいだ",
            f"{len(crossed)}か所で同じことを言っています。最初の1つ: {crossed[0]}"))
    else:
        findings.append(Finding(True, "本のあいだ", "本どうしで同じ話は重なっていません"))

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
