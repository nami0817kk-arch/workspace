"""バナナの回のセット 6 本の題名と概要欄(out/banana/desc_*.txt と titles.json)。python episodes/banana/make_desc.py [本編の動画ID]
数字と出典は 台本.md の冒頭の「出どころ」。映像の出典は assets/sources.json(使ったものだけ載せる)。"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "out" / "banana"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {"long": "バナナには、なぜ種がないのか。野生のバナナは種だらけ、店のバナナはぜんぶ同じ1本の分身だった",
          "s1": "バナナの真ん中の黒い点は、消えた種のなごりだった #shorts",
          "s2": "世界のバナナは1,000種以上。店のバナナは、ほぼ1つの品種 #shorts",
          "s3": "70年前のバナナは別の品種だった。病気で消えたグロスミッシェル #shorts",
          "s4": "今のバナナも枯れ始めている。土の中で数十年眠るカビ TR4 #shorts",
          "s5": "病気に強いバナナの遺伝子は、食べられない野生のバナナにあった #shorts"}
LEAD = {"long": "バナナには、なぜ種がないのか。国連食糧農業機関(FAO)・日本バナナ輸入組合の統計・論文の数字で、種のないバナナの歴史をたどって確かめました。",
        "s1": "日本バナナ輸入組合「バナナの植物学」から。野生のバナナの種は、アズキ粒ほどの堅い種でした。",
        "s2": "FAO によると、バナナの品種は1,000以上。輸出されるバナナのほぼ全部がキャベンディッシュです。",
        "s3": "1940〜1960年、ホンジュラスの谷では3万ヘクタールのバナナ畑がパナマ病で消えました(米国植物病理学会 APSnet)。",
        "s4": "FAO の TR4 Global Network から。世界の生産の8割以上が、TR4 に弱い品種です。",
        "s5": "2024年2月、オーストラリアの食品基準機関 FSANZ が、TR4 に強いキャベンディッシュ QCAV-4 を認めました。"}
SOURCES = """▼断り書き
※バナナの絵の一部は AI で作ったイメージです(画面の右上に表示)。
※1人あたりの量・値段は、総務省の家計調査(二人以上の世帯)を日本バナナ輸入組合がまとめたもの。倍数は自分で計算しました。

▼出典
・FAO(国連食糧農業機関)「Bananas」・TR4 Global Network「What is Fusarium Tropical Race 4?」
・Ploetz「Panama Disease: An Old Nemesis Rears Its Ugly Head」(米国植物病理学会 APSnet)
・Heslop-Harrison & Schwarzacher「Domestication, genomics and the future for banana」(Annals of Botany, 2007)
・日本バナナ輸入組合「バナナの植物学」「バナナに関する統計」(財務省貿易統計・総務省家計調査)
・Delacueva ほか(米国植物病理学会 2018年大会 要旨)
・オーストラリア食品基準機関 FSANZ「A1274」承認報告(2024年2月)"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#バナナ #種 #パナマ病 #なぜ #解説"""

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
print("ok", len(by))
