"""点検に使う一覧（読みが割れる語・型の規則・知らせない組）。共通の data/base.yaml に、チャンネル側の yaml を足す。"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import yaml

BASE = Path(__file__).resolve().parent / "data" / "base.yaml"
KEYS = ("ambiguous", "kanji_ok", "alike", "counters", "extra")


@dataclass
class Lexicon:
    ambiguous: dict[str, tuple[str, ...]] = field(default_factory=dict)   # 読みが割れる語 → 読みの候補
    rules: list[dict] = field(default_factory=list)                       # 文脈で読みが決まる型
    kanji_ok: dict[str, tuple[str, ...]] = field(default_factory=dict)    # 1語でよくある読み（知らせない）
    alike: dict[str, tuple[str, ...]] = field(default_factory=dict)       # 語ごとの、誤りではない読み（() は何でも）
    counters: dict[str, tuple[str, ...]] = field(default_factory=dict)    # 数字の直後の読み
    extra: dict[str, tuple[str, ...]] = field(default_factory=dict)       # 辞書に無いが正しい読み

    def add(self, data: dict) -> "Lexicon":
        """同じ形の dict（yaml を読んだもの）を足す。同じキーは読みを足し合わせ、rules は後ろに足す。"""
        for k in KEYS:
            for word, reads in (data.get(k) or {}).items():
                cur = getattr(self, k).get(str(word), ())
                getattr(self, k)[str(word)] = tuple(dict.fromkeys(cur + tuple(str(r) for r in (reads or ()))))
        for r in data.get("rules") or []:
            self.rules.append(dict(r))
        return self

    @classmethod
    def load(cls, *extra: str | Path | dict, base: bool = True) -> "Lexicon":
        """共通の一覧（base=True）にチャンネル側の一覧（yaml のパスか dict）を足したもの。"""
        lex = cls()
        for src in ([BASE] if base else []) + list(extra):
            if isinstance(src, dict):
                lex.add(src)
            else:
                lex.add(yaml.safe_load(Path(src).read_text(encoding="utf-8")) or {})
        return lex


_DEFAULT: Lexicon | None = None


def default() -> Lexicon:
    global _DEFAULT
    if _DEFAULT is None:
        _DEFAULT = Lexicon.load()
    return _DEFAULT
