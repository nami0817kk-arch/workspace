"""ことば探しの本の納品前点検（50項目）。projects/puzzle-book で  python tools/qa_kotoba.py

入稿の直前に必ず回す。KDP の入稿要件・中身の正しさ・表記の一貫性を、出来上がった PDF から確かめる。
"""
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "src"))
import pymupdf  # noqa: E402
from fontTools.ttLib import TTFont  # noqa: E402
from pypdf import PdfReader  # noqa: E402
from puzzle_generator import BLOCKED_WORDS, DIRS, WORDSEARCH_DIFFICULTIES, find_all, verify_wordsearch  # noqa: E402

import kdp_spec  # noqa: E402
from build_kotoba import COPY_PERMISSION, KotobaSpec, generate_puzzles, page_count  # noqa: E402

INT, COV = "output/kotoba-vol1-interior.pdf", "output/kotoba-vol1-cover.pdf"
LISTING = pathlib.Path("books/kotoba-vol1-listing.md").read_text(encoding="utf-8")
KDP_TITLE, KDP_SUB = "ゆったり ことば探し", "季節とくらしの、なつかしい言葉"
spec = KotobaSpec.load("books/kotoba-vol1.json")
recs = generate_puzzles(spec)
di, dc = pymupdf.open(INT), pymupdf.open(COV)
N = len(recs)
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


pages_problem = range(3, 3 + N)
pages_answer = range(3 + N, 3 + N + -(-N // 4))
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
except Exception as e:  # noqa: BLE001
    ok_open = False
check("別の読み取り器（pypdf）でも本文・表紙を正常に開ける", ok_open)
size_mb = (pathlib.Path(INT).stat().st_size, pathlib.Path(COV).stat().st_size)
check("ファイルの大きさ（本文 650MB 未満・表紙 40MB 以下の推奨）", size_mb[0] < 650e6 and size_mb[1] < 40e6,
      f"本文 {size_mb[0] / 1e6:.1f}MB / 表紙 {size_mb[1] / 1e6:.2f}MB")
check("本文で透明（半透明・マスク）を使っていない", not alpha(di))
check("表紙で透明を使っていない", not alpha(dc))
exp_w = (0.25 + 2 * trim.width_in + len(di) * kdp_spec.spine_width_in(1, "white", spec.ink)) * 72
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
for i in list(pages_problem) + list(pages_answer):
    last = di[i].get_text().strip().splitlines()[-1]
    if last != str(i + 1):
        folio_bad.append((i + 1, last))
check("問題・答えのページにノンブル（ページ番号）が正しく入っている", not folio_bad, str(folio_bad[:3]))

print("\n■ B. 中身の正しさ（問題・答え・言葉）")
check("60問すべてが検証を通る（どの語も8方向でちょうど1回）", N == 60 and all(verify_wordsearch(r) for r in recs))
mis = []
for r in recs:
    for pl in r["solution"]["placements"]:
        dx, dy = DIRS[pl["dir"]]
        got = "".join(r["board"]["grid"][pl["start"][1] + dy * i][pl["start"][0] + dx * i] for i in range(len(pl["answer"])))
        if got != pl["answer"]:
            mis.append(pl["answer"])
check("答えの位置の文字が、語と一文字ずつ一致", not mis, str(mis[:3]))
blk = [(r["board"]["theme"], w) for r in recs for w in BLOCKED_WORDS if find_all(r["board"]["grid"], w)
       and not any(w in pl["answer"] or w[::-1] in pl["answer"] for pl in r["solution"]["placements"])]
check("どの盤面にも不適切な語（死・暴言など）ができていない", not blk, str(blk[:3]))
hira = re.compile(r"^[ぁ-ゖー]$")
kata = re.compile(r"^[ァ-ヺー]$")
mixed = [t["theme"] for t, r in zip(spec.themes, recs)
         if not all((kata if t["script"] == "katakana" else hira).match(ch) for row in r["board"]["grid"] for ch in row)]
check("盤面の文字がテーマの文字の種類（ひらがな／カタカナ）でそろっている", not mixed, str(mixed))
lone = []
for r in recs:
    used = {(pl["start"][0] + DIRS[pl["dir"]][0] * i, pl["start"][1] + DIRS[pl["dir"]][1] * i)
            for pl in r["solution"]["placements"] for i in range(len(pl["answer"]))}
    lone += [r["board"]["theme"] for y, row in enumerate(r["board"]["grid"]) for x, ch in enumerate(row)
             if (x, y) not in used and ch in "ぁぃぅぇぉゃゅょっゎァィゥェォャュョッ"]
check("埋め草に小さい字（ゃ・っ）が単独で置かれていない", not lone, str(set(lone)))
cnt = {"easy": 6, "medium": 8, "hard": 10}
bad_n = [t["theme"] for t in spec.themes if len(t["words"]) != cnt[t["difficulty"]]
         or any(len(w["answer"]) > WORDSEARCH_DIFFICULTIES[t["difficulty"]]["size"] for w in t["words"])]
check("語の数が難易度どおり（6・8・10語）で、盤面に収まる長さ", not bad_n, str(bad_n))
order = [t["difficulty"] for t in spec.themes]
check("やさしい→ふつう→むずかしいの順で各20問",
      order == sorted(order, key=["easy", "medium", "hard"].index) and all(order.count(d) == 20 for d in cnt))
answers = [w["answer"] for t in spec.themes for w in t["words"]]
check("本全体で同じ語が二度出ない（480語）", len(answers) == len(set(answers)) == 480, f"{len(answers)}語")
where = {w["answer"]: t["theme"] for t in spec.themes for w in t["words"]}
sfx = [(a, b) for a in where for b in where if a != b and where[a] != where[b]
       and any(b == a + x for x in ("まき", "づけ", "やき", "しる", "じょう"))]
check("「ごぼう／ごぼうまき」型の重なりがない", not sfx, str(sfx))
lab = [w["label"] for t in spec.themes for w in t["words"] if not w["label"].startswith(w["answer"])]
check("一覧の表記（ラベル）が答えの語で始まっている", not lab, str(lab[:3]))
kanji = [re.search(r"（(.+)）", w["label"]).group(1) for t in spec.themes for w in t["words"] if "（" in w["label"]]
check("漢字の添え書きが本全体で重複しない", len(kanji) == len(set(kanji)))
th = [t["theme"] for t in spec.themes]
no_icon = [t["theme"] for t in spec.themes if not pathlib.Path(f"assets/emoji/emoji_u{t.get('icon', '')}.svg").exists()]
check("60テーマが重複なく、すべてに絵と思い出トークがある", len(set(th)) == 60 and not no_icon
      and all(t.get("talk") for t in spec.themes), str(no_icon))
sens = [t["talk"] for t in spec.themes if not t["talk"].endswith("？")
        or re.search(r"死|亡|病|戦争|介護|認知|別れ", t["talk"])]
check("思い出トークはすべて問いかけで、つらい話題（死・病気・戦争など）に触れない", not sens, str(sens))
gm = [i + 1 for i, r in enumerate(recs) if "".join(r["board"]["grid"][0]) not in di[3 + i].get_text().replace("\n", "")
      or "".join(r["board"]["grid"][0]) not in di[3 + N + i // 4].get_text().replace("\n", "")]
check("各問の盤面が、問題ページと答えのページで同じ", not gm, str(gm[:4]))
toc = di[2].get_text()
tb = []
for i, r in enumerate(recs):
    m = re.search(rf"{re.escape(r['board']['theme'])}\s*\n\s*(\d+)", toc)
    if not m or m.group(1) != str(4 + i):
        tb.append(i + 1)
check("もくじに60テーマが載り、ページ番号が本文と一致", not tb, str(tb[:4]))
rec_text = di[IDX_RECORD].get_text().replace("\n", "")
rb_ = [t for t in th if t not in rec_text]
check("できたこと記録に60テーマがすべて載っている", not rb_, str(rb_[:3]))
wl = []
for i, (t, r) in enumerate(zip(spec.themes, recs)):
    txt = di[3 + i].get_text().replace("\n", "")
    wl += [w["answer"] for w in t["words"] if w["answer"] not in txt]
check("各問ページの語の一覧に、その問の語がすべて載っている", not wl, str(wl[:3]))

print("\n■ C. 表記と一貫性（題名・名義・入力内容・表現）")
title_line = next((l.strip() for l in colophon.splitlines() if l.strip().startswith("ゆったり")), "")
check("題名・副題が表紙・表題・奥付で KDP に入れた値と一致", "ゆったり" in cover_text and "ことば探し" in cover_text
      and "ことば探し" in di[0].get_text() and title_line == KDP_TITLE and KDP_SUB in cover_text
      and KDP_SUB in di[0].get_text(), f"奥付='{title_line}'")
check("発行者「つるはし社」が表紙・表題・奥付にある", all("つるはし社" in x for x in (cover_text, di[0].get_text(), colophon)))
pii = [w for w in ("nami", "0817") if w in fixed_text.lower()] + (["なみ"] if re.search(r"(?<!たし)なみ", fixed_text) else [])
check("個人を特定できる文字（nami・0817 など）が盤面以外に出ていない", not pii, str(pii))
cm = [TTFont(f"assets/fonts/{n}").getBestCmap() for n in ("NotoSansJP-Regular.ttf", "NotoSansJP-Bold.ttf")]
tofu = {ch for ch in all_int_text + cover_text if not ch.isspace() and not all(ord(ch) in c for c in cm)}
check("字形が無い文字（四角に化ける字）がない", not tofu, str(sorted(tofu)))
check("奥付に図版の出典（Noto Emoji）がある", "Noto Emoji" in colophon)
check("コピー許可の範囲が奥付・裏表紙・入力内容に書いてある",
      all(l.strip("【】") in colophon.replace("\n", "") for l in COPY_PERMISSION[1:2])
      and "施設内のコピーOK" in cover_text and "コピーOK" in LISTING)
seals = ["全60問", "思い出", "トーク", "大きな", "文字", "オール", "カラー", "答え", "つき"]
check("表紙の札の文言（全60問・思い出トーク・大きな文字・オールカラー・答えつき）", all(s in cover_text for s in seals))
n480 = f"{len(answers)}語"
lst_ok = ("1,100" in LISTING and n480 in LISTING and n480 in cover_text and "思い出トーク" in LISTING)
check("入力内容の案：価格 1,100円・語数・思い出トークが本体と一致", lst_ok)
check("入力内容の案：タイトル・サブタイトルが KDP に入れた値と一致",
      f"タイトル: {KDP_TITLE}" in LISTING and f"サブタイトル: {KDP_SUB}" in LISTING)
paste = LISTING[LISTING.index("## 内容紹介"):LISTING.index("## カテゴリー")]  # 実際に貼り付ける部分だけを見る
claims = re.findall(r"認知症予防|予防になる|効果があ|効きます|治る|改善します|若返", paste + cover_text + fixed_text)
check("効き目をうたう表現（認知症予防・効果がある等）がない", not claims, str(claims))

assert len(R) == 50, len(R)
ng = [r for r in R if not r[1]]
print(f"\n{len(R) - len(ng)}/{len(R)} 合格")
for n in ng:
    print("  NG:", n[0], n[2])
