"""うなぎの回のセット 5 本の題名と概要欄(out/unagi/desc_*.txt と titles.json)。python episodes/unagi/make_desc.py [本編の動画ID]
数字と出典は 台本.md の冒頭の「出どころ」。映像の出典は assets/sources.json(使ったものだけ載せる)。"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "out" / "unagi"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {"long": "養殖うなぎも、始まりは天然の魚だった。稚魚1匹600円、60年で60分の1に減った理由",
          "s1": "重さ0.2グラムのうなぎの稚魚に、1匹600円の値が付いた理由 #shorts",
          "s2": "うなぎの完全養殖は2010年に成功。それでも天然の稚魚に頼る理由 #shorts",
          "s3": "うなぎが生まれる場所は、日本から2,000キロ先の海だった #shorts",
          "s4": "2000年のうなぎは16万トン。8割以上が輸入だった #shorts"}
LEAD = {"long": "うなぎは、なぜこんなに高くなったのか。水産庁の資料(2026年7月)と国の統計の数字で、うなぎの一生をたどって確かめました。",
        "s1": "シラスウナギ(うなぎの稚魚)の取引価格は、2018年に1キロ299万円。1キロは約5,000匹なので、1匹約600円です。",
        "s2": "水産庁の資料から、卵から育てたシラスウナギと、天然のシラスウナギの1匹あたりの値段を比べました。",
        "s3": "水産庁の資料「ニホンウナギの一生」から。",
        "s4": "水産庁の資料「我が国におけるウナギ供給量の推移」から。"}
SOURCES = """▼断り書き
※1匹あたりの値段・匹数は、シラスウナギ1匹を約0.2グラムとした計算です。
※かば焼きの値段は、総務省の東京都区部の年平均(100グラム)。調べる銘柄は年によって変わります。
※うなぎの絵の一部は AI で作ったイメージです(画面の右上に表示)。

▼出典
・水産庁「ウナギをめぐる状況と対策について」(2026年7月)
・水産庁「ウナギ稚魚採捕量の推移」「ウナギ供給量の推移」
・総務省統計局「主要品目の東京都区部小売価格(昭和25年〜平成22年)」"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#うなぎ #シラスウナギ #養殖 #なぜ #解説"""

src = json.loads((HERE / "assets" / "sources.json").read_text(encoding="utf-8"))
text = (HERE / "lines.py").read_text(encoding="utf-8")
used = {u + ".mp4" for u in re.findall(r'V\("(\w+)"', text)}
by = sorted({s["by"].strip() for k, s in src.items() if k in used and not s.get("ai") and s.get("site") == "Pexels"})
MEDIA = "▼映像(Pexels)\n" + "、".join(by)

for k, t in TITLES.items():
    body = [LEAD[k], ""]
    if k == "long":
        ch = OUT / "chapters.txt"
        body += ["▼目次", ch.read_text(encoding="utf-8").strip() if ch.exists() else "(書き出し後に入る)", ""]
    elif LONG_ID:
        body += ["▼本編", f"https://youtu.be/{LONG_ID}", ""]
    body += [SOURCES, "", MEDIA, "", FOOT]
    out = "\n".join(body) + "\n"
    assert "nami" not in out.lower() and "0817" not in out
    (OUT / f"desc_{k}.txt").write_text(out, encoding="utf-8")
(OUT / "titles.json").write_text(json.dumps(TITLES, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", len(by), "人:", "、".join(by))
