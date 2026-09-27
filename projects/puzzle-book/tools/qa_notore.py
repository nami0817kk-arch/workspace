"""あたまの体操の本の納品前点検（50項目）。projects/puzzle-book で  python tools/qa_notore.py

入稿の直前に必ず回す。KDP の入稿要件・中身の正しさ・表記の一貫性を、出来上がった PDF から確かめる。
A（入稿要件）は qa_kotoba.py と同じ物差し。B は計算・時計・迷路などを紙面から読み直して確かめる。
"""
import json
import math
import pathlib
import re
import sys
from collections import defaultdict

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "src"))
import pymupdf  # noqa: E402
from fontTools.ttLib import TTFont  # noqa: E402
from pypdf import PdfReader  # noqa: E402
from puzzle_generator import clock_label, validate_record  # noqa: E402

import kdp_spec  # noqa: E402
from build_notore import COPY_PERMISSION, LEVEL_PARAMS, PAIR_ICONS, PUZZLE_NAMES, NotoreSpec, generate_days, page_count  # noqa: E402

INT, COV = "output/notore-vol1-interior.pdf", "output/notore-vol1-cover.pdf"
LISTING = pathlib.Path("books/notore-vol1-listing.md").read_text(encoding="utf-8")
KDP_TITLE, KDP_SUB = "ゆったり あたまの体操", "計算・時計・数字さがし・迷路・同じ絵さがし"
spec = NotoreSpec.load("books/notore-vol1.json")
days = generate_days(spec)
di, dc = pymupdf.open(INT), pymupdf.open(COV)
N = len(days)
trim = kdp_spec.TRIMS[spec.trim]
PW, PH = trim.width_in * 72, trim.height_in * 72
R = []


def check(name, ok, detail=""):
    R.append((name, bool(ok), detail))
    print(f"{len(R):>2}. {'OK' if ok else 'NG'}  {name}  {detail}")


def spans(doc, pages=None):
    for p in doc:
        if pages is not None and p.number not in pages:
            continue
        for b in p.get_text("dict")["blocks"]:
            for ln in b.get("lines", []):
                for s in ln["spans"]:
                    if s["text"].strip():
                        yield p, s


def alpha(doc):
    for p in doc:
        for x in p.get_contents():
            if re.search(rb"/ca\s+0?\.\d|/CA\s+0?\.\d", doc.xref_stream(x)):
                return True
    return any("/SMask" in doc.xref_object(x) for x in range(1, doc.xref_length()) if doc.xref_object(x))


def left_page(i):  # i 日目（0始まり）の左・右のページ番号（0始まり）
    return 3 + 2 * i


def answer_page(i):
    return 3 + 2 * N + i // 2


pages_day = range(3, 3 + 2 * N)
pages_answer = range(3 + 2 * N, 3 + 2 * N + -(-N // 2))
IDX_RECORD, IDX_COLOPHON = len(di) - 2, len(di) - 1
all_int_text = "".join(p.get_text() for p in di)
fixed_pages = (0, 1, 2, IDX_RECORD, IDX_COLOPHON)
fixed_text = dc[0].get_text() + "".join(di[i].get_text() for i in fixed_pages)
colophon = di[IDX_COLOPHON].get_text()
cover_text = dc[0].get_text()

print("■ A. KDP の入稿要件（PDF・判型・余白・色・書体）")
sizes = {(round(p.rect.width, 2), round(p.rect.height, 2)) for p in di}
check("本文の全ページが判型（A4 8.27×11.69in）ちょうど", sizes == {(round(PW, 2), round(PH, 2))}, str(sizes))
check("本文のページ数が設計どおり・偶数・24以上・大判の上限780以下",
      len(di) == page_count(spec) and len(di) % 2 == 0 and 24 <= len(di) <= 780, f"{len(di)}ページ")
miss_i = {f[3] for p in di for f in p.get_fonts() if f[1] == "n/a"}
check("本文の書体がすべて埋め込み", not miss_i, str(miss_i))
miss_c = {f[3] for p in dc for f in p.get_fonts() if f[1] == "n/a"}
check("表紙の書体がすべて埋め込み", not miss_c, str(miss_c))
check("本文・表紙ともパスワード・暗号化なし", not di.is_encrypted and not dc.is_encrypted)
ok_open = True
try:
    PdfReader(INT).pages[0], PdfReader(COV).pages[0]
except Exception:  # noqa: BLE001
    ok_open = False
check("別の読み取り器（pypdf）でも本文・表紙を正常に開ける", ok_open)
size_mb = (pathlib.Path(INT).stat().st_size, pathlib.Path(COV).stat().st_size)
check("ファイルの大きさ（本文 650MB 未満・表紙 40MB 以下の推奨）", size_mb[0] < 650e6 and size_mb[1] < 40e6,
      f"本文 {size_mb[0] / 1e6:.1f}MB / 表紙 {size_mb[1] / 1e6:.2f}MB")
check("本文で透明（半透明・マスク）を使っていない", not alpha(di))
check("表紙で透明を使っていない", not alpha(dc))
exp_w = (0.25 + 2 * trim.width_in + kdp_spec.spine_width_in(len(di), "white", spec.ink)) * 72
check("表紙は1ページで、幅・高さが KDP の式どおり", len(dc) == 1 and abs(dc[0].rect.width - exp_w) < 0.1
      and abs(dc[0].rect.height - (PH + 18)) < 0.1, f"{dc[0].rect.width / 72:.4f}×{dc[0].rect.height / 72:.4f}in")
raw_c = b"".join(dc.xref_stream(x) for x in dc[0].get_contents())
rgb = re.findall(rb"(?<![\w.])(?:[\d.]+\s+){3}(?:rg|RG)(?!\w)", raw_c)
check("表紙の色指定は CMYK だけ（RGB なし）", not rgb, f"RGB {len(rgb)}件")
imgs = dc[0].get_images(full=True)
cs = [pymupdf.Pixmap(dc, im[0]).colorspace.name for im in imgs]
check("表紙の画像はすべて CMYK", all("CMYK" in c.upper() for c in cs), str(cs))
dpis = []
for im in imgs:
    bbox = dc[0].get_image_bbox(im)
    dpis.append(min(im[2] / (bbox.width / 72), im[3] / (bbox.height / 72)))
check("表紙の画像は 300dpi 以上", all(d >= 299 for d in dpis), f"{[round(d) for d in dpis]}dpi")
check("本文にラスター画像（低解像度の恐れ）を使っていない", not any(p.get_images() for p in di))
check("本文の文字は 7pt 以上", min(s["size"] for _, s in spans(di)) >= 6.99)
check("表紙の文字は 7pt 以上", min(s["size"] for _, s in spans(dc)) >= 6.99)
thin = []
for p in di:
    for d in p.get_drawings():
        if d.get("type") in ("s", "fs") and d.get("width") and d["width"] < 0.75 - 0.01:
            thin.append((p.number + 1, round(d["width"], 2)))
check("本文の罫線・枠線は 0.75pt 以上（KDP の最小の線の太さ）", not thin, f"細い線 {len(thin)}件 {sorted(set(thin))[:4]}")
out = []
for p in di:
    odd = (p.number + 1) % 2 == 1
    l_, r_ = (27, 18) if odd else (18, 27)
    boxes = [pymupdf.Rect(s["bbox"]) for pp, s in spans(di, {p.number})] + [d["rect"] for d in p.get_drawings()]
    for r in boxes:
        if not r.is_empty and (r.x0 < l_ - .5 or r.x1 > PW - r_ + .5 or r.y0 < 17.5 or r.y1 > PH - 17.5):
            out.append(p.number + 1)
check("本文の中身がすべて外側 0.25in・ノド 0.375in の内側", not out, f"{sorted(set(out))[:5]}")
bleed, spine = 9, kdp_spec.spine_width_in(len(di), "white", spec.ink) * 72
back = (bleed, bleed + PW)
front = (back[1] + spine, back[1] + spine + PW)
bad_c = []
for _, s in spans(dc):
    x0, y0, x1, y1 = s["bbox"]
    if not (any(a + 18 <= x0 and x1 <= b - 18 for a, b in (back, front)) and bleed + 18 <= y0 and y1 <= bleed + PH - 18):
        bad_c.append(s["text"][:8])
check("表紙の文字が仕上がり線から 0.25in 以上内側（背にも文字なし）", not bad_c, str(bad_c[:4]))
bw, bh = (v * 72 for v in kdp_spec.BARCODE_BOX_IN)
box = pymupdf.Rect(back[1] - 18 - bw, bleed + PH - 18 - bh, back[1] - 18, bleed + PH - 18)
on_bar = [s["text"] for _, s in spans(dc) if pymupdf.Rect(s["bbox"]).intersects(box)]
check("裏表紙のバーコード欄（2×1.2in）に文字がない", not on_bar, str(on_bar))
boxes = [(pymupdf.Rect(s["bbox"]), s["text"]) for _, s in spans(dc)]
ov = [(a[1], b[1]) for i, a in enumerate(boxes) for b in boxes[i + 1:]
      if a[1] != b[1] and (a[0] & b[0]).width > 1 and (a[0] & b[0]).height > 1]
check("表紙の文字どうしが重ならない", not ov, str(ov[:2]))
blank_run, run = 0, 0
for p in di:
    run = run + 1 if not p.get_text().strip() and not p.get_drawings() else 0
    blank_run = max(blank_run, run)
check("白紙ページの連続が KDP の上限（途中4・末尾10）以内", blank_run <= 4, f"最長 {blank_run}")
folio_bad = []
for i in list(pages_day) + list(pages_answer):
    last = di[i].get_text().strip().splitlines()[-1]
    if last != str(i + 1):
        folio_bad.append((i + 1, last))
check("毎日のページ・答えのページにノンブル（ページ番号）が正しく入っている", not folio_bad, str(folio_bad[:3]))

print("\n■ B. 中身の正しさ（紙面から読み直す）")
bad_v = []
for day in days:
    for key in ("arithmetic", "number", "right", "clock"):
        try:
            validate_record(day[key])
        except Exception as e:  # noqa: BLE001
            bad_v.append((day["day"], key, str(e)[:40]))
check("30日×4つ（計算・数字さがし・右のパズル・時計）がすべて検証を通る", N == 30 and not bad_v, str(bad_v[:3]))

OPS = {"＋": "+", "－": "-", "×": "×"}
ar_page, ar_ans = [], []
for i, day in enumerate(days):
    text = di[left_page(i)].get_text().replace("\n", " ")
    printed = {int(k): (int(a), OPS[op], int(b)) for k, a, op, b in
               re.findall(r"\((\d+)\)\s*(\d+)\s*([＋－×])\s*(\d+)\s*＝", text)}
    rec = {k + 1: (p["a"], p["op"], p["b"]) for k, p in enumerate(day["arithmetic"]["board"]["problems"])}
    if printed != rec:
        ar_page.append(day["day"])
    block = di[answer_page(i)].get_text().split(f"\n{day['day']}日目\n")[1].split("時計")[0]
    got = {int(k): int(v) for k, v in re.findall(r"\((\d+)\)\s*(\d+)", block)}
    want = {k: a + b if op == "+" else a - b if op == "-" else a * b for k, (a, op, b) in printed.items()}
    if got != want:
        ar_ans.append(day["day"])
check("計算：紙面の10問が記録どおりに印刷されている", not ar_page, str(ar_page))
check("計算：答えのページの数が、紙面の問題から計算し直した値と一致", not ar_ans, str(ar_ans))
ar_bad = []
for day in days:
    probs = [(p["a"], p["op"], p["b"]) for p in day["arithmetic"]["board"]["problems"]]
    if len(set(probs)) != 10 or any(op == "-" and a <= b for a, op, b in probs):
        ar_bad.append(day["day"])
check("計算：日の中で同じ問題がなく、引き算の答えは1以上（マイナス・0にならない）", not ar_bad, str(ar_bad))
lv_bad = []
for day in days:
    probs = day["arithmetic"]["board"]["problems"]
    d = day["difficulty"]
    ops = {p["op"] for p in probs}
    if d == "easy" and not all(p["a"] < 10 and p["b"] < 10 and p["op"] != "×" for p in probs):
        lv_bad.append(day["day"])
    if d == "medium" and ("×" in ops or not all(p["a"] >= 10 and p["b"] >= 10 for p in probs)):
        lv_bad.append(day["day"])
    if d == "hard" and "×" not in ops:
        lv_bad.append(day["day"])
check("計算：やさしい＝1桁の＋－／ふつう＝2桁の＋－／むずかしい＝かけ算も入る", not lv_bad, str(lv_bad))

ns_bad = []
for i, day in enumerate(days):
    g = day["number"]["board"]["grid"]
    n = len(g)
    txt = di[left_page(i)].get_text().split("たどりましょう")[1].split("かかった時間")[0].split()
    if [int(t) for t in txt] != [v for row in g for v in row] or sorted(txt, key=int) != [str(k) for k in range(1, n * n + 1)]:
        ns_bad.append(day["day"])
check("数字さがし：紙面の数字が記録の並びどおりで、1からn²までがちょうど1回ずつ", not ns_bad, str(ns_bad))

cl_ans, cl_bad = [], []
for i, day in enumerate(days):
    times = day["clock"]["board"]["times"]
    block = di[answer_page(i)].get_text().split(f"\n{day['day']}日目\n")[1].split("時計")[1].split("迷路")[0].split("同じ絵")[0]
    got = re.findall(r"\(\d\)\s*(\d+時(?:\d+分)?(?:30分)?)", block)
    if got != [clock_label(h, m) for h, m in times]:
        cl_ans.append((day["day"], got))
    step = {"easy": 30, "medium": 15, "hard": 5}[day["difficulty"]]
    if len({tuple(t) for t in times}) != 3 or any(m % step for _, m in times):
        cl_bad.append(day["day"])
check("時計：答えのページの「N時M分」が記録の時刻と一致", not cl_ans, str(cl_ans[:2]))
check("時計：日の中で同じ時刻がなく、刻みが難易度どおり（30分・15分・5分）", not cl_bad, str(cl_bad))


def read_hands(page):
    """針は中心から出る太さの違う2本の線（短針が太い）。中心ごとにまとめて、左から時刻を読む。"""
    by_center = defaultdict(list)
    for dr in page.get_drawings():
        if len(dr["items"]) == 1 and dr["items"][0][0] == "l" and dr.get("width"):
            p0, p1 = dr["items"][0][1], dr["items"][0][2]
            by_center[(round(p0.x, 1), round(p0.y, 1))].append((dr["width"], p1.x - p0.x, p0.y - p1.y))
    clocks = []
    for (cx, cy), ls in by_center.items():
        if len(ls) != 2 or not 1.6 < max(ls)[0] / min(ls)[0] < 1.95:
            continue
        (_, hx, hy), (_, mx, my) = sorted(ls, reverse=True)  # 太い方が短針
        ma = (90 - math.degrees(math.atan2(my, mx))) % 360
        ha = (90 - math.degrees(math.atan2(hy, hx))) % 360
        m = round(ma / 6) % 60
        h = round((ha - m * 0.5) / 30) % 12 or 12
        clocks.append((cx, [h, m]))
    return [t for _, t in sorted(clocks)]


hands = [(day["day"], read_hands(di[left_page(i) + 1]), day["clock"]["board"]["times"])
         for i, day in enumerate(days)]
hb = [(d, got, want) for d, got, want in hands if got != want]
check("時計：紙面の針の向きを読み取ると、記録の時刻と一致（30日×3つ）", not hb, str(hb[:2]))

mz_bad = []
DELTA = {1: (0, -1), 2: (1, 0), 4: (0, 1), 8: (-1, 0)}
for day in days:
    r = day["right"]
    if r["type"] != "maze":
        continue
    b = r["board"]
    W, H, walls = b["width"], b["height"], b["cell_walls"]
    edges = set()
    for y in range(H):
        for x in range(W):
            for bit, (dx, dy) in DELTA.items():
                nx, ny = x + dx, y + dy
                if not walls[y][x] & bit and 0 <= nx < W and 0 <= ny < H:
                    edges.add(frozenset({(x, y), (nx, ny)}))
    seen, stack = {(0, 0)}, [(0, 0)]
    while stack:
        cur = stack.pop()
        for e in edges:
            if cur in e:
                (o,) = e - {cur}
                if o not in seen:
                    seen.add(o)
                    stack.append(o)
    path = [tuple(p) for p in r["solution"]["path"]]
    ok_path = (path[0] == tuple(b["start"]) and path[-1] == tuple(b["goal"])
               and all(frozenset({a, c}) in edges for a, c in zip(path, path[1:])))
    if not (len(edges) == W * H - 1 and len(seen) == W * H and ok_path):
        mz_bad.append(day["day"])
check("迷路：どれも全マスがつながり、ループがない（ゴールまでの道は1本だけ）。答えの道は壁を通らない", not mz_bad, str(mz_bad))
alt = [d["right"]["type"] for d in days]
msz = [(d["difficulty"], d["right"]["board"]["width"]) for d in days if d["right"]["type"] == "maze"]
check("迷路は奇数日・同じ絵さがしは偶数日に交互。迷路の大きさは 8→11→14",
      alt == ["maze", "pair_search"] * 15 and all(w == LEVEL_PARAMS[lv]["maze"] for lv, w in msz), str(sorted(set(msz))))
ps_bad = []
for day in days:
    r = day["right"]
    if r["type"] != "pair_search":
        continue
    cells = [c for row in r["board"]["grid"] for c in row]
    dup = [c for c in set(cells) if cells.count(c) > 1]
    (x1, y1), (x2, y2) = r["solution"]["pair"]
    if (len(dup) != 1 or cells.count(dup[0]) != 2 or r["board"]["grid"][y1][x1] != dup[0]
            or r["board"]["grid"][y2][x2] != dup[0] or not set(cells) <= set(PAIR_ICONS)
            or (r["board"]["rows"], r["board"]["cols"]) != LEVEL_PARAMS[day["difficulty"]]["pair"]):
        ps_bad.append(day["day"])
check("同じ絵さがし：同じ絵はちょうど1組で、答えの位置がその組。盤面は難易度どおりの大きさ", not ps_bad, str(ps_bad))
red = []
for i in range(0, N, 2):
    p = di[answer_page(i)]
    circles = [d for d in p.get_drawings() if d.get("color") and len(d["items"]) >= 4 and all(it[0] == "c" for it in d["items"])
               and d["color"][0] > 0.8 and d["color"][1] < 0.4]
    if len(circles) != 2:
        red.append((answer_page(i) + 1, len(circles)))
check("同じ絵さがし：答えのページに赤い丸がちょうど2つ（15ページ）", not red, str(red[:3]))
hd = []
for i, day in enumerate(days):
    lab = {"easy": "やさしい", "medium": "ふつう", "hard": "むずかしい"}[day["difficulty"]]
    lt, rt = di[left_page(i)].get_text(), di[left_page(i) + 1].get_text()
    if not (lt.startswith(f"{day['day']}日目\n") and lab in lt and rt.startswith(f"{day['day']}日目（つづき）") and lab in rt):
        hd.append(day["day"])
for i in range(0, N, 2):
    if f"{i + 1}日目〜{i + 2}日目" not in di[answer_page(i)].get_text():
        hd.append(f"答え{i + 1}")
check("見出し：毎日の左右ページの「N日目」と難易度、答えのページの「N日目〜M日目」が正しい", not hd, str(hd[:4]))
talks = [d["talk"] for d in days]
tk = [t for t in talks if not t.endswith("？") or re.search(r"死|亡|病|戦争|介護|認知|別れ", t)]
tk += [d["day"] for i, d in enumerate(days) if d["talk"] not in di[left_page(i) + 1].get_text().replace("\n", "")]
check("思い出トーク：30日すべて違う問いかけで、つらい話題に触れず、右のページに載っている",
      len(set(talks)) == 30 and not tk, str(tk[:3]))

print("\n■ C. 表記と一貫性（題名・名義・入力内容・表現）")
title_line = next((l.strip() for l in colophon.splitlines() if l.strip().startswith("ゆったり")), "")
check("題名・副題が表紙・表題・奥付で KDP に入れた値と一致",
      "ゆったり" in cover_text and "あたまの体操" in cover_text and KDP_SUB in cover_text
      and KDP_SUB in di[0].get_text() and "あたまの体操" in di[0].get_text() and title_line == KDP_TITLE, f"奥付='{title_line}'")
check("発行者「つるはし社」が表紙・表題・奥付にある", all("つるはし社" in x for x in (cover_text, di[0].get_text(), colophon)))
pii = [w for w in ("nami", "0817") if w in fixed_text.lower()] + (["なみ"] if re.search(r"(?<!たし)なみ", fixed_text) else [])
check("個人を特定できる文字（nami・0817 など）が出ていない", not pii, str(pii))
cm = [TTFont(f"assets/fonts/{n}").getBestCmap() for n in ("NotoSansJP-Regular.ttf", "NotoSansJP-Bold.ttf")]
tofu = {ch for ch in all_int_text + cover_text if not ch.isspace() and not all(ord(ch) in c for c in cm)}
check("字形が無い文字（四角に化ける字）がない", not tofu, str(sorted(tofu)))
check("奥付に図版の出典（Noto Emoji）がある", "Noto Emoji" in colophon)
check("コピー許可の範囲が奥付・裏表紙・入力内容に書いてある",
      all(l.strip("【】") in colophon.replace("\n", "") for l in COPY_PERMISSION[1:2])
      and "施設内のコピーOK" in cover_text and "コピーOK" in LISTING)
seals = ["30日分", "思い出", "トーク", "5種類の", "パズル", "オール", "カラー", "答え", "つき"]
check("表紙の札の文言（30日分・思い出トーク・5種類のパズル・オールカラー・答えつき）", all(s in cover_text for s in seals))
howto = di[1].get_text() + di[2].get_text()
check("遊び方のページに5種類（計算・数字さがし・迷路・同じ絵さがし・時計）の説明がそろっている",
      all(n in howto for n in PUZZLE_NAMES), str([n for n in PUZZLE_NAMES if n not in howto]))
rec_text = di[IDX_RECORD].get_text()
check("30日の記録に1〜30日目がすべて載っている", all(f"{k}日目" in rec_text for k in range(1, 31)))
paste = LISTING[LISTING.index("## 内容紹介"):LISTING.index("## カテゴリー")]  # 実際に貼り付ける部分だけを見る
kt = [w for w, t in (("本文", all_int_text), ("表紙", cover_text), ("入力内容", paste)) if "ことば探し" in t]
check("「ことば探し」が本文・表紙・内容紹介に残っていない（2026-09-27 指示で外した）", not kt, str(kt))
check("入力内容の案：タイトル・サブタイトル・価格 1,100円が本体と一致",
      f"タイトル: {KDP_TITLE}" in LISTING and f"サブタイトル: {KDP_SUB}" in LISTING and "1,100" in LISTING
      and f"{len(di)}ページ" in LISTING)
claims = re.findall(r"認知症予防|予防になる|効果があ|効きます|治る|改善します|若返|脳トレ", paste + cover_text + fixed_text)
check("効き目をうたう表現（認知症予防・効果がある等）や「脳トレ」（商標）がない", not claims, str(claims))

assert len(R) == 50, len(R)
ng = [r for r in R if not r[1]]
print(f"\n{len(R) - len(ng)}/{len(R)} 合格")
for n in ng:
    print("  NG:", n[0], n[2])
sys.exit(1 if ng else 0)
