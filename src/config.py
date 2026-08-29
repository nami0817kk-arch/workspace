"""config/project.yaml を読み込んで型付きの設定オブジェクトにする。"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONFIG_PATH = ROOT / "config" / "project.yaml"

# 環境に日本語フォントが無いと文字が豆腐になるため、候補を順に探す
FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf",
    "/usr/share/fonts/opentype/ipafont-gothic/ipagp.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
    "C:/Windows/Fonts/meiryob.ttc",
    "C:/Windows/Fonts/YuGothB.ttc",
    "C:/Windows/Fonts/msgothic.ttc",
    "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
]


class ConfigError(Exception):
    """設定ファイルが壊れている / 必要な項目が無い。"""


@dataclass
class VideoConfig:
    width: int = 1920
    height: int = 1080
    fps: int = 30
    font: str = ""
    telop_size: int = 58
    name_size: int = 40
    title_size: int = 72
    background: str = "assets/backgrounds/default.png"

    def font_path(self) -> Path:
        if self.font:
            path = _resolve(self.font)
            if not path.exists():
                raise ConfigError(f"フォントが見つかりません: {path}")
            return path
        for candidate in FONT_CANDIDATES:
            if Path(candidate).exists():
                return Path(candidate)
        raise ConfigError(
            "日本語フォントが見つかりません。config/project.yaml の video.font に "
            "TTF/OTF のパスを指定してください。"
        )

    def background_path(self) -> Path:
        return _resolve(self.background)


@dataclass
class VoicevoxConfig:
    # auto: ENGINE(HTTP) → CORE(ローカル) → 無音 の順に試す
    backend: str = "auto"  # auto / engine / core / silent
    url: str = "http://127.0.0.1:50021"
    core_dir: str = "vendor/voicevox"
    timeout: int = 60
    pause: float = 0.35


@dataclass
class CastMember:
    """登場キャラ1人ぶんの音声・立ち絵設定。"""

    name: str
    key: str
    style_id: int
    speed: float = 1.0
    pitch: float = 0.0
    intonation: float = 1.0
    position: str = "left"  # left / right / none
    color: str = "#ffffff"
    aliases: list[str] = field(default_factory=list)

    def sprite_dir(self) -> Path:
        return _resolve(f"assets/characters/{self.key}")


@dataclass
class ProjectConfig:
    video: VideoConfig
    voicevox: VoicevoxConfig
    cast: dict[str, CastMember]
    path: Path = DEFAULT_CONFIG_PATH

    def resolve_speaker(self, name: str) -> CastMember:
        """台本に書かれた話者名（表記ゆれ・別名を含む）を CastMember に解決する。"""
        wanted = name.strip()
        if wanted in self.cast:
            return self.cast[wanted]
        lowered = wanted.lower()
        for member in self.cast.values():
            if member.key.lower() == lowered:
                return member
            if any(alias.strip().lower() == lowered for alias in member.aliases):
                return member
        known = "/ ".join(self.cast)
        raise ConfigError(f"話者『{wanted}』は config に定義されていません（定義済み: {known}）")


def _resolve(value: str | Path) -> Path:
    """相対パスはリポジトリルート基準で解決する。"""
    path = Path(value)
    return path if path.is_absolute() else ROOT / path


def load_config(path: str | Path | None = None) -> ProjectConfig:
    config_path = Path(path) if path else DEFAULT_CONFIG_PATH
    if not config_path.exists():
        raise ConfigError(f"設定ファイルがありません: {config_path}")
    raw = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
    return build_config(raw, config_path)


def build_config(raw: dict, path: Path = DEFAULT_CONFIG_PATH) -> ProjectConfig:
    video = VideoConfig(**(raw.get("video") or {}))
    voicevox = VoicevoxConfig(**(raw.get("voicevox") or {}))

    cast_raw = raw.get("cast") or {}
    if not cast_raw:
        raise ConfigError("cast が空です。最低1人は話者を定義してください。")

    cast: dict[str, CastMember] = {}
    for name, values in cast_raw.items():
        values = dict(values or {})
        if "style_id" not in values:
            raise ConfigError(f"cast.{name}.style_id が未設定です")
        cast[name] = CastMember(
            name=name,
            key=values.get("key", name),
            style_id=int(values["style_id"]),
            speed=float(values.get("speed", 1.0)),
            pitch=float(values.get("pitch", 0.0)),
            intonation=float(values.get("intonation", 1.0)),
            position=values.get("position", "left"),
            color=values.get("color", "#ffffff"),
            aliases=list(values.get("aliases") or []),
        )
    return ProjectConfig(video=video, voicevox=voicevox, cast=cast, path=path)
