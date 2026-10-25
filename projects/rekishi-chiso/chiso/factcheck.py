"""台本と事実カードの突き合わせ（10-26）。

台本の書き方：
- 一番上に `facts: 伊達政宗_facts_20261026.yaml`（research/ の中の名前か、絶対パス）
- 事実を言う行に、行の上のコメントか行末のコメントで `# fact: masamune-03`（複数は `# fact: masamune-03, masamune-07`）
- カードがまだ無いが「知らない事実」として書いた行は `# fact: ?`（点検で「カードにつながっていない」と出る）

点検（「事実：」で出す。どれも ! 止まりで台本は止めない）：
 ① `# fact: ?` の行・カードに無い ID
 ② つながる事実が「本文を開いた」「出どころ2つ以上」のどちらでもないのに、行が「と伝わる」の言い方になっていない
 ③ 冒頭3分の知らない事実（知らない度が中・高のカード）が7個以上・各1分に2個以上か（docs/story-main.md の「0.」）
カードの YAML も `# fact:` も無い台本（scripts/oichi-story.yaml など）は何もしない。
"""
from __future__ import annotations

import re
from pathlib import Path

import yaml

from .voice import display_text

CHARS_PER_SEC = 7.0
GAP = 0.6                     # 行のあいだの間（check.pacing と同じ目安）
OPEN_SEC = 180.0
OPEN_MIN = 7
PER_MIN = 2
HEDGES = ("と伝わ", "といわれ", "と言われ", "とされ", "という話", "といいます", "と書かれ", "とあります", "という説", "記録には")
SPEAKERS = ("語り", "聞き", "人物", "二人")
_ITEM = re.compile(r"^(\s*)-\s+(" + "|".join(SPEAKERS) + r")\s*:")
_FACT = re.compile(r"#\s*fact\s*:\s*([^#\n]+)")


def fact_links(text: str) -> dict[int, list[str]]:
    """台本の YAML の文字から {行の番号: [ID]}。sections の中の話者の行（`- 語り:` など）を数える。
    行の上のコメント（行と同じ字下げ）・行末のコメント・行の中のコメント（字下げが深い）を、その行につなぐ。"""
    links: dict[int, list[str]] = {}
    pending: list[str] = []
    cur, cur_indent = -1, -1
    in_sections = False
    n = -1
    for raw in text.splitlines():
        if re.match(r"^sections\s*:", raw):
            in_sections = True
            continue
        if in_sections and re.match(r"^[A-Za-z_]\w*\s*:", raw):
            in_sections = False
        if not in_sections:
            continue
        m = _ITEM.match(raw)
        f = _FACT.search(raw)
        ids = [x.strip() for x in f.group(1).split(",") if x.strip()] if f else []
        if m:
            n += 1
            cur, cur_indent = n, len(m.group(1))
            got = pending + ids
            pending = []
            if got:
                links.setdefault(cur, []).extend(got)
            continue
        if ids:
            indent = len(raw) - len(raw.lstrip())
            is_comment = raw.lstrip().startswith("#")
            if cur >= 0 and (indent > cur_indent or not is_comment):
                links.setdefault(cur, []).extend(ids)       # 行の中のコメント・キーの行末
            else:
                pending += ids                              # 次の行の上のコメント
    return links


def cards_path(text: str, research_dir: Path) -> Path | None:
    m = re.search(r"^facts\s*:\s*[\"']?([^\"'#\n]+?)[\"']?\s*(?:#.*)?$", text, re.M)
    name = m.group(1).strip() if m else ""
    if not name:
        return None
    p = Path(name)
    return p if p.is_absolute() else research_dir / name


def load_cards(path: Path) -> dict[str, dict]:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return {str(f["id"]): f for f in data.get("facts", [])}


def starts(script) -> list[float]:
    """行ごとの始まりの秒（字数÷7字／秒＋間の目安）。"""
    t, out = 0.0, []
    for line in script.lines:
        out.append(t)
        t += len(display_text(line.text)) / CHARS_PER_SEC + GAP
    return out


def check(script, text: str, research_dir: Path) -> list[str]:
    links = fact_links(text)
    path = cards_path(text, research_dir)
    if not links and path is None:
        return []
    warns: list[str] = []
    cards: dict[str, dict] = {}
    if path is not None:
        if path.exists():
            cards = load_cards(path)
        else:
            warns.append(f"事実：カードの YAML が見つかりません（{path.name}）。research --cards で作るか、facts: を直す（カードの中身は見ずに数えます）")
    elif links:
        warns.append("事実：`# fact:` はあるが、台本の一番上に facts:（カードの YAML）がありません")
    t0 = starts(script)
    lines = script.lines
    unknown_rows: list[float] = []
    for idx, ids in sorted(links.items()):
        if idx >= len(lines):
            continue
        row = f"{idx + 1}行目"
        line_text = display_text(lines[idx].text)
        for fid in ids:
            if fid == "?":
                warns.append(f"事実：{row} が事実カードにつながっていません（# fact: ?）")
                unknown_rows.append(t0[idx])
                continue
            card = cards.get(fid)
            if card is None:
                if cards:
                    warns.append(f"事実：{row} の {fid} がカードにありません")
                continue
            strong = bool(card.get("opened_body")) or int(card.get("independent", 0)) >= 2
            if not strong and not any(h in line_text for h in HEDGES):
                warns.append(f"事実：{row} の {fid} は本文を開いておらず出どころも{card.get('independent', 0)}つだけ。"
                             f"「と伝わります」の言い方にするか、出どころをもう1つ探す")
            if card.get("unknown") in ("中", "高"):
                unknown_rows.append(t0[idx])
    if links:
        opening = [t for t in unknown_rows if t < OPEN_SEC]
        per = [sum(1 for t in opening if m * 60 <= t < (m + 1) * 60) for m in range(3)]
        mark = "" if len(opening) >= OPEN_MIN and all(p >= PER_MIN for p in per) else "足りない："
        warns.append(f"事実：{mark}冒頭3分の知らない事実 {len(opening)}個（目安{OPEN_MIN}個以上）・1分ごと "
                     + "／".join(f"{m}分台 {p}個" for m, p in enumerate(per)) + f"（目安 各{PER_MIN}個以上）")
    return warns


def summary(script, text: str, research_dir: Path) -> list[str]:
    """CLI の fact-check 用：つながりの一覧（行・ID・主張・独立・本文・知らない度）。"""
    links = fact_links(text)
    path = cards_path(text, research_dir)
    cards = load_cards(path) if path and path.exists() else {}
    t0 = starts(script)
    out = []
    for idx, ids in sorted(links.items()):
        for fid in ids:
            c = cards.get(fid, {})
            out.append(f"{int(t0[idx] // 60)}:{int(t0[idx] % 60):02d} {idx + 1}行目 {fid} "
                       f"独立{c.get('independent', '?')} 本文{'○' if c.get('opened_body') else '×'} "
                       f"知らない度{c.get('unknown', '?')} {str(c.get('claim', ''))[:30]}")
    return out
