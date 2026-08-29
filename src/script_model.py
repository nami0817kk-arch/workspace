"""台本 Markdown のパースとデータモデル。

台本フォーマット（scripts/sample.md も参照）::

    ---
    title: 【ゆっくり解説】タイトル
    tags: [ゆっくり解説]
    ---

    ## シーン名
    @bg: assets/backgrounds/default.png

    霊夢: 今日は〇〇について解説するわよ。
      telop: 〇〇ってなに？
      emotion: normal
      se: assets/audio/se_pon.wav
      pause: 0.6
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

import yaml

# 「霊夢: セリフ」。全角コロンも受け付ける
LINE_RE = re.compile(r"^(?P<speaker>[^:：]{1,20})[:：]\s*(?P<text>.*)$")
ATTR_RE = re.compile(r"^(?P<key>[a-zA-Z_]+)[:：]\s*(?P<value>.*)$")
DIRECTIVE_RE = re.compile(r"^@(?P<key>[a-zA-Z_]+)[:：]\s*(?P<value>.*)$")

LINE_ATTRS = {"telop", "emotion", "pause", "image", "speed", "no_telop", "se", "source", "card"}

# 情報の確度。ニュース系では、これを画面に出さないと視聴者が判断できない
SOURCE_TIERS = {
    "official": "official",   # クラブ・当事者が発表した
    "report": "report",       # 報道機関が報じた
    "rumor": "rumor",         # 未確認・噂の段階
    "確定": "official",
    "公式": "official",
    "発表": "official",
    "報道": "report",
    "噂": "rumor",
    "未確認": "rumor",
}
SCENE_DIRECTIVES = {"bg", "background"}

# 読み上げ時間の概算（TTS を使わない --no-tts モード用）
SECONDS_PER_CHAR = 0.16
BASE_SECONDS = 0.45
MIN_SECONDS = 0.8


class ScriptError(Exception):
    """台本の書式エラー。行番号つきで投げる。"""


@dataclass
class Line:
    """1発話。音声1ファイル・テロップ1枚に対応する。"""

    speaker: str
    text: str
    telop: str | None = None
    emotion: str = "normal"
    image: str | None = None
    se: str | None = None
    card: str | None = None     # frontmatter の cards で定義したカードの名前
    source: str | None = None   # official / report / rumor
    pause: float | None = None
    speed: float | None = None
    no_telop: bool = False
    source_line: int = 0

    # ビルド中に埋まる
    audio_path: Path | None = None
    duration: float = 0.0
    start: float = 0.0

    def telop_text(self) -> str:
        """画面に表示する文字列。telop 未指定ならセリフをそのまま使う。"""
        if self.no_telop:
            return ""
        return self.telop if self.telop is not None else self.text

    def estimated_duration(self) -> float:
        """音声を作らない場合の想定尺（秒）。"""
        return max(MIN_SECONDS, BASE_SECONDS + len(self.text) * SECONDS_PER_CHAR)


@dataclass
class Scene:
    """章。YouTube のチャプターと1対1で対応させる。"""

    title: str
    lines: list[Line] = field(default_factory=list)
    background: str | None = None

    @property
    def duration(self) -> float:
        return sum(line.duration for line in self.lines)


@dataclass
class Script:
    title: str
    scenes: list[Scene] = field(default_factory=list)
    description: str = ""
    tags: list[str] = field(default_factory=list)
    sources: list[str] = field(default_factory=list)
    background: str | None = None   # 動画全体の既定背景
    cards: dict = field(default_factory=dict)   # 画面に差し込むカードの定義
    meta: dict = field(default_factory=dict)
    source: Path | None = None

    @property
    def lines(self) -> list[Line]:
        return [line for scene in self.scenes for line in scene.lines]

    @property
    def duration(self) -> float:
        return sum(scene.duration for scene in self.scenes)

    def char_count(self) -> int:
        return sum(len(line.text) for line in self.lines)

    def to_dict(self) -> dict:
        return {
            "title": self.title,
            "description": self.description,
            "tags": self.tags,
            "scenes": [
                {
                    "title": scene.title,
                    "background": scene.background,
                    "lines": [
                        {
                            "speaker": line.speaker,
                            "text": line.text,
                            "telop": line.telop_text(),
                            "emotion": line.emotion,
                            "image": line.image,
                            "start": round(line.start, 3),
                            "duration": round(line.duration, 3),
                        }
                        for line in scene.lines
                    ],
                }
                for scene in self.scenes
            ],
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), ensure_ascii=False, indent=2)


def load_script(path: str | Path) -> Script:
    path = Path(path)
    if not path.exists():
        raise ScriptError(f"台本が見つかりません: {path}")
    script = parse_script(path.read_text(encoding="utf-8"))
    script.source = path
    if not script.title:
        script.title = path.stem
    return script


def parse_script(text: str) -> Script:
    body, meta = _split_frontmatter(text)

    script = Script(
        title=str(meta.get("title", "")),
        description=str(meta.get("description", "")),
        tags=[str(tag) for tag in (meta.get("tags") or [])],
        sources=[str(url) for url in (meta.get("sources") or [])],
        background=str(meta["bg"]) if meta.get("bg") else None,
        cards=dict(meta.get("cards") or {}),
        meta=meta,
    )

    current: Scene | None = None
    last_line: Line | None = None

    for number, raw in enumerate(body.splitlines(), start=meta.get("_offset", 0) + 1):
        stripped = raw.strip()
        if not stripped or stripped.startswith("//"):
            continue

        if stripped.startswith("#"):
            title = stripped.lstrip("#").strip()
            if not title:
                raise ScriptError(f"{number}行目: シーン見出しが空です")
            current = Scene(title=title)
            script.scenes.append(current)
            last_line = None
            continue

        directive = DIRECTIVE_RE.match(stripped)
        if directive:
            if current is None:
                raise ScriptError(f"{number}行目: @指定の前にシーン見出し（## ...）が必要です")
            key = directive["key"].lower()
            if key not in SCENE_DIRECTIVES:
                raise ScriptError(f"{number}行目: 未対応の指定 @{key}")
            current.background = directive["value"].strip() or None
            continue

        # インデントされた行は直前のセリフへの属性指定
        if raw[:1] in (" ", "\t") and last_line is not None:
            attr = ATTR_RE.match(stripped)
            if not attr:
                raise ScriptError(f"{number}行目: 属性は『key: 値』の形式で書いてください")
            _apply_attr(last_line, attr["key"].lower(), attr["value"].strip(), number)
            continue

        match = LINE_RE.match(stripped)
        if not match:
            raise ScriptError(
                f"{number}行目: 『話者: セリフ』の形式ではありません -> {stripped[:40]}"
            )
        if current is None:
            current = Scene(title="本編")
            script.scenes.append(current)

        content = match["text"].strip()
        if not content:
            raise ScriptError(f"{number}行目: セリフが空です")
        last_line = Line(
            speaker=match["speaker"].strip(),
            text=content,
            source_line=number,
        )
        current.lines.append(last_line)

    if not script.lines:
        raise ScriptError("台本にセリフが1つもありません")

    for line in script.lines:
        if line.card and line.card not in ("none", "なし") and line.card not in script.cards:
            known = ", ".join(script.cards) or "（定義なし）"
            raise ScriptError(
                f"{line.source_line}行目: カード『{line.card}』は frontmatter の "
                f"cards に定義されていません（定義済み: {known}）"
            )
    return script


def _apply_attr(line: Line, key: str, value: str, number: int) -> None:
    if key not in LINE_ATTRS:
        raise ScriptError(f"{number}行目: 未対応の属性『{key}』（使えるのは {sorted(LINE_ATTRS)}）")
    if key == "source":
        tier = SOURCE_TIERS.get(value.strip().lower()) or SOURCE_TIERS.get(value.strip())
        if tier is None:
            raise ScriptError(
                f"{number}行目: source は {sorted(set(SOURCE_TIERS.values()))} "
                "または 確定/報道/噂 で指定してください"
            )
        line.source = tier
    elif key in ("pause", "speed"):
        try:
            setattr(line, key, float(value))
        except ValueError as exc:
            raise ScriptError(f"{number}行目: {key} には数値を指定してください") from exc
    elif key == "no_telop":
        line.no_telop = value.lower() not in ("false", "no", "0", "")
    else:
        setattr(line, key, value)


def _split_frontmatter(text: str) -> tuple[str, dict]:
    """先頭の --- で囲まれた YAML を切り出す。無ければ空 dict。"""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return text, {}
    for index in range(1, len(lines)):
        if lines[index].strip() == "---":
            raw = "\n".join(lines[1:index])
            meta = yaml.safe_load(raw) or {}
            if not isinstance(meta, dict):
                raise ScriptError("frontmatter は key: value のマッピングにしてください")
            meta["_offset"] = index + 1
            return "\n".join(lines[index + 1 :]), meta
    raise ScriptError("frontmatter の終端 --- がありません")
