"""宇宙で冷えない回のセット 6 本の題名と概要欄(out/space-heat/desc_*.txt と titles.json)。python episodes/space-heat/make_desc.py [本編の動画ID]
数字は sim/calc.txt、測った値・定数の出どころは research.md と sim/calc.py の冒頭。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "space-heat"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {
    "long": "宇宙はマイナス270℃なのに、宇宙ステーションは熱がこもる。冷えない本当の理由",
    "s1": "宇宙はマイナス270℃。なのに物が冷えないのはなぜ #shorts",
    "s2": "宇宙の日なたは120℃。黒い板を1枚置くと分かる #shorts",
    "s3": "宇宙に生身で出ても、人は一瞬では凍らない #shorts",
    "s4": "宇宙ステーションの放熱板が白い理由。黒なら62℃ #shorts",
    "s5": "宇宙服は氷で体を冷やす。1回で捨てる水は3.6kg #shorts",
}
LEAD = {
    "long": "宇宙はマイナス270℃。それなのに国際宇宙ステーションは、最大70kWの熱を捨てるために、大きな放熱板を6枚も広げています。熱が逃げる3つの道、光だけで決まる温度、放熱板の広さと色、宇宙服の冷やし方を、物理の式で計算して確かめました。答えは、宇宙は寒いのではなく、熱を渡す相手がいない場所だから。",
    "s1": "高さ400kmの空気は地上のおよそ1兆分の1(NASA の資料の表から)。6畳の部屋の空気は地上で61kg、400kmでは1グラムの2千万分の1(自分で計算)。熱が逃げる道は、赤外線の光だけになります。",
    "s2": "太陽の光 1平方mあたり1,361Wを黒い板が受け、片面から赤外線で出すとして、釣り合う温度を シュテファン＝ボルツマンの式で計算すると120℃。JAXA が示す日なたの温度 120℃と合います。",
    "s3": "皮膚33℃・放射率0.98・外へ向いた面 1.3平方mとして、出す赤外線は641W(自分で計算)。体が作る熱 約100Wを引き、体重70kgで割ると、1時間に約8℃。1966年の事故の記録(NASA CR-1223)では、倒れたのは12〜15秒後で、原因は酸素が足りないことでした。",
    "s4": "黒い板を日なたに置くと、両面から出しても62℃(地球の赤外線を含めて計算)。白い塗料(太陽の光の吸収 0.14・放射率 0.9)なら、両面から出してマイナス65℃。中のアンモニアは2.8℃で送り出しています。",
    "s5": "1回の船外活動で宇宙へ捨てる水は約3.6kg(NASA の報告)。氷が蒸発する熱 1kgあたり2.83MJをかけると10.2MJ、8時間ならして354W(自分で計算)。",
}
SOURCES = """▼断り書き
※温度は「入る光と出る光が釣り合う」として、シュテファン＝ボルツマンの式で自分で計算しました。板の形・向き・地球からの光の当たり方を簡単にした値です。
※放熱板の広さの計算は、板を2.8℃・放射率0.9とし、地球から届く赤外線(1平方mあたり240W、高さ400kmで地球が見える割合 0.29)を引いた値です。実物の板の表面温度は資料に無く、仮の値です。
※人が冷える速さは、皮膚33℃・体重70kg・比熱 3.47kJ/(kg・℃)として体全体をならした値です。
※70kW はアメリカ側の放熱の仕組みの設計上の上限で、いつも70kWを捨てているわけではありません。
※図は形を簡単にして描いたものです。

▼出典
・NASA/Boeing「Active Thermal Control System (ATCS) Overview」(70kW・放熱板 6枚・大きさ・白い塗料・アンモニアの温度と凍る温度)
・NASA「Space Station Facts and Figures」(90分で1周・1日16回の日の出)
・JAXA「きぼう」船外実験プラットフォームの熱真空試験(日なた120℃・日陰−150℃)
・NASA CR-205357 Smith ほか 1997(高さ400kmの空気の濃さ)
・NASA LAMBDA COBE FIRAS、Mather ほか 1999(宇宙の背景 2.725K)
・Kopp & Lean 2011(太陽の光 1,361W/m²)、NASA CERES(地球が出す赤外線)
・NASA Finckenor「MISSE Thermal Control Materials」、NASA TM-1998-208500(白い塗料の吸収率・放射率)
・NASA ICES-2021-365(人の出す熱 88〜191W)、Hill & Taylor(NASA JSC、宇宙服の昇華器)、Hodgson ほか(1回の船外活動で失う水 3.6kg)
・Roth「Rapid (explosive) decompression emergencies in pressure-suited subjects」NASA CR-1223, 1968(1966年の事故)
・NIST CODATA(シュテファン＝ボルツマン定数)、Feistel & Wagner 2007(氷の昇華熱)
・地球の画像: NASA Blue Marble"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#宇宙 #宇宙ステーション #ISS #物理 #なぜ #解説"""

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
