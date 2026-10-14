"""YouTube の検索候補から、名前のあとによく続く語を数える（2026-10-08）。

    python tools/keywords.py 久保建英
    python tools/keywords.py アーセナル --out research/metrics/keywords_arsenal.md
    python tools/keywords.py --note research/20261008_finance_arteta.yaml
    python tools/keywords.py --date 20261008

**なぜ要るか。** このチャンネルで作りによって太くできる経路は検索だけで
（直近28日で 5.4%・608回）、しかも**検索で来ている上位5語のうち4語が
日本人選手名**だった（中村敬斗44・久保建英21・鎌田大地17・海外サッカー14・
上田綺世13）。シリーズ（クラブ紹介・選手紹介・スタジアム・比べる…）は
題材がクラブ名か人名で決まるので、「その名前のあとに人が実際に打っている語」が
分かれば、題名の後半とタグをそこに寄せられる。いまは勘で決めている。

**やっていること。** 検索候補（suggestqueries.google.com、ds=yt）を
「名前」「名前＋空白」「名前＋あ・か・さ…の頭文字」で取り、候補の中で
名前のあとに続く語を数えて並べる。サッカーの文脈で中身と食い違う語には印を付け、
**決まりに当たるもの（Jリーグ・女子・賭け・違法視聴・ゲーム・ハイライト）は
候補から外して、外した理由を一緒に出す**。

**出すもの**（標準出力に日本語、控えは `research/keywords/<名前>.json`）:
続く語の数の多い順（印つき）／題名の候補3つ／タグの候補15／ハッシュタグの候補3つ／
外した語とその理由。**どれも下書きで、決めるのは人。**

**通信は curl を subprocess で呼ぶ**（このPCの Python の通信は証明書で落ちることがある）。
1回ごとに間を空け、1つの名前で取る回数に上限を置く（相手に負担をかけない）。
suggestqueries は無料。**YouTube Data API も Gemini も1回も呼ばない。**

下敷きは別チャンネルの `projects/rekishi-chiso/chiso/keywords.py`（10-07）。
違うのは、印を付ける語（ゲーム・大河 → サッカーで中身と食い違うもの）と、
タグ・ハッシュタグ・題名をこのプロジェクトの決まり（`src/tags.py`・`src/review.py`・
`src/variety.py`）に通すところ。
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
import urllib.parse
from collections import Counter
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, ".")

from src import clubs as club_book     # noqa: E402  クラブ名の辞書（別名→正式名）
from src import review as review_mod   # noqa: E402  題名の決まり（主語・答えを隠す）
from src import tags as tags_mod       # noqa: E402  タグとハッシュタグの決まり
from src import variety as variety_mod  # noqa: E402  結び方の見方

URL = "https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&hl=ja&q={q}"
# 各行の頭。これで「名前＋あ行」「名前＋か行」…の候補が出る（12回）
ROW_HEADS = "あかさたなはまやらわ"
ALL_KANA = ("あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほ"
            "まみむめもやゆよらりるれろわをん")              # --all：あ〜ん（48回）
WAIT = 1.2            # 1回ごとに空ける秒数（相手に負担をかけない）
MAX_QUERIES = 14      # 1つの名前で取る回数の上限。--all でも50まで
MAX_QUERIES_ALL = 50
OUT_DIR = Path("research/keywords")
NOTE_DIR = Path("research")

# ───────────────────────────── 印を付ける語 ─────────────────────────────
# 下敷き（歴史の地層）は「ゲーム・大河」で分けていた。こちらは**サッカーの文脈で
# 中身と食い違うもの**で分ける。印は2種類ある:
#   HARD … 決まりに当たるので**候補から外す**（外した理由を出す）
#   SOFT … 表には残すが、題名とタグには使わない（人が見て判断する）

# ゲーム。**中身と食い違うタグは付けない**（`src/tags.py` の決まり。2026-09-10 に
# 「ハイライト」を、09-15 に「チャンピオンズリーグ」を同じ理由で外している）
GAME = ("ウイイレ", "ウイニングイレブン", "efootball", "イーフト", "イーフトボール",
        "fifa", "fc26", "fc25", "fc24", "fc24", "ultimate team", "パワサカ", "サカつく",
        "ゲーム", "攻略", "ガチャ", "ガチャ 爆死", "選手カード", "カード", "能力値", "実況",
        "fm26", "フットボールマネージャー", "マイクラ", "ロブロックス", "スキル 設定")
# **FIFA は団体の名前でもある。**この語が一緒にあるときはゲームと数えない
GAME_EXCEPT = ("ランキング", "ワールドカップ", "会長", "インファンティーノ", "クラブワールドカップ")
# Jリーグ。**扱うリーグは欧州7つのまま**（2026-09-15 に MLS・リーガMX を足す案を見送り）
JLEAGUE = ("jリーグ", "j1", "j2", "j3", "jリーグ時代", "ルヴァン", "天皇杯", "jリーグ 移籍",
           "fc東京", "川崎フロンターレ", "鹿島アントラーズ", "横浜fマリノス")
# 女子サッカーは扱わない（2026-09-16 指示。日本人が絡む題材でも入れない）
WOMEN = ("女子", "女子サッカー", "なでしこ", "weリーグ", "女子代表", "女子ワールドカップ")
# 賭け。収益化の審査に関わるので題名・タグ・概要欄に入れない
BET = ("オッズ", "ブックメーカー", "賭け", "ベット", "bet", "toto", "カジノ", "必勝法",
       "予想 オッズ", "ブック")
# 違法視聴・配信。**こちらは試合映像を持っていない**（権利の関係で使えない）。
# 「ハイライト」を 2026-09-10 に外したのと同じ理由で、この並びは中身と食い違う
PIRACY = ("無料", "無料視聴", "無料 視聴", "海賊", "違法", "ライブ配信", "生配信", "生中継",
          "見逃し配信", "フルマッチ", "フル試合", "ハイライト", "ハイライト 動画",
          "ストリーミング", "どこで見れる", "放送", "中継", "dazn", "abema")

# ── ここから下は外さない。印を付けて表に残し、人が判断する ──
# 人の話。嫁・彼女・年収…は本人の私生活なので、こちらで勝手に題材にしない。
# **年俸は題材にしたことがある**（10-08 アルテタの契約）ので、外さずに印だけ付ける
PRIVATE = ("嫁", "妻", "彼女", "彼氏", "家", "高校", "父", "母", "兄", "弟", "姉", "妹",
           "子供", "息子", "宗教", "身長", "体重", "国籍", "性格", "プライベート",
           "インスタ", "すっぴん", "タトゥー")
# **語の一部でも当たるもの**（「塩貝けんと喧嘩」のような、くっついた形で検索されている語）。
# 短い語（母・家）を一部で見ると「母国」「国家」に当たるので、そちらは上の一覧（語ごと）で見る
PRIVATE_PART = ("結婚", "離婚", "熱愛", "恋愛", "年収", "年俸", "自宅", "実家", "学歴",
                "家族", "喧嘩", "けんか", "不仲", "炎上", "噂", "批判", "叩かれ", "失言")
# 一般の語・ほかのチャンネルの出し方。題名とタグには使わない
# **「海外の反応」は入れない。**このチャンネルは海外の反応を必ず混ぜる決まりなので、
# 中身と食い違わない（2026-09-16）
GENERIC = ("まとめ", "最新", "動画", "とは", "すごさ", "やばい", "面白い", "おもしろ",
           "ゆっくり", "ゆっくり解説", "切り抜き", "字幕", "曲", "歌", "bgm", "cm",
           "ダンス", "tiktok", "shorts", "ショート", "アニメ", "コラ", "ネタ", "mad",
           "ai", "mv", "asmr", "似てる", "そっくり", "モノマネ", "歌ってみた", "替え歌",
           "読み方", "英語", "一覧")

HARD = ("game", "jleague", "women", "bet", "piracy")     # 候補から外す
SOFT = ("private", "generic")                            # 表に残すが使わない
MARKS = {"game": "ゲーム", "jleague": "Jリーグ", "women": "女子", "bet": "賭け",
         "piracy": "視聴・配信", "private": "人の話", "generic": "一般の語", "": ""}
REASONS = {
    "game": "ゲームの話。中身と食い違うタグは付けない（src/tags.py）",
    "jleague": "Jリーグは扱わない（扱うリーグは欧州7つ。2026-09-15）",
    "women": "女子サッカーは扱わない（2026-09-16 指示）",
    "bet": "賭けの語。収益化の審査に関わるので使わない",
    "piracy": "試合映像・配信の話。こちらは映像を持っていないので中身と食い違う",
    "private": "本人の私生活の話。題材にするかは人が決める（印だけ付けて残す）",
    "generic": "一般の語・ほかのチャンネルの出し方。題名とタグには使わない",
}


def mark(word: str) -> str:
    """その語の印。HARD（外す）か SOFT（使わない）か、空（使える）か。"""
    w = str(word).strip().lower()
    if not w:
        return ""
    tokens = set(w.split())

    def hit(key: str) -> bool:
        # ai・bet・fifa などの短い英字は、語として一致したときだけ数える
        # （「bettina」の bet、「samurai」の ai を拾わないため）
        if key.isascii() and len(key) <= 4:
            return key in tokens
        return key in w

    if any(hit(g) for g in GAME) and not any(x in w for x in GAME_EXCEPT):
        return "game"
    if any(hit(x) for x in JLEAGUE):
        return "jleague"
    if any(hit(x) for x in WOMEN):
        return "women"
    if any(hit(x) for x in BET):
        return "bet"
    if any(hit(x) for x in PIRACY):
        return "piracy"
    if w in PRIVATE or any(t in PRIVATE for t in tokens) or any(p in w for p in PRIVATE_PART):
        return "private"
    if w in GENERIC or any(t in GENERIC for t in tokens):
        return "generic"
    return ""


# ───────────────────────────── 検索候補を取る ─────────────────────────────
def fetch(query: str, curl: str = "curl") -> list[str]:
    """検索候補を1回取る。失敗したら空（止めない）。

    **通信は curl を subprocess で呼ぶ形だけ。**このPCの Python の通信は
    証明書で落ちることがある（`network-probe.txt`）。
    """
    url = URL.format(q=urllib.parse.quote(str(query)))
    try:
        r = subprocess.run([curl, "-s", "--max-time", "15", "-A", "Mozilla/5.0", url],
                           capture_output=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return []
    if r.returncode != 0 or not r.stdout:
        return []
    try:
        data = json.loads(r.stdout.decode("utf-8", errors="replace"))
    except ValueError:
        return []
    return [str(x) for x in data[1]] if isinstance(data, list) and len(data) > 1 else []


def queries(name: str, full: bool = False) -> list[str]:
    """取りにいく言葉。上限（MAX_QUERIES）で切る。"""
    heads = ALL_KANA if full else ROW_HEADS
    limit = MAX_QUERIES_ALL if full else MAX_QUERIES
    return ([name, name + " "] + [f"{name} {k}" for k in heads])[:limit]


def collect(name: str, full: bool = False, wait: float = WAIT, fetcher=fetch) -> dict:
    """名前ごとに候補を取る。**1回ごとに間を空ける。**"""
    out: dict[str, list[str]] = {}
    for i, q in enumerate(queries(name, full)):
        if i and wait:
            time.sleep(wait)
        out[q] = fetcher(q)
    return out


def tail(suggestion: str, name: str) -> str:
    """候補から名前を除いた残り。"""
    s = str(suggestion).strip()
    s = s[len(name):] if s.startswith(name) else s.replace(name, " ")
    return re.sub(r"\s+", " ", s).strip()


def count(name: str, raw: dict) -> tuple[Counter, Counter]:
    """(語の点, 続きの言い回しの点)。

    候補の上のほうほど重く（1位 2.0点 … 10位 1.1点）、何回も出る候補は
    出た回数ぶん足す。suggestqueries は実数を返さないので、順位を重みにする。
    """
    words, phrases = Counter(), Counter()
    for sugg in raw.values():
        for pos, s in enumerate(sugg or []):
            rest = tail(s, name)
            if not rest:
                continue
            pt = 1 + max(10 - pos, 1) / 10
            phrases[rest] += pt
            for w in dict.fromkeys(rest.split(" ")):
                # 「久保建英の移籍」→ 移籍（印の付いた語はそのまま）
                if w.startswith("の") and len(w) >= 2 and not mark(w):
                    w = w[1:]
                if len(w) >= 2 or re.search(r"[一-鿿]", w):
                    words[w] += pt
    return words, phrases


def plain_words(words: Counter) -> list[str]:
    """印の無い語（＝題名とタグに使える語）を点の高い順に。"""
    return [w for w, _ in words.most_common() if not mark(w)]


def dropped(words: Counter) -> list[tuple[str, float, str, str]]:
    """外した語・使わない語を（語, 点, 印, 理由）で。**外したことを必ず出す。**"""
    out = []
    for w, n in words.most_common():
        m = mark(w)
        if m:
            out.append((w, round(n, 1), MARKS[m], REASONS[m]))
    return out


# ───────────────────────────── タグとハッシュタグ ─────────────────────────────
def tag_candidates(name: str, plain: list[str], book=None) -> list[str]:
    """タグの候補15（`src/tags.py` の決まりに通す）。

    **タグ（合計500字・1つ30字）とハッシュタグは別物**（2026-09-15）。
    ここで出すのはタグの候補で、並べ方は `src/tags.py` と同じ
    「**人の名前をいちばん前に**、分類語はいちばん後ろ」。
    あふれたら後ろから落ちる（`tags.fit`）ので、名前が守られる。

    「名前＋語」の形も入れる。**それが人が実際に打っている言葉**だから。
    """
    cand: list[str] = [str(name).strip()]
    for canon in club_book.canonical(name, book):          # 別名で渡されたとき（Arsenal → アーセナル）
        if canon not in cand:
            cand.append(canon)
    for w in plain[:8]:                                    # 実際に打たれている言い回し
        cand.append(f"{name} {w}")
    for w in plain:                                        # 語そのまま
        cand.append(w)
    cand += list(tags_mod.BASE)                            # 分類語はいちばん後ろ
    return tags_mod.fit(cand)[:15]


def hashtag_candidates(name: str, plain: list[str]) -> list[str]:
    """ハッシュタグの候補3つ。

    **概要欄に出すのは前の3つだけ**（`tags.HASHTAGS`）。動画の上に丸いボタンで
    出るのもこの3つで、**16個以上並べると YouTube はハッシュタグを全部無視する**
    （`tags.HASHTAG_LIMIT = 15`）。だから数を稼ぐ意味が無い。

    **ハッシュタグに空白は使えない**（YouTube が切る）ので、「名前＋語」の形は
    タグだけに使い、ここでは空白の無い語だけを並べる。
    """
    out = [str(name).strip().replace(" ", "")]
    for w in plain:
        if " " not in w and len(w) >= 2 and w not in out:
            out.append(w)
    for fallback in tags_mod.BASE:                         # 語が薄いときの埋め
        if fallback not in out:
            out.append(fallback)
    return tags_mod.hashtags([t for t in out if len(t) <= tags_mod.MAX_TAG_LENGTH])


# ───────────────────────────── 題名の候補 ─────────────────────────────
# **結び方がそろわないように、形の違うものを並べてある**（`src/variety.py` の
# `_tail_kind` で見る。2026-09-08 に9本中7本が「〜がこちらです」で終わっていた）。
# どれも「頭は名前」「答えを言い切らない」「札は頭に置かない」を満たす形
# **語が人の名前でも読める形にしてある**（続く語の上位には共演者・同僚の名前が来る。
# 「久保建英の長友は…」のような形にならないよう、「の＋語」で始める形は使わない）
TITLE_FORMS = (
    "{name}、{w1}はどうなっているのか",           # 問いかけ
    "{name}と{w1}。記録が示す中身",               # 体言止め（中身）
    "{name}　{w1}と{w2}、数字で見える差",         # 体言止め（連体形＋名詞）
    "{name}、{w2}が変えたもの",                   # 体言止め（連体形＋形式名詞）
    "{name}はなぜ{w2}と並べて語られるのか",       # 問いかけ（別の結び）
    "{name}、{w3}をめぐって動いたのは",           # 言いさし（〜のは）
    "{name}の{w3}について、記録が示す評価は",     # 「〜は」で切る
)
# 語が足りないときの埋め（当たり障りのない語で、決まりは満たす）
FILLER = ("現状", "評価", "数字")


def recent_tails(limit: int = 12, root: Path | None = None) -> list[str]:
    """直近の本の結び方（`research/<日付>_*.yaml` の `theme.title`）。

    **直近の本の結びと重ならない候補を選ぶ**ため。1本ずつの点検では
    「答えを隠しているか」しか見えず、そろいは並べないと気づけない。
    """
    import yaml

    base = Path(root) if root else NOTE_DIR
    if not base.exists():
        return []
    notes = sorted((p for p in base.glob("*.yaml")
                    if re.match(r"^\d{8}_", p.name)
                    and not p.name.endswith(("_candidates.yaml", "_topics.yaml",
                                             "_series_plan.yaml"))),
                   key=lambda p: p.name, reverse=True)[:limit]
    out: list[str] = []
    for path in notes:
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        except (OSError, yaml.YAMLError):
            continue
        title = str(((data.get("theme") or {}) if isinstance(data.get("theme"), dict) else {})
                    .get("title") or data.get("title") or "").strip()
        if title:
            out.append(variety_mod._tail_kind(title))
    return out


def title_ok(title: str) -> tuple[bool, str]:
    """題名の決まりを満たすか（`src/review.py` の検査をそのまま当てる）。"""
    if title.strip().startswith("【"):
        return False, "札が頭にある"
    shim = SimpleNamespace(title=title)                     # 検査は title しか見ない
    subject = review_mod.check_title_subject(shim)
    if not subject.ok:
        return False, subject.detail
    hook = review_mod.check_title_hook(shim)
    if not hook.ok:
        return False, hook.detail
    return True, ""


def title_candidates(name: str, plain: list[str], avoid: list[str] | None = None,
                     want: int = 3) -> list[str]:
    """題名の候補3つ（下書き）。

    決まり：頭は人名かクラブ名（`check_title_subject`）／答えを言い切らない
    （`check_title_hook`）／**結び方を定型にしない**（候補どうしでも、直近の本とも
    同じ末尾にしない）／札（【速報】等）は頭に置かない。
    """
    words = [w for w in plain if len(w) >= 2][:6] + list(FILLER)
    w1, w2, w3 = words[0], words[1], words[2]
    out: list[str] = []

    def collect_titles(taken: list[str]) -> None:
        for form in TITLE_FORMS:
            if len(out) >= want:
                return
            title = form.format(name=name, w1=w1, w2=w2, w3=w3)
            if title in out:
                continue
            ok, _why = title_ok(title)
            if not ok:
                continue
            kind = variety_mod._tail_kind(title)
            if kind in taken:                               # 同じ結び方は並べない
                continue
            taken.append(kind)
            out.append(title)

    collect_titles(list(avoid or []))
    # **3つに届かなかったら、直近の本との重なりだけは譲る**（候補どうしの重なりは譲らない）。
    # 直近の結びを全部避けると、形が尽きて1つしか出ない日がある
    if len(out) < want:
        collect_titles([variety_mod._tail_kind(t) for t in out])
    return out


# ───────────────────────────── 出すもの ─────────────────────────────
def build(name: str, raw: dict, avoid: list[str] | None = None, book=None) -> dict:
    """1つの名前ぶんの結果（下書き）。"""
    words, phrases = count(name, raw)
    plain = plain_words(words)
    return {
        "name": name,
        "fetched": len(raw),
        "suggestions": sum(len(v or []) for v in raw.values()),
        "unique": len({s for v in raw.values() for s in (v or [])}),
        "words": [[w, round(n, 1), MARKS[mark(w)]] for w, n in words.most_common()],
        "phrases": [[p, round(n, 1), MARKS[mark(p)]] for p, n in phrases.most_common(20)],
        "titles": title_candidates(name, plain, avoid),
        "tags": tag_candidates(name, plain, book),
        "hashtags": hashtag_candidates(name, plain),
        "dropped": [list(x) for x in dropped(words)],
        "raw": raw,
    }


def report(data: dict) -> str:
    """標準出力と `--out` に出す文章（日本語）。"""
    name = data["name"]
    lines = [f"# 「{name}」のあとに続く語（YouTube の検索候補）", "",
             f"取った回数：{data['fetched']}（候補 {data['suggestions']} 件、"
             f"重なりを除いて {data['unique']} 件）", "",
             "## よく続く語（点の高い順。候補の上のほうほど重い）", "",
             "| 語 | 点 | 印 |", "|---|---:|---|"]
    for w, n, m in data["words"][:40]:
        lines.append(f"| {w} | {n} | {m} |")
    lines += ["", "## 続きの言い回し（上位20）", ""]
    lines += [f"- {p}（{n}）" + (f" 〔{m}〕" if m else "") for p, n, m in data["phrases"]]
    lines += ["", "## 題名の候補（下書き。頭は名前・答えは言い切らない・結び方はそろえない）", ""]
    lines += [f"- {t}" for t in data["titles"]] or ["- （作れませんでした。語が薄いです）"]
    lines += ["", "## タグの候補（15）", "",
              "、".join(data["tags"]),
              "",
              f"（合計 {tags_mod.text_length(data['tags'])} 字／上限 {tags_mod.MAX_TAGS_TEXT} 字）"]
    lines += ["", "## ハッシュタグの候補（3つ。概要欄に出すのはこれだけ）", "",
              " ".join("#" + t for t in data["hashtags"]),
              "",
              f"※ハッシュタグが{tags_mod.HASHTAG_LIMIT + 1}個以上あると YouTube は全部を無視する。"
              "空白を含む語はタグにだけ使う"]
    lines += ["", "## 外した語とその理由", ""]
    if data["dropped"]:
        seen: dict[str, list[str]] = {}
        for w, _n, m, why in data["dropped"]:
            seen.setdefault(f"{m}｜{why}", []).append(w)
        for key, ws in seen.items():
            m, why = key.split("｜", 1)
            lines.append(f"- **{m}**（{why}）：{'、'.join(ws[:12])}")
    else:
        lines.append("- 外した語はありません")
    lines += ["", "※どれも下書きです。決めるのは人。", ""]
    return "\n".join(lines)


def save(data: dict, out_dir: Path | None = None) -> Path:
    """控えを `research/keywords/<名前>.json` に残す。"""
    base = Path(out_dir) if out_dir else OUT_DIR
    base.mkdir(parents=True, exist_ok=True)
    safe = re.sub(r'[\\/:*?"<>|\s]', "_", data["name"])
    path = base / f"{safe}.json"
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    return path


# ───────────────────────────── 取材メモから名前を拾う ─────────────────────────────
def names_from_note(path: str | Path) -> list[str]:
    """取材メモ・台本から名前を拾う（`theme.topic`・`people:`・`crest_main`）。"""
    import yaml

    p = Path(path)
    try:
        data = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
    except (OSError, yaml.YAMLError):
        return []
    if not isinstance(data, dict):
        return []
    found: list[str] = []
    theme = data.get("theme") if isinstance(data.get("theme"), dict) else {}
    for value in [theme.get("topic")] + list(data.get("people") or []):
        name = str(value or "").strip()
        if name and name not in found:
            found.append(name)
    thumb = data.get("thumbnail") if isinstance(data.get("thumbnail"), dict) else {}
    for value in (thumb.get("crest_main") or []):
        name = str(value or "").strip()
        if name and name not in found:
            found.append(name)
    return found


def names_from_date(date: str, root: Path | None = None) -> list[str]:
    """その日の取材メモ全部から名前を拾う（`--date 20261008`）。"""
    base = Path(root) if root else NOTE_DIR
    found: list[str] = []
    for path in sorted(base.glob(f"{date}_*.yaml")):
        for name in names_from_note(path):
            if name not in found:
                found.append(name)
    return found


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="YouTube の検索候補から、名前のあとによく続く語を数える（題名・タグの下書き）")
    ap.add_argument("names", nargs="*", help="調べる名前（選手名・クラブ名）")
    ap.add_argument("--note", help="取材メモ・台本から名前を拾う（theme.topic・people・crest_main）")
    ap.add_argument("--date", help="その日の取材メモ全部から名前を拾う（例 20261008）")
    ap.add_argument("--out", help="文章を書き出す先（.md）")
    ap.add_argument("--all", action="store_true", help="頭の文字をあ〜んまで（48回。ふだんは10回）")
    ap.add_argument("--wait", type=float, default=WAIT, help=f"1回ごとに空ける秒数（既定 {WAIT}）")
    args = ap.parse_args(argv)

    names = list(args.names)
    if args.note:
        names += [n for n in names_from_note(args.note) if n not in names]
    if args.date:
        names += [n for n in names_from_date(args.date) if n not in names]
    if not names:
        ap.error("名前がありません（名前を直に渡すか、--note か --date を付けてください）")

    avoid = recent_tails()                 # 直近の本の結び方。これと重ならない題名を選ぶ
    texts: list[str] = []
    for i, name in enumerate(names):
        if i:
            time.sleep(args.wait)          # 名前のあいだも間を空ける
        raw = collect(name, full=args.all, wait=args.wait)
        if not any(raw.values()):
            print(f"「{name}」の候補が取れませんでした（通信か、名前の書き方を確かめてください）")
            continue
        data = build(name, raw, avoid)
        avoid += [variety_mod._tail_kind(t) for t in data["titles"]]
        text = report(data)
        print(text)
        texts.append(text)
        path = save(data)
        print(f"控え：{path}")
    if args.out and texts:
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text("\n".join(texts), encoding="utf-8")
        print(f"書き出し：{out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
