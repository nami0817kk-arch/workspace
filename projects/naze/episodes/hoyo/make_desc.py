"""青ヶ島の回のセット 6 本の題名と概要欄(out/aogashima/desc_*.txt と titles.json)。python episodes/aogashima/make_desc.py [本編の動画ID]
数字と出典は sim/facts.md。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "hoyo"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {'long': '九州と四国は、いちばん近い所で14km。なぜ橋がないのか。深さ・長さ・お金で確かめる',
    's1': '九州と四国は14km。橋がないのは「作れない」からではない #shorts',
    's2': '14kmの海を渡るのに、トンネルは21.3km要る #shorts',
    's3': '1兆5,200億円の中身。高いのは海の下だけではない #shorts',
    's4': '9年かけて調べて、結論は「十分に可能」 #shorts',
    's5': '国道なのに、船で70分。国道197号は海の上を通る #shorts'}
LEAD = {'long': '大分県の佐賀関と愛媛県の佐田岬は、いちばん近い所で約14km。それなのに橋もトンネルもなく、渡る方法はフェリーだけです。海の深さ、トンネルの長さ、事業費、50年続く調べを、数字で確かめました。',
    's1': '豊予海峡の幅は14km(環境省 海域保全)。佐賀関〜三崎のフェリーは約70分・1日16往復(国道九四フェリー)。事業費は大分県の2026年3月の試算で1兆5,200億円。',
    's2': '海の深さは約180m(大分市)。道路トンネルは延長21.3km・最急勾配4%(大分県の検討結果)。100m下がるのに2.5km必要なのは、4%から自分で計算しました。',
    's3': '事業費は海峡部9,300億円(本坑6,200・先進導坑1,600・作業坑1,500)と陸上5,900億円(大分県側1,000・愛媛県側4,900)の合計1兆5,200億円(大分県 2026年3月23日公表)。',
    's4': '1974〜82年の9年間、旧日本鉄道建設公団が調査。結論は「青函トンネルの技術で十分に可能」。2025年の見直しでも、トンネルルート上に活断層は確認できず(大分県「地質文献調査の結果」令和7年3月)。',
    's5': '国道197号は大分から高知まで続く国道で、佐賀関〜三崎は海上区間のフェリー(国土交通省九州地方整備局)。約70分・1日16往復(国道九四フェリー)。'}
SOURCES = """▼断り書き
※海峡の断面は、国土地理院の標高タイルと海底の標高データ(Terrain Tiles)から自分で描いた図です。海の深さは粗いデータなので、図は目安です。
※「14km」は環境省の資料の値です。自分で地図から測った最も狭い所は約13.2kmでした。
※トンネルの事業費は、大分県が2026年3月に出した試算です。建設が決まったわけではありません。
※坂の長さ(100m下がるのに2.5km)は、勾配4%からの自分の計算です。

▼出典
・環境省 海域保全(豊予海峡の幅)
・大分県「豊予海峡ルートにおける地質文献調査の結果」令和7年3月24日、「道路トンネルの検討結果」2026年3月、2026年3月23日公表の事業費、知事定例会見 2026年11月4日
・大分市(海峡の最大水深)
・国道九四フェリー(航路・所要時間・便数)、国土交通省 九州地方整備局(国道197号の海上区間)
・地図: 国土地理院(シームレス空中写真・標高タイル)、NASA Blue Marble(GIBS)、標高 Terrain Tiles(USGS SRTM・GMTED2010、NOAA ETOPO1)"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#豊予海峡 #九州 #四国 #地理 #なぜ #解説"""

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
