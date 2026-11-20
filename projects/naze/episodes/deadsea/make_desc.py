"""死海の回のセット 6 本の題名と概要欄(out/deadsea/desc_*.txt と titles.json)。python episodes/deadsea/make_desc.py [本編の動画ID]
数字と出典は parts.py の冒頭。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "deadsea"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {'long': '死海は40年で30m下がった。川の水だけではなかった、水面が下がり続ける本当の理由',
    's1': '陸でいちばん低い湖は、40年で30m下がった #shorts',
    's2': '死海が下がる4割は、塩を取る池のせいだった #shorts',
    's3': 'ヨルダン川の水は、9割が死海に届かない #shorts',
    's4': '死海の岸に、5,500個の穴が開いた理由 #shorts',
    's5': '紅海から水を引いても、死海は止まらない #shorts'}
LEAD = {'long': '陸の上でいちばん低い水面、死海。2018年の水面は海面下433mで、毎年約1.1mずつ下がっています。水はどこへ消えているのか。入る水と出る水、ヨルダン川、南の塩を取る池、そして紅海から水を引く案まで、論文と資料の数字と、自分で測った標高データで確かめました。',
    's1': '2018年10月の水面は海面下433m、2014〜2017年の下がり方は年110±7cm(Vey ほか 2021)。40年で30m下がった(イスラエル環境保護省 2018)。ヨルダン川の流れ込みは1955年より前の約1割(Vey ほか 2021)。',
    's2': 'ICL は2018年に北の湖から約4.3億m³をくみ上げ、約2.7億m³を戻した(ICL 2018)。両岸の塩の工場の正味の水の使用は約2.5億m³で、下がる分の約4割(Vey ほか 2021)。',
    's3': 'ヨルダン川から死海へ入る水は1955年より前と比べて9割減(Vey ほか 2021)。デガニア・アルモットのダム(Globes 2018)。上流で使われる水は約14億m³(ICL 2018)。下がり方は年0.7mから1.2mへ(イスラエル環境保護省 2018)。',
    's4': '2015年時点で死海の岸に開いた穴は約5,500個(Globes 2018、イスラエル環境保護省の資料)。40年で水面は30m下がった。',
    's5': '紅海から年約2.5億m³を管で運ぶ案では、下がり方が年約35cmゆるみ、なお年約0.75m下がる見込み(ICL 2018)。2.5億m³÷641km²≒0.39m は自分で計算。'}
SOURCES = """▼断り書き
※湖の広さ(約641km²)と昔の岸の線は、標高データ(SRTM、2000年2月の撮影)から自分で測った目安です。2000年の水面は海面下412mと測れ、記録とほぼ同じでした。
※「1年に約7億m³」「約0.39m」「約0.7m」は、資料の数字からの自分の計算です。
※数字の多くは2018年ごろの資料です。その後も水面は下がっています。
※地点の位置は地図から読んだ目安です。

▼出典
・M. Vey ほか(2021)Scientific Reports(死海の水位・下がり方・水の出入り・カリの工場の割合)
・イスラエル環境保護省(2018、Globes 2018年2月13日の記事)
・ICL「Dead Sea water level」(2018年の持続可能性報告)
・琵琶湖の面積: 国土地理院。東京ドームの容積・東京タワーの高さ
・地図: NASA Blue Marble(GIBS)、標高 Terrain Tiles(USGS SRTM・GMTED2010、NOAA ETOPO1)、Natural Earth"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#死海 #ヨルダン川 #湖 #地理 #なぜ #解説"""

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
