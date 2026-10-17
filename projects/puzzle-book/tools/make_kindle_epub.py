"""紙の本の PDF から、Kindle 用の固定レイアウト EPUB を作る。projects/puzzle-book で

    python tools/make_kindle_epub.py sekai-kotowaza-vol1

output/<名前>-interior.pdf の各ページを、仕上がり線で切って（裁ち落としを捨てて）画像にし、
1ページ＝1画像の固定レイアウト（rendition:layout pre-paginated・左から右）の EPUB3 にまとめる。
表紙は output/<名前>-cover.pdf の表側を切り出して、EPUB の表紙と KDP に別に上げる表紙画像（JPEG）にする。
絵と色が多い本なので、文字を流し込む形ではなく、紙の本と同じ見た目を保つ形にしている。
"""
import io
import json
import sys
import uuid
import zipfile
from datetime import date
from pathlib import Path

import pymupdf
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))
import kdp_spec  # noqa: E402

PAGE_H = 2048  # 1ページの画像の高さ（Kindle の固定レイアウトで推奨される高解像度）
COVER_H = 2560  # KDP に上げる表紙画像の高さ（推奨は長辺2,560px）


def jpeg(img: Image.Image, quality: int) -> bytes:
    out = io.BytesIO()
    img.convert("RGB").save(out, "JPEG", quality=quality, optimize=True, progressive=True)
    return out.getvalue()


def render(page: pymupdf.Page, clip: pymupdf.Rect, height: int) -> Image.Image:
    zoom = height / clip.height
    pm = page.get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), clip=clip, colorspace=pymupdf.csRGB)
    return Image.frombytes("RGB", (pm.width, pm.height), pm.samples)


def main() -> None:
    stem = sys.argv[1] if len(sys.argv) > 1 else "sekai-kotowaza-vol1"
    spec = json.loads(Path(f"books/{stem}.json").read_text(encoding="utf-8"))
    title, publisher = spec["title"], spec.get("publisher", "つるはし社")
    trim = kdp_spec.TRIMS[spec.get("trim", "a5")]
    B = kdp_spec.COVER_BLEED_IN * 72
    tw, th = trim.width_in * 72, trim.height_in * 72
    interior = pymupdf.open(f"output/{stem}-interior.pdf")
    cover = pymupdf.open(f"output/{stem}-cover.pdf")[0]

    pages = []
    for p in interior:
        n = p.number + 1
        x0 = 0 if n % 2 == 1 else B  # 奇数ページは右、偶数ページは左に裁ち落としがある
        clip = pymupdf.Rect(x0, B, x0 + tw, B + th)
        pages.append(jpeg(render(p, clip, PAGE_H), 80))
    W, H = render(interior[0], pymupdf.Rect(0, B, tw, B + th), PAGE_H).size

    # 表紙の表側（右半分）を仕上がりで切り出す
    cw = cover.rect.width
    front = pymupdf.Rect(cw - B - tw, B, cw - B, B + th)
    cover_img = render(cover, front, COVER_H)
    Path("output").mkdir(exist_ok=True)
    Path(f"output/{stem}-kindle-cover.jpg").write_bytes(jpeg(cover_img, 90))
    cover_small = jpeg(render(cover, front, PAGE_H), 85)

    book_id = f"urn:uuid:{uuid.uuid5(uuid.NAMESPACE_URL, 'tsuruhashi/' + stem)}"
    today = date.today().isoformat()
    toc = spec.get("kindle_toc", [])  # [[見出し, ページ番号], ...]（無ければ表紙だけ）

    def page_xhtml(img: str, n: int) -> str:
        return (f'<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n'
                f'<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja">\n'
                f'<head><meta charset="UTF-8"/><title>{title} {n}</title>\n'
                f'<meta name="viewport" content="width={W}, height={H}"/>\n'
                f'<style>html,body{{margin:0;padding:0;width:{W}px;height:{H}px}}img{{width:{W}px;height:{H}px;display:block}}</style>\n'
                f'</head><body><img src="images/{img}" alt="{n}ページ"/></body></html>\n')

    manifest, spine = [], []
    with zipfile.ZipFile(f"output/{stem}-kindle.epub", "w") as z:
        z.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        z.writestr("META-INF/container.xml",
                   '<?xml version="1.0" encoding="UTF-8"?>\n<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
                   '<rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>\n',
                   compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("OEBPS/images/cover.jpg", cover_small)
        manifest.append('<item id="cover-image" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/>')
        z.writestr("OEBPS/cover.xhtml", page_xhtml("cover.jpg", 0), compress_type=zipfile.ZIP_DEFLATED)
        manifest.append('<item id="cover" href="cover.xhtml" media-type="application/xhtml+xml"/>')
        spine.append('<itemref idref="cover" properties="rendition:page-spread-center"/>')
        for i, data in enumerate(pages, start=1):
            img, xh = f"p{i:03d}.jpg", f"p{i:03d}.xhtml"
            z.writestr(f"OEBPS/images/{img}", data)
            z.writestr(f"OEBPS/{xh}", page_xhtml(img, i), compress_type=zipfile.ZIP_DEFLATED)
            manifest.append(f'<item id="img{i:03d}" href="images/{img}" media-type="image/jpeg"/>')
            manifest.append(f'<item id="p{i:03d}" href="{xh}" media-type="application/xhtml+xml"/>')
            side = "page-spread-right" if i % 2 == 1 else "page-spread-left"
            spine.append(f'<itemref idref="p{i:03d}" properties="{side}"/>')
        nav_items = "".join(f'<li><a href="p{int(pg):03d}.xhtml">{label}</a></li>' for label, pg in toc)
        z.writestr("OEBPS/nav.xhtml",
                   '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n'
                   '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja">'
                   f'<head><meta charset="UTF-8"/><title>{title}</title></head><body>'
                   f'<nav epub:type="toc" id="toc"><h1>もくじ</h1><ol><li><a href="cover.xhtml">表紙</a></li>{nav_items}</ol></nav>'
                   '<nav epub:type="landmarks" hidden=""><ol>'
                   '<li><a epub:type="cover" href="cover.xhtml">表紙</a></li>'
                   '<li><a epub:type="bodymatter" href="p001.xhtml">本文</a></li></ol></nav>'
                   '</body></html>\n', compress_type=zipfile.ZIP_DEFLATED)
        manifest.append('<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>')
        opf = ('<?xml version="1.0" encoding="UTF-8"?>\n'
               '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" xml:lang="ja" '
               'prefix="rendition: http://www.idpf.org/vocab/rendition/#">\n'
               '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
               f'<dc:identifier id="bookid">{book_id}</dc:identifier>\n'
               f'<dc:title>{title}</dc:title>\n<dc:creator>{publisher}</dc:creator>\n<dc:publisher>{publisher}</dc:publisher>\n'
               f'<dc:language>ja</dc:language>\n<meta property="dcterms:modified">{today}T00:00:00Z</meta>\n'
               '<meta property="rendition:layout">pre-paginated</meta>\n'
               '<meta property="rendition:orientation">portrait</meta>\n'
               '<meta property="rendition:spread">landscape</meta>\n'
               '<meta name="cover" content="cover-image"/>\n'
               '<meta name="fixed-layout" content="true"/>\n'
               f'<meta name="original-resolution" content="{W}x{H}"/>\n'
               '<meta name="primary-writing-mode" content="horizontal-lr"/>\n'
               '<meta name="orientation-lock" content="portrait"/>\n'
               '</metadata>\n<manifest>\n' + "\n".join(manifest) + '\n</manifest>\n'
               '<spine page-progression-direction="ltr">\n' + "\n".join(spine) + '\n</spine>\n</package>\n')
        z.writestr("OEBPS/content.opf", opf, compress_type=zipfile.ZIP_DEFLATED)
    size = Path(f"output/{stem}-kindle.epub").stat().st_size
    print(f"{len(pages)}ページ・{W}x{H}px・{size / 1e6:.1f}MB -> output/{stem}-kindle.epub")
    print(f"表紙 {cover_img.size[0]}x{cover_img.size[1]}px -> output/{stem}-kindle-cover.jpg")


if __name__ == "__main__":
    main()
