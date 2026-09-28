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


# 数量・容量で終わる語は「何があるか」を伝えない（350ml・24本・2ケース）。
UNIT_TAIL = re.compile(r"(?:ml|cc|kg|mg|mm|cm|pk|[0-9])(?:本|個|枚|袋|缶|箱|入|"
                       r"ケース|パック|セット|色|点|台|足|膳|食|人前)?$")
MIN_SHARE = 0.02      # そのジャンルの2%以上に出る語だけ見る
TERM_LIMIT = 5
# 既に採った語とこれだけ一緒に出るなら、同じものの別表記とみなす
SAME_THING = 0.7


def genre_terms(names_by_genre: dict, limit: int = TERM_LIMIT) -> dict:
    """ジャンルごとに「そのジャンルらしい語」を選ぶ。

    価格.com のトップは、カテゴリの下に「ノートパソコン タブレット
    ハードディスク PCパーツ 周辺機器」とサブ項目を2行置いている。あれが面の
    情報量を作っていて、「ここに何があるか」が一目で分かる。うちは楽天の
    ジャンルを8つしか取っておらず、その下の階層を持っていないので、
    **商品名から出す**。

    ただ数えるだけだと、どのジャンルにもある語（セット・送料無料）が並ぶ。
    そのジャンルでの出現率を全体の出現率で割った値（どれだけ偏っているか）で
    選ぶと、家電なら「静音・コンパクト・省エネ」、テレビゲームなら
    「switch・nintendo・コントローラー」が出る（2026-09-28 実測）。
    """
    per, total, all_n = {}, collections.Counter(), 0
    for genre, names in names_by_genre.items():
        count = collections.Counter()
        sets = []
        for name in names:
            words = set(tokens(name))
            sets.append(words)
            for word in words:
                count[word] += 1
        per[genre] = (count, len(names), sets)
        total.update(count)
        all_n += len(names)
    if not all_n:
        return {}

    out = {}
    for genre, (count, n, sets) in per.items():
        scored = []
        for word, k in count.items():
            if k < n * MIN_SHARE or len(word) < 2 or UNIT_TAIL.search(word):
                continue
            share = k / n
            lift = share / (total[word] / all_n)
            scored.append((lift * share, word))
        scored.sort(reverse=True)
        picked = []
        for _, word in scored:
            # 「イヤホン」を採ったあとに「ワイヤレスイヤホン」を並べても
            # 行き先が増えない。どちらかが他方を含む語は飛ばす。
            if any(word in got or got in word for got in picked):
                continue
            # 文字種が違ううえ同じ商品名に一緒に書かれてばかりなら、同じものの
            # 別表記。「ヤマハ」と「yamaha」、「スイッチ」と「switch」がこれで、
            # 読みの対応は辞書なしでは付けられないが、共起なら数えられる。
            # 文字種の条件が無いと、同じ商品群にしか出ない別のもの
            # （「ヤマハ」と「電子ピアノ」）まで落ちる。
            if any(word.isascii() != got.isascii()
                   and (sum(1 for ws in sets if word in ws and got in ws)
                        >= min(count[word], count[got]) * SAME_THING)
                   for got in picked):
                continue
            picked.append(word)
            if len(picked) >= limit:
                break
        out[genre] = picked
    return out
