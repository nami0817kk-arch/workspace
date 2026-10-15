# -*- coding: utf-8 -*-
"""ショートの台本ページ（2026-10-15 ユーザー「これ、ショートだよね？」）。

`tools/pages.py scripts` は**台本の全文（本編の形）**を出すので、ショートだけを作る日（ニュース）は
実際に読み上げる文面が見えなかった。ここでは `shorts.trim` が組んだ**ショートそのもの**を出す。

    python tools/pages_short.py <日付> <名前,名前,…> [--images]

出力: output/pages/shorts_<日付>/index.html
各本: 題・想定尺・使う節・サムネ、そして1行ずつ 話者／読み上げる文／画面の大きな一言／写真／反応か本人の言葉の印。
"""
from __future__ import annotations

import argparse
import html
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except Exception:
        pass

from src import shorts  # noqa: E402
from src.script_model import load_script  # noqa: E402
from tools.pages import BASE_CSS, data_uri  # noqa: E402

e = html.escape
NARR = ("キャスター", "解説", "ナレーター")
CSS = """
.sl{list-style:none;padding:0;margin:0}
.sl li{border-top:1px solid var(--line,#ddd);padding:.5rem 0;display:grid;grid-template-columns:5.5rem 1fr;gap:.6rem}
.sl .who{font-size:.78rem;opacity:.7}
.sl .big{display:inline-block;background:#222;color:#ffd700;border-radius:.3rem;padding:.1rem .5rem;margin:.25rem .25rem 0 0;font-weight:700}
.sl .img{font-size:.74rem;opacity:.65}
.sl .voice .t{background:rgba(120,160,255,.12);border-radius:.4rem;padding:.2rem .4rem;display:inline-block}
.sl .outro{opacity:.8}
.meta{font-size:.85rem;opacity:.8;margin:.2rem 0 .6rem}
"""


def short_block(path: Path, images: bool) -> str:
    script = load_script(path)
    short = shorts.trim(script)
    est = shorts._estimate(short)
    scenes = " → ".join(s.title for s in short.scenes)
    items = []
    for line in short.lines:
        who = str(line.speaker)
        text = str(line.text or "")
        voice = who not in NARR and not who.startswith("キャスター")
        outro = text in shorts.SHORT_OUTRO_ANY or getattr(line, "_outro", False)
        big = str(getattr(line, "short_telop", "") or "").strip()
        bigs = f'<span class="big">{e(big.replace("/", " ／ "))}</span>' if big else ""
        img = ""
        if line.image:
            p = ROOT / str(line.image)
            name = Path(str(line.image)).name
            img = f'<div class="img">写真: {e(Path(str(line.image)).parent.name)}/{e(name)}</div>'
            if images and p.exists() and not str(line.image).endswith(".png"):
                img = (f'<div class="img"><img src="{data_uri(p, 160)}" alt="" style="height:4.2rem"> '
                       f'{e(Path(str(line.image)).parent.name)}/{e(name)}</div>')
        cls = "voice" if voice else ("outro" if outro else "")
        items.append(f'<li class="{cls}"><span class="who">{e(who)}</span><span><span class="t">{e(text)}</span>{bigs}{img}</span></li>')
    thumb = ROOT / "output" / path.stem / "thumbnail.png"
    th = (f'<figure><img src="{data_uri(thumb, 560)}" alt="" style="max-width:100%"><figcaption>サムネ（本編の一覧用。ショートの一覧は動画の冒頭の1コマ）</figcaption></figure>'
          if thumb.exists() else "")
    title = str(short.title or script.title)
    q = str((script.meta or {}).get("short_question") or "")
    return (f'<details id="{e(path.stem)}"><summary><b>{e(title)}</b>'
            f'<span class="d"> 約{est:.0f}秒／{len(short.lines)}行</span></summary>'
            f'<div class="meta">使う節: {e(scenes)}　締めの質問: {e(q) or "（なし）"}</div>{th}'
            f'<ol class="sl">{"".join(items)}</ol></details>')


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("date")
    ap.add_argument("stems")
    ap.add_argument("--images", action="store_true")
    a = ap.parse_args(argv)
    blocks, rows = [], []
    for stem in a.stems.split(","):
        path = ROOT / "scripts" / f"{stem}.md"
        try:
            b = short_block(path, a.images)
        except Exception as exc:  # 1本が壊れても他は出す
            b = f'<details><summary><b>{e(stem)}</b> 組めませんでした</summary><p>{e(str(exc))}</p></details>'
        blocks.append(b)
    page = (f'<meta charset="utf-8"><title>{e(a.date)} ショート台本</title><style>{BASE_CSS}{CSS}</style><main>'
            f'<h1>{e(a.date)} ショートの台本（{len(blocks)}本）</h1>'
            '<p class="lead"><b>ショートだけ</b>を作ります（本編は作らない）。ここに出すのは、ショートで<b>実際に読み上げる並び</b>です。'
            '青い帯は本人・監督・ネットの声、黄色い札は画面に大きく出す一言、写真は行ごとの絵。締めは登録の依頼のあとに質問が来ます。</p>'
            + "".join(blocks) + "</main>")
    out = ROOT / "output" / "pages" / f"shorts_{a.date}" / "index.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page, encoding="utf-8")
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
