"""太陽のセット 6 本の題名と概要欄(out/sun/desc_*.txt と titles.json)。python episodes/sun/make_desc.py [本編の動画ID]
題名は scripts.md(3版)の案。出典は scripts.md の頭、数字は sim/calc.txt。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "sun"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {
    "long": "核のゴミは、なぜ太陽に捨てないのか。捨てられるが、日本の分だけで200兆円かかる",
    "s1": "太陽は地球109個ぶんの大きさなのに、ロケットを向けても当たらない #shorts",
    "s2": "太陽へ落とすには秒速27km、太陽系の外へは秒速12km。近いほうが2倍むずかしい #shorts",
    "s3": "月へ人を運んだロケット1機で、太陽に捨てられる核のゴミは2本だけ #shorts",
    "s4": "太陽に近づく探査機は、金星のそばを7回通って6年かけた。まっすぐ行けない理由 #shorts",
    "s5": "太陽へ落とすいちばん安い道は、まず木星の遠さまで離れること #shorts",
}
LEAD = {
    "long": "核のゴミを太陽に捨てることは、できます。ただ、とんでもなく高くつく。地球は太陽のまわりを秒速30kmで回っていて、太陽へ落とすにはその速さを秒速27km消さなければならないからです。ゴミの筒を1本積んだカプセルを、撃ち方を変えて4回撃ち、道すじを軌道の式で計算して確かめました。",
    "s1": "地球は太陽のまわりを秒速30kmで回っています。太陽の向きに秒速10kmで撃っても、横の速さが残るので、いちばん近づくのは金星の道のあたり(太陽から0.75天文単位)。軌道の式で自分で計算した値です。",
    "s2": "地球の公転の速さ(秒速29.8km)から、太陽の表面に届く道へ移るには秒速26.9km減らす必要があります。太陽系の外へ出るには秒速12.3km足せば足ります(軌道の速さの式で自分で計算)。",
    "s3": "低い軌道から太陽へ落とすには秒速21.3kmが要り、水素のエンジンでも出発の重さは届ける重さの127倍になります。サターンV(低い軌道へ約118トン)なら、太陽へ届くのは約0.93トン、ガラス固化体で約2本。タンクの重さを入れない、いちばん甘い見積もりです。",
    "s4": "NASAのパーカー・ソーラー・プローブ(685kg)は2018年に打ち上げられ、金星のそばを7回通って速さを落とし、2024年12月に太陽の表面から約610万kmまで近づきました。",
    "s5": "いったん木星の遠さ(5.2天文単位)まで行ってからブレーキをかけると、低い軌道からの合計は秒速13.2km。まっすぐ太陽へ向かう秒速21.3kmの約6割です。行きに約2.7年、落ちるのに約2.1年(自分で計算)。",
}
SOURCES = """▼断り書き
※カプセルの道すじ・必要な速さ・重さの比・費用は、軌道の速さの式とロケットの式で自分で計算しました(太陽と地球の値は NASA の Fact Sheet、エンジンは水素(噴く速さ 4.4km/s)を置いた値)。サターンV 1機で筒2本・1,300機は、タンクの重さを入れない、いちばん甘い見積もりです。
※サターンVの値段は、1回 1億8,500万ドル(1969〜71年のドル)を今のドルに直し、1ドル150円で円にした目安です。
※ガラス固化体・サターンV・探査機の図は、形を簡単にして描いたものです。

▼出典
・NASA Sun Fact Sheet / Earth Fact Sheet(太陽の半径、地球の公転の速さ)
・NASA: パーカー・ソーラー・プローブ(打ち上げ・重さ・2024年12月24日の最接近)、"It's Surprisingly Hard to Go to the Sun"、メッセンジャー、ボイジャー
・NASA TM X-2912(1974年)、NASA CR-161888(1981年): 宇宙への処分の検討
・NUMO「地層処分事業にいくらかかりますか？」(約4.7兆円)、NUMO の説明資料(ガラス固化体 約2,500本・4万本の計画)
・NASA RPS Safety(打ち上げ事故と原子力電源)、The Canadian Encyclopedia(コスモス954号)
・2024年の打ち上げ数と失敗数: 各国の打ち上げ記録の集計"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#太陽 #宇宙 #核のゴミ #ロケット #なぜ #解説"""

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
