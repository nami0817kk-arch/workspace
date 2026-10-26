"""富士山のセット 6 本の題名と概要欄(out/fuji/desc_*.txt と titles.json)。python episodes/fuji/make_desc.py [本編の動画ID]"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "fuji"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {
    "long": "富士山は左右対称ではなかった。西は38度、東は22度。標高データで測った日本一の山の形",
    "s1": "富士山は左右対称ではなかった。西は38度、東は22度 #shorts",
    "s2": "富士山の中には、古い火山が3つ隠れていた。今の山は1万年ほど #shorts",
    "s3": "富士山の体積は400立方km。1辺7.4kmのサイコロと同じだった #shorts",
    "s4": "富士山の最後の噴火は山頂ではなかった。1707年、江戸に灰が降った #shorts",
    "s5": "富士山の頂上は8月でも平均6.4度。太陽に近いのに寒い理由 #shorts",
}
LEAD = {
    "long": "富士山は、左右がそろったきれいな三角形。でも国土地理院の標高データで測ると、山頂近くの傾きは西が38度、東が22度でした。それでもきれいに見える理由、中に眠る古い火山、山頂ではない所からの噴火、頂上が寒い理由まで、データと国の資料で確かめました。",
    "s1": "国土地理院の標高データで富士山の斜面を測ると、東と西で16度も違いました。それでもきれいに見える理由。",
    "s2": "今の富士山は約1万1000年前から。その中には、先小御岳・小御岳・古富士という古い火山が眠っています。",
    "s3": "富士山の体積は約400立方km。1辺7.4kmのサイコロと同じです。それだけの量が積み上がった仕組み。",
    "s4": "1707年の宝永噴火は、山頂ではなく南東の斜面から。火山灰は江戸、川崎、房総半島まで届きました。",
    "s5": "富士山の頂上は、8月でも平均6.4度、1年の平均はマイナス5.9度。太陽に近いのに寒い理由。",
}
SOURCES = """▼出典・データ
・地形：国土地理院 標高タイル・空中写真（高さは1.3倍に強調）。斜面の傾きは標高データから計算
・国土地理院「三角点『富士山』の新しい標高」（2024年12月）、日本の主な山岳標高
・気象庁『日本活火山総覧』富士山、富士山の火山活動解説資料（噴火警戒レベル）、富士山の気温の平年値（1991〜2020年）、『気象観測の手引き』
・内閣府 災害教訓の継承に関する専門調査会『1707 富士山宝永噴火』報告書（平成18年3月）
・山梨県「富士山のすがた」
・地図：Natural Earth、NOAA ETOPO1、プレート境界 Bird (2003)、国土地理院 淡色地図"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#富士山 #火山 #地形 #宝永噴火 #なぜ #解説"""

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
