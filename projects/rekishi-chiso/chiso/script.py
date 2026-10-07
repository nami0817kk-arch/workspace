"""台本（YAML）を読み込んで、1行ずつの「話す内容＋その時の画面」に展開する。

台本の形:

    title: マリー・アントワネットは本当に悪女だったのか
    series: 悪女と呼ばれた女たち
    timeline:
      start: 1755
      end: 1793
      events: [[1755, 誕生], [1770, 結婚], ...]
    shorts:
      s1: {title: "あの名言、実は言っていない"}
    sections:
      - title: あの言葉は、言っていない
        background: {image: paintings/versailles.jpg, credit: "ピエール・パテル《ヴェルサイユ宮殿》1668年"}
        portrait: {image: paintings/marie.jpg, caption: "ヴィジェ＝ルブラン画（1778年）"}
        year: 1755
        lines:
          - 語り: 「パンがなければ、お菓子を食べればいいじゃない」。
            tone: 強調
          - 聞き: え、言ってないんですか？
            tone: 驚き
            short: s1

人物の言葉は、話者を「人物」にして who に誰かを書く。声は config.yaml の roles で決める（2026-10-04）:

          - 人物: 「ごめんなさい。わざとではないのよ」
            who: マリー

画面の指定（background / portrait / card / year）は「次に変えるまで続く」。
portrait と card は節が変わると消える。null を書けばその行で消せる。
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from pathlib import Path

import yaml

SPEAKERS = ("語り", "聞き", "人物", "二人")   # 二人＝語りと聞きが声を合わせる（締めの一言）
CAST = ("語り", "聞き")      # 画面に立ち絵がいる2人。「人物」の行は who の名前が話者になる
_UNSET = object()


@dataclass(frozen=True)
class Picture:
    image: str
    credit: str = ""      # 背景の出典（画面の下に小さく出す）
    caption: str = ""     # 肖像の下に出す説明
    who: str = ""         # 肖像の人物（people: の名前）。省けば caption の名前から探す
    age: bool = True      # false で「この時○歳」を出さない（話の時代と絵の人物の年が離れるとき）


@dataclass(frozen=True)
class Card:
    head: str             # 例: 1774年 5月
    body: str = ""        # 例: 18歳でフランス王妃に


@dataclass
class Line:
    index: int
    section: int
    speaker: str
    text: str
    tone: str = "普通"
    pause: float | None = None        # この行の前に置く間（秒）。None なら自動
    shorts: tuple[str, ...] = ()
    background: Picture | None = None
    portrait: Picture | None = None
    card: Card | None = None
    year: int | None = None
    memo: tuple = ()                  # その節で出た札（新しい順に最大3枚）。画面左の「掘り出したメモ」
    figure: str | None = None         # 図（地図・グラフ・相関図）の指定。JSON の文字列（chiso/figures.py）
    bubble: str | None = None         # 肖像の人物の吹き出し（その行だけ）。JSON の文字列（chiso/extras.py）
    icon: str | None = None           # 1文の挿絵（その行だけ）。Phosphor のアイコン名
    place: tuple | None = None        # 位置の小さな地図 (地名, 経度, 緯度)。places.yaml から自動で付く
    term: tuple | None = None         # 用語の札 (言葉, 説明)。terms.yaml と台本の terms: から自動で付く
    hook: bool = False                # 節の終わりの「引き」（次の節が気になる一言）。check が節ごとに確かめる
    reaction: str | None = None       # つむぎの「寄り」（その行だけ）。JSON の文字列（chiso/reaction.py）
    detail: str | None = None         # 絵の一部を大きく（その行だけ）。JSON の文字列（chiso/pen.py）
    mark: str | None = None           # 赤ペンの書き込み。JSON {"items": [...], "from": n}（chiso/pen.py）


MEMO_SIZE = 3
LOOK_KEYS = ("texture", "recap")   # 台本の一番上に書くと config.yaml の同じ名前より優先（10-07）
TERM_LINES = 3        # 用語の札を出しておく行数（初めて出た行から）
TERM_MAX = 40         # 説明の字数の上限（右上の狭い札に収める）


def attach_terms(lines: list, glossary: dict, attr: str = "term", value=None, mask=()) -> None:
    """その回で初めて出た用語（地名）に、札（小さな地図）を付ける。新しい言葉が出たらすぐ差し替え、
    同じ行に2つ以上あれば、前の札が終わってから順に出す。節が変わると札は消える。"""
    import re
    if not glossary:
        return
    words = sorted(glossary, key=len, reverse=True)       # 長い言葉を先に（王太子妃の中の王太子より先に）
    seen: set[str] = set()
    pending: list[str] = []
    cur, left, sec = None, 0, None
    for line in lines:
        if line.section != sec:
            cur, left, sec, pending = None, 0, line.section, []
        plain = re.sub(r"[《》]", "", line.text)
        for m in sorted(mask, key=len, reverse=True):      # 「神聖ローマ皇帝」の中の「ローマ」は地名にしない
            plain = plain.replace(m, "＿" * len(m))
        found = []
        for w in words:
            pos = plain.find(w)
            if pos >= 0 and w not in seen and not any(w in f for _, f in found):
                found.append((pos, w))
        found = [w for _, w in sorted(found)]
        seen.update(found)
        if found:
            cur, left = found[0], TERM_LINES
            pending = found[1:] + pending
        elif left <= 0 and pending:
            cur, left = pending.pop(0), TERM_LINES
        if cur is not None and left > 0:
            setattr(line, attr, value(cur) if value else (cur, glossary[cur]))
            left -= 1


@dataclass
class Section:
    index: int
    title: str


@dataclass
class Script:
    title: str
    series: str
    timeline_start: int | None
    timeline_end: int | None
    events: list[tuple[int, str]]
    sections: list[Section]
    lines: list[Line]
    shorts: dict[str, dict] = field(default_factory=dict)
    path: Path | None = None
    next: dict = field(default_factory=dict)        # 次回予告 {title, teaser}
    thumbnail: dict = field(default_factory=dict)   # サムネイルの文字と絵（thumb.py）
    people: dict = field(default_factory=dict)      # 人物の生没（肖像に「この時○歳」を出す）
    tags: list = field(default_factory=list)        # YouTube のタグ（全ショートと本編に共通）
    look: dict = field(default_factory=dict)        # 画面の道具の入り切り（texture・recap）。config より優先
    playlists: list = field(default_factory=list)   # 本編を入れる再生リスト（省けば series:。chiso/channel.py）
    shorts_playlists: list = field(default_factory=list)   # ショートを入れる再生リスト（省けば入れない）
    en: dict = field(default_factory=dict)          # 英語の題名・説明・章の題 {title, description, chapters}

    @property
    def question(self) -> str:
        """題名の問いの部分（「｜」より前）。冒頭で大きく出す。"""
        return self.title.split("｜")[0]

    @property
    def roles(self) -> list[str]:
        """人物の言葉を話す人（出てくる順）。"""
        out: list[str] = []
        for line in self.lines:
            if line.speaker not in CAST + ("二人",) and line.speaker not in out:
                out.append(line.speaker)
        return out

    def short_lines(self, short_id: str) -> list[Line]:
        return [line for line in self.lines if short_id in line.shorts]


class ScriptError(ValueError):
    pass


def _picture(raw, where: str) -> Picture | None:
    if raw is None:
        return None
    if isinstance(raw, str):
        return Picture(image=raw)
    if not isinstance(raw, dict) or "image" not in raw:
        raise ScriptError(f"{where}: 絵の指定には image が要ります: {raw!r}")
    return Picture(image=str(raw["image"]), credit=str(raw.get("credit", "")),
                   caption=str(raw.get("caption", "")), who=str(raw.get("who", "")),
                   age=bool(raw.get("age", True)))


def _card_year(card) -> int | None:
    """札の見出しの年（「1774年5月」→1774）。年で始まらない札（「首飾りの値段」）は None。"""
    import re
    # 「1760年代半ば」は1つの年ではないので数えない
    m = re.match(r"(\d{3,4})年(?!代)", card.head) if card is not None else None
    return int(m.group(1)) if m else None


def _card(raw, where: str) -> Card | None:
    if raw is None:
        return None
    if isinstance(raw, str):
        return Card(head=raw)
    if not isinstance(raw, dict) or "head" not in raw:
        raise ScriptError(f"{where}: card には head が要ります: {raw!r}")
    return Card(head=str(raw["head"]), body=str(raw.get("body", "")))


FIGURE_TYPES = ("map", "pie", "bars", "people", "compare", "money", "stats", "calc", "numberline", "line", "versus")
FIGURE_NEEDS = {"stats": ("items",), "calc": ("terms",), "numberline": ("items",), "line": ("points",),
                "versus": ("left", "right"), "bars": ("bars",), "people": ("nodes",), "compare": ("people",),
                "pie": ("parts",)}


def _bubble(raw, where: str) -> str | None:
    if raw is None:
        return None
    import json
    if isinstance(raw, str):
        raw = {"text": raw}
    if not isinstance(raw, dict) or not raw.get("text"):
        raise ScriptError(f"{where}: bubble には text が要ります: {raw!r}")
    return json.dumps(raw, ensure_ascii=False, sort_keys=True)


def _figure(raw, where: str) -> str | None:
    if raw is None:
        return None
    import json
    if not isinstance(raw, dict) or raw.get("type") not in FIGURE_TYPES:
        raise ScriptError(f"{where}: figure の type は {' / '.join(FIGURE_TYPES)} のどれかです: {raw!r}")
    if raw["type"] == "money" and not all(raw.get(k) for k in ("then", "yen", "basis")):
        # 換算の前提（何を何に置き換えたか）を出さない金額は、根拠のない数字になる
        raise ScriptError(f"{where}: money には then（当時の金額）・yen（円）・basis（置き換えの前提）が要ります")
    missing = [k for k in FIGURE_NEEDS.get(raw["type"], ()) if not raw.get(k)]
    if missing:
        raise ScriptError(f"{where}: {raw['type']} には {'・'.join(missing)} が要ります")
    if raw["type"] == "versus" and not all(isinstance(raw[k], dict) and raw[k].get("image") for k in ("left", "right")):
        raise ScriptError(f"{where}: versus の left・right には image（絵）が要ります")
    if "upto" in raw and (not isinstance(raw["upto"], int) or isinstance(raw["upto"], bool) or raw["upto"] < 1):
        raise ScriptError(f"{where}: upto は1以上の整数です（先頭から何項目を出すか）: {raw['upto']!r}")
    if "grow_from" in raw:
        raise ScriptError(f"{where}: grow_from は自動で付きます（台本には upto だけを書く）")
    return json.dumps(raw, ensure_ascii=False, sort_keys=True)


def _grown(new: str | None, prev: str | None) -> str | None:
    """同じ図に upto だけを変えて書いた行なら、前の行の upto を grow_from に入れる（新しい項目だけ描き進める）。"""
    import json
    if new is None or prev is None:
        return new
    a, b = json.loads(new), json.loads(prev)
    if "upto" not in a:
        return new
    from .figures import base_key
    if base_key(a) != base_key(b):
        return new
    before = b.get("upto")
    if before == a["upto"]:
        return prev                                   # 同じ図をそのまま書き直しただけ
    a["grow_from"] = min(int(before), a["upto"]) if before is not None else a["upto"]
    return json.dumps(a, ensure_ascii=False, sort_keys=True)


def _reaction(raw, where: str) -> str | None:
    """つむぎの「寄り」：{number: "100人", lead: "信長の供は", say: "少なっ！"}。number は必ず書く。"""
    if raw is None:
        return None
    import json
    if not isinstance(raw, dict) or not str(raw.get("number", "")).strip():
        raise ScriptError(f"{where}: reaction には number（大きく出す数字）が要ります: {raw!r}")
    return json.dumps({k: str(v) for k, v in raw.items()}, ensure_ascii=False, sort_keys=True)


def _detail(raw, where: str, background) -> str | None:
    """絵の一部を大きく：{box: [x0, y0, x1, y1], label: 鉄砲隊, image: (省けばその場面の背景)}。
    box は元の絵の画素か、0〜1 の割合（4つとも1以下なら割合とみなす）。"""
    if raw is None:
        return None
    import json
    if not isinstance(raw, dict) or "box" not in raw:
        raise ScriptError(f"{where}: detail には box（[左, 上, 右, 下]）が要ります: {raw!r}")
    box = raw["box"]
    if (not isinstance(box, (list, tuple)) or len(box) != 4
            or not all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in box)):
        raise ScriptError(f"{where}: detail の box は数4つ [左, 上, 右, 下] です: {box!r}")
    if not (box[0] < box[2] and box[1] < box[3]) or min(box) < 0:
        raise ScriptError(f"{where}: detail の box は 左<右・上<下 の順に書きます: {box!r}")
    image = raw.get("image") or (background.image if background is not None else None)
    if not image:
        raise ScriptError(f"{where}: detail は背景の絵があるときだけ使えます（別の絵なら image: を書く）")
    unknown = set(raw) - {"box", "label", "image"}
    if unknown:
        raise ScriptError(f"{where}: detail に書けるのは box・label・image です: {sorted(unknown)}")
    return json.dumps({"image": str(image), "box": [float(v) for v in box], "label": str(raw.get("label", ""))},
                      ensure_ascii=False, sort_keys=True)


MARK_TYPES = ("circle", "arrow", "underline", "strike", "note")


def _marks(raw, where: str, figure: str | None) -> list[dict]:
    """赤ペン：[{type: circle, at: 2}, {type: note, at: [0.6, 0.2], text: ここ}]。
    at は図の何番目の項目（1から）か、絵の上の点 [x, y]・範囲 [x0, y0, x1, y1]（割合か元の絵の画素）。"""
    if isinstance(raw, dict):
        raw = [raw]
    if not isinstance(raw, list):
        raise ScriptError(f"{where}: mark は書き込みの並び（[{{type: circle, at: 2}}]）です: {raw!r}")
    out = []
    for m in raw:
        if not isinstance(m, dict) or m.get("type") not in MARK_TYPES:
            raise ScriptError(f"{where}: mark の type は {' / '.join(MARK_TYPES)} のどれかです: {m!r}")
        at = m.get("at")
        if isinstance(at, bool) or at is None:
            raise ScriptError(f"{where}: mark には at（図の項目の番号か、絵の上の [x, y]・[x0, y0, x1, y1]）が要ります")
        if isinstance(at, int):
            if at < 1:
                raise ScriptError(f"{where}: mark の at（項目の番号）は1からです: {at}")
            if figure is None:
                raise ScriptError(f"{where}: mark の at を番号で書けるのは図が出ているときだけです")
        elif not (isinstance(at, (list, tuple)) and len(at) in (2, 4)
                  and all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in at)):
            raise ScriptError(f"{where}: mark の at は番号か [x, y]・[x0, y0, x1, y1] です: {at!r}")
        if m["type"] == "note" and not str(m.get("text", "")).strip():
            raise ScriptError(f"{where}: note には text が要ります")
        unknown = set(m) - {"type", "at", "text", "from"}
        if unknown:
            raise ScriptError(f"{where}: mark に書けるのは type・at・text・from です: {sorted(unknown)}")
        out.append({k: (list(v) if isinstance(v, tuple) else v) for k, v in m.items()})
    return out


def _mark_target(detail, figure, background, portrait, section) -> str:
    """書き込みが乗っているもの。これが替わると前の書き込みは消える。"""
    from .figures import base_key
    if detail:
        return f"d{section}:{detail}"
    if figure:
        return f"f{section}:{base_key(figure)}"
    return f"p{section}:{background.image if background else ''}:{portrait.image if portrait else ''}"


def _speaker_and_text(raw: dict, where: str) -> tuple[str, str]:
    found = [(key, raw[key]) for key in SPEAKERS if key in raw]
    if len(found) != 1:
        raise ScriptError(f"{where}: 1行に話者（{' / '.join(SPEAKERS)}）は1人だけ書きます: {raw!r}")
    speaker, text = found[0]
    text = str(text or "").strip()
    if not text:
        raise ScriptError(f"{where}: せりふが空です")
    who = raw.get("who")
    if speaker == "人物":
        if not who or str(who) in SPEAKERS:
            raise ScriptError(f"{where}: 「人物」の行には who（誰の言葉か。config.yaml の roles の名前）が要ります")
        return str(who), text
    if who:
        raise ScriptError(f"{where}: who は「人物」の行にだけ書きます")
    return speaker, text


def parse(data: dict, path: Path | None = None, glossary: dict[str, str] | None = None,
          places: dict | None = None) -> Script:
    if not isinstance(data, dict):
        raise ScriptError("台本の一番上は辞書（title / sections ...）にします")
    timeline = data.get("timeline") or {}
    events = [(int(y), str(label)) for y, label in timeline.get("events", [])]
    sections: list[Section] = []
    lines: list[Line] = []
    background: Picture | None = None
    year: int | None = timeline.get("start")
    known_tones = None
    try:
        from .voice import TONES
        known_tones = set(TONES)
    except Exception:  # pragma: no cover - voice が読めないときは確認を省く
        pass

    for s_index, raw_section in enumerate(data.get("sections") or []):
        where_s = f"{s_index + 1}節"
        if "title" not in raw_section:
            raise ScriptError(f"{where_s}: title がありません")
        sections.append(Section(index=s_index, title=str(raw_section["title"])))
        if "background" in raw_section:
            background = _picture(raw_section["background"], where_s)
        portrait = _picture(raw_section.get("portrait"), where_s)
        card = _card(raw_section.get("card"), where_s)
        if raw_section.get("year") is not None:
            year = int(raw_section["year"])
        elif _card_year(card) is not None:
            year = _card_year(card)
        memo: list[Card] = [card] if card is not None else []
        figure = _figure(raw_section.get("figure"), where_s)
        raw_lines = raw_section.get("lines") or []
        if not raw_lines:
            raise ScriptError(f"{where_s}: lines がありません")
        marks: list[dict] = []
        mark_on = None
        for l_index, raw in enumerate(raw_lines):
            where = f"{where_s} {l_index + 1}行目"
            speaker, text = _speaker_and_text(raw, where)
            if "background" in raw:
                background = _picture(raw["background"], where)
            if "portrait" in raw:
                portrait = _picture(raw["portrait"], where)
            if "figure" in raw:
                figure = _grown(_figure(raw["figure"], where), figure)
            if "card" in raw:
                card = _card(raw["card"], where)
                if card is not None and (not memo or memo[-1] != card):
                    memo.append(card)
            if raw.get("year") is not None:
                year = int(raw["year"])
            elif "card" in raw and _card_year(card) is not None:
                # 札に年があれば、年表の印（と「この時○歳」）もその年へ（10-04 の確認で、札だけ進んで年齢がずれていた）
                year = _card_year(card)
            tone = str(raw.get("tone", "普通"))
            if known_tones is not None and tone not in known_tones:
                raise ScriptError(f"{where}: tone「{tone}」は定義されていません（{'、'.join(sorted(known_tones))}）")
            shorts = raw.get("short") or ()
            if isinstance(shorts, str):
                shorts = (shorts,)
            pause = raw.get("pause")
            detail = _detail(raw.get("detail"), where, background)
            # 赤ペンは、同じもの（大きく見せた絵・図・背景）の上にいるあいだ足していく。替わると消える
            target = _mark_target(detail, figure, background, portrait, s_index)
            if target != mark_on:
                marks, mark_on = [], target
            start = len(marks)
            if "mark" in raw:
                if raw["mark"] in (None, []):
                    marks = []
                    start = 0
                else:
                    marks = marks + _marks(raw["mark"], where, figure if not detail else None)
            import json as _json
            mark = (_json.dumps({"items": marks, "from": start}, ensure_ascii=False, sort_keys=True)
                    if marks else None)
            lines.append(Line(
                index=len(lines), section=s_index, speaker=speaker, text=text, tone=tone,
                pause=float(pause) if pause is not None else None, shorts=tuple(shorts),
                background=background, portrait=portrait, card=card, year=year,
                memo=tuple(reversed(memo[-MEMO_SIZE:])), figure=figure,
                bubble=_bubble(raw.get("bubble"), where), hook=bool(raw.get("hook")), icon=(str(raw["icon"]) if raw.get("icon") else None),
                reaction=_reaction(raw.get("reaction"), where), detail=detail, mark=mark,
            ))
    if not lines:
        raise ScriptError("せりふが1行もありません")
    shorts_meta = data.get("shorts") or {}
    used = {s for line in lines for s in line.shorts}
    missing = used - set(shorts_meta)
    if missing:
        raise ScriptError(f"shorts に定義のないショートが使われています: {sorted(missing)}")
    gl = {**(glossary or {}), **{str(k): str(v) for k, v in (data.get("terms") or {}).items()}}
    long = [k for k, v in gl.items() if len(v) > TERM_MAX]
    if long:
        raise ScriptError(f"用語の説明は{TERM_MAX}字までです: {long}")
    attach_terms(lines, gl)
    if places:
        attach_terms(lines, places, "place", lambda w: (w, *places[w]), mask=[k for k in gl if k not in places])
    people = {}
    for name, v in (data.get("people") or {}).items():
        if not isinstance(v, dict) or "born" not in v:
            raise ScriptError(f"people の {name} には born（生まれた日 YYYY-MM-DD）が要ります")
        people[str(name)] = {"born": str(v["born"]), "died": str(v.get("died", "")),
                             "match": [str(name)] + [str(m) for m in v.get("match", [])]}
    return Script(
        title=str(data.get("title", "")), series=str(data.get("series", "")),
        timeline_start=timeline.get("start"), timeline_end=timeline.get("end"), events=events,
        sections=sections, lines=lines, shorts=shorts_meta, path=path,
        next=dict(data.get("next") or {}), people=people, thumbnail=dict(data.get("thumbnail") or {}),
        tags=[str(t) for t in (data.get("tags") or [])],
        look={k: bool(data[k]) for k in LOOK_KEYS if k in data},
        playlists=_names(data["playlists"]) if "playlists" in data else _names(data.get("series")),
        shorts_playlists=_names(data.get("shorts_playlists")),
        en=_english(data.get("en"), len(sections)),
    )


def _names(v) -> list[str]:
    """再生リストの名前の並び。1つなら文字列で書いてもよい。空・null は入れない。"""
    if v is None or v == "":
        return []
    items = [v] if isinstance(v, str) else list(v)
    out = [str(x).strip() for x in items if str(x or "").strip()]
    long = [x for x in out if len(x) > 150]
    if long:
        raise ScriptError(f"再生リストの名前は150字までです: {long}")
    return list(dict.fromkeys(out))


def _english(v, n_sections: int) -> dict:
    """en: {title, description, chapters}。章の題は節と同じ数（時刻は日本語の概要欄の目次から取る）。"""
    if not v:
        return {}
    if not isinstance(v, dict) or not str(v.get("title", "")).strip():
        raise ScriptError("en: には title（英語の題名）が要ります")
    out = {"title": str(v["title"]).strip(), "description": str(v.get("description", "")).strip(),
           "chapters": [str(c).strip() for c in (v.get("chapters") or [])]}
    if len(out["title"]) > 100:
        raise ScriptError(f"en.title は100字までです（{len(out['title'])}字）")
    if any(c in out["title"] + out["description"] for c in "<>"):
        raise ScriptError("en の題名・説明に < > は使えません（YouTube が受け付けない）")
    if out["chapters"] and len(out["chapters"]) != n_sections:
        raise ScriptError(f"en.chapters は節と同じ数にします（節 {n_sections}・章 {len(out['chapters'])}）")
    return out


def load(path: str | Path) -> Script:
    path = Path(path)
    with path.open(encoding="utf-8") as f:
        data = yaml.safe_load(f)
    gfile = path.resolve().parent.parent / "terms.yaml"       # scripts/ の隣
    glossary = {}
    if gfile.exists():
        glossary = {str(k): str(v) for k, v in (yaml.safe_load(gfile.read_text(encoding="utf-8")) or {}).items()}
    pfile = path.resolve().parent.parent / "places.yaml"
    places = {}
    if pfile.exists():
        places = {str(k): (float(v[0]), float(v[1]))
                  for k, v in (yaml.safe_load(pfile.read_text(encoding="utf-8")) or {}).items()}
    return parse(data, path, glossary, places)


def digest(path: str | Path) -> str:
    """台本ファイルの中身のハッシュ。承認（approve）はこの値に対して出す。"""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def person_of(people: dict, pic) -> str | None:
    """肖像の人物。who があればそれ、無ければ caption の名前（「（」より前）が人物名か別名で終わるもの。"""
    if pic is None or not getattr(pic, "age", True):
        return None
    if pic.who:
        return pic.who if pic.who in people else None
    name = pic.caption.partition("（")[0].strip()
    for person, v in people.items():
        if any(name == m or name.endswith(m) for m in v["match"]):
            return person
    return None


def age_at(info: dict, year: int | None, card=None) -> int | None:
    """その場面の年での満年齢。月は、同じ年の札（「1774年5月」など）があればそれを使い、無ければ年の半ば（7月1日）とみなす。
    生まれる前・1歳未満・亡くなったあとは None。"""
    import re
    if year is None:
        return None
    month, day = 7, 1
    if card is not None:
        m = re.match(r"(\d{3,4})年\s*(?:(\d{1,2})月)?\s*(?:(\d{1,2})日)?", card.head)
        if m and int(m.group(1)) == year and m.group(2):
            month, day = int(m.group(2)), int(m.group(3) or 1)
    by, bm, bd = (int(x) for x in info["born"].split("-"))
    if info.get("died"):
        dy, dm, dd = (int(x) for x in info["died"].split("-"))
        if (year, month, day) > (dy, dm, dd):
            return None
    age = year - by - (1 if (month, day) < (bm, bd) else 0)
    return age if age >= 1 else None
