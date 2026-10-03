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

画面の指定（background / portrait / card / year）は「次に変えるまで続く」。
portrait と card は節が変わると消える。null を書けばその行で消せる。
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from pathlib import Path

import yaml

SPEAKERS = ("語り", "聞き")
_UNSET = object()


@dataclass(frozen=True)
class Picture:
    image: str
    credit: str = ""      # 背景の出典（画面の下に小さく出す）
    caption: str = ""     # 肖像の下に出す説明


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
                   caption=str(raw.get("caption", "")))


def _card(raw, where: str) -> Card | None:
    if raw is None:
        return None
    if isinstance(raw, str):
        return Card(head=raw)
    if not isinstance(raw, dict) or "head" not in raw:
        raise ScriptError(f"{where}: card には head が要ります: {raw!r}")
    return Card(head=str(raw["head"]), body=str(raw.get("body", "")))


def _speaker_and_text(raw: dict, where: str) -> tuple[str, str]:
    found = [(key, raw[key]) for key in SPEAKERS if key in raw]
    if len(found) != 1:
        raise ScriptError(f"{where}: 1行に話者（{' / '.join(SPEAKERS)}）は1人だけ書きます: {raw!r}")
    speaker, text = found[0]
    text = str(text or "").strip()
    if not text:
        raise ScriptError(f"{where}: せりふが空です")
    return speaker, text


def parse(data: dict, path: Path | None = None) -> Script:
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
        raw_lines = raw_section.get("lines") or []
        if not raw_lines:
            raise ScriptError(f"{where_s}: lines がありません")
        for l_index, raw in enumerate(raw_lines):
            where = f"{where_s} {l_index + 1}行目"
            speaker, text = _speaker_and_text(raw, where)
            if "background" in raw:
                background = _picture(raw["background"], where)
            if "portrait" in raw:
                portrait = _picture(raw["portrait"], where)
            if "card" in raw:
                card = _card(raw["card"], where)
            if raw.get("year") is not None:
                year = int(raw["year"])
            tone = str(raw.get("tone", "普通"))
            if known_tones is not None and tone not in known_tones:
                raise ScriptError(f"{where}: tone「{tone}」は定義されていません（{'、'.join(sorted(known_tones))}）")
            shorts = raw.get("short") or ()
            if isinstance(shorts, str):
                shorts = (shorts,)
            pause = raw.get("pause")
            lines.append(Line(
                index=len(lines), section=s_index, speaker=speaker, text=text, tone=tone,
                pause=float(pause) if pause is not None else None, shorts=tuple(shorts),
                background=background, portrait=portrait, card=card, year=year,
            ))
    if not lines:
        raise ScriptError("せりふが1行もありません")
    shorts_meta = data.get("shorts") or {}
    used = {s for line in lines for s in line.shorts}
    missing = used - set(shorts_meta)
    if missing:
        raise ScriptError(f"shorts に定義のないショートが使われています: {sorted(missing)}")
    return Script(
        title=str(data.get("title", "")), series=str(data.get("series", "")),
        timeline_start=timeline.get("start"), timeline_end=timeline.get("end"), events=events,
        sections=sections, lines=lines, shorts=shorts_meta, path=path,
    )


def load(path: str | Path) -> Script:
    path = Path(path)
    with path.open(encoding="utf-8") as f:
        return parse(yaml.safe_load(f), path)


def digest(path: str | Path) -> str:
    """台本ファイルの中身のハッシュ。承認（approve）はこの値に対して出す。"""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
