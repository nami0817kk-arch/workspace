"""カナをそろえる・エンジンからカナを取る。

エンジンのカナは VOICEVOX の audio_query の形（長音は「トオキョオ」と母音で書く・助詞の「は」は「ワ」）。
辞書（UniDic）のカナは「トーキョー」（pron）と「トウキョウ」（kana）。norm で比べられる形にそろえる。
"""
from __future__ import annotations

import json
import urllib.parse
import urllib.request
from pathlib import Path

_VOWEL: dict[str, str] = {}
for _v, _row in {"ア": "アカガサザタダナハバパマヤャラワァヮ", "イ": "イキギシジチヂニヒビピミリィ",
                 "ウ": "ウクグスズツヅヌフブプムユュルゥヴ", "エ": "エケゲセゼテデネヘベペメレェ",
                 "オ": "オコゴソゾトドノホボポモヨョロヲォ"}.items():
    for _c in _row:
        _VOWEL[_c] = _v
_SAME = str.maketrans({"ヲ": "オ", "ヂ": "ジ", "ヅ": "ズ", "ヮ": "ワ"})
# 濁りを外して比べる（「付け」ズケ／ツケ：ヅは norm でズになるので、ツ・スもそろえる）
_UNVOICE = str.maketrans("ガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポツチ",
                         "カキクケコサシスセソタシステトハヒフヘホハヒフヘホスシ")


def kata(s: str) -> str:
    """ひらがなをカタカナに。"""
    return "".join(chr(ord(c) + 0x60) if "ぁ" <= c <= "ゖ" else c for c in s)


def norm(kana: str, long: bool = False) -> str:
    """比べるためにそろえたカナ。長音符「ー」を前の母音に、ヲ→オ など。字数は変えない。
    long=True で「オウ」「エイ」も「オオ」「エエ」に（辞書の書きのカナ「トウキョウ」用。語の中だけで使う。
    エンジンのカナ列に掛けると「ッテ／イウ」の「テイ」が語をまたいで「テエ」になる）。"""
    s = kata(kana).translate(_SAME)
    out: list[str] = []
    for c in s:
        prev = _VOWEL.get(out[-1]) if out else None
        if c == "ー" and prev:
            c = prev
        elif long and c == "ウ" and prev == "オ":
            c = "オ"
        elif long and c == "イ" and prev == "エ":
            c = "エ"
        out.append(c)
    return "".join(out)


def unvoice(kana: str) -> str:
    """濁り・半濁りを外す（連濁の違いを同じとみなすため）。"""
    return kana.translate(_UNVOICE)


def join_n_phrases(accent_phrases: list) -> list:
    """「ン」で始まる区切りを前の区切りにつなぐ（VOICEVOX は「〜ないんですか」を「ナイ／ンデスカ」と切る）。
    読みのカナは変わらない。区切りの見た目を音声と同じにするためだけ。"""
    out: list = []
    for p in accent_phrases:
        moras = p.get("moras") or []
        if out and moras and moras[0].get("text") == "ン" and not out[-1].get("pause_mora"):
            out[-1] = {**out[-1], "moras": out[-1]["moras"] + moras, "pause_mora": p.get("pause_mora")}
        else:
            out.append(p)
    return out


def voicevox_kana(text: str, url: str = "http://127.0.0.1:50021", speaker: int = 0, timeout: int = 20) -> str:
    """VOICEVOX の audio_query で読んだカナ。区切りは「／」（rekishi-chiso の kana コマンドと同じ形）。"""
    req = urllib.request.Request(f"{url}/audio_query?{urllib.parse.urlencode({'text': text, 'speaker': speaker})}",
                                 method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as res:
        q = json.loads(res.read())
    return "／".join("".join(m["text"] for m in p["moras"]) for p in join_n_phrases(q["accent_phrases"]))


def engine_up(url: str = "http://127.0.0.1:50021", timeout: float = 3) -> bool:
    try:
        with urllib.request.urlopen(f"{url}/version", timeout=timeout):
            return True
    except OSError:
        return False


class VoicevoxKana:
    """エンジンのカナを、同じ文は控え（JSON）から返す。読みは声（speaker）によらない。
    エンジンに繋がらなければ available が False（kana は控えに無い文だけ None）。"""

    def __init__(self, url: str = "http://127.0.0.1:50021", speaker: int = 0, cache: Path | None = None,
                 timeout: int = 20):
        self.url, self.speaker, self.timeout = url, speaker, timeout
        self.cache_path = Path(cache) if cache else None
        self.memo: dict[str, str] = {}
        if self.cache_path is not None and self.cache_path.exists():
            try:
                self.memo = json.loads(self.cache_path.read_text(encoding="utf-8"))
            except ValueError:
                self.memo = {}
        self._dirty = False
        self.available = engine_up(url)

    def kana(self, text: str) -> str | None:
        if text in self.memo:
            return self.memo[text]
        if not self.available:
            return None
        k = voicevox_kana(text, self.url, self.speaker, self.timeout)
        self.memo[text] = k
        self._dirty = True
        return k

    def save(self) -> None:
        if self._dirty and self.cache_path is not None:
            self.cache_path.parent.mkdir(parents=True, exist_ok=True)
            self.cache_path.write_text(json.dumps(self.memo, ensure_ascii=False), encoding="utf-8")
            self._dirty = False
