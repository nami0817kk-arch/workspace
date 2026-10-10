"""読み替え辞書（画面の文字 → 読み上げる文字）の置き換え。

置き換えは「長いキーから順に、文全体を str.replace」。rekishi-chiso の readings.yaml と同じ決まり。
"""
from __future__ import annotations

from pathlib import Path


def load_readings(path: str | Path) -> dict[str, str]:
    import yaml
    path = Path(path)
    if not path.exists():
        return {}
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return {str(k): str(v) for k, v in data.items()}


def apply_readings(text: str, readings: dict[str, str]) -> str:
    for word in sorted(readings, key=len, reverse=True):
        text = text.replace(word, readings[word])
    return text


def _walk(text: str, readings: dict[str, str]):
    """置き換えを1つずつ進め、(置き換えたあとの文, 各字の元の位置 or None, 当たり [(キー, 始まり, 終わり)])。"""
    cur = text
    origin: list[int | None] = list(range(len(text)))
    hits: list[tuple[str, int, int]] = []
    for word in sorted(readings, key=len, reverse=True):
        if not word or word not in cur:
            continue
        rep = readings[word]
        out, org, i = [], [], 0
        while True:
            k = cur.find(word, i)
            if k < 0:
                break
            span = origin[k:k + len(word)]
            if None not in span and span == list(range(span[0], span[0] + len(word))):
                hits.append((word, span[0], span[0] + len(word)))
            out.append(cur[i:k])
            org += origin[i:k]
            out.append(rep)
            org += [None] * len(rep)
            i = k + len(word)
        out.append(cur[i:])
        org += origin[i:]
        cur = "".join(out)
        origin = org
    return cur, origin, hits


def apply_tracked(text: str, readings: dict[str, str]) -> tuple[str, list[int | None]]:
    """apply_readings と同じ置き換えをし、置き換えたあとの各字が元の何文字目か（辞書で入った字は None）も返す。"""
    out, origin, _ = _walk(text, readings)
    return out, origin


def replacements(text: str, readings: dict[str, str]) -> list[tuple[str, int, int]]:
    """元の文のどこを、どのキーで置き換えるか。(キー, 始まり, 終わり)。"""
    return _walk(text, readings)[2]
