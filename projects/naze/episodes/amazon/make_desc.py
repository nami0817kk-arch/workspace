"""アマゾン川の回のセット 6 本の題名と概要欄(out/amazon/desc_*.txt と titles.json)。python episodes/amazon/make_desc.py [本編の動画ID]
数字と出典は parts.py の冒頭。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "amazon"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {'long': 'アマゾン川に橋が1本もないのは、作れないからではなかった。水位と谷の幅と人の数で確かめる',
    's1': '6,000km以上流れるアマゾン川に、橋は1本もない #shorts',
    's2': 'アマゾン川の水面は、1年で最大18m上下する #shorts',
    's3': 'アマゾン川の本当の幅は、60kmになる #shorts',
    's4': '日本の4倍の州に、人は394万。半分は1つの町 #shorts',
    's5': '2024年、アマゾン川の水位は122年で最低になった #shorts'}
LEAD = {'long': '6,000km以上流れるアマゾン川の本流には、橋が1本もありません。マナウス港の水位計の記録(最高30.02m・最低12.11m)、標高データで自分で測った谷の幅(25〜60km)、アマゾナス州の人口と広さから、橋がない理由を確かめました。',
    's1': 'アマゾナス州は約156万km²・約394万人、マナウスは約206万人(ブラジル地理統計院 2022年国勢調査)。',
    's2': 'マナウス港の水位計(1902年から): 最高30.02m(2021年)、最低12.11m(2024年10月)。ブラジル地質調査所の資料と報道。',
    's3': '標高データ(Terrain Tiles、SRTM)で、マナウス〜サンタレンを南北に5本切り、水面から20m以内の低い帯の幅を自分で測りました(24.6〜59.3km)。森の木の高さが乗るので目安です。',
    's4': 'アマゾナス州 3,941,613人・1,558,704km²、マナウス 2,063,547人(ブラジル地理統計院 2022年国勢調査)。日本の面積は約37.8万km²。',
    's5': 'マナウス港の水位は2024年10月9日に12.11m。1902年に記録を始めてから最も低い値(ブラジル地質調査所の資料と報道)。'}
SOURCES = """▼断り書き
※谷の幅は、標高データから自分で測った目安です。森の木の高さが入るので、実際の低い土地はもう少し広い可能性があります。
※川の道すじ・町の位置は、地図から読んだ目安です。

▼出典
・マナウス港の水位計の記録(ブラジル地質調査所 SGB の技術ノート、報道)
・ブラジル地理統計院(IBGE)2022年国勢調査
・日本の面積: 国土地理院
・地図: NASA Blue Marble(GIBS)、標高 Terrain Tiles(USGS SRTM・GMTED2010、NOAA ETOPO1)、Natural Earth"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#アマゾン川 #ブラジル #川 #地理 #なぜ #解説"""

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
