"""海の水を全部抜いたら回のセット 6 本の題名と概要欄(out/drain/desc_*.txt と titles.json)。python episodes/drain/make_desc.py [本編の動画ID]
数字は sim/calc.txt と sim/straits.txt。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "drain"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {
    "long": "海の水を全部抜いたら、最後に残るのはどこか。海面を1万m下げていく世界地図",
    "s1": "海を31m下げるだけで、イギリスは大陸と地続き #shorts",
    "s2": "海の水を陸にのせると、エベレストが埋まる #shorts",
    "s3": "大西洋の底には、6万5千kmの山脈が隠れている #shorts",
    "s4": "海の底の3分の1は、深さ4,000〜5,000mの平原 #shorts",
    "s5": "海の水を抜いて、最後に残る水たまりはマリアナ海溝 #shorts",
}
LEAD = {
    "long": "地球の海の水を、上から少しずつ抜いていきます。31mでイギリスが大陸と地続きになり、2,000mで水は半分、4,000〜5,000mで海の底の3分の1が一気に現れ、最後に残るのはマリアナ海溝です。世界の海の深さのデータ(ETOPO 2022)で、海面を下げて自分で計算しました。",
    "s1": "海面を下げて、陸がつながる深さを測りました(ETOPO 2022 の 60 秒の格子)。イギリスとフランス 31m、アラスカとシベリア 45m、北海道とサハリン 59m、本州と北海道 123m。50m 下げて出てくる海の底は 1,070万平方km(日本の28個ぶん)。2万年ほど前の海は、いまより120m以上低かったと考えられています(Lambeck ほか 2014)。",
    "s2": "ETOPO 2022 の海の深さを 0.1度おきに足すと、海の水は 13億3,700万立方km、海の広さは 3億6,010万平方km、平均の深さ 3,713m。陸の広さ 1億4,990万平方km にのせると厚さ 8.92km(エベレスト 8,849m)。1つの球にすると直径 1,367km(月の直径 3,474km)。",
    "s3": "大西洋を北緯30度で切った断面(ETOPO 2022)。真ん中の盛り上がりは、海の底が両側へ広がっていく所(中央海嶺)。海の中の山脈の長さ 6万5千km は NOAA Ocean Service の値です。",
    "s4": "海の広さのうち、深さ 4,000〜5,000m が 32.1%、3,000〜4,000m が 22.3%、5,000〜6,000m が 20.3%、6,000m より深い所は 1.0%(ETOPO 2022 から計算)。5,000m 下げると、残る水は 2.4%。",
    "s5": "6,000m 下げると海の底の 99% が干上がり、残る水の広さは 370万平方km。チャレンジャー海淵の深さ 10,935m は 2021年の測定(Greenaway ほか 2021)。地図のデータ(ETOPO 2022)は格子でならしてあるので、いちばん深い所は 10,541m になります。東京からの距離 2,720km は自分で計算。",
}
SOURCES = """▼断り書き
※海面を下げた地図は、海の水を海全体から同じだけ減らしたものです。海が分かれて閉じこめられた水が残る分や、水の重さが消えて海の底が浮き上がる分は入れていません。
※海の量・広さ・深さの割合は、ETOPO 2022 を 0.1度おきに足した、自分で計算した値です。海峡がつながる・切れる深さは 60 秒(1 分)の格子で測りました。

▼出典
・NOAA NCEI「ETOPO 2022 15 Arc-Second Global Relief Model」(60秒の Ice Surface)
・NOAA Ocean Service「What is the longest mountain range on earth?」(海の中の山脈 6万5千km)
・Lambeck ほか 2014「Sea level and global ice volumes from the Last Glacial Maximum to the Holocene」PNAS(2万年ほど前の海面)
・Greenaway ほか 2021「Revised depth of the Challenger Deep from submersible transects」(10,935m)
・エベレスト 8,849m(2020年 中国・ネパール発表)、月の直径 3,474km(NASA)、日本の面積(国土地理院)
・地図: NASA Blue Marble(GIBS)、標高 Terrain Tiles(USGS SRTM・GMTED2010、NOAA ETOPO1)、国境 Natural Earth"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#海 #海底 #地図 #マリアナ海溝 #なぜ #解説"""

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
