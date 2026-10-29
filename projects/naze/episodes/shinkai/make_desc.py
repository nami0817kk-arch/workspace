"""深海魚 6 本の題名と概要欄(out/shinkai/desc_*.txt と titles.json)。python episodes/shinkai/make_desc.py [本編の動画ID]"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out" / "shinkai"
OUT.mkdir(parents=True, exist_ok=True)
LONG_ID = sys.argv[1] if len(sys.argv) > 1 else ""

# 題名は scripts.md の「題名の案」のまま(本編は A)
TITLES = {
    "long": "深海魚は水深8,336mでもつぶれない。指先に870kgの水圧で平気な理由を計算で確かめる",
    "s1": "水深1万mの水圧は指先に1.1トン。それでも魚はつぶれない #shorts",
    "s2": "ペットボトルの空気を水深8,336mに沈めたら、直径1cmの粒になった #shorts",
    "s3": "1000気圧で押しても水は4%しか縮まない。深海魚がつぶれない理由 #shorts",
    "s4": "しんかい6500の殻で水深1万mへ行くなら、厚さは13cm要る #shorts",
    "s5": "魚が住めるのは8,200mまでかもしれない。決めるのは体の中の液 #shorts",
}
LEAD = {
    "long": "2022年、伊豆・小笠原海溝の水深8,336mで魚が撮影されました。そこでは指先1平方cmに約870kgの重さがかかります。それでも魚がつぶれないのはなぜか。"
            "深さごとの水圧、空気を沈める、水を1,000気圧で押す、潜水艇の殻の厚さ、体の中の液の濃さの5つを、計算で確かめました。"
            "答えは、つぶれる空気を持たないことと、体の中の水が外の水と釣り合っていること。魚が住める深さの限界の話まで。",
    "s1": "水深10mで指先1平方cmに約1kg、1,000mで約100kg、10,935mで約1.1トン。水圧の計算と、深海魚がつぶれない理由（つぶれる空気がない・中と外が釣り合っている）。",
    "s2": "500mLの空気を水深8,336mへ沈めると、ボイルの法則で845分の1の約0.6mL（直径約1cmの粒）。深海魚は、つぶれる空気を体に持っていません。",
    "s3": "海水を1,000気圧で押しても、縮むのは約4%（1Lが約960mL）。空気なら約1,000分の1。もし海が縮まなかったら、海面は約30m高い計算です。",
    "s4": "しんかい6500の殻と同じ余裕で計算すると、水深1,000mなら約1cm、10,935mなら約13.5cm。魚は殻なしで泳ぐのに、人はなぜ厚い殻が要るのか。",
    "s5": "深い所の魚ほど体の中にTMAOという物質を多く持ち、約8,200mで体の液が海水と同じ濃さになる、という2014年の研究の計算。魚の最深記録は8,336mです。",
}
SOURCES = """▼出典・データ
・8,336mの魚の撮影（2022年8月・伊豆・小笠原海溝）：東京海洋大学 プレスリリース（2023年4月3日）、西オーストラリア大学（2023年4月）
・捕獲の最深記録（日本海溝 8,022m）：西オーストラリア大学（2023年4月）
・チャレンジャー海淵 10,935m：Greenaway ほか (2021) Deep-Sea Research Part I 178:103644
・しんかい6500 の殻（チタン合金・内径2.0m・厚さ73.5mm）：JAMSTEC
・1万m級の潜水艇（内径1.5m・厚さ90mm）：Triton Submarines（メーカーの発表）
・発泡スチロールのカップを深海へ：NOAA Ocean Exploration（調査船 Okeanos Explorer EX1705 の航海記）
・海の平均の深さ 3,682m：Charette & Smith (2010) Oceanography 23(2)
・マダラの水分（100gあたり80.9g）：文部科学省 日本食品標準成分表（八訂）増補2023年。※深海魚そのものの値ではありません
・クサウオのなかまにうきぶくろが無いこと：Gerringer ほか (2017) Royal Society Open Science 4:171063
・TMAO・体の液の濃さ・約8,200m：Yancey ほか (2014) PNAS 111(12):4461-4465。TMAOがたんぱく質を守る働きや、約8,200mが魚の限界になるという話は、研究者の見方（考えられている）で、餌の量など他の理由もありえます
・水圧・水の縮み：海水の国際的な計算式 TEOS-10（IOC・SCOR・IAPSO 2010）を Python の gsw 3.6.23 で計算。指先の広さは1平方cmと置きました
・空気の縮み：ボイルの法則（温度は変えない）で計算
・潜水艇の殻の厚さ：「しんかい6500と同じ余裕で」と置いて、球の殻にかかる力から計算した値で、実際の設計の値ではありません（座屈などは数えていません）
・数字は上のデータから自分で計算しました"""
FOOT = """音声：VOICEVOX:剣崎雌雄
絵はAIで作成（Google Gemini）
運営：のこぎり社

#深海魚 #水圧 #深海 #なぜ #解説 #物理"""

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
