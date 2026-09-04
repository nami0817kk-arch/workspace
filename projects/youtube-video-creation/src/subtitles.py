"""字幕(SRT)・チャプター・概要欄などの書き出し。"""

from __future__ import annotations

from pathlib import Path

from .script_model import Script


# 字幕1枚の上限。日本語の字幕は1秒に4文字前後が読みやすいとされる。
# テレビの字幕は全角15字×2行がふつう。実測（2026-09-04）で、1行そのまま
# 出していたため45文字の枚があり、一度に読む量が多すぎた。
CAPTION_LIMIT = 30
MIN_CAPTION_SECONDS = 1.2


def to_srt(script: Script) -> str:
    blocks = []
    index = 1
    for line in script.lines:
        # 字幕は読み上げた内容そのもの。テロップは画面に焼き込んであるし、
        # 画面用に短く切ってあるので、そのまま字幕にすると途中で切れる。
        # **確度バッジ（[報道] など）は画面の表示物なので字幕には入れない。**
        # 読み上げていない文字が字幕に出ると、聞こえた音と食い違う。
        text = line.text or line.telop_text()
        pause = line.pause or 0.0
        end = line.start + max(0.4, line.duration - pause)

        chunks = split_caption(text)
        span = max(0.4, end - line.start)
        weights = [len(c) for c in chunks] or [1]
        total = sum(weights) or 1
        at = line.start
        for order, (chunk, weight) in enumerate(zip(chunks, weights)):
            take = span * weight / total
            if len(chunks) > 1:
                take = max(MIN_CAPTION_SECONDS, take)
            last = order == len(chunks) - 1
            stop = end if last else min(end, at + take)
            if stop <= at:
                stop = at + 0.4
            head = f"{line.speaker}: " if order == 0 else ""
            blocks.append(
                f"{index}\n{_timestamp(at)} --> {_timestamp(stop)}\n{head}{chunk}\n"
            )
            index += 1
            at = stop
    return "\n".join(blocks)


def split_caption(text: str, limit: int = CAPTION_LIMIT) -> list[str]:
    """字幕1枚ぶんに切る。句点、次に読点と、意味の切れ目を優先する。

    読み上げの速さは変えられないので、**1枚に載る量**を抑えるのが目的。
    一度に読む字数が減れば、目で追える。
    """
    import re as _re

    text = text.strip()
    if not text:
        return [""]
    if len(text) <= limit:
        return [text]

    # まず句点で分け、収まるものは隣とくっつける
    parts = [p for p in _re.split(r"(?<=。)", text) if p]
    merged: list[str] = []
    for part in parts:
        if merged and len(merged[-1]) + len(part) <= limit:
            merged[-1] += part
        else:
            merged.append(part)

    final: list[str] = []
    for chunk in merged:
        final.extend(_halve(chunk, limit))
    return final


def _halve(text: str, limit: int) -> list[str]:
    """長い一文を二つに割る。真ん中に近い切れ目を選ぶ。

    端から詰めると「リバプールが、」のような短い1枚が出る。真ん中で割れば
    どちらも同じくらいの量になり、読む負担がそろう。
    """
    if len(text) <= limit:
        return [text]
    cut = _cut_point(text)
    return _halve(text[:cut], limit) + _halve(text[cut:], limit)


MIN_PIECE = 10


def _cut_point(text: str) -> int:
    """一文を割る位置。読点 → 語の変わり目 → 真ん中、の順に探す。"""
    import re as _re

    middle = len(text) / 2
    commas = [
        m.end() for m in _re.finditer("、", text[:-1])
        if MIN_PIECE <= m.end() <= len(text) - MIN_PIECE
    ]
    if commas:
        return min(commas, key=lambda p: abs(p - middle))

    # 読点が無ければ、ひらがなの後に漢字・カタカナが来る位置（語の頭）を探す。
    # 真ん中から外へ広げて、いちばん近いものを選ぶ。
    def word_start(i: int) -> bool:
        before, after = text[i - 1], text[i]
        return _is_hiragana(before) and (_is_kanji(after) or _is_katakana(after))

    center = int(middle)
    for offset in range(0, len(text) // 2):
        for index in (center - offset, center + offset):
            if MIN_PIECE <= index <= len(text) - MIN_PIECE and word_start(index):
                return index

    # それも無ければ、同じ字種が続く途中だけは避けて真ん中で割る
    for offset in range(0, len(text) // 2):
        for index in (center - offset, center + offset):
            if not (MIN_PIECE <= index <= len(text) - MIN_PIECE):
                continue
            before, after = text[index - 1], text[index]
            same = (
                (_is_kanji(before) and _is_kanji(after))
                or (_is_katakana(before) and _is_katakana(after))
            )
            if not same:
                return index
    return center


def _is_kanji(char: str) -> bool:
    return "一" <= char <= "鿿"


def _is_hiragana(char: str) -> bool:
    return "ぁ" <= char <= "ん"


def _is_katakana(char: str) -> bool:
    return "ァ" <= char <= "ヴ"


def chapters(script: Script) -> list[tuple[float, str]]:
    """YouTube のチャプター。各シーンの最初のセリフの開始時刻を使う。

    タイトルカードのぶん時刻がずれるので、尺の足し算ではなく実際の start を見る。
    """
    result: list[tuple[float, str]] = []
    for scene in script.scenes:
        if not scene.lines:
            continue
        result.append((scene.lines[0].start, scene.title))
    if result:
        result[0] = (0.0, result[0][1])  # 最初のチャプターは必ず 0:00
    return result


def description(script: Script, credits: list[str] | None = None) -> str:
    """概要欄のたたき台（本文 + チャプター + クレジット + タグ）。"""
    parts = [script.description.strip()] if script.description.strip() else []
    marks = chapters(script)
    if len(marks) > 1:
        parts.append("■ 目次\n" + "\n".join(f"{_clock(t)} {title}" for t, title in marks))
    if script.sources:
        # ニュース系では出典の明示が要る。frontmatter の sources をそのまま並べる
        parts.append("■ 出典\n" + "\n".join(script.sources))
    if credits:
        parts.append("■ クレジット\n" + "\n".join(credits))
    if script.tags:
        parts.append(" ".join(f"#{tag}" for tag in script.tags))
    return "\n\n".join(parts).strip() + "\n"


def write_outputs(script: Script, out_dir: Path, credits: list[str] | None = None) -> dict[str, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    files = {
        "srt": out_dir / "subtitles.srt",
        "description": out_dir / "description.txt",
        "script_json": out_dir / "script.json",
    }
    files["srt"].write_text(to_srt(script), encoding="utf-8")
    files["description"].write_text(
        f"{script.title}\n\n{description(script, credits)}", encoding="utf-8"
    )
    files["script_json"].write_text(script.to_json(), encoding="utf-8")
    return files


def _timestamp(seconds: float) -> str:
    ms = int(round(seconds * 1000))
    hours, ms = divmod(ms, 3_600_000)
    minutes, ms = divmod(ms, 60_000)
    secs, ms = divmod(ms, 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{ms:03d}"


def _clock(seconds: float) -> str:
    total = int(seconds)
    hours, rest = divmod(total, 3600)
    minutes, secs = divmod(rest, 60)
    return f"{hours}:{minutes:02d}:{secs:02d}" if hours else f"{minutes}:{secs:02d}"
