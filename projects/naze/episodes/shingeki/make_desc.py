"""進撃の巨人 × 2乗3乗 6 本の題名と概要欄(out/shingeki/desc_*.txt と titles.json)。python episodes/shingeki/make_desc.py [本編の動画ID]"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "shingeki"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {
    "long": "超大型巨人を人の体で作ったら、歩くだけで骨が折れた。骨を鉄にしても60mは歩けない",
    "s1": "人をそのまま大きくしたら、34mで歩くだけで骨が折れた #shorts",
    "s2": "15m級の巨人が人の骨なら、走った足が折れる。走れるのは11mまで #shorts",
    "s3": "超大型巨人の骨を足りるまで太くしたら、太ももの9割が骨になった #shorts",
    "s4": "歩ける超大型巨人を計算したら、体の重さは発泡スチロール並みだった #shorts",
    "s5": "巨人の骨を鉄にしても60mは歩けない。人の骨は鉄並みに強い #shorts",
}
LEAD = {
    "long": "『進撃の巨人』の超大型巨人は身長60m。もし人の体のまま60mにしたら、歩けるのか。体重は約2,860トン（ゾウ約480頭分）、骨の負担は人の35倍。人を少しずつ大きくする、走らせる、骨を鉄にする、骨を太くする、体を軽くする、の5つの仮の実験で確かめました。100年前に同じ計算をした学者の話も。",
    "s1": "歩くときの骨の負担は、つぶれる強さの約20分の1。背を2倍にすると負担も2倍。3mで1割、15mで4割、34mで骨の強さに届きます。",
    "s2": "激しく動くと骨の負担は歩くときの約3倍。人の骨のまま大きくなると、走れるのは身長11mまで。15m級は強さを3割超えます。",
    "s3": "骨の負担を人と同じにするには、骨の断面を体重と同じ約4万4千倍に。太さは人の約210倍、太ももの9割が骨になります。",
    "s4": "骨の負担を人と同じにするには、体重を35分の1の約80トンに。体の中身は水の35分の1、発泡スチロールに近い軽さです。",
    "s5": "人の骨は1平方mmに約20kgでつぶれる。ふつうの鋼は約25kg。鋼の骨でも歩けるのは42mまで。しかも鉄は骨の約4倍重い。",
}
SOURCES = """▼出典・計算
・作品の設定（超大型巨人 60m、壁 50m）をもとに、人と同じ形・同じ重さの体を仮定して計算しました（作品の体重ではありません）
・骨の強さ：Reilly & Burstein (1975) J Biomech 8:393
・歩く・走るときの骨のひずみ：Burr ら (1996) Bone 18:405
・動物の骨の安全率：Biewener (1989, 1990) Science
・鋼材の強さ：JIS G 3101（SS400）・JIS G 3106（SM570）、日本建設業連合会 鉄骨Q&A
・骨の密度：NIST（ICRU-44）
・太ももの太さ：産業技術総合研究所 人体寸法データベース2003、大腿骨の径：Karakaş & Harma (2008)
・ホールデン「On Being the Right Size」(1926)、ガリレオ『新科学対話』(1638)
・アフリカゾウ：Larramendi (2016)、最大級の恐竜：Mazzetta ら (2004)・Carballido ら (2017)、シロナガスクジラ：NOAA Fisheries
・作品の絵は使っていません。影絵と図は自分で描きました。動物の絵は AI（Google Gemini）で作成"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#進撃の巨人 #超大型巨人 #物理 #なぜ #解説"""

for k, t in TITLES.items():
    body = [LEAD[k], ""]
    if k == "long":
        ch = OUT / "chapters.txt"
        body += ["▼目次", ch.read_text(encoding="utf-8").strip() if ch.exists() else "(書き出し後に入る)", ""]
    elif LONG_ID:
        body += ["▼本編", f"https://youtu.be/{LONG_ID}", ""]
    body += [SOURCES, "", FOOT]
    (OUT / f"desc_{k}.txt").write_text("\n".join(body) + "\n", encoding="utf-8")
(OUT / "titles.json").write_text(json.dumps(TITLES, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok")
