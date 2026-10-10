"""① 別の辞書（fugashi＋UniDic）との食い違い。

置き換えたあとの文（エンジンに渡した文）を fugashi で語に切り、エンジンのカナ列を語の切れ目へ合わせる
（読みの候補との編集距離の和が最小になる並べ方）。読みの候補に無い読みをした語を知らせる。
同じとみなすもの：長音（ー／オウ／エイ）・助詞の「は／わ」「へ／え」（辞書の kana と pron の両方を候補に入れる）・
数字（fugashi は読みを付けないので何でも合う）・数字の直後の数え方・連濁（頭の濁り）・濁りだけの違い・終わりの「ッ」。
**両方の辞書が同じ間違いをした所は拾えない**（UniDic も「織田家＝オダカ」「表＝ヒョウ」と読む）ので、② の規則がある。
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from functools import lru_cache

from .kana import kata, norm, unvoice
from .lexicon import Lexicon, default
from .morph import SYMBOL, Tok, tokens

_KANA_ONLY = re.compile(r"[^ァ-ヴー]")
_VOICED: dict[str, list[str]] = {}
for _a, _b in zip("カキクケコサシスセソタチツテトハヒフヘホ", "ガギグゲゴザジズゼゾダヂヅデドバビブベボ"):
    _VOICED.setdefault(_a, []).append(_b)
for _a, _b in zip("ハヒフヘホ", "パピプペポ"):
    _VOICED[_a].append(_b)


@dataclass
class Diff:
    surface: str       # 語（置き換えたあとの文の字）
    engine: str        # エンジンの読み
    dictionary: str    # fugashi（UniDic）の読み
    start: int         # 置き換えたあとの文での位置
    end: int
    proper: bool = False   # 人名・地名（固有名詞）を含む


def _alts(t: Tok, prev: Tok | None, lex: Lexicon) -> tuple[str, ...] | None:
    """語の読みの候補（norm したカナ）。None は何でも合う（数字・記号・未知語）。"""
    if t.reading is None:
        return None
    raw = [_KANA_ONLY.sub("", kata(r)) for r in (t.reading, t.kana) if r] + list(lex.extra.get(t.surface, ()))
    base = {norm(r) for r in raw} | {norm(r, long=True) for r in raw}
    if prev is not None and prev.pos[1] == "数詞":
        base |= {norm(r) for r in lex.counters.get(t.surface, ())}
    base |= {norm(r) for r in lex.kanji_ok.get(t.surface, ()) + lex.ambiguous.get(t.surface, ())}
    out = set(base)
    if prev is not None:                                       # 連濁（「火薬づくり」「攻め」）・数え方の濁り（3本＝ボン）
        for r in base:
            if r and r[0] in _VOICED:
                out |= {v + r[1:] for v in _VOICED[r[0]]}
    return tuple(sorted(x for x in out if x)) or None


def _ed(a: str, b: str) -> int:
    if a == b:
        return 0
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def plan(toks: list[Tok], lex: Lexicon):
    """突き合わせる語：(語の番号, 読みの候補 or None, 数字の直後か)。記号は何でも合う（〇＝マルと読むものもある）。"""
    out = []
    prev = None
    for i, t in enumerate(toks):
        if t.pos[0] in SYMBOL:
            out.append((i, None, False))
            prev = None
            continue
        alts = _alts(t, prev, lex)
        loose = alts is not None and prev is not None and prev.reading is None and prev.pos[1] == "数詞"
        out.append((i, alts, loose))
        prev = t
    return out


@lru_cache(maxsize=200000)
def _cost(alts: tuple[str, ...], seg: str, loose: bool) -> int:
    """ずれの量（編集1つで2）。数字の直後の語（数え方）は読みが変わりやすいので、合わなくても1（知らせない）。"""
    if seg in alts:
        return 0
    if loose:
        return 1
    return 2 * min(_ed(a, seg) for a in alts)


def _exact(pl, b: str) -> list[tuple[int, int, int]] | None:
    """どの語も読みの候補のどれかのとおりに読めているなら、語ごとの (始まり, 終わり, 0)。読めていなければ None。
    多くの行はこれで済む（編集距離の並べ方は重いので、食い違いのある行だけにする）。"""
    reach: dict[int, int] = {0: 0}
    backs = []
    for _, alts, _loose in pl:
        if not reach:
            return None
        nxt: dict[int, int] = {}
        if alts is None:
            ks = sorted(reach)
            for j in range(ks[0], len(b) + 1):
                nxt[j] = max(k for k in ks if k <= j)
        else:
            for k in sorted(reach):
                for a in alts:
                    if b.startswith(a, k):
                        nxt.setdefault(k + len(a), k)
        backs.append(nxt)
        reach = nxt
    if len(b) not in reach:
        return None
    spans = []
    j = len(b)
    for back in reversed(backs):
        k = back[j]
        spans.append((k, j, 0))
        j = k
    return spans[::-1]


def _dropped(alts) -> int:
    return 2 * min(len(a) for a in alts) + 1


def _align(pl, b: str) -> list[tuple[int, int, int]]:
    """語ごとにエンジンのカナのどこが当たるかを、読みの候補とのずれの和が最小になるように決める。
    戻り値：語ごとの (始まり, 終わり, ずれの量)。読みの無い語は、どこまででも取れる（費用0）。"""
    m = len(b)
    INF = 10 ** 9
    dp = [0] + [INF] * m
    backs = []
    for _, alts, loose in pl:
        new = [INF] * (m + 1)
        back = [0] * (m + 1)
        if alts is None:
            best, arg = INF, 0
            for j in range(m + 1):
                if dp[j] < best:
                    best, arg = dp[j], j
                new[j], back[j] = best, arg
        else:
            lo = max(1, min(len(a) for a in alts) - 2)
            hi = max(len(a) for a in alts) + 2
            drop = _dropped(alts)
            for j in range(m + 1):
                best, arg = dp[j] + drop, j                   # エンジンが読まなかった（「披露」の「披」）
                for k in range(max(0, j - hi), j - lo + 1):
                    if dp[k] >= INF:
                        continue
                    c = dp[k] + _cost(alts, b[k:j], loose)
                    if c < best:
                        best, arg = c, k
                new[j], back[j] = best, arg
        dp = new
        backs.append(back)
    spans = []
    j = m
    for i in range(len(pl) - 1, -1, -1):
        k = backs[i][j]
        _, alts, loose = pl[i]
        if alts is None:
            cost = 0
        elif k == j:
            cost = _dropped(alts)
        else:
            cost = _cost(alts, b[k:j], loose)
        spans.append((k, j, cost))
        j = k
    return spans[::-1]


def token_kana(text: str, kana: str, lex: Lexicon | None = None) -> tuple[list[Tok], dict[int, tuple[str, int]]]:
    """語ごとに、エンジンのカナのどこが当たるか。(語の一覧, {語の番号: (エンジンの読み, ずれの量)})。
    kana は「／」区切りでもよい。全部合っている行は、読みを "" にして早く返す。"""
    lex = lex or default()
    toks = tokens(text)
    b_raw = kana.replace("／", "")
    b = norm(b_raw)
    pl = plan(toks, lex)
    if not pl:
        return toks, {}
    if _exact(pl, b) is not None:
        return toks, {i: ("", 0) for i, _, _ in pl}
    return toks, {i: (b_raw[s:e], c) for (i, _, _), (s, e, c) in zip(pl, _align(pl, b))}


def segments(text: str, kana: str, lex: Lexicon | None = None) -> tuple[list[Tok], dict[int, str]]:
    """語ごとのエンジンの読み（全部の語。合っている行でも並べ方を計算する）。"""
    lex = lex or default()
    toks = tokens(text)
    b_raw = kana.replace("／", "")
    pl = plan(toks, lex)
    if not pl:
        return toks, {}
    b = norm(b_raw)
    spans = _exact(pl, b) or _align(pl, b)
    return toks, {i: b_raw[s:e] for (i, _, _), (s, e, _) in zip(pl, spans)}


def same_reading(surface: str, engine: str, dictionary: str, lex: Lexicon | None = None) -> bool:
    """知らせるほどの違いではないか：濁りだけの違い（シズガダケ／シズガタケ）・終わりの「ッ」（イッ／イチ）・
    1語でよくある読み（kanji_ok）・確かめた組（alike）。"""
    lex = lex or default()
    a, b = norm(engine), norm(dictionary)
    if a == b or unvoice(a) == unvoice(b):
        return True
    if a.endswith("ッ") and a[:-1] == b[:-1] and b[-1:] in ("チ", "ツ", "ク", "キ"):
        return True
    la = norm(engine, long=True)
    if surface in lex.alike and (not lex.alike[surface] or la in {norm(x, long=True) for x in lex.alike[surface]}):
        return True
    if unvoice(la) in {unvoice(norm(x, long=True)) for x in lex.kanji_ok.get(surface, ())}:
        return True
    return False


def diff_line(text: str, kana: str, lex: Lexicon | None = None, fixed=frozenset()) -> list[Diff]:
    """置き換えたあとの文（エンジンに渡した文）とエンジンのカナから、辞書と読みが食い違う語。隣り合う食い違いは1つに。
    読みが割れる語（lex.ambiguous。② が受け持つ）と助詞だけの食い違い、読み替え辞書で入った字
    （fixed：置き換えたあとの文での位置）にかかる食い違いは知らせない。"""
    lex = lex or default()
    toks, got = token_kana(text, kana, lex)
    out: list[Diff] = []
    run: list[int] = []

    def flush():
        if not run:
            return
        ts = [toks[i] for i in run]
        run.clear()
        if (all(t.surface in lex.ambiguous or t.pos[0] in ("助詞", "助動詞") for t in ts)
                or any(k in fixed for k in range(ts[0].start, ts[-1].end))):
            return
        eng = "".join(got[toks.index(t)][0] for t in ts)
        dic = "".join(t.reading or "" for t in ts)
        surface = text[ts[0].start:ts[-1].end]
        if not same_reading(surface, eng, dic, lex):
            out.append(Diff(surface, eng, dic, ts[0].start, ts[-1].end, any(t.pos[1] == "固有名詞" for t in ts)))

    for i, _t in enumerate(toks):
        if i in got and got[i][1] >= 2:
            run.append(i)
        else:
            flush()
    flush()
    return out
