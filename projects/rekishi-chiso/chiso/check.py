"""作る前の点検。素材の有無・台本の書きすぎ・読みの確認・抑揚の張りつき。

どれも音声や画面を作る前に安く見つけられるもの。作ってから気づくと、作り直しに時間がかかる。
"""
from __future__ import annotations

import re

from pathlib import Path

from .voice import TONES, display_text

LINE_WARN = 90          # 1行のせりふがこれより長いと、字幕が3枚以上に分かれて追いにくい
CARD_BODY_WARN = 22     # 札の本文がこれより長いと、メモ欄からはみ出しやすい
SPEED_WARN = 1.2        # これより速いと早口に聞こえる
CHARS_PER_SEC = 7.0     # 合成音声のおおよその速さ（字／秒）。ショートの長さの見積もりに使う


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
    for sid in script.shorts:
        chars = sum(len(display_text(l.text)) for l in script.short_lines(sid))
        est = chars / CHARS_PER_SEC
        if est > short_limit:
            warns.append(f"ショート {sid}：見積もり約{est:.0f}秒（{short_limit:.0f}秒を超えそう）")
        for l in script.short_lines(sid):               # 見立ての「段階N」の札は、ショート単体では唐突（10-06 ナポレオン s10）
            if l.card is not None and l.card.head.startswith("段階"):
                warns.append(f"ショート {sid}：{l.index + 1}行目に「{l.card.head}」の札が出ます（ショートに入れない行に移す）")
    return warns


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


# --- 1本ぶんの決まり（2026-10-04 に固めたコンセプト） ---------------------------
MIN_FIGURES = 3          # 地図・グラフ・相関図を合わせて3つ以上
MIN_MINUTES = 25.0
HOOK_WINDOW = 2          # 節の終わりから何行以内に「引き」（hook: true）を置くか       # 本編の長さの下限の目安（目標は30〜40分）


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
    else:
        for k in ("image", "crop", "name", "main"):        # hook・stamp は任意（10-07、通説を打ち消す形をやめた）
            if k not in script.thumbnail:
                errors.append(f"サムネイルの {k} がありません")
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
    for name in sorted({l.icon for l in script.lines if l.icon}):
        if name not in extras.known_icons():
            errors.append(f"挿絵の名前が分かりません: {name}")
    warns += reaction_rules(script)
    if not any("《" in l.text for l in script.lines):
        warns.append("《》の強調が1つもありません")
    if not script.shorts:
        warns.append("ショート（shorts:）がありません")
    return errors, warns


def reaction_rules(script) -> list[str]:
    """つむぎの寄り（reaction）は1本に2回まで（10-07。毎回使うと安くなる）。続けて同じ寄りを書いた行は1回と数える。"""
    from .reaction import MAX_PER_EPISODE
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
BG_MAX_SEC = 40.0        # 同じ背景の絵は長くても40秒まで
NOVELTY_MAX_SEC = 20.0   # 20秒に1回は新しいもの（絵・札・図・挿絵・肖像）を出す
HOST_SHARE_MAX = 0.70    # 剣崎の字数の割合（10-07 の5本は72〜79%で講義に近かった）


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
        new_thing = new_bg or (l.card is not None and l.card != prev.get("card")) or bool(l.figure and l.figure != prev.get("fig"))             or bool(getattr(l, "icon", None)) or (l.portrait is not None and l.portrait != prev.get("por"))             or bool(getattr(l, "reaction", None))
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
        prev = {"bg": bg, "sec": l.section, "card": l.card, "fig": l.figure, "por": l.portrait}
    total = sum(len(display_text(l.text)) for l in script.lines) or 1
    host = sum(len(display_text(l.text)) for l in script.lines if l.speaker == "語り")
    if host / total > HOST_SHARE_MAX:
        warns.append(f"剣崎の字数が{host * 100 // total}%（{HOST_SHARE_MAX:.0%}まで。つむぎにも事実を言わせる）")
    return warns
