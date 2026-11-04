"""チリのセット 6 本の題名と概要欄(out/chile/desc_*.txt と titles.json)。python episodes/chile/make_desc.py [本編の動画ID]
題名は scripts.md(2版)の案。出典は scripts.md の頭、数字は sim/calc.txt。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "chile"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {
    "long": "チリは日本の2倍の広さなのに、幅は東京〜宇都宮ほど。隣の国々は、なぜこの細い帯を残したのか",
    "s1": "チリの幅は93km。東京〜宇都宮とほぼ同じなのに、長さは日本の1.5倍 #shorts",
    "s2": "アルゼンチンのワインの町メンドーサは、200年以上チリの町だった #shorts",
    "s3": "チリの山の頂から海の底まで1万5,000m。富士山4つ分の段差が509kmに収まる理由 #shorts",
    "s4": "海のないボリビアに、いまも海軍がある。海を失ったのは砂漠の白い石の戦争 #shorts",
    "s5": "記録に残る最大の地震はM9.5。チリで起きたのは、国の形と同じ理由だった #shorts",
}
LEAD = {
    "long": "チリの広さは日本のおよそ2倍。それなのに幅は、いちばん狭い所で93km。国境のデータで長さと幅を自分で測り、細長い国になった4つの理由を確かめました。2つは地面(アンデス山脈と海溝を作る1つの力)、2つは人の線(北の硝石の戦争と、南の海峡の取り引き)です。",
    "s1": "チリの長さは4,274km、宗谷岬〜波照間島の1.5倍。幅はいちばん狭い所で93km、東京駅〜宇都宮駅とほぼ同じです(Natural Earth の国境から自分で測った値)。",
    "s2": "1561年、チリの隊がアンデス山脈を越えてメンドーサを作りました。1776年、スペインの王がブエノスアイレスを中心に区切りを作り直し、山の東の町はそちらへ。山の峰がチリの東の縁になりました。",
    "s3": "チリでいちばん高い峰(オホス・デル・サラード、約6,900m)から509km西の海の底(リチャーズ海淵、8,065m)まで、高さの差は約1万5,000m。海の板が年に6.5〜8cm、南アメリカの下へもぐりこんで、溝と山を作っています。",
    "s4": "1904年の講和で、ボリビアは海岸をチリに渡しました。それでもボリビアには海軍があり、チチカカ湖などで活動しています。3月23日は「海の日」です。",
    "s5": "1960年のチリ地震はマグニチュード9.5、ずれた長さは約1,000km(USGS)。海の板が陸の下へもぐりこむ力が、地震も、沖の溝も、アンデス山脈も作っています。",
}
SOURCES = """▼断り書き
※長さ・幅・距離は、Natural Earth の国境データから自分で計算しました(長さ4,274km、本土の平均幅186km、いちばん狭い所93km)。公表値(最小90km)とほぼ一致します。
※地図の塗り分けのうち、昔の境(1874年のボリビアの海岸、アラウカニア)は、いまの州の境で近く表したものです。2章の「高い峰の線」「水を分ける線」と、帆船の道筋、地震でずれた範囲の線は、説明のための図です。
※海溝の線は、標高データで各緯度のいちばん深い所を自分で結んだものです。
※場面の絵は AI で作ったイメージで、実際の人や場所を写したものではありません。

▼出典
・地図: NASA Blue Marble(GIBS)、標高 Terrain Tiles(USGS SRTM・GMTED2010、NOAA ETOPO1)、国境 Natural Earth
・面積: CIA World Factbook(チリ 756,102km²、アルゼンチン 2,780,400km²)、国土地理院(日本 377,975km²)
・Memoria Chilena(チリ国立図書館): サンティアゴの建設(1541年)、太平洋戦争と講和、1929年リマ条約、アラウカニアの占領(1861〜1883年)、オレリー＝アントワーヌ・ド・トゥナン、ゴレタ船アンクー号とブルネス砦(1843年)、1881年境界条約、硝石産業の盛衰
・1881年 チリ・アルゼンチン境界条約 第1条(チリ国立図書館デジタル版)、1874年 チリ・ボリビア境界条約(条約文)
・クージョの移管(1776年): アルゼンチン国立歴史アカデミー『アルゼンチン国民史』ほか
・USGS: ナスカプレートの沈み込みの速さ(Open-File Report 2015-1031-E)、1960年チリ地震
・Britannica: リチャーズ海淵 8,065m
・ボリビア海軍と「海の日」: Armada Boliviana、報道"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#チリ #地理 #アンデス山脈 #南米 #なぜ #解説"""

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
