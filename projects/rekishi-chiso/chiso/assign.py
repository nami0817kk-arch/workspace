"""絵の割り当ての下書き（10-07）。

    python -m chiso.cli assign scripts/x.yaml --assets research/x_assets.md

絵の一覧（research の *_assets.md。表に「ファイル名」「何か」「台本で合う場面」の列がある）と台本の各行を照らし、
どの行の頭でどの絵に替えるかの下書きを out/x_assign.md に出す。台本は書き換えない（決めるのは人）。

照らし方は語の一致の点数だけ（外部の AI は使わない）:
  - 絵の「何か」「台本で合う場面」から、年（1804）・カタカナの語（ナポレオン・ジョゼフィーヌ）・漢字の語（戴冠・遺骸）を取り出す
  - 行のせりふ・札・節の題にその語があれば点。多くの絵に出てくる語（主人公の名前など）は点を下げる（idf）
  - 年は「台本で合う場面」「何か」の中の年（描かれた出来事の年）だけを使う。「年」の列は描いた年なので使わない
同じ背景が40秒を超えそうになったら、次に点の高い別の絵か、無ければ「絵の一部を大きく（detail）」を候補に出す。
"""
from __future__ import annotations

import math
import re
from dataclasses import dataclass, field
from pathlib import Path

from .voice import display_text

from .check import BG_MAX_SEC, CHARS_PER_SEC  # noqa: E402  check.pacing と同じ目安
MIN_HOLD_SEC = 15.0        # 替えたばかりの絵は、これより短くは替えない（目がうるさくなる。節の頭は別）
SWITCH_SCORE = 3.0         # これ以上の点で、いまの絵より MARGIN 以上よく合う絵があれば替える
MARGIN = 1.0
STRONG_SCORE = 6.0         # これ以上よく合う絵（戴冠式・ノートルダム・1804年がそろう等）は、替えたばかりでも替える
ALT_SCORE = 1.5            # 40秒を超えるときの「次に合う絵」の最低点。これより低ければ detail を勧める
YEAR_POINTS = 1.5          # 出来事の年が合ったときの点
SECTION_WEIGHT = 0.5       # 節の題の一致は半分に数える
STOP = {"場面", "肖像", "全身", "全身像", "半身像", "正面", "正面像", "白黒", "版画", "石版", "石版画", "銅版画", "背景",
        "手前", "右奥", "左奥", "後ろ", "対比", "前後", "頂点", "図版", "縮小", "直前", "直後", "一面", "結び", "暮らし",
        "台本", "描写", "引き", "構図", "横長", "縦長", "彩色", "手彩色", "原図", "所蔵", "作品"}


@dataclass
class Asset:
    file: str
    what: str = ""
    scene: str = ""
    tokens: set = field(default_factory=set)
    years: set = field(default_factory=set)


def parse_assets(md: str) -> list[Asset]:
    """*_assets.md の表を読む。「ファイル名」の列がある表の行だけ。"""
    out, cols = [], None
    for raw in md.splitlines():
        line = raw.strip()
        if not line.startswith("|"):
            cols = None if not line else cols
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if cols is None:
            if "ファイル名" in cells:
                cols = {name: i for i, name in enumerate(cells)}
            continue
        if set(line) <= set("|-: "):
            continue
        get = lambda k: cells[cols[k]] if k in cols and cols[k] < len(cells) else ""
        file = get("ファイル名").strip("`")
        if not file:
            continue
        a = Asset(file=file, what=get("何か"), scene=get("台本で合う場面"))
        text = f"{a.what} {a.scene}"
        a.tokens = words(text)
        a.years = years(text)
        out.append(a)
    return out


def words(text: str) -> set[str]:
    """年以外の語：カタカナ3字以上（・＝で分ける）・漢字2字以上（3字以上は2字ずつの並びも）。"""
    out = set()
    for k in re.findall(r"[ァ-ヴー]{3,}", text):
        out.add(k)
    for k in re.findall(r"[一-鿿々]{2,}", text):
        out.add(k)
        if len(k) >= 3:
            out.update(k[i:i + 2] for i in range(len(k) - 1))
    return {w for w in out if w not in STOP and not re.fullmatch(r"[一二三四五六七八九十百千]+", w)}


def years(text: str) -> set[int]:
    """出来事の年（3〜4桁＋「年」、または「1805〜1807」「1796-97」の範囲）。"""
    out = set()
    for a, b in re.findall(r"(\d{4})\s*[-〜～]\s*(\d{2,4})(?!\d)", text):
        lo = int(a)
        hi = int(b) if len(b) == 4 else int(a[:2] + b)
        if 0 <= hi - lo <= 15:
            out.update(range(lo, hi + 1))
    out.update(int(y) for y in re.findall(r"(\d{3,4})年", text))
    return out


def idf(assets: list[Asset]) -> dict[str, float]:
    n = len(assets) or 1
    df: dict[str, int] = {}
    for a in assets:
        for t in a.tokens:
            df[t] = df.get(t, 0) + 1
    return {t: math.log((n + 1) / (c + 0.5)) for t, c in df.items()}


def line_text(line) -> str:
    card = f" {line.card.head} {line.card.body}" if getattr(line, "card", None) is not None else ""
    return display_text(line.text) + card


def score(asset: Asset, text: str, line_years: set[int], weights: dict[str, float]) -> tuple[float, list[str]]:
    """一致した語の点の和。長い語が合ったら、その中の2字の並び（戴冠式の中の戴冠・冠式）は数えない。"""
    pts, why = 0.0, []
    for t in sorted((t for t in asset.tokens if t in text), key=len, reverse=True):
        if any(t in w for w in why):
            continue
        w = weights.get(t, 1.0) * (1.5 if len(t) >= 3 else 1.0)
        if w > 0:
            pts += w
            why.append(t)
    hit = sorted(asset.years & line_years)
    if hit:
        pts += YEAR_POINTS
        why.append(f"{hit[0]}年")
    return pts, why


@dataclass
class Pick:
    line: object
    start: float
    file: str
    reason: str
    detail: bool = False


def draft(script, assets: list[Asset]) -> list[Pick]:
    weights = idf(assets)
    picks: list[Pick] = []
    cur, held, t, sec = None, 0.0, 0.0, None
    recent: list[str] = []
    for line in script.lines:
        sec_title = script.sections[line.section].title if script.sections else ""
        text = line_text(line)
        ly = set(int(y) for y in re.findall(r"(\d{3,4})年", text))
        if getattr(line, "year", None):
            ly.add(int(line.year))
        ranked = []
        for a in assets:
            s, why = score(a, text, ly, weights)
            s2, why2 = score(a, sec_title, set(), weights)
            total = s + SECTION_WEIGHT * s2
            if total > 0:
                ranked.append((total, a.file, why + [f"節の題「{w}」" for w in why2 if w not in why]))
        ranked.sort(key=lambda r: -r[0])
        dur = len(display_text(line.text)) / CHARS_PER_SEC + 0.6
        new_section = line.section != sec
        sec = line.section
        best = ranked[0] if ranked else None
        cur_pts = next((r[0] for r in ranked if r[1] == cur), 0.0)
        better = best and best[1] != cur and best[0] >= SWITCH_SCORE and best[0] >= cur_pts + MARGIN
        if best and best[1] != cur and (cur is None or (new_section and best[0] >= ALT_SCORE)
                                        or (better and (held >= MIN_HOLD_SEC or best[0] >= STRONG_SCORE))):
            picks.append(Pick(line, t, best[1], f"{best[0]:.1f}点：" + "・".join(best[2][:5])))
            cur, held = best[1], 0.0
            recent = (recent + [best[1]])[-3:]
        elif cur is not None and held + dur > BG_MAX_SEC:
            alt = next((r for r in ranked if r[1] != cur and r[1] not in recent and r[0] >= ALT_SCORE), None)
            if alt:
                picks.append(Pick(line, t, alt[1], f"同じ絵が{BG_MAX_SEC:.0f}秒を超えるので次に合う絵（{alt[0]:.1f}点：" + "・".join(alt[2][:4]) + "）"))
                cur = alt[1]
                recent = (recent + [alt[1]])[-3:]
            else:
                picks.append(Pick(line, t, cur, f"同じ絵が{BG_MAX_SEC:.0f}秒を超える。合う絵が無いので、この絵の一部を大きく（detail）", detail=True))
            held = 0.0
        held += dur
        t += dur
    return picks


def _mmss(s: float) -> str:
    return f"{int(s // 60)}:{int(s % 60):02d}"


def report(script, assets: list[Asset], picks: list[Pick]) -> str:
    used = {p.file for p in picks}
    unused = [a.file for a in assets if a.file not in used]
    cur_bgs = {Path(l.background.image).name for l in script.lines if getattr(l, "background", None)}
    lines = [f"# 絵の割り当ての下書き：{script.title}", "",
             f"絵 {len(assets)} 枚のうち {len(used)} 枚を使う案。替える所 {len(picks)} か所"
             f"（うち「絵の一部を大きく」{sum(p.detail for p in picks)} か所）。台本は書き換えていない。", "",
             "照らし方：年・カタカナの語・漢字の語の一致の点数（主人公の名前のように多くの絵に出る語は軽く）。"
             "時刻は字数からの見積もり（7字／秒）。", "",
             "| 行 | 時刻 | 話者 | せりふの頭 | 絵 | いまの背景 | 理由 |", "|---:|---|---|---|---|---|---|"]
    for p in picks:
        head = display_text(p.line.text)[:22].replace("|", "｜")
        now = Path(p.line.background.image).name if getattr(p.line, "background", None) else "—"
        pic = ("detail: " if p.detail else "") + p.file
        lines.append(f"| {p.line.index + 1} | {_mmss(p.start)} | {p.line.speaker} | {head} | {pic} | {now} | {p.reason} |")
    if unused:
        lines += ["", "## 使わなかった絵", ""] + [f"- {f}（いまの台本では{'使っている' if f in cur_bgs else '使っていない'}）" for f in unused]
    return "\n".join(lines) + "\n"
