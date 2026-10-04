"""作る前の点検。素材の有無・台本の書きすぎ・読みの確認・抑揚の張りつき。

どれも音声や画面を作る前に安く見つけられるもの。作ってから気づくと、作り直しに時間がかかる。
"""
from __future__ import annotations

from pathlib import Path

from .voice import TONES, display_text

LINE_WARN = 90          # 1行のせりふがこれより長いと、字幕が3枚以上に分かれて追いにくい
CARD_BODY_WARN = 22     # 札の本文がこれより長いと、メモ欄からはみ出しやすい
SPEED_WARN = 1.2        # これより速いと早口に聞こえる
CHARS_PER_SEC = 7.0     # 合成音声のおおよその速さ（字／秒）。ショートの長さの見積もりに使う


def missing_assets(script, assets: Path) -> list[str]:
    """台本が使う絵のうち、置き場に無いもの。"""
    used = set()
    for line in script.lines:
        for pic in (line.background, line.portrait):
            if pic is not None:
                used.add(pic.image)
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
    return warns


def saturation(script, voices: dict) -> dict[str, tuple[int, int]]:
    """話者ごとに、抑揚が声のソフトの上限を超えた行・早口になった行の数（該当行, 全行）。

    2026-10-04、つむぎの99行中64行で抑揚が上限2.0に張りつき、キンキンした声になっていた。
    """
    out: dict[str, list[int]] = {}
    for line in script.lines:
        v = voices[line.speaker]
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
MIN_MINUTES = 25.0       # 本編の長さの下限の目安（目標は30〜40分）


def episode(script) -> tuple[list[str], list[str]]:
    """1本ぶんの決まり。(止めるもの, 知らせるもの) を返す。"""
    import json
    errors, warns = [], []
    if not script.sections or "見立て" not in script.sections[-1].title:
        errors.append("最後の節は「見立て：…」にする（なぜそうなったか）")
    if not script.next:
        errors.append("次回予告（next: {title, teaser}）がありません")
    if not script.thumbnail:
        errors.append("サムネイル（thumbnail:）がありません")
    else:
        for k in ("image", "crop", "hook", "stamp", "name", "main"):
            if k not in script.thumbnail:
                errors.append(f"サムネイルの {k} がありません")
    figs = {l.figure for l in script.lines if l.figure}
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
    if not any("《" in l.text for l in script.lines):
        warns.append("《》の強調が1つもありません")
    if not script.shorts:
        warns.append("ショート（shorts:）がありません")
    if not getattr(script, "question", ""):
        warns.append("題名に問いがありません")
    return errors, warns
