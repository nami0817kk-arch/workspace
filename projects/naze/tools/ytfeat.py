import json, re, statistics as st
d = json.load(open("ch_all.json", encoding="utf-8"))
SKIP = {"The Last Day", "GENKI LABO", "ミリタリースタジオ"}
rows = []
for k, v in d.items():
    if k in SKIP: continue
    new = [r for r in v["new"] if r["d"] is not None and 4 <= r["d"] <= 200]
    if len(new) < 8: continue
    med = st.median([r["n"] for r in new])
    for r in new:
        rows.append(dict(ch=k, t=r["t"], n=r["n"], d=r["d"], x=r["n"] / max(med, 1)))
F = {
 "不在形(ない・いない・できない・見えない)": r"ない(?!か)|無い|消え|絶滅しない",
 "住んでいない・人がいない": r"住んでいない|住まない|人がいない|誰もいない|無人|空白|空っぽ|住めない",
 "暮らせる・住む(ありえない場所)": r"暮らせる|住むのか|暮らす|人が住|こんな(所|場所|山奥|離島|島)",
 "橋・道・行けない": r"橋|トンネル|行けない|繋が|つなが|渡れ|行き来|空港がない|道路",
 "上限(より高い・限界・できない)": r"より(高い|大きい|深い|速い)|限界|できない|作れない|存在しない|止まる",
 "なのに": r"のに[、,]?|にもかかわらず|なのに",
 "一番・最大・世界一": r"世界一|日本一|最大|最強|最も|いちばん|一番",
 "正体・秘密・真実・謎": r"正体|秘密|真実|の謎|ミステリー",
 "昔の年で始まる": r"^[【\[]?[^】]{0,8}】?\s*(約)?\d[\d,]*(万|億)?年(前)?",
 "N選・TOP": r"\d+選|TOP\s?\d+|ランキング|\d+つの",
 "もしも": r"もし",
 "なぜ": r"なぜ|何故",
 "理由": r"理由",
 "数字あり": r"\d",
 "【】": r"【",
 "日本の地名": r"日本|東京|大阪|北海道|四国|九州|本州|沖縄|富士|琵琶湖|瀬戸内|名古屋|京都|福岡|関東|関西|東北|新潟|千葉|伊豆|阿蘇|桜島|佐渡|青森|鹿児島|横浜|神戸|広島",
 "海を抜く・水を抜く・3D・標高データ": r"抜|標高データ|3D|３D|断面|切って",
 "同じ縮尺・並べ・比較": r"同じ縮尺|並べ|比較|比べ",
 "計算・シミュレーション": r"計算|シミュレーション|検証",
}
def stat(sel):
    xs = [r["x"] for r in sel]
    if not xs: return (0, 0, 0, 0)
    return (len(xs), st.median(xs), sum(x >= 3 for x in xs) / len(xs), sum(x >= 10 for x in xs) / len(xs))
out = []
n, m, h3, h10 = stat(rows)
out.append(f"全体 {n}本 真ん中の倍率 {m:.2f} 3倍以上 {h3:.0%} 10倍以上 {h10:.0%}  チャンネル {len({r['ch'] for r in rows})}")
for name, pat in F.items():
    a = [r for r in rows if re.search(pat, r["t"])]; b = [r for r in rows if not re.search(pat, r["t"])]
    sa, sb = stat(a), stat(b)
    out.append(f"{name:<24} あり {sa[0]:>4}本 倍率{sa[1]:.2f} 3倍↑{sa[2]:>4.0%} 10倍↑{sa[3]:>4.0%} ｜ なし 倍率{sb[1]:.2f} 3倍↑{sb[2]:>4.0%} 10倍↑{sb[3]:>4.0%}")
open("feat.txt", "w", encoding="utf-8").write("\n".join(out))
rows.sort(key=lambda r: -r["x"])
with open("hits.txt", "w", encoding="utf-8") as f:
    for r in rows:
        if r["x"] >= 4 and r["n"] >= 50000: f.write(f"{r['x']:>6.1f}倍 {r['n']/1e4:>6.1f}万 {r['d']:>3}日 {r['ch'][:10]:<10} {r['t'][:70]}\n")
with open("miss.txt", "w", encoding="utf-8") as f:
    import random; random.seed(1)
    lo = [r for r in rows if r["x"] <= 0.5]
    for r in random.sample(lo, min(150, len(lo))): f.write(f"{r['x']:>5.2f}倍 {r['n']:>7} {r['ch'][:10]:<10} {r['t'][:70]}\n")
json.dump(rows, open("rows.json", "w", encoding="utf-8"), ensure_ascii=False)
print("\n".join(out)); print(sum(1 for _ in open("hits.txt", encoding="utf-8")))
