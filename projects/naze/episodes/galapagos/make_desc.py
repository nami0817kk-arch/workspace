"""ガラパゴスの回のセット 6 本の題名と概要欄(out/galapagos/desc_*.txt と titles.json)。python episodes/galapagos/make_desc.py [本編の動画ID]
数字と出典は parts.py の冒頭。写真の出典は sim/photos.json(使った写真だけ載せる)。"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "out" / "galapagos"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {'long': 'ガラパゴスの生き物は、なぜここにしかいないのか',
          's1': '赤道の真下にペンギンがいる。海の底の山が作る冷たい海 #shorts',
          's2': '泳げないゾウガメは、930kmの海をどう渡ったのか #shorts',
          's3': 'ガラパゴスの島は、西へ行くほど若い #shorts',
          's4': '海に潜るトカゲは、世界でガラパゴスだけ #shorts',
          's5': 'ゾウガメの甲羅は、島によって形が違う #shorts'}
LEAD = {'long': 'ガラパゴス諸島の爬虫類と陸の哺乳類は、97%がここにしかいない種類です。本土からの距離(約930km)と海の深さ(約3,200m)を標高データで自分で測り、島の生まれ方・赤道の冷たい海・島ごとの違いから、その理由を確かめました。',
        's1': 'ガラパゴスペンギンは、北半球にもすむただ1種類のペンギン(Galapagos Conservancy)。イサベラ島・フェルナンディナ島の西の冷たい水のたまりは1年の平均22〜23度(Karnauskas ほか 2015)。',
        's2': 'ゾウガメは食べず飲まずで最長1年生きられます(Galapagos Conservancy)。本土の岸からいちばん近い島まで約930kmは、Natural Earth の地図の形から自分で測りました。',
        's3': 'サンクリストバル島で約235万年前、エスパニョーラ島で約270万年前の溶岩(Frontiers in Earth Science 2018 の総説)。ナスカプレートはホットスポットに対して100万年に約51km東へ動いています。',
        's4': 'ウミイグアナは海に出る唯一のトカゲで、20万〜30万匹(Galapagos Conservancy)。',
        's5': 'ゾウガメは今15種。ドーム型は湿った高地のある大きな島、鞍型は乾いた島にすみます(Galapagos Conservancy)。'}
SOURCES = """▼断り書き
※本土からの距離・海の深さ・島の数・陸の広さは、標高データと地図から自分で測った値です(1画素約300mの粗い値)。
※海流の道すじ・地点は、地図から読んだ目安です。
※写真の一部は、色を濃くし、切り抜いています。

▼出典
・Galapagos Conservancy「Biodiversity」(固有種の割合、ゾウガメ、ペンギン、ウミイグアナ、陸の哺乳類)
・島の年代とプレートの動き: Frontiers in Earth Science 2018(doi:10.3389/feart.2018.00050)、White et al. 1993、Argus et al. 2011
・海の温度: Karnauskas et al. 2015, Geophysical Research Letters
・ペンギンの巣とクロムウェル海流: Boersma(The Condor 1998)
・1977年の日照りとフィンチ: Boag & Grant 1981(Science 214)、Grant 夫妻の講演(Balzan 賞 2005)
・地図: NASA Blue Marble(GIBS)、標高 Terrain Tiles(USGS SRTM・GMTED2010、NOAA ETOPO1)、Natural Earth"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#ガラパゴス #ゾウガメ #ウミイグアナ #進化 #生き物 #地理 #なぜ #解説"""

src = json.loads((HERE / "sim" / "photos.json").read_text(encoding="utf-8"))
used = set(re.findall(r'PHOTO\("(\w+)"', (HERE / "parts.py").read_text(encoding="utf-8"))) | {"swim"}
PHOTOS = "▼写真(Wikimedia Commons)\n" + "\n".join(f"・{s['artist']}({s['license']}) {s['page']}" for k, s in src.items() if k in used and s["artist"])

for k, t in TITLES.items():
    body = [LEAD[k], ""]
    if k == "long":
        ch = OUT / "chapters.txt"
        body += ["▼目次", ch.read_text(encoding="utf-8").strip() if ch.exists() else "(書き出し後に入る)", ""]
    elif LONG_ID:
        body += ["▼本編", f"https://youtu.be/{LONG_ID}", ""]
    body += [SOURCES, "", PHOTOS, "", FOOT]
    text = "\n".join(body) + "\n"
    assert "nami" not in text.lower() and "0817" not in text
    (OUT / f"desc_{k}.txt").write_text(text, encoding="utf-8")
(OUT / "titles.json").write_text(json.dumps(TITLES, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", sorted(used))
