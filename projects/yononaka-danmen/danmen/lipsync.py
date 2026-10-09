# -*- coding: utf-8 -*-
"""声から、口の開き具合と瞬きの時刻を決める。

声の大きさを 1/10 秒ごとに測り、大きい区間ほど口を開ける
（歴史の地層の `chiso/lipsync.py` と同じ考え方）。

    levels(wav, fps)   … コマごとの口の段階（0 閉じ / 1 小 / 2 中 / 3 大）
    blinks(sec, fps)   … 瞬きを入れるコマ（1 半目 / 2 閉じ）

**固定の大きさで切ってはいけない。** 最初そうしたら、7割が「大きく開く」になった
（2026-10-09）。声の録り方・話者・調子で平均の大きさが変わるので、
**その声のいちばん大きいところを 1 として相対で**決める。
"""
from __future__ import annotations

import array
import wave
from pathlib import Path

FPS = 10                      # 1秒に何コマ口を切り替えるか
# いちばん大きいところを 1 としたときの境目。実測で 閉じ21% / 小20% / 中42% / 大17%
CUTS = (0.08, 0.40, 0.80)
BLINK_EVERY = 3.6             # 何秒ごとに瞬きするか
BLINK_FIRST = 1.2             # 最初の瞬きまで


def levels(wav: Path, fps: int = FPS) -> tuple[list[int], float]:
    """コマごとの口の段階と、声の長さ（秒）。"""
    with wave.open(str(wav)) as w:
        n, sr = w.getnframes(), w.getframerate()
        raw = array.array("h", w.readframes(n))
    step = max(sr // fps, 1)
    peaks = []
    for i in range(0, n, step):
        chunk = raw[i:i + step]
        if not chunk:
            break
        peaks.append(max(abs(v) for v in chunk) / 32768)
    top = max(peaks) if peaks else 1.0
    if top <= 0:
        top = 1.0
    out = []
    for q in peaks:
        r = q / top
        out.append(0 if r < CUTS[0] else 1 if r < CUTS[1] else 2 if r < CUTS[2] else 3)
    # **1コマだけの開閉は、ちらついて見える。** 前後が閉じている単独の開きは均す
    for i in range(1, len(out) - 1):
        if out[i] and not out[i - 1] and not out[i + 1]:
            out[i] = 0
    return out, n / sr


def blinks(seconds: float, fps: int = FPS, every: float = BLINK_EVERY,
           first: float = BLINK_FIRST) -> dict[int, int]:
    """{コマ番号: 1 半目 / 2 閉じ}。半目→閉じ→半目 の3コマで1回。"""
    out: dict[int, int] = {}
    t = first
    while t < seconds:
        k = int(t * fps)
        out[k] = 1
        out[k + 1] = 2
        out[k + 2] = 1
        t += every
    return out


# ---------------------------------------------------------------------------
# 音から口の形を決める（2026-10-10。ユーザー「口パクのリズムや種類はリアルの口の動きを意識して」）
#
# 声の大きさで開き具合を決めると、口の形が「あ」しか無く、リズムも 1/10 秒刻みで
# 音とずれる。**読み上げエンジンが返す「音ごとの長さ」から、母音ごとに口の形を決める。**
#
#   - あ → 大きく開く / い・え → 横に小さく開く / う・お → 丸くすぼめる
#   - ん・っ・間 → 閉じる。**ま行・ば行・ぱ行の頭は唇を閉じる**（実際に唇が合わさる音）
#   - それ以外の子音のあいだは、次の母音の形を先に作っておく（人は音より先に口を動かす）
#   - 無声化した母音（「です」の「す」など）は小さく
#   - 閉じた口から「あ」へ・「あ」から閉じた口へは、間に半開きを1コマはさむ（あごは一気に動かない）
#   - 口は音より 1コマ（約 0.03 秒）先に動かす
#
# VOICEVOX（岬）は音ごとの長さを正確に返す。**AivisSpeech（小倉）は長さが全部 0** なので、
# 同じ文を VOICEVOX で読ませた長さの割合を借りて、実際の音声の「声のある区間」に合わせて伸び縮みさせる。
# ---------------------------------------------------------------------------
VIDEO_FPS = 30
LEAD = 0.033                     # 口を音より先に動かす秒数
A_BIG = 0.55                     # 「あ」を目いっぱい開けるのは、この大きさ以上の所だけ
BILABIAL = {"m", "my", "b", "by", "p", "py"}
SHAPE_OF = {"a": "a", "i": "i", "u": "u", "e": "e", "o": "o",
            "A": "i", "I": "i", "U": "i", "E": "i", "O": "i",   # 無声化は小さく
            "N": "closed", "cl": "closed", "pau": "closed"}


def _segments(query: dict) -> list[tuple[float, str, bool]]:
    """(長さ, 形, 間か) の並び。query の長さは秒（話速の補正前）。"""
    seg = [(float(query.get("prePhonemeLength", 0.1)), "closed", True)]
    for ap in query["accent_phrases"]:
        for m in ap["moras"]:
            shape = SHAPE_OF.get(m["vowel"], "i")
            cl = float(m.get("consonant_length") or 0)
            if cl > 0:
                seg.append((cl, "closed" if m.get("consonant") in BILABIAL else shape, False))
            seg.append((float(m["vowel_length"]), shape, False))
        pm = ap.get("pause_mora")
        if pm:
            seg.append((float(pm["vowel_length"]), "closed", True))
    seg.append((float(query.get("postPhonemeLength", 0.1)), "closed", True))
    return seg


def _voiced_spans(wav: Path, frame: float = 0.01) -> tuple[list[tuple[float, float]], float]:
    """声のある区間 [(始め, 終わり)] と全体の秒数。0.08 秒より短い切れ目はつなぐ。"""
    with wave.open(str(wav)) as w:
        n, sr = w.getnframes(), w.getframerate()
        raw = array.array("h", w.readframes(n))
    step = max(int(sr * frame), 1)
    rms = []
    for i in range(0, n, step):
        c = raw[i:i + step]
        rms.append((sum(v * v for v in c) / max(len(c), 1)) ** 0.5 if c else 0.0)
    top = max(rms) if rms else 1.0
    on = [r > top * 0.06 for r in rms]
    spans, start = [], None
    for i, v in enumerate(on + [False]):
        if v and start is None:
            start = i
        elif not v and start is not None:
            spans.append([start * frame, i * frame])
            start = None
    merged: list[list[float]] = []
    for s in spans:
        if merged and s[0] - merged[-1][1] < 0.08:
            merged[-1][1] = s[1]
        else:
            merged.append(s)
    return [(a, b) for a, b in merged], n / sr


def _loudness(wav: Path, frame: float = 0.01) -> list[float]:
    """10ms ごとの声の大きさ（いちばん大きい所を 1 とする）。"""
    with wave.open(str(wav)) as w:
        n, sr = w.getnframes(), w.getframerate()
        raw = array.array("h", w.readframes(n))
    step = max(int(sr * frame), 1)
    out = []
    for i in range(0, n, step):
        c = raw[i:i + step]
        out.append((sum(v * v for v in c) / max(len(c), 1)) ** 0.5 if c else 0.0)
    top = max(out) if out else 1.0
    return [v / (top or 1.0) for v in out]


def _fit(seg, spans, total) -> list[tuple[float, float, str]]:
    """音の並び seg を、実際の音声の声のある区間に合わせて (始め, 終わり, 形) にする。"""
    # 文中の間（pause）で塊に分ける
    groups, cur = [], []
    for d, shape, is_pause in seg[1:-1]:
        if is_pause:
            if cur:
                groups.append(cur)
                cur = []
        else:
            cur.append((d, shape))
    if cur:
        groups.append(cur)
    if not spans or not groups:
        return [(0.0, total, "closed")]
    # 声のある区間の数が塊の数以上なら、長い切れ目から順に塊の境目にあてる
    if len(spans) >= len(groups) > 1:
        gaps = sorted(range(len(spans) - 1), key=lambda i: spans[i + 1][0] - spans[i][1], reverse=True)
        cut = sorted(gaps[:len(groups) - 1])
        blocks, s0 = [], 0
        for c in cut:
            blocks.append((spans[s0][0], spans[c][1]))
            s0 = c + 1
        blocks.append((spans[s0][0], spans[-1][1]))
    else:
        blocks = [(spans[0][0], spans[-1][1])]
        groups = [[x for g in groups for x in g]]
    out = []
    for (b0, b1), g in zip(blocks, groups):
        tot = sum(d for d, _ in g) or 1.0
        t = b0
        for d, shape in g:
            dt = (b1 - b0) * d / tot
            out.append((t, t + dt, shape))
            t += dt
    return out


def _exact(seg, total) -> list[tuple[float, float, str]]:
    """VOICEVOX の長さをそのまま使う（話速などの差は全体の長さで割り戻す）。"""
    s = sum(d for d, _, _ in seg) or 1.0
    k = total / s
    out, t = [], 0.0
    for d, shape, _ in seg:
        out.append((t, t + d * k, shape))
        t += d * k
    return out


def visemes(wav: Path, query: dict, exact: bool, fps: int = VIDEO_FPS) -> tuple[list[str], float]:
    """コマごとの口の形（closed / a / a- / i / u / e / o）と、声の長さ（秒）。a- は中くらいの「あ」。

    exact … query の長さが本物か（VOICEVOX で読んだ声なら True）。
            False なら query の長さは割合として使い、wav の声のある区間に合わせる。
    """
    seg = _segments(query)
    spans, total = _voiced_spans(wav)
    tl = _exact(seg, total) if exact else _fit(seg, spans, total)
    # **どの「あ」も目いっぱい開けると不自然**（2026-10-10）。実際の口は強く言う所だけ大きく開く。
    # その「あ」の区間の声の大きさが、その台詞でいちばん大きい所の 55% 未満なら中くらい（a-）にする
    loud = _loudness(wav)
    tl2 = []
    for t0, t1, shape in tl:
        if shape == "a":
            win = loud[int(t0 / 0.01):max(int(t1 / 0.01), int(t0 / 0.01) + 1)]
            if win and max(win) < A_BIG:
                shape = "a-"
        tl2.append((t0, t1, shape))
    tl = tl2
    n = max(int(round(total * fps)), 1)
    shapes, j = [], 0
    for k in range(n):
        t = (k + 0.5) / fps + LEAD
        while j < len(tl) - 1 and tl[j][1] <= t:
            j += 1
        shapes.append(tl[j][2] if tl and tl[j][0] <= t < tl[j][1] else "closed")
    return _smooth(shapes), total


def _smooth(s: list[str]) -> list[str]:
    s = list(s)
    # 1コマだけの形は前後に合わせる（ちらつく）。ただし唇を閉じる1コマは残す（「ま」の頭など）
    for k in range(1, len(s) - 1):
        if s[k] != s[k - 1] and s[k] != s[k + 1] and s[k] != "closed":
            s[k] = s[k - 1] if s[k - 1] != "closed" else s[k + 1]
    # 閉じ ↔ あ の間に半開きを1コマ（「あ」が3コマ以上続くときだけ）
    k = 0
    while k < len(s):
        if s[k] == "a":
            e = k
            while e < len(s) and s[e] == "a":
                e += 1
            if e - k >= 3:
                if k > 0 and s[k - 1] == "closed":
                    s[k] = "i"
                if e < len(s) and s[e] == "closed":
                    s[e - 1] = "i"
            k = e
        else:
            k += 1
    return s


def blinks30(seconds: float, fps: int = VIDEO_FPS, seed: int = 0) -> set[int]:
    """瞬きで目を閉じるコマ。**間隔は不規則**（2〜5.5秒）、閉じるのは約0.1秒、ときどき2回続けて。

    人の瞬きは一定の間隔ではない。等間隔だと機械に見える。
    """
    import random
    rnd = random.Random(seed)
    out: set[int] = set()
    t = rnd.uniform(0.8, 2.0)
    while t < seconds:
        k = int(t * fps)
        out.update({k, k + 1, k + 2})
        if rnd.random() < 0.2:                       # 2回続けて
            out.update({k + 6, k + 7, k + 8})
        t += rnd.uniform(2.0, 5.5)
    return {k for k in out if k < int(seconds * fps)}
