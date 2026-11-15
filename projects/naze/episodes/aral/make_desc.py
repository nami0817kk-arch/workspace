"""アラル海の回のセット 6 本の題名と概要欄(out/aral/desc_*.txt と titles.json)。python episodes/aral/make_desc.py [本編の動画ID]
数字と出典は parts.py の冒頭。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "aral"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {'long': '世界4位の湖アラル海は、なぜ1割に縮んだのか。水は「くまれた」のではなく空へ消えた',
    's1': '北海道の8割あった湖が、1割に。水は空へ消えた #shorts',
    's2': 'アラル海は、毎年1mずつ空へ消えていた #shorts',
    's3': '縮んだ湖の広さを、割り算1つで当ててみた #shorts',
    's4': 'アラル海の塩は、海の4倍より濃くなった #shorts',
    's5': '13kmの堤防1本で、北の湖に魚が戻った #shorts'}
LEAD = {'long': '中央アジアのアラル海は、1960年には世界で4番目に大きな湖でした(約6万7,500km²、北海道の約8割)。2014年には水面が1割に。水はどこへ消えたのか。湖に入る水と空へ出る水の出入り、川の水の行方、干上がった底、そして割り算で出す湖の広さで確かめました。',
    's1': '1960年のアラル海は約6万7,500km²で世界4位(Micklin ほか 2020)。2014年の水面は1960年の10.4%。出口の川がなく、入る水と蒸発のつり合いで広さが決まる湖です。',
    's2': '1911〜1960年の水の出入りは、川56km³+雨と雪9.1km³に対し、蒸発66.1km³(Micklin ほか 2020)。66.1km³を広さ67,499km²で割ると深さ約1m(自分で計算)。1975〜85年に湖へ届いた川の水は約10km³(Gleick 1993)。',
    's3': '雨と雪を引いた1年の蒸発の深さは (66.1−9.1)÷67,499km² ≒ 0.84m(自分で計算)。1992〜2011年に入った水は平均8.8km³(Micklin ほか 2020)。8.8÷0.00084 ≒ 1万400km²。2018年に測られた広さは9,668km²。',
    's4': '1960年の塩分は約10g/L、2018年の西側は150g/L超(Micklin ほか 2020)。海水は約35g/L。西側の水面は53.4mから約23mへ下がりました。商業の漁は1980年代のはじめに終わりました。',
    's5': 'コクアラルの堤防は長さ13km、2003〜2005年に建設(世界銀行とカザフスタン政府)。北の湖の漁獲は2005年695tから2016年6,000t(Micklin ほか 2020)。'}
SOURCES = """▼断り書き
※昔の岸の線は、標高データ(Terrain Tiles)の等高線から自分で引いた目安です。1960年の水面53.4mの線の内側は約6万8,600km²で、記録(6万7,499km²)とのずれは約2%でした。
※「深さ約1m」「0.84m」「割り算の広さ」は、論文の数字からの自分の計算です。実際の蒸発は、湖が小さく塩辛くなるほど変わります。
※川の道すじ・町と堤防の位置は、地図から読んだ目安です。

▼出典
・P. Micklin, N. Aladin, T. Chida ほか(2020)"The Aral Sea: A Story of Devastation and Partial Recovery of a Large Lake", S. Mischke 編『Large Asian Lakes in a Changing World』Springer
・J. Conrad, K. Kobildjanova "The Economics of an Environmental Disaster: The Aral Sea"(Cornell University)、Gleick(1993)
・北海道の面積: 国土地理院 全国都道府県市区町村別面積調。琵琶湖の水の量: 滋賀県
・地図: NASA Blue Marble(GIBS)、標高 Terrain Tiles(USGS SRTM・GMTED2010、NOAA ETOPO1)、Natural Earth"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#アラル海 #中央アジア #湖 #地理 #なぜ #解説"""

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
