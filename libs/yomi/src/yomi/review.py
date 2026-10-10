"""1本ぶんの読みの点検（①〜③）をまとめて回し、知らせの文にする。チャンネルの check から呼ぶ。

    from yomi import Lexicon, VoicevoxKana, review
    lex = Lexicon.load("reading_extra.yaml")                  # チャンネル側の追加一覧
    src = VoicevoxKana(url, speaker=13, cache="work/kana_cache.json")
    rep = review(items, readings, src.kana if src.available else None, lex, strip=lambda t: t.replace("《", "").replace("》", ""))
    errors, warns = rep.lines()                               # 「読み：…」で始まる文

items は (見出し, 文) の並び（見出しは「12行目」のように行の番号で書くと、同じ知らせがまとめやすい）。
"""
from __future__ import annotations

from dataclasses import dataclass, field

from .collide import Collision, collision_lines, collisions
from .diff import Diff, diff_line
from .lexicon import Lexicon, default
from .morph import available
from .replace import apply_tracked
from .rules import Hit, ambiguous_hits


@dataclass
class Report:
    diffs: list[tuple[str, Diff]] = field(default_factory=list)      # (見出し, 食い違い)
    hits: list[Hit] = field(default_factory=list)                     # 読みが割れる語（型に当たったものも）
    collisions: list[Collision] = field(default_factory=list)
    engine: bool = True                                               # エンジンのカナで見たか
    morph: bool = True                                                # fugashi があったか

    @property
    def stops(self) -> list[Hit]:
        """止めるもの：型に当たって、正しく読めていない（か確かめられない）所。"""
        return [h for h in self.hits if h.rule is not None and not h.ok]

    def lines(self) -> tuple[list[str], list[str]]:
        """(止めるもの, 知らせるもの)。どれも「読み」で始まる。"""
        if not self.morph:
            return [], ["読み：fugashi・unidic-lite が入っていないので、辞書との突き合わせ・読みが割れる語・辞書の巻き込みは見ていません"]
        errors, warns = [], []
        if not self.engine:
            warns.append("読み：エンジン（VOICEVOX）が動いていないので、辞書との突き合わせは飛ばしました"
                         "（型に当たった所は確かめられないので止めます）")
        for h in self.stops:
            said = f"エンジンは{h.got}" if h.got is not None else "エンジンが無いので確かめられません"
            errors.append(f"読み：{h.label}「{h.word}」の「{h.char}」は{'・'.join(h.want)}と読む型（{h.rule}）。{said}。"
                          f"読み替え辞書に「{h.word}」の読みを足す")
        errors += ["読み：" + c for c in collision_lines(self.collisions)]
        proper: dict[str, list[str]] = {}
        for label, d in self.diffs:
            if d.proper:
                proper.setdefault(f"{d.surface}＝{d.engine}", []).append(label)
            else:
                warns.append(f"読み：{label}「{d.surface}」エンジン {d.engine}／辞書 {d.dictionary}")
        if proper:
            warns.append("読み（人名・地名。辞書と違うもの。どちらも外しやすいので耳で確かめる）："
                         + "・".join(f"{k}（{'・'.join(v)}）" for k, v in proper.items()))
        listed: dict[str, dict[str, list[str]]] = {}
        for h in self.hits:
            if h.rule is None:
                listed.setdefault(h.char, {}).setdefault(h.got or "?", []).append(h.label.replace("行目", ""))
        if listed:
            warns.append("読みが割れる語（読み替え辞書で決めていない所。少ない読みの行を kana で確かめる）："
                         + "／".join(listing(c, by) for c, by in listed.items()))
        return errors, warns


def listing(word: str, by: dict[str, list[str]]) -> str:
    """1語ぶんの一覧：「上＝ウエ×12・ジョオ（77）」。いちばん多い読みは数だけ、ほかの読みは見出しを添える。"""
    order = sorted(by.items(), key=lambda kv: -len(kv[1]))
    parts = []
    for n, (r, rows) in enumerate(order):
        if (n == 0 and len(order) > 1) or len(rows) > 6:
            parts.append(f"{r}×{len(rows)}")
        else:
            parts.append(f"{r}（{'・'.join(rows)}）")
    return f"{word}＝" + "・".join(parts)


def review(items, readings: dict[str, str], kana=None, lex: Lexicon | None = None, strip=None) -> Report:
    """items：(見出し, 文)。kana：置き換えたあとの文 → エンジンのカナ の関数（None ならエンジン無し）。
    strip：文から読まない印を外す関数（《》など）。"""
    lex = lex or default()
    rep = Report(engine=kana is not None, morph=available())
    if not rep.morph:
        return rep
    items = list(items)
    for label, text in items:
        plain = strip(text) if strip else text
        sp, origin = apply_tracked(plain, readings)
        k = kana(sp) if kana is not None else None
        if k is not None:
            fixed = frozenset(i for i, o in enumerate(origin) if o is None)
            rep.diffs += [(label, d) for d in diff_line(sp, k, lex, fixed)]
        rep.hits += ambiguous_hits(label, sp, k, lex)
    rep.collisions = collisions(readings, items, strip)
    return rep
