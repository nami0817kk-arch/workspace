"""ショート動画（縦9:16）の書き出し。

本編は2〜3分だが、YouTube ショートは60秒まで。全部は入らないので、
どこを切るかを決める必要がある。

切り方は「冒頭 + 1つの節」。冒頭で何の話かを言い、1つだけ掘って、
続きは本編へ送る。まとめまで入れると60秒に収まらないし、
入れたところで本編を見る理由がなくなる。
"""

from __future__ import annotations

import copy
import hashlib
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


def crest_background(script, out_dir) -> str:
    """**エンブレムの回は、ショートの下地をエンブレムにする**（2026-09-14 指示）。

    YouTube はショートの一覧に**動画から自動で作った1コマ**を出す。
    こちらが設定したサムネイルは届かない（2026-09-09 に確認済み。
    `render._photo_stage` の注記も同じ）。つまり一覧で何が見えるかは
    **動画の中身**で決まるので、エンブレムを下地そのものに敷く。

    写真のある回は素通しする（人の顔のほうが強い）。
    """
    from pathlib import Path

    from .thumbnail import _short_crest_stage

    meta = script.meta or {}
    if str(meta.get("thumbnail_photo") or "").strip():
        return ""
    if [x for x in (meta.get("thumbnail_photos") or []) if str(x).strip()]:
        return ""
    names = [str(x) for x in (meta.get("thumbnail_crest_main") or [])]
    if not names:
        return ""
    from .config import load_config

    font_path = str(load_config().video.font_path())
    stage = _short_crest_stage(names, font_path,
                              str(meta.get("thumbnail_crest_link", "対")))
    if stage is None:
        return ""
    out = Path(out_dir) / "crest_bg.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    stage.convert("RGB").save(out, quality=95)
    return str(out).replace("\\", "/")


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
    # **末尾の無音を削る**（2026-09-13、Gemini に実物の動画を見せて指摘された）。
    # 読み上げ37.2秒に対して動画は40.2秒。**最後の3秒は音が無い。**
    # 冒頭の静止カードを外した理由（「最初の2.6秒で誰も喋っていなかった」）と
    # まったく同じことが、終わりで起きていた。**ショートは最後の一言で終える**
    titles = replace(config.titles, intro=0.0, chapter=0.0, outro=SHORT_OUTRO)
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
    # 冒頭に題の読み上げが何行目にあるかを見るため、元の題を渡す
    short.scenes[0]._title = str(getattr(script, "title", "") or (script.meta or {}).get("title", "") or "")
    _drop_hook(short.scenes[0])
    _drop_main_mark(short.scenes[1])
    _drop_lead_in(short.scenes[1])
    _hoist_voice(short, script)
    # **選ばれた反応のぶんは、先に空けておく**（2026-09-15）。
    # `_add_voices_tail` は尺が余っているぶんしか足さないので、
    # 印を付けた2件目が0.6秒はみ出して落ちていた（松木の回）。
    # 印は書いた人の指定なので、語りのほうを詰めて場所を作る
    # `_fit` は渡した秒数に ESTIMATE_SLACK を掛けてから使うので、
    # 空ける秒数のほうも割り戻しておく（掛け直されて目減りする）
    _fit(short, max_seconds - _reserved(script, short, max_seconds) / ESTIMATE_SLACK)
    _add_voices_tail(short, script, max_seconds)
    _add_more_body(short, script, max_seconds)
    _drop_boards(short)
    _add_face(short)
    _add_subscribe(short)
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


def _drop_boards(short: Script) -> None:
    """**板はショートに出さない**（2026-09-23 指摘「ショートの背景がおかしい」）。

    基礎DATAや登録選手の板は 16:9 で作ってある。縦（9:16）に敷くと真ん中しか
    映らず、「マス 基礎DATA」「ブラック・ナイト」のように字が切れて読めない。
    板を外せば、その回の下地（エンブレムかスタジアムの実写）が出る。
    **写真は外さない**（顔は縦でも成立する）。
    """
    from .render import _is_board

    for scene in short.scenes:
        for line in scene.lines:
            if line.image and _is_board(line.image):
                line.image = None


def _drop_hook(opening: Scene) -> None:
    """冒頭は**タイトルの読み上げ1行だけ**にする（2026-09-09）。

    視聴維持の曲線を初めて読んだら、捨てられているのは0〜3秒ではなく
    **4〜9秒**だった（実測: 4秒で100% → 8秒で39.7%、3秒で105% → 9秒で39.6%）。
    タイトルを読むところまでは残っていて、そのあとの「今回の問いは〜」で
    半分以上が消える。問いの言い直しは、クリックした人がもう知っている話。
    画面のテロップには残るので、読み上げだけ落とす。
    """
    if len(opening.lines) <= 1:
        return
    # **一言 → 題 の順で始まる回は、題まで残す**（2026-09-22）。プレミア20クラブ紹介は
    # 「クラブを表す一言」を題の前に読む（09-21 指示）ので、1行目だけ残すと
    # **ショートがクラブ名を一度も言わない**（「プレミアリーグで、いちばん小さなスタジアム。
    # このクラブの、基本のデータです」）。題を読む行までを残し、そのあとの問いを落とす
    def bare(text: str) -> str:
        return "".join(ch for ch in str(text or "") if ch not in "、。！？!? 　「」『』*")

    title = bare(getattr(opening, "_title", "") or "")
    keep = 1
    for index, line in enumerate(opening.lines[1:3], start=1):
        if title and bare(line.text) == title:
            keep = index + 1
            break
    del opening.lines[keep:]
    # **一言そのものはショートでは落とし、題の1行から始める**（2026-09-23）。
    # 20本の実尺で、一言（4〜5秒）のせいで「誰かの言葉」が16秒に届かない回が14本あった
    # （17〜20秒）。題の行にクラブ名が入るようになった（09-22）ので、一言を落としても
    # ショートがクラブ名を言わないことはない。本編の一言はそのまま
    if keep >= 2:
        del opening.lines[: keep - 1]


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

    # **書いた人が「ここが山場」と印を付けている。**機械の点より、その印を採る。
    # 印は取材メモの `main: true`（台本では `@main: true`）。
    # **2026-09-10 まではセリフの「ここからが本題です」が印だった**が、
    # ユーザー指示「台本のここからが本題ですはいらない」で読み上げから外した。
    # 文字のほうも見るのは、それ以前に書いた台本のため
    text = " ".join((getattr(l, "text", "") or "") for l in scene.lines)
    if getattr(scene, "main", False) or MAIN_MARK in text:
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

    # **山場の印があるなら、その節にする**（2026-09-13）。
    # CLAUDE.md には「機械の点より印を優先する」と書いてあったのに、
    # 実際は点の加算（MAIN_BONUS）でしかなく、**反応を並べた節に負けた。**
    # 代弁が7行ある「見ていた人が書いていたこと」が選ばれ、
    # ショートが試合の話をせずネットの声だけになっていた（書き出す前に発見）
    marked = [s for s in script.scenes[1:] if getattr(s, "main", False)]
    if marked:
        return marked[0]

    # **冒頭の次を機械的に取らない。**そこは前置きであることが多い。
    # まとめは答えを先に言ってしまうので外す
    body = [s for s in script.scenes[1:] if s.title != "まとめ"]
    if not body:
        return script.scenes[1]
    cards = script.cards or {}
    best = max(body, key=lambda s: (strength(s, cards), -body.index(s)))
    return best


# ショートの最後のカードを出す秒数。
# **2026-09-13 に 0 にした**理由は「3秒の**無音**でスワイプされる」だった。
# 2026-09-15 にユーザーの指摘「最後にカードとチャンネル登録の依頼を
# 読み上げれば良いのでは？」で戻す。**喋りながら出すなら、その理由は消える。**
# 2026-09-07 に読み上げをやめた理由（毎回同じ文句に8秒）にも当たらない。
# **2秒まで。**登録者は10日で24人しかおらず、本編が配られないのもそのため。
# ショートの末尾は、登録を頼める唯一の場所
# **締めは5秒枠**（2026-09-18 ユーザー指示「ショートの最後に本編はチャンネルから
# 見て下さい的な感じを入れたい。5秒くらいの枠で」）。2.0 から広げた。
# **ショートから本編へ渡す道が、これまで無かった。**本編の再生は登録者からが
# 86%で、ショートを見た人が本編へ回る経路はどこにも作っていない
SHORT_OUTRO = 5.0

# 最後に読み上げる一言（2026-09-15）。**短くする。**8秒使っていた頃の
# 「続報はチャンネル登録してお待ちください」には戻さない
# **本編へ渡す一言**（2026-09-18）。登録の依頼だけだったところに、
# 「本編がある」ことと「どこで見られるか」を足した。
# **押せるリンクは作れない**ので、行き先は「チャンネル」と言い切る。
# 2行に分けるのは、読み上げが5秒の枠に収まるようにするため
SHORT_SUBSCRIBE = "本編はチャンネルから見られます。"
SHORT_SUBSCRIBE_2 = "チャンネル登録もお願いします。"

# 締めのかたまり（本編への誘い＋登録の依頼）。**2行ある**（2026-09-18 に1行から増やした）
SHORT_OUTRO_LINES = (SHORT_SUBSCRIBE, SHORT_SUBSCRIBE_2)


def _outro_count(lines) -> int:
    """末尾にある締めの行数。**0〜2**。"""
    count = 0
    for line in reversed(lines):
        if (line.text or "").strip() in SHORT_OUTRO_LINES:
            count += 1
        else:
            break
    return count


def _has_outro(lines) -> bool:
    return _outro_count(lines) > 0


# ショートの最後に足すネットの声の本数（2026-09-13 ユーザー「ショートにもいくつか」）
VOICES_TAIL_MAX = 12


def _is_voices_scene(scene: Scene) -> bool:
    """反応だけを並べた節か。**語りが1行でもあれば違う。**

    ただし **`only: short` の1行は数えない**（2026-09-17 に発見）。
    反応の節の頭には「ショート単体で話が分かるように」状況説明を1行置く決まりで、
    その行の話者はキャスターである。**取材メモの雛形が必ずそう作る**ので、
    語りを1行でも見た時点で弾いていたこの関数は、**どの回でも False を返していた。**
    結果、`_add_voices_tail` の元が見つからず、**9/17 のショート5本すべてに
    ネットの声が1件も入っていなかった**（ユーザー指示「声は必ず」に反する）。
    その1行はショートの本体側へ切り出されるので、ここで数える相手ではない。
    """
    lines = [l for l in scene.lines
             if (l.text or "").strip()
             and str(getattr(l, "only", "") or "").strip() != "short"]
    if not lines:
        return False
    return all((getattr(l, "speaker", "") or "").strip() not in NARRATORS for l in lines)


def _reserved(script: Script, short: Script, max_seconds: float) -> float:
    """`short_voice` で選ばれた反応が要る秒数（2026-09-15）。

    印が無ければ0。今までどおり「余ったぶんだけ」足す。
    """
    if str((script.meta or {}).get("short_voices", "")).lower() in ("false", "no", "0"):
        return 0.0
    source = _voices_source(short, script)
    if source is None:
        return 0.0
    picked = [l for l in source.lines if getattr(l, "short_voice", False)]
    if not picked:
        return 0.0
    need = sum(l.duration or l.estimated_duration()
               for l in picked[:VOICES_TAIL_MAX])
    # 語りを削りすぎない。**半分までしか空けない**
    return min(need, max_seconds * 0.5)


def _voices_source(short: Script, script: Script) -> Scene | None:
    """ショートの締めに足す反応の節。"""
    if short.scenes[-1] is short.scenes[0]:
        return None
    for scene in reversed(script.scenes[1:]):
        if scene is short.scenes[-1] or scene.title == short.scenes[-1].title:
            continue
        if _is_voices_scene(scene):
            return scene
    return None


def _echoes_title(text: str, title: str) -> bool:
    """タイトルの言い直しか。**8字以上そのまま重なったら**そう見なす。

    `research.SHORT_REPEAT_MIN` と同じ基準。ショートでは、締めの反応が
    タイトルの2秒後に読まれるので、同じ言い回しだと言い直しに聞こえる。
    """
    body = "".join(ch for ch in str(text or "") if ch not in "、。「」『』！？ 　")
    head = "".join(ch for ch in str(title or "") if ch not in "、。「」『』！？ 　")
    if len(body) < 8 or len(head) < 8:
        return False
    return any(body[i:i + 8] in head for i in range(len(body) - 7))


def _add_voices_tail(short: Script, script: Script, max_seconds: float) -> None:
    """**ショートの最後にもネットの声を少しだけ足す**（2026-09-13 ユーザー指示）。

    本編では「反応は最後の節」と決まっているので、ショートが切り出す山場の節には
    入らない。そのままだとショートに1件も乗らない。**尺が余っているぶんだけ**、
    最後の反応の節から順に足す。

    **尺に収める処理のあとに足す。**先に足すと、締めのかたまりが反応になり、
    その手前＝山場の一番強い一言から削られてしまう（デ・パウルの回で実際に起きた）。
    """
    # **題材によっては、ショートに反応を入れない**（2026-09-14 指示
    # 「この話題において、ショートにはネット民の声は不要」）。
    # 審判の声明や本人の発言が芯の回は、最後が匿名の感想だと締まらない
    if str((script.meta or {}).get("short_voices", "")).lower() in ("false", "no", "0"):
        return
    source = _voices_source(short, script)
    if source is None:
        return
    target = max_seconds * ESTIMATE_SLACK
    # **どの反応で締めるかは、書いた人が選べる**（2026-09-15 指示）。
    # 上から順に取ると、1件目が見出しの言い直しになる回がある（松木の
    # 「松木玖生が今季公式戦初ゴール…平河悠との日本人対決を制す」は
    # タイトルとほぼ同じだった）。取材メモに `short_voice: true` と書く。
    # 印が1つも無ければ、今までどおり上から順に取る
    picked = [l for l in source.lines if getattr(l, "short_voice", False)]
    # 印が無いときの受け皿からも、頭の状況説明（`only: short`）は外す。
    # あれは語りで、ショートの本体側に既に入っている
    rest = [l for l in source.lines
            if str(getattr(l, "only", "") or "").strip() != "short"
            and not getattr(l, "short_voice", False)]
    # **印の付いたものを先に置き、そのあと残りで上限まで埋める**
    # （2026-09-20 ユーザー指摘「ショートの内容が薄い、ちゃんと時間使って」）。
    # 2026-09-16 に一度この形にしかけて見送ったのは、**残りの1件目が
    # 見出しの言い直しになる回がある**ため（9/15 の指摘）。そこで、
    # **タイトルと重なる反応だけを飛ばして**埋める。印の順番は変えないので、
    # 締めは書いた人が選んだ一言のまま
    # タイトルは `title` 属性が正。meta に無い書き方の台本もある
    title = str(getattr(script, "title", "") or (script.meta or {}).get("title", "") or "")
    if not title and script.scenes and script.scenes[0].lines:
        # 1行目はタイトルを読む決まりなので、そこからでも拾える
        title = str(script.scenes[0].lines[0].text or "")
    rest = [l for l in rest if not _echoes_title(l.text, title)]
    # 冒頭に上げた反応（`_hoist_voice`）は締めに重ねない
    already = {(l.text or "").strip() for l in short.lines}
    added = 0
    for line in (picked + rest):
        if (line.text or "").strip() in already:
            continue
        if added >= VOICES_TAIL_MAX:
            break
        cost = line.duration or line.estimated_duration()
        if _estimate(short) + cost > target:
            break
        short.scenes[-1].lines.append(copy.deepcopy(line))
        added += 1


def _add_more_body(short: Script, script: Script, max_seconds: float) -> None:
    """**反応が無い回は、続きの節から足して尺を使い切る**（2026-09-20）。

    ユーザー指摘「ショートの内容が薄い、ちゃんと時間使って」。
    締めに足せるのは反応の節だけなので、**コメントが0件の回**
    （紹介もの）は38秒で終わっていた。そういう回は、
    切り出した節の**次の節の語り**を、尺が余っているぶんだけ続ける。

    足すのは語りだけ。**反応の節からは取らない**（それは `_add_voices_tail` の役目）。
    """
    target = max_seconds * ESTIMATE_SLACK
    if _estimate(short) > target - 4:
        return
    body_title = short.scenes[-1].title
    seen = {str(l.text) for l in short.scenes[-1].lines}
    after = []
    passed = False
    for scene in script.scenes[1:]:
        if scene.title == body_title:
            passed = True
            continue
        if passed and not _is_voices_scene(scene):
            after.append(scene)
    for scene in after:
        for line in scene.lines:
            if str(getattr(line, "only", "") or "").strip() == "short":
                continue
            if str(line.text) in seen:
                continue
            cost = line.duration or line.estimated_duration()
            if _estimate(short) + cost > target:
                return
            short.scenes[-1].lines.append(copy.deepcopy(line))
            seen.add(str(line.text))


def _add_subscribe(short: Script) -> None:
    """**最後に登録を頼む一言を足す**（2026-09-15 ユーザー指摘）。

    2026-09-13 にカードを 0 秒にしたのは「3秒の**無音**でスワイプされる」から。
    喋りながら出すなら、その理由には当たらない。2026-09-07 に読み上げを
    やめた理由（毎回同じ文句に8秒）にも、2秒なら当たらない。

    **写真とテロップは前の行のものを引き継ぐ**（画面は止めない）。
    """
    lines = short.scenes[-1].lines
    if not lines:
        return
    if _has_outro(lines):
        return
    for words in (SHORT_SUBSCRIBE, SHORT_SUBSCRIBE_2):
        last = copy.deepcopy(lines[-1])
        last.text = words
        last.speaker = NARRATORS[0]
        last.telop = words
        last.duration = 0.0
        last.audio_path = None
        last.card = "none"
        lines.append(last)


STACK_DIR = Path("assets/images/_stack")


def stacked_photo(meta: dict) -> str:
    """**サムネが2枚並びの回は、ショートでも同じ2枚を出す**
    （2026-09-17 指示「ショートも横割りで本編のサムネと同じようにして」）。

    本編のサムネは左右に割るが、ショートは縦長なので**上下に割る**。
    それまでは `thumbnail_photos` の**1枚目しか出ていなかった**ので、
    鈴木の回はサムネにある人影（＝答えの伏せ字）がショートに出ず、
    同じ回に見えなかった。

    作った1枚は `assets/images/_stack/` に控える（同じ組み合わせなら作り直さない）。
    """
    tiles = [str(x).strip() for x in ((meta or {}).get("thumbnail_photos") or [])]
    tiles = [x for x in tiles if x and Path(x).exists()]
    if len(tiles) < 2:
        return ""
    from PIL import Image

    from .render import _cover

    # **控えの名前は道のり全体から作る**（2026-09-23 指摘「レアルショートの背景が誤っている」）。
    # それまでは「ファイル名の幹」だけで名付けていたので、写真がどの回も `01.jpg` である以上
    # `01__01.jpg` が全部の回でぶつかり、**別の回で作った組写真をそのまま使い回していた**。
    # レアルの回（テバスとペレス）に、まったく別の人が2人映っていた
    digest = hashlib.sha1("|".join(tiles[:3]).encode("utf-8")).hexdigest()[:10]
    name = "__".join(Path(t).stem for t in tiles[:3]) + f"_{digest}.jpg"
    out = STACK_DIR / name
    if out.exists():
        return out.as_posix()
    width, height = SIZE
    band = height // len(tiles[:3])
    canvas = Image.new("RGB", (width, band * len(tiles[:3])), (12, 14, 20))
    for index, tile in enumerate(tiles[:3]):
        with Image.open(tile) as image:
            canvas.paste(_cover(image.convert("RGB"), width, band), (0, band * index))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out, quality=95)
    return out.as_posix()


def _add_face(script: Script) -> None:
    """顔写真を**最初の行から最後まで、全部の行に置く**。

    実測（2026-09-06）で、写真が出るのは平均12秒目、映っているのは全体の
    2割だけだった（ミランは10%、レアルは23秒目から）。
    **ショートは数秒で見るか決められる。**顔が12秒後では、その前に離脱される。

    **写真は「指定した行以降そのまま残る」わけではない。**残るのは
    カードとテロップで、写真は指定した行だけ。最初そう思い込んで先頭にだけ
    置いたところ、5秒出て消えた（実測して分かった）。全部の行に置く。
    """
    # **2枚並びのサムネは、上下に割った1枚にしてから敷く**（2026-09-17 指示）
    photo = stacked_photo(script.meta)
    if not photo:
        photo = str((script.meta or {}).get("thumbnail_photo") or "").strip()
    if not photo:
        photo = next((str(line.image) for line in script.lines if line.image), "")
    if not photo:
        return
    for line in script.lines:
        if not line.image or photo.startswith(STACK_DIR.as_posix()):
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


def subject_problems(short: Script, script: Script) -> list[str]:
    """**ショートが、自分の題名に答えているか**（2026-09-17）。

    同じ日に2回やった。鈴木彩艶の回は題名が「鈴木彩艶が後半から出た試合」なのに、
    ショートの中身は相手選手の経歴だけで、**鈴木の話が1行も入っていなかった**。
    日本代表の回も「名前が消えたのは誰だったか」と聞いて、**誰なのかを一度も
    言わずに**終わっていた。どちらもユーザーが見て気づいた。

    ショートは山場の節しか切り出さない。その節に主語が出てこない台本は普通にある。
    **1行目（題名の読み上げ）を除いて**、題材の名前が一度も出てこなければ知らせる。
    直し方は、その節に `short_only` の行を足すこと。
    """
    topic = str((script.meta or {}).get("topic") or "").strip()
    people = [str(x).strip() for x in ((script.meta or {}).get("people") or []) if str(x).strip()]
    names = [n for n in ([topic] + people) if n]
    if not names:
        return []
    body = [l for l in short.lines if (l.text or "").strip()][1:]
    said = "".join((l.text or "") for l in body)
    if any(name in said for name in names):
        return []
    # **題名にその名前が入っているなら、もう言っている**（2026-09-18 に踏んだ）。
    # ショートの1行目は題名の読み上げなので、視聴者はそこで聞いている。
    # ここを見ずに「本文にも出せ」と求めると、**もう一方の検査と両立しない**——
    # `_advise_short_repeats` は「ショート専用の行が題名と8字以上重なるな」と言う。
    # サンバの回で、題名の「マンチェスター・シティ」を本文に入れれば重複で叱られ、
    # 入れなければ主語なしで叱られ、**どちらにしても直せない**状態になった
    title = str((short.title or script.title or "")).strip()
    if any(name in title for name in names):
        return []
    # **略した呼び方でも通す。**「マンチェスター・シティ」に対する「シティ」など。
    # 略称は**中黒で区切られた一部**を使うことが多いので、そこだけ見る。
    # 部分文字列を総当たりすると「マン」のような短い断片で誤って通る
    for name in names:
        for piece in re.split(r"[・=＝\s]", name):
            if len(piece) >= 3 and piece in said:
                return []
    return [f"ショートの中身に「{names[0]}」が一度も出てきません"
            "（題名だけで、答えが入っていない。山場の節に short_only の行を足す）"]


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
ESTIMATE_SLACK = 0.92


# 情報を持たない「振り」。**発言の直前に置かれ、2〜4秒を使う**
# **「こう」が無い振りもある**（2026-09-18）。「監督が口を開きました。」は
# 何ひとつ言っていないのに、「こう」を含まないので見出し扱いで守られていた。
# 話す動作の言い方を並べる（中身のある行はこの形で終わらない）
_SPEAK = r"(?:こう[^。]{0,8}|口を開き|語り|話し|明かし|続け|答え|振り返っ|述べ|説明し)"
LEAD_IN = re.compile(_SPEAK + r"(?:まし|ていま|いま|ま)す?[た。]?。?$")
# 最初の発言はここまでに出したい（秒）。実測の境目は19秒
# **2026-09-22 に16秒へ**。直近14日・196本の実測で、16秒までに出る60本が
# 維持46.6%、遅い59本が39.8%。超えたら `_hoist_voice` が反応を1件、冒頭に上げる
QUOTE_BY = 16.0


# 振りとして落としてよい長さの上限（2026-09-11）。
# **中身のある行が「こう振り返っています。」で終わることがある。**
# 中村敬斗の回で「17歳で日本を離れ、LASKリンツからランスへ移りました。
# その移籍のときに感じたことを、こう振り返っています。」が丸ごと消え、
# ショートがいきなり発言から始まっていた
LEAD_IN_MAX = 30


def _is_lead_in(line) -> bool:
    text = (getattr(line, "text", "") or "").strip()
    if not text or len(text) > LEAD_IN_MAX:
        return False
    return bool(LEAD_IN.search(text))


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


def _hoist_voice(short: Script, script: Script) -> None:
    """~~言葉が遅いショートは、反応を1件だけ冒頭に上げる~~（2026-09-22 ユーザーOK）

    → **2026-09-23 に取り消した。**ユーザー指摘「最初にネットコメントがあってよく分からん」
    「他のショートもさいしょにネットコメントがあって違和感」。実物を見ると、題の直後に
    前提のない反応が来て、**何の話か分からないまま始まる**（フェランは
    「ペドリになりたい。24時間ずっとフェランの頭の中にいられるんだから」が2行目だった）。

    **言葉を早く出す目的は変わらない**（16秒。維持が7ポイント違う実測がある）。
    直す場所を、ショートの組み立てから**取材メモの側**へ移した。山場の節は
    「状況の1行（`short_only`）→ すぐ本人の言葉」の順で書く。`draft` の
    `_check_quote_timing` が16秒を超えたら止めるので、書くときに気づける。
    """
    return  # 取り消し済み（上の理由）。呼び出しは残してあるので、戻すならこの行を消す
    if str((script.meta or {}).get("short_voices", "")).lower() in ("false", "no", "0"):
        return
    at = quote_at(short)
    # 語りだけの山場（記録・市場価値の回）は at が None。**それこそ上げる相手**
    if at is not None and at <= QUOTE_BY:
        return
    source = _voices_source(short, script)
    if source is None:
        return
    title = str(getattr(script, "title", "") or (script.meta or {}).get("title", "") or "")
    for line in source.lines:
        if str(getattr(line, "only", "") or "").strip() == "short":
            continue
        if getattr(line, "short_voice", False):
            continue          # 締めに取ってある
        if _echoes_title(line.text, title):
            continue
        short.scenes[1].lines.insert(0, copy.deepcopy(line))
        return


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


# 前の行を受ける書き出し。これで始まる行の手前は削らない
REFERRING = ("その", "この", "そこ", "それ", "これ", "そう")


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
        # **発言より先に語りを削る**（2026-09-15 指摘「イラオラの言葉に欠落がある」）。
        # 手前から1行ずつ削っていたので、**監督の3つの発言のうち真ん中が落ちて**
        # いた。CLAUDE.md は「短くするために発言を削るのは本末転倒」と書いている。
        # 語りは包み紙で、発言が中身。**包み紙から捨てる**
        # **見出しになっている語りは削らない**（2026-09-18 ユーザー指摘）。
        # 「語りは包み紙、発言が中身」は正しいが、**包み紙ではない語り**がある。
        # 「二つ目は、バログンの件です」は次の発言が**何の話か**を決めていて、
        # これを抜くと発言が宙に浮く。ヴァツケの回で、
        # 「一つ目は…」「二つ目は…」「三つ目は…」が全部消え、
        # 発言だけが並んで**何の話か分からない**ショートになっていた。
        # **次が発言の語りは飛ばして、そうでない語りから削る**
        cut = None
        for index in range(keep - 1, 0, -1):
            if not _is_narrator(scene.lines[index]):
                continue
            # **ショートのために書いた前置きは削らない**（2026-09-22）。
            # 鈴木彩艶の回で「ヴィラは3対2で勝ったが2点取られた」が消え、
            # 「2失点でもベスト11」の2失点が何のことか分からなくなっていた
            if (getattr(scene.lines[index], "only", "") or "") == "short":
                continue
            # **次の語りが「その」「この」で受けているなら、元の行を残す**。
            # 「2点目は、鈴木が蹴ったボールから」が消え、ショートが
            # 「そのボールが相手陣の深くまで落ち」から始まっていた
            nxt = scene.lines[index + 1] if index + 1 < len(scene.lines) else None
            referred = (nxt is not None and _is_narrator(nxt)
                        and (getattr(nxt, "text", "") or "").lstrip("*").startswith(REFERRING))
            if referred:
                continue
            leads = nxt is not None and not _is_narrator(nxt)
            if leads and not _is_lead_in(scene.lines[index]):
                continue          # 見出し。中身を決めているので残す
            cut = index
            break
        if cut is None:
            # 削れる語りが無い。**次は「2つ目以降の発言」を削る**（2026-09-18）。
            # 見出しと最初の発言を対で捨てると、**後ろに続く同じ人の発言が
            # 宙に浮く**。デ・パウルの回で、紹介ごと落ちたのに発言だけが
            # 2つ残り、誰の言葉か分からないショートになっていた。
            # 一つの話の中で**余っている発言から**削る
            for index in range(keep - 1, 1, -1):
                if (not _is_narrator(scene.lines[index])
                        and not _is_narrator(scene.lines[index - 1])):
                    cut = index
                    break
        if cut is None:
            # それでも足りない。**話ごと（見出し＋続く発言すべて）落とす**
            head = None
            for index in range(keep - 2, 0, -1):
                if (_is_narrator(scene.lines[index])
                        and not _is_narrator(scene.lines[index + 1])):
                    head = index
                    break
            if head is None:
                cut = keep - 1
            else:
                last = head + 1
                while (last + 1 < keep and not _is_narrator(scene.lines[last + 1])):
                    last += 1
                del scene.lines[head + 1:last + 1]
                keep -= last - head
                cut = head
        del scene.lines[cut]
        keep -= 1
        # 代弁を全部落としたあとの「こう話しました。」だけを残さない。
        # **落とすのは振りだけ。**語りをまとめて消していたので、
        # マック・アリスターの回で決勝点の描写ごと消えて27秒になっていた
        # （2026-09-10 に書き出して発見）。尺に収まっていても削っていた
        while keep > 1 and _is_lead_in(scene.lines[keep - 1]):
            del scene.lines[keep - 1]
            keep -= 1
        # **語りが2つ続いたら、前のほうは振りだった**（2026-09-15）。
        # 遠藤の回で「もうひとつ、理由を挙げています。」→（イラオラの発言）→
        # 「そのうえで、こう続けました。」の真ん中だけが尺で落ち、
        # **振りが2つ並んだ。**`LEAD_IN` は「こう」を含む形しか見ないので
        # 素通りしていたが、**語りのあいだに発言が無い**ことは形で分かる。
        # 直前に消したのが発言だったときだけ効かせる（語りの連続を
        # もともと書いている回は触らない）
        while (keep > 1
               and _is_narrator(scene.lines[keep - 1])
               and (getattr(scene.lines[keep - 1], "only", "") or "") != "short"
               and keep < len(scene.lines)
               and _is_narrator(scene.lines[keep])):
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


# **TikTok 用は1分を超える**（2026-09-16 ユーザー決定「上限は60秒以上でよい」）。
# TikTok の Creator Rewards Program は「1分以上のオリジナル作品」だけが対象で、
# YouTube ショート（58秒で切る）はそのまま上げても1本も数えられない。
# 下限は60秒ちょうどにしない。書き出すまで実尺が分からず、見積りはぶれる
TIKTOK_MIN_SECONDS = 62.0
# **見積りは実尺より長く出る**（2026-09-16 実測）。板倉の回は見積り54秒に対して
# 書き出したら48秒だった。ショートは話速を1.1倍にしているぶん、文字数からの
# 見積りが実尺を上回る。足りるかどうかは、この比で割り戻してから見る
TIKTOK_ESTIMATE_RATIO = 0.89
# 上は決めない、というのがユーザーの判断。ただ**引き延ばしにしない**ため、
# 足すのは台本に書いてある節と反応だけで、同じ台本の中身が尽きたらそこで止める
TIKTOK_MAX_SECONDS = 90.0
TIKTOK_VOICES_MAX = 6
# **TikTok の締めはYouTubeへ送る**（2026-09-16 ユーザー「tiktokからyoutubeへの流れを
# 作りたい」）。TikTok は説明欄のリンクを押せないので、**声で名前を言う**しかない。
# ショートの締め（チャンネル登録の依頼）と入れ替える
TIKTOK_OUTRO = "続きは、ユーチューブの海外サッカーの理由で。"


def tiktok_cut(script: Script, section: str = "") -> Script:
    """ショートと同じ作りで、1分を超える縦動画にする。

    まずショートと同じく「冒頭＋山場の節」を作り、足りなければ次の順で足す。

    1. 反応をもう何件か（ショートは3件まで。TikTok は6件まで）
    2. 山場の**手前の節**（何があったか）。足したら、山場の節に書いてある
       ショート専用の前置きは外す（手前の節と同じことを二度言うため）
    3. 山場の**うしろの節**（反応の節は1で使うので除く）

    **台本に無いことは足さない。**尽きても1分に届かなければ、そのまま返す
    （書き出したあとに `_cmd_short` が止める）。
    """
    cut = trim(script, section, max_seconds=TIKTOK_MAX_SECONDS)
    need = TIKTOK_MIN_SECONDS / TIKTOK_ESTIMATE_RATIO

    def enough() -> bool:
        return _estimate(cut) >= need

    def before_subscribe(line) -> None:
        lines = cut.scenes[-1].lines
        at = len(lines) - _outro_count(lines)
        lines.insert(at, copy.deepcopy(line))

    body_title = cut.scenes[-1].title
    content = [sc for sc in script.scenes[1:] if not _is_voices_scene(sc) and sc.title != "まとめ"]
    index = next((i for i, sc in enumerate(content) if sc.title == body_title), None)

    # 2. 節を足すときは**山場のうしろへ**（2026-09-16）。
    # 最初は手前に挟んでいたが、山場が後ろへ動いて最初の発言が16〜17秒目に
    # なった（ロドリ・キャラガーで実測）。**発言が遅いとその前に離脱する。**
    # うしろに置くので、締めの「チャンネル登録」は足し直して最後に戻す
    def add_scene(scene: Scene) -> None:
        lines = cut.scenes[-1].lines
        if _has_outro(lines):
            lines.pop()
        cut.scenes.append(copy.deepcopy(scene))
        _add_subscribe(cut)

    if index is not None:
        rest = content[index + 1:] + list(reversed(content[:index]))
        for scene in rest:
            if enough():
                break
            add_scene(scene)

    # **ネットの声は最後**（2026-09-16 ユーザー指摘「流れは、ネットの声は最後」）。
    # 節を足すと、先に入れた反応が途中に挟まってしまう。**節を全部足してから**、
    # いったん反応を抜いて、いちばん後ろへ置き直す
    source = _voices_source(cut, script)
    # 動かすのは**反応の節から来た行だけ**。記者や監督の引用は動かさない
    voiced = {(l.text or "").strip()
              for sc in script.scenes if _is_voices_scene(sc) for l in sc.lines}
    crowd = [l for l in cut.lines if (l.text or "").strip() in voiced]
    for scene in cut.scenes:
        scene.lines = [l for l in scene.lines if l not in crowd]
    for line in crowd:
        before_subscribe(line)
    if source is not None:
        have = {(l.text or "").strip() for l in cut.lines}
        added = len(crowd)
        for line in source.lines:
            if enough() or added >= TIKTOK_VOICES_MAX:
                break
            if (line.text or "").strip() in have:
                continue
            before_subscribe(line)
            added += 1

    # 締めの一言を、YouTubeへ送る文に差し替える
    lines = cut.scenes[-1].lines
    if _has_outro(lines):
        # TikTok は行き先が違う。**締めの2行をまとめて差し替える**
        for _ in range(_outro_count(lines)):
            lines.pop()
        tail = copy.deepcopy(lines[-1])
        tail.text = TIKTOK_OUTRO
        tail.telop = TIKTOK_OUTRO
        tail.speaker = NARRATORS[0]
        tail.duration = 0.0
        tail.audio_path = None
        tail.card = "none"
        lines.append(tail)
        lines[-1].audio_path = None
        lines[-1].duration = 0.0

    _add_face(cut)
    return cut


def tiktok_path(script_path: str | Path) -> Path:
    return Path(f"output/{Path(script_path).stem}_tiktok")


def default_path(script_path: str | Path) -> Path:
    return Path(f"output/{Path(script_path).stem}_short")


def _introduces(lines, index: int) -> bool:
    """`index` の行は**直前の語りに紹介された発言**か。

    「二つ目は、バログンの件です」→「大統領が電話をかけ…」のような対。
    発言だけ残すと**何の話か分からなくなる**ので、対ごと落とす。
    直前がもっと前の発言に続く語り（別の対の一部）なら、そこは切らない。
    """
    if index < 1 or index >= len(lines):
        return False
    here = (getattr(lines[index], "speaker", "") or "").strip()
    before = (getattr(lines[index - 1], "speaker", "") or "").strip()
    # 落とすのが発言で、その直前が語りなら対とみなす
    if here in NARRATORS or before not in NARRATORS:
        return False
    # **節の1行目は残す。**そこを抜くと話の入口が消える
    return index - 1 > 0


def enforce_limit(script: Script, max_seconds: float, config) -> int:
    """**音声を作ったあと、実尺で上限に収める**（2026-09-16）。

    それまでは文字数からの見積りに安全率（`ESTIMATE_SLACK`）を掛けて
    手前で切っていた。**見積りは当てにならない。**直近5本の実測では
    実尺／見積りが 0.923〜1.073 とばらつき、古い記録では 56秒の見積りが
    66秒になっている。安全率を厳しくすると短くなりすぎ（43〜46秒）、
    緩めると上限を超える。**どちらも直らない。**

    合成が終われば1行ずつの秒数が分かる。ここで**足りなければ落とす**。
    落とすのは後ろから（＝ネットの声から）で、**締めの一言は残す。**
    """
    from . import inserts as inserts_mod

    dropped = 0
    while True:
        total = (sum(line.duration or 0.0 for line in script.lines)
                 + inserts_mod.plan(script, config).total)
        if total <= max_seconds:
            return dropped
        lines = script.scenes[-1].lines
        # **締めは2行ある**（2026-09-18 に1行から増やした）。1行ぶんしか
        # 守っていなかったので、**「本編はチャンネルから見られます」が先に落ちて**、
        # 残るのは「チャンネル登録もお願いします」だけになっていた。
        # ユーザー指摘「ショートの最後がチャンネル登録お願いだけになってる」。
        # **かたまりごと守る**
        keep = _outro_count(lines)
        index = len(lines) - (keep + 1)
        if index < 1:
            return dropped          # これ以上は削れない。呼んだ側が止める
        # **見出しと発言は対で落とす**（2026-09-18 ユーザー指摘。ヴァツケの回で
        # 「一つ目は…」「二つ目は…」だけが消え、**発言が宙に浮いていた**）。
        # 1行ずつ後ろから抜くので、語りだけが先に消えて
        # 「二つ目についての発言」が、何の二つ目か分からないまま流れる。
        # 落とす行が発言なら、**その直前の語り（振り）も一緒に**落とす
        take = [index]
        if _introduces(lines, index):
            take.insert(0, index - 1)
        for at in reversed(take):
            lines.pop(at)
            dropped += 1
