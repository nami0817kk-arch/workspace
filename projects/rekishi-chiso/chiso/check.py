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
