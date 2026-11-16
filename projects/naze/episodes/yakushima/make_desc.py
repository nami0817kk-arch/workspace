"""屋久島の回のセット 6 本の題名と概要欄(out/yakushima/desc_*.txt と titles.json)。python episodes/yakushima/make_desc.py [本編の動画ID]
数字と出典は parts.py の冒頭。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "yakushima"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {'long': '屋久島の雨は東京の約3倍。隣の種子島と同じ大きさなのに、なぜ屋久島だけ雨が多いのか',
    's1': '屋久島の雨は、東京の約3倍。山の上はもっと降る #shorts',
    's2': '同じ大きさの隣の島。雨の量は1.8倍ちがう #shorts',
    's3': '空気1m³から、約10gの水がしぼり出される #shorts',
    's4': '屋久島に降る雨は、1年で東京ドーム約1,900杯 #shorts',
    's5': '屋久島の電気は、99.5%が雨の水力 #shorts'}
LEAD = {'long': '屋久島の1年の雨は4,651.7mmで、東京の約3倍。山の上は8,000〜10,000mmと推測されています。隣の種子島とほぼ同じ大きさなのに、なぜ屋久島だけ雨が多いのか。国土地理院の標高データで島の高さと坂を測り、空気が冷えて水が出てくる量を計算して確かめました。',
    's1': '年降水量の平年値(1991〜2020年): 屋久島 4,651.7mm、東京 1,598.2mm(気象庁)。山の上は年8,000〜10,000mmと推測(林野庁)。いちばん高い所から海岸までの距離は、国土地理院の標高で自分で測りました。',
    's2': '広さと高さは国土地理院の標高で自分で測りました(屋久島 約506km²・1,931m、種子島 約456km²・281m)。年降水量の平年値 屋久島 4,651.7mm、種子島 2,532.5mm(気象庁)。',
    's3': '雲の中では100m上るごとに約0.5度下がるとして、1,900m上ると約10度。空気1m³が持てる水(飽和水蒸気量)は25度で約23g、15度で約13g。差の約10gを自分で計算しました。',
    's4': '島の広さ約506km²(自分で測った)×海沿いの年降水量4.65m ≒ 約23億m³。東京ドーム(124万m³)で約1,900杯。山の上はもっと降るので、少なく見積もった値です。',
    's5': '島で使う電気の99.5%は水力発電(環境省)。屋久島電工が水力発電所を3つ動かしています(国土交通省)。'}
SOURCES = """▼断り書き
※島の広さ・高さ・坂は、国土地理院の標高タイルから自分で測った値です(宮之浦岳の公式の高さは1,936m)。
※「約10度冷える」「約10gの水」は、一般的な値を使った自分の計算です。実際の雨の量は風の強さや向きで変わります。
※地図の空中写真は、色が青く寄っていたため、森の色に近づける補正をかけています。

▼出典
・気象庁 平年値(1991〜2020年)の年降水量(屋久島・種子島・東京)
・林野庁「屋久島の自然」(山の上の降水量の推測)
・環境省(島の電気のうち水力発電の割合)、国土交通省(屋久島電工の水力発電所)
・林芙美子『浮雲』
・地図: 国土地理院(シームレス空中写真・標高タイル)、NASA Blue Marble(GIBS)、標高 Terrain Tiles"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#屋久島 #種子島 #雨 #地理 #なぜ #解説"""

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
