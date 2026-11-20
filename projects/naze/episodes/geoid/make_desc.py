"""海面の回のセット 6 本の題名と概要欄(out/geoid/desc_*.txt と titles.json)。python episodes/geoid/make_desc.py [本編の動画ID]
数字と出典は scripts.md の「確かめた数字」と sim/calc.txt。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "geoid"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {'long': '海の表面は平らではなかった。インド洋の真ん中は107m低い。見えない海面のでこぼこを1万倍で見る',
    's1': 'インド洋の真ん中、海面は約100m低い #shorts',
    's2': '衛星だけで富士山を測ると3,818m。43mずれる理由 #shorts',
    's3': '沖縄の海面は、東京湾より68cm高い #shorts',
    's4': '2025年4月、日本中の標高が書き換わった #shorts',
    's5': '氷がとけると、近くの海はむしろ下がる #shorts'}
LEAD = {'long': 'インド洋の真ん中では、海面がまわりより約107m低くなっています。なのに船で走っても気づきません。重力の模型と国土地理院の計算で、海面のでこぼこ、その原因、日本の標高との関係、そして「水平」とは何かを確かめました。',
    's1': 'いちばん低い海面は、スリランカの南で約107m(重力の模型 EGM2008 から計算)。いちばん急な東側でも、25km進んで1m下がるゆるい坂です。',
    's2': '富士山頂の下の見えない海面(ジオイド)は、物差しの地球(楕円体)より約42.5m上(国土地理院 ジオイド2024)。衛星の高さからこれを引くと標高になります。',
    's3': '那覇・父島・南鳥島などの離島は、島ごとの平均海面を標高の0mにしています。東京湾の海面との差は、那覇0.684m・父島0.642m・南鳥島0.997m(国土地理院 基準面補正量)。',
    's4': '2025年4月1日、国土地理院は全国の標高を衛星測位を基盤とする値に改定しました。三角点の最大改定量は宮城県牡鹿半島で+57cm、北海道知床半島で-67cm。',
    's5': '大きな氷床は重力で周りの海水を引き寄せています。氷が減ると、氷から最大約2,000kmの海岸で海面が下がり、遠い海ほど多く上がります(NASA)。'}
SOURCES = """▼断り書き
※海面のでこぼこの地球と地図は、重力の模型 EGM2008 から自分で描いた図です。高さの差は1万倍に大きくしています。
※いちばん低い・高い海面(-106.9m・+85.7m)と坂のゆるさは、EGM2008(5分角の網目)から自分で計算した値です。
※日本各地の見えない海面の高さは、国土地理院のジオイド高計算(ジオイド2024日本とその周辺)で測った値です。
※地球の断面の図は、論文の考え方を説明するための模式図です。

▼出典
・重力の模型 EGM2008(米国家地理空間情報局。GeographicLib の5分角の網目)
・国土地理院「ジオイドとは」「ジオイド・モデルの概要」「全国の標高成果の改定」、ジオイド高計算
・Pal & Ghosh (2023) How the Indian Ocean Geoid Low Was Formed, Geophysical Research Letters
・NASA Science「The fingerprints of sea level rise」(2015)、Mitrovica ほか (2001) Nature
・地球の形 GRS80(赤道半径 6,378.137km・極半径 6,356.752km)
・地図: NASA Blue Marble(GIBS)、国土地理院(シームレス空中写真)、標高 Terrain Tiles(USGS SRTM・GMTED2010、NOAA ETOPO1)"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#ジオイド #海面 #重力 #地理 #なぜ #解説"""

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
