"""南極の氷が全部とけたら回のセット 6 本の題名と概要欄(out/antarctic/desc_*.txt と titles.json)。python episodes/antarctic/make_desc.py [本編の動画ID]
数字は sim/calc.txt と sim/flood.txt。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "antarctic"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {
    "long": "南極の氷が全部とけたら、海は58m上がる。東京も北京も沈む世界地図と、とけるまでの年数",
    "s1": "南極の氷が全部とけたら、東京も北京も海の下 #shorts",
    "s2": "南極の氷は日本37個ぶん。厚さは平均2,117m #shorts",
    "s3": "南極の氷がとけても、海は69mではなく58mしか上がらない #shorts",
    "s4": "氷を取った南極は、1つの大陸ではなかった #shorts",
    "s5": "太陽の光を全部注いでも、南極の氷がとけるまで1年半 #shorts",
}
LEAD = {
    "long": "南極の氷が全部とけると、世界の海は58m上がります。人口500万人を超える都市53のうち、34で中心の地面が58mより低い。東京も北京もロンドンも海の下です。南極の氷の厚さのデータと世界の標高のデータで、沈む陸・氷の量・58mになる理由・とかすのに要る熱を、自分で計算して確かめました。",
    "s1": "海面を58m上げ、海から低い所を伝ってつながる陸を塗りました(Terrain Tiles の標高)。人口500万人を超える都市53のうち34で中心が58mより低く、合わせて約3億5千万人が住んでいます(Natural Earth の都市の人口)。",
    "s2": "ETOPO 2022 の氷の表面と岩盤の高さの差から計算すると、南極の氷は広さ1,383万平方km、体積2,722万立方km、平均の厚さ2,117m(Bedmap3 の値 2,717万立方km とほぼ同じ)。",
    "s3": "氷を全部水にして海の広さで割ると69m。海に浮かぶ氷(2.3m ぶん)と、海面より低い岩に乗った氷の海面より下の部分(8.5m ぶん)は海面を上げないので、引くと58m(Bedmap3 も 58m)。",
    "s4": "ETOPO 2022 の岩盤の高さ(氷の下)を真上から描きました。地面に乗った氷の47%は、岩盤が海面より低い所にあります。氷の重さで大陸が押し下げられたままの姿です。",
    "s5": "氷1kgをとかす熱 334kJ × 2京5千兆トン = 8.3×10^24 J。地球が受け止める太陽の光 174兆kW で割ると1.52年。地球にたまる熱 1平方mあたり0.76W(2006〜2020年)なら約680年。2012〜2017年の速さ(1年2,190億トン、IMBIE 2018)なら11万年以上(自分で計算)。",
}
SOURCES = """▼断り書き
※海面を上げた地図は、海から低い所を伝ってつながる陸だけを塗りました。氷の重みが消えて陸が浮き上がる分、海の水が重力で偏る分は入れていません。
※都市の高さは、Natural Earth の都市の中心の点の標高です(1点の値で、街全体が沈むとは限りません)。
※南極の氷の量は、ETOPO 2022 の氷の表面と岩盤の差を 0.05度おきに足した、自分で計算した値です。
※とかす熱の年数は、熱を全部氷に回したと仮定した値で、実際にそうなるわけではありません。

▼出典
・NOAA NCEI「ETOPO 2022 15 Arc-Second Global Relief Model」(60秒の Ice Surface と Bedrock)
・Pritchard ほか 2025「Bedmap3 updated ice bed, surface and thickness gridded datasets for Antarctica」Scientific Data(体積・58m)
・Morlighem ほか 2017「BedMachine v3」Geophysical Research Letters(グリーンランド 7.4m)
・The IMBIE team 2018「Mass balance of the Antarctic Ice Sheet from 1992 to 2017」Nature(1年に失った氷)
・von Schuckmann ほか 2023「Heat stored in the Earth system 1960–2020」Earth System Science Data(0.76W/m²)
・Kopp & Lean 2011(太陽の光 1,361W/m²)
・地図: NASA Blue Marble(GIBS)、標高 Terrain Tiles(USGS SRTM・GMTED2010、NOAA ETOPO1)、国境・都市 Natural Earth"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#南極 #海面上昇 #地球温暖化 #地図 #なぜ #解説"""

for k, t in TITLES.items():
    body = [LEAD[k], ""]
    if k == "long":
        ch = OUT / "chapters.txt"
        body += ["▼目次", ch.read_text(encoding="utf-8").strip() if ch.exists() else "(書き出し後に入る)", ""]
    elif LONG_ID:
        body += ["▼本編", f"https://youtu.be/{LONG_ID}", ""]
    body += [SOURCES, "", FOOT]
    text = "\n".join(body) + "\n"
    assert "nami" not in text.lower() and "0817" not in text
    (OUT / f"desc_{k}.txt").write_text(text, encoding="utf-8")
(OUT / "titles.json").write_text(json.dumps(TITLES, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok")
