"""分野を広げた調べ(2026-11-19)の集計。ytch.py の出力(ch_all.json と追加の ch_b.json)を読み、真ん中の何倍かで分野・問い方ごとに数える。python tools/ytbroad.py(json のあるフォルダで)"""
import json, re, statistics as st
d = json.load(open("ch_all.json", encoding="utf-8")); d.update(json.load(open("ch_b.json", encoding="utf-8")))
rows = []; info = []
for k, v in d.items():
    new = [r for r in v["new"] if r["d"] is not None and 4 <= r["d"] <= 200]
    if len(new) < 8: continue
    med = st.median([r["n"] for r in new])
    info.append((k, len(new), int(med)))
    for r in new: rows.append(dict(ch=k, t=r["t"], n=r["n"], d=r["d"], x=r["n"] / max(med, 1), med=med))
json.dump(rows, open("rows.json", "w", encoding="utf-8"), ensure_ascii=False)
R = rows

def tab(D, name):
    print("==", name, "(本数 / 5倍以上% / 10倍以上% / 倍率の真ん中 / 5倍以上を出したch数)")
    out = []
    for k, p in D.items():
        rs = [r for r in R if re.search(p, r["t"])]
        if len(rs) < 8: continue
        h5 = [r for r in rs if r["x"] >= 5]
        out.append((len(h5) / len(rs), k, len(rs), 100 * len(h5) // len(rs), 100 * sum(r["x"] >= 10 for r in rs) // len(rs), round(st.median(r["x"] for r in rs), 2), len({r["ch"] for r in h5})))
    for o in sorted(out, reverse=True): print(" ", *o[1:])
base = [r["x"] for r in R]
print("全体", len(R), "5倍以上", 100 * sum(x >= 5 for x in base) // len(R), "% 10倍以上", 100 * sum(x >= 10 for x in base) // len(R), "%")
F = {
 "心・脳(自分の行動・感覚)": r"心理|脳|なぜか|人の特徴|特徴|性格|IQ|記憶|気がする|やめられない|眠れ|寝落ち",
 "仕事・職場・人間関係": r"職場|仕事|会社を辞め|友達|親切|恋愛|モテ|嫌われ|人間関係",
 "会社の儲け・カラクリ": r"儲|利益|売上|稼|カラクリ|戦略|経営|ビジネス|年商",
 "お金・給料・経済": r"お金|給料|経済|円|物価|税",
 "食べ物": r"食べ|味|卵|和牛|料理|弁当|おにぎり|マヨネーズ|貝|エビ|カニ|肉|魚を",
 "生き物": r"動物|生物|昆虫|魚|鳥|猫|犬|ゾウ|クジラ|哺乳類|コウモリ|ヒアリ|トラ|進化",
 "人の体・病気・寿命": r"体|病|寿命|免疫|心拍|がん|睡眠|視線",
 "宇宙": r"宇宙|銀河|火星|天体|星|ブラックホール|ハッブル|ウェッブ|アポロ",
 "地球・地理・自然": r"海|川|湖|山|雪|砂漠|深海|地球|島|ナイル",
 "歴史・昔": r"歴史|江戸|戦国|秀吉|文明|黒死病|古代|戦争|日露|旅順|キリスト|宗教|文書|年前",
 "人類の習慣の起源": r"いつから|発明|ようになった|始まり|起源",
 "日本と世界のちがい": r"日本(人)?(は|が|の|だけ|で)|世界的に|海外|ヨーロッパの人|アメリカ人",
 "技術・機械・乗り物": r"エンジン|車|クルマ|ロケット|飛行機|技術|CVT|タイヤ|トラック|USB|AI|OS|プログラミング",
 "ゲーム・会社の昔話": r"任天堂|セガ|FF|ゲーム|ファミコン",
 "都市伝説・謎": r"都市伝説|UFO|ムー|謎の|ミステリー|消えた",
 "社会・人口・世代": r"世代|子供が増えない|人口|若者|社会|ルール",
}
tab(F, "分野")
Q = {
 "なぜ〜のか(問い)": r"なぜ|何故",
 "〜ない理由・いない・できない(不在と上限)": r"(ない|いない|できない|なれない)(理由|のか|\?|？)",
 "なのに・のに(ギャップ)": r"のに|なのに",
 "正体・カラクリ・仕組み": r"正体|カラクリ|仕組み|秘密",
 "本当の理由": r"本当の理由|意外な理由|衝撃の理由",
 "特徴・共通点・N選": r"特徴|共通点|\d+選|\d+つの",
 "もしも・〜したら": r"もし|したら|行くと",
 "知っていますか？(問いかけ)": r"知っていますか|知ってる",
 "どう違う・比べ": r"違う|違い|比較|比べ|×",
 "【】つき": r"【",
 "数字あり": r"\d",
 "実は・異常・衝撃": r"実は|異常|衝撃|ヤバ|恐ろしい",
}
tab(Q, "問い方")
