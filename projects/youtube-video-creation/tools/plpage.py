# -*- coding: utf-8 -*-
"""プレミア20クラブの台本を、画面の絵ごと1枚のページにする（2026-09-22）。

    python tools/plpage.py                      # output/pages/pl20/index.html
    python tools/plpage.py --thumbs             # 先に20本のサムネを output/pages/pl20thumbs/ に描く

出したページは Artifact として同じURLへ出し直す（URL は CLAUDE.md「プレミアリーグ20クラブ紹介」）。
"""
import base64
import html
import io
import json
import re
from pathlib import Path

from PIL import Image

IMAGES: dict[str, str] = {}      # 画像のパス → データURI（同じ絵は1回だけ持つ）


def data_uri(path: Path, width: int = 420) -> str:
    key = str(path)
    if key in IMAGES:
        return key
    with Image.open(path) as im:
        im = im.convert("RGB")
        if im.width > width:
            im = im.resize((width, max(1, round(im.height * width / im.width))), Image.LANCZOS)
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=68, optimize=True)
    IMAGES[key] = "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode("ascii")
    return key


def fig(path: str, caption: str, cls: str = "") -> str:
    p = ROOT / path
    if not p.exists():
        return f'<p class="sc">→ {html.escape(caption)}（ファイル無し）</p>'
    key = data_uri(p)
    return (f'<figure class="{cls}"><img data-k="{html.escape(key)}" alt="">'
            f'<figcaption>{html.escape(caption)}</figcaption></figure>')

import yaml

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "pages" / "pl20"
THUMBS = ROOT / "output" / "pages" / "pl20thumbs"
OUT.mkdir(parents=True, exist_ok=True)
import subprocess
import sys
if "--thumbs" in sys.argv:
    THUMBS.mkdir(parents=True, exist_ok=True)
    for _key, _num in [("bournemouth", "01"), ("arsenal", "02"), ("villa", "03"), ("brentford", "04"), ("brighton", "05"), ("chelsea", "06"), ("coventry", "07"), ("palace", "08"), ("everton", "09"), ("fulham", "10"), ("hull", "11"), ("ipswich", "12"), ("leeds", "13"), ("liverpool", "14"), ("mancity", "15"), ("manutd", "16"), ("newcastle", "17"), ("forest", "18"), ("sunderland", "19"), ("tottenham", "20")]:
        _hits = sorted((ROOT / "scripts").glob(f"*pl{_num}_{_key}.md"))
        if _hits:
            subprocess.run([sys.executable, "-m", "src.cli", "thumbnail", str(_hits[-1]), "--out", str(THUMBS / f"{_key}.png")], cwd=ROOT, capture_output=True)
    print("thumbs", len(list(THUMBS.glob("*.png"))))

ORDER = [("bournemouth", "01"), ("arsenal", "02"), ("villa", "03"), ("brentford", "04"),
         ("brighton", "05"), ("chelsea", "06"), ("coventry", "07"), ("palace", "08"),
         ("everton", "09"), ("fulham", "10"), ("hull", "11"), ("ipswich", "12"),
         ("leeds", "13"), ("liverpool", "14"), ("mancity", "15"), ("manutd", "16"),
         ("newcastle", "17"), ("forest", "18"), ("sunderland", "19"), ("tottenham", "20")]

LINE = re.compile(r"^(キャスター|解説|ナレーター|[^\s:：]+): (.*)$")
ATTR = re.compile(r"^  ([a-z_]+): (.*)$")


def screen_name(path: str, key: str) -> str:
    n = Path(path).stem
    if "_in.png" in path:
        return "スタジアムの中の写真"
    if "/backgrounds/" in path:
        return "下地（スタジアムの外）"
    if "_map" in n:
        return "ホームタウンの地図"
    if "_cups" in n:
        return "優勝回数の板（トロフィー）"
    if "_last" in n:
        return "昨季の最終順位表"
    if "_story/" in path:
        return "クラブの話の実写"
    if "_episode/" in path:
        return "逸話の実写"
    if "/photos/pl/" in path:
        return "オーナーの顔写真" if "owner" in n else "監督の顔写真" if "manager" in n else "名選手の顔写真"
    m = re.match(rf"pl_{key}_data(\d)$", n)
    if m:
        spec = json.loads((ROOT / f"research/pl_data/{key}.json").read_text(encoding="utf-8"))
        return f"基礎DATAの板（{spec['tiles'][int(m.group(1))][0]} が明るい）"
    m = re.match(rf"pl_{key}_(gk|df|mf|fw)\d?(_f)?$", n)
    if m:
        who = {"gk": "ゴールキーパー", "df": "ディフェンダー",
               "mf": "ミッドフィールダー", "fw": "フォワード"}[m.group(1)]
        return f"{who}の板" + ("（話している選手だけ明るい）" if m.group(2) else "")
    return n


def rich(t):
    return re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", html.escape(t))


def card_html(c):
    if not c or c.get("type") != "table":
        return ""
    cols = [x for x in (c.get("columns") or []) if x]
    out = ['<div class="tbl"><table>']
    if cols:
        out.append("<tr>" + "".join(f"<th>{html.escape(str(x))}</th>" for x in cols) + "</tr>")
    for row in c.get("rows") or []:
        out.append("<tr>" + "".join(f"<td>{rich(str(x))}</td>" for x in row) + "</tr>")
    out.append("</table></div>")
    return "".join(out)


blocks, missing = [], []
for key, num in ORDER:
    hits = sorted((ROOT / "scripts").glob(f"*pl{num}_{key}.md"))
    if not hits:
        missing.append(key)
        continue
    text = hits[-1].read_text(encoding="utf-8")
    _, fm, body = text.split("---\n", 2)
    meta = yaml.safe_load(fm)
    cards = meta.get("cards") or {}
    secs, cur, line = [], None, None
    for r in body.splitlines():
        if r.startswith("## "):
            cur = {"h": r[3:].strip(), "lines": [], "main": False, "bg": ""}
            secs.append(cur); line = None; continue
        if r.startswith("@main"):
            cur["main"] = True; continue
        if r.startswith("@bg:"):
            cur["bg"] = r[4:].strip(); continue
        if r.startswith("@"):
            continue
        m = ATTR.match(r)
        if m and line is not None:
            line["attr"][m.group(1)] = m.group(2); continue
        m = LINE.match(r)
        if m and cur is not None:
            line = {"text": m.group(2), "attr": {}}
            cur["lines"].append(line)
    inner = []
    thumb = THUMBS / f"{key}.png"
    if thumb.exists():
        inner.append(f'<figure class="thumb"><img data-k="{html.escape(data_uri(thumb, 640))}" alt=""><figcaption>サムネイル</figcaption></figure>')
    shown_bg = ""
    for s in secs:
        tag = ' <span class="tag">ショート</span>' if s["main"] else ""
        inner.append(f'<h4>{html.escape(s["h"])}{tag}</h4>')
        if s["bg"] and s["bg"] != shown_bg:
            inner.append(fig(s["bg"], "下地（この節から）", "bg"))
            shown_bg = s["bg"]
        used = set()
        for l in s["lines"]:
            cn = l["attr"].get("card")
            if cn and cn not in ("none", "なし") and cn not in used:
                used.add(cn); inner.append(card_html(cards.get(cn)))
            img = l["attr"].get("image", "")
            if img:
                inner.append(fig(img, screen_name(img, key)))
            pre = "（ショートだけ）" if l["attr"].get("only") == "short" else ""
            inner.append(f'<p{" class=so" if pre else ""}>{pre}{rich(l["text"])}</p>')
    n_lines = sum(len(s["lines"]) for s in secs)
    blocks.append(
        # 公開する題（シリーズ名の後ろ書き。2026-09-23）。読み上げの1行目は title のまま
        f'<details><summary><b>{num}　{html.escape(meta["title"])}</b>'
        + (f'<span class="ser">｜{html.escape(str(meta["series"]))}</span>' if meta.get("series") else "")
        + f'<span class="n">{len(secs)}節・{n_lines}行</span></summary>'
        + "".join(inner) + "</details>")

CSS = """
.ser{color:var(--mut);font-weight:400}
:root{--bg:#f5f4f1;--fg:#1c1b19;--mut:#6b6862;--card:#fff;--line:#e2ded6;--acc:#a8321f;--hi:#1f7a5a}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]){--bg:#14120f;--fg:#efece4;--mut:#9d9689;--card:#1f1c17;--line:#332f27;--acc:#e8a08c;--hi:#5fd6a8}}
:root[data-theme=dark]{--bg:#14120f;--fg:#efece4;--mut:#9d9689;--card:#1f1c17;--line:#332f27;--acc:#e8a08c;--hi:#5fd6a8}
body{background:var(--bg);color:var(--fg);font:15px/1.8 "Hiragino Sans","Noto Sans JP",system-ui,sans-serif;padding-inline:16px;padding-block:22px 64px}
main{max-width:780px;margin:0 auto}
h1{font-size:1.4rem;margin:0 0 .2rem;color:var(--acc)} .lead{color:var(--mut);font-size:.88rem;margin:0 0 14px}
.note{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 14px;font-size:.86rem;margin-bottom:18px}
details{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:8px 16px;margin:10px 0}
summary{cursor:pointer;font-size:1rem;color:var(--acc);padding:4px 0}
summary .n{color:var(--mut);font-size:.78rem;margin-left:10px;font-weight:400}
h4{font-size:.94rem;margin:1rem 0 .3rem;color:var(--fg);border-left:3px solid var(--acc);padding-left:8px}
p{margin:.25rem 0} p.so{color:var(--mut)}
p.sc{color:var(--hi);font-size:.76rem;margin:.5rem 0 .1rem}
.tag{font-size:.7rem;color:var(--hi);border:1px solid var(--hi);border-radius:99px;padding:0 7px;margin-left:6px}
figure{margin:.5rem 0 .2rem;max-width:420px} figure.thumb{max-width:640px} figure.bg{max-width:300px}
figure img{width:100%;height:auto;border-radius:6px;border:1px solid var(--line);background:#111;display:block}
figcaption{color:var(--hi);font-size:.76rem;margin-top:2px}
.tbl{overflow-x:auto;margin:.4rem 0} table{border-collapse:collapse;font-size:.82rem}
td,th{border:1px solid var(--line);padding:3px 9px;text-align:left;font-variant-numeric:tabular-nums}
"""

warn = (f'<br><b style="color:#a8321f">まだ組めていないクラブ: {"、".join(missing)}</b>'
        if missing else "")
page = ("<title>プレミア20クラブの台本</title><style>" + CSS + "</style><main>"
        "<h1>プレミア20クラブの台本</h1>"
        f'<p class="lead">2026-09-22 ／ {len(blocks)}クラブ ／ クラブ名を押すと開きます</p>'
        '<div class="note"><b>クラブを表す一言から始まります。</b>タイトルはその次に読みます。<br><span style="color:#1f7a5a">→</span> の行は、そこから画面が変わるものです。<br>画面：<b>昨季の最終順位表</b>（自分の行だけ白い）／<b>トロフィーの板</b>／<b>ホームタウンの地図</b>／オーナーと名選手の<b>顔写真</b>／<b>登録選手の板は話している選手だけ明るい</b>。<br><b>画像は実際に画面に出るものを縮めて載せています</b>（下地・板・写真・順位表・サムネイル）。<br><b>9/22 夜に直したもの</b>：⑪耳で分からない言い回し（勝敗の無いスコア、48字を超える行、「です」が3行続く、アルファベット）を機械の点検に足し、20本すべて直しました。登録選手の節は1文ずつに割っています。⑨冒頭に「いま見る理由」の節（2〜3行）を足し、ショートはそこから始まります。日本人のいる回は1つ目がその選手。⑩監督の節を登録選手の前に移しました。⑧「今季の監督」の節を登録選手のあとに足しました（名前・就任・前職と顔写真。20人とも本人の記事で裏取り、写真は目で確認）。⑦「このクラブを語る3人」を1人1行から1人3行に（来た経緯・決定的な場面・残したもの。各選手の Wikipedia で裏取り）。1本の尺は4分〜4分50秒になりました。⑤トロフィーの板を20クラブすべて描き直し、ヨーロッパ合計ではなく大会ごと（チャンピオンズリーグ／ヨーロッパリーグ／カップウィナーズカップ／カンファレンスリーグ／フェアーズカップ／スーパーカップ／クラブワールドカップ／インタートトカップ）にしました。読み上げも同じ内訳です。⑥基礎DATAは20クラブとも同じ順（創立 → 愛称 → ホームタウン → 本拠地 → オーナー → タイトル歴 → クラブ記録 → 直近のタイトル → 昨季の順位）で話し、板もその並びです。<br><b>9/22 昼に直したもの</b>：①クラブごとに「へえ」となる逸話の節を1つ足しました（Wikipedia のクラブ記事で裏を取ったものだけ。例：フォレストが1886年にアーセナルへユニフォームを贈った／ハルが「ハル・タイガース」に改名されかけた）。②新しい読み手に20本を通しで読ませ、勝敗の無いスコア・冒頭で約束して答えていないこと・同じ数字の二度読み・耳で分からない言い回し（「季」「UEFA」）を直しました。③本の中の言い直し8本を直しました。④日本人選手が題にある回は、その選手の具体的な1行（出場数など）を足しました。構成（基礎DATA→クラブの話→逸話→名選手→登録選手→今季）と登録選手の節は変えていません。' + warn + '</div>'
        + "".join(blocks) + "</main>"
        + "<script>const IM=" + json.dumps(IMAGES, ensure_ascii=False)
        + ";for(const i of document.querySelectorAll('img[data-k]')){i.src=IM[i.dataset.k]||'';}</script>")
(OUT / "index.html").write_text(page, encoding="utf-8")
print("ok", len(blocks), "クラブ / 未:", missing)
