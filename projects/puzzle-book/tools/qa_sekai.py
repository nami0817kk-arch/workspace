"""世界のことわざの本の納品前点検（50項目）。projects/puzzle-book で  python tools/qa_sekai.py

入稿の直前に必ず回す。KDP の入稿要件（裁ち落としあり）・中身の正しさ・表記の一貫性を、出来上がった PDF から確かめる。
4言語の言い方は books/sekai-kotowaza-verified.json（2出典以上で確かめた記録）と一字ずつ照らし合わせる。
"""
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "src"))
import pymupdf  # noqa: E402
from pypdf import PdfReader  # noqa: E402

import kdp_spec  # noqa: E402
from build_sekai import (LANGS, NATIVE, SekaiSpec, art_path, chapter_page, chapter_quiz, has_art, item_page,  # noqa: E402
                         load_items, page_count)

INT, COV = "output/sekai-kotowaza-vol1-interior.pdf", "output/sekai-kotowaza-vol1-cover.pdf"
LISTING = pathlib.Path("books/sekai-kotowaza-vol1-listing.md").read_text(encoding="utf-8")
spec = SekaiSpec.load("books/sekai-kotowaza-vol1.json")
items = load_items(spec)
VER = {r["no"]: r for r in json.loads(pathlib.Path(spec.verified).read_text(encoding="utf-8"))}
di, dc = pymupdf.open(INT), pymupdf.open(COV)
trim = kdp_spec.TRIMS[spec.trim]
B = kdp_spec.COVER_BLEED_IN * 72
TW, TH = trim.width_in * 72, trim.height_in * 72
SAFE = 0.375 * 72
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


def flat(text):
    return re.sub(r"\s+", "", text)


def ptext(n):  # 1始まりのページ番号
    return di[n - 1].get_text()


all_int = "".join(p.get_text() for p in di)
cover_text = dc[0].get_text()
colophon = ptext(len(di))

print("■ A. KDP の入稿要件（裁ち落としあり・PDF・色・書体）")
check("本文のページ数が設計どおり・偶数・KDP の最小（72）以上・828以下",
      len(di) == page_count(spec) and len(di) % 2 == 0 and kdp_spec.MIN_PAGES_UPLOAD <= len(di) <= 828, f"{len(di)}ページ")
sizes = {(round(p.rect.width, 2), round(p.rect.height, 2)) for p in di}
check("本文のページの大きさが 判型の幅+0.125in・高さ+0.25in（裁ち落としあり）",
      sizes == {(round(TW + B, 2), round(TH + 2 * B, 2))}, str(sizes))
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
size_b = (pathlib.Path(INT).stat().st_size, pathlib.Path(COV).stat().st_size)
check("ファイルの大きさ（本文 650MB 未満・表紙 40MB 以下）", size_b[0] < 650e6 and size_b[1] < 40e6,
      f"本文 {size_b[0] / 1e6:.1f}MB / 表紙 {size_b[1] / 1e6:.2f}MB")
check("本文で透明（半透明・マスク）を使っていない", not alpha(di))
check("表紙で透明を使っていない", not alpha(dc))
exp_w = (0.25 + 2 * trim.width_in + kdp_spec.spine_width_in(len(di), "white", spec.ink)) * 72
check("表紙は1ページで、幅・高さが KDP の式どおり（A5・プレミアムカラーの背幅）",
      len(dc) == 1 and abs(dc[0].rect.width - exp_w) < 0.1 and abs(dc[0].rect.height - (TH + 2 * B)) < 0.1,
      f"{dc[0].rect.width / 72:.4f}×{dc[0].rect.height / 72:.4f}in")
raw_c = b"".join(dc.xref_stream(x) for x in dc[0].get_contents())
rgb = re.findall(rb"(?<![\w.])(?:[\d.]+\s+){3}(?:rg|RG)(?!\w)", raw_c)
check("表紙の色指定は CMYK だけ（RGB なし）", not rgb, f"RGB {len(rgb)}件")


def image_report(doc):
    out = []
    for p in doc:
        for im in p.get_images(full=True):
            cs = pymupdf.Pixmap(doc, im[0]).colorspace.name
            bbox = p.get_image_bbox(im)
            dpi = min(im[2] / (bbox.width / 72), im[3] / (bbox.height / 72))
            out.append((p.number + 1, cs, round(dpi)))
    return out


ci_rep, ii_rep = image_report(dc), image_report(di)
check("表紙の画像はすべて CMYK・300dpi 以上", all("CMYK" in c.upper() and d >= 299 for _, c, d in ci_rep), str(ci_rep))
ART_KEYS = [f"item{k:02d}" for k in range(1, 51)] + [f"chapter{k}" for k in range(1, 6)] + ["cover", "title"]
missing_art = [k for k in ART_KEYS if art_path(k) is None] if has_art() else []
pages_with_img = {n for n, _, _ in ii_rep}
no_img = [k + 1 for k in range(50) if has_art() and item_page(spec, k) not in pages_with_img]
check("本文の画像（挿絵・見方の見本）はすべて CMYK・300dpi 以上。挿絵57枚がそろい、50句すべてのページに載っている",
      ii_rep and all("CMYK" in c.upper() and d >= 299 for _, c, d in ii_rep) and not missing_art and not no_img,
      f"足りない挿絵 {missing_art} / 絵の無い句 {no_img}")
check("本文の文字は 7pt 以上", min(s["size"] for _, s in spans(di)) >= 6.99)
check("表紙の文字は 7pt 以上", min(s["size"] for _, s in spans(dc)) >= 6.99)
thin = [(p.number + 1, round(d["width"], 2)) for p in di for d in p.get_drawings()
        if d.get("type") in ("s", "fs") and d.get("width") and d["width"] < 0.74]
check("本文の線は 0.75pt 以上", not thin, str(thin[:4]))
out = []
for p, s in spans(di):
    n = p.number + 1
    x0 = 0 if n % 2 == 1 else B  # 奇数ページは右、偶数ページは左に裁ち落とし
    bx = s["bbox"]
    if bx[0] < x0 + SAFE - 0.5 or bx[2] > x0 + TW - SAFE + 0.5 or bx[1] < B + SAFE - 0.5 or bx[3] > B + TH - SAFE + 0.5:
        out.append((n, s["text"][:10]))
check("本文の文字がすべて仕上がり線から 0.375in 以上内側（奇数・偶数で裁ち落としの側を変えて判定）", not out, str(out[:4]))
spine = kdp_spec.spine_width_in(len(di), "white", spec.ink) * 72
back, front = (B, B + TW), (B + TW + spine, B + TW + spine + TW)
bad_c = [s["text"][:8] for _, s in spans(dc)
         if not (any(a + 18 <= s["bbox"][0] and s["bbox"][2] <= b - 18 for a, b in (back, front))
                 and B + 18 <= s["bbox"][1] and s["bbox"][3] <= B + TH - 18)]
check("表紙の文字が仕上がり線から 0.25in 以上内側（背にも文字なし）", not bad_c, str(bad_c[:4]))
bw, bh = (v * 72 for v in kdp_spec.BARCODE_BOX_IN)
box = pymupdf.Rect(back[1] - 18 - bw, B + TH - 18 - bh, back[1] - 18, B + TH - 18)
on_bar = [s["text"] for _, s in spans(dc) if pymupdf.Rect(s["bbox"]).intersects(box)]
check("裏表紙のバーコード欄（2×1.2in）に文字がない", not on_bar, str(on_bar))
boxes = [(pymupdf.Rect(s["bbox"]), s["text"]) for _, s in spans(dc)]
ov = [(a[1], b[1]) for i, a in enumerate(boxes) for b in boxes[i + 1:]
      if a[1] != b[1] and (a[0] & b[0]).width > 1 and (a[0] & b[0]).height > 1]
check("表紙の文字どうしが重ならない", not ov, str(ov[:2]))
folio_bad = []
for k in range(len(items)):
    n = item_page(spec, k)
    if str(n) not in [t.strip() for t in ptext(n).splitlines()]:
        folio_bad.append(n)
check("50句のページに、正しいページ番号が入っている", not folio_bad, str(folio_bad[:4]))
blank_run, run = 0, 0
for pg in di:
    run = run + 1 if not pg.get_text().strip() else 0
    blank_run = max(blank_run, run)
check("文字のないページが続かない（KDP の白紙の上限より十分少ない）", blank_run <= 1, f"最長 {blank_run}")

print("\n■ B. 中身の正しさ（確かめた記録と紙面を照らし合わせる）")
srcs = [it["src"] for it in items]
check("5章×10句＝50句で、確かめた記録の50件を重なりなく使っている",
      len(spec.chapters) == 5 and all(len(ch["items"]) == 10 for ch in spec.chapters)
      and len(set(srcs)) == 50 and set(srcs) == set(VER))
weak = [(no, k) for no, r in VER.items() for k, _ in LANGS
        if r[k]["match"] not in ("同じ", "近い") or len(set(r[k]["sources"])) < 2]
check("200の言い方すべてが「同じ」か「近い」で、出典の URL が2つ以上ある", not weak, str(weak[:4]))
miss = []
for k, it in enumerate(items):
    page = flat(ptext(item_page(spec, k))).replace("近い言い方", "")  # 原文の途中に札がはさまるため
    for lang, _ in LANGS:
        if flat(it[lang]["text"]) not in page:
            miss.append((k + 1, lang))
        if it[lang].get("trad") and flat(it[lang]["trad"]) not in page:  # 中国語は繁体字（確かめた記録の形）も添える
            miss.append((k + 1, lang + "-繁体字"))
check("200の言い方が、確かめた記録と一字ずつ同じ形で紙面に載っている（中国語は簡体字と繁体字）", not miss, str(miss[:4]))
near_bad = []
for k, it in enumerate(items):
    want = sum(1 for lang, _ in LANGS if it[lang]["near"])
    chips = [s for _, s in spans(di, {item_page(spec, k) - 1}) if s["text"].strip() == "近い言い方" and s["size"] < 8]
    if len(chips) != want:  # ひとくち話の文中の「近い言い方」は数えない
        near_bad.append(k + 1)
check("「近い言い方」の札が、記録で「近い」の言い方にだけ付いている", not near_bad, str(near_bad[:4]))
read_bad = [(k + 1, lang) for k, it in enumerate(items) for lang in ("zh", "ko")
            if not it[lang]["read"] or flat(it[lang]["read"]) not in flat(ptext(item_page(spec, k)))]
check("中国語のピンインと韓国語のカタカナの読みが、100件すべて載っている", not read_bad, str(read_bad[:4]))
lit_bad = [(k + 1, lang) for k, it in enumerate(items) for lang, _ in LANGS
           if flat(it[lang]["lit"]) not in flat(ptext(item_page(spec, k)))]
check("直訳（または漢字の書き方）が、200件すべて載っている", not lit_bad, str(lit_bad[:4]))
jp_bad = [k + 1 for k, it in enumerate(items)
          if not all(flat(x) in flat(ptext(item_page(spec, k))) for x in (it["jp"], it["kana"], it["mean"]))]
check("日本のことわざ・読みがな・意味が、それぞれのページに載っている", not jp_bad, str(jp_bad[:4]))
story_bad = [k + 1 for k, it in enumerate(items) if flat(it["story"]) not in flat(ptext(item_page(spec, k)))]
check("ひとくち話が、それぞれのページに載っている", not story_bad, str(story_bad[:4]))
kana_bad = [it["jp"] for it in items if not re.fullmatch(r"[ぁ-ゖー]+", it["kana"])]
check("読みがなは、すべてひらがなだけで書かれている", not kana_bad, str(kana_bad))
script_bad = [it["jp"] for it in items if re.search(r"[가-힣]", it["story"] + it["mean"])]
check("ひとくち話・意味に、日本語の書体に無いハングルを入れていない", not script_bad, str(script_bad))
same_bad = []
for it in items:
    for lang, name in LANGS:
        if re.search(rf"{name}[^。]*?(まったく同じ|そっくり同じ)", it["story"]) and it[lang]["near"]:
            same_bad.append((it["jp"], lang))
check("ひとくち話で「まったく同じ」と書いた言語は、記録でも「同じ」", not same_bad, str(same_bad))
no_bad = [k + 1 for k in range(len(items)) if f"{k + 1:02d}" not in ptext(item_page(spec, k)).split()]
check("句の番号（01〜50）が、それぞれのページで正しい", not no_bad, str(no_bad[:4]))
head_bad = [k + 1 for k, it in enumerate(items)
            if f"第{it['chapter'] + 1}章　{it['chapter_title']}" not in ptext(item_page(spec, k))]
check("句のページの柱（章の名前）が、その章のものになっている", not head_bad, str(head_bad[:4]))
order_bad = []
for k in range(len(items)):
    p = di[item_page(spec, k) - 1]
    ys = []
    for lang, _ in LANGS:
        hits = p.search_for(NATIVE[lang][0])
        ys.append(hits[0].y0 if hits else -1)
    if -1 in ys or ys != sorted(ys):
        order_bad.append(k + 1)
check("どのページも 英語→フランス語→中国語→韓国語 の順に並んでいる", not order_bad, str(order_bad[:4]))
ch_bad = []
for ci, ch in enumerate(spec.chapters):
    t = flat(ptext(chapter_page(spec, ci)))
    if flat(ch.get("intro", "-"))[:20] not in t:
        ch_bad.append((ci + 1, "導入文"))
    for k, lang, lit in chapter_quiz(items, ci):  # クイズの問い（直訳）と、こたえの句・ページ
        if flat(lit) not in t or flat(items[k]["jp"]) not in t or f"{item_page(spec, k)}ページ" not in t:
            ch_bad.append((ci + 1, items[k]["jp"]))
check("章の扉に導入文があり、クイズの問いとこたえ（句とページ）が本文と合っている", not ch_bad, str(ch_bad[:4]))
monkey = next(it for it in items if it["jp"] == "犬猿の仲")
intro = flat(ptext(2))
check("「はじめに」の4つの例文が、本文の「犬猿の仲」のページと同じ",
      all(flat(monkey[lang]["text"]) in intro for lang, _ in LANGS))
toc = ptext(5)
toc_bad = [ci + 1 for ci, ch in enumerate(spec.chapters) if ch["title"] not in toc or str(chapter_page(spec, ci)) not in toc]
toc_bad += [it["jp"] for k, it in enumerate(items)
            if not re.search(re.escape(it["jp"]) + r"\s*\n\s*" + str(item_page(spec, k)) + r"\b", toc)]
check("もくじに5章と50句がそろい、ページ番号が本文と一致", not toc_bad, str(toc_bad[:4]))
idx = ptext(len(di) - 4)
idx_bad = [it["jp"] for k, it in enumerate(items)
           if not re.search(re.escape(it["jp"]) + r"\s*\n\s*" + str(item_page(spec, k)) + r"\b", idx)]
check("さくいんに50句がすべて載り、ページ番号が本文と一致", not idx_bad, str(idx_bad[:3]))

print("\n■ C. 表記と一貫性（題名・名義・入力内容・表現）")
check("題名・副題が表紙・表題ページ・奥付で同じ",
      flat(spec.title) in flat(cover_text) and "世界ではこう言う" in ptext(1) and spec.title in colophon
      and spec.subtitle in cover_text)
check("発行者「つるはし社」が表紙・表題ページ・奥付にある", all("つるはし社" in x for x in (cover_text, ptext(1), colophon)))
fixed = cover_text + "".join(ptext(n) for n in (1, 2, 3, 4, 5, len(di) - 3, len(di) - 1, len(di)))
pii = [w for w in ("nami", "0817") if w in fixed.lower()]
check("個人を特定できる文字（nami・0817 など）が出ていない", not pii, str(pii))
tofu = [(i, n + 1) for i, d in enumerate((di, dc)) for n, p in enumerate(d) if "\x00" in p.get_text() or "�" in p.get_text()]
check("化けた字（書体に無い字）が本文・表紙のどこにもない", not tofu, str(tofu[:4]))
check("奥付に書体（OFL）と図版（挿絵があれば生成AI、なければ Noto Emoji）の出典がある", "Open Font License" in colophon
      and "Nanum Gothic" in colophon and "Noto Sans TC" in colophon and ("FLUX.1" in colophon if has_art() else "Noto Emoji" in colophon))
refs = ptext(len(di) - 1)
check("参考にした資料のページに5つの言語の資料がそろっている", all(x in refs for x in ("英語", "フランス語", "中国語", "韓国語", "日本語")))
check("入力内容の案：タイトル・サブタイトル・A5・裁ち落としあり・ページ数・価格の案が本体と一致",
      f"タイトル: {spec.title}" in LISTING and f"サブタイトル: {spec.subtitle}" in LISTING and "A5" in LISTING
      and "裁ち落としあり" in LISTING and f"{len(di)}ページ" in LISTING and "1,480" in LISTING)
check("入力内容に AI 申告（テキストは Claude、挿絵があれば画像は FLUX.1）と商標確認（J-PlatPat）の記録がある",
      "作品全体" in LISTING and "Claude" in LISTING and "J-PlatPat" in LISTING
      and (not has_art() or "画像「" in LISTING and "FLUX.1" in LISTING))
paste = LISTING[LISTING.index("## 内容紹介"):LISTING.index("## キーワード")]
quotes = re.findall(r"「([^」]+)」", paste)
qbad = [q for q in quotes if flat(q) not in flat(all_int) and q not in ("近い言い方",)]
check("内容紹介に書いた「」の言い回しが、本文に実際にある", not qbad, str(qbad[:4]))
claims = re.findall(r"脳トレ|認知症|最新|No\.?1|ナンバーワン|ベストセラー|完全版", paste + cover_text + fixed)
check("誇大な表現（最新・No.1・ベストセラー等）や「脳トレ」を使っていない", not claims, str(claims))

assert len(R) == 50, len(R)
ng = [r for r in R if not r[1]]
print(f"\n{len(R) - len(ng)}/{len(R)} 合格")
for n in ng:
    print("  NG:", n[0], n[2])
sys.exit(1 if ng else 0)
