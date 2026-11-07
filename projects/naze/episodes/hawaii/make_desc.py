"""ハワイの水はどこから回のセット 6 本の題名と概要欄(out/hawaii/desc_*.txt と titles.json)。python episodes/hawaii/make_desc.py [本編の動画ID]
数字と出典は sim/facts.md。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "hawaii"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {'long': '海の真ん中のハワイに、1年1万mmの雨が降る山。その水はどこから来て、どこへ消えるのか',
    's1': '同じ島なのに、雨の量が19倍ちがうハワイ #shorts',
    's2': '一番近い大陸まで3,857km。ハワイの水はどこから来る #shorts',
    's3': 'ハワイの4,000mの山頂は、雨がほとんど降らない #shorts',
    's4': '島の地下では、真水が海水の上に浮いている #shorts',
    's5': 'ホノルルの水道は、ほぼ100%が地下水 #shorts'}
LEAD = {'long': '大陸から3,857km離れた海の真ん中のハワイに、1年に約1万mmの雨が降る山があります。水を運ぶ貿易風、山の高さと雲のふた、海水の上に浮かぶ地下水まで、島の高さのデータで山を切って確かめました。',
    's1': 'カウアイ島のワイアレアレ山は年に約1万mm(393.85インチ)、同じ島の西のマナは514mm(20.23インチ)。NWS ホノルル予報所の平年値。割ると約19倍(自分で計算)。',
    's2': 'ホノルル〜サンフランシスコ 3,857km(ハワイ州の統計書)。貿易風は北東から、夏は80〜95%の時間吹く(WRCC)。',
    's3': 'マウナケア山頂付近の年降水量 204mm は州で最少(ハワイ大学 Rainfall Atlas)。逆転層はおよそ1,500〜2,200m、その上は湿り気が40%未満(WRCC・Rainfall Atlas)。東京の平年値 1,598.2mm(気象庁)。',
    's4': '地下水の水面が海面より1フィート上なら、海面下40フィートまで真水(USGS Fact Sheet 126-00)。ハワイの家庭用水の約99%が地下水(同)。',
    's5': 'オアフ島の水道はほぼ100%が地下水(ホノルル水道局)。2026年の汲み上げは1日1.24億〜1.43億ガロン(約47万〜54万立方m)。山に降った一滴が地下水になるまで25年かかることがある(同)。'}
SOURCES = """▼断り書き
※島を切った断面は、Terrain Tiles の標高(z10)を約460mおきにならした、自分で描いた図です。雲のふたの高さは 2,000m で描いています。
※インチ・フィート・ガロンからメートル法への換算は自分の計算です。

▼出典
・NWS Honolulu「Rain gage data table, December 2025」(ワイアレアレ・マナ・ホノルル空港の平年値)
・ハワイ大学「Rainfall Atlas of Hawaiʻi」(マウナケア山頂付近 204mm、逆転層)
・WRCC「Climate of Hawaii」(貿易風・逆転層)
・USGS Fact Sheet FS 126-00「Ground Water in Hawaii」(淡水レンズ、地下水の割合、州全体の雨)
・Honolulu Board of Water Supply(オアフ島の水道・汲み上げ量・25年)
・State of Hawaii Data Book(距離・ハナレイ川の流量)、ハワイ州 水資源委員会(通年の川 376本)、DLNR 州立公園局(アカカの滝)
・国土交通省「日本の水資源の現況」(日本の年平均降水量)、気象庁(東京の平年値)
・地図: NASA Blue Marble(GIBS)、標高 Terrain Tiles(USGS SRTM・GMTED2010、NOAA ETOPO1)"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#ハワイ #カウアイ島 #地図 #地理 #なぜ #解説"""

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
