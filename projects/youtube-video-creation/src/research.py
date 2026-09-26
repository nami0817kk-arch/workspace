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
    # **football_fans.mp4 は stadium_night.mp4 と同じファイルだった**（md5一致／
    # 2026-09-13 に発覚）。名前が2つあるだけで、上の「場の空気」と同じ絵が
    # 流れていた。観客の入った昼のスタジアムに差し替えた
    # **`match_stadium.mp4` はヴォルフスブルクのスタジアム**で、
    # LEDの看板に VFL WOLFSBURG と読める（2026-09-18 に画面で見つけた）。
    # どのクラブの回でも使う下地なので、**クラブ名が映るものは置けない**
    "background": STOCK + "stadium_night.mp4",
    "context": STOCK + "stadium_night.mp4",
    "react": STOCK + "stadium_night.mp4",
    "voices": STOCK + "stadium_night.mp4",
    "collapsed": STOCK + "stadium_night.mp4",
    # これからどうなる / なぜ —— 練習・戦術
    "next": STOCK + "soccer_training.mp4",
    "why": STOCK + "soccer_training.mp4",
    "message": STOCK + "soccer_training.mp4",
}
# 上に無い節に配る並び。**実写を優先し、同じものが続かないようにする**
BACKGROUNDS = (
    STOCK + "stadium_night.mp4",
    STOCK + "soccer_training.mp4",
    STOCK + "stadium_night.mp4",
    "assets/backgrounds/studio.png",
    STOCK + "soccer_ball.mp4",
)
# オープニングの下地。**必ず実写のサッカー**（人が写っているもの）を指す。
# **`match_stadium.mp4` は使わない**（2026-09-18 ユーザー指摘「一瞬だけ背景が変わった」）。
# 中身は**ヴォルフスブルクのスタジアム**で、LEDの看板に VFL WOLFSBURG と読める。
# 9/17 に静止画の既定（`crest_still.png`）は直したが、**動くほうは「未決」のまま
# 置いていた**。伊藤涼太郎の回で、写真の出ない行だけ下地が見えて露見した。
# `stadium_night.mp4` は夜のスタジアムで、クラブ名が読めない
OPENING_BACKGROUND = STOCK + "stadium_night.mp4"
# **エンブレム主役の回だけ、下地を止める**（2026-09-15 指示
# 「下地が、動くのやめて」→「エンブレムの時の話ね」）。
# 写真のある回は画面が写真で持つが、**写真が無い回は実写の下地が
# 2分間まるまる動き続ける**。VARの回は2分6秒で140MBあった
# （写真のある回は25MB前後）。実写クリップから1コマ抜いた静止画なので、
# サッカーの画のままで止まる
# **名前を match_stadium にしてはいけない**（2026-09-15 に踏んだ）。
# render は書き出しのたびに moving_background() を通し、
# 「同じ名前で始まる .mp4 があれば差し替える」ので、
# **静止画にしたつもりが stock/match_stadium.mp4 に戻されていた**
# **クラブの実写を既定値にしない**（2026-09-17）。ここは長いあいだ
# `crest_still.png` で、その中身は**ヴォルフスブルクのスタジアムの実写**だった
# （LEDの看板に VFL WOLFSBURG と読める）。写真の無い回は全部これになるので、
# ホッフェンハイムの話もPSVの話もマンUの話も、同じドイツのスタジアムの前で
# 喋っていた。9/17 に台本4本を手で直したが、**既定値を直さなかったので
# その日のうちに新しい台本3本へ戻ってきた。**
# いまは模様の無い下地（studio.png）。**どのクラブのものでもない**
STILL_BACKGROUND = "assets/backgrounds/studio.png"

SPEAKERS = ("キャスター", "解説")
# 匿名の集まり。**画面に積む**ので、行ごとの引用カードは出さない
# （config の voice_crowd と同じ並び。ここは台本を組み立てる側の控え）
CROWD_VOICES = ("ネット民", "現地サポ", "海外のファン")


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
    # 行ごとの "short"（ショート専用）。空なら本編にも出す
    line_onlys: list = field(default_factory=list)
    # **画面に出している板と字幕が同じなら、字幕は出さない**（2026-09-20 指示
    # 「画面と字幕のが同じ場合は、字幕不要」）。基礎DATAの板の上に読み上げ文を
    # 重ねると、板のタイルが読めなくなっていた
    line_no_telops: list = field(default_factory=list)
    # **ショートの締めに回す反応**（2026-09-15 指示）。印の付いた反応だけを
    # ショートの最後に足す。付いていなければ今までどおり上から順に取る
    line_short_voices: list = field(default_factory=list)
    # **長い反応を行に分けたときの「続き」の印**（2026-09-26）。ショートが反応を
    # 行ごとに拾って前半だけで切れた（久保の回）。続きの行は前の行とひとかたまり
    line_conts: list = field(default_factory=list)
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
    # **シリーズ名を公開する題の後ろに付ける**（2026-09-23 指示「サブタイトルにプレミアリーグチーム紹介として」）。
    # 「題｜シリーズ名」の形。**読み上げの1行目には入れない**（ショートの16秒を食うだけ）。
    # 2026-09-21 の「②プレミア20クラブ紹介はいらない」は連番を頭に置く形の話で、こちらは末尾の名札
    series: str = ""
    # **この回に出てくる人の名前**（2026-09-10）。ハッシュタグに使う。
    # 参考4チャンネルは10〜34個貼っていて中身はほぼ選手名、こちらは7〜8個で
    # 選手名が1つも無い回があった。**本文から機械で拾わない**（辞書が無いので）
    people: list = field(default_factory=list)
    slot: str = ""
    theme_id: str = ""
    prefix: str = ""                 # 【速報】【朗報】【悲報】
    hook: str = ""                   # 冒頭のつかみ
    # **タイトルより前に読む一言**（2026-09-21 指示「最初にクラブを表す
    # 一言を述べてから始める」）。プレミア20クラブ紹介のために足した。
    # 書いていなければ、その行は出さない（今までどおりタイトルから始まる）
    lead: str = ""
    # **このあと話すことを、冒頭で見せる**（2026-09-23 指摘「最初の15秒で人が離れる
    # 可能性があるから、この後の流れを見せるのもあり」）。題を読む行に表を出す。
    # 取材メモの `theme.opening_card`（{type: table, ...}）に書く
    opening_card: dict | None = None
    # **最初の画面を指定する**（2026-09-23 指摘「最初の画面がデータではない」）。
    # オープニングの3行（一言・題・つかみ）にこの絵を当てる。板を指定したときは、
    # 「この動画で分かること」は板に焼き込んである（板の上にカードは重ねない決まり）
    opening_image: str = ""
    answer: str = ""                 # まとめで返す答え
    watch: str = ""                  # 次に何を見るか
    follow_up: bool = False
    # **ショートに反応を入れない回**（2026-09-14 指示「この話題において、
    # ショートにはネット民の声は不要」）。審判の声明や本人の発言が芯の回は、
    # 最後が匿名の感想だと締まらない
    short_voices: bool = True
    league: str = ""                 # england / spain / ... 何を追えていないかの集計に使う
    # **画面とタグに出すリーグ名の上書き**（2026-09-15）。`league` は集計の鍵なので
    # 国の単位までしか持てない。松木の回は `england` から「プレミアリーグ」が付いたが、
    # **サウサンプトンもブリストル・シティも2部**で、中身と食い違っていた
    league_name: str = ""            
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
    text = path.read_text(encoding="utf-8")
    try:
        raw = yaml.safe_load(text) or {}
    except yaml.YAMLError as err:
        # **行頭の `**` は YAML の別名（alias）扱いで落ちる**（2026-09-16 に3度踏んだ）。
        # `*` で始まる平文はエイリアス参照とみなされるので、引用符で囲む必要がある。
        # 素の ScannerError は「expected alphabetic or numeric character」としか言わず、
        # 強調のせいだと分からない
        bad = [n for n, line in enumerate(text.splitlines(), 1)
               if line.lstrip().startswith("- **")]
        if bad:
            rows = "、".join(str(n) for n in bad[:5])
            raise ResearchError(
                f"{path} の {rows} 行目が `- **` で始まっています。"
                "**行頭の強調は引用符で囲んでください**"
                '（例: - "**4試合**になりました。"）。YAML は `*` を別名の印とみなします'
            ) from err
        raise ResearchError(f"{path} を読めません: {err}") from err
    return build_notes(raw)


def build_notes(raw: dict) -> Notes:
    theme = dict(raw.get("theme") or {})
    if not theme:
        raise ResearchError(
            "theme がありません。1本＝1テーマなので、扱うテーマを1つ決めてください"
        )

    sections: list[Section] = []
    # **ショートに使うのは main の節だけ**。ほかの節の `short_only` は本編からも
    # 落ちるので、**どこにも読まれない**（2026-09-22 に7本すべてで踏んだ。
    # 「ベストイレブンに選ばれた」という前置きが、ショートに一度も出なかった）
    has_main = any(isinstance(e, dict) and e.get("main")
                   for e in (raw.get("sections") or []))
    for index, entry in enumerate(raw.get("sections") or [], start=1):
        if has_main and isinstance(entry, dict) and not entry.get("main"):
            for item in entry.get("say") or []:
                if isinstance(item, dict) and item.get("short_only"):
                    raise ResearchError(
                        f"{entry.get('id') or index}: short_only の行が main でない節にあります"
                        f"（{str(item.get('text', ''))[:20]}）。ショートは main の節しか使わないので、"
                        "この行はどこにも読まれません。main の節の頭に移してください")
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
        onlys: list[str] = []
        picks: list[bool] = []
        conts: list[bool] = []
        mutes: list[bool] = []
        for item in raw_lines:
            if isinstance(item, dict):
                # **知らない鍵は黙って捨てない**（2026-09-22）。`short_only: true` を
                # `only: short` と書いた5本で、ショート専用の前置きが本編にも入っていた。
                # 文中の「: 」で YAML が鍵に割れた行も、ここで止まる
                unknown = sorted(str(k) for k in item if k not in LINE_KEYS)
                if unknown:
                    raise ResearchError(
                        f"{entry.get('id') or index}: 行に知らない鍵があります（{unknown[0][:30]}）。"
                        f"使えるのは {'・'.join(sorted(LINE_KEYS))}。"
                        "文に「: 」が入るなら text を引用符で囲んでください")
                lines.append(str(item.get("text", "")).strip())
                voices.append(str(item.get("voice", "")).strip())
                telops.append(str(item.get("telop", "")).strip())
                cards.append(item.get("card"))
                images.append(str(item.get("image", "")).strip())
                # **ショートにだけ出す行**（2026-09-14 指示「ショートでも、
                # 試合の概要を最初に説明して」）。ショートは節を切り出して
                # 単体で出すので前置きが要るが、本編に残すと言い直しになる
                onlys.append("short" if item.get("short_only") else "")
                # **ショートの締めに回す反応**（2026-09-15 指示）。
                # 上から順に取ると、1件目が見出しの言い直しになる回がある
                picks.append(bool(item.get("short_voice")))
                mutes.append(bool(item.get("no_telop")))
                conts.append(bool(item.get("cont")))
            else:
                lines.append(str(item).strip())
                voices.append("")
                telops.append("")
                cards.append(None)
                images.append("")
                onlys.append("")
                picks.append(False)
                mutes.append(False)
                conts.append(False)
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
                line_onlys=[onlys[i] for i in keep],
                line_short_voices=[picks[i] for i in keep],
                line_conts=[conts[i] for i in keep],
                line_no_telops=[mutes[i] for i in keep],
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
        series=str(raw.get("series", "")).strip(),
        people=[str(x).strip() for x in (raw.get("people") or []) if str(x).strip()],
        title=str(theme.get("title", "")).strip(),
        theme_id=str(theme.get("id", "")).strip(),
        question=str(theme.get("question", "")).strip(),
        prefix=str(theme.get("prefix") or "").strip().strip("【】"),
        hook=str(theme.get("hook") or "").strip(),
        lead=str(theme.get("lead") or "").strip(),
        opening_card=(dict(theme["opening_card"]) if theme.get("opening_card") else None),
        opening_image=str(theme.get("opening_image") or "").strip(),
        thumbnail=dict(raw.get("thumbnail") or {}),
        answer=str(raw.get("answer") or "").strip(),
        watch=str(raw.get("watch") or "").strip(),
        follow_up=bool(raw.get("follow_up", False)),
        short_voices=raw.get("short_voices", True) is not False,
        league=str(theme.get("league", "")).strip().lower(),
        league_name=str(theme.get("league_name") or "").strip(),
        kind=str(theme.get("kind", "transfer")).strip().lower() or "transfer",
        topic=str(theme.get("topic", "")).strip(),
        sections=sections,
    )


def verify(notes: Notes, plan: Plan) -> list[str]:
    """確度と構成の条件を満たしているか調べ、問題を文章で返す。空なら合格。"""
    policy = getattr(plan, "policy", {}) or {}
    problems: list[str] = []
    # **知らないリーグの鍵で止める**（2026-09-15）。`league_name` が鍵そのものを
    # 返していたので、`league: premier`（正しくは `england`）が
    # **そのまま `premier` というタグ**になって公開の手前まで来ていた
    if notes.league and not plan.league(notes.league):
        known = "／".join(sorted(getattr(plan, "leagues", {}) or {}))
        problems.append(
            f"league の『{notes.league}』は知らない鍵です。書けるのは {known} です")

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
    problems += _check_quote_timing(notes)
    problems += _check_thumbnail_resolution(notes)
    problems += _check_line_images_wide(notes)
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


# 1行ぶんの辞書に書いてよい鍵
LINE_KEYS = frozenset({"text", "voice", "telop", "card", "image",
                       "short_only", "short_voice", "no_telop", "cont"})


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
    if not card:
        return problems
    # **type の名前そのものを見ていなかった**（2026-09-18 に踏んだ）。
    # `type: bullets` と書いた取材メモが draft を通り、**音声を合成し終えた
    # あとの render** で「カードの type は … のいずれか」で落ちた。
    # 正しくは `points`。この関数は「落ちる条件を先に見る」ためにあるのに、
    # 中身の欄だけ見て、種類の名前を見ていなかった
    from .cards import CARD_TYPES
    if kind not in CARD_TYPES:
        near = {"bullets": "points", "list": "points", "箇条書き": "points",
                "bar": "bars", "graph": "bars", "quotes": "quote"}.get(kind, "")
        problems.append(
            f"{section.id}: カードの type『{kind}』は知りません。"
            f"書けるのは {'／'.join(CARD_TYPES)} です"
            + (f"（`{near}` のことですか）" if near else ""))
        return problems
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
        # **形まで見る**（2026-09-22）。`- ["佐野海舟", 5000]` と書いた2本が `draft` を通り、
        # 書き出しの途中で ValueError で落ちた。items は `{label: …, value: …}` の並び
        elif card.get("type") == "bars":
            for item in card.get("items") or []:
                if not (isinstance(item, dict) and "label" in item and "value" in item):
                    problems.append(f"{section.id}: bars の items は "
                                    f"{{label: …, value: …}} で書いてください（{str(item)[:30]}）")
                    break
        problems += _check_bar_units(section, card)
    return problems


# 棒の名前が自分の単位を抱えている書き方（「使った額（億円）」など）。
# **括弧で単位を書いた時点で、その棒だけ別の単位だと言っている**
_LABEL_PAREN = re.compile(r"[（(]([^（()）]{1,8})[)）]\s*$")
# **括弧の中身が単位とは限らない。**「バルコラ（リヴァプール）」のように
# クラブ名を入れる書き方があるので、単位の形をしたものだけ拾う。
# 前に付いてよいのは数字・英字・億万千百だけ（「今回」を単位と読まないため）
_UNIT_LIKE = re.compile(
    r"^[0-9A-Za-z/％%億万千百]*"
    r"(円|点|回|本|人|秒|分|試合|位|歳|勝|敗|ポンド|ユーロ|ドル|km/h|km|kg|cm|％|%)$")


def _unit_in(label: str) -> str:
    """名前の末尾の括弧から単位を取り出す。単位に見えなければ空。"""
    found = _LABEL_PAREN.search(label.strip())
    if not found:
        return ""
    inner = found.group(1).strip()
    return inner if _UNIT_LIKE.match(inner) else ""


def _check_bar_units(section, card: dict) -> list[str]:
    """**単位の違う値を棒グラフに並べない。**

    同じ軸に置くと `unit` が全部の棒に付く。2026-09-10 に
    「総額（百万ユーロ）100」と「分ける回数 3」を並べて、
    どちらも「単位ちがい」と表示された。そのときは台本だけ直して
    **検査を足さなかったので、9/14 に同じことが起きた**
    （「使った額（億円）780点」「取った点 0点」）。
    金額と得点は比べるものではないので、表にする。
    """
    units = {str(card.get("unit") or "").strip()} - {""}
    for item in card.get("items") or []:
        label = str((item or {}).get("label", "") if isinstance(item, dict) else item)
        found = _unit_in(label)
        if found:
            units.add(found)
    if len(units) > 1:
        return [f"{section.id}: 単位の違う値を棒グラフに並べています"
                f"（{' / '.join(sorted(units))}）。"
                "同じ軸に置くと unit が全部の棒に付きます。table にしてください"]
    return []


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


# **読み上げる反応は10〜20件**（2026-09-07 ユーザー決定）。
# 伸びている3チャンネルの実測は他人の声が尺の58%・19.2件で、こちらは14%・2.2件だった
REACTION_MIN = 10


def advise(notes: Notes, plan: Plan | None = None, now=None) -> list[str]:
    """止めるほどではないが直したほうがよい点。draft のときに出す。"""
    notes_warnings: list[str] = []

    # **件数を数えていなかった**（2026-09-18 に気づいた）。
    # 「10〜20件」と決めてあるのに、機械は**1件でもあれば通していた**。
    # サンバの回は6件、ヴァツケの回は日本語0件のまま書き出せた。
    # **数が少ない回はある**（記事が1本しか出ていない題材など）ので**止めない**。
    # 気づかずに出ることだけを防ぐ
    voices = sum(1 for sec in notes.sections for v in sec.voices
                 if str(v or "").strip() in ("ネット民", "現地サポ", "海外のファン"))
    if 0 < voices < REACTION_MIN:
        notes_warnings.append(
            f"ネットの声が{voices}件です（決まりは10〜20件）。"
            "少ないまま出すなら、それでよいか確かめてください")

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
    # **`draft` と `review` で物差しが違っていた**（2026-09-22 に判明）。
    # こちらは体言止めの一覧（TITLE_NOUN_TAILS）を見ていなかったので、
    # `review` が通す題を `draft` が弾いていた。**同じ一覧を見る**
    # 一覧を共有しても、**判定の枝（「は」止め・動詞止め）がずれた**ので、
    # 同じ関数そのものを呼ぶ
    from types import SimpleNamespace

    from .review import check_title_hook

    title = notes.video_title
    if check_title_hook(SimpleNamespace(title=title)).ok:
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
# **数字が並ぶ節には、画面にも表を出す**（2026-09-15）。
# 9/16 に出した本編5本のうち4本は、110秒のあいだ画面が2つしかなかった
# （下地の切替1回、カード0回）。手元に写真106枚・エンブレム40枚・
# カードの仕組みがあるのに、どれも使っていなかった。
# 参考チャンネルは5〜10秒ごとに絵が変わる。**素材ではなく使い方の差。**
CARD_NUMBER_LINES = 3    # この本数以上の行に数字があれば、表を出したい
VOLUME_SOURCES = 5       # 出典の本数
VOLUME_OUTLETS = 3       # 媒体の数


def _bare_text(text: str) -> str:
    """比べるための素の文。句読点と記号を落とす。"""
    return re.sub(r"[。、．，\s　？?！!「」『』*]", "", str(text or ""))


# 誰かの言葉が出るまでの上限（秒）。直近14日・196本の実測（2026-09-22）:
# ショートは16秒までに出る60本が維持46.6%、遅い59本が39.8%。
# 本編は46秒までに出る31本が40.9%、遅い30本が31.3%。
# 9/13 に測ったときは「知らせるだけ」にしたが、その日の7本のうち
# ショートで16秒に収まったのは1本だけだった。**知らせても直さないので止める**
SHORT_QUOTE_BY = 16.0
MAIN_QUOTE_BY = 46.0


def _seconds_of(text: str) -> float:
    """読み上げの見積り。script_model と同じ式。"""
    from .script_model import BASE_SECONDS, MIN_SECONDS, SECONDS_PER_CHAR

    return max(MIN_SECONDS, BASE_SECONDS + len(_bare_text(text)) * SECONDS_PER_CHAR)


def _check_quote_timing(notes: Notes) -> list[str]:
    """誰かの言葉が早く出るか。本編は46秒、ショートは16秒まで。

    紹介ものなど、他人の声を1つも持たない回は見ない。
    ショートは山場（main）の節を切り出すので、その節の中で数える。
    山場に言葉が遅くても、反応（ネット民など）があれば `shorts` が
    1件を冒頭に上げるので通す。
    """
    has_voice = any(v and v not in SPEAKERS for s in notes.sections for v in s.voices)
    if not has_voice:
        return []
    problems: list[str] = []
    opening = _seconds_of(notes.title) + (_seconds_of(notes.hook) if notes.hook else 0.0)

    elapsed = opening
    found = False
    for section in notes.sections:
        for number, sentence in enumerate(section.say):
            only = section.line_onlys[number] if number < len(section.line_onlys) else ""
            if only == "short":
                continue
            voice = section.voices[number] if number < len(section.voices) else ""
            if voice and voice not in SPEAKERS:
                found = True
                break
            elapsed += _seconds_of(sentence)
        if found:
            break
    if found and elapsed > MAIN_QUOTE_BY:
        problems.append(
            f"本編で誰かの言葉が出るのが{elapsed:.0f}秒目です（{MAIN_QUOTE_BY:.0f}秒まで）。"
            "本人の発言か反応を、前のほうの節に1つ置いてください")

    main = next((s for s in notes.sections if s.main), None)
    crowd = any(v and v not in SPEAKERS and v not in notes.people
                for s in notes.sections for v in s.voices)
    if main is not None and not crowd:
        elapsed = _seconds_of(notes.title)
        found = False
        for number, sentence in enumerate(main.say):
            voice = main.voices[number] if number < len(main.voices) else ""
            if voice and voice not in SPEAKERS:
                found = True
                break
            elapsed += _seconds_of(sentence)
        if found and elapsed > SHORT_QUOTE_BY:
            problems.append(
                f"ショートで誰かの言葉が出るのが{elapsed:.0f}秒目です（{SHORT_QUOTE_BY:.0f}秒まで）。"
                "山場の前置きは1行にして、その直後に言葉を置いてください")
    return problems


# 写真をこれ以上引き伸ばすとぼやける（2026-09-22 ユーザー「サムネが左がぼやけてる」）。
# 400×530の写真を1280×720の左3分の1に伸ばしていた。9/17 の「画面の左がぼやける」も同じ
THUMB_STRETCH_MAX = 1.6
THUMB_SIZE = (1280, 720)


def _advise_wide_photo(notes: Notes) -> list[str]:
    """**本文に敷く写真は横に広いものを使う**（2026-09-25 指摘）。

    縦の写真は右に立てて左にべた塗りの面が残る。ユーザーの「左がグレー」は
    **色の話ではなく、その面があること**への指摘だった（私は色を直して読み違えた）。
    1枚のときは横長を探す。縦しか無ければ2枚並べて1枚にする（`tools/pairphoto.py`）。
    2枚並べた回（`photos`）は、冒頭の絵が1枚目だけになるので、**並べた1枚を
    `photo` に置く**（`photos` はサムネ用で、本文と冒頭には1枚目しか届かない）。
    """
    thumb = notes.thumbnail or {}
    photos = [str(x) for x in (thumb.get("photos") or []) if str(x).strip()]
    single = str(thumb.get("photo") or "").strip()
    body = single or (photos[0] if photos else "")
    if not body:
        return []
    file = Path(body)
    if not file.exists():
        return []
    try:
        from PIL import Image

        with Image.open(file) as im:
            w, h = im.size
    except Exception:
        return []
    if w >= h * 0.95:
        return []
    hint = ("`tools/pairphoto.py` で2枚を横に並べた1枚を作り、`thumbnail.photo` に置いてください"
            if photos else
            "記事の写真（`tools/articlephoto.py`）か Commons の横長のファイル（`portrait --file`）を探すか、"
            "`tools/pairphoto.py` で2枚並べてください")
    return [f"本文と冒頭に敷く写真 {file.name} が縦長（{w}×{h}）です。右に立てると**左に面が残ります**。"
            f"{hint}（2026-09-25 指摘「ちゃんと横に広い写真を使う」）"]


def _check_line_images_wide(notes: Notes) -> list[str]:
    """**行に差し込む写真も横に広いものにする**（2026-09-25 指摘「久保とかの写真が映るとき、左がグレー」）。

    語る人の写真を行の `image:` に置いたら、縦の写真がそのまま右に立って、
    サムネで直したのと同じ「左に面」が本文に出た。**同じ日に同じ指摘を2回受けた。**
    語る人（左）＋主役（右）の2枚並べ（`tools/pairphoto.py`）にする。縦長なら止める。
    """
    problems: list[str] = []
    seen: set[str] = set()
    for section in notes.sections:
        # **表のある節は見ない**（2026-09-26 ラ・リーガ版の見本）。表は画面の左に出て、
        # 写真は右に並ぶ（名選手・監督・逸話の節。プレミア版ボーンマスで見せて通った形）。
        # 左に面は残らない。止めるべきは、表の無い節で縦の写真が1枚だけ立つ場合
        if section.card and str(section.card.get("type")) == "table":
            continue
        for image in (section.line_images or []):
            path = str(image or "").strip()
            if not path or path in seen:
                continue
            seen.add(path)
            file = Path(path)
            if not file.exists():
                continue
            try:
                from PIL import Image

                with Image.open(file) as im:
                    w, h = im.size
            except Exception:
                continue
            if w < h * 0.95:
                problems.append(
                    f"節『{section.heading}』の行に差し込む写真 {file.name} が縦長（{w}×{h}）です。"
                    "右に立てると**左に面が残ります**。`tools/pairphoto.py` で「語る人（左）＋主役（右）」の"
                    "2枚並べを作って、その1枚を置いてください（2026-09-25 指摘「左がグレー」）")
    return problems


TABLE_ROWS_WITH_LONG_LINE = 4     # これより多い行の表と
LONG_TELOP_CHARS = 40             # これより長い1行（テロップが3行になる）を同じ節に置かない


def _advise_card_telop_overlap(notes: Notes) -> list[str]:
    """**表とテロップが重ならないか**（2026-09-25、ラフィーニャの山場で表の下半分が隠れた）。

    表は画面の上から伸び、テロップは下から上へ伸びる。行の多い表と3行になるテロップが
    同じ節にあると、真ん中でぶつかる。review は画面を見ないので通っていた（4コマで見つけた）。
    直し方は、長い行を2つに割るか、表の行を減らす。
    """
    hints: list[str] = []
    for section in notes.sections:
        card = section.card or {}
        if str(card.get("type", "")).lower() != "table":
            continue
        rows = len(card.get("rows") or [])
        if rows < TABLE_ROWS_WITH_LONG_LINE:
            continue
        for number, sentence in enumerate(section.say):
            only = section.line_onlys[number] if number < len(section.line_onlys) else ""
            if only == "short":
                continue
            text = _bare_text(sentence if isinstance(sentence, str) else str((sentence or {}).get("text", "")))
            if len(text) > LONG_TELOP_CHARS:
                hints.append(
                    f"節『{section.heading}』: 表が{rows}行あり、{len(text)}字の行（『{text[:16]}…』）の"
                    "テロップが3行になって表の下にかかります。行を2つに割るか、表を減らしてください"
                    "（2026-09-25 ラフィーニャ）")
                break
    return hints


def _advise_offtopic_section(notes: Notes) -> list[str]:
    """**主役の名前が一度も出ない節は、題に答えていない疑いがある**（2026-09-25）。

    同じ日に4本で、題に答えない節を落とすよう言われた。松木「抑えられなかった側」
    （相手紙の評価）、佐野「33年前の兄弟」（歴史のおさらい）、シャビ「三世代目の
    デビュー」（脇役の紹介）、ラフィーニャ「ロドリの言葉」（別の話題）。
    機械で取れるのは「主役の名前が節に出てこない」ことだけなので、知らせるだけにする。
    落とす判断は「この節を落としても題の答えは変わらないか」で、人がする。
    """
    people = [str(x).strip() for x in (notes.people or []) if str(x).strip()]
    if not people:
        return []
    lead = people[0]
    forms = {lead, lead.replace("・", ""), lead.split("・")[0], lead.split("・")[-1]}
    if len(lead) >= 4 and "・" not in lead:
        forms.add(lead[:2])          # 「久保建英」→「久保」
    forms = {f for f in forms if len(f) >= 2}
    hints: list[str] = []
    for section in notes.sections:
        card = section.card or {}
        if str(card.get("type", "")).lower() == "reactions" or section.heading == "ネットの反応":
            continue
        # 本人が語る節は、地の文に名前が無くても主役の節（`voices` に本人がいる）
        text = "".join(section.say or []) + "".join(str(v) for v in (section.voices or []))
        if any(f in text for f in forms):
            continue
        hints.append(
            f"節『{section.heading}』に主役（{lead}）の名前が一度も出ません。"
            "題に答えない節（相手側の評価・歴史のおさらい・脇役の紹介・別の話題）なら落としてください。"
            "**この節を落としても題の答えが変わらないなら、要らない節です**（2026-09-25 に4本で指摘）")
    return hints


def _check_thumbnail_resolution(notes: Notes) -> list[str]:
    thumb = notes.thumbnail or {}
    photos = [str(x) for x in (thumb.get("photos") or []) if str(x).strip()]
    single = str(thumb.get("photo") or "").strip()
    targets = [(p, len(photos)) for p in photos] or ([(single, 1)] if single else [])
    problems: list[str] = []
    for path, tiles in targets:
        file = Path(path)
        if not file.exists():
            continue
        try:
            from PIL import Image

            with Image.open(file) as im:
                w, h = im.size
        except Exception:
            continue
        if tiles > 1:
            need = max((THUMB_SIZE[0] / tiles) / w, THUMB_SIZE[1] / h)
        elif h > w * 1.1:
            need = THUMB_SIZE[1] / h          # 縦長は右に立てるので高さだけ
        else:
            need = max(THUMB_SIZE[0] / w, THUMB_SIZE[1] / h)
        if need > THUMB_STRETCH_MAX:
            problems.append(
                f"サムネの写真 {file.name} は {w}×{h} で、{need:.1f}倍に引き伸ばすとぼやけます"
                f"（{THUMB_STRETCH_MAX}倍まで）。大きい写真を探すか、並べる枚数を減らしてください")
    return problems


# 読み上げ1行の長さの目安。超えると合成音声で一息に聞き取れない（2026-09-22、読み手の指摘）
LINE_MAX = 48
# 勝敗の言葉。スコアの行にこれが無いと「2対1」だけでどちらが勝ったか分からない
RESULT_WORDS = ("勝", "負", "敗", "引き分け", "ドロー", "下し", "破", "退け", "制し", "屈し")


def _advise_ear(notes: Notes) -> list[str]:
    """**耳で分からない言い回し**（2026-09-22、流れの点検で20本中十数本に出た型）。

    - スコアだけで勝敗を言わない（「アウェーで2対1。」）
    - 1行が長すぎる（48字超。合成音声は一息に読むので聞き取れない）
    - 語りの語尾が「です」で3行続く（アナウンスに聞こえて離脱する）
    - 読み上げにアルファベットが残る（UEFA・CL は読めない。FA・PK の2文字は通す）
    反応・引用（他人の文）は見ない。こちらが書いた地の文だけ。
    """
    hints: list[str] = []
    for section in notes.sections:
        run = 0
        for number, sentence in enumerate(section.say):
            voice = section.voices[number] if number < len(section.voices) else ""
            if voice and voice not in SPEAKERS:
                run = 0
                continue
            text = sentence if isinstance(sentence, str) else str((sentence or {}).get("text", ""))
            bare = _bare_text(text)
            where = f"節『{section.heading}』"
            if re.search(r"\d+対\d+", text) and not any(w in text for w in RESULT_WORDS):
                hints.append(f"{where}: スコアだけで勝敗を言っていません（『{text[:24]}』）。「2対1の勝ち」のように言ってください")
            if len(bare) > LINE_MAX:
                hints.append(f"{where}: 1行が{len(bare)}字あります（{LINE_MAX}字まで）。2つに割ってください（『{text[:20]}…』）")
            if re.search(r"[A-Za-z]{3,}", text):
                hints.append(f"{where}: 読み上げにアルファベットが残っています（『{text[:24]}』）。カタカナにしてください")
            run = run + 1 if bare.endswith("です") else 0
            if run == 3:
                hints.append(f"{where}: 語尾の「です」が3行続いています（『{text[:20]}…』）。言い切りや体言止めを混ぜてください")
    return hints


def _advise_readings(notes: Notes) -> list[str]:
    """**漢字の人名は読みの辞書に無いと誤読される**（2026-09-22）。

    `people:` の漢字だけの名前が config/reading.yaml に無ければ知らせる。
    VOICEVOX は日本人選手の名前を半分近く読み違えていた（実測）。
    """
    from .reading import load_dictionary

    known = load_dictionary()
    hints: list[str] = []
    for person in notes.people or []:
        name = str(person).strip()
        if re.fullmatch(r"[一-龥々]{2,6}", name) and name not in known:
            hints.append(f"『{name}』の読みが config/reading.yaml にありません。"
                         "合成音声が読み違えます。読みを足してください")
    return hints


def _advise_group_thumbnail(notes: Notes) -> list[str]:
    """**群れの回は、サムネも並べる**（2026-09-22 ユーザー「一人の写真ではなくて
    取り上げた選手を並べて」。9/17「群れの回は群れを主語にする」と同じ型）。

    タイトルに `people` の誰の名前も出ていないなら、その回の主語は群れ。
    それなのに写真が1枚なら知らせる。
    """
    people = [str(p) for p in (notes.people or []) if str(p).strip()]
    if len(people) < 2:
        return []
    title = str(notes.title or "")
    if any(name in title for name in people):
        return []
    thumb = notes.thumbnail or {}
    photos = [x for x in (thumb.get("photos") or []) if str(x).strip()]
    if len(photos) >= 2:
        return []
    return [f"群れの回（{'・'.join(people[:4])}）なのに、サムネの写真が1枚です。"
            "thumbnail.photos に取り上げた人を並べてください（5枚まで）"]


def _advise_thumbnail_name(notes: Notes) -> list[str]:
    """**サムネの言葉に、クラブ名か人名を入れる**（2026-09-25 指示）。

    一覧に並ぶのは題ではなく絵なので、絵の中に名前が無いと、
    誰の話か分からないまま流れる。タイトルの頭に名前を置く決まり
    （2026-09-07）と同じ筋で、そちらは検索、こちらは一覧に効く。
    エンブレムは絵なので、**読める文字として**入っているかを見る。
    """
    thumb = notes.thumbnail or {}
    words = " ".join(str(thumb.get(k) or "") for k in ("line1", "line2"))
    words += " " + " ".join(str(x) for x in (thumb.get("points") or []))
    if not words.strip():
        return []
    names = [str(x).strip() for x in (notes.people or []) if str(x).strip()]
    names += [str(notes.topic or "").strip()]
    names += [str(x).strip() for x in (thumb.get("crests") or [])]
    names += [str(x).strip() for x in (thumb.get("crest_main") or [])]
    for name in [n for n in names if n]:
        # 「マンチェスター・ユナイテッド」を「マンU」と書くので、頭の2文字でも当てる
        # 「アーリング・ハーランド」を「ハーランド」と書くので、後ろの語でも当てる
        for form in {name, name.replace("・", ""), name.split("・")[0], name.split("・")[-1], name[:3], name[:2]}:
            if len(form) >= 2 and form in words:
                return []
    return ["サムネの文字に、クラブ名も人名も入っていません"
            f"（『{str(thumb.get('line1') or '')}』『{str(thumb.get('line2') or '')}』）。"
            "**一覧に並ぶのは絵なので、絵の中に名前が要ります**（2026-09-25 指示）"]


def _advise_thumbnail_promise(notes: Notes) -> list[str]:
    """**サムネが、本編で言っていないことを約束していないか**（2026-09-21）。

    プレミア20クラブ紹介で4本見つかった。旧台本から節を落としたのに、
    サムネの文字だけが残っていて、**その話を一度もしない動画**になっていた
    （アーセナル「1919年、票で決まった」／チェルシー「史上最も荒れた決勝」／
    ブレントフォード「酒場の投票で決まった」／エヴァートン「出た家から宿敵が生まれた」）。

    **節を落としたら、その節を指している言葉が他に無いか必ず見る**（CLAUDE.md）の、
    サムネ側。手がかり（漢字・カタカナ・数字のかたまり）が**1つも読み上げに
    出てこない**ときだけ知らせる。言い回しは変わるので、厳しくは見ない。
    """
    import re as _re

    thumbnail = notes.thumbnail or {}
    # **題も比べる相手に入れる**（2026-09-21）。サムネの2行目はクラブ名や選手名の
    # ことが多く、読み上げの本文には出てこない。それを「約束を破っている」と
    # 数えると、20本中8本で鳴った（全部この形だった）
    body = _bare_text(" ".join(
        text for scene in notes.sections for text in scene.say))
    # 題・問い・一言・つかみも**比べる相手**に入れる（サムネの2行目はクラブ名や
    # 選手名のことが多く、節の本文には出てこない）。ただし**判じるかどうかは
    # 節の中身で決める**。雛形の段階で鳴らしても直しようがない
    said = body + _bare_text(" ".join(
        [notes.title, notes.question, notes.lead, notes.hook]))
    # **比べる相手が無いときは黙る。**節がまだ無い雛形や、読み上げに漢字・カタカナが
    # 1つも無い作り物では、「出てこない」と言っても意味がない
    if not _re.search(r"[一-龯ァ-ヶー]{2,}|\d+", body):
        return []
    hints: list[str] = []
    for which in ("line1", "line2"):
        text = str(thumbnail.get(which) or "")
        # 伏せ字（●●）を含む行は、隠すのが目的なので見ない
        if not text or "●" in text:
            continue
        clues = [c for c in _re.findall(r"[一-龯ァ-ヶー]{2,}|\d+", text) if len(c) >= 2]
        if not clues:
            continue

        def found(clue: str) -> bool:
            """**言い回しは変わる。**3字以上のかたまりは、2字が重なれば通す。

            サムネ「6回優勝が、3部にいた」に対して読み上げは
            「1部で6回も優勝しているクラブが、2018年には3部にいました」。
            丸ごとでは当たらないが、「優勝」が重なっていれば同じ話をしている
            """
            if clue in said:
                return True
            # **数字は丸ごと一致だけ。**2桁ずつで見ると「1919年」が
            # 「2026年5月19日」の "19" に当たって通ってしまった（2026-09-21 実測）
            if clue.isdigit():
                return False
            return len(clue) >= 3 and any(clue[i:i + 2] in said
                                          for i in range(len(clue) - 1))

        if not any(found(clue) for clue in clues):
            hints.append(f"サムネの {which}『{text}』は、読み上げのどこにも出てきません。"
                         "**その話をしない動画**になっていないか見てください"
                         "（節を落としたときに、サムネの文字だけ残ることがあります）")
    return hints


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
    # **丸ごと同じでなくても言い直しになる**（2026-09-14 指摘
    # 「送り出されたのはどんな場面でしたかが2回繰り返されてる」）。
    # 題が「…送り出されたのはどんな場面か」、つかみが「…送り出されたのは、
    # どんな場面だったのか」で、同じでないので素通りしていた
    shared = _longest_common(_bare_text(notes.hook), _bare_text(notes.question))
    if len(shared) >= HOOK_ECHO_MIN:
        return [f"theme.hook が問いを言い直しています（『{shared}』が両方にあります）。"
                "1行目で題を読んだ直後に同じことを言うと、2回繰り返して聞こえます。"
                "別の事実を書くか、空のままにしてください"]
    return []


# つかみと問いに、これだけ続けて同じ字が入っていたら言い直しとみなす
HOOK_ECHO_MIN = 6


def _longest_common(left: str, right: str) -> str:
    """いちばん長く続けて重なっている部分を返す。"""
    if not left or not right:
        return ""
    best = ""
    # 題材の文は長くても100字ほどなので、素直に総当たりで足りる
    for start in range(len(left)):
        for end in range(start + len(best) + 1, len(left) + 1):
            chunk = left[start:end]
            if chunk in right:
                best = chunk
            else:
                break
    return best


# 同じ言い回しが2か所に出てよい長さ。これを超えたら言い直し
# **12字→8字**（2026-09-22）。「7試合で12ゴール」（シメオネの引用と確認の節）や
# 「9月18日時点」（日本代表の1節目と山場）が12字に届かず素通りし、
# ユーザーの「内容の重複とかないか確認して」で手で数えて見つけた
REPEAT_MIN = 8
# 同じ数字を別の節で読む（2026-09-22）。数字＋単位で見る。
# 年号（2025年）は節をまたいで出て当たり前なので除く
NUMBER_TOKEN = re.compile(r"\d[\d,.]*(?:万|億|点|ゴール|試合|本|人|回|位|歳|分|秒|月|日|戦|失点|得点|勝|敗|ユーロ|ポンド|円|%)")
# **ショートの中の重複は、もっと短くても効く**（2026-09-15）。
# 本編で12字としたのは節と節が数十秒離れているからで、ショートでは
# **タイトルの次の行**として2秒後に読まれる。遠藤の回の重なりは
# 「4試合続けて出番なし」の10字で、12字では届かなかった
SHORT_REPEAT_MIN = 8


def _meaningful(shared: str, notes: Notes) -> str:
    """重なりのうち、意味を持つ部分。

    人名（`people:`）は節をまたいで出て当たり前なので落とす。
    """
    out = shared
    for name in notes.people or []:
        out = out.replace(str(name), "")
    # **固有名詞の一致は言い直しではない**（2026-09-22）。8字に下げたら
    # 「ヨーロッパリーグ」「ファルマー・スタジアム」「1部リーグの優勝」で鳴った。
    # 助詞を除いてひらがなが残らない重なりは、名詞が同じだけ。
    # 動詞や形容詞（「負けずに優勝し」）が含まれていて初めて言い直し
    if not re.search(r"[ぁ-ん]", re.sub(r"[のとやからまでにはがをでも]", "", out)):
        return ""
    return out.strip("はがをにでとのも")


def _advise_repeats(notes: Notes) -> list[str]:
    """節をまたいで同じことを言っていないか（2026-09-14 指摘「話の重複が多い」）。

    **節ごとに書くと、どの節も自分で名乗り直す。**「マインツ対フランクフルト」
    「鈴木唯人は3試合続けての先発でした」のように、前の節で言い終えた一文が
    そのまま二度読まれていた。引きの一言が後の節で繰り返される型も多い。

    人の目では見つからない。台本を通しで読み返すのは最後の1回だけだからで、
    そのときには既に「知っている話」になっていて引っかからない。
    """
    said: list[tuple[str, str]] = []
    # **タイトルも読み上げの1行目**（2026-09-15 指摘「本編で重複がある」）。
    # 引きだけ見ていたので、「遠藤航が4試合続けて出番なし」（題）と
    # 「遠藤航が、リーグ戦で4試合続けて出番がありません」（節1）が
    # **数秒の間に二度読まれて**いた。題は比べる相手に入っていなかった
    said.append(("タイトル", _bare_text(notes.title)))
    if notes.hook:
        said.append(("引き", _bare_text(notes.hook)))
    for section in notes.sections:
        for number, sentence in enumerate(section.say):
            # **ショート専用の前置きは見ない**（2026-09-14）。本編には出ないので、
            # 前の節と同じことを言っていて当たり前。ここで止めると
            # 「ショートでも試合の概要を最初に説明して」が書けなくなる
            only = (section.line_onlys[number]
                    if number < len(section.line_onlys) else "")
            if only == "short":
                continue
            # **反応は人の書いた文なので直さない。**こちらが書いた地の文だけ見る。
            # **そう書いてあるのに、実装が見ていなかった**（2026-09-15）。
            # 松木の回で「平河悠との日本人対決」がタイトルと重なると鳴ったが、
            # それは書き込みの原文で、**こちらが直してはいけない文**だった
            voice = (section.voices[number]
                     if number < len(section.voices) else "")
            if voice and voice not in SPEAKERS:
                continue
            text = sentence if isinstance(sentence, str) else str(
                (sentence or {}).get("text", ""))
            said.append((section.id, _bare_text(text)))

    problems: list[str] = []
    seen: set[str] = set()
    opening = ("タイトル", "引き")
    for index, (where, text) in enumerate(said):
        for other_where, other in said[:index]:
            shared = _longest_common(text, other)
            # **冒頭とのかぶりは、もっと短くても効く**（2026-09-15）。
            # 12字は節と節が数十秒離れている前提の数字で、タイトルと第1節は
            # 数秒しか離れていない。遠藤の重なりは「4試合続けて出番」の8字と
            # 「チャンピオンズリーグの」の11字で、どちらも12字に届かなかった
            limit = SHORT_REPEAT_MIN if other_where in opening else REPEAT_MIN
            # 同じ節の中の対句（「4000万から5000万へ」「2000万から3000万へ」）は
            # 言い直しではない。節の中だけは元の12字で見る
            if other_where == where:
                limit = max(limit, 12)
            shared = _meaningful(shared, notes)
            if len(shared) >= limit and shared not in seen:
                seen.add(shared)
                problems.append(
                    f"{other_where} と {where} で同じことを言っています"
                    f"（『{shared}』）。あとの節から落とすか、言い換えてください")
    # **同じ数字を別の節でもう一度読んでいないか**（2026-09-22）。
    # シメオネの回で、本人の引用「7試合で12ゴール」を次の節で
    # 「ラフィーニャは7試合で12ゴール」と読み直していた。ユーザー「数字が
    # あっているとかは不要」。字面が違っても数字は同じなので、数字で見る
    said_numbers: dict[str, str] = {}
    for where, text in said:
        for token in NUMBER_TOKEN.findall(text):
            if len(token) < 4 or re.fullmatch(r"\d{4}年?", token):
                continue          # 「2失点」「7試合」は短すぎて、題材そのものの数字
            first = said_numbers.setdefault(token, where)
            if first != where and token not in seen and not (
                    first in opening and where in opening):
                seen.add(token)
                problems.append(
                    f"{first} と {where} で同じ数字を読んでいます（『{token}』）。"
                    "数字は一度だけ言い、あとは画面の表に任せてください")
    return problems


def _advise_short_repeats(notes: Notes) -> list[str]:
    """ショートの中で同じことを言っていないか（2026-09-15）。

    **`_advise_repeats` には穴があった。**ショート専用の行（`short_only`）は
    「本編には出ないので、前の節と同じで当たり前」として**まるごと見ていなかった。**
    ところがショートでは、その行は**タイトルを読む1行目のすぐ下**に来る。
    遠藤の回で実際にこうなっていた。

        S:0 遠藤航が4試合続けて出番なし。監督が語った理由とは。   ← タイトル
        S:1 遠藤航がリーグ戦で4試合続けて出番なし。…            ← short_only

    9/14 に「節をまたいで同じことを言わない」を入れたのに、**同じ型の重複が
    ユーザーの目で見つかった。**前の節と重なってよいのはそのとおりで、
    **比べる相手が違っていた。**ショートに一緒に出るものと突き合わせる。
    """
    problems: list[str] = []
    seen: set[str] = set()
    title = _bare_text(notes.title)
    for section in notes.sections:
        # ショートに一緒に出るのは、タイトルの1行目と、この節の本編の行
        others = [("タイトル", title)]
        for number, sentence in enumerate(section.say):
            only = (section.line_onlys[number]
                    if number < len(section.line_onlys) else "")
            if only == "short":
                continue
            voice = (section.voices[number]
                     if number < len(section.voices) else "")
            if voice and voice not in SPEAKERS:
                continue          # 反応は人の書いた文なので直さない
            text = sentence if isinstance(sentence, str) else str(
                (sentence or {}).get("text", ""))
            others.append((section.id, _bare_text(text)))
        for number, sentence in enumerate(section.say):
            only = (section.line_onlys[number]
                    if number < len(section.line_onlys) else "")
            if only != "short":
                continue
            text = _bare_text(sentence if isinstance(sentence, str) else str(
                (sentence or {}).get("text", "")))
            for where, other in others:
                shared = _longest_common(text, other)
                # **タイトルだけ基準を下げる。**ショートではタイトルの次の行として
                # 2秒後に読まれる。節の中の他の行はもっと離れているので、
                # 本編と同じ12字で見る（そうしないと「はフェルナンデス」のような
                # 人名の重なりで鳴る）
                limit = SHORT_REPEAT_MIN if where == "タイトル" else REPEAT_MIN
                shared = _meaningful(shared, notes)
                if len(shared) >= limit and shared not in seen:
                    seen.add(shared)
                    problems.append(
                        f"ショート専用の行が {where} と重なっています"
                        f"（『{shared}』）。ショートではこの2つが続けて読まれます。"
                        "タイトルに無いことだけを書いてください")
    return problems


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



def _advise_cards(notes: Notes) -> list[str]:
    """数字が並んでいるのに、画面へ出していない節を拾う。

    **声だけで数字を並べても、聞く人は数えられない。**表にすれば
    画面がもう1枚増えるうえ、耳で追えなかった人が目で追える。
    反応の節は数えない（白い箱を並べる形が決まっている）。
    """
    hints: list[str] = []
    for section in notes.sections:
        card = section.card or {}
        if str(card.get("type", "")).lower() == "reactions":
            continue
        if card:
            continue
        numbered = [line for line in section.say
                    if isinstance(line, str) and any(ch.isdigit() for ch in line)]
        if len(numbered) < CARD_NUMBER_LINES:
            continue
        hints.append(
            f"節『{section.heading}』は数字の行が{len(numbered)}行ありますが、"
            "画面に表を出していません。`card: {type: table, title: …, rows: …}` "
            "で1枚増やせます"
        )
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
    hints: list[str] = (_advise_volume(notes) + _advise_material(notes) + _advise_cards(notes)
                        + _advise_hook(notes) + _advise_thumbnail_repeat(notes)
                        + _advise_thumbnail_promise(notes)
                        + _advise_thumbnail_name(notes)
                        + _advise_wide_photo(notes)
                        + _advise_offtopic_section(notes)
                        + _advise_card_telop_overlap(notes)
                        + _advise_repeats(notes) + _advise_short_repeats(notes)
                        + _advise_title(notes) + _advise_group_thumbnail(notes)
                        + _advise_ear(notes) + _advise_readings(notes))
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
    # **同じ題の作り直しも、この動画そのもの**（2026-09-22）。プレミア20クラブの
    # 台本を翌日に直して掛け直したら、8本すべてが「昨日扱ったテーマ」で止まった。
    # 見出しまで同じなら、別の話題ではない
    if entry.headline and entry.headline == notes.title and entry.at.date() != today:
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
# **1枚のカードを出しておける行数**（2026-09-12）。
# カードは明示的に消すまで残る（script_model の rows）。
# 実測：1行5〜6秒。2行で12.7秒になり「同じ絵が12秒」に引っかかった。
# **1行ごとに、カードと写真を入れ替える。**
CARD_LINES_MAX = 1
# **読み上げる文はぜんぶ画面に出す**（2026-09-14 指示）。
# 54字で切っていたので、長い一文は「…アンドレス・」で終わっていた。
# 収まらないぶんは render 側が字を小さくして入れる
TELOP_LIMIT = 200


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
        # シリーズ名（2026-09-23）。subtitles.write_outputs が公開する題の後ろに付ける
        **({"series": notes.series} if notes.series else {}),
        # **話のまとまり**を台本にも残す（2026-09-15）。`clubs.yaml` に無いクラブは
        # topic からタグにしているので、`review` の「タグのクラブ名」が
        # 突き合わせる相手を持てなかった（サウサンプトンの回が × になっていた）
        **({"topic": notes.topic} if notes.topic else {}),
        "thumbnail_line1": str(thumbnail.get("line1") or notes.title),
        "thumbnail_line2": str(thumbnail.get("line2") or notes.question),
        "thumbnail_tags": [str(t) for t in (thumbnail.get("tags") or [])],
        # 案を書いてあれば台本に持ち越す。thumbnail --all で並べて比べる
        "thumbnail_alt": [dict(a or {}) for a in (thumbnail.get("alt") or [])],
        # 左の余白に積む短い言葉（2026-09-08）。3つまで
        "thumbnail_points": [str(x) for x in (thumbnail.get("points") or [])][:3],
        # **赤で1行**（2026-09-14 指示）。エンブレムの回は points を出さないので、
        # 言いたい一言を置く場所が帯しか無かった
        "thumbnail_note_red": str(thumbnail.get("note_red") or ""),
        "thumbnail_band_full": bool(thumbnail.get("band_full", False)),
        # **ショートに反応を入れない回**（2026-09-14 指示）。取材メモに
        # `short_voices: false` と書く。既定は入れる
        **({} if notes.short_voices else {"short_voices": False}),
        # 顔を並べる（2026-09-08）。2〜3枚で全面が写真になる
        "thumbnail_photos": [str(x) for x in (thumbnail.get("photos") or [])][:5],
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
        # **サムネだけに敷く絵**（2026-09-17）。一覧板や数字の図をここに書く。
        # `thumbnail_photo` に入れると動画の中でも使われ、カードと重なる
        **({"thumbnail_board": str(thumbnail["board"])} if thumbnail.get("board") else {}),
        **({"thumbnail_focus": thumbnail["focus"]} if thumbnail.get("focus") is not None else {}),
        # **縦型（ショート）で横のどこを残すか**（2026-09-18）。
        # 横長の写真を縦の画面に敷くと真ん中で切られ、端の人が落ちる
        **({"thumbnail_focus_x": thumbnail["focus_x"]}
           if thumbnail.get("focus_x") is not None else {}),
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
            league_name=(notes.league_name
                         or (plan.league_name(notes.league) if notes.league else "")),
            kind=notes.kind,
            # **選手名を入れる**（2026-09-08）。辞書が無いので推測はしないが、
            # サムネの札には人名を書いているので、そこから持ってくる。
            # 参考4チャンネルのハッシュタグはほぼ全部が選手名とクラブ名で、
            # こちらは「サッカー」「移籍市場」のような分類語しか無かった。
            # サンチョの回にサンチョが入っていない状態だった
            # **エンブレムに書いたクラブ名も入れる**（2026-09-15）。
            # `crest_main` / `crests` は手で書いたクラブ名なのに、タグへは
            # 渡していなかった。ボーンマスの回は `crest_main` に
            # 「ボーンマス」「ブレントフォード」と書いてあるのに、
            # タグにクラブ名が1つも無かった
            extra=[str(t) for t in (thumbnail.get("tags") or [])]
            + [str(t) for t in (thumbnail.get("crest_main") or [])]
            + [str(t) for t in (thumbnail.get("crests") or [])],
            # **この回に出てくる人**（2026-09-10）。取材メモの `people:` に書く。
            # 辞書が無いので本文からは拾わない（推測で人名を作らない）。
            # **話者名から自動で足す案は取り下げた**（2026-09-15）。試したら
            # タグは中央値8個→9個しか増えず、代わりに「ノティシアス・デ・
            # ギプスコア」「Le Petit Lillois」のような**地元紙の名前**が入った。
            # 話者名には媒体も混ざるので、機械では人と見分けられない
            people=list(notes.people),
            topic=notes.topic,
        ),
        "sources": notes.sources,
        "cards": _cards(notes),
    }

    # オープニングとまとめにも下地を指定する。指定が無いと frontmatter の既定に
    # 落ちて、どちらも同じ緑になっていた（実測でまとめの3カットが緑だった）
    # **この回の下地。**題材ごとに変えるが、**1本のあいだは変えない**
    # **エンブレム主役の回は、オープニングも止める**（2026-09-15）。
    # has_photo を下で計算していたので、**冒頭の1節だけ実写のまま**残っていた
    _has_photo_early = bool(str((notes.thumbnail or {}).get("photo") or "").strip()
                            or [x for x in ((notes.thumbnail or {}).get("photos") or [])
                                if str(x).strip()])
    opening_background = (OPENING_BACKGROUND if _has_photo_early else STILL_BACKGROUND)
    # **節が下地を指定していたら、オープニングもそれに合わせる**（2026-09-18 に踏んだ）。
    # 全節に `bg` を書いたのに、**オープニングだけ既定の実写クリップ**のままで、
    # 1つ目の切り替わりで場所が変わって見えた。
    # 「下地は1本のあいだ変えない」（2026-09-14 指示）に、ここだけ従っていなかった
    _first_bg = next((sec.bg for sec in notes.sections if sec.bg), "")
    if _first_bg:
        opening_background = _first_bg
    lines = ["---", _front_matter(front), "---", "",
             "## オープニング",
             # **最初の画面はサッカーの、人が写っているものにする**（2026-09-13 指摘）。
             # ここは night.png 決め打ちだった。night.png は自前で描いた玉ぼけで、
             # 人もピッチも写っていない。写真の無い回（クラブのエンブレムで作る回）は
             # 開いた瞬間が抽象画になっていた
             f"@bg: {moving_background(opening_background)}", ""]
    # **1行目はタイトルをそのまま読む**（2026-09-07）。参考3チャンネルの直近4本は
    # 全部、最初の2〜5秒でタイトルを読み上げていた。クリックした人が「これで
    # 合っている」と確かめられる。こちらは別の導入文から入っていた。
    #
    # **冒頭から名乗らない。**「海外サッカーのニュースです」は毎回同じで中身が無く、
    # 続く「〜ここを掘っていきます」も問いを言い直しているだけだった。
    # **問いは読み上げず、画面に出す。**読むと、つかみと合わせて前置きが18秒になる
    # **タイトルの前に、そのクラブを表す一言**（2026-09-21 指示）。
    # 「1行目はタイトル」の決まりは残す（クリックした人が確かめられる）ので、
    # **一言 → タイトル**の順。書いていない回は今までどおりタイトルから始まる
    # **最初の画面を指定できる**（2026-09-23）。プレミア20クラブ紹介は、
    # 1行目のキャッチコピーを**基礎DATAの板の中**に置いて、そこを読む
    _open_image = [f"  image: {notes.opening_image}"] if notes.opening_image else []
    if notes.lead and _bare_text(notes.lead) != _bare_text(notes.title):
        lines += [
            f"キャスター: {_ends_sentence(notes.lead)}",
            f"  telop: {_telop(notes.lead, TELOP_LIMIT)}",
        ] + _open_image + (["  no_telop: true"] if notes.opening_image else [])
    lines += [
        f"キャスター: {_ends_sentence(notes.title)}",
        f"  telop: {notes.title}",
        "  se: assets/audio/se_pon.wav",
    ] + _open_image
    # **このあと話すことを冒頭で見せる**（2026-09-23 指摘）。最初の15秒が
    # 写真1枚とテロップだけで、読む物が無かった
    if notes.opening_card and not notes.opening_image:
        lines.append("  card: opening_card")
    if notes.format == "news":
        # **問いを読み上げない**（2026-09-09）。視聴維持の曲線を読んだら、
        # 捨てられているのは0〜3秒ではなく**4〜9秒**だった（4秒100% → 8秒39.7%）。
        # タイトルを読むところまでは残り、そのあとの一言で半分以上が消える。
        # hook が空のときは question をそのまま読んでいた＝クリックした人が
        # もう知っている話の言い直し。**書いていなければ、その行ごと出さない。**
        if notes.hook and _bare_text(notes.hook) != _bare_text(notes.question):
            lines += [
                f"キャスター: {_ends_sentence(notes.hook)}",
                # **問いを画面に出さない**（2026-09-14 指摘「この今回の問はいらない」）。
                # 読み上げずに画面へ出す形にしていたが、**喋っている言葉と
                # 画面の字が違う**状態が続いていた。喋っている一言をそのまま出す。
                # 画面は2〜3行に折り返せる。20字で切ると「…当の監督…」のように
                # 途中で切れた文字がそのまま出ていた（2026-09-07 に書き出して確認）
                f"  telop: {_telop(notes.hook, TELOP_LIMIT)}",
            ] + _open_image
    elif notes.hook:
        # 反応・本人の言葉の型は、つかみが書いてあれば1行だけ。問いは立てない。
        # 参考（サッカーラボ 25.5万回）は 0:02 でタイトル、0:11 から事実だった
        lines.append(f"キャスター: {_ends_sentence(notes.hook)}")
        # **テロップを付け忘れていた**（2026-09-24 に発見）。news の型には付けて
        # いたのに、quote / voices の型ではこの1行だけ声だけで流れていた。
        # 「読み上げた文は、画面にも出す」（2026-09-10）が、型で抜けていた形。
        lines.append(f"  telop: {_telop(notes.hook, TELOP_LIMIT)}")
        lines += _open_image
    lines.append("")

    # **カードを消したあとに置く絵**（2026-09-12）。カードを消しただけだと
    # 「カードも写真も無い」まま画面が伸びる。サムネの写真を本文にも出す決まりが
    # もともとあるので、それをここで使う
    _thumb = notes.thumbnail or {}
    fallback_image = str(_thumb.get("photo") or "")
    if not fallback_image:
        # **顔を2枚並べた回は `photos` に入っている**（`photo` は空）。
        # ここを見ていなかったので、写真に戻すはずの行が空のままだった
        _photos = [str(x) for x in (_thumb.get("photos") or []) if str(x).strip()]
        fallback_image = _photos[0] if _photos else ""
    if not fallback_image:
        # **エンブレムが主役の回は写真が1枚も無い**（2026-09-13）。
        # カードを消さないようにしたら、今度は同じカードが33秒出たままになった。
        # エンブレムそのものを、カードと入れ替える絵に使う
        from . import crest as _crest
        for _club in (_thumb.get("crest_main") or []):
            _path = _crest.find(str(_club))
            if _path is not None:
                fallback_image = str(_path).replace("\\", "/")
                break

    previous_background = ""
    # 絵を写真に替えたか。**替えるのは1本につき1回**
    photo_on = False
    # **エンブレムは全画面の下地に使えない**（2026-09-14 指摘「右側が黒くなってる」
    # 「ユベントスのロゴか見えない」）。写真用の作りは、同じ写真をぼかして敷いた上に
    # 右半分へ立てるので、**背景が透明なエンブレムを渡すと右半分が黒くなる**。
    # 写真が1枚も無い回は、下地を最後まで替えない（切り替え0回）
    has_photo = bool(str(_thumb.get("photo") or "").strip()
                     or [x for x in (_thumb.get("photos") or []) if str(x).strip()])
    # 山場の節から替える。**山場の指定が無い台本は2つ目の節**（1回なのは同じ）
    switch_at = next((i for i, sec in enumerate(notes.sections) if sec.main),
                     1 if len(notes.sections) > 1 else 0)
    for index, section in enumerate(notes.sections):
        # **1本のあいだ下地を変えない**（2026-09-14 指示「背景を何度も変更するのは
        # やめてください。サムネとサッカー関連背景でお願いします」）。
        # 節ごとに別のクリップへ切り替えていたので、2分のあいだに4回も
        # 場所が変わって見えた。画面を動かすのは**サムネの写真の出し入れ**で足りる。
        # 取材メモが `bg` を書いた節だけは、その指定に従う
        # **エンブレム主役の回は止まった下地**（2026-09-15）
        background = section.bg or (opening_background if has_photo else STILL_BACKGROUND)
        # **素材が無ければ静止画に落とす。**stock を取っていない環境でも動く
        if background.startswith(STOCK) and not _resolve_bg(background).exists():
            background = BACKGROUNDS[index % len(BACKGROUNDS)]
        previous_background = background
        lines += [f"## {section.heading}", f"@bg: {moving_background(background)}"]
        if section.main:
            lines.append("@main: true")
        # **ここから写真に替える。**それより前は下地のまま
        if has_photo and index >= switch_at:
            photo_on = True
        lines.append("")
        # **節の頭で数え直す**（2026-09-20）。1行目が `only: short` だと、
        # 数え始め（first_kept）より前にこの2つを使って落ちた。前の節があれば
        # その値が残っていて表に出ず、**1節目がショート専用の行で始まる台本**で初めて踏んだ
        shown_for = 0
        last_image = ""
        showed_photo = False
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
            own_only = (section.line_onlys[number]
                        if number < len(section.line_onlys) else "")
            # **板と同じことを字幕で重ねない**（2026-09-20 指示）
            own_mute = (section.line_no_telops[number]
                        if number < len(section.line_no_telops) else False)
            if own_only:
                lines.append(f"  only: {own_only}")
            # 本編に残る最初の行（`only: short` を飛ばす）
            first_kept = next(
                (i for i in range(len(section.say))
                 if not (section.line_onlys[i]
                         if i < len(section.line_onlys) else "")), 0)
            if (number < len(section.line_short_voices)
                    and section.line_short_voices[number]):
                lines.append("  short_voice: true")
            if (number < len(section.line_conts)
                    and section.line_conts[number]):
                lines.append("  cont: true")
            # **`only: short` の行に節のカードを付けない**（2026-09-18 に踏んだ）。
            # その行は本編では落ちるので、**カードごと消える**。
            # クロップの回で、選手の表が画面に一度も出なかった。
            # `_is_voices_scene` が `only: short` の語りを数えて壊れたのと同じ型で、
            # **あの1行はショート専用なのに、節の1行目として扱われている**
            if number == first_kept:
                shown_for = 0
                showed_photo = False
                # **1行目も、読み上げた文を画面に出す**（2026-09-13 ユーザー指示「A」）。
                # それまでは節のテロップ（見出し）で上書きしていた。おかげで
                # **これから言うことが画面に先に出ていた。**実例（アルテタの回）:
                #   読み「この話が出た翌日、アーセナルはサンダーランドと戦いました」
                #   画面「サンダーランドに2対0」← **結果を先に見せている**
                # 「読み上げた文は画面にも出す」という決まりが、各節の1行目だけ
                # 守られていなかった（`画面に出る字 96%` の残り4%がこれ）。
                # 節の見出しは章カードで別に出ているので、ここでは要らない。
                # **手で書いた line_telops があればそれを優先する**（従来どおり）
                head = own_telop
                if not head and voice and voice not in SPEAKERS:
                    # **代弁なら、その人の言葉として出す。**節のテロップを
                    # そのまま被せると、別人の発言に他人の名前が乗る（実測 2026-09-06）
                    room = max(8, TELOP_LIMIT - len(voice) - 1)
                    head = f"{voice}「{_telop(sentence, room)}」"
                elif not head:
                    head = _telop(sentence)
                if own_mute:
                    lines.append("  no_telop: true")
                else:
                    lines.append(f"  telop: {head}")
                lines.append(f"  source: {section.tier}")
                if own_card:
                    lines.append(f"  card: {section.id}_{number}_card")
                elif section.card:
                    lines.append(f"  card: {section.id}_card")
                else:
                    shown_for = CARD_LINES_MAX      # カードが無いので数えない
                # **カードが無い行にも写真は出す。**入れ子にしていたせいで、
                # カードを持たない行の写真が消えていた（実測 2026-09-06）
                # **節の1行目にも出す**（2026-09-14）。ここだけ抜けていたので、
                # 節が変わるたびに下地へ戻り、写真と下地が交互に出ていた
                if photo_on and fallback_image and not own_image:
                    own_image = fallback_image
                if own_image:
                    lines.append(f"  image: {own_image}")
                    # **入れ替えた写真は、そのあとの行にも残す**（2026-09-25 指摘
                    # 「ジダン 背景がジダンだけとなっている」）。行に写真を指定しても、
                    # 次の行でサムネの写真へ戻っていたので、**2枚目が一度も出ないか、
                    # 出ても1行で消える**（画面は「ジダン→ムバッペ→ジダン」と2回動く）。
                    # 入れ替えは1本1回までの決まりなので、**新しい写真を既定にする**
                    fallback_image = own_image
                    # **行に写真があれば、そのあとの行でカードを下ろせる**（2026-09-22）。
                    # 名選手の節が1人3行になり、顔写真はあるのに、サムネ写真の無い回
                    # （プレミア20クラブ紹介）は photo_on が立たず、同じカードが22秒続いた
                    showed_photo = True
                    last_image = own_image
            else:
                # **指定が無い行にも、読み上げ文からテロップを作る**
                # （2026-09-06 ユーザーの指示）。指定が無いと前の見た目のまま
                # 続き、画面が止まる。テレビのニュースは1発言ごとに字幕が変わる。
                # **代弁の行は誰の言葉かを頭に付ける。**画面だけ見ても分かるように
                shown = own_telop
                if not shown and voice and voice not in SPEAKERS:
                    # 代弁は誰の言葉かを頭に付ける。画面だけ見ても分かるように
                    room = max(8, TELOP_LIMIT - len(voice) - 1)
                    # **鉤括弧を二重にしない**（2026-09-23 に画面で見つけた）。
                    # 原文が「…」で始まる発言だと「マルコ・ローゼ「「ボールに…」」」になる
                    inner = _telop(sentence, room)
                    if inner.startswith("「") and inner.endswith("」"):
                        inner = inner[1:-1]
                    shown = f"{voice}「{inner}」"
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
                if own_mute:
                    lines.append("  no_telop: true")
                elif shown:
                    lines.append(f"  telop: {shown}")
                shown_for += 1
                if own_image:
                    # 自分で写真を指定した行も「写真を出した」と数える。
                    # 数えないと、次の行に同じ写真がもう一度出て12.6秒になった
                    showed_photo = True
                    last_image = own_image
                if own_card:
                    lines.append(f"  card: {section.id}_{number}_card")
                    shown_for = 0
                elif shown_for >= CARD_LINES_MAX:
                    # **同じカードを出しっぱなしにしない**（2026-09-12）。
                    # カードは次の行にも残る決まりなので（script_model の rows）、
                    # 語りが続くとその分だけ同じ絵が伸びる。
                    # 実測では、2行の節で11秒・3行で17秒・4行で23秒・10行で53秒。
                    # **カードを消して、代わりに写真を出す。**消すだけだと
                    # 「カードも写真も無い」まま16秒伸びた
                    # **代わりに出すものが無いなら、カードは消さない**（2026-09-13）。
                    # エンブレムを主役にした回は写真が1枚も無く、
                    # カードを消したあとが「カードも写真も無い」まま伸びていた
                    # （実測でアーセナル27秒・チェルシー55秒・リヴァプール58秒）。
                    # **消すのは、写真に入れ替えられるときだけ**にする
                    # **消すのは、写真に入れ替えられるときだけ**（2026-09-13）。
                    # 入れ替える相手が無いのに消すと「カードも写真も無い」まま伸びる。
                    # 2026-09-14 指摘「意味のないnoneが入っている」も同じところ
                    if photo_on and fallback_image:
                        lines.append("  card: none")
                    elif showed_photo and not own_image and last_image and number >= 2:
                        # **表は下ろさない**（2026-09-23 指摘「左の表が消える」）。
                        # 9/22 は「3行目でカードを下ろして顔だけにする」としていたが、
                        # **表が消えると、誰の何の話かが画面から無くなる。**
                        # 写真だけ引き継いで、表はそのまま出しておく
                        own_image = last_image
                    shown_for = 0
                # **絵の切り替えは1本につき1回だけ**（2026-09-14 指示
                # 「背景がコロコロ変わるのやめてほしい。変更は一度まで」）。
                # それまでは「写真 → 下地だけ → 写真」と交互に出していたので、
                # 2分のあいだに画面が何度も入れ替わって見えた。
                # **山場の節に入ったところで写真に替え、そのまま最後まで出す。**
                # image は行ごとの指定で次の行に残らないので、毎行に書く
                if photo_on and fallback_image and not own_image:
                    own_image = fallback_image
                if own_image:
                    lines.append(f"  image: {own_image}")
                    fallback_image = own_image      # 上と同じ（2026-09-25）
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
        # まとめも同じ下地のまま。ここだけ変えると、最後に場所が飛ぶ
        wrap_background = previous_background or opening_background
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
    if notes.opening_card:
        cards["opening_card"] = notes.opening_card
    for section in notes.sections:
        if section.card:
            cards[f"{section.id}_card"] = section.card
        for number, one in enumerate(section.line_cards):
            if one:
                cards[f"{section.id}_{number}_card"] = one
        # **代弁の行ぶんの引用カード**（2026-09-12）。台本と同じ番号で作る
        for number, sentence in enumerate(section.say):
            voice = section.voices[number] if number < len(section.voices) else ""
            if number == 0 or not voice or voice in SPEAKERS:
                continue
            if number < len(section.line_cards) and section.line_cards[number]:
                continue
            # **代弁の行に引用カードを出さない**（2026-09-14 指摘
            # 「話の重複が多い」「現地はどう見たかで、同じテロップが出ている」）。
            # 下のテロップが既に「LA NUOVA「〜」」と話者ごと出しているので、
            # カードを重ねると**同じ一文が画面に2つ**並ぶ。匿名の反応なら
            # 積み上げと合わせて3か所だった。
            # 2026-09-12 にこのカードを足したのは「同じ絵のまま30〜50秒」を
            # 避けるためだったが、いまは下地が実写で動いている
            continue
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
