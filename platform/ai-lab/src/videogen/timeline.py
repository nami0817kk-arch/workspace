"""動画の構成（タイムライン）。

1シーン = 画像1枚 + 音声（任意）+ 字幕（任意）。
シーンの長さは **音声の長さから決まる** のが基本で、明示したいときだけ seconds を書く。
音声を先に作ってから画を並べる作り方（ナレーション動画）に合わせている。
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

from .errors import TimelineError

#: 画の動き（Ken Burns）
MOTIONS = ("none", "zoom_in", "zoom_out", "pan_left", "pan_right")

#: 音声も seconds も無いシーンの長さ
DEFAULT_SECONDS = 4.0
#: 音声から長さを決めたときに足す余白（読み終わりで画が切り替わらないように）
DEFAULT_TAIL = 0.3
#: これより短いシーンは作らない
MIN_SECONDS = 0.1

SIZE_RE = re.compile(r"\s*(\d+)\s*[x×]\s*(\d+)\s*")


def parse_size(size: str) -> tuple[int, int]:
    """'1920x1080' を (幅, 高さ) にする。"""
    match = SIZE_RE.fullmatch(str(size))
    if not match:
        raise TimelineError(f"size の指定が不正です: {size!r}（例: 1920x1080）")
    width, height = int(match.group(1)), int(match.group(2))
    if width % 2 or height % 2:
        # H.264 (yuv420p) は偶数でないと encode できない
        raise TimelineError(f"size は偶数で指定してください: {width}x{height}")
    return width, height


@dataclass
class Scene:
    """1シーン。"""

    image: str
    audio: str = ""
    text: str = ""
    seconds: float | None = None
    motion: str = "none"

    @classmethod
    def from_dict(cls, data: dict, index: int) -> Scene:
        if not isinstance(data, dict):
            raise TimelineError(f"シーン{index}: 辞書で書いてください")
        unknown = set(data) - {"image", "audio", "text", "seconds", "motion"}
        if unknown:
            raise TimelineError(
                f"シーン{index}: 知らない項目があります: {', '.join(sorted(unknown))}"
            )
        if not data.get("image"):
            raise TimelineError(f"シーン{index}: image（画像ファイル）が要ります")

        motion = str(data.get("motion", "none"))
        if motion not in MOTIONS:
            raise TimelineError(
                f"シーン{index}: motion に {motion!r} は指定できません（{', '.join(MOTIONS)}）"
            )
        seconds = data.get("seconds")
        if seconds is not None:
            seconds = float(seconds)
            if seconds < MIN_SECONDS:
                raise TimelineError(f"シーン{index}: seconds が短すぎます: {seconds}")
        return cls(
            image=str(data["image"]),
            audio=str(data.get("audio", "")),
            text=str(data.get("text", "")),
            seconds=seconds,
            motion=motion,
        )


@dataclass
class Timeline:
    """動画1本ぶんの構成。"""

    scenes: list[Scene] = field(default_factory=list)
    size: str = "1920x1080"
    fps: int = 30
    #: 全体に敷く BGM
    bgm: str = ""
    #: BGM の音量（dB）。ナレーションを消さないよう既定で大きく下げる
    bgm_gain_db: float = -18.0
    #: 先頭と末尾の暗転（秒）
    fade: float = 0.0
    #: 音声から長さを決めたときの余白
    tail: float = DEFAULT_TAIL
    #: 字幕を焼き込むときのフォント（libass が使う名前、またはフォントファイル）
    font: str = ""

    @property
    def dimensions(self) -> tuple[int, int]:
        return parse_size(self.size)

    @classmethod
    def from_dict(cls, data: dict) -> Timeline:
        if not isinstance(data, dict):
            raise TimelineError("タイムラインは辞書で書いてください")
        raw_scenes = data.get("scenes")
        if not isinstance(raw_scenes, list) or not raw_scenes:
            raise TimelineError("scenes に1つ以上のシーンが要ります")

        timeline = cls(
            scenes=[Scene.from_dict(scene, index) for index, scene in enumerate(raw_scenes, 1)],
            size=str(data.get("size", "1920x1080")),
            fps=int(data.get("fps", 30)),
            bgm=str(data.get("bgm", "")),
            bgm_gain_db=float(data.get("bgm_gain_db", -18.0)),
            fade=float(data.get("fade", 0.0)),
            tail=float(data.get("tail", DEFAULT_TAIL)),
            font=str(data.get("font", "")),
        )
        if timeline.fps <= 0:
            raise TimelineError(f"fps は正の数で指定してください: {timeline.fps}")
        if timeline.fade < 0:
            raise TimelineError(f"fade は0以上で指定してください: {timeline.fade}")
        parse_size(timeline.size)  # 描き始めてから落とさないよう、ここで検査する
        return timeline

    # --- 長さ ---------------------------------------------------------
    def durations(self, probe: Callable[[str], float] | None = None) -> list[float]:
        """各シーンの長さ（秒）。seconds > 音声の長さ > 既定値 の順に決める。"""
        from . import ffmpeg

        measure = probe or ffmpeg.probe_seconds
        lengths: list[float] = []
        for scene in self.scenes:
            if scene.seconds is not None:
                lengths.append(round(scene.seconds, 3))
            elif scene.audio:
                lengths.append(round(max(MIN_SECONDS, measure(scene.audio) + self.tail), 3))
            else:
                lengths.append(DEFAULT_SECONDS)
        return lengths

    def total_seconds(self, probe: Callable[[str], float] | None = None) -> float:
        return round(sum(self.durations(probe)), 3)

    def missing_files(self) -> list[str]:
        """存在しない素材の一覧（描き始める前にまとめて知らせるため）。"""
        candidates = [scene.image for scene in self.scenes]
        candidates += [scene.audio for scene in self.scenes if scene.audio]
        if self.bgm:
            candidates.append(self.bgm)
        return [path for path in candidates if not Path(path).is_file()]


# --- 読み込み ---------------------------------------------------------
def load(path_or_data: str | Path | dict) -> Timeline:
    """タイムラインを読み込む（辞書・JSON・YAML）。"""
    if isinstance(path_or_data, dict):
        return Timeline.from_dict(path_or_data)

    path = Path(path_or_data)
    if not path.is_file():
        raise TimelineError(f"構成ファイルがありません: {path}")
    text = path.read_text(encoding="utf-8")

    if path.suffix.lower() == ".json":
        data = json.loads(text)
    else:
        try:
            import yaml
        except ImportError as exc:  # pragma: no cover - 環境依存
            raise TimelineError("YAML を読むには PyYAML が要ります: pip install PyYAML") from exc
        data = yaml.safe_load(text)
    return Timeline.from_dict(data)
