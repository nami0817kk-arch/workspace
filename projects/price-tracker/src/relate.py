"""商品名の近さで「似た商品」を選ぶ。通信しない。

これまでは同じジャンルの先頭から8件を取っていた。ジャンルは1,500件あるので、
実際には同じ顔ぶれを全ページで使い回していた（実測: 商品ページ60枚が
33商品・5通りしか出していなかった）。

困るのは2つある。読み手には関係のない商品が並ぶ。そして商品ページどうしの
リンクがひと握りに集中し、残りは一覧のページ送りからしか辿れない。
検索エンジンが奥まで来ない理由になる。
"""
import collections
import math
import re
import unicodedata

# 名前を語に割る。記号と助詞のたぐいは切れ目として扱う。
SPLIT = re.compile(r"[^0-9a-zぁ-んァ-ヶー一-龥]+")
# 1文字の語は「用」「型」のように単独では意味を持たないので落とす。
MIN_LEN = 2
# どの商品にも出る語（ケース・送料・セットなど）は近さの手がかりにならない。
# 出現が多すぎる語は無視する。候補が爆発するのを防ぐ意味もある。
MAX_DF_RATIO = 0.08
# ただし件数が少ないと、この割合では語が全部落ちてしまう（20件なら2件以上
# 出る語が全滅する）。実データ（12,658件）では 0.08 が効くので、
# 小さい集合のための下限だけ置く。
MIN_DF_CAP = 50
# 1つの語から見る候補の上限。よくある語で候補が数千件になるのを止める。
MAX_POSTING = 400


def tokens(name: str) -> list[str]:
    text = unicodedata.normalize("NFKC", str(name or "")).lower()
    return [w for w in SPLIT.split(text) if len(w) >= MIN_LEN]


def build_index(rows: list[dict], name_of) -> tuple[dict, dict, dict]:
    """語 → 商品コードの索引と、語の重み、商品ごとの語を返す。"""
    postings = collections.defaultdict(list)
    per_item = {}
    for row in rows:
        ws = set(tokens(name_of(row)))
        per_item[row["item_code"]] = ws
        for w in ws:
            postings[w].append(row["item_code"])
    total = max(len(rows), 1)
    cap = max(int(total * MAX_DF_RATIO), MIN_DF_CAP)
    weight = {}
    for w, codes in postings.items():
        if len(codes) > cap:
            continue          # ありふれた語は手がかりにしない
        # 珍しい語ほど強く効かせる
        weight[w] = math.log(total / len(codes))
    return postings, weight, per_item


def related(rows: list[dict], name_of, limit: int = 8) -> dict:
    """商品コード → 名前の近い順の商品リスト。

    同じ語をいくつ共有するかで測る。珍しい語ほど重い。
    手がかりが1つも無い商品には空を返す（呼ぶ側で従来の埋め方に倒す）。
    """
    by_code = {r["item_code"]: r for r in rows}
    postings, weight, per_item = build_index(rows, name_of)
    out = {}
    for row in rows:
        code = row["item_code"]
        score = collections.Counter()
        for w in per_item[code]:
            if w not in weight:
                continue
            codes = postings[w]
            if len(codes) > MAX_POSTING:
                continue
            for other in codes:
                if other != code:
                    score[other] += weight[w]
        best = [by_code[c] for c, _ in score.most_common(limit)]
        out[code] = best
    return out
