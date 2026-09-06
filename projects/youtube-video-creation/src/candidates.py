"""候補テーマの採点と、枠への割り振り。

1日ぶんのテーマを、毎回同じものさしで選ぶための仕組み。
枠の数と並びは config の cadence.slots で決まる。
スキャンで拾った候補を点数化し、朝・昼・夜のどれに回すかを決める。

点数はあくまで並べ替えの目安で、最後に選ぶのは人。
なぜその順になったかを内訳で示すので、違うと思ったら手で入れ替えればよい。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import yaml

from .config import _resolve


class CandidateError(Exception):
    pass


@dataclass
class Candidate:
    id: str
    title: str
    en: str = ""        # 英語サイトを検索するときの語。無ければ英語の検索は出さない
    url: str = ""       # 元になった記事・投稿。hours_ago を省くとここから割り出す
    topic: str = ""     # 話題のまとまり（クラブ名・移籍案件など）。枠の重複を避けるのに使う
    league: str = ""    # england / spain / germany / italy / france / netherlands / japan
                        # 現地語の検索を出すかどうかの判断に使う
    kind: str = "transfer"   # transfer / match / other。枠に散らすのと検索の出し分けに使う
    hours_ago: float = 99.0
    tier: str = "未確認"
    reaction: bool = False
    goals: bool = False     # 試合結果むけ。点が多く動いた
    upset: bool = False     # 試合結果むけ。番狂わせ
    big_club: bool = False
    numbers: bool = False
    topic_rank: int = 0     # まとめ集約サイトの掲載順（クリック数順）。0 は載っていない
    note: str = ""
    sources: list[str] = field(default_factory=list)

    # 採点の結果
    score: int = 0
    breakdown: dict[str, int] = field(default_factory=dict)


def load_candidates(path: str | Path) -> tuple[str, list[Candidate]]:
    target = Path(path)
    if not target.exists():
        raise CandidateError(f"候補ファイルがありません: {target}")
    raw = yaml.safe_load(target.read_text(encoding="utf-8")) or {}

    items: list[Candidate] = []
    for index, entry in enumerate(raw.get("candidates") or [], start=1):
        entry = dict(entry or {})
        title = str(entry.get("title", "")).strip()
        if not title:
            raise CandidateError(f"{index}件目: title が空です")
        items.append(
            Candidate(
                id=str(entry.get("id") or f"c{index}"),
                title=title,
                en=str(entry.get("en", "")).strip(),
                url=str(entry.get("url", "")).strip(),
                topic=str(entry.get("topic", "")).strip(),
                league=str(entry.get("league", "")).strip().lower(),
                kind=str(entry.get("kind", "transfer")).strip().lower() or "transfer",
                hours_ago=float(entry["hours_ago"]) if "hours_ago" in entry else -1.0,
                tier=str(entry.get("tier", "未確認")).strip(),
                reaction=bool(entry.get("reaction", False)),
                goals=bool(entry.get("goals", False)),
                upset=bool(entry.get("upset", False)),
                big_club=bool(entry.get("big_club", False)),
                numbers=bool(entry.get("numbers", False)),
                topic_rank=int(entry.get("topic_rank", 0) or 0),
                note=str(entry.get("note", "")).strip(),
                sources=[str(u).strip() for u in (entry.get("sources") or []) if str(u).strip()],
            )
        )
    if not items:
        raise CandidateError("candidates が空です")
    return str(raw.get("date", "")).strip(), items


def fill_ages(items: list[Candidate], age_of) -> list[str]:
    """hours_ago を書かなかった候補を、url から割り出して埋める。

    割り出せなければ 99（＝古い扱い）にする。新しさで点が付くので、
    分からないものを新しい側に倒すと、確認していない候補が上に来てしまう。
    """
    notes: list[str] = []
    for item in items:
        if item.hours_ago >= 0:
            continue
        age = age_of(item.url) if item.url else None
        if age is None:
            item.hours_ago = 99.0
            reason = "urlが無い" if not item.url else "urlから日付を割り出せない"
            notes.append(f"{item.title}: hours_ago が空で、{reason}ため古い扱いにしました")
        else:
            item.hours_ago = round(age, 1)
    return notes


def outlet_count(sources: list[str]) -> int:
    """その話を書いている媒体の数。同じ媒体の複数記事は1社と数える。

    「2社以上で一致」は確度の条件でもあるが、ここでは別の使い方をする。
    何社が同時に書いているかは、世の中がいま何に注目しているかの代わりになる。
    数えるのはホスト名で、www の有無は揃える。
    """
    hosts = set()
    for url in sources or []:
        host = str(url).split("://", 1)[-1].split("/", 1)[0].lower().strip()
        # www / m / amp は同じ媒体の配信面の違い。別の社として数えると
        # 「2社が一致」が実は1社、という水増しになる（m.gianlucadimarzio.com で実測）
        for prefix in ("www.", "m.", "amp."):
            host = host.removeprefix(prefix)
        if host:
            hosts.add(host)
    return len(hosts)


def is_japanese(item: "Candidate", words: list[str]) -> bool:
    """日本人選手が絡む話か。設定に並べた語で見る。

    国籍そのものは記事から機械では分からない。名前で拾える範囲だけを見て、
    拾えなかったものを「日本人ではない」と断定はしない（枠に入れないだけ）。
    """
    haystack = f"{item.title} {item.en} {item.note} {item.topic}"
    return any(str(w).strip() and str(w).strip() in haystack for w in (words or []))


def score(items: list[Candidate], scoring: dict) -> list[Candidate]:
    """候補に点をつける。内訳も残す。"""
    from . import clubs as club_book

    weights = dict(scoring.get("weights") or {})
    # 「6時間以内なら3点」のような段階。近いものから順に見る
    stages = sorted(
        ((float(k), int(v)) for k, v in (scoring.get("freshness_hours") or {}).items())
    )
    top = max((points for _, points in stages), default=1)
    fresh_weight = int(weights.get("freshness", 0))

    # 「3社以上なら2点」のような段階。多いほうから見て、最初に届いたもの
    outlet_stages = sorted(
        ((int(k), int(v)) for k, v in (scoring.get("outlets_count") or {}).items()),
        reverse=True,
    )
    outlet_top = max((points for _, points in outlet_stages), default=1)
    outlet_weight = int(weights.get("outlets", 0))

    clubs = [str(c).strip() for c in (scoring.get("big_clubs") or []) if str(c).strip()]
    japanese_weight = int(weights.get("japanese", 0))
    # 「10位以内なら3点」のような段階。上位から順に見る
    rank_stages = sorted(
        ((int(k), int(v)) for k, v in (scoring.get("topic_ranks") or {}).items())
    )
    rank_top = max((p for _, p in rank_stages), default=1)
    rank_weight = int(weights.get("topic_rank", 0))
    japanese_words = list(scoring.get("japanese") or [])

    for item in items:
        breakdown: dict[str, int] = {}

        # ビッグクラブは名前で拾えるので、手で立てなくても効くようにする。
        # 見出しは英語で来ることが多いので、別名辞書でも当てる
        # （scoring.big_clubs は日本語表記しか並んでいない）
        if not item.big_club:
            haystack = f"{item.title} {item.en} {item.note}"
            item.big_club = any(club in haystack for club in clubs) or club_book.is_big(haystack)

        stage = next((points for hours, points in stages if item.hours_ago <= hours), 0)
        if stage:
            # 段階の点を、この項目の重み（満点）に合わせて割り当てる
            breakdown["新しさ"] = round(stage / top * fresh_weight)

        # 何社が同じ話を書いているか。5社が1時間で一斉に書いた話と、1社しか
        # 書いていない話を同点にしないための手がかり。
        # reaction などは人が手で立てる欄で、gather は false のまま書き出すので、
        # 自動で効く材料はここと新しさ・ビッグクラブしかない
        outlets = outlet_count(item.sources)
        points = max((p for n, p in outlet_stages if outlets >= n), default=0)
        if points:
            breakdown["媒体数"] = round(points / outlet_top * outlet_weight)

        for key, label in (
            ("reaction", "反応"),
            ("goals", "得点"),
            ("upset", "番狂わせ"),
            ("big_club", "ビッグクラブ"),
            ("numbers", "数字"),
        ):
            if getattr(item, key):
                breakdown[label] = int(weights.get(key, 0))

        # まとめ集約サイトの掲載順。**もう一つの採点の軸。**
        # 新しさと媒体数は「速報として大きいか」を測るが、こちらは
        # 「いま実際に読まれているか」を測る。まとめ由来の候補は媒体数1・
        # 時刻不明で点が伸びず、幅を広げても枠が埋まらなかった（2026-09-05 実測）。
        if item.topic_rank:
            points = next(
                (p for limit, p in rank_stages if item.topic_rank <= limit), 0
            )
            if points:
                breakdown["話題順"] = round(points / rank_top * rank_weight)

        # 日本人選手に点は付けない。**枠で担保して、点では寄せない。**
        # 一度 japanese: 3 を入れたところ、朝の3枠が全部日本人選手になった
        # （2026-09-05 実測）。日本人は「1日に2枠」という割り当ての制約で、
        # 全体の傾向を寄せるものではない。weights に japanese を書けば効くが、
        # 既定では 0。
        if japanese_weight and is_japanese(item, japanese_words):
            breakdown["日本人"] = japanese_weight

        item.breakdown = {k: v for k, v in breakdown.items() if v}
        item.score = sum(item.breakdown.values())
    return sorted(items, key=lambda c: (-c.score, c.hours_ago))


# 実況ブログ・速報ティッカーの見出し。**1試合を多数の媒体が同時中継するので
# 「媒体数」が伸び、注目度の代わりとして数えている点が高く出る。**
# ところが中身は「47分に1点」だけで、2分の動画にする題材が無い。
# 実測（2026-09-06）で、8点の「Nottingham Forest vs Tottenham LIVE!」が
# 8点のPSG敗戦記事を押しのけて枠に入った。
LIVE_MARKS = (
    "live!", "live:", "liveblog", "live blog", "live updates", "live-ticker",
    "liveticker", "en directo", "en vivo", "in diretta", "ao vivo", "en direct",
    "as it happened", "minute-by-minute", "match centre",
    "実況", "速報まとめ", "試合記録", "ライブ",
)


# スタメン発表の見出し。**試合前の情報なので、公開する頃には古い。**
# 中身も選手名の並びだけで、2分の動画にする題材が無い（実況ブログと同じ理由）。
# 2026-09-07 のユーザー判断で対象外にした。実測では 434件中11件が該当し、
# すべて本物のスタメン発表だった（誤爆なし）。
LINEUP_MARKS = (
    "スタメン", "先発メンバー",
    "starting xi", "starting line", "line-ups", "lineups", "predicted xi", "confirmed xi",
    "alineaciones", "alineación", "once inicial", "onces",
    "aufstellung", "formazioni", "les compositions", "compositions probables",
    "opstelling", "onze do", "onze inicial",
)


# 種別を散らすために、これ以上の点差を捨てない。kind は見出しからの推測なので、
# 札を信じて良い記事を落とすほうが損になる
KIND_TOLERANCE = 2


def _best(pool: list["Candidate"]) -> int:
    return max((c.score for c in pool), default=0)


def is_live_feed(item: "Candidate") -> bool:
    """実況・ティッカーの見出しか。題材にならないので枠から外す。

    **正規表現を使わない。**単語境界を書こうとして、ファイルに書き出す途中で
    記号が制御文字に化け、条件が黙って効かなくなった（2026-09-06 実測）。
    見た目は正しく、テストを書くまで気づけなかった。素の文字列比較で足りる。
    """
    low = item.title.lower()
    if any(m in low for m in LIVE_MARKS):
        return True
    # 「Tor zum 1:0 durch X in der 47. Minute」のような得点速報
    if "tor zum " in low:
        return True
    # 「1:0 …… 47. Minute」。点差と分がそろっていれば試合中の速報
    return ":" in low and "minute" in low and any(ch.isdigit() for ch in low)


def is_lineup(item: "Candidate") -> bool:
    """スタメン発表の見出しか。実況と同じく題材にならないので枠から外す。

    実況ブログと分けてあるのは、外す理由が違うため。実況は「中身が無い」、
    こちらは中身が無いことに加えて**公開する頃には試合が終わっている**。
    """
    low = item.title.lower()
    return any(mark in low for mark in LINEUP_MARKS)


def assign(
    items: list[Candidate], scoring: dict, slots: list[str]
) -> tuple[dict[str, Candidate], dict[str, list[str]]]:
    """枠ごとに1本ずつ割り当てる。同じ候補は2つの枠に入れない。

    条件に合う候補が無ければ全体から選ぶ（枠を空けるより出したほうがよい）。
    そのときは満たせなかった条件を並べて返す。黙って別のものを入れると、
    枠の狙いから外れていることに気づけない。条件は複数外れることがあるので、
    1件で上書きせず全部残す。
    """
    rules = dict(scoring.get("slots") or {})
    spread = bool(scoring.get("spread_topics", True))
    # 候補が全部同じ種類の日は、散らしようがない。条件そのものを持ち出さない
    spread_kinds = bool(scoring.get("spread_kinds", True)) and len({c.kind for c in items}) > 1
    # 実況ブログは題材にならない。**どの枠にも入れない**
    fallbacks: dict[str, list[str]] = {}
    remaining = [c for c in items if not is_live_feed(c)]
    dropped = len(items) - len(remaining)
    if dropped:
        fallbacks.setdefault("_", []).append(f"実況・速報の見出しを{dropped}件外しました")
    # スタメン発表も題材にならない。**どの枠にも入れない**
    before = len(remaining)
    remaining = [c for c in remaining if not is_lineup(c)]
    if before - len(remaining):
        fallbacks.setdefault("_", []).append(
            f"スタメン発表の見出しを{before - len(remaining)}件外しました"
        )
    chosen: dict[str, Candidate] = {}
    used_topics: set[str] = set()
    used_kinds: list[str] = []

    for slot in slots:
        rule = dict(rules.get(slot) or {})
        pool = remaining

        # 大きい話が1つあると3本ともそれになる。すでに使った話題は外す
        if spread and used_topics:
            fresh_topics = [c for c in pool if not c.topic or c.topic not in used_topics]
            if not fresh_topics and pool:
                fallbacks.setdefault(slot, []).append("他の枠と別の話題が残っていません")
            pool = fresh_topics or pool

        # 3本とも試合結果、3本とも移籍だと単調になる。使いすぎた種別は外す。
        # **上限は枠数に比例させる。**「2枠まで」で固定していたため、枠を9本に
        # 増やしたとき候補が413件から5件まで削られ、後半の枠が埋まらなくなった
        # （2026-09-04 実測）。種別は3つしかないので、枠数の3分の1が目安。
        if spread_kinds and pool:
            cap = max(2, -(-len(slots) // 3))
            over = {k for k in set(used_kinds) if used_kinds.count(k) >= cap}
            if over:
                varied = [c for c in pool if c.kind not in over]
                if not varied:
                    fallbacks.setdefault(slot, []).append("他の枠と別の種類が残っていません")
                # **点が大きく劣るなら散らさない。**kind は見出しからの当てずっぽうで、
                # 移籍でない記事にも transfer が付く。誤った札のために、
                # 8点の記事を外して5点の記事を入れていた（2026-09-06 実測）。
                # 見た目の変化より、話の大きさを優先する
                elif _best(varied) + KIND_TOLERANCE < _best(pool):
                    fallbacks.setdefault(slot, []).append(
                        f"種別を散らすと{_best(pool)}点→{_best(varied)}点まで落ちるので、"
                        "散らしません"
                    )
                    varied = pool
                pool = varied or pool

        # 日本人選手の枠。名前で拾えたものだけを入れる
        if rule.get("require_japanese") and pool:
            words = list(scoring.get("japanese") or [])
            japanese = [c for c in pool if is_japanese(c, words)]
            if not japanese:
                fallbacks.setdefault(slot, []).append(
                    "日本人選手が絡む候補がありません（scoring.japanese に名前を足すか、枠を空けます）"
                )
                continue    # 別の話で埋めない。空けたほうが枠の意味が保てる
            pool = japanese

        # 日本人以外の枠。日本人枠と対にして使う（例: 9本中3本を日本人、2本をそれ以外）
        if rule.get("exclude_japanese") and pool:
            words = list(scoring.get("japanese") or [])
            others = [c for c in pool if not is_japanese(c, words)]
            if not others:
                fallbacks.setdefault(slot, []).append(
                    "日本人以外の候補がありません。枠を空けます"
                )
                continue
            pool = others

        # リーグを指定する枠。**別のリーグで埋めない。**
        # 「プレミアの枠」にラ・リーガを入れたら、枠を分けた意味が無くなる
        want = rule.get("require_league")
        if want and pool:
            names = [str(w).strip().lower() for w in (want if isinstance(want, list) else [want])]
            same = [c for c in pool if c.league in names]
            if not same:
                fallbacks.setdefault(slot, []).append(
                    f"{' か '.join(names)} の候補がありません。枠を空けます"
                )
                continue
            pool = same

        # 語で絞る枠。記者名（ロマーノ）や大会名など、群では表せない指定に使う。
        # 見出しだけでなく注記・出典も見る（「ロマーノ氏によると」は本文側に出る）
        needles = rule.get("require_words")
        if needles and pool:
            words = [str(w).strip().lower() for w in needles if str(w).strip()]
            hit = [c for c in pool if _mentions(c, words)]
            if not hit:
                fallbacks.setdefault(slot, []).append(
                    f"{' / '.join(words)} に触れた候補がありません。枠を空けます"
                )
                continue
            pool = hit

        tiers = rule.get("require_tier")
        if tiers:
            filtered = [c for c in pool if c.tier in tiers]
            if not filtered and pool:
                fallbacks.setdefault(slot, []).append(
                    f"確度が{' か '.join(tiers)}の候補がありません"
                )
            pool = filtered or pool

        pick = _prefer(pool, str(rule.get("prefer", "total")), slot, fallbacks)
        if pick is None:
            continue

        # 本数を増やすと、埋めるために弱い候補が入る。実測（2026-09-04）で
        # 枠を5→9に増やしたとたん、2点のブログ雑感が枠に入った。
        # **点の低いものを出すくらいなら空ける。**枠は埋めるためのものではない。
        floor = int(rule.get("min_score", scoring.get("min_score", 0)) or 0)
        if floor and pick.score < floor:
            fallbacks.setdefault(slot, []).append(
                f"いちばん高い候補でも{pick.score}点で、下限{floor}点に届きません。"
                "無理に埋めず空けます"
            )
            continue
        chosen[slot] = pick
        remaining = [c for c in remaining if c.id != pick.id]
        if pick.topic:
            used_topics.add(pick.topic)
        used_kinds.append(pick.kind)
    return chosen, fallbacks


def _mentions(item: Candidate, words: list[str]) -> bool:
    """見出し・英語の語・注記・出典のどれかに、指定の語が入っているか。"""
    hay = " ".join([item.title, item.en, item.note, *item.sources]).lower()
    return any(w in hay for w in words)


def _prefer(
    pool: list[Candidate], prefer: str, slot: str, fallbacks: dict[str, list[str]]
) -> Candidate | None:
    """枠の方針に沿って1つ選ぶ。条件に合うものが無ければ全体から最高点。"""
    if not pool:
        return None
    if prefer == "topic":
        # **集約サイトの掲載順だけで選ぶ。**こちらの採点を通さない枠。
        # 載っていないものは選ばない（比べる軸が無いので）
        listed = [c for c in pool if c.topic_rank]
        if not listed:
            fallbacks.setdefault(slot, []).append(
                "まとめ集約サイトに載っている候補がありません（gather --topics で取ります）"
            )
            return None
        return min(listed, key=lambda c: (c.topic_rank, -c.score))

    if prefer == "freshness":
        # 時刻の順に並べるだけだと、30分新しいだけの小さい話が、その日の
        # いちばん大きい話を押しのける。同じくらい新しいものは点数で選ぶ
        newest = min(c.hours_ago for c in pool)
        band = [c for c in pool if c.hours_ago <= newest + FRESH_BAND_HOURS]
        return max(band, key=lambda c: (c.score, -c.hours_ago))

    flags = {"reaction": "賛否が割れる", "big_club": "ビッグクラブが絡む"}
    if prefer in flags:
        matching = [c for c in pool if getattr(c, prefer)]
        if not matching:
            fallbacks.setdefault(slot, []).append(f"{flags[prefer]}候補がありません")
        return max(matching or pool, key=lambda c: c.score)

    return max(pool, key=lambda c: c.score)


# domains にこれを書くと、その候補のリーグの公式サイトに絞る。
# 試合レポートは premierleague.com と bundesliga.com で別物なので、
# 公式をひとまとめにすると関係ないリーグまで引いてしまう
# 「同じくらい新しい」とみなす幅。この中なら、新しさではなく点数で選ぶ
FRESH_BAND_HOURS = 6.0

LEAGUE_OFFICIAL = "league_official"

# こちらはそのリーグの現地語メディア。ドイツの試合なら kicker / sport1 に絞る
LEAGUE_MEDIA = "league_media"


def deep_queries(
    item: Candidate,
    templates: list[dict],
    domains: dict[str, list[str]],
    league_official: list[str] | None = None,
    league_media: list[str] | None = None,
    match_q: str = "",
) -> list[dict]:
    """選んだテーマの深掘り検索を組み立てる。

    海外サイトを日本語で検索しても何も出ないので、{en} を使う雛形は
    候補に英語の語が入っているときだけ出す。
    when: を書いた雛形は、そのリーグの候補のときだけ出す。
    """
    queries = []
    for template in templates:
        text = str(template.get("q", ""))
        if "{en}" in text and not item.en:
            continue
        if "{match_q}" in text and not match_q:
            continue

        # 条件が合うときだけ出す。when はリーグ名（germany）か種別（match）。
        # 並べて書くと「どちらも満たすとき」になる（when: [germany, match]）。
        # ドイツ語の検索をスペインの話に出しても、移籍の話にxGを引いても無駄になる
        if not _wanted(item, template.get("when")):
            continue

        group = str(template.get("domains") or "")
        if group in (LEAGUE_OFFICIAL, LEAGUE_MEDIA):
            hosts = list((league_official if group == LEAGUE_OFFICIAL else league_media) or [])
            if not hosts:
                continue  # そのリーグの引き先が登録されていない
        else:
            hosts = domains.get(group, []) if group else []

        queries.append(
            {
                "q": (
                    text.replace("{theme}", item.title)
                    .replace("{en}", item.en)
                    .replace("{match_q}", match_q)
                    .strip()
                ),
                "label": str(template.get("label", "")),
                "domains": hosts,
            }
        )
    return queries


def _wanted(item: Candidate, when) -> bool:
    """when の条件をすべて満たすか。when は文字列でも並びでもよい。"""
    if not when:
        return True
    wanted = [when] if isinstance(when, str) else list(when)
    return all(
        str(value).strip().lower() in (item.league, item.kind)
        for value in wanted
        if str(value).strip()
    )


def exclude_covered(items: list[Candidate], covered: dict[str, object]) -> tuple[list, list]:
    """直近で扱った話題を候補から外す。(残り, 外したもの) を返す。"""
    keep = [c for c in items if c.id not in covered]
    dropped = [c for c in items if c.id in covered]
    return keep, dropped


def worksheet(date_label: str) -> str:
    """候補ファイルの雛形。スキャンで拾ったものをここに並べる。"""
    return f'''# 候補テーマ（{date_label}）
# スキャンで拾ったものを並べる。深掘りはまだしない。
# 埋めたら python -m src.cli pick このファイル
date: "{date_label}"
candidates:
  - id: ""            # 短い識別子。重複判定にも使う
    title: ""         # 一言で。あとで動画タイトルの素になる
    en: ""            # 英語サイトを引くときの語（例: Julian Alvarez Atletico）
    url: ""           # 元の記事・投稿のURL
    topic: ""         # 話題のまとまり（例: alvarez）。同じ topic は1日1枠まで
    league: ""        # england/spain/germany/italy/france/netherlands/japan
                      # 書くと現地語の検索も出る
    kind: transfer    # transfer / match / other。match と書くと試合むけの検索が出る
    hours_ago:        # 何時間前か。空にすると url から割り出す
    tier: 報道         # 確定 / 報道 / 未確認
    reaction: false   # 賛否が割れる・驚きがあるか
    big_club: false   # ビッグクラブが絡むか
    numbers: false    # 金額・記録など数字が立つか
    goals: false      # 試合結果むけ。点が多く動いたか
    upset: false      # 試合結果むけ。番狂わせか
    note: ""          # ひとことメモ
    sources:
      - ""
'''
