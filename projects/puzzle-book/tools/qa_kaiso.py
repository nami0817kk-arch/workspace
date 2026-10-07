"""思い出ばなしの本の納品前点検（50項目）。projects/puzzle-book で  python tools/qa_kaiso.py

入稿の直前に必ず回す。KDP の入稿要件・中身の正しさ・表記の一貫性を、出来上がった PDF から確かめる。
A（入稿要件）は qa_notore.py と同じ物差し。B は問いかけが紙面のどこにどう載ったかを PDF から読み直す。
"""
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "src"))
import pymupdf  # noqa: E402
from fontTools.ttLib import TTFont  # noqa: E402
from pypdf import PdfReader  # noqa: E402

import kdp_spec  # noqa: E402
from build_kaiso import COPY_PERMISSION, KaisoSpec, month_first_page, page_count, topic_page  # noqa: E402

INT, COV = "output/kaiso-vol1-interior.pdf", "output/kaiso-vol1-cover.pdf"
LISTING = pathlib.Path("books/kaiso-vol1-listing.md").read_text(encoding="utf-8")
KDP_TITLE, KDP_SUB = "ゆったり 思い出ばなし", "12か月・季節の問いかけ96"
SAD = r"死|亡|病|戦争|戦時|疎開|空襲|別れ|認知|介護|葬|災害|地震"
spec = KaisoSpec.load("books/kaiso-vol1.json")
di, dc = pymupdf.open(INT), pymupdf.open(COV)
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


def flat(i):
    return di[i].get_text().replace("\n", "")


IDX_MEMO, IDX_COLOPHON = len(di) - 2, len(di) - 1
all_int_text = "".join(p.get_text() for p in di)
fixed_pages = (0, 1, 2, 3, IDX_MEMO, IDX_COLOPHON)
fixed_text = dc[0].get_text() + "".join(di[i].get_text() for i in fixed_pages)
colophon = di[IDX_COLOPHON].get_text()
cover_text = dc[0].get_text()
topics = spec.topics

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
for i in range(1, len(di) - 1):  # 表題と奥付にはページ番号を入れない
    last = di[i].get_text().strip().splitlines()[-1]
    if last != str(i + 1):
        folio_bad.append((i + 1, last))
check("表題・奥付以外の全ページにノンブル（ページ番号）が正しく入っている", not folio_bad, str(folio_bad[:3]))

print("\n■ B. 中身の正しさ（紙面から読み直す）")
check("12か月が1月から順にそろい、どの月も話題8つ・話のたね3つずつ",
      [m["month"] for m in spec.months] == list(range(1, 13)) and all(len(m["topics"]) == 8 for m in spec.months)
      and all(len(t["tane"]) == 3 for t in topics))
qs = [t["q"] for t in topics]
tane = [s for t in topics for s in t["tane"]]
labels = [t["label"] for t in topics]
check("問いかけ96・話のたね288・話題名96が、本の中で1つも重ならない",
      len(set(qs)) == 96 and len(set(tane)) == 288 and len(set(labels)) == 96, f"{len(set(qs))}/{len(set(tane))}/{len(set(labels))}")
sad = [s for s in qs + tane + labels if re.search(SAD, s)]
check("問い・話のたね・話題名に、つらくなりやすい言葉（戦争・病気・死別・災害など）がない", not sad, str(sad[:3]))
others = [t["talk"] for t in json.loads(pathlib.Path("books/kotoba-vol1.json").read_text(encoding="utf-8"))["themes"]]
others += [d["talk"] for d in json.loads(pathlib.Path("books/notore-vol1.json").read_text(encoding="utf-8"))["days"]]
dup = set(qs + tane) & set(others)
check("ほかの2冊（ことば探し・あたまの体操）の「思い出トーク」と同じ問いを使っていない", not dup, str(dup))
check("問いかけは「？」か「。」で、話のたねは「？」で終わる",
      all(q.endswith(("？", "。")) for q in qs) and all(s.endswith("？") for s in tane))
miss = []
for mi, month in enumerate(spec.months):
    for ti, t in enumerate(month["topics"]):
        txt = flat(topic_page(spec, mi, ti) - 1)
        if t["q"] not in txt or not all(s in txt for s in t["tane"]) or t["label"] not in txt:
            miss.append(t["label"])
check("96の問いかけ・話のたね・話題名が、それぞれ決まったページにそのまま印刷されている", not miss, str(miss[:3]))
bad_cov = []
for mi, month in enumerate(spec.months):
    txt = flat(month_first_page(spec, mi) - 1)
    for ti, t in enumerate(month["topics"]):
        if f"{month['month']}-{ti + 1}" not in txt or t["label"] not in txt or f"{topic_page(spec, mi, ti)}ページ" not in txt:
            bad_cov.append((month["month"], t["label"]))
check("月の扉に8つの話題名・番号・ページ番号が載り、本文のページと一致", not bad_cov, str(bad_cov[:3]))
toc = di[3].get_text()
bad_toc = [m["month"] for mi, m in enumerate(spec.months)
           if not re.search(rf"{m['month']}月\n{re.escape(m['season'])}\n[\s\S]*?\n{month_first_page(spec, mi)}\n", toc)]
check("もくじの12か月の季節名とページ番号が、月の扉のページと一致", not bad_toc, str(bad_toc))
bad_band = []
for mi, month in enumerate(spec.months):
    for p in range(month_first_page(spec, mi), month_first_page(spec, mi) + 4):
        txt = di[p].get_text()
        if not txt.startswith(f"{month['month']}月　{month['season']}\n{month['old_name']}"):
            bad_band.append(p + 1)
check("話題ページの帯（「N月　季節」と旧暦の月名）が、その月のものになっている", not bad_band, str(bad_band[:3]))
nums = [f"{m['month']}-{k + 1}" for m in spec.months for k in range(8)]
bad_no = [n for n in nums if all_int_text.count(n) < 2]
check("話題の番号（1-1〜12-8）が、月の扉と話題ページの両方に出ている", not bad_no, str(bad_no[:3]))
write_bad = []
for mi in range(12):
    for p in range(month_first_page(spec, mi), month_first_page(spec, mi) + 4):
        txt = di[p].get_text()
        if txt.count("聞いたこと・思い出したこと") != 2 or txt.count("話した日") != 2 or txt.count("話のたね") != 2:
            write_bad.append(p + 1)
check("話題ページごとに、話のたねの箱と書きとめる欄（話した日つき）が2つずつある", not write_bad, str(write_bad[:3]))
head_bad = [ln for p in di for ln in p.get_text().splitlines() if ln[:1] in "、。？！」）"]
check("行の頭に句読点・閉じかっこが来ていない（折り返しの確認）", not head_bad, str(head_bad[:3]))
icons = [t["icon"] for t in topics] + [m["cover_icon"] for m in spec.months]
no_icon = [c for c in icons if not pathlib.Path(f"assets/emoji/emoji_u{c}.svg").exists()]
check("絵がすべて手元にあり、話題の絵96種・月の顔12種がそれぞれ重ならない",
      not no_icon and len(set(icons[:96])) == 96 and len(set(icons[96:])) == 12, str(no_icon))
howto = di[1].get_text() + di[2].get_text()
check("使い方（ご家族の方へ・施設の方へ）と、話をするときの心がけ5つが載っている",
      "ご家族の方へ" in howto and "介護施設・デイサービスの方へ" in howto and "話をするときの心がけ" in howto
      and all(str(k) in di[2].get_text() for k in range(1, 6)))
memo = di[IDX_MEMO]
check("巻末に「思い出メモ」があり、書きこむ罫線が引いてある",
      "思い出メモ" in memo.get_text() and sum(1 for d in memo.get_drawings() for it in d["items"] if it[0] == "l") >= 15)

print("\n■ C. 表記と一貫性（題名・名義・入力内容・表現）")
title_line = next((l.strip() for l in colophon.splitlines() if l.strip().startswith("ゆったり")), "")
check("題名・副題が表紙・表題・奥付で KDP に入れる値と一致",
      KDP_SUB in cover_text.replace("\n", "") and "思い出ばなし" in cover_text and "思い出ばなし" in di[0].get_text()
      and "12か月" in di[0].get_text() and "季節の問いかけ96" in di[0].get_text() and title_line == KDP_TITLE,
      f"奥付='{title_line}'")
check("発行者「つるはし社」が表紙・表題・奥付にある", all("つるはし社" in x for x in (cover_text, di[0].get_text(), colophon)))
pii = [w for w in ("nami", "0817") if w in fixed_text.lower()] + (["なみ"] if re.search(r"(?<!たし)(?<!ら)なみ", fixed_text) else [])
check("個人を特定できる文字（nami・0817 など）が出ていない", not pii, str(pii))
cm = [TTFont(f"assets/fonts/{n}").getBestCmap() for n in ("NotoSansJP-Regular.ttf", "NotoSansJP-Bold.ttf")]
tofu = {ch for ch in all_int_text + cover_text if not ch.isspace() and not all(ord(ch) in c for c in cm)}
check("字形が無い文字（四角に化ける字）がない", not tofu, str(sorted(tofu)))
check("奥付に図版の出典（Noto Emoji）がある", "Noto Emoji" in colophon)
check("コピー許可の範囲が奥付・裏表紙・入力内容に書いてある",
      all(l.strip("【】") in colophon.replace("\n", "") for l in COPY_PERMISSION[1:2])
      and "施設内のコピーOK" in cover_text and "コピーOK" in LISTING)
seals = ["12か月", "96の", "問いかけ", "話の", "たねつき", "書きこみ", "欄つき", "オール", "カラー"]
check("表紙の札の文言（12か月・96の問いかけ・話のたねつき・書きこみ欄つき・オールカラー）", all(s in cover_text for s in seals))
ex = [spec.months[0]["topics"][0]["q"], spec.months[6]["topics"][0]["q"], spec.months[9]["topics"][1]["q"]]
check("裏表紙の「問いかけの例」3つが、本文の問いかけと一字一句同じ", all(q in cover_text.replace("\n", "") for q in ex))
check("入力内容の案：タイトル・サブタイトル・価格 1,100円・ページ数が本体と一致",
      f"タイトル: {KDP_TITLE}" in LISTING and f"サブタイトル: {KDP_SUB}" in LISTING and "1,100" in LISTING
      and f"{len(di)}ページ" in LISTING)
paste = LISTING[LISTING.index("## 内容紹介"):LISTING.index("## キーワード")]  # 実際に貼り付ける部分だけを見る
claims = re.findall(r"認知症予防|予防になる|効果があ|効きます|治る|改善します|若返|脳トレ", paste + cover_text + fixed_text)
check("効き目をうたう表現（認知症予防・効果がある等）や「脳トレ」（商標）がない", not claims, str(claims))
check("内容紹介の例文が本文の問いかけ・話のたねと一致（「」の中）",
      all(e in qs + tane for e in re.findall(r"例:「(.+?)」", paste)), str(re.findall(r"例:「(.+?)」", paste)))
check("入力内容に AI 申告（テキスト・作品全体・Claude）と商標確認（J-PlatPat）の記録がある",
      "作品全体" in LISTING and "Claude" in LISTING and "J-PlatPat" in LISTING)

assert len(R) == 50, len(R)
ng = [r for r in R if not r[1]]
print(f"\n{len(R) - len(ng)}/{len(R)} 合格")
for n in ng:
    print("  NG:", n[0], n[2])
sys.exit(1 if ng else 0)
