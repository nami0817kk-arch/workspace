"""字幕（SRT）の書き出し。

**字幕ファイルは常に作る。** 焼き込み（burn-in）は libass が要るうえ、
一度焼くとやり直しが効かない。テキストとして残しておけば YouTube にそのまま渡せる。
"""

from __future__ import annotations

from pathlib import Path


def timestamp(seconds: float) -> str:
    """SRT の時刻表記（00:00:01,500）にする。"""
    seconds = max(0.0, float(seconds))
    milliseconds = int(round(seconds * 1000))
    hours, milliseconds = divmod(milliseconds, 3_600_000)
    minutes, milliseconds = divmod(milliseconds, 60_000)
    whole, milliseconds = divmod(milliseconds, 1000)
    return f"{hours:02d}:{minutes:02d}:{whole:02d},{milliseconds:03d}"


def build_srt(texts: list[str], durations: list[float]) -> str:
    """字幕つきシーンだけを SRT にする。"""
    lines: list[str] = []
    number = 0
    start = 0.0
    for text, seconds in zip(texts, durations, strict=True):
        end = start + seconds
        if text.strip():
            number += 1
            lines.append(str(number))
            lines.append(f"{timestamp(start)} --> {timestamp(end)}")
            lines.append(text.strip())
            lines.append("")
        start = end
    return "\n".join(lines)


def write_srt(texts: list[str], durations: list[float], path) -> Path | None:
    """SRT を書き出す。字幕が1つも無ければ何も作らない。"""
    body = build_srt(texts, durations)
    if not body.strip():
        return None
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(body, encoding="utf-8")
    return target


def escape_for_filter(path) -> str:
    """subtitles フィルタに渡せる形にする。

    Windows のパスはそのままでは通らない。区切りを / にしたうえで、
    ドライブレターのコロンを filtergraph の区切りと解釈されないよう退避する。
    """
    backslash = chr(92)
    text = str(path).replace(backslash, "/")
    return text.replace(":", backslash + ":").replace("'", backslash + "'")
