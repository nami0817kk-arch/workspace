"""シベリアの回のセット 6 本の題名と概要欄(out/siberia/desc_*.txt と titles.json)。python episodes/siberia/make_desc.py [本編の動画ID]
数字と出典は parts.py の冒頭。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "siberia"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {'long': 'シベリアに人がいないのは、寒さのせいではなかった。日本の30倍の土地を、町の並びで確かめる',
    's1': '日本の30倍の土地に、日本の5分の1の人しかいない #shorts',
    's2': '北緯60度。ヘルシンキは111万人、シベリアは全部で102万人 #shorts',
    's3': 'シベリアの大河は、なぜ役に立たないのか #shorts',
    's4': 'シベリアの大きな町は、1本の線の上に並ぶ #shorts',
    's5': '道路も鉄道もない、北緯69度の17万人の町 #shorts'}
LEAD = {'long': 'シベリアと極東は日本の約30倍の広さに、人は日本の5分の1ほど。なぜ人がいないのか。町の人口を緯度ごとに自分で数えると、北緯60度より北は土地の39%に町の人の7%。同じ北緯60度のヘルシンキと比べ、凍った地面、北へ流れる川、シベリア鉄道の帯、北の町の成り立ちから確かめました。',
    's1': 'シベリア連邦管区と極東連邦管区は、あわせて約1,131万km²・約2,478万人(ロシア統計局 2021年国勢調査)。Natural Earth の州の形から自分で面積を足すと日本の30.0倍。',
    's2': 'ヘルシンキ(北緯60.2度)約111万人、ストックホルム(59.4度)約126万人。北緯60度より北のシベリアの町(Natural Earth の町の人口の見積もり)を自分で足すと約102万人。',
    's3': 'オビ川・エニセイ川・レナ川は、どれも南から北へ流れて北極海に出ます。春は上流から先にとけ、凍った下流で水があふれます。',
    's4': 'シベリア鉄道 モスクワ〜ウラジオストク 9,288km(ロシア鉄道)。Natural Earth の町の人口で大きい順の15の町は、すべて北緯57度より南(自分で数えた)。',
    's5': 'ノリリスクは北緯69.3度、約17万人(Natural Earth の見積もり)。ニッケルなどの鉱山の町で、国のほかの地域とつながる道路と鉄道はありません。'}
SOURCES = """▼断り書き
※ここでの「シベリア」は、ロシアのシベリア連邦管区と極東連邦管区をあわせた範囲です。
※町の人口と緯度ごとの割合は、地図のデータ(Natural Earth の populated places、都市の人口の見積もり)で自分で数えた目安です。古めの見積もりを含みます。
※川と鉄道の道すじ、町の位置は、地図から読んだ目安です。

▼出典
・ロシア統計局 2021年国勢調査(連邦管区の人口と面積)
・ロシア天然資源・環境相(2021年、永久凍土の割合)
・ロシア鉄道(シベリア鉄道の長さ)
・日本の面積: 国土地理院。日本の人口: 総務省 人口推計
・地図: NASA Blue Marble(GIBS)、標高 Terrain Tiles(USGS SRTM・GMTED2010、NOAA ETOPO1)、Natural Earth"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#シベリア #ロシア #人口 #地理 #なぜ #解説"""

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
