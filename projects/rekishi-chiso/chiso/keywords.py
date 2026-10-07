"""YouTube の検索候補から、名前のあとによく続く語を数える（10-07）。

    python -m chiso.cli keywords "織田信長"

検索候補（suggestqueries.google.com、ds=yt）を「名前」「名前＋空白」「名前＋あ・か・さ…の頭文字」で取り、
候補の中で名前のあとに続く語を数えて並べる。ゲーム（FGO・無双・BASARA…）と大河・ドラマの語は印を付けて分ける。
結果から題名の候補3つ・タグの候補15・概要欄に入れる語を出す（どれも下書き。決めるのは人）。

通信は curl を subprocess で呼ぶ（このPCの Python の通信は証明書で落ちることがある）。1回ごとに間を空ける。
取った候補は out/keywords_<名前>.json に控え、describe --keywords はそれを読む（無ければ取る）。
"""
from __future__ import annotations

import json
import re
import subprocess
import time
import urllib.parse
from collections import Counter
from pathlib import Path

URL = "https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&hl=ja&q={q}"
ROW_HEADS = "あかさたなはまやらわ"                      # 既定：各行の頭（10回）
ALL_KANA = ("あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほ"
            "まみむめもやゆよらりるれろわをん")               # --all：あ〜ん（46回）
WAIT = 1.0                                              # 1回ごとに空ける秒数

GAME = ("fgo", "fate", "無双", "basara", "バサラ", "パズドラ", "モンスト", "信長の野望", "太閤立志伝", "戦国大戦",
        "英傑大戦", "の野望", "三國志", "三国志大戦", "にゃんこ", "ウマ娘", "グラブル", "コトダマン", "ゲーム", "攻略", "ガチャ",
        "声優", "ポケモン", "ドラクエ", "スマブラ", "マイクラ", "マインクラフト", "モンハン", "艦これ", "刀剣乱舞",
        "千銃士", "アヴェンジャー", "バーサーカー", "セイバー", "アーチャー", "ランサー", "ライダー", "キャスター",
        "アサシン", "サーヴァント", "宝具", "ぐだぐだ", "コスプレ", "フィギュア", "アニメ", "mad", "mmd", "asmr",
        "ai", "実況", "替え歌", "エグスプロージョン", "ネタ", "コント", "芸人", "パロディ", "歌ってみた", "ボカロ",
        "ラップ", "rap", "song", "minecraft", "roblox", "nobunaga's ambition", "civilization", "シヴィライゼーション")
DRAMA = ("大河", "ドラマ", "映画", "キャスト", "俳優", "役者", "演じ", "主演", "麒麟がくる", "どうする家康",
         "豊臣兄弟", "真田丸", "軍師官兵衛", "おんな城主", "西郷どん", "青天を衝け", "鎌倉殿", "べらぼう", "いだてん",
         "花燃ゆ", "江〜", "篤姫", "龍馬伝", "利家とまつ", "風林火山", "天地人", "光る君へ", "nhk", "朝ドラ", "舞台",
         "ミュージカル", "宝塚", "レジェンド&バタフライ", "木村拓哉", "染谷将太", "長谷川博己", "仲野太賀",
         "小栗旬", "松本潤", "岡田准一", "吉沢亮", "鈴木亮平",
         # 歴史上の人物を演じた俳優（検索候補に名前だけで出てくる。見つけたら足す）
         "渡哲也", "渡辺謙", "反町隆史", "舘ひろし", "江口洋介", "海老蔵", "吉川晃司", "豊川悦司", "緒形直人",
         "高橋英樹", "役所広司", "玉木宏", "及川光博", "北大路欣也", "松方弘樹", "藤岡弘", "池松壮亮", "浜辺美波",
         "竹中直人", "中村雅俊", "西田敏行", "香川照之", "内野聖陽", "阿部寛", "中井貴一", "大泉洋", "堺雅人", "長澤まさみ")
# 一般の語・ほかのチャンネルの名前（題名・タグ・概要欄には使わない。表には印を付けて残す）
GENERIC = ("解説", "歴史", "最新", "再現", "かっこいい", "海外", "海外の反応", "まとめ", "簡単", "わかりやすく",
           "わかりやすい", "配信者", "子供向け", "小学生", "中学生", "授業", "年表", "動画", "面白い", "おもしろ", "雑学",
           "どんな人", "とは", "何した", "何をした人", "すごさ", "凄さ", "やばい", "読み方", "英語", "歌", "会見", "最後",
           "漫画", "まんが", "マンガ", "ゆっくり", "ゆっくり解説", "簡単に", "小説", "朗読", "睡眠", "睡眠用", "聞き流し",
           # ほかの YouTube チャンネルの名前（検索候補に出る）
           "かしまし", "中田敦彦", "あっちゃん", "コテンラジオ", "ゆる言語学")
MARKS = {"game": "ゲーム・娯楽", "drama": "大河・ドラマ", "generic": "一般の語", "": ""}


def fetch(query: str, curl: str = "curl") -> list[str]:
    """検索候補を1回取る。失敗したら空。"""
    url = URL.format(q=urllib.parse.quote(query))
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
    return [name, name + " "] + [f"{name} {k}" for k in (ALL_KANA if full else ROW_HEADS)]


def collect(name: str, full: bool = False, wait: float = WAIT, fetcher=fetch) -> dict[str, list[str]]:
    out = {}
    for i, q in enumerate(queries(name, full)):
        if i and wait:
            time.sleep(wait)
        out[q] = fetcher(q)
    return out


def mark(word: str) -> str:
    """ゲーム・娯楽なら game、大河・ドラマ（俳優を含む）なら drama、一般の語なら generic、どれでもなければ空。"""
    w = word.lower()
    tokens = set(w.split())

    def hit(k):
        if k.isascii() and len(k) <= 4:          # ai・mad などの短い英字は語として一致したときだけ（samurai の ai は数えない）
            return k in tokens
        return k in w
    if any(hit(g) for g in GAME):
        return "game"
    if any(hit(d) for d in DRAMA):
        return "drama"
    if w in GENERIC:
        return "generic"
    return ""


def tail(suggestion: str, name: str) -> str:
    """候補から名前を除いた残り（名前で始まらない候補は、名前の所を抜いた残り）。"""
    s = suggestion.strip()
    s = s[len(name):] if s.startswith(name) else s.replace(name, " ")
    return re.sub(r"\s+", " ", s).strip()


def count(name: str, raw: dict[str, list[str]]) -> tuple[Counter, Counter]:
    """(語の点, 続きの言い回しの点)。候補の上のほうほど重く（1位 2点 … 10位 1.1点）、何回も出る候補は出た回数ぶん足す。"""
    words, phrases = Counter(), Counter()
    for sugg in raw.values():
        for pos, s in enumerate(sugg):
            rest = tail(s, name)
            if not rest:
                continue
            pt = 1 + max(10 - pos, 1) / 10
            phrases[rest] += pt
            for w in dict.fromkeys(rest.split(" ")):
                if w.startswith("の") and len(w) >= 2 and not mark(w):     # 「秀長の妻」→ 妻（「信長の野望」はゲームの印のまま）
                    w = w[1:]
                if len(w) >= 2 or re.search(r"[一-鿿]", w):
                    words[w] += pt
    return words, phrases


def plain_words(words: Counter, generic: bool = False) -> list[str]:
    """ゲーム・大河の印が無い語を点の高い順に（generic=True で一般の語も残す）。"""
    return [w for w, _ in words.most_common() if not mark(w) or (generic and mark(w) == "generic")]


def suggest(name: str, words: Counter) -> dict:
    """題名の候補3つ・タグの候補15・概要欄に入れる語（下書き）。"""
    top = plain_words(words)
    w = ([x for x in top if len(x) >= 2] + ["生涯", "真相", "最期"])[:3]      # 題名には2字以上の語だけ
    tag_words = top
    titles = [
        f"{name}の生涯｜{w[0]}・{w[1]}・{w[2]}を掘る",
        f"{name}とは何者だったのか｜{w[0]}から{w[1]}まで",
        f"{name}　{w[0]}と{w[1]}、記録に残る本当の姿",
    ]
    tags = [name]
    for x in tag_words:
        tags.append(f"{name} {x}")
        if len(tags) >= 10:
            break
    for x in top:
        if x not in tags:
            tags.append(x)
        if len(tags) >= 15:
            break
    return {"titles": titles, "tags": tags[:15], "description_words": top[:12]}


def report(name: str, raw: dict[str, list[str]]) -> tuple[str, dict]:
    words, phrases = count(name, raw)
    sug = suggest(name, words)
    lines = [f"# 「{name}」の検索候補（YouTube）", "",
             f"取った回数：{len(raw)}（候補 {sum(len(v) for v in raw.values())} 件、重なりを除いて {len(set(s for v in raw.values() for s in v))} 件）", "",
             "## よく続く語（点の高い順。候補の上のほうほど重い）", "", "| 語 | 点 | 印 |", "|---|---:|---|"]
    for w, n in words.most_common(40):
        lines.append(f"| {w} | {n:.1f} | {MARKS[mark(w)]} |")
    lines += ["", "## 続きの言い回し（上位20）", ""]
    lines += [f"- {p}（{n:.1f}）" + (f" 〔{MARKS[mark(p)]}〕" if mark(p) else "") for p, n in phrases.most_common(20)]
    lines += ["", "## 題名の候補（下書き。名前を先頭に、毎回同じ形にしない）", ""] + [f"- {t}" for t in sug["titles"]]
    lines += ["", "## タグの候補（15）", "", "、".join(sug["tags"])]
    lines += ["", "## 概要欄に入れる語（ゲーム・大河を除く。describe --keywords は台本に出てくる語だけ使う）", "",
              "・".join(sug["description_words"])]
    data = {"name": name, "raw": raw, "words": [[w, round(n, 2)] for w, n in words.most_common()], "suggest": sug}
    return "\n".join(lines) + "\n", data


def cache_path(out: Path, name: str) -> Path:
    safe = re.sub(r'[\\/:*?"<>|\s]', "_", name)
    return out / f"keywords_{safe}.json"


def covered_words(words: list[str], script, limit: int = 10) -> list[str]:
    """概要欄の「この動画で扱うこと」に入れる語：ゲーム・大河の印が無く、台本（せりふ・節の題・札）に出てくるものだけ。
    扱っていない語を並べると、YouTube の誤解を招くメタデータの決まりに当たるため。"""
    from .voice import display_text
    text = " ".join([display_text(l.text) for l in script.lines] + [s.title for s in script.sections]
                    + [f"{l.card.head} {l.card.body}" for l in script.lines if l.card is not None])
    out = []
    for w in words:
        if len(w) >= 2 and not mark(w) and w in text and w not in out:
            out.append(w)
        if len(out) >= limit:
            break
    return out


def description_line(words: list[str]) -> str:
    return "この動画で扱うこと：" + "・".join(words) if words else ""
