"""空の色 6 本の題名と概要欄(out/sky/desc_*.txt と titles.json)。python episodes/sky/make_desc.py [本編の動画ID]"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "sky"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

TITLES = {
    "long": "空が青いのは、青い光が赤の約6倍散らばるから。夕焼けは38倍の空気を通る",
    "s1": "空気に色はなかった。空が青いのは、青い光が赤の約6倍散らばるから #shorts",
    "s2": "青より紫の方が散らばるのに、空が紫に見えない3つの理由 #shorts",
    "s3": "夕焼けの光は、昼の38倍の空気を通ってくる。赤くなる理由 #shorts",
    "s4": "月の空は昼でも真っ黒だった。空気の99%は地上30kmまで #shorts",
    "s5": "火星の夕焼けは青かった。地球と逆になる理由 #shorts",
}
LEAD = {
    "long": "空気に色はないのに、空はなぜ青いのか。レイリー散乱の式で計算すると、青い光（450nm）は赤い光（700nm）の約6倍散らばります。紫に見えない理由、空気の層の厚さ、夕焼けで光が通る空気の長さ（地平線で約38倍）、雲が白い理由、火星の夕焼けが青い理由まで確かめました。",
    "s1": "散らばる強さは波の長さの4乗に反比例。450nmと700nmで計算すると約5.9倍。空のどこを見ても青い理由。",
    "s2": "波の短い紫の方がよく散らばるのに、空が紫に見えない。太陽の光に紫が少ない・上空で吸収される・目が感じにくい。",
    "s3": "太陽の高さ10度で約5.6倍、地平線で約38倍。Kasten & Young の式で、光が通る空気の長さを計算しました。",
    "s4": "空気の重さの半分は地上5.5kmまで、99%は約30kmまで。空気がほとんど無い月では、昼でも空は黒い。",
    "s5": "2015年4月、キュリオシティが撮った火星の夕焼けは、太陽のまわりが青い。昼の空はオレンジ。地球と逆です。",
}
SOURCES = """▼出典・データ
・レイリー散乱（波の長さの4乗に反比例）：UC Riverside Physics FAQ「Why is the sky blue?」、国立天文台 暦Wiki「大気/散乱」
・NASA Space Place「Why Is the Sky Blue?」、NASA Science「Visible Light」
・空気の通り道の長さ：Kasten & Young (1989) Applied Optics 28(22) の式で計算
・空気の重さの高さ分布：NASA Glenn「Earth Atmosphere Model」の式で計算
・雲が白い理由：英国気象庁 Met Office、香港天文台
・火星の夕焼け：NASA PIA19400（キュリオシティ、2015年4月）
・青空・夕焼け・雲・月・火星の絵は生成画像（想像の絵）です"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#空 #夕焼け #光 #物理 #なぜ #解説"""

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
