"""電子レンジ 6 本の題名と概要欄(out/renji/desc_*.txt と titles.json)。python episodes/renji/make_desc.py [本編の動画ID]"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "renji"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

# 題名は scripts.md の「題名の案」のまま(ユーザー承認済み)
TITLES = {
    "long": "電子レンジは中から温めていなかった。厚さ10cmの肉は、表面が100℃でも中心は23℃",
    "s1": "電子レンジで厚さ10cmを温めると、表面100℃でも中心は23℃ #shorts",
    "s2": "電子レンジは休ませた方が中まで温まる。計算で16℃の差 #shorts",
    "s3": "電子レンジの周波数を8倍にすると、温まるのは0.4mmの皮だけ #shorts",
    "s4": "電子レンジの温めムラは6cmおき。波の長さで計算できる #shorts",
    "s5": "解凍で外だけ煮えるのは氷のせい。氷の中で電波は12m届く #shorts",
}
LEAD = {
    "long": "電子レンジの電波がしっかり届くのは、食べ物の表面から約2cmまで。水の測定値と熱の伝わり方から、電子レンジの中を計算で実験しました。"
            "厚さ2・4・6・10cmの水のかたまりを温めると、一番熱い所が100℃のとき真ん中は96・78・54・23℃。休み休み温めると6cmで70℃。"
            "周波数を変えたときの届く深さ、2,450MHzに決まっている理由、温めムラが約6cmおきになる理由、氷がほぼ素通りさせる理由まで確かめました。",
    "s1": "水の測定値から計算すると、2.45GHzの電波は約2cmで3分の1、6cmで30分の1。熱が生まれるのは外側だけで、真ん中は外から伝わる熱を待つしかありません。",
    "s2": "厚さ6cmの水のかたまりで計算。続けて温めると外が100℃のとき真ん中は54℃、10秒温めて20秒休むと70℃。休んでいる間に熱が中へ伝わります。",
    "s3": "水がいちばんよく吸うのは約20GHz。そこでは電波が表面0.4mmで吸われきってしまいます。2.45GHzなら約1.9cmまで届く、ちょうどいい周波数です。",
    "s4": "2.45GHzの電波の波の長さは約12cm。壁ではね返った波と重なって、強い所が半波長の約6cmおきに並びます。回る皿はそのムラを減らす仕組みです。",
    "s5": "氷の分子は固まっていて回れないので、電波を水の数千分の1しか吸いません。計算すると、氷の中で電波が3分の1になるのは約12m先です。",
}
SOURCES = """▼出典・データ
・電子レンジの周波数 2,450MHz ±50MHz：電波法施行規則 第46条の7（e-Gov 法令検索）
・2.4〜2.5GHz は世界共通の ISM 帯：ITU-R SM.2180
・熱は外側の層で生まれ、内側は外から伝わる熱で温まる：米国食品医薬品局（FDA）「Microwave Ovens」
・マイクロ波が入る深さの目安（1〜1.5インチ）：米国農務省（USDA）、ネブラスカ大学
・2.45GHz は水の共鳴ではない：West Texas A&M University（C. Baird）
・水が最もよく吸う周波数（約20GHz）：キール大学の講義資料
・水の誘電率：デバイの式（静的誘電率78.36・緩和時間8.27ピコ秒）で計算。氷の誘電損失：Koh (1997) Cold Regions Science and Technology 25(2)
・解凍で融けた所に電波が集まる：米国特許 4,520,250、家電Watch（2025年7月30日）
・日本初のターンテーブル式（1966年）：シャープ「オンリーワン商品・デバイス」
・半分のブドウの火花：Khattak, Bianucci, Slepkov (2019) PNAS 116(10):4000-4005
・届く深さ・厚さを変えて温める実験・波の長さは、上の数値から自分で計算しました（湯気で逃げる熱と横からの熱は数えない仮の計算）"""
FOOT = """音声：VOICEVOX:剣崎雌雄
運営：のこぎり社

#電子レンジ #なぜ #解説 #物理 #マイクロ波"""

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
