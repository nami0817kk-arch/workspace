# -*- coding: utf-8 -*-
"""ユーザーに見せるページを作る（2026-09-22、別セッションからも同じ形で出せるように）。

    python tools/pages.py topics <日付> <候補.yaml>     # ○△✖ を押せる題材の一覧
    python tools/pages.py scripts <日付> [--images]      # その日の台本を1枚に（読み上げ全文・板・写真の名前）

出力は output/pages/topics_<日付>/index.html と output/pages/scripts_<日付>/index.html。
それを Artifact として出す（題材ページは `capabilities: {db: {}}` を付けると ○△✖ が保存される）。
**同じ日のページは同じURLへ出し直す**（CLAUDE.md「見せる前の決まり」）。

候補.yaml の形:
    title: 9月22日の題材
    lead: 候補537件から22件
    note: |
      昨日の試合はありません。…（HTML可）
    items:
      - num: 1
        slot: 日本人            # 日本人／海外／プレミア／ラ・リーガ／ロマーノ …
        head: 見出し
        why: 出す理由（**太字**可）
        src: 出典の説明（媒体名・何時間前）
        url: https://…
        fmt: news              # news／voices／quote
        weak: true             # 弱い（出典1本・同じ選手が続く など）
        new: true              # 差し替え候補
    drops:
      - [落とした候補, 理由]
"""
from __future__ import annotations

import base64
import html
import io
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from pick_block import PICK_CSS, PICK_JS  # noqa: E402

e = html.escape

sys.path.insert(0, str(ROOT))
from src.script_model import BASE_SECONDS, MIN_SECONDS, SECONDS_PER_CHAR  # noqa: E402

# 見積りと実尺のずれ（直近の実測で 0.92〜1.07）。**分どまりで出す**ので丸めに吸わせる
BARE = re.compile(r"\*\*|[（(].*?[）)]")


def say_seconds(text: str) -> float:
    """1行の読み上げの見積り。script_model と同じ式。"""
    return max(MIN_SECONDS, BASE_SECONDS + len(BARE.sub("", text)) * SECONDS_PER_CHAR)


def real_seconds(stem: str) -> float | None:
    """書き出し済みなら実尺を返す（見積りより、こちらが正しい）。"""
    import json
    meta = ROOT / "output" / stem / "script.json"
    if not meta.exists():
        return None
    try:
        data = json.loads(meta.read_text(encoding="utf-8"))
    except Exception:
        return None
    total = 0.0
    for scene in data.get("scenes", []):
        for line in scene.get("lines", []):
            total += float(line.get("duration") or 0.0)
    return total or None


def mmss(seconds: float) -> str:
    m, sec = divmod(int(round(seconds)), 60)
    return f"{m}分{sec:02d}秒"

BASE_CSS = """
:root{--paper:#f5f4f1;--panel:#fff;--ink:#1c1b19;--ink-soft:#4a4842;--ink-faint:#8a867e;
      --line:#e2ded6;--pitch:#1f7a5a;--bg:#f5f4f1;--fg:#1c1b19;--mut:#6b6862;--card:#fff;--acc:#a8321f;--hi:#1f7a5a}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]){
      --paper:#14120f;--panel:#1f1c17;--ink:#efece4;--ink-soft:#c9c3b8;--ink-faint:#9d9689;
      --line:#332f27;--pitch:#5fd6a8;--bg:#14120f;--fg:#efece4;--mut:#9d9689;--card:#1f1c17;--acc:#e8a08c;--hi:#5fd6a8}}
:root[data-theme=dark]{--paper:#14120f;--panel:#1f1c17;--ink:#efece4;--ink-soft:#c9c3b8;
      --ink-faint:#9d9689;--line:#332f27;--pitch:#5fd6a8;--bg:#14120f;--fg:#efece4;
      --mut:#9d9689;--card:#1f1c17;--acc:#e8a08c;--hi:#5fd6a8}
body{background:var(--bg);color:var(--fg);font:15px/1.8 "Hiragino Sans","Noto Sans JP",system-ui,sans-serif;padding-inline:16px;padding-block:20px 80px}
main{max-width:780px;margin:0 auto}
h1{font-size:1.4rem;margin:0 0 .2rem;color:var(--acc)} .lead{color:var(--mut);font-size:.88rem;margin:0 0 14px}
.note{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 14px;font-size:.86rem;margin-bottom:16px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px 16px;margin:12px 0}
.card h3{font-size:1rem;margin:0 0 .3rem;line-height:1.5}
.card .num{display:inline-block;min-width:1.6em;color:var(--mut);font-weight:400}
.meta{font-size:.76rem;margin:.1rem 0 .5rem;display:flex;gap:7px;align-items:center;flex-wrap:wrap} .meta a{color:var(--mut)}
.slot{border:1px solid var(--line);border-radius:99px;padding:0 8px;color:var(--mut)}
.fmt{border:1px solid #1f7a5a;color:#1f7a5a;border-radius:99px;padding:0 8px}
.fresh{border:1px solid #a8761b;color:#a8761b;border-radius:99px;padding:0 8px}
.weak{border:1px solid var(--acc);color:var(--acc);border-radius:99px;padding:0 8px}
.card p{margin:.3rem 0;font-size:.92rem} ul{font-size:.86rem;color:var(--mut)} li{margin:.3rem 0}
details{background:var(--card);border:1px solid var(--line);border-radius:10px;margin:12px 0;padding:0 16px}
summary{cursor:pointer;display:flex;gap:10px;align-items:baseline;padding:12px 0;font-weight:600}
summary .t{flex:1} summary .d{color:var(--mut);font-weight:400;font-size:.85rem;white-space:nowrap}
section{border-top:1px solid var(--line);padding:10px 0} h3.sec{font-size:1rem;margin:0;color:var(--acc)}
.tag{font-size:.72rem;color:var(--hi);border:1px solid var(--hi);border-radius:99px;padding:0 7px;margin-left:6px}
ol{padding-left:1.3rem;margin:.4rem 0} ol li{margin:.2rem 0;color:var(--fg)} li.so{color:var(--mut)}
.im{font-size:.7rem;color:var(--mut);border:1px solid var(--line);border-radius:4px;padding:0 5px;margin-left:4px;white-space:nowrap}
.tbl{overflow-x:auto} table{border-collapse:collapse;font-size:.83rem;margin:.4rem 0} td,th{border:1px solid var(--line);padding:2px 8px;text-align:left;font-variant-numeric:tabular-nums}
.src{font-size:.75rem;color:var(--mut);word-break:break-all;border-top:1px solid var(--line);padding:8px 0}
figure{margin:.5rem 0 .2rem;max-width:420px} figure.thumb{max-width:640px}
figure img{width:100%;height:auto;border-radius:6px;border:1px solid var(--line);background:#111;display:block}
figcaption{color:var(--hi);font-size:.76rem;margin-top:2px}
.toc{display:flex;flex-wrap:wrap;gap:6px 12px;font-size:.85rem;margin-bottom:18px} .toc a{color:var(--acc)}
"""


def rich(text: str) -> str:
    """`**太字**` を太字に。HTML は書けないので、改行はそのまま改行にする。

    題材の理由は数行になるので、1段落に流し込むと読めない（2026-09-24）。
    """
    out = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", e(str(text or "")))
    return out.strip().replace("\n", "<br>")


def ja_date(date: str) -> str:
    return f"{int(date[4:6])}月{int(date[6:8])}日"


# ---------- 題材の一覧 ----------
def topics(date: str, spec_path: Path) -> Path:
    spec = yaml.safe_load(spec_path.read_text(encoding="utf-8"))
    cards = []
    for it in spec.get("items") or []:
        tag = f'<span class="slot">{e(str(it.get("slot", "")))}</span>'
        fmt = f'<span class="fmt">{e(str(it.get("fmt", "news")))}</span>'
        warn = '<span class="weak">弱い</span>' if it.get("weak") else ""
        if it.get("new"):
            warn = '<span class="fresh">差し替え候補</span>' + warn
        cards.append(f'''<div class="card" data-num="{int(it["num"])}">
<h3><span class="num">{int(it["num"])}</span>{e(str(it["head"]))}</h3>
<p class="meta">{tag}{fmt}{warn}<a href="{e(str(it.get("url", "")))}" target="_blank" rel="noopener">{e(str(it.get("src", "")))}</a></p>
<p>{rich(it.get("why", ""))}</p>
<div class="picks">
  <button class="o" data-v="o">○ 作る</button><button class="t" data-v="t">△ 保留</button><button class="x" data-v="x">✖ 却下</button>
  <input placeholder="ひとこと（任意）">
</div></div>''')
    drops = "".join(f"<li><b>{e(str(a))}</b> … {rich(b)}</li>" for a, b in (spec.get("drops") or []))
    title = spec.get("title") or f"{ja_date(date)}の題材"
    page = (f"<title>{e(title)}</title>" + PICK_CSS + f"<style>{BASE_CSS}</style>"
            f"<script>window.PICK_KEY='{date}';</script>"
            f"<main><h1>{e(title)}</h1>"
            f'<p class="lead">{e(str(spec.get("lead", "")))} ／ ○△✖を押すと残ります</p>'
            f'<div class="note">{spec.get("note", "")}<br>'
            '<span class="fmt">news</span> <span class="fmt">voices</span> <span class="fmt">quote</span> は動画の型の提案です。'
            '<span class="weak">弱い</span>は出典が1本だったり、同じ選手が続いたりするものです。</div>'
            '<div id="pickbar" class="pickbar"></div>' + "".join(cards)
            + (f'<div class="note"><b>落とした候補と、その理由</b><ul>{drops}</ul></div>' if drops else "")
            + "</main>" + PICK_JS)
    out = ROOT / "output" / "pages" / f"topics_{date}" / "index.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page, encoding="utf-8")
    return out


# ---------- 台本の一覧 ----------
LINE = re.compile(r"^(キャスター|解説|ナレーター|[^\s:：]+): (.*)$")
ATTR = re.compile(r"^  ([a-z_]+): (.*)$")


def parse(path: Path):
    text = path.read_text(encoding="utf-8")
    _, fm, body = text.split("---\n", 2)
    meta = yaml.safe_load(fm)
    sections, cur, line = [], None, None
    for raw in body.splitlines():
        if raw.startswith("## "):
            cur = {"heading": raw[3:].strip(), "lines": [], "main": False}
            sections.append(cur)
            line = None
            continue
        if raw.startswith("@main"):
            if cur:
                cur["main"] = True
            continue
        if raw.startswith("@"):
            continue
        m = ATTR.match(raw)
        if m and line is not None:
            line["attr"][m.group(1)] = m.group(2)
            continue
        m = LINE.match(raw)
        if m and cur is not None:
            line = {"who": m.group(1), "text": m.group(2), "attr": {}}
            cur["lines"].append(line)
    return meta, sections


def card_html(card) -> str:
    if not card or card.get("type") not in ("table", "bars"):
        return ""
    parts = ['<div class="tbl"><table>']
    if card.get("type") == "bars":
        for it in card.get("items") or []:
            if isinstance(it, dict):
                parts.append(f"<tr><td>{rich(it.get('label', ''))}</td><td>{rich(it.get('value', ''))}</td></tr>")
    else:
        cols = [c for c in (card.get("columns") or []) if c]
        if cols:
            parts.append("<tr>" + "".join(f"<th>{e(str(c))}</th>" for c in cols) + "</tr>")
        for row in card.get("rows") or []:
            parts.append("<tr>" + "".join(f"<td>{rich(str(c))}</td>" for c in row) + "</tr>")
    parts.append("</table></div>")
    return "".join(parts)


def data_uri(path: Path, width: int = 420) -> str:
    from PIL import Image

    with Image.open(path) as im:
        im = im.convert("RGB")
        if im.width > width:
            im = im.resize((width, max(1, round(im.height * width / im.width))))
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=68, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def scripts(date: str, images: bool = False) -> Path:
    paths = sorted(p for p in (ROOT / "scripts").glob(f"{date}_*.md"))
    chunks, toc, stats, est_all = [], [], [], []
    for path in paths:
        key = path.stem[len(date) + 1:]
        meta, sections = parse(path)
        cards = meta.get("cards") or {}
        nline = sum(len(s["lines"]) for s in sections)
        chars = sum(len(l["text"]) for s in sections for l in s["lines"])
        # **本編の尺**。ショートだけの行（only: short）は本編で読まないので数えない
        est = sum(say_seconds(l["text"]) for s in sections for l in s["lines"]
                  if l["attr"].get("only") != "short")
        got = real_seconds(path.stem)
        length = mmss(got) if got else "およそ " + mmss(est)
        est_all.append(got or est)
        stats.append((meta.get("title", key), len(sections), nline, chars, length))
        toc.append(f'<a href="#{e(key)}">{e(str(meta.get("title", key))[:18])}</a>')
        body = []
        for sec in sections:
            tag = ' <span class="tag">ショートはこの節</span>' if sec["main"] else ""
            body.append(f'<section><h3 class="sec">{e(sec["heading"])}{tag}</h3>')
            used, items = set(), []
            for l in sec["lines"]:
                cname = l["attr"].get("card")
                if cname and cname not in ("none", "なし") and cname not in used:
                    used.add(cname)
                    body.append(card_html(cards.get(cname)))
                img = l["attr"].get("image", "")
                cls = ' class="so"' if l["attr"].get("only") == "short" else ""
                pre = "（ショートだけ）" if l["attr"].get("only") == "short" else ""
                mark = ""
                if img:
                    p = ROOT / img
                    if images and p.exists():
                        mark = f'<figure><img src="{data_uri(p)}" alt=""><figcaption>{e(Path(img).stem)}</figcaption></figure>'
                    else:
                        mark = f' <span class="im">{e(Path(img).stem)}</span>'
                who = "" if l["who"] in ("キャスター", "解説", "ナレーター") else f"<b>{e(l['who'])}</b>: "
                items.append(f'<li{cls}>{pre}{who}{rich(l["text"])}{mark}</li>')
            body.append("<ol>" + "".join(items) + "</ol></section>")
        srcs = meta.get("sources") or []
        src = '<div class="src">出典: ' + " / ".join(e(s) for s in srcs) + "</div>" if srcs else ""
        thumb = ROOT / "output" / path.stem / "thumbnail.png"
        th = (f'<figure class="thumb"><img src="{data_uri(thumb, 640)}" alt=""><figcaption>サムネイル</figcaption></figure>'
              if thumb.exists() else "")
        chunks.append(f'<details id="{e(key)}"><summary><span class="t">{e(str(meta.get("title", key)))}</span>'
                      f'<span class="d">{e(length)} ／ {len(sections)}節</span></summary>{th}'
                      + "".join(body) + src + "</details>")
    total_est = sum(est_all)
    rows = "".join(f"<tr><td>{e(str(n))}</td><td>{e(ln)}</td><td>{s}</td><td>{l}</td><td>{c}</td></tr>"
                   for n, s, l, c, ln in stats)
    title = f"{ja_date(date)}の台本"
    page = (f"<title>{e(title)}</title><style>{BASE_CSS}</style><main>"
            f"<h1>{e(title)}（{len(paths)}本）</h1>"
            f'<p class="lead">{date[:4]}-{date[4:6]}-{date[6:]} ／ 読み上げの全文。太字は画面で強調する数字。<b>尺は本編の見込み</b>（ショートは別に58秒まで）</p>'
            '<div class="toc">' + " ".join(toc) + "</div>" + "".join(chunks)
            + f'<details><summary><span class="t">分量</span><span class="d">合計 {e(mmss(total_est))}</span></summary>'
              '<div class="tbl"><table><tr><th>題材</th><th>尺</th><th>節</th><th>行</th><th>文字</th></tr>' + rows
            + "</table></div></details></main>")
    out = ROOT / "output" / "pages" / f"scripts_{date}" / "index.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page, encoding="utf-8")
    return out


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    if argv[0] == "topics" and len(argv) >= 3:
        print(topics(argv[1], Path(argv[2])))
        return 0
    if argv[0] == "scripts":
        print(scripts(argv[1], images="--images" in argv))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
