"""作る前の点検。素材の有無・台本の書きすぎ・読みの確認・抑揚の張りつき・1本ぶんの決まり。

どれも音声や画面を作る前に安く見つけられるもの。作ってから気づくと、作り直しに時間がかかる。
結果は report() が「止めるもの（×）→ 直すと効くもの（!）→ 参考（・）」の順に並べ、
同じ種類の知らせは1件にまとめて行の番号を並べる（10-08。1本に数十件出て読まれなくなっていた）。
"""
from __future__ import annotations

import re

from pathlib import Path

from .voice import TONES, display_text

# --- 目安の数字（10-08 に1か所へ集めた。style.py・reaction.py・hooks.py・assign.py・qc.py もここを読む）------------
# 台本
LINE_WARN = 90           # 1行のせりふがこれより長いと、字幕が3枚以上に分かれて追いにくい
CARD_BODY_WARN = 22      # 札の本文がこれより長いと、メモ欄からはみ出しやすい
CHARS_PER_SEC = 7.0      # 合成音声のおおよその速さ（字／秒）。ショートの長さ・画面の替わりの見積もりに使う
HOOK_WINDOW = 2          # 節の終わりから何行以内に「引き」（hook: true）を置くか
MIN_FIGURES = 3          # 図（地図・グラフ・相関図…）を1本に3つ以上
# 声
SPEED_WARN = 1.2         # これより速いと早口に聞こえる
# 画面の替わり方（10-07。信長の回で同じ絵が2分前後動かない区間が6か所あった）
BG_MAX_SEC = 40.0        # 同じ背景の絵は長くても40秒まで
NOVELTY_MAX_SEC = 20.0   # 20秒に1回は新しいもの（絵・札・図・挿絵・肖像）。知らせるのは2倍（40秒）を超えたとき
REACTION_MAX = 2         # つむぎの寄り（reaction）は1本に2回まで
# 掛け合い（10-04・10-07）
HOST_SHARE_MAX = 0.70    # 剣崎の字数の割合（10-07 の5本は72〜79%で講義に近かった）
# 文体（10-08、chiso/style.py。既存6本に掛けて決めた）
ENDING_RUN = 4           # 剣崎の同じ語尾がこの数だけ続いたら知らせる
PHRASE_LEN = 8           # この字数以上の言い回しを数える
PHRASE_TIMES = 4         # 1本の中でこの回数以上出たら知らせる
HEAD_TIMES = 3           # つむぎの返しが「え、」「へえ、」で始まるのが1節にこの回数以上
COMMAS_MAX = 5           # 1文の読点がこの数以上なら長い
COMMAS_LONG = 4          # 読点がこの数で、
LONG_CHARS = 60          # この字数以上の文も長いと数える
# ショート（10-08：頭の問い hook と最後の問い tease も声で読むので、字数に含めて数える）
SHORT_CHARS_MAX = 360    # 本文＋hook＋tease の字数の目安の上限（約60秒。7字／秒＋間＋最後の画面）
SHORT_CHARS_MIN = 200    # これより短いと、本編へ誘う前に話が立たない
# サムネイル
THUMB_HOOKS_MAX = 2      # 引きの要素（reactor・hide・contrast・flip・flash）は1枚にこの数まで


def missing_assets(script, assets: Path) -> list[str]:
    """台本が使う絵のうち、置き場に無いもの。"""
    import json
    used = set()
    for line in script.lines:
        for pic in (line.background, line.portrait):
            if pic is not None:
                used.add(pic.image)
        fig = json.loads(line.figure) if getattr(line, "figure", None) else {}
        if fig.get("type") == "versus":                        # 左右比べの絵（10-07）
            used.update(str(fig[k]["image"]) for k in ("left", "right") if fig.get(k, {}).get("image"))
        if getattr(line, "detail", None):                      # 絵の一部を大きく（10-07）
            used.add(json.loads(line.detail)["image"])
    thumb = getattr(script, "thumbnail", None) or {}
    if thumb.get("layout"):                                    # 構図を選んだサムネイルの絵（10-07。classic は今までどおり見ない）
        used.update(str(v) for v in [thumb.get("image")] + [(thumb.get(k) or {}).get("image") if isinstance(thumb.get(k), dict) else None
                                                           for k in ("left", "right")] if v)
        c = thumb.get("cutout")                                # 手で抜いた人物の絵（透明 PNG）
        if isinstance(c, str) or (isinstance(c, dict) and c.get("image")):
            used.add(str(c if isinstance(c, str) else c["image"]))
    return sorted(p for p in used if not (assets / p).exists())


def lint(script, short_limit: float = 60.0) -> list[str]:
    """書きすぎ・長すぎの注意。止めはしない（直すかどうかは人が決める）。"""
    warns = []
    for line in script.lines:
        n = len(display_text(line.text))
        if n > LINE_WARN:
            warns.append(f"{line.index + 1}行目：せりふが{n}字（{LINE_WARN}字まで推奨）")
        if line.card is not None and len(line.card.body or "") > CARD_BODY_WARN:
            warns.append(f"{line.index + 1}行目：札の本文が{len(line.card.body)}字（{CARD_BODY_WARN}字まで推奨）")
    for sid, meta in script.shorts.items():
        body = sum(len(display_text(l.text)) for l in script.short_lines(sid))
        extra = sum(len(display_text(str((meta or {}).get(k) or "").replace("／", ""))) for k in ("hook", "tease"))
        chars = body + extra
        est = chars / CHARS_PER_SEC
        if chars > SHORT_CHARS_MAX or est > short_limit:
            warns.append(f"ショート {sid}：本文＋問いで{chars}字・見積もり約{est:.0f}秒"
                         f"（{SHORT_CHARS_MAX}字・{short_limit:.0f}秒まで）")
        elif body and body < SHORT_CHARS_MIN:
            warns.append(f"ショート {sid}：本文が{body}字（{SHORT_CHARS_MIN}字くらいから）")
        # 見立ての「段階N」の札は、ショート単体では唐突（10-06 ナポレオン s10）。札は次に替えるまで続くので、
        # 行ごとに出すと同じ札で5〜6件並んだ（10-08）。札ごとに1件
        staged: dict[str, list[int]] = {}
        for l in script.short_lines(sid):
            if l.card is not None and l.card.head.startswith("段階"):
                staged.setdefault(l.card.head, []).append(l.index + 1)
        for head, rows in staged.items():
            warns.append(f"ショート {sid}：「{head}」の札が出ます {span(rows)}行目（札をショートに入れない行に移す）")
    return warns


def span(rows: list[int]) -> str:
    """行の番号の並びを短く（[3, 4, 5, 9] → 「3〜5・9」）。"""
    out, start, prev = [], None, None
    for r in sorted(set(rows)):
        if start is None:
            start = prev = r
        elif r == prev + 1:
            prev = r
        else:
            out.append(f"{start}〜{prev}" if prev != start else str(start))
            start = prev = r
    if start is not None:
        out.append(f"{start}〜{prev}" if prev != start else str(start))
    return "・".join(out)


# --- 知らせの並べ方（10-08）-----------------------------------------------------------
# 既存7本で1本28〜44件の「!」が出て、読まれなくなっていた。同じ種類をまとめ、効くものから並べる。
REFERENCE = ("文体：", "章の題に", "《》の強調が", "サムネイルの落差の二語", "サムネイルの隠した")  # 参考（直すかは内容しだい）
_ROW = re.compile(r"(\d+(?:〜\d+)?)行目")


def report(errors: list[str], warns: list[str]) -> list[str]:
    """点検の結果を、止めるもの（×）→ 直すと効くもの（!）→ 参考（・）の順に。
    行の番号だけが違う同じ種類の知らせは1件にまとめ、番号を並べる（「1・13・31行目から同じ背景が…［3か所］」）。"""
    def fold(items: list[str]) -> list[str]:
        groups: dict[str, list[str]] = {}
        for w in dict.fromkeys(items):                         # 全く同じ知らせは1つに
            key = re.sub(r"\d+", "#", _ROW.sub("@", w))
            groups.setdefault(key, []).append(w)
        out = []
        for members in groups.values():
            if len(members) == 1 or not _ROW.search(members[0]):
                out += members
                continue
            rows = [_ROW.search(m).group(1) for m in members]
            rest = [_ROW.sub("@", m, count=1) for m in members]
            if len(set(rest)) == 1:                           # 行の番号だけが違う
                text = rest[0].replace("@", "・".join(rows) + "行目", 1)
            else:                                             # ほかの数（字数など）も違う：行ごとに添える
                parts = [re.split(r"(\d+)", r) for r in rest]
                same = [all(p[i] == parts[0][i] for p in parts) if all(len(p) == len(parts[0]) for p in parts) else False
                        for i in range(len(parts[0]))]
                if not all(len(p) == len(parts[0]) for p in parts) or not all(_ROW.match(m) for m in members):
                    out += members                            # 行の番号で始まる知らせだけをまとめる
                    continue
                vary = [i for i, ok in enumerate(same) if not ok]
                body = "".join(x if same[i] else "…" for i, x in enumerate(parts[0]))
                each = "・".join(f"{r}行目（{'/'.join(p[i] for i in vary)}）" for r, p in zip(rows, parts))
                text = body.replace("@", "", 1).lstrip("：") + "：" + each
            out.append(f"{text}［{len(members)}か所］")
        return out
    fix = [w for w in warns if not w.startswith(REFERENCE)]
    ref = [w for w in warns if w.startswith(REFERENCE)]
    return ([f"× {e}" for e in fold(errors)] + [f"! {w}" for w in fold(fix)] + [f"・{w}" for w in fold(ref)])


def saturation(script, voices: dict) -> dict[str, tuple[int, int]]:
    """話者ごとに、抑揚が声のソフトの上限を超えた行・早口になった行の数（該当行, 全行）。

    2026-10-04、つむぎの99行中64行で抑揚が上限2.0に張りつき、キンキンした声になっていた。
    """
    out: dict[str, list[int]] = {}
    for line in script.lines:
        v = voices.get(line.speaker)
        if v is None:            # roles に無い人物（preflight が別に止める）
            continue
        t = TONES[line.tone]
        raw_int = v.intonation * (1 + (t.get("intonation", 1.0) - 1) * v.tone_strength)
        raw_speed = v.speed * (1 + (t.get("speed", 1.0) - 1) * v.tone_strength)
        # 話者ごとに置いた上限（控えめにするためのもの）は狙いどおりなので数えない。
        # 声のソフト自体の上限（抑揚2.0）か、早口（1.2倍超）に当たったものだけ数える
        hit = raw_int > 2.0 or raw_speed > SPEED_WARN
        c = out.setdefault(line.speaker, [0, 0])
        c[0] += int(hit)
        c[1] += 1
    return {k: (a, b) for k, (a, b) in out.items()}




def episode(script) -> tuple[list[str], list[str]]:
    """1本ぶんの決まり。(止めるもの, 知らせるもの) を返す。"""
    import json
    errors, warns = [], []
    last = script.sections[-1].title if script.sections else ""
    if not ("まとめ" in last or "見立て" in last):        # 10-07 から人物・出来事を掘る形。最後は「まとめ：…」（前の回の「見立て」も通す）
        errors.append("最後の節は「まとめ：…」にする（その人・出来事は何だったのか）")
    if not script.next:
        errors.append("次回予告（next: {title, teaser}）がありません")
    if not script.thumbnail:
        errors.append("サムネイル（thumbnail:）がありません")
    else:                                                  # hook・stamp は任意（10-07、通説を打ち消す形をやめた）
        from . import thumb
        errors += thumb.problems(script.thumbnail)         # 構図（layout）の名前と、構図ごとに要る項目
        from . import hooks
        warns += hooks.notes(script.thumbnail)             # 引きの要素（10-08）：隠し・落差は本編で答えが出るか、反転の注意、盛りすぎ
    # 節の終わりの引き（10-04）：途中で見るのをやめる人を減らすため、次の節が気になる一言で締める。
    # 最初の節（導入。冒頭の問いが引きを兼ねる）と最後の節（見立て。次回予告で締める）は除く
    for sec in script.sections[1:-1]:
        tail = [l for l in script.lines if l.section == sec.index][-HOOK_WINDOW:]
        if not any(l.hook for l in tail):
            errors.append(f"{sec.index + 1}節「{sec.title}」の終わり{HOOK_WINDOW}行に引き（hook: true）がありません")
    e2, w2 = cast_rules(script)
    errors += e2
    warns += w2
    warns += pacing(script)
    from .figures import base_key
    figs = {base_key(l.figure): l.figure for l in script.lines if l.figure}.values()   # 1項目ずつ増やす図（upto）は1つと数える
    if len(figs) < MIN_FIGURES:
        warns.append(f"図（地図・グラフ・相関図）が{len(figs)}つ（{MIN_FIGURES}つ以上を推奨）")
    from . import figures
    for f in figs:
        spec = json.loads(f)
        if spec["type"] == "map":
            try:
                figures.with_places(spec)
            except ValueError as e:
                errors.append(f"地図「{spec.get('title', '')}」: {e}")
    from . import extras
    for l in script.lines:
        if l.bubble and (l.portrait is None or l.figure):
            warns.append(f"{l.index + 1}行目：吹き出しは肖像が出ているときだけ出ます（いまは出ません）")
    for l in script.lines:
        if getattr(l, "detail", None) and l.icon:
            warns.append(f"{l.index + 1}行目：絵の一部（detail）と挿絵（icon）が同じ行にあります（挿絵は出ません）")
        if getattr(l, "mark", None) and not getattr(l, "detail", None) and not l.figure and l.portrait is None                 and (l.icon or l.background is None):
            warns.append(f"{l.index + 1}行目：赤ペン（mark）を乗せる絵・図がありません（出ません）")
    warns += combo_rules(script)
    for name in sorted({l.icon for l in script.lines if l.icon}):
        if name not in extras.known_icons():
            errors.append(f"挿絵の名前が分かりません: {name}")
    warns += reaction_rules(script)
    warns += opening_rules(script)
    warns += short_opening_rules(script)
    warns += short_question_rules(script)
    warns += chapter_titles(script)
    from . import match                                    # 話と画面の一致（10-08 ユーザー指摘「会話している内容と画面の内容が合ってない」）
    warns += match.notes(script)
    from . import style                                    # 文体（10-08）：AIらしく聞こえる語尾・言い回し・書き言葉
    warns += style.notes(script, name_words(script))
    if not any("《" in l.text for l in script.lines):
        warns.append("《》の強調が1つもありません")
    if not script.shorts:
        warns.append("ショート（shorts:）がありません")
    return errors, warns


def combo_rules(script) -> list[str]:
    """道具どうしが同じ行で重なり、片方が出ないもの（10-08、見本の台本 _showcase.yaml の通し確認で洗い出した）。
    画面はどれか1つを優先して描く：寄り（reaction）→ 絵の一部（detail）→ 図（figure）→ 肖像・挿絵・額。"""
    out = []
    for l in script.lines:
        n = l.index + 1
        if getattr(l, "detail", None) and l.figure:
            out.append(f"{n}行目：絵の一部（detail）と図（figure）が同じ行にあります（図は出ません）")
        if l.icon and l.figure and not getattr(l, "detail", None):
            out.append(f"{n}行目：図が出ている行の挿絵（icon）は出ません（figure: null のあとに置く）")
        if getattr(l, "reaction", None) and (l.bubble or l.icon or getattr(l, "detail", None)):
            out.append(f"{n}行目：つむぎの寄り（reaction）の行では、吹き出し・挿絵・絵の一部は出ません")
    return out


def reaction_rules(script) -> list[str]:
    """つむぎの寄り（reaction）は1本に2回まで（10-07。毎回使うと安くなる）。続けて同じ寄りを書いた行は1回と数える。"""
    MAX_PER_EPISODE = REACTION_MAX
    runs, prev = [], None
    for l in script.lines:
        r = getattr(l, "reaction", None)
        if r and r != prev:
            runs.append(l.index + 1)
        prev = r
    if len(runs) > MAX_PER_EPISODE:
        return [f"つむぎの寄り（reaction）が{len(runs)}回 {runs}（1本{MAX_PER_EPISODE}回まで。数字の山場だけに）"]
    return []


# --- 2人のキャラと会話の流れ（2026-10-04 にユーザーと決めた） ---------------------------
# つむぎ：ふだん軽い話し言葉、驚くと素が出る。一人称「あーし」は節に1回くらい。剣崎を「剣崎さん」と呼ぶ。
# 剣崎：落ち着いた丁寧語。つむぎを「つむぎさん」と呼ぶ。素性（付喪神・3600歳）は語らない。
# 進行役はいつも剣崎（10-04「いつも剣崎でお願いします」）。締めは剣崎「今日の地層は、ここまでです」→ 次回の通説 → 二人「また一緒に、掘りましょう！」
HOST = "語り"            # 進行役は剣崎に固定
CLOSING = "また一緒に、掘りましょう"
HOST_CLOSE = "今日の地層は、ここまでです"
PARROT_MAX = 2          # 1節の中で、驚くだけの短い返し（おうむ返し）の上限
SIGH_RUN_MAX = 1        # 「……」で終わるつむぎの感想が続いてよい数（手引き「2回続けない」。10-05 に2→1）
ASHI_MAX = 2            # 1節の「あーし」の上限（目安は1回）
POLITE = re.compile(r"(ですか|ですね|ですよね|でした|ました|ます|ません|でしょうか)(?=[。？！?!、…\s]|$)")   # 文の切れ目の丁寧語だけ（「だました側」は数えない）


def cast_rules(script) -> tuple[list[str], list[str]]:
    import re
    errors, warns = [], []
    host = HOST
    lines = script.lines
    if lines and lines[0].speaker != host:
        errors.append("最初の行は進行役の剣崎（語り）が話す")
    if not lines or lines[-1].speaker != "二人" or CLOSING not in lines[-1].text:
        errors.append(f"最後の行は二人で「{CLOSING}！」")
    if not any(HOST_CLOSE in l.text and l.speaker == host for l in lines):
        errors.append(f"締めに剣崎の「{HOST_CLOSE}」がありません")
    for l in lines:
        if re.search(r"めすお|べっつー", l.text):
            errors.append(f"{l.index + 1}行目：呼び方は「剣崎さん」「つむぎさん」（公式のあだ名は使わない）")
        if re.search(r"付喪神|3600歳|メスの", l.text):
            warns.append(f"{l.index + 1}行目：剣崎の素性は語らない決まり")
    for a, b in zip(lines, lines[1:]):
        if a.speaker == b.speaker == "聞き":      # 掛け合いが崩れる（10-04 Gemini の指摘）。1行にまとめるか剣崎の返しを挟む
            warns.append(f"{a.index + 1}〜{b.index + 2}行目：つむぎが2行続いています")
    for sec in script.sections:
        mine = [l for l in lines if l.section == sec.index and l.speaker == "聞き"]
        parrot = [l for l in mine if l.tone == "驚き" and len(re.sub(r"[《》！？!?…、。]", "", l.text)) <= 8]
        if len(parrot) > PARROT_MAX:
            warns.append(f"{sec.index + 1}節：つむぎの驚くだけの返しが{len(parrot)}回（{PARROT_MAX}回まで。予想・疑い・置き換えに変える）"
                         f" {[l.index + 1 for l in parrot]}")
        ashi = sum(l.text.count("あーし") for l in mine)
        if ashi > ASHI_MAX:
            warns.append(f"{sec.index + 1}節：「あーし」が{ashi}回（節に1回くらい）")
        run = 0
        for l in mine:
            run = run + 1 if re.search(r"…+[。！？]?$", l.text) else 0
            if run == SIGH_RUN_MAX + 1:
                warns.append(f"{l.index + 1}行目：「……」で終わるつむぎの感想が{run}回続いています")
        polite = [l.index + 1 for l in mine if POLITE.search(l.text)]
        if polite:
            warns.append(f"{sec.index + 1}節：つむぎが丁寧語 {polite}（ふだんは軽い話し言葉）")
    return errors, warns


# --- 画面の替わり方（10-07）：信長の回で同じ絵が2分前後動かない区間が6か所あった。
#     伸びている歴史動画を18本調べた上で、目安を数字にした。行の秒数は字数から見積もる。


def _new_mark(line, prev_mark) -> bool:
    """この行で赤ペンの印が新しく足されたか（10-07。絵の一部・赤ペンも「新しいもの」と数える）。"""
    from .pen import spec_of
    mark = getattr(line, "mark", None)
    if not mark or mark == prev_mark:
        return False
    items, start = spec_of(mark)
    return len(items) > start


def pacing(script) -> list[str]:
    warns = []
    def sec(l):
        return len(display_text(l.text)) / CHARS_PER_SEC + 0.6
    bg_t = nov_t = 0.0
    prev = None
    bg_start = nov_start = None
    reported_bg = reported_nov = False
    for l in script.lines:
        bg = l.background.image if l.background else None
        new_bg = prev is None or bg != prev.get("bg") or l.section != prev.get("sec")
        new_thing = (new_bg or (l.card is not None and l.card != prev.get("card"))
                     or bool(l.figure and l.figure != prev.get("fig"))
                     or bool(getattr(l, "icon", None)) or (l.portrait is not None and l.portrait != prev.get("por"))
                     or bool(getattr(l, "reaction", None))
                     or bool(getattr(l, "detail", None) and l.detail != prev.get("det"))
                     or _new_mark(l, prev.get("mark")))
        if new_bg:
            bg_t, bg_start, reported_bg = 0.0, l, False
        if new_thing:
            nov_t, nov_start, reported_nov = 0.0, l, False
        bg_t += sec(l)
        nov_t += sec(l)
        if bg_t > BG_MAX_SEC and not reported_bg:
            warns.append(f"{bg_start.index + 1}行目から同じ背景が{BG_MAX_SEC:.0f}秒を超えます（場面ごとに絵を替える）")
            reported_bg = True
        if nov_t > NOVELTY_MAX_SEC * 2 and not reported_nov:
            warns.append(f"{nov_start.index + 1}行目から{NOVELTY_MAX_SEC * 2:.0f}秒以上、画面に新しいものが出ません（札・図・挿絵・絵）")
            reported_nov = True
        prev = {"bg": bg, "sec": l.section, "card": l.card, "fig": l.figure, "por": l.portrait,
                "det": getattr(l, "detail", None), "mark": getattr(l, "mark", None)}
    total = sum(len(display_text(l.text)) for l in script.lines) or 1
    host = sum(len(display_text(l.text)) for l in script.lines if l.speaker == "語り")
    if host / total > HOST_SHARE_MAX:
        warns.append(f"剣崎の字数が{host * 100 // total}%（{HOST_SHARE_MAX:.0%}まで。つむぎにも事実を言わせる）")
    return warns


# --- 冒頭とショートの出だし（10-07）---------------------------------------------
# 伸びている歴史の長尺18本の調べ（research/benchmark_long.md）：冒頭15秒でいちばん重い事実を1文。
# ショートは最初の2秒で誰の何の話か分からないと流される。どちらも知らせるだけで止めない。
OPENING_LINES = 4        # 冒頭15秒 ≒ 最初の4行
OPENING_CHARS = 100      # ≒ 15秒 × 7字／秒
_KANSUJI = "〇一二三四五六七八九十百千万億"
COUNTERS = ("人", "年", "歳", "日", "か月", "ヶ月", "月", "万", "億", "回", "代", "石", "両", "里", "倍", "割",
            "枚", "隻", "本", "つ", "度", "時間", "分", "秒", "キロ", "メートル", "円", "文", "貫", "通", "か国", "カ国")
_FACT = re.compile(r"[0-9０-９]|[" + _KANSUJI + r"]+(?:" + "|".join(COUNTERS) + r")")
WEAK_STARTS = ("そして", "しかも", "それ", "でも", "はい")


def has_number(text: str) -> bool:
    """数字・年・数（「四十七人」「三日」のような漢数字＋数え方）が入っているか。"""
    return bool(_FACT.search(display_text(text)))


def name_words(script) -> list[str]:
    """台本の人物の呼び方：people: の名前と言い換え・サムネイルの名前・題名の頭の名前。
    4字の漢字の名前は、名字と名前の2字ずつも（「信長」「明智」）。"""
    out: list[str] = []
    for name, v in (getattr(script, "people", None) or {}).items():
        out += [name] + list(v.get("match", []))
    thumb = getattr(script, "thumbnail", None) or {}
    if thumb.get("name"):
        out.append(str(thumb["name"]))
    more = []
    for n in out:
        if re.fullmatch(r"[一-鿿]{4}", n):
            more += [n[:2], n[2:]]
    head = re.sub(r"^[「『][^」』]*[」』]", "", getattr(script, "title", "") or "")
    m = re.match(r"(.+?)(?:とは|は|の|、|｜|「|$)", head)
    if m and len(m.group(1)) >= 2:
        out.append(m.group(1))
    return list(dict.fromkeys(w for w in out + more if len(w) >= 2))


def has_name(text: str, names: list[str]) -> bool:
    plain = display_text(text)
    return any(n in plain for n in names)


def opening_rules(script) -> list[str]:
    """冒頭15秒（最初の4行・約100字）に、数字・年・人名などの具体的な事実が入っているか。"""
    window, chars = [], 0
    for l in script.lines[:OPENING_LINES]:
        if chars >= OPENING_CHARS:
            break
        window.append(l)
        chars += len(display_text(l.text))
    names = name_words(script)
    if window and not any(has_number(l.text) or has_name(l.text, names) for l in window):
        return [f"冒頭15秒（最初の{len(window)}行・{chars}字）に数字・年・人名がありません"
                "（冒頭15秒でいちばん重い事実を1文）"]
    return []


def short_opening_rules(script) -> list[str]:
    """ショートの1行目：つなぎの言葉で始まらないこと、名前か数字が入っていること（最初の2秒で何の話か分かるように）。
    同じ種類はショートをまとめて1件に（10-08。1本に5件並んだ）。"""
    weak, bare = [], []
    names = name_words(script)
    for sid in getattr(script, "shorts", {}) or {}:
        lines = script.short_lines(sid)
        if not lines:
            continue
        first = lines[0]
        plain = display_text(first.text).lstrip("「『（ 　")
        head = next((w for w in WEAK_STARTS if plain.startswith(w)), None)
        if head:
            weak.append(f"{sid}（{first.index + 1}行目「{head}」）")
        elif not (has_number(first.text) or has_name(first.text, names)):
            bare.append(f"{sid}（{first.index + 1}行目）")
    warns = []
    if weak:
        warns.append(f"ショートの1行目がつなぎの言葉で始まります：{'・'.join(weak)}（単体で見ると前が無い。最初の2秒で何の話か分かる一言に）")
    if bare:
        warns.append(f"ショートの1行目に名前も数字もありません：{'・'.join(bare)}（最初の2秒で誰の何の話か分かるように）")
    return warns


def _hira(text: str) -> str:
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in text)


_NOUN = re.compile(r"[一-鿿々〆ヵヶ]{2,}|[ァ-ヴー]{2,}|[A-Za-z0-9]{2,}")
_QUOTED = re.compile(r"[『「](.+?)[』」]")


def question_nouns(text: str) -> list[str]:
    """問いの中の名詞らしい語（かっこの中・2字以上の漢字・カタカナ・英数字）。ひらがなは拾わない（形態素解析は入れていない）。"""
    plain = display_text(str(text).replace("／", ""))
    out = [q for q in _QUOTED.findall(plain)]
    for q in list(out):
        out += _NOUN.findall(q)
    out += _NOUN.findall(_QUOTED.sub(" ", plain))
    return list(dict.fromkeys(w for w in out if w))


def short_question_rules(script) -> list[str]:
    """ショートの頭の問い（hook）と最後の問い（tease）（10-08 ユーザー決定）。
    無い・？で終わらない・同じ問い・tease の語が本編の台本に見当たらない（答えが本編に無さそう）を知らせる。
    既存の台本には無いので × にはしない。"""
    lacks, notq, same, noans = [], [], [], []
    for sid, meta in (getattr(script, "shorts", {}) or {}).items():
        meta = meta or {}
        hook = str(meta.get("hook") or "").replace("／", "").strip()
        tease = str(meta.get("tease") or "").replace("／", "").strip()
        miss = [k for k, v in (("hook", hook), ("tease", tease)) if not v]
        if miss:
            lacks.append(f"{sid}（{'・'.join(miss)}）")
        bad = [k for k, v in (("hook", hook), ("tease", tease)) if v and not v.endswith(("？", "?"))]
        if bad:
            notq.append(f"{sid}（{'・'.join(bad)}）")
        if hook and tease and display_text(hook) == display_text(tease):
            same.append(sid)
        if tease:
            rest = _hira("".join(display_text(l.text) for l in script.lines if sid not in l.shorts))
            words = question_nouns(tease)
            if not words or not any(_hira(w) in rest for w in words):
                noans.append(f"{sid}（{'・'.join(words) or '語なし'}）")
    warns = []
    if lacks:
        warns.append(f"ショートに頭の問い（hook）・最後の問い（tease）がありません：{'・'.join(lacks)}"
                     "（頭で疑問を出し、最後にもう一つの疑問で本編へ）")
    if notq:
        warns.append(f"ショートの問いが？で終わっていません：{'・'.join(notq)}")
    if same:
        warns.append(f"ショートの hook と tease が同じ問いです：{'・'.join(same)}（最後はもう一つ別の疑問に）")
    if noans:
        warns.append(f"ショートの tease の語が、そのショートの外の台本に見当たりません：{'・'.join(noans)}"
                     "（答えが本編に無いと、本編へ誘っても答えが出ない）")
    return warns


# --- サムネイルの構図が続いていないか（10-07 ユーザー決定「量産型に見せない」）---------------------
LAYOUT_STREAK = 3        # 同じ構図がこの回数続いたら知らせる


def _layout_of_script(path: Path) -> str | None:
    import yaml
    from .thumb import layout_of
    if not path.exists():
        return None
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return layout_of(data.get("thumbnail") or {})


def layout_streak(posted_log: Path, scripts_dir: Path, stem: str, layout: str) -> list[str]:
    """投稿済みの本編（posted.json の <名前>:main を publish_at 順）と、今の台本の構図を並べ、
    最後に同じ構図が3回以上続いていたら知らせる。今の台本が投稿済みなら、その回までで数える。"""
    import json
    entries = json.loads(posted_log.read_text(encoding="utf-8")) if posted_log.exists() else []
    mains = sorted((e for e in entries if str(e.get("key", "")).endswith(":main")), key=lambda e: e.get("publish_at", ""))
    names = [e["key"][: -len(":main")] for e in mains]
    if stem in names:
        names = names[: names.index(stem)]
    seq = [(n, _layout_of_script(scripts_dir / f"{n}.yaml")) for n in names] + [(stem, layout)]
    run = []
    for n, lay in reversed(seq):
        if lay != layout:
            break
        run.append(n)
    if len(run) >= LAYOUT_STREAK:
        return [f"サムネイルの構図「{layout}」が{len(run)}回続いています（{'→'.join(reversed(run))}）。"
                "題材に合う別の構図（face・scene・versus・number・map・classic）を thumbnail.layout で選ぶ"]
    return []


# --- 概要欄の章の題（10-08）-------------------------------------------------------
# 章（describe の「■ 目次」）は節の題から作る。伸びている長尺18本の調べ（research/benchmark_long.md）で、
# 章の題に年・人名・場面が入っていると、途中から探して見る人が拾いやすかった。知らせるだけで止めない。
SCENE_WORDS = ("事件", "の変", "の乱", "戦い", "合戦", "討ち入り", "クーデター", "刃傷", "城", "島", "港",
               "使節", "条約", "戴冠", "遠征", "行列", "裁判", "処刑", "暗殺", "即位", "葬儀", "結婚", "花嫁")


def place_names() -> list[str]:
    """places.yaml の地名。"""
    import yaml
    from .figures import GAZETTEER
    if not GAZETTEER.exists():
        return []
    return [str(k) for k in (yaml.safe_load(GAZETTEER.read_text(encoding="utf-8")) or {})]


def chapter_marker(title: str, names: list[str], places: list[str]) -> bool:
    """章の題に、年・数字・人名・地名・場面（「」の言葉・出来事の語）のどれかが入っているか。"""
    head = re.sub(r"^(地表|見立て|まとめ)[：:]", "", title)
    return bool(has_number(head) or "年" in head or has_name(head, names) or any(p in head for p in places)
                or re.search(r"「[^」]+」", head) or any(w in head for w in SCENE_WORDS)
                or re.search(r"[一-鿿]{1,4}(?:寺|城|宮|園|藩|湾|峠)", head))


def chapter_titles(script, places: list[str] | None = None) -> list[str]:
    """年・人名・場面のどれも入っていない節の題（＝概要欄の章の題）。
    名前は people: とその言い換え・サムネの名前、地名は places.yaml と台本に出た地名、
    場面は「」の言葉・出来事の語・用語の札の言葉（楽市楽座・出島）・寺や城の名。"""
    names = name_words(script) + [l.term[0] for l in script.lines if getattr(l, "term", None)]
    places = place_names() if places is None else places
    places = list(dict.fromkeys(places + [l.place[0] for l in script.lines if getattr(l, "place", None)]))
    bare = [f"{s.index + 1}節「{s.title}」" for s in script.sections if not chapter_marker(s.title, names, places)]
    if not bare:
        return []
    return [f"章の題に年・人名・場面がありません：{'、'.join(bare)}（概要欄の目次になる。「1582年 本能寺の変」「信長と堺の2万貫」のように）"]


# --- 画面の幅（10-09 点検。秀吉の第7節の題が右上の札・横長の額に隠れて切れた）------------------------
def section_title_fit(painter) -> list[str]:
    """節の題が、その行の画面（肖像の額・用語の札・場所の地図のある状態）で、いちばん小さい字でも
    置ける幅に収まらない行。止める（×）。寄りの行は題を出さない作りなので数えない。台本の題を短くする。"""
    from .render import TITLE_MIN, state_of
    sc = painter.script
    bad: dict[int, list[int]] = {}
    need: dict[int, tuple[float, float]] = {}
    for line in sc.lines:
        state = state_of(line)
        if state.reaction:
            continue
        try:
            room = painter.title_room(state)
        except FileNotFoundError:
            continue                                      # 素材が無い行は missing_assets が止める
        title = sc.sections[line.section].title
        if painter.title_size(title, room) is None:
            bad.setdefault(line.section, []).append(line.index + 1)
            w = painter.font("serif", TITLE_MIN, bold=True).getlength(title)
            need[line.section] = (w, min(room, need.get(line.section, (0, room))[1]))
    out = []
    for sec, rows in bad.items():
        w, room = need[sec]
        out.append(f"節の題が画面に収まりません：{sec + 1}節「{sc.sections[sec].title}」（{span(rows)}行目。"
                   f"いちばん小さい字でも{w:.0f}px、置ける幅{room:.0f}px。右上の札・肖像の額に隠れる。題を短くする）")
    return out


def timeline_crowding(painter) -> list[str]:
    """年表の出来事が近すぎて、ふだん（いまの年がどの出来事でもないとき）名札が出ないもの（10-09。秀吉の回で
    1573〜1598 に5つ集まり、名札が3段に詰まって字幕の箱に隠れた）。その年の行のあいだだけは出る。"""
    sc = painter.script
    if sc.timeline_start is None or sc.timeline_end is None or not sc.events:
        return []
    rows = painter.timeline_rows(470, painter.W - 470, None)
    hidden = [f"{label}（{y}年）" for (y, label), r in zip(sc.events, rows) if r is None]
    if not hidden:
        return []
    return [f"年表の出来事が近すぎて、名札が出ないものがあります：{'、'.join(hidden)}"
            "（その年の行だけ出る。timeline.events を減らすか、名札を短くする）"]

