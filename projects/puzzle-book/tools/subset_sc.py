"""簡体字の書体（Noto Sans SC）を、本に載せる簡体字だけに絞る。

元の書体は1つ約10MBあり、リポジトリに置くには重い。中国語の50句は決まっているので、
使う字だけを残した書体を assets/fonts/NotoSansSC-*.ttf に置く。
句を足したり直したりしたら、元の可変書体を渡してこのスクリプトを回し直す
（化けた字は qa_sekai.py と test_build_sekai.py の字形の点検で見つかる）。

    python tools/subset_sc.py <NotoSansSC[wght].ttf>
"""
import json
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parent.parent
verified = json.loads((ROOT / "books" / "sekai-kotowaza-verified.json").read_text(encoding="utf-8"))
chars = set("，、。（）「」 ")
for r in verified:
    chars |= set(r["zh"].get("simp", ""))
text = "".join(sorted(chars))
for wght, name in ((400, "Regular"), (700, "Bold")):
    font = instancer.instantiateVariableFont(TTFont(sys.argv[1]), {"wght": wght})
    opts = subset.Options()
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    sub = subset.Subsetter(opts)
    sub.populate(text=text)
    sub.subset(font)
    out = ROOT / "assets" / "fonts" / f"NotoSansSC-{name}.ttf"
    font.save(out)
    print(out.name, out.stat().st_size, "bytes", len(text), "字")
