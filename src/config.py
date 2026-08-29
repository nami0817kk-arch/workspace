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


# 英文の見出しをそのまま出すことがあるので、欧文はプロポーショナルなフォントを使う
LATIN_FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    "C:/Windows/Fonts/segoeui.ttf",
    "C:/Windows/Fonts/arial.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
]


class ConfigError(Exception):
    """設定ファイルが壊れている / 必要な項目が無い。"""


@dataclass
class VideoConfig:
    width: int = 1920
    height: int = 1080
    fps: int = 30
    font: str = ""
    latin_font: str = ""           # 英文用。空なら環境から自動検出
    telop_size: int = 58
    name_size: int = 40
    title_size: int = 72
    show_characters: bool = True   # False にすると立ち絵を出さないニュース風レイアウト
    headline_size: int = 74        # 立ち絵なしのときの見出し文字サイズ
    accent: str = "#3ea6ff"        # 見出し左のアクセント帯（確度バッジが無いとき）
    thumbnail_style: str = "band"  # band=黄色帯＋赤帯 / clean=文字組みだけ
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

    def latin_font_path(self) -> Path:
        """英文用のフォント。見つからなければ日本語フォントで代用する。"""
        if self.latin_font:
            path = _resolve(self.latin_font)
            if path.exists():
                return path
        for candidate in LATIN_FONT_CANDIDATES:
            if Path(candidate).exists():
                return Path(candidate)
        return self.font_path()

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
class AudioConfig:
    bgm: str = ""              # 空ならBGMなし
    bgm_gain: float = -22.0    # dB
    bgm_fade: float = 2.0      # 前後のフェード秒
    duck: bool = True          # 喋っている間だけBGMを下げる
    duck_ratio: float = 8.0
    se_gain: float = -8.0      # dB
    scene_se: str = ""         # シーン頭で鳴らす効果音
    loudness_target: float = -14.0  # LUFS。YouTube の基準。0 にすると正規化しない


@dataclass
class MotionConfig:
    enabled: bool = True
    fps: int = 30              # アニメーション部分の描画レート
    telop_in: float = 0.18     # テロップが出るときのアニメ秒
    speaker_pop: float = 0.16  # 話者が切り替わるときの立ち絵のバウンド秒
    scene_fade: float = 0.32   # シーン転換にかける秒数
    scene_transition: str = "dip"  # dip（暗転）/ crossfade（直接混ぜる）
    background_zoom: float = 1.0   # 静止画背景をゆっくり寄せる。1.0 で止めたまま


@dataclass
class TitleConfig:
    """冒頭と章の変わり目に差し込むタイトルカード。0 にすると出さない。"""

    intro: float = 2.6      # 冒頭のタイトル（秒）
    chapter: float = 1.4    # 章タイトル（秒）
    outro: float = 3.0      # 最後のカード（秒）
    fade: float = 0.32      # 出入りのフェード（秒）


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
    audio: AudioConfig = field(default_factory=AudioConfig)
    motion: MotionConfig = field(default_factory=MotionConfig)
    titles: TitleConfig = field(default_factory=TitleConfig)
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
    audio = AudioConfig(**(raw.get("audio") or {}))
    motion = MotionConfig(**(raw.get("motion") or {}))
    titles = TitleConfig(**(raw.get("titles") or {}))

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
    return ProjectConfig(
        video=video,
        voicevox=voicevox,
        cast=cast,
        audio=audio,
        motion=motion,
        titles=titles,
        path=path,
    )
