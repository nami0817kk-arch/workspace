"""取材メモ（YAML）を検証して、台本の下書きに変換する。

1本＝1テーマの深掘りを前提にしている。取材メモは
「テーマ」「動画が答える問い」「節（何が起きたか／なぜ／争点／これから）」で構成する。

検証でやること:
  - 確度の条件（config/sources.yaml の tiers）を満たしているか
  - 深掘りと呼べる節数があるか、問いが立っているか
  - 直近で扱った話題と重なっていないか
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

import yaml

from . import coverage, xposts
from .plan import Plan

# 節の中身に合う背景を選ぶ。順番に配るだけだと、緑の芝ばかりが続く
# （実測: 17カット中13カットが緑系だった）。節の性格で下地を変える。
BACKGROUND_BY_SECTION = {
    "what": "assets/backgrounds/stadium.png",       # 何が起きたか
    "score": "assets/backgrounds/pitch.png",        # 試合そのもの
    "turning": "assets/backgrounds/pitch.png",      # 試合が決まった場面
    "numbers": "assets/backgrounds/studio.png",     # 数字・表は模様の無い下地に
    "point": "assets/backgrounds/studio.png",       # 争点
    "background": "assets/backgrounds/night.png",   # 経緯・背景は芝を出さない
    "collapsed": "assets/backgrounds/night.png",    # 壊れた話
    "voices": "assets/backgrounds/night.png",       # 世の中の声
    "next": "assets/backgrounds/tactics.png",       # これからどうなる
}
# 上に無い節に配る並び。緑が続かないよう交互にする
BACKGROUNDS = (
    "assets/backgrounds/stadium.png",
    "assets/backgrounds/night.png",
    "assets/backgrounds/tactics.png",
    "assets/backgrounds/studio.png",
    "assets/backgrounds/pitch.png",
)
SPEAKERS = ("キャスター", "解説")


class ResearchError(Exception):
    pass


@dataclass
class Section:
    """深掘りの1節。動画の1章になる。"""

    id: str
    heading: str
    tier: str
    telop: str
    say: list[str]
    sources: list[str] = field(default_factory=list)
    official: bool = False
    card: dict | None = None
    bg: str = ""      # この節の背景。空なら既定の並びから割り当てる


# タイトルの頭に付ける札。まとめ系で定番の使い分け
PREFIXES = {
    "速報": "いま入った確定・報道",
    "朗報": "良いニュース",
    "悲報": "悪いニュース",
    "": "",
}


@dataclass
class Notes:
    date: str
    title: str
    question: str                    # この動画が答える問い
    slot: str = ""
    theme_id: str = ""
    prefix: str = ""                 # 【速報】【朗報】【悲報】
    hook: str = ""                   # 冒頭のつかみ
    answer: str = ""                 # まとめで返す答え
    watch: str = ""                  # 次に何を見るか
    follow_up: bool = False
    league: str = ""                 # england / spain / ... 何を追えていないかの集計に使う
    kind: str = "transfer"           # transfer / match / other
    topic: str = ""                  # 話題のまとまり。続報かどうかを見るのに使う
    thumbnail: dict = field(default_factory=dict)
    sections: list[Section] = field(default_factory=list)

    @property
    def video_title(self) -> str:
        return f"【{self.prefix}】{self.title}" if self.prefix else self.title

    @property
    def tiers_used(self) -> set[str]:
        return {section.tier for section in self.sections}

    @property
    def sources(self) -> list[str]:
        seen: list[str] = []
        for section in self.sections:
            for url in section.sources:
                if url not in seen:
                    seen.append(url)
        return seen


def load_notes(path: str | Path) -> Notes:
    path = Path(path)
    if not path.exists():
        raise ResearchError(f"取材メモがありません: {path}")
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return build_notes(raw)


def build_notes(raw: dict) -> Notes:
    theme = dict(raw.get("theme") or {})
    if not theme:
        raise ResearchError(
            "theme がありません。1本＝1テーマなので、扱うテーマを1つ決めてください"
        )

    sections: list[Section] = []
    for index, entry in enumerate(raw.get("sections") or [], start=1):
        entry = dict(entry or {})
        say = entry.get("say")
        lines = [say] if isinstance(say, str) else list(say or [])
        sections.append(
            Section(
                id=str(entry.get("id") or f"s{index}"),
                heading=str(entry.get("heading", "")).strip(),
                tier=str(entry.get("tier", "")).strip(),
                telop=str(entry.get("telop", "")).strip(),
                say=[str(s).strip() for s in lines if str(s).strip()],
                sources=[str(u).strip() for u in (entry.get("sources") or []) if str(u).strip()],
                official=bool(entry.get("official", False)),
                card=entry.get("card"),
                bg=str(entry.get("bg", "")).strip(),
            )
        )
    if not sections:
        raise ResearchError("sections が空です。節を立てて掘ってください")

    return Notes(
        date=str(raw.get("date", "")).strip(),
        slot=str(raw.get("slot", "")).strip(),
        title=str(theme.get("title", "")).strip(),
        theme_id=str(theme.get("id", "")).strip(),
        question=str(theme.get("question", "")).strip(),
        prefix=str(theme.get("prefix", "")).strip().strip("【】"),
        hook=str(theme.get("hook", "")).strip(),
        thumbnail=dict(raw.get("thumbnail") or {}),
        answer=str(raw.get("answer", "")).strip(),
        watch=str(raw.get("watch", "")).strip(),
        follow_up=bool(raw.get("follow_up", False)),
        league=str(theme.get("league", "")).strip().lower(),
        kind=str(theme.get("kind", "transfer")).strip().lower() or "transfer",
        topic=str(theme.get("topic", "")).strip(),
        sections=sections,
    )


def verify(notes: Notes, plan: Plan) -> list[str]:
    """確度と構成の条件を満たしているか調べ、問題を文章で返す。空なら合格。"""
    policy = getattr(plan, "policy", {}) or {}
    problems: list[str] = []

    if not notes.title:
        problems.append("theme.title が空です")
    if not notes.date:
        problems.append("date が空です")
    if policy.get("require_question", True) and not notes.question:
        problems.append(
            "theme.question が空です。この動画が答える問いを1つ立ててください"
            "（例: なぜ金の問題ではないのか）"
        )
    if not notes.answer:
        problems.append("answer が空です。まとめで問いにどう答えるかを書いてください")

    minimum = int(policy.get("min_sections", 3))
    if len(notes.sections) < minimum:
        problems.append(
            f"節が{len(notes.sections)}つしかありません。深掘りには{minimum}つ以上必要です"
            "（何が起きたか／なぜ／争点／これから）"
        )

    for section in notes.sections:
        label = section.id
        if section.tier not in plan.tiers:
            known = " / ".join(plan.tiers)
            problems.append(f"{label}: 確度『{section.tier}』が未定義です（{known}）")
            continue
        rule = plan.tiers[section.tier]

        if not section.heading:
            problems.append(f"{label}: heading が空です")
        if not section.telop:
            problems.append(f"{label}: telop が空です")
        if not section.say:
            problems.append(f"{label}: say が空です")

        needed = int(rule.get("needs_sources", 1))
        if len(section.sources) < needed:
            problems.append(
                f"{label}: 確度『{section.tier}』には出典が{needed}本必要です"
                f"（いまは{len(section.sources)}本）"
            )
        problems += _check_reactions(section)

        if rule.get("needs_official") and not section.official:
            problems.append(
                f"{label}: 確度『{section.tier}』はクラブ・当事者の発表が条件です。"
                "発表を確認できないなら tier を下げてください"
            )
    return problems


def _check_reactions(section: Section) -> list[str]:
    """反応カードは、実在する投稿・記事に基づいているかを見る。

    もっともらしいファンの声は、思いつきでいくらでも書ける。だからここは
    警告ではなく、通さない扱いにしている。出典が無ければ台本にしない。
    """
    card = section.card or {}
    if str(card.get("type", "")).lower() != "reactions":
        return []

    problems: list[str] = []
    if not section.sources:
        problems.append(
            f"{section.id}: 反応カードに出典がありません。"
            "実在する投稿・記事のURLを sources に入れてください"
        )

    for item in card.get("items") or []:
        entry = item if isinstance(item, dict) else {"text": str(item)}
        label = str(entry.get("label", "")).strip()
        if label.startswith("@"):
            problems.append(
                f"{section.id}: 反応のラベルにアカウント名（{label}）が入っています。"
                "個人が特定できる形では出しません。「X」「海外のファン」などにしてください"
            )
    return problems


def advise(notes: Notes, plan: Plan | None = None, now=None) -> list[str]:
    """止めるほどではないが直したほうがよい点。draft のときに出す。"""
    notes_warnings: list[str] = []

    if notes.prefix and notes.prefix not in PREFIXES:
        known = " / ".join(k for k in PREFIXES if k)
        notes_warnings.append(f"prefix『{notes.prefix}』は定番ではありません（{known}）")

    # 【速報】は確定か報道にだけ。噂だけの回に付けると釣りになる
    if notes.prefix == "速報" and not (notes.tiers_used & {"確定", "報道"}):
        notes_warnings.append(
            "【速報】が付いていますが、確定・報道の節がありません。"
            "未確認だけの回に速報と書くと、内容と釣り合いません"
        )

    if not notes.thumbnail.get("line1"):
        notes_warnings.append(
            "thumbnail.line1 が空です。サムネの主見出しを書いてください"
        )
    if len(str(notes.thumbnail.get("line1", ""))) > 14:
        notes_warnings.append("thumbnail.line1 が長めです。14文字くらいまでが読みやすい")
    if len(str(notes.thumbnail.get("line2", ""))) > 18:
        notes_warnings.append("thumbnail.line2 が長めです。18文字くらいまでが読みやすい")

    notes_warnings += _advise_posts(notes, plan, now)
    notes_warnings += _advise_sources(notes, plan)
    notes_warnings += _advise_voices(notes)
    notes_warnings += _advise_spread(notes, plan)
    return notes_warnings


# 1つの媒体にこの割合を超えて頼ると、実質1社の報道になる
SINGLE_SITE_SHARE = 0.6


def _advise_spread(notes: Notes, plan: Plan | None) -> list[str]:
    """出典の使い回しと、1媒体への偏りを見る。

    同じ記事を複数の節で使い回すと、出典欄には何本も並ぶのに、実際に
    確かめた記事は1本しかない。数だけ見ると裏が取れているように見える。
    """
    hints: list[str] = []

    seen: dict[str, list[str]] = {}
    for section in notes.sections:
        for url in section.sources:
            seen.setdefault(url, []).append(section.heading)

    for url, headings in seen.items():
        if len(headings) >= 3:
            hints.append(
                f"同じ記事を{len(headings)}つの節で使っています（{' / '.join(headings)}）。"
                "出典の数だけ見ると裏が取れているように見えますが、実際は1本です"
            )

    if plan is None or not notes.sources:
        return hints

    counts: dict[str, int] = {}
    for url in notes.sources:
        group = plan.group_of(url)
        host = url.split("/")[2] if "://" in url else url
        if group != "official":     # 公式は1社に寄って当然なので数えない
            counts[host] = counts.get(host, 0) + 1

    total = sum(counts.values())
    if total >= 3:
        host, count = max(counts.items(), key=lambda pair: pair[1])
        if count > total * SINGLE_SITE_SHARE:
            hints.append(
                f"出典{total}本のうち{count}本が {host} です。"
                "1社の報道に乗っているだけになっていないか確かめてください"
            )
    return hints


# 数を語る言い回し。ファンの反応で使うと、数えていないのに数えたことになる
CROWD_WORDS = (
    "声が多", "意見が多", "が大半", "ほとんど", "みんな", "世論",
    "圧倒的に", "軒並み", "総じて", "口を揃え",
)


def _advise_voices(notes: Notes) -> list[str]:
    """反応の扱いで気をつける点。"""
    hints: list[str] = []
    for section in notes.sections:
        card = section.card or {}
        if str(card.get("type", "")).lower() != "reactions":
            continue

        if section.tier not in ("未確認", "背景"):
            hints.append(
                f"節『{section.heading}』: ファンの反応は確度『未確認』で出すのが無難です"
                f"（いまは『{section.tier}』）。数人の投稿は世の中の総意ではありません"
            )
        for line in section.say:
            for word in CROWD_WORDS:
                if word in line:
                    hints.append(
                        f"節『{section.heading}』: 「{word}」は数を数えた言い方です。"
                        "投稿を数えていないなら「こういう声もある」に留めてください"
                    )
                    break
    return hints


# 確度の強さ。出典の群が支えられる上限と突き合わせるために順序を付ける
TIER_RANK = {"背景": 0, "未確認": 1, "報道": 2, "確定": 3}


def _advise_sources(notes: Notes, plan: Plan | None) -> list[str]:
    """節の確度を、出典の情報源が支えられるか調べる。

    噂まとめだけを根拠に「確定」と出すと、視聴者に対して嘘になる。
    群ごとの上限（config/sources.yaml の domain_tiers）と比べる。
    """
    if plan is None or not plan.domain_tiers:
        return []

    hints: list[str] = []
    for section in notes.sections:
        want = TIER_RANK.get(section.tier)
        if want is None or not section.sources:
            continue

        best, group = -1, ""
        for url in section.sources:
            if plan.is_blocked(url):
                hints.append(
                    f"節『{section.heading}』: 取得できないサイトを出典にしています"
                    f"（{url}）。裏を取り直せないので、別の出典に替えてください"
                )
                continue
            rank = TIER_RANK.get(plan.ceiling(url), -1)
            if rank > best:
                best, group = rank, plan.group_of(url)

        if best < 0:
            hints.append(
                f"節『{section.heading}』: 出典がどの情報源の群にも入っていません。"
                "config/sources.yaml の domains に足すか、別の出典に替えてください"
            )
        elif best < want:
            hints.append(
                f"節『{section.heading}』: 確度『{section.tier}』に対して出典が弱いです"
                f"（いちばん強いもので {group} 群 = {plan.domain_tiers.get(group)} まで）。"
                "確度を下げるか、より強い出典を足してください"
            )
    return hints


def _advise_posts(notes: Notes, plan: Plan | None, now=None) -> list[str]:
    """Xの投稿を出典に使っている節を見る。

    投稿URLに時刻が埋まっているので、開かなくても古さが分かる。
    古い噂をそのまま読み上げると、すでに決着した話を流すことになる。
    """
    if plan is None:
        return []
    stale = int((plan.social or {}).get("stale_hours", 24))
    hints: list[str] = []
    for section in notes.sections:
        for url in section.sources:
            if not xposts.is_post(url):
                continue
            for problem in xposts.review(url, plan.accounts, stale, now):
                hints.append(f"節『{section.heading}』: {problem}")
    return hints


def check_repeats(notes: Notes, plan: Plan, now=None) -> list[str]:
    """直近で扱ったテーマと重なっていないか調べる。

    1日に何本も出すと同じテーマを繰り返しがちなので、記録と突き合わせる。
    掘り直しとして意図的に扱う場合は follow_up: true を書く。
    """
    settings = plan.coverage or {}
    ledger = settings.get("ledger")
    if not ledger or notes.follow_up or not notes.theme_id:
        return []

    within = int(settings.get("repeat_within_hours", 36))
    hits = coverage.duplicates(coverage.load(ledger), [notes.theme_id], within, now)
    entry = hits.get(notes.theme_id)
    if entry is None:
        return []

    # 同じ日・同じ枠の記録は、この動画そのもの。作り直しは重複ではない
    today = (now or datetime.now()).date()
    if entry.slot == notes.slot and entry.at.date() == today:
        return []

    stamp = entry.at.strftime("%m/%d %H:%M")
    return [
        f"{notes.theme_id}: {stamp} の［{entry.slot}］で扱ったテーマです（{entry.headline}）。"
        "掘り直すなら follow_up: true を書いてください"
    ]


# テロップに入る目安。これを超えると読みきれないうちに次へ行く
TELOP_LIMIT = 26


def _telop(text: str, limit: int = TELOP_LIMIT) -> str:
    """読み上げ文をそのままテロップにすると長すぎる。頭の一文だけ使う。"""
    head = str(text).strip().split("。")[0].strip("　 ")
    if len(head) > limit:
        head = head[: limit - 1] + "…"
    return head


# 動詞・形容詞の言い切りはこの音で終わる。名詞止めと区別するために使う
PLAIN_ENDINGS = tuple("うくぐすつぬぶむるい")
POLITE_ENDINGS = ("です", "ます", "ました", "ません", "でした", "ましょう", "ください", "でしょう")


def _ends_sentence(text: str) -> str:
    """文末に句点を1つだけ付ける。

    取材メモの問いは「〜のか。」と句点で終えて書くことが多い。そこへ機械が
    もう1つ足していたので、読み上げが「〜のか。。25人枠の」となり、
    合成音声が不自然に間を空けていた（2026-09-04 に台本を読んで気づいた）。
    """
    text = text.strip()
    if not text:
        return ""
    return text if text[-1] in "。！？" else text + "。"


def _spoken(text: str) -> str:
    """メモの書き言葉を、読み上げても不自然でない形にする。

    「〜を拒んでいる」で終わるメモをそのまま読ませると、原稿の下書きを
    そのまま読んだように聞こえる。最後の文だけ、ですます に直す。
    """
    body = str(text).strip().rstrip("。")
    if not body:
        return ""
    parts = [part for part in body.split("。") if part.strip()]
    parts[-1] = _polite(parts[-1])
    return "。".join(parts) + "。"


def _polite(sentence: str) -> str:
    sentence = sentence.rstrip("　 ")
    if sentence.endswith(POLITE_ENDINGS):
        return sentence
    # 「拒んでいる」のような動詞止めと、「朝7時」のような名詞止めで付け方が違う
    if sentence.endswith(PLAIN_ENDINGS):
        return sentence + "、ということです"
    return sentence + "です"


def to_script(notes: Notes, plan: Plan) -> str:
    """検証を通った取材メモから、台本の Markdown を組み立てる。"""
    from . import tags as tags_mod

    problems = verify(notes, plan)
    if problems:
        raise ResearchError("取材メモに不備があります:\n  - " + "\n  - ".join(problems))

    thumbnail = notes.thumbnail or {}
    front = {
        "title": notes.video_title,
        "thumbnail_line1": str(thumbnail.get("line1") or notes.title),
        "thumbnail_line2": str(thumbnail.get("line2") or notes.question),
        "thumbnail_tags": [str(t) for t in (thumbnail.get("tags") or [])],
        # 案を書いてあれば台本に持ち越す。thumbnail --all で並べて比べる
        "thumbnail_alt": [dict(a or {}) for a in (thumbnail.get("alt") or [])],
        # init-assets が必ず作るものを既定にする。動く背景にしたいときは
        # `make-clip` で mp4 を作ってから、台本の bg を差し替える
        "bg": "assets/backgrounds/stadium.png",
        "date": notes.date,
        "intro_title": notes.title,
        "intro_label": "海外サッカー ニュース",
        "outro_title": _telop(notes.watch, 20) or "続報は次回お伝えします",
        "outro_sub": "チャンネル登録でお待ちください",
        "description": (
            f"{notes.title}\n\n"
            f"この動画が答える問い: {notes.question}\n\n"
            "※各社の報道をもとにしています。クラブが発表した「確定」、\n"
            "報道機関が伝える「報道」、SNS段階の「未確認」、\n"
            "経緯の説明である「背景」を画面上で分けています。\n"
        ),
        # タグは話の中身から作る。どの動画にも同じ4つでは検索に掛からない
        "tags": tags_mod.build(
            f"{notes.title} {notes.topic}",
            league_name=plan.league_name(notes.league) if notes.league else "",
            kind=notes.kind,
        ),
        "sources": notes.sources,
        "cards": _cards(notes),
    }

    # オープニングとまとめにも下地を指定する。指定が無いと frontmatter の既定に
    # 落ちて、どちらも同じ緑になっていた（実測でまとめの3カットが緑だった）
    lines = ["---", _front_matter(front), "---", "",
             "## オープニング", "@bg: assets/backgrounds/night.png", ""]
    hook = notes.hook or notes.title
    lines += [
        f"キャスター: 海外サッカーのニュースです。{hook}",
        f"  telop: {notes.title}",
        "  se: assets/audio/se_pon.wav",
        # 問いは「〜のか。」で終わることが多い。そのまま繋ぐと「。、ここを」になる
        f"キャスター: この動画では、{notes.question.rstrip('。')}、ここを掘っていきます。",
        f"  telop: 今回の問い: {_telop(notes.question, 20)}",
        "",
    ]

    previous_background = ""
    for index, section in enumerate(notes.sections):
        background = section.bg or BACKGROUND_BY_SECTION.get(section.id, "")
        if not background or background == previous_background:
            # 同じ下地が続くと、節が変わったことが画面から分からない。
            # 割り当てが無いときと、前の節と同じになったときは並びから選ぶ
            order = list(BACKGROUNDS[index % len(BACKGROUNDS):]) + list(BACKGROUNDS)
            background = next(c for c in order if c != previous_background)
        previous_background = background
        lines += [f"## {section.heading}", f"@bg: {background}", ""]
        for number, sentence in enumerate(section.say):
            # 掛け合いにする。1文目は事実をキャスターが読み、
            # 2文目以降は解説が受ける。交互に振ると同じ文体の読み分けになり、
            # 会話に聞こえない（実測）
            speaker = SPEAKERS[0] if number == 0 else SPEAKERS[1 if number % 2 else 0]
            lines.append(f"{speaker}: {sentence}")
            if number == 0:
                lines.append(f"  telop: {section.telop}")
                lines.append(f"  source: {section.tier}")
                if section.card:
                    lines.append(f"  card: {section.id}_card")
        lines.append("")

    lines += [
        "## まとめ",
        "@bg: assets/backgrounds/studio.png",
        "",
        # 問いと答えを1行にすると、実測で15.7秒ぶん画面が止まった（2026-09-04）。
        # 掛け合いの形にも合うので、問いをキャスター、答えを解説に分ける。
        f"キャスター: まとめます。{_ends_sentence(notes.question)}",
        f"  telop: 今回の問い: {_telop(notes.question, 20)}",
        "  card: wrap",
        f"解説: {_spoken(notes.answer)}",
        f"  telop: {_telop(notes.answer)}",
    ]
    if notes.watch:
        lines += [
            f"解説: 次の焦点です。{_spoken(notes.watch)}",
            f"  telop: 次の焦点: {_telop(notes.watch, 22)}",
        ]
    lines += [
        "キャスター: 動きがあり次第、あらためてお伝えします。"
        "続報はチャンネル登録してお待ちください。",
        "  telop: 続報はチャンネル登録でチェック",
        "  se: assets/audio/se_jingle.wav",
        "  pause: 1.2",
        "",
    ]
    return "\n".join(lines)


def _cards(notes: Notes) -> dict:
    cards: dict = {}
    for section in notes.sections:
        if section.card:
            cards[f"{section.id}_card"] = section.card
    # まとめのカードは「答え」だけにする。
    # 問い・答え・次の焦点を3つ並べたら、2分の動画の締めには字が細かすぎ、
    # 下のテロップとも重なっていた（作った動画を目視して発見）。
    # 問いは冒頭で、次の焦点は読み上げで言うので、画面で繰り返す必要はない。
    cards["wrap"] = {
        "type": "points",
        "title": "この動画の答え",
        "items": [notes.answer],
    }
    return cards


def _front_matter(front: dict) -> str:
    return yaml.safe_dump(front, allow_unicode=True, sort_keys=False, width=100).rstrip()
