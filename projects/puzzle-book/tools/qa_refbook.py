"""図鑑・辞典（金属とレアメタルの図鑑・世界の通貨じてん）の納品前点検。projects/puzzle-book で

    python tools/qa_refbook.py metals
    python tools/qa_refbook.py currency

入稿の直前に必ず回す。KDP の入稿要件（裁ち落としあり）・データとの一致・表記を、出来上がった PDF から確かめる。
"""
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "src"))
import pymupdf  # noqa: E402
from pypdf import PdfReader  # noqa: E402

import kdp_spec  # noqa: E402

BOOK = sys.argv[1] if len(sys.argv) > 1 else "metals"
if BOOK == "metals":
    import build_metals as bm  # noqa: E402

    spec = bm.MetalsSpec.load("books/metals-vol1.json")
    items, _meta = bm.load_metals(spec)
    page_count, item_page, chapters = bm.page_count, bm.item_page, bm.chapters
    key = "metals"
    label = lambda x: x["name"]  # noqa: E731
else:
    import build_currency as bm  # noqa: E402

    spec = bm.CurrencySpec.load("books/currency-vol1.json")
    items, _meta = bm.load_currencies(spec)
    page_count, item_page, chapters = bm.page_count, bm.item_page, bm.chapters
    key = "currency"
    label = lambda x: x["name"]  # noqa: E731

INT, COV = f"output/{key}-vol1-interior.pdf", f"output/{key}-vol1-cover.pdf"
LISTING = pathlib.Path(f"books/{key}-vol1-listing.md").read_text(encoding="utf-8")
di, dc = pymupdf.open(INT), pymupdf.open(COV)
trim = kdp_spec.TRIMS[spec.trim]
B = kdp_spec.COVER_BLEED_IN * 72
TW, TH = trim.width_in * 72, trim.height_in * 72
SAFE = 0.375 * 72
R = []


def check(name, ok, detail=""):
    R.append((name, bool(ok), detail))
    print(f"{len(R):>2}. {'OK' if ok else 'NG'}  {name}  {detail}")


def spans(doc):
    for p in doc:
        for b in p.get_text("dict")["blocks"]:
            for ln in b.get("lines", []):
                for s in ln["spans"]:
                    if s["text"].strip():
                        yield p, s


def flat(text):
    return re.sub(r"\s+", "", text)


print(f"■ A. KDP の入稿要件（{spec.title}）")
n = len(di)
check("本文のページ数が設計どおり・KDP の最小（72）以上", n == page_count(items) and n >= kdp_spec.MIN_PAGES_UPLOAD, f"{n}ページ")
sizes = {(round(p.rect.width, 2), round(p.rect.height, 2)) for p in di}
check("本文の大きさが 判型の幅+0.125in・高さ+0.25in", sizes == {(round(TW + B, 2), round(TH + 2 * B, 2))}, str(sizes))
check("本文・表紙の書体がすべて埋め込み",
      not {f[3] for d in (di, dc) for p in d for f in p.get_fonts() if f[1] == "n/a"})
ok_open = True
try:
    PdfReader(INT).pages[0], PdfReader(COV).pages[0]
except Exception:  # noqa: BLE001
    ok_open = False
check("暗号化なし・別の読み取り器（pypdf）でも開ける", ok_open and not di.is_encrypted and not dc.is_encrypted)
sb = (pathlib.Path(INT).stat().st_size, pathlib.Path(COV).stat().st_size)
check("ファイルの大きさ（本文 650MB 未満・表紙 40MB 以下）", sb[0] < 650e6 and sb[1] < 40e6, f"{sb[0] / 1e6:.1f}MB / {sb[1] / 1e6:.2f}MB")
exp_w = (0.25 + 2 * trim.width_in + kdp_spec.spine_width_in(n, "white", spec.ink)) * 72
check("表紙の幅・高さが KDP の式どおり", len(dc) == 1 and abs(dc[0].rect.width - exp_w) < 0.1
      and abs(dc[0].rect.height - (TH + 2 * B)) < 0.1, f"{dc[0].rect.width / 72:.4f}in")
raw = b"".join(d.xref_stream(x) for d in (di, dc) for p in d for x in p.get_contents())
rgb = re.findall(rb"(?<![\w.])(?:[\d.]+\s+){3}(?:rg|RG)(?!\w)", raw)
check("本文・表紙の色指定は CMYK だけ（RGB なし）", not rgb, f"RGB {len(rgb)}件")
imgs = []
for d in (di, dc):
    for p in d:
        for im in p.get_images(full=True):
            cs = pymupdf.Pixmap(d, im[0]).colorspace.name
            bbox = p.get_image_bbox(im)
            dpi = min(im[2] / (bbox.width / 72), im[3] / (bbox.height / 72)) if bbox.width else 999
            imgs.append((p.number + 1, cs, round(dpi)))
bad_img = [x for x in imgs if "CMYK" not in x[1].upper() or x[2] < 299]
check("画像はすべて CMYK・300dpi 以上", not bad_img, str(bad_img[:4]) + f"（全{len(imgs)}枚）")
check("文字は 7pt 以上（本文・表紙）", min(s["size"] for d in (di, dc) for _, s in spans(d)) >= 6.79)
out = []
for p, s in spans(di):
    x0 = 0 if (p.number + 1) % 2 == 1 else B
    a, b_, c_, d_ = s["bbox"]
    if a < x0 + SAFE - 0.5 or c_ > x0 + TW - SAFE + 0.5 or b_ < B + SAFE - 0.5 or d_ > B + TH - SAFE + 0.5:
        out.append((p.number + 1, s["text"][:8]))
check("本文の文字はすべて仕上がりから 0.375in 以上内側", not out, str(out[:4]))
cs_ = kdp_spec.COVER_SAFE_IN * 72
cw = dc[0].rect.width
spine_w = kdp_spec.spine_width_in(n, "white", spec.ink) * 72
bad_c = []
for _, s in spans(dc):
    a, b_, c_, d_ = s["bbox"]
    in_back = c_ <= B + TW
    lo, hi = (B + cs_, B + TW - cs_) if in_back else (B + TW + spine_w + cs_, cw - B - cs_)
    if a < lo - 0.5 or c_ > hi + 0.5 or b_ < B + cs_ - 0.5 or d_ > B + TH - cs_ + 0.5:
        bad_c.append(s["text"][:8])
check("表紙の文字は安全域の内側", not bad_c, str(bad_c[:4]))
bw, bh = (v * 72 for v in kdp_spec.BARCODE_BOX_IN)
box = pymupdf.Rect(B + TW - cs_ - bw, B + TH - cs_ - bh, B + TW - cs_, B + TH - cs_)
on_bar = [s["text"] for _, s in spans(dc) if pymupdf.Rect(s["bbox"]).intersects(box)]
check("裏表紙のバーコード欄に何も重なっていない", not on_bar, str(on_bar[:3]))
tofu = [(i, p.number + 1) for i, d in enumerate((di, dc)) for p in d if "\x00" in p.get_text() or "�" in p.get_text()]
check("化けた字（書体に無い字）がない", not tofu, str(tofu[:4]))
nums = [p.number + 1 for p in di if str(p.number + 1) not in p.get_text().split()]
expect_blank = {1, n} | {bm.chapter_page(items, ci) for ci in range(len(chapters(items)))}
check("ページ番号が入っていないのは表題・章扉・奥付だけ", set(nums) <= expect_blank, str(sorted(set(nums) - expect_blank)[:5]))

print("■ B. データと紙面の一致")
missing = [label(x) for k, x in enumerate(items) if flat(label(x)) not in flat(di[item_page(items, k) - 1].get_text())]
check(f"{len(items)}項目すべてが、決まったページに載っている", not missing, str(missing[:4]))
weak = [label(x) for x in items if len(set(x.get("sources") or [])) < 2]
check("どの項目にも出典の URL が2つ以上ある", not weak, str(weak[:4]))
toc = di[bm.FRONT_PAGES - 1].get_text()
toc_bad = [label(x) for k, x in enumerate(items) if label(x) not in toc and re.sub(r"（.*?）", "", label(x)) not in toc]
check("もくじに全項目がある", not toc_bad, str(toc_bad[:4]))
idx_text = "".join(di[i].get_text() for i in range(n - bm.BACK_PAGES, n))
idx_bad = [label(x) for k, x in enumerate(items) if str(item_page(items, k)) not in idx_text]
check("さくいんに全項目のページ番号がある", not idx_bad, str(idx_bad[:4]))
if BOOK == "metals":
    over = [x["name"] for x in items if sum(t.get("share_percent") or 0 for t in (x.get("producers") or {}).get("top3") or []) > 100.5]
    check("産出国の割合の合計が100%をこえない", not over, str(over))
    srcs = {(x.get("producers") or {}).get("source", "") for x in items}
    check("産出国の出典が記録されている（USGS ほか）", all(srcs) and any("USGS" in s for s in srcs), str(srcs)[:80])
    cred = pathlib.Path("assets/metals-photos/credits.json")
    credits = json.loads(cred.read_text(encoding="utf-8")) if cred.exists() else []
    no_photo = [x["name"] for x in items if bm.photo_path(x) is None]
    check("55種すべてに写真がある", not no_photo, f"写真なし {len(no_photo)}件 {no_photo[:4]}")
    bad_lic = [c["file"] for c in credits if not re.search(r"CC BY|CC0|Public domain|PD|Free Art|FAL|GFDL", c.get("license", ""), re.I)
               or re.search(r"NC|ND", c.get("license", ""))]
    check("写真のライセンスが商用・改変不要で使えるもの（NC・ND なし）", credits and not bad_lic, str(bad_lic[:4]))
    cpage = di[n - 2].get_text()
    cr_bad = [c["file"] for c in credits if flat(c.get("author", ""))[:6] not in flat(cpage)]
    check("写真の出典のページに、全写真の作者が載っている", credits and not cr_bad, str(cr_bad[:4]))
else:
    dates = {(x.get("rate_now") or {}).get("date") for x in items if x["code"] != "JPY"}
    check("為替の日付が全通貨でそろっている", len(dates) == 1, str(dates))
    norate = [x["code"] for x in items if x["code"] != "JPY" and not (x.get("rate_now") or {}).get("yen")]
    check("日本円以外の全通貨に為替の値と出典がある", not norate and all((x.get("rate_now") or {}).get("source") for x in items if x["code"] != "JPY"), str(norate))
    date = next(iter(dates)).replace("-", "/")
    pages_bad = [x["code"] for k, x in enumerate(items) if x["code"] != "JPY" and date not in di[item_page(items, k) - 1].get_text()]
    check("各ページに為替の日付が出ている", not pages_bad, str(pages_bad[:4]))
    flags_bad = [f for x in items for f in x["flags"] if not (bm.FLAG_DIR / f"{f}.svg").exists()]
    check("国旗の絵がすべてある", not flags_bad, str(flags_bad))
    check("奥付に国旗の出典（flag-icons・MIT）がある", "flag-icons" in di[n - 1].get_text())

print("■ C. 表記と出品メモ")
check("出品メモのタイトル・サブタイトルが本と一致",
      f"タイトル: {spec.title}" in LISTING and f"サブタイトル: {spec.subtitle}" in LISTING)
check("表紙に題名・副題・発行者がある",
      flat(spec.title) in flat(dc[0].get_text()) and flat(spec.publisher) in flat(dc[0].get_text()))
check("奥付に題名・発行者・初版の日付がある",
      spec.title in di[n - 1].get_text() and spec.publisher in di[n - 1].get_text() and "初版発行" in di[n - 1].get_text())
check("出品メモに商標の確認（J-PlatPat）と AI 申告がある", "J-PlatPat" in LISTING and "AI 生成" in LISTING)
check(f"出品メモのページ数が本と一致（{n}ページ）", f"{n}ページ" in LISTING)
alltext = "".join(p.get_text() for p in di) + dc[0].get_text() + LISTING
pii = [w for w in ("nami", "0817") if w in alltext]
check("個人を特定できる文字が出ていない", not pii, str(pii))
hype = re.findall(r"最新版|No\.?1|ナンバーワン|ベストセラー|完全版|決定版", alltext)
check("誇大な表現を使っていない", not hype, str(hype[:3]))

ng = [r for r in R if not r[1]]
print(f"\n{len(R) - len(ng)}/{len(R)} 合格")
for r in ng:
    print("  NG:", r[0], r[2])
sys.exit(1 if ng else 0)
