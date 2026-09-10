"""ショート動画（縦9:16）の書き出し。

本編は2〜3分だが、YouTube ショートは60秒まで。全部は入らないので、
どこを切るかを決める必要がある。

切り方は「冒頭 + 1つの節」。冒頭で何の話かを言い、1つだけ掘って、
続きは本編へ送る。まとめまで入れると60秒に収まらないし、
入れたところで本編を見る理由がなくなる。
"""

from __future__ import annotations

import copy
import re
from dataclasses import replace
from pathlib import Path

from .config import ProjectConfig
from .script_model import Scene, Script

# ショートの上限。ぎりぎりを狙うと音声の長さのぶれで超える
MAX_SECONDS = 58.0
SHORT_SPEED = 1.1      # ショートの話速の倍率。本編は変えない
SIZE = (1080, 1920)


class ShortError(Exception):
    pass


def portrait(config: ProjectConfig) -> ProjectConfig:
    """縦向きの設定にする。文字は横幅が狭くなるぶん小さくする。

    **タイトルカードと章タイトルは出さない。** 本編では話の入口として要るが、
    ショートでは冒頭2.6秒が「無音の静止画」になり、そこで捨てられる。
    実測（2026-09-07）で、公開済みショートの視聴維持は
    「視聴を継続 9.4% / スワイプして消去 90.7%」だった。最初の2秒に
    音も動きも被写体も無いのが効いている（先頭フレームを抜いて確認済み）。
    尺の上限が58秒しかないショートでは、カードに使う4秒の価値も本編とは違う。
    """
    video = replace(
        config.video,
        width=SIZE[0],
        height=SIZE[1],
        telop_size=max(40, int(config.video.telop_size * 0.78)),
        # 見出しは縮めない。参考チャンネルは画面幅いっぱいの極太2行だった
        headline_size=max(44, int(config.video.headline_size * 0.70)),
        title_size=max(56, int(config.video.title_size * 0.62)),
    )
    titles = replace(config.titles, intro=0.0, chapter=0.0)
    # **ショートは少し速く読む**（2026-09-08）。参考は反応1件3秒台で、
    # 9/7 に Gemini に聞いた答えでも「1件3〜4秒に詰める」が2番目だった。
    # 本編の話速（1.0〜1.05）は参考と同じなので触らず、ショートだけ上げる
    cast = {key: replace(member, speed=round(member.speed * SHORT_SPEED, 3))
            for key, member in config.cast.items()}
    return replace(config, video=video, titles=titles, cast=cast)


def trim(script: Script, section: str = "", max_seconds: float = MAX_SECONDS) -> Script:
    """冒頭と、掘る節を1つだけ残す。

    section を指定しなければ、冒頭の次にある最初の中身の節を使う。
    尺に収まらなければ、その節の後ろのセリフから落とす。
    """
    if len(script.scenes) < 2:
        raise ShortError("節が1つしかありません。ショートにする意味がありません")

    opening = script.scenes[0]
    body = _pick(script, section)

    short = copy.deepcopy(script)
    short.scenes = [copy.deepcopy(opening), copy.deepcopy(body)]
    _retitle(short, body)
    _drop_hook(short.scenes[0])
    _drop_main_mark(short.scenes[1])
    _drop_lead_in(short.scenes[1])
    _fit(short, max_seconds)
    _add_face(short)
    if not short.scenes[-1].lines:
        raise ShortError(f"『{body.title}』は冒頭だけで尺を使い切ります。節を選び直してください")
    return short


def _retitle(short: Script, body: Scene) -> None:
    """ショートに別のタイトルを付ける（2026-09-09）。

    昨夜の12本は、本編とショートが**同じ題名**で並んでいた。チャンネルの画面では
    重複に見え、検索でも自分同士でぶつかる。台本に `short_title` があればそれを使い、
    無ければ使った節の見出し（telop）を添えて、少なくとも別の題名にする。
    """
    meta = short.meta or {}
    chosen = str(meta.get("short_title") or "").strip()
    if not chosen:
        # **節の見出しをそのまま題名にする。**本編の題名を頭に足していたら
        # 「22件の書き込みから　上田綺世が初先発で…」になり、意味を成さなかった
        # （2026-09-09、予約したあとに気づいた）。見出しが弱ければ本編の題名のまま
        head = ""
        for line in body.lines:
            head = (line.telop or "").strip()
            if head:
                break
        chosen = head if len(head) >= 10 else short.title
    short.title = chosen[:100]
    # **画面と読み上げは本編のまま。**題名だけ分ける。ここを書き換えると
    # 「読み上げている文」と「画面に出ている文」がずれる
    short.meta = dict(meta)


def _drop_hook(opening: Scene) -> None:
    """冒頭は**タイトルの読み上げ1行だけ**にする（2026-09-09）。

    視聴維持の曲線を初めて読んだら、捨てられているのは0〜3秒ではなく
    **4〜9秒**だった（実測: 4秒で100% → 8秒で39.7%、3秒で105% → 9秒で39.6%）。
    タイトルを読むところまでは残っていて、そのあとの「今回の問いは〜」で
    半分以上が消える。問いの言い直しは、クリックした人がもう知っている話。
    画面のテロップには残るので、読み上げだけ落とす。
    """
    if len(opening.lines) > 1:
        del opening.lines[1:]


def _drop_main_mark(scene: Scene) -> None:
    """**「ここからが本題です。」を落とす**（2026-09-10）。

    本編では前の節と対比させる言葉だが、**ショートにはその「前」が無い。**
    いきなり「ここからが本題です」で始まると、何かを見落としたように聞こえる。
    画面のテロップには影響しない（読み上げの文だけ削る）。
    """
    for line in scene.lines:
        text = (getattr(line, "text", "") or "").lstrip()
        for mark in ("ここからが本題です。", "ここからが本題です", "ここからが本題。"):
            if text.startswith(mark):
                line.text = text[len(mark):].lstrip() or text
                return
        if text:
            return


# 語りを担当する声。ここに無い話者は「誰かの言葉を代弁している」
NARRATORS = ("キャスター", "解説", "ナレーター")


# 代弁で稼げる上限。これが無いと、発言の多い節が必ず勝つ
VOICE_CAP = 12
# 取材メモの決まりで、答えを出す節はこの言葉で始まる
MAIN_MARK = "ここからが本題"
MAIN_BONUS = 14
# 試合の前の話だと分かる見出し
BEFORE_WORDS = ("試合の前", "前日", "試合前")
BEFORE_PENALTY = 8


def strength(scene: Scene, cards: dict) -> int:
    """その節の強さ。**いちばん強い場面をショートに使う**（2026-09-06 ユーザー）。

    11本を振り返ると、残ったのは全部「誰かの言葉」だった
    （アルテタ「欠かせない選手だった」／モウリーニョ「なぜ負けたのか分からない」）。
    **事実の説明より、本人の口から出た一言が強い。**
    数字も次点で効く（枠内8本・xG3.16のような、それ自体が語るもの）。
    """
    voices = 0
    score = 0
    for line in scene.lines:
        who = (getattr(line, "speaker", "") or "").strip()
        if who and who not in NARRATORS:
            voices += 3         # 代弁。いちばん強い
        name = getattr(line, "card", None)
        kind = str((cards.get(name) or {}).get("type", "")).lower() if name else ""
        if kind == "quote":
            score += 3          # 原文の引用が画面に出る
        elif kind in ("bars", "table"):
            score += 2          # 数字が語る
        elif kind:
            score += 1
        if getattr(line, "image", None):
            score += 1

    # **代弁だけで勝たせない**（2026-09-10 ユーザー指摘）。1行3点で
    # 上限が無かったので、**発言が10行ある「試合の前に何を言っていたか」が
    # 必ず勝っていた**。アーセナル回は27点で選ばれ、タイトルが
    # 「5試合で4点目の決勝弾」なのに**決勝弾が1秒も入っていなかった**。
    # PSG回も同じで、6得点が入っていなかった。いちばんニュース性の低い節が
    # 選ばれる作りになっていた
    score += min(voices, VOICE_CAP)

    text = " ".join((getattr(l, "text", "") or "") for l in scene.lines)
    # **書いた人が「ここが山場」と印を付けている。**取材メモの決まりで、
    # 答えを出す節は「ここからが本題です」で始める。機械の点より、その印を採る
    if MAIN_MARK in text:
        score += MAIN_BONUS
    # **試合の前の話は速報性が低い。**結果が出たあとに配るものなので、
    # 「前日はこう言っていた」だけのショートは中身が古い
    if any(word in (scene.title or "") for word in BEFORE_WORDS):
        score -= BEFORE_PENALTY
    return score


def _pick(script: Script, section: str) -> Scene:
    if section:
        for scene in script.scenes:
            if section in (scene.title, getattr(scene, "key", "")):
                return scene
        known = " / ".join(scene.title for scene in script.scenes[1:])
        raise ShortError(f"『{section}』という節がありません（{known}）")

    # **冒頭の次を機械的に取らない。**そこは前置きであることが多い。
    # まとめは答えを先に言ってしまうので外す
    body = [s for s in script.scenes[1:] if s.title != "まとめ"]
    if not body:
        return script.scenes[1]
    cards = script.cards or {}
    best = max(body, key=lambda s: (strength(s, cards), -body.index(s)))
    return best


def _add_face(script: Script) -> None:
    """顔写真を**最初の行から最後まで、全部の行に置く**。

    実測（2026-09-06）で、写真が出るのは平均12秒目、映っているのは全体の
    2割だけだった（ミランは10%、レアルは23秒目から）。
    **ショートは数秒で見るか決められる。**顔が12秒後では、その前に離脱される。

    **写真は「指定した行以降そのまま残る」わけではない。**残るのは
    カードとテロップで、写真は指定した行だけ。最初そう思い込んで先頭にだけ
    置いたところ、5秒出て消えた（実測して分かった）。全部の行に置く。
    """
    photo = str((script.meta or {}).get("thumbnail_photo") or "").strip()
    if not photo:
        photo = next((str(line.image) for line in script.lines if line.image), "")
    if not photo:
        return
    for line in script.lines:
        if not line.image:
            line.image = photo


# ショートは数秒で見るか決められる。**顔が出るのが遅いと、その前に離脱する**
FACE_BY_SECONDS = 3.0
FACE_SHARE = 0.6


def face_timing(script: Script) -> tuple[float | None, float]:
    """(顔が最初に出る秒, 出ている割合)。顔が無ければ (None, 0)。"""
    at = None
    shown = 0.0
    total = 0.0
    for line in script.lines:
        span = line.duration or line.estimated_duration()
        if getattr(line, "image", None):
            if at is None:
                at = total
            shown += span
        total += span
    return at, (shown / total if total else 0.0)


def quote_problems(script: Script) -> list[str]:
    """発言が出るのが遅くないか（2026-09-10）。

    44本を測ったら、ショートは**誰かの言葉が19秒までに出る9本が平均維持50.4%、
    遅い8本が33.7%**だった（本編では 25.1% と 22.7% で差が出ない）。
    振りは機械で落とすが、そこから先は**台本の書き方**なので、
    書き出したところで知らせる。
    """
    at = quote_at(script)
    if at is None:
        return ["誰かの言葉が1つも入っていません（節を選び直すか、台本に発言を足す）"]
    if at > QUOTE_BY:
        return [f"最初の発言が{at:.0f}秒目です（{QUOTE_BY:.0f}秒までに出す。"
                "状況の説明を短くするか、発言のある節を選ぶ）"]
    return []


def face_problems(script: Script) -> list[str]:
    """顔の出し方の問題。**実測（2026-09-06）で平均12秒目・全体の2割だった。**

    ミランは10%、レアルは23秒目からで、30秒の動画では終盤に一度出るだけ。
    """
    at, share = face_timing(script)
    if at is None:
        return ["顔が1枚も出ていません"]
    out = []
    if at > FACE_BY_SECONDS:
        out.append(f"顔が出るのが{at:.0f}秒目です（{FACE_BY_SECONDS:.0f}秒までに出す）")
    if share < FACE_SHARE:
        out.append(f"顔が出ているのは{share * 100:.0f}%です（{FACE_SHARE * 100:.0f}%以上）")
    return out


# **見積りは実尺より短く出る。**章の切り替え・間・書き出しの処理が乗るため。
# 実測（2026-09-07）で見積り56秒に対し実尺66秒。**1割以上ずれる。**
# そのぶん手前で切らないと、60秒を超えてショートとして扱われなくなる
# **60秒まで使う**（2026-09-10 ユーザー「60秒で良いよ」）。0.80 だと
# 目標が46秒で、実尺は38〜45秒に収まっていた。**上限まで2割空けていた。**
# 見積りのずれは回によって +5%〜+18%（実測）なので、0.86 で目標50秒、
# 最悪でも59秒に収まる
ESTIMATE_SLACK = 0.86


# 情報を持たない「振り」。**発言の直前に置かれ、2〜4秒を使う**
LEAD_IN = re.compile(r"こう[^。]{0,8}(?:まし|ていま|いま|ま)す?[た。]?。?$")
# 最初の発言はここまでに出したい（秒）。実測の境目は19秒
QUOTE_BY = 15.0


def _is_lead_in(line) -> bool:
    text = (getattr(line, "text", "") or "").strip()
    return bool(text) and bool(LEAD_IN.search(text))


def _drop_lead_in(scene: Scene) -> None:
    """**最初の発言までの「振り」を落とす**（2026-09-10）。

    「こう話しました。」のような行は、次に発言が来ることを予告するだけで
    情報を持たない。**それでも2〜4秒かかる。**

    ショート44本を測ったら、誰かの言葉が19秒までに出る9本は平均維持50.4%、
    それより遅い8本は33.7%だった（本編では差が出ない）。**ショートでは
    発言までの秒数がそのまま維持に効く。**話者を名乗る行は残す
    （「ショート単体で分かるように」の決まりと衝突するため）。
    """
    out = []
    for index, line in enumerate(scene.lines):
        who = (getattr(line, "speaker", "") or "").strip()
        if who not in NARRATORS:
            break
        if _is_lead_in(line):
            out.append(index)
    for index in reversed(out):
        del scene.lines[index]


def quote_at(script: Script) -> float | None:
    """最初の「誰かの言葉」が始まる秒。語りだけなら None。"""
    elapsed = 0.0
    for line in script.lines:
        if (getattr(line, "speaker", "") or "").strip() not in NARRATORS:
            return elapsed
        elapsed += line.duration or line.estimated_duration()
    return None


def _blocks(scene: Scene) -> list[list[int]]:
    """節を「語りの1行＋そのあとに続く代弁」のかたまりに割る。

    取材メモは「そして、進め方そのものに踏み込みます。」のような
    語りを置いてから発言を並べる。**語りだけ、発言だけを落とすと文が繋がらない**ので、
    落とすときはこのかたまりごと動かす。
    """
    out: list[list[int]] = []
    for index, line in enumerate(scene.lines):
        who = (getattr(line, "speaker", "") or "").strip()
        if who in NARRATORS and (not out or any(
            (getattr(scene.lines[i], "speaker", "") or "").strip() not in NARRATORS
            for i in out[-1]
        )):
            out.append([index])
        elif out:
            out[-1].append(index)
        else:
            out.append([index])
    return out


def _is_narrator(line) -> bool:
    return (getattr(line, "speaker", "") or "").strip() in NARRATORS


def _closing(scene: Scene) -> list[int]:
    """締めのかたまり。代弁が入っていなければ空を返す（守る値打ちが無い）。"""
    blocks = _blocks(scene)
    if len(blocks) < 2:
        return []
    last = blocks[-1]
    if all(_is_narrator(scene.lines[i]) for i in last):
        return []
    return last


def _drop_middle(scene: Scene, script: Script, target: float) -> None:
    """**締めを残して、その手前から落とす**（2026-09-10）。

    後ろから1行ずつ落とすと、**いちばん強い一言がいつも先に消える。**
    ブラジル代表の回で実際に起きた。チアゴ・シウヴァの発言は
    年齢の話 → 進め方の話 → 「賛成しない」と積み上がっているのに、
    尺に収める処理が後ろから削るので、締めの「賛成しない」が落ち、
    途中の「全員を入れ替えて新しい顔ぶれにすることなんてできない」で終わっていた。
    鎌田の回は逆に「こう話しています。」という**振りだけ**で終わっていた。

    **視聴者が最後に聞くのは、いちばん強い一言であるべき。**
    締めのかたまりに代弁が入っているときだけ効かせる。
    振り（語り）だけが残ったら、その行も落とす（文が繋がらないため）。
    """
    closing = _closing(scene)
    if not closing:
        return
    keep = closing[0]
    while _estimate(script) > target and keep > 1:
        del scene.lines[keep - 1]
        keep -= 1
        # 代弁を全部落としたあとの「こう話しました。」だけを残さない
        while keep > 1 and _is_narrator(scene.lines[keep - 1]):
            del scene.lines[keep - 1]
            keep -= 1


def _fit(script: Script, max_seconds: float) -> None:
    """尺に収める。冒頭は削らない。

    **見積りの甘さを見込んで、手前で切る。**そのまま上限まで詰めると、
    書き出したときに超える（実測で56秒の見積りが66秒になった）。

    削る順番は、まず締めの手前から（`_drop_middle`）、
    それでも収まらなければ後ろから1行ずつ。
    """
    target = max_seconds * ESTIMATE_SLACK
    if _estimate(script) > target:
        _drop_middle(script.scenes[-1], script, target)
    while _estimate(script) > target and len(script.scenes[-1].lines) > 1:
        script.scenes[-1].lines.pop()


def _estimate(script: Script) -> float:
    """ビルド前は実尺が分からないので、文字数からの見積もりを使う。"""
    return sum(line.duration or line.estimated_duration() for line in script.lines)


def outro_line(script: Script) -> str:
    """ショートの締め。本編へ送る。"""
    return "続きは本編で。チャンネル登録してお待ちください。"


def default_path(script_path: str | Path) -> Path:
    return Path(f"output/{Path(script_path).stem}_short")
