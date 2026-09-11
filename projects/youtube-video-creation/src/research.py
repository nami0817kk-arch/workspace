"""取材メモ（YAML）を検証して、台本の下書きに変換する。

1本＝1テーマの深掘りを前提にしている。取材メモは
「テーマ」「動画が答える問い」「節（何が起きたか／なぜ／争点／これから）」で構成する。

検証でやること:
  - 確度の条件（config/sources.yaml の tiers）を満たしているか
  - 深掘りと呼べる節数があるか、問いが立っているか
  - 直近で扱った話題と重なっていないか
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

import yaml

from .backgrounds import moving_background
from .config import _resolve

from . import coverage, xposts
from .plan import Plan

# 節の中身に合う背景を選ぶ。順番に配るだけだと、緑の芝ばかりが続く
# （実測: 17カット中13カットが緑系だった）。節の性格で下地を変える。
#
# **2026-09-07 に実写の動画へ変えた。**自作の静止イラストだと、30〜50秒のあいだ
# 画面がほとんど動かない。ショートの競合は実際の試合映像で、権利の関係で
# それは使えないが、「動いていない」ことは埋められる。
# 素材は `stock` で取る（Pexels / Pixabay、クレジットは概要欄に出る）。
# **無ければ静止画に落ちる**ので、素材が揃っていない環境でも動く
STOCK = "assets/backgrounds/stock/"
BACKGROUND_BY_SECTION = {
    # 何が起きたか / 発表 —— 場の空気
    "what": STOCK + "stadium_night.mp4",
    "said": STOCK + "stadium_night.mp4",
    "stake": STOCK + "stadium_night.mp4",
    # 試合そのもの —— ボールとピッチ
    "score": STOCK + "soccer_ball.mp4",
    "turn": STOCK + "soccer_ball.mp4",
    "turning": STOCK + "soccer_ball.mp4",
    # 数字・整理 —— 模様の無い下地のほうが読める
    "numbers": "assets/backgrounds/studio.png",
    "point": "assets/backgrounds/studio.png",
    # 経緯・背景・反応 —— 観客側
    "background": STOCK + "football_fans.mp4",
    "context": STOCK + "football_fans.mp4",
    "react": STOCK + "football_fans.mp4",
    "voices": STOCK + "football_fans.mp4",
    "collapsed": STOCK + "football_fans.mp4",
    # これからどうなる / なぜ —— 練習・戦術
    "next": STOCK + "soccer_training.mp4",
    "why": STOCK + "soccer_training.mp4",
    "message": STOCK + "soccer_training.mp4",
}
# 上に無い節に配る並び。**実写を優先し、同じものが続かないようにする**
BACKGROUNDS = (
    STOCK + "stadium_night.mp4",
    STOCK + "football_fans.mp4",
    STOCK + "soccer_training.mp4",
    "assets/backgrounds/studio.png",
    STOCK + "soccer_ball.mp4",
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
    # 各行を誰の声で読むか。空文字はニュースを読む人（キャスター/解説）。
    # **代弁は出典のある発言だけ**に使う（2026-09-05 の型）
    voices: list[str] = field(default_factory=list)
    sources: list[str] = field(default_factory=list)
    official: bool = False
    card: dict | None = None
    # **行ごとのテロップとカード。**節に1枚だけだと、節の途中で画面が
    # まったく変わらない。実測（2026-09-06）で33秒・47秒の静止が出た
    line_telops: list = field(default_factory=list)
    line_cards: list = field(default_factory=list)
    # 行に差し込む写真。**本文に写真が1枚も入っていなかった**（実測 2026-09-06）。
    # 使えるライセンスが広がったので、顔を本文にも出す
    line_images: list = field(default_factory=list)
    bg: str = ""      # この節の背景。空なら既定の並びから割り当てる
    # **その節の地の文を誰が読むか**（2026-09-09 ユーザー指示）。
    # 空なら今までどおりキャスターと解説の交互。「何が起きたか」は事実なので
    # キャスターだけ、「試合はどう動いたか」は解説だけ、のように節で決められる
    narrator: str = ""
    # **答えを出す節の印**（2026-09-10 ユーザー「台本のここからが本題ですはいらない」）。
    # それまではセリフの頭に「ここからが本題です。」と書いて印にしていたが、
    # **聞く人には要らない言葉**だった。読み上げから外し、指定だけを残す。
    # ショートはこの印の付いた節を優先して選ぶ（`shorts.MAIN_BONUS`）
    main: bool = False


# まとめの答えの上限。**実測で決めた**（2026-09-08）。
# 止まったのは 66 / 67 / 73 / 76 字。通ったのは 48 / 50 / 54 字。
# 境目は54と66のあいだなので、少し余裕を見て 58 にする。
# **厳しくしすぎると鳴りっぱなしになり、警告が無いのと同じになる**
ANSWER_MAX = 58

# タイトルの頭に付ける札。まとめ系で定番の使い分け。
# **2026-09-07 に増やした。**分野を横断して24本を並べたら、向こうは動画ごとに
# 強い言葉を作っていた（【激ヤバ】【緊急事態】【崩壊】【魔境】【神試合】
# 【現地評価ぶっ壊れ】【お笑い】）。こちらは4つ固定で、毎回同じ顔になっていた。
# **数を増やしても中身と食い違わせない。**札は内容の要約であって煽りではない
PREFIXES = {
    "速報": "いま入った確定・報道",
    "朗報": "良いニュース",
    "悲報": "悪いニュース",
    "詳報": "続報・掘り下げ",
    "衝撃": "予想を外れた出来事",
    "緊急": "いま動いている・時間が迫っている",
    "独占": "一次情報に直接あたったもの",
    "現地反応": "現地のサポーター・媒体の受け止め",
    "神試合": "内容が突出した試合",
    "異変": "いつもと様子が違う",
    "決着": "長かった話が終わった",
    "波紋": "反応が割れている",
    "": "",
}


# 動画の型（2026-09-08）。**題材ごとに選ぶ。**
#
# 14チャンネルを同じ物差しで測ったら、ニュース番組の形をしているのは
# こちらだけで、伸びている側は形式も尺もバラバラなのに「誰かの声がある」点だけ
# 全員同じだった（docs/news-sources.md）。他所で回っている作りは、こちらでも
# 作れるようにしておく。どれを使うかは取材メモの format: で決める。
#
#   news   … キャスターと解説が事実を掘る。問い→節→反応。確度の札を出す
#            **まとめは無い**（2026-09-08 ユーザー「まとめはいらない」）。
#            反応の節を最後に置き、最後の1件で終わる。参考の動画はどれもそう終わる
#   voices … 事実は最初の30秒だけ。残りは反応を1件ずつ読む（2ch系5チャンネルの型）
#   quote  … 選手・監督が自分で語った言葉を切り出す（KOALA SOCCER の型・30秒前後）
FORMATS = {
    "news": {
        "label": "海外サッカー ニュース",
        "needs_question": True, "needs_answer": False, "wrap": False,
        "min_sections": 3,
        "voice_min": 40.0,
        "note": "※各社の報道をもとにしています。クラブが発表した「確定」、\n"
                "報道機関が伝える「報道」、SNS段階の「未確認」、\n"
                "経緯の説明である「背景」を画面上で分けています。\n",
    },
    "voices": {
        "label": "みんなの反応",
        "needs_question": False, "needs_answer": False, "wrap": False,
        "min_sections": 2,
        "voice_min": 70.0,
        "note": "※反応は実在する投稿・記事から引いています。出典は下にあります。\n"
                "個人が特定できる形では出していません。\n",
    },
    "quote": {
        "label": "本人の言葉",
        "needs_question": False, "needs_answer": False, "wrap": False,
        "min_sections": 1,
        "voice_min": 60.0,
        "note": "※発言は下の記事から引いています。\n",
    },
}


@dataclass
class Notes:
    date: str
    title: str
    question: str                    # この動画が答える問い
    format: str = "news"             # news / voices / quote。FORMATS 参照
    voice_min: float | None = None   # 他人の声の下限を回ごとに下げるとき
    # ショートに付ける別の題名（2026-09-09）。**書いても効いていなかった。**
    # shorts._retitle は台本の front matter を見るのに、to_script が書き出して
    # いなかったので、節のテロップが題名になっていた（「試合登録は20人。2人が
    # 外れる」が題名で並んでいた）
    short_title: str = ""
    # **この回に出てくる人の名前**（2026-09-10）。ハッシュタグに使う。
    # 参考4チャンネルは10〜34個貼っていて中身はほぼ選手名、こちらは7〜8個で
    # 選手名が1つも無い回があった。**本文から機械で拾わない**（辞書が無いので）
    people: list = field(default_factory=list)
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
        raw_lines = [say] if isinstance(say, str) else list(say or [])
        # `- text` でも `- {voice: 監督, text: …}` でも書けるようにする。
        # 誰かの発言を、その人の声で読ませるため
        lines: list[str] = []
        voices: list[str] = []
        telops: list[str] = []
        cards: list = []
        images: list[str] = []
        for item in raw_lines:
            if isinstance(item, dict):
                lines.append(str(item.get("text", "")).strip())
                voices.append(str(item.get("voice", "")).strip())
                telops.append(str(item.get("telop", "")).strip())
                cards.append(item.get("card"))
                images.append(str(item.get("image", "")).strip())
            else:
                lines.append(str(item).strip())
                voices.append("")
                telops.append("")
                cards.append(None)
                images.append("")
        keep = [i for i, s in enumerate(lines) if s]
        sections.append(
            Section(
                id=str(entry.get("id") or f"s{index}"),
                heading=str(entry.get("heading", "")).strip(),
                main=bool(entry.get("main", False)),
                tier=str(entry.get("tier", "")).strip(),
                telop=str(entry.get("telop", "")).strip(),
                say=[s for s in lines if s],
                voices=[v for s, v in zip(lines, voices) if s],
                line_telops=[telops[i] for i in keep],
                line_cards=[cards[i] for i in keep],
                line_images=[images[i] for i in keep],
                sources=[str(u).strip() for u in (entry.get("sources") or []) if str(u).strip()],
                official=bool(entry.get("official", False)),
                card=entry.get("card"),
                bg=str(entry.get("bg", "")).strip(),
                narrator=str(entry.get("narrator", "")).strip(),
            )
        )
    if not sections:
        raise ResearchError("sections が空です。節を立てて掘ってください")

    chosen = str(raw.get("format") or theme.get("format") or "news").strip().lower()
    if chosen not in FORMATS:
        raise ResearchError(
            f"format『{chosen}』は知らない型です（{' / '.join(FORMATS)}）"
        )

    return Notes(
        date=str(raw.get("date", "")).strip(),
        slot=str(raw.get("slot", "")).strip(),
        format=chosen,
        voice_min=(float(raw["voice_min"]) if raw.get("voice_min") is not None else None),
        short_title=str(raw.get("short_title", "")).strip(),
        people=[str(x).strip() for x in (raw.get("people") or []) if str(x).strip()],
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
    shape = FORMATS[notes.format]
    # 問いと答えは news の型だけに求める。反応や本人の言葉を並べる型に
    # 「問い」を立てさせると、無理に作った問いが冒頭に乗る
    if shape["needs_question"] and policy.get("require_question", True) and not notes.question:
        problems.append(
            "theme.question が空です。この動画が答える問いを1つ立ててください"
            "（例: なぜ金の問題ではないのか）"
        )
    if shape["needs_answer"] and not notes.answer:
        problems.append("answer が空です。まとめで問いにどう答えるかを書いてください")

    minimum = int(shape["min_sections"])
    if notes.format == "news":
        minimum = int(policy.get("min_sections", minimum))
    if len(notes.sections) < minimum:
        what = "深掘りには" if notes.format == "news" else f"型『{notes.format}』には"
        problems.append(
            f"節が{len(notes.sections)}つしかありません。{what}{minimum}つ以上必要です"
            + ("（何が起きたか／なぜ／争点／これから）" if notes.format == "news" else "")
        )
    # **反応で終わる**（2026-09-08 ユーザー「他人の声のところは他のチャンネルを参考に」）。
    # 参考の動画は、事実のあとに反応を1件ずつ読んで、最後の1件で切れる。
    # こちらは反応のあとに「これから何を見るか」と「まとめ」を語っていた。
    # 反応の節より後ろに、語りだけの節があれば止める
    problems += _check_voices_last(notes)
    if notes.format == "voices" and not _has_crowd(notes):
        problems.append(
            "型『voices』なのに、反応の行（voice: ネット民 など）がありません。"
            "事実の節のあとに、反応を1件ずつ voice 付きで並べてください"
        )
    if notes.format == "quote" and not _has_named_voice(notes):
        problems.append(
            "型『quote』なのに、本人の発言の行（voice: 選手名）がありません"
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
        problems += _check_card(section)

        if rule.get("needs_official") and not section.official:
            problems.append(
                f"{label}: 確度『{section.tier}』はクラブ・当事者の発表が条件です。"
                "発表を確認できないなら tier を下げてください"
            )
    problems += _check_voice_clash(notes)
    return problems

def _has_crowd(notes: Notes) -> bool:
    """匿名の反応の行があるか。voice が付いていてキャスター・解説ではないもの。"""
    return any(v and v not in SPEAKERS
               for section in notes.sections for v in section.voices)


def _has_named_voice(notes: Notes) -> bool:
    return _has_crowd(notes)


# 匿名の群衆の名前。config/project.yaml の voicevox.voice_crowd と同じ顔ぶれ。
# **ここに載っている声だけが「反応」。**名前のある人の発言は反応ではない
# （2026-09-09、監督の会見を反応と見て「反応で終わる」の点検が誤って鳴った）
CROWD_VOICES = ("ネット民", "現地サポ", "海外のファン")


def _voice_heavy(section: Section) -> bool:
    """匿名の反応が半分以上の節。**名前のある人の発言は数えない。**"""
    if not section.say:
        return False
    crowd = sum(1 for v in section.voices if v in CROWD_VOICES)
    return crowd * 2 >= len(section.say)


def _check_voices_last(notes: Notes) -> list[str]:
    """反応の節のあとに、語りだけの節が続いていないか。"""
    heavy = [i for i, s in enumerate(notes.sections) if _voice_heavy(s)]
    if not heavy:
        return []
    trailing = [s.heading or s.id for s in notes.sections[heavy[-1] + 1:]]
    if not trailing:
        return []
    return [
        "反応の節のあとに語りの節があります（" + "／".join(trailing) + "）。"
        "参考チャンネルは反応の最後の1件で終わります。"
        "見通しは反応の前に置いてください"
    ]


def _check_voice_clash(notes: Notes) -> list[str]:
    """別人が同じ声にならないか（2026-09-07）。

    声は名前のハッシュで選ぶので、まれに衝突する。メッシとモウリーニョが
    どちらも style 42 になっていた。**書き出す前に気づけるようにする。**
    """
    try:
        from .config import load_config

        config = load_config()
    except Exception:
        return []

    names = sorted({v.strip() for section in notes.sections
                    for v in section.voices if v.strip()})
    seen: dict[int, str] = {}
    problems: list[str] = []
    for name in names:
        try:
            style = config.resolve_speaker(name).style_id
        except Exception:
            continue
        if style in seen and seen[style] != name:
            # **空いている声を出す。**止めるだけだと、config を開いて
            # 20個の番号から空きを探すことになる
            # **決め打ちしていない方を動かす。**すでに決めた人の声を
            # 変えると、その人の声が動画をまたいで変わる
            move = name if name not in config.voice_fixed else seen[style]
            pool = (config.voice_pool_female
                    if move in config.voice_female else config.voice_pool)
            free = next((v for v in pool if v not in seen), None)
            hint = (f"（config の voicevox.voice_fixed に「{move}: {free}」を足す）"
                    if free else "（プールに空きがありません。声を増やしてください）")
            problems.append(
                f"『{seen[style]}』と『{name}』が同じ声（style {style}）になります。"
                + hint
            )
        else:
            seen.setdefault(style, name)
    return problems


def _check_card(section: Section) -> list[str]:
    """カードの中身が、書き出しに耐える形かを取材メモの段階で見る。

    **書き出しまで気づけなかった**（2026-09-09）。`table` に columns を
    書き忘れた台本が `draft` を通り、音声を合成し終えたあとの
    `render` で「table カードには columns と rows が必要です」で落ちた。
    落ちる条件はカードの側が知っているので、ここで先に同じことを見る。
    """
    card = section.card or {}
    kind = str(card.get("type", "")).lower()
    problems: list[str] = []
    if kind == "table":
        columns = card.get("columns") or []
        rows = card.get("rows") or []
        if not columns or not rows:
            problems.append(f"{section.id}: table カードには columns と rows が必要です")
        elif any(len(row) != len(columns) for row in rows):
            problems.append(
                f"{section.id}: table の各行は columns と同じ数（{len(columns)}）にしてください"
            )
    elif kind == "bars":
        if not (card.get("items") or []):
            problems.append(f"{section.id}: bars カードには items が必要です")
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
    # **出典が無くても書き出す**（2026-09-11 ユーザー「出しても良い」）。
    # それまでは弾いていた。**反応そのものが実在するかどうかの決まりは
    # 変えていない**（作らない）。URL を後から足す回まで止めないだけ。

    for item in card.get("items") or []:
        entry = item if isinstance(item, dict) else {"text": str(item)}
        label = str(entry.get("label", "")).strip()
        if label.startswith("@"):
            problems.append(
                f"{section.id}: 反応のラベルにアカウント名（{label}）が入っています。"
                "個人が特定できる形では出しません。「X」「海外のファン」などにしてください"
            )
    return problems


def _has_name(title: str, sections) -> bool:
    """タイトルに人名かクラブ名らしきものが入っているか。

    カタカナが4文字以上続くか、漢字が2〜4文字続けば名前とみなす。
    厳密な判定ではなく、**入れ忘れに気づかせる**ための目安。
    """
    import re

    if re.search(r"[ァ-ヴー]{4,}", title):
        return True
    return bool(re.search(r"[一-鿿]{2,4}", title))


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

    # **札は毎回付けない**（2026-09-08 ユーザー指示）。
    # 参考3チャンネルは例外なく先頭にラベルを付けているが、
    # こちらは同じ札が並ぶと一覧が単調になる。**空でよい。**
    # 付けるなら、その回に釣り合うものだけ。数の偏りは variety が見る。
    # 同じく3チャンネルとも、タイトルに人名かクラブ名が入る
    if notes.title and not _has_name(notes.title, notes.sections):
        notes_warnings.append(
            "タイトルに選手名・クラブ名が見当たりません。"
            "参考3チャンネルはどれも人の名前を入れています"
        )

    if len(notes.video_title) > 40:
        notes_warnings.append(
            f"タイトルが{len(notes.video_title)}文字。一覧では途中で切れます"
            "（参考3チャンネルは20〜35文字が中心）"
        )

    if not notes.thumbnail.get("line1"):
        notes_warnings.append(
            "thumbnail.line1 が空です。サムネの主見出しを書いてください"
        )
    if len(str(notes.thumbnail.get("line1", ""))) > 14:
        notes_warnings.append("thumbnail.line1 が長めです。14文字くらいまでが読みやすい")

    # **サムネに答えを書かない**（2026-09-08 ユーザー指摘）。
    # タイトルでは答えを隠しているのに、サムネの左に「挙げられた3人の名前」を
    # そのまま並べていた。それでは隠している意味が消える。
    # 参考チャンネルは答えの位置を ●● で伏せている
    for point in (notes.thumbnail.get("points") or [])[:3]:
        bare = point.replace("●", "").strip()
        if len(bare) >= 4 and bare in notes.answer:
            notes_warnings.append(
                f"サムネの『{point}』が、まとめの答えにそのまま入っています。"
                "タイトルで隠しているのに、サムネで答えては意味がありません")

    # **まとめの答えが長いと、カードが12秒以上そのままになる**（2026-09-08 実測）。
    # 書き出してから review の「カードの持ち」で気づくと、音声から作り直しになる。
    # 45字で約12秒。ここで知らせれば、作り直さずに済む
    if len(notes.answer) > ANSWER_MAX:
        notes_warnings.append(
            f"answer が{len(notes.answer)}字あります（{ANSWER_MAX}字まで）。"
            "まとめのカードが12秒以上そのままになり、review が止めます")
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


# 他人の声の目安（2026-09-07、docs/video-quality.md の実測）。
# 参考3チャンネルは尺の58%・19.2件・1件3.1秒。こちらは14%・2.2件・1件39字だった
VOICE_SHARE_TARGET = 40      # %
VOICE_COUNT_TARGET = 10      # 件
# 字。2026-09-07 に実測（1件3.1秒＝約16字）で20字に締めたが、2026-09-08 に
# サッカーラボ（25.5万回）の文字起こしを取ると1件30〜45字だった。参考が割れて
# いるので目安は30字、review の上限は45字にする
VOICE_LINE_TARGET = 30


def _advise_title(notes: Notes) -> list[str]:
    """タイトルが答えを言い切っていないか（2026-09-07）。

    各チャンネルの最高再生を並べたら、上位はほぼ全部が答えを隠していた。
    こちらの直近14本は全部が言い切りで、タイトルで用が足りてしまっていた。
    """
    from .review import TITLE_HOOKS, TITLE_QUESTION_TAILS

    title = notes.video_title
    if any(word in title for word in TITLE_HOOKS):
        return []
    if title.rstrip("。！!").endswith(TITLE_QUESTION_TAILS):
        return []
    if title.rstrip("。！!").endswith(("」", "』")):
        return []
    return [
        f"タイトル『{title[:24]}…』が答えを言い切っています。"
        "伸びている3チャンネルの上位は「〜がこちらです」「〜が話題に」"
        "「〜してしまう」のように**答えを隠して**います（中身では必ず答える）"
    ]


def _advise_volume(notes: Notes) -> list[str]:
    """他人の声が足りているか。**ここが再生数の差の中身**なので、書式より先に見る。"""
    other: list[int] = []
    total = 0
    for section in notes.sections:
        for number, sentence in enumerate(section.say):
            total += len(sentence)
            voice = section.voices[number] if number < len(section.voices) else ""
            if voice and voice not in SPEAKERS:
                other.append(len(sentence))
    if not total:
        return []

    hints: list[str] = []
    share = sum(other) / total * 100
    if share < VOICE_SHARE_TARGET:
        hints.append(
            f"他人の声が{share:.0f}%（{len(other)}件）しかありません。"
            f"伸びている3チャンネルは58%・19件です。"
            "`reactions <スレURL> --say` で短い反応を取り出せます"
        )
    elif len(other) < VOICE_COUNT_TARGET:
        hints.append(
            f"他人の声は{len(other)}件です。参考は19件で、1件2〜4秒に刻んでいます"
        )
    long_lines = [n for n in other if n > VOICE_LINE_TARGET]
    if long_lines:
        hints.append(
            f"長い引用が{len(long_lines)}件あります（最長{max(long_lines)}字）。"
            "1件は30字までに割ってください。長いと画面も声も止まります"
        )
    return hints


# 中身のボリューム（2026-09-08 ユーザー「中身のボリュームで負けている」）。
# 今日の18本の中央値は 他人の声4件・数字の行7・出典4本/3媒体。
# 参考（サッカーラボ 25.5万回）は反応約15件、冒頭30秒に数字4つ
VOLUME_VOICES = 10       # 件
VOLUME_NUMBERS = 8       # 数字を含む行
VOLUME_SOURCES = 5       # 出典の本数
VOLUME_OUTLETS = 3       # 媒体の数


def _bare_text(text: str) -> str:
    """比べるための素の文。句読点と記号を落とす。"""
    return re.sub(r"[。、．，\s　？?！!「」『』]", "", str(text or ""))


def _advise_hook(notes: Notes) -> list[str]:
    """つかみの一言が、問いの言い直しになっていないか（2026-09-09）。

    視聴維持の曲線で、捨てられているのは4〜9秒だった。タイトルを読むところまでは
    残り、そのあとの一言で半分以上が消える。**言い直しなら、無いほうがよい。**
    """
    if notes.format != "news":
        return []
    if not notes.hook:
        return ["theme.hook が空です。**その行は出しません**"
                "（問いの言い直しは4〜9秒で半分が離脱した実測があります）。"
                "入れるなら、問いとは別の一言を書いてください"]
    if _bare_text(notes.hook) == _bare_text(notes.question):
        return ["theme.hook が問いと同じです。**その行は出しません。**"
                "別の一言にするか、空のままにしてください"]
    return []


def _advise_thumbnail_repeat(notes: Notes) -> list[str]:
    """サムネの帯と伏せ字が同じことを言っていないか（2026-09-09 ユーザー指摘）。

    3本とも `line2` と `points` の1つが同じ文だった。狭い1枚に同じ言葉を
    2回置くと、**そのぶん言えることが減る**。
    """
    thumbnail = notes.thumbnail or {}
    said = [str(thumbnail.get("line1") or ""), str(thumbnail.get("line2") or "")]
    points = [str(p) for p in (thumbnail.get("points") or [])]
    hints: list[str] = []
    for point in points:
        for index, line in enumerate(said, start=1):
            if not point or not line:
                continue
            if _bare_text(point) == _bare_text(line):
                hints.append(f"サムネの points『{point}』が line{index} と同じです。"
                             "1枚に同じことを2回書くと、そのぶん言えることが減ります")
    for index, point in enumerate(points):
        for other in points[index + 1:]:
            if _bare_text(point) == _bare_text(other):
                hints.append(f"サムネの points に同じ文が2つあります: 『{point}』")
    return hints


def _advise_material(notes: Notes) -> list[str]:
    """中身の量が参考に届いているか。届かなければ、どこが薄いかを言う。"""
    from urllib.parse import urlparse

    voices = sum(1 for s in notes.sections for v in s.voices if v and v not in SPEAKERS)
    numbers = sum(1 for s in notes.sections for line in s.say if any(ch.isdigit() for ch in line))
    sources = notes.sources
    outlets = {urlparse(u).netloc for u in sources}
    hints: list[str] = []
    if voices < VOLUME_VOICES:
        hints.append(f"他人の声が{voices}件です（目安{VOLUME_VOICES}件）。"
                     "`reactions --find <題材>` でスレを探して足せます")
    if numbers < VOLUME_NUMBERS:
        hints.append(f"数字を含む行が{numbers}行です（目安{VOLUME_NUMBERS}行）。"
                     "`material` の数字の行から拾えます")
    if len(sources) < VOLUME_SOURCES or len(outlets) < VOLUME_OUTLETS:
        hints.append(f"出典が{len(sources)}本・{len(outlets)}媒体です"
                     f"（目安{VOLUME_SOURCES}本・{VOLUME_OUTLETS}媒体）")
    return hints


def _advise_voices(notes: Notes) -> list[str]:
    """反応の扱いで気をつける点。"""
    hints: list[str] = (_advise_volume(notes) + _advise_material(notes)
                        + _advise_hook(notes) + _advise_thumbnail_repeat(notes)
                        + _advise_title(notes))
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
# **画面に出る字の上限**。1920幅・58pxで1行に約27.8字、枠には3行入る。
# 26 は1行ぶんで、**読み上げの半分しか画面に出ていなかった**
# （2026-09-10 に19本513行を数えて 46%。ユーザー指摘）。2行ぶんに広げた
TELOP_LIMIT = 54


def _resolve_bg(path: str):
    """背景の実体。**取っていない素材を台本に書かないため。**"""
    from pathlib import Path as _P

    return _P(path)


def _telop(text: str, limit: int = TELOP_LIMIT) -> str:
    """読み上げ文を画面に出す形にする。

    **前は「。」で切って頭の一文だけにしていた。**2文目以降は必ず落ちるので、
    「6分、ヤマルのゴールで先制します。2試合続けての得点でした」の後半が
    画面に出ないまま読まれていた（2026-09-10 実測）。
    いまは**収まるなら丸ごと出す**。収まらないときだけ、限度の中で
    文の切れ目を探して切る。切れ目が無ければ … を付ける。
    """
    body = str(text).strip().strip("　 ")
    if not body:
        return ""
    if len(body) <= limit:
        return body.rstrip("。")
    head = body[:limit]
    for mark in ("。", "、"):
        cut = head.rfind(mark)
        if cut >= limit // 2:          # 半分より前で切ると言葉が足りない
            return body[:cut]
    return body[: limit - 1] + "…"


# 動詞・形容詞の言い切りはこの音で終わる。名詞止めと区別するために使う
# 「た」「だ」（過去形）を入れていなかったせいで、「判断した」が「判断したです」に
PLAIN_ENDINGS = tuple("うくぐすつぬぶむるいただ")
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
    shape = FORMATS[notes.format]
    front = {
        "title": notes.video_title,
        # 型は台本に残す。review が型ごとにしきい値を変える
        "format": notes.format,
        # 他人の声の下限を回ごとに下げられる（2026-09-09）。試合の経過を詳しく
        # 伝える回は地の文が増える。**下げるときは取材メモに理由を書く**
        **({"voice_min": notes.voice_min} if notes.voice_min is not None else {}),
        # ショートだけ別の題名にする（2026-09-09）。shorts._retitle がここを見る
        **({"short_title": notes.short_title} if notes.short_title else {}),
        "thumbnail_line1": str(thumbnail.get("line1") or notes.title),
        "thumbnail_line2": str(thumbnail.get("line2") or notes.question),
        "thumbnail_tags": [str(t) for t in (thumbnail.get("tags") or [])],
        # 案を書いてあれば台本に持ち越す。thumbnail --all で並べて比べる
        "thumbnail_alt": [dict(a or {}) for a in (thumbnail.get("alt") or [])],
        # 左の余白に積む短い言葉（2026-09-08）。3つまで
        "thumbnail_points": [str(x) for x in (thumbnail.get("points") or [])][:3],
        # 顔を並べる（2026-09-08）。2〜3枚で全面が写真になる
        "thumbnail_photos": [str(x) for x in (thumbnail.get("photos") or [])][:3],
        # **エンブレムを主役にする**（2026-09-09 ユーザー指示）。
        # 「小さく添えるだけ」の決まりを変えた。出てくる人のクラブ姿の写真が
        # 無いときに使う。写真より優先される
        "thumbnail_crest_main": [str(x) for x in (thumbnail.get("crest_main") or [])][:3],
        # エンブレム2つの間に置く字。対戦以外の回で「対」だと誤解を招く
        **({"thumbnail_crest_link": str(thumbnail["crest_link"])}
           if thumbnail.get("crest_link") is not None else {}),
        # 並べた顔の継ぎ目に置く印。対立の回だけ
        **({"thumbnail_face_link": str(thumbnail["face_link"])}
           if thumbnail.get("face_link") is not None else {}),
        # **エンブレムだけ止める**（2026-09-09 ユーザー「レアルは不要」）。
        # tags を削ると YouTube のタグからも消えるので、絵のほうだけ別に持つ
        **({"thumbnail_crests": [str(x) for x in (thumbnail.get("crests") or [])]}
           if "crests" in thumbnail else {}),
        # **顔写真は取材メモに持たせる。**台本にしか書けなかったので、
        # 台本を作り直すたびに消えていた（2026-09-06 に2回やった）。
        # 直すたびに手で書き戻すのは、必ずどこかで抜ける
        **({"thumbnail_photo": str(thumbnail["photo"])} if thumbnail.get("photo") else {}),
        **({"thumbnail_focus": thumbnail["focus"]} if thumbnail.get("focus") is not None else {}),
        # init-assets が必ず作るものを既定にする。動く背景にしたいときは
        # `make-clip` で mp4 を作ってから、台本の bg を差し替える
        "bg": "assets/backgrounds/stadium.png",
        "date": notes.date,
        "intro_title": notes.title,
        "intro_label": shape["label"],
        "outro_title": _telop(notes.watch, 20) or "続報は次回お伝えします",
        "outro_sub": "チャンネル登録でお待ちください",
        "description": (
            f"{notes.title}\n\n"
            + (f"この動画が答える問い: {notes.question}\n\n" if notes.question else "")
            + shape["note"]
        ),
        # タグは話の中身から作る。どの動画にも同じ4つでは検索に掛からない
        "tags": tags_mod.build(
            f"{notes.title} {notes.topic}",
            league_name=plan.league_name(notes.league) if notes.league else "",
            kind=notes.kind,
            # **選手名を入れる**（2026-09-08）。辞書が無いので推測はしないが、
            # サムネの札には人名を書いているので、そこから持ってくる。
            # 参考4チャンネルのハッシュタグはほぼ全部が選手名とクラブ名で、
            # こちらは「サッカー」「移籍市場」のような分類語しか無かった。
            # サンチョの回にサンチョが入っていない状態だった
            extra=[str(t) for t in (thumbnail.get("tags") or [])],
            # **この回に出てくる人**（2026-09-10）。取材メモの `people:` に書く。
            # 辞書が無いので本文からは拾わない（推測で人名を作らない）
            people=list(notes.people),
            topic=notes.topic,
        ),
        "sources": notes.sources,
        "cards": _cards(notes),
    }

    # オープニングとまとめにも下地を指定する。指定が無いと frontmatter の既定に
    # 落ちて、どちらも同じ緑になっていた（実測でまとめの3カットが緑だった）
    lines = ["---", _front_matter(front), "---", "",
             "## オープニング",
             f"@bg: {moving_background('assets/backgrounds/night.png')}", ""]
    # **1行目はタイトルをそのまま読む**（2026-09-07）。参考3チャンネルの直近4本は
    # 全部、最初の2〜5秒でタイトルを読み上げていた。クリックした人が「これで
    # 合っている」と確かめられる。こちらは別の導入文から入っていた。
    #
    # **冒頭から名乗らない。**「海外サッカーのニュースです」は毎回同じで中身が無く、
    # 続く「〜ここを掘っていきます」も問いを言い直しているだけだった。
    # **問いは読み上げず、画面に出す。**読むと、つかみと合わせて前置きが18秒になる
    lines += [
        f"キャスター: {_ends_sentence(notes.title)}",
        f"  telop: {notes.title}",
        "  se: assets/audio/se_pon.wav",
    ]
    if notes.format == "news":
        # **問いを読み上げない**（2026-09-09）。視聴維持の曲線を読んだら、
        # 捨てられているのは0〜3秒ではなく**4〜9秒**だった（4秒100% → 8秒39.7%）。
        # タイトルを読むところまでは残り、そのあとの一言で半分以上が消える。
        # hook が空のときは question をそのまま読んでいた＝クリックした人が
        # もう知っている話の言い直し。**書いていなければ、その行ごと出さない。**
        if notes.hook and _bare_text(notes.hook) != _bare_text(notes.question):
            lines += [
                f"キャスター: {_ends_sentence(notes.hook)}",
                # 画面は2〜3行に折り返せる。20字で切ると「…当の監督…」のように
                # 途中で切れた文字がそのまま出ていた（2026-09-07 に書き出して確認）
                f"  telop: 今回の問い: {_telop(notes.question, TELOP_LIMIT)}",
            ]
    elif notes.hook:
        # 反応・本人の言葉の型は、つかみが書いてあれば1行だけ。問いは立てない。
        # 参考（サッカーラボ 25.5万回）は 0:02 でタイトル、0:11 から事実だった
        lines.append(f"キャスター: {_ends_sentence(notes.hook)}")
    lines.append("")

    previous_background = ""
    for index, section in enumerate(notes.sections):
        background = section.bg or BACKGROUND_BY_SECTION.get(section.id, "")
        # **素材が無ければ静止画に落とす。**stock を取っていない環境でも動く
        if background.startswith(STOCK) and not _resolve_bg(background).exists():
            background = ""
        if not background or background == previous_background:
            # 同じ下地が続くと、節が変わったことが画面から分からない。
            # 割り当てが無いときと、前の節と同じになったときは並びから選ぶ
            order = list(BACKGROUNDS[index % len(BACKGROUNDS):]) + list(BACKGROUNDS)
            background = next(c for c in order if c != previous_background)
        previous_background = background
        lines += [f"## {section.heading}", f"@bg: {moving_background(background)}"]
        if section.main:
            lines.append("@main: true")
        lines.append("")
        for number, sentence in enumerate(section.say):
            # 掛け合いにする。1文目は事実をキャスターが読み、
            # 2文目以降は解説が受ける。交互に振ると同じ文体の読み分けになり、
            # 会話に聞こえない（実測）
            # 誰かの発言なら、その人の名前を話者にする。**代弁は人ごとに声が変わる。**
            voice = section.voices[number] if number < len(section.voices) else ""
            # 節が読み手を決めていれば、そのまま。**交互は既定であって決まりではない**
            # （2026-09-09 ユーザー「何が起きたかはキャスターが伝えて良い」）
            speaker = voice or section.narrator or (
                SPEAKERS[0] if number == 0 else SPEAKERS[1 if number % 2 else 0]
            )
            lines.append(f"{speaker}: {sentence}")
            own_telop = (section.line_telops[number]
                         if number < len(section.line_telops) else "")
            own_card = (section.line_cards[number]
                        if number < len(section.line_cards) else None)
            own_image = (section.line_images[number]
                         if number < len(section.line_images) else "")
            if number == 0:
                # **1行目が代弁なら、その人の言葉として出す。**節のテロップを
                # そのまま被せると、別人の発言に他人の名前が乗る（実測 2026-09-06）
                head = own_telop or section.telop
                if not own_telop and voice and voice not in SPEAKERS:
                    room = max(8, TELOP_LIMIT - len(voice) - 1)
                    head = f"{voice}「{_telop(sentence, room)}」"
                lines.append(f"  telop: {head}")
                lines.append(f"  source: {section.tier}")
                if own_card:
                    lines.append(f"  card: {section.id}_{number}_card")
                elif section.card:
                    lines.append(f"  card: {section.id}_card")
                # **カードが無い行にも写真は出す。**入れ子にしていたせいで、
                # カードを持たない行の写真が消えていた（実測 2026-09-06）
                if own_image:
                    lines.append(f"  image: {own_image}")
            else:
                # **指定が無い行にも、読み上げ文からテロップを作る**
                # （2026-09-06 ユーザーの指示）。指定が無いと前の見た目のまま
                # 続き、画面が止まる。テレビのニュースは1発言ごとに字幕が変わる。
                # **代弁の行は誰の言葉かを頭に付ける。**画面だけ見ても分かるように
                shown = own_telop
                if not shown and voice and voice not in SPEAKERS:
                    # 代弁は誰の言葉かを頭に付ける。画面だけ見ても分かるように
                    room = max(8, TELOP_LIMIT - len(voice) - 1)
                    shown = f"{voice}「{_telop(sentence, room)}」"
                elif not shown:
                    # **地の文も画面に出す**（2026-09-10 ユーザー指摘で変更）。
                    # それまでは「最初の一文が16字に収まるときだけ」出していた。
                    # 収まらない行は**何も出ず、前の画面が残る**ので、
                    # 513行のうち198行（39%）で画面が読み上げとずれていた。
                    # 実例: 「アルバレスを獲れませんでした」と読んでいるあいだ、
                    # 画面はフリックの発言のままだった。
                    # 元の理由（字幕と二重になる）は、字幕が焼き込みではなく
                    # 別ファイルの CC なので、そもそも二重にならない
                    shown = _telop(sentence)
                if shown:
                    lines.append(f"  telop: {shown}")
                if own_card:
                    lines.append(f"  card: {section.id}_{number}_card")
                if own_image:
                    lines.append(f"  image: {own_image}")
        lines.append("")

    # **まとめは答えの1行だけにする**（2026-09-07）。参考3チャンネルの直近4本に
    # まとめの節は1つも無く、最後は反応で終わっていた。こちらは最後の節が尺の
    # 18%（4行20〜25秒）を占め、中身は冒頭で言ったことの言い直しだった。
    #
    # **答えそのものは残す。**このチャンネルは「なぜそうなったかを、2分で」を
    # 名乗っていて、答えを出さないなら看板の方を降ろすことになる。
    # 次の焦点は読み上げず、最後のカード（outro_title）と概要欄に置く。
    # 締めの挨拶（続報は…チャンネル登録して…）は毎回同じで、8秒を使っていた
    # **まとめの下地も、直前の節と同じにしない。**決め打ちにしていたため、
    # 最後の節がたまたま studio に落ちると2節続けて同じ絵になっていた
    # （2026-09-07 に CI が検出）。本文の節と同じ選び方に揃える。
    #
    # **まとめがあるのは news の型だけ。**反応や本人の言葉の型は、最後の1件で
    # 終わる。参考の動画はどれも反応で切れていて、締めの語りが無い
    if shape["wrap"]:
        wrap_background = "assets/backgrounds/studio.png"
        if wrap_background == previous_background:
            wrap_background = next(c for c in BACKGROUNDS if c != previous_background)
        lines += [
            "## まとめ",
            f"@bg: {moving_background(wrap_background)}",
            "",
            f"解説: {_spoken(notes.answer)}",
            f"  telop: {_telop(notes.answer)}",
            "  card: wrap",
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
        for number, one in enumerate(section.line_cards):
            if one:
                cards[f"{section.id}_{number}_card"] = one
    # まとめのカードは「答え」だけにする。
    # 問い・答え・次の焦点を3つ並べたら、2分の動画の締めには字が細かすぎ、
    # 下のテロップとも重なっていた（作った動画を目視して発見）。
    # 問いは冒頭で、次の焦点は読み上げで言うので、画面で繰り返す必要はない。
    if FORMATS[notes.format]["wrap"]:
        cards["wrap"] = {
            "type": "points",
            "title": "この動画の答え",
            "items": [notes.answer],
        }
    return cards


def _front_matter(front: dict) -> str:
    return yaml.safe_dump(front, allow_unicode=True, sort_keys=False, width=100).rstrip()
