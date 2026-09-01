"""docparse のテスト共通設定。

読み取り部分（pdfplumber）は差し替えでテストする。加えて、
**本物の PDF を1つその場で組み立てて**、実際に読めるところまで確かめる
（PDF を読む道具なのに、PDF を1度も読まないテストでは意味がない）。
"""

from __future__ import annotations

import pytest


def build_pdf(lines: list[str]) -> bytes:
    """文字の入った1ページの PDF を組み立てる（外部ライブラリを使わない）。

    xref のバイト位置がずれると PDF として開けないので、実際に書いた位置から数える。
    """
    content = "BT /F1 14 Tf 72 720 Td 18 TL\n"
    for index, line in enumerate(lines):
        escaped = line.replace("(", r"\(").replace(")", r"\)")
        content += f"({escaped}) Tj\n" if index == 0 else f"T* ({escaped}) Tj\n"
    content += "ET"
    stream = content.encode("latin-1")

    objects = [
        b"<</Type/Catalog/Pages 2 0 R>>",
        b"<</Type/Pages/Kids[3 0 R]/Count 1>>",
        b"<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]"
        b"/Resources<</Font<</F1 5 0 R>>>>/Contents 4 0 R>>",
        b"<</Length " + str(len(stream)).encode() + b">>stream\n" + stream + b"\nendstream",
        b"<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>",
    ]

    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for number, body in enumerate(objects, 1):
        offsets.append(len(out))
        # 区切りの改行を省くと endstream と endobj がくっついて読めなくなる
        out += f"{number} 0 obj\n".encode() + body + b"\nendobj\n"

    xref_at = len(out)
    out += f"xref\n0 {len(objects) + 1}\n".encode()
    out += b"0000000000 65535 f \n"
    for offset in offsets:
        out += f"{offset:010d} 00000 n \n".encode()
    out += f"trailer<</Size {len(objects) + 1}/Root 1 0 R>>\nstartxref\n{xref_at}\n%%EOF\n".encode()
    return bytes(out)


@pytest.fixture
def sample_pdf(tmp_path):
    """本物の PDF（1ページ・文字入り）。"""
    path = tmp_path / "sample.pdf"
    path.write_bytes(build_pdf(["Operating income 1,234", "Net income -567"]))
    return path


@pytest.fixture
def fake_extractor():
    """読み取り部分の差し替え。ページの生データをそのまま返す。"""

    def make(pages):
        def extractor(_path, wanted=None):
            for raw in pages:
                if wanted and raw["number"] not in wanted:
                    continue
                yield raw

        return extractor

    return make
