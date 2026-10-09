"""読み違いを防ぐ4段の仕組み（10-10。10/12〜13 の4本で、聞いて分かる誤読が約50か所あった）。

点検の中身は共有ライブラリ libs/yomi（ほかのチャンネルでも使う）。ここは歴史の地層の側：
台本から読む文を並べる・チャンネルだけの一覧（yomi.yaml）を足す・VOICEVOX のカナの控え・check の知らせ。

1. **別の辞書との食い違い**：readings.yaml で置き換えた文を fugashi（UniDic）でも読み、VOICEVOX のカナと突き合わせる。
   長音・助詞の「は／わ」「へ／え」・数字・連濁は同じとみなす。**両方が同じ間違いをした所は拾えない**（UniDic も
   「織田家＝オダカ」「表＝ヒョウ」「方＝ホウ」と読む）ので 2 段目がある。check に「読み：」（!）として出る
2. **読みが割れる語の一覧と型**：家・方・表…（共通）と 斉・都・明…（yomi.yaml）を1語で使い、readings.yaml で決めて
   いない所を一覧に（・）。名字＋家・数字＋石・名前＋の方・表＋の/に/と・都＋助詞 は型にして、VOICEVOX が正しく
   読めていなければ ×（止める）。エンジンが無いときは確かめられないので ×
3. **readings.yaml の巻き込み**：キーがもっと長い語の一部に当たり（「露: つゆ」が「披露」に）、読みが変わるもの（×）。
   check と、readings.yaml を読む所（kana・shorts）の両方で出す
4. **読みの確認の関門**：`reading-ok` が台本と readings.yaml のハッシュを approvals/x.reading.json に控え、`approve` は
   それが無いか合わないと止まる（cli.py。予約・公開済みの回＝posted.json に main がある回は対象外）
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
try:
    import yomi
except ImportError:                                       # pip install -e ../../libs/yomi をしていない手元（モノレポの中）
    sys.path.insert(0, str(ROOT.parent.parent / "libs" / "yomi" / "src"))
    import yomi

from .voice import apply_readings, split_emphasis

EXTRA = ROOT / "yomi.yaml"
KANA_CACHE = ROOT / "work" / "kana_cache.json"
_LEX = None


def lexicon() -> "yomi.Lexicon":
    """共通の一覧＋歴史の地層の一覧（yomi.yaml）。"""
    global _LEX
    if _LEX is None:
        _LEX = yomi.Lexicon.load(EXTRA)
    return _LEX


def strip(text: str) -> str:
    """読まない印（《》）を外す。"""
    return split_emphasis(text)[0]


def spoken(text: str, readings: dict[str, str]) -> str:
    """VOICEVOX に渡す文（tts.speak と同じ）。"""
    return apply_readings(strip(text), readings)


def items(sc) -> list[tuple[str, str]]:
    """読みを確かめる文：本編の全行と、ショートの hook・tease（つむぎの声で読む）。(見出し, 文)。"""
    out = [(f"{l.index + 1}行目", l.text) for l in sc.lines]
    for sid, meta in (getattr(sc, "shorts", {}) or {}).items():
        for k in ("hook", "tease"):
            v = str((meta or {}).get(k) or "").replace("／", "").strip()
            if v:
                out.append((f"ショート {sid} の {k}", v))
    return out


def all_scripts(scripts_dir: Path = ROOT / "scripts", skip=()) -> list[tuple[str, str]]:
    """scripts/ の台本の読む文（skip の台本名は除く）。(「台本名 12行目」, 文)。"""
    from . import script as script_mod
    out = []
    for f in sorted(scripts_dir.glob("*.yaml")):
        if f.stem in skip:
            continue
        out += [(f"{f.stem} {label}", text) for label, text in items(script_mod.load(f))]
    return out


def kana_source(url: str, style_id: int = 0) -> "yomi.VoicevoxKana":
    """VOICEVOX のカナ（同じ文は work/kana_cache.json から）。"""
    return yomi.VoicevoxKana(url, style_id, cache=KANA_CACHE)


def collision_lines(readings: dict[str, str], texts) -> list[str]:
    return yomi.collision_lines(yomi.collisions(readings, texts, strip))


def notes(sc, readings: dict[str, str], src=None) -> tuple[list[str], list[str]]:
    """1本ぶんの読みの点検。(止めるもの, 知らせるもの)。src は kana(文) と available を持つもの（None ならエンジン無し）。"""
    engine = src is not None and src.available
    rep = yomi.review(items(sc), readings, src.kana if engine else None, lexicon(), strip)
    if src is not None and hasattr(src, "save"):
        src.save()
    return rep.lines()
