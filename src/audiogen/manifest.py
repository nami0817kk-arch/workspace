"""マニフェストによる一括生成。

ゲーム1本ぶんの効果音と BGM を1つの JSON にまとめて宣言し、
そこから素材一式を作り直せるようにする。設定と seed が残っているので、
あとから同じ音をいつでも再現できる。

前回の生成内容を出力先の索引ファイルに記録しているため、
2回目以降は変更のあったものだけを作り直す。

マニフェストの例::

    {
      "sample_rate": 44100,
      "sfx": [
        {"name": "coin", "as": "se/coin", "seed": 1},
        {"name": "footstep", "as": "se/step", "count": 4, "seed": 2}
      ],
      "bgm": [
        {"as": "bgm/title", "style": "calm", "bars": 16, "seed": 7, "stereo": true}
      ]
    }
"""

from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass, field
from typing import Any, Sequence

from . import bgm as bgm_module
from . import sfx
from .core import SAMPLE_RATE, duration_of, write_wav

INDEX_NAME = ".audiogen-index.json"
"""出力先に置く索引ファイル。前回どの設定で作ったかを覚えておく。"""

FORMAT_VERSION = 1
"""索引の形式。生成のしかたを変えたときはここを上げて作り直させる。"""

_SFX_KEYS = {"name", "as", "seed", "pitch", "count", "spread"}
_BGM_KEYS = {
    "as", "style", "key", "scale", "bpm", "bars", "seed", "progression",
    "drums", "structure", "swing", "humanize", "parts", "loop", "stereo",
    "chord_instrument", "bass_instrument", "lead_instrument",
}


class ManifestError(ValueError):
    """マニフェストの書き方が正しくないときに投げる。"""


@dataclass(frozen=True)
class Asset:
    """マニフェストの1項目。"""

    kind: str
    """``"sfx"`` か ``"bgm"``。"""
    path: str
    """出力先からの相対パス(拡張子なし)。"""
    spec: dict[str, Any]
    sample_rate: int

    def fingerprint(self) -> str:
        """設定から決まる指紋。1文字でも変われば作り直す。"""
        payload = json.dumps(
            {
                "version": FORMAT_VERSION,
                "kind": self.kind,
                "sample_rate": self.sample_rate,
                "spec": self.spec,
            },
            sort_keys=True,
            ensure_ascii=False,
        )
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]

    def outputs(self) -> list[str]:
        """この項目が書き出すファイル名(拡張子つき、相対パス)。"""
        count = int(self.spec.get("count", 1))
        if self.kind == "sfx" and count > 1:
            return [f"{self.path}_{index}.wav" for index in range(1, count + 1)]
        return [f"{self.path}.wav"]


@dataclass
class Manifest:
    """マニフェスト1つぶんの内容。"""

    sample_rate: int = SAMPLE_RATE
    output: str = "output"
    assets: list[Asset] = field(default_factory=list)


@dataclass
class BuildResult:
    """1項目の生成結果。"""

    asset: Asset
    files: list[str]
    status: str
    """``"written"``(生成した) / ``"skipped"``(前回と同じ) / ``"planned"``(下見)。"""
    seconds: float = 0.0


def _relative_path(value: Any, index: int, kind: str) -> str:
    """出力先を飛び出さない相対パスかどうかを確かめる。"""
    if not isinstance(value, str) or not value.strip():
        raise ManifestError(f"{kind}[{index}]: 'as' must be a non-empty string")
    path = value.strip().replace("\\", "/")
    if path.startswith("/") or os.path.isabs(path) or ".." in path.split("/"):
        raise ManifestError(f"{kind}[{index}]: 'as' must stay inside the output directory: {value!r}")
    return path


def parse(data: Any) -> Manifest:
    """読み込んだ JSON をマニフェストに変換する。"""
    if not isinstance(data, dict):
        raise ManifestError("manifest must be a JSON object")

    unknown = set(data) - {"sample_rate", "output", "sfx", "bgm"}
    if unknown:
        raise ManifestError(f"unknown top-level keys: {', '.join(sorted(unknown))}")

    sample_rate = int(data.get("sample_rate", SAMPLE_RATE))
    if sample_rate <= 0:
        raise ManifestError("sample_rate must be positive")
    manifest = Manifest(sample_rate=sample_rate, output=str(data.get("output", "output")))

    for index, entry in enumerate(data.get("sfx", []) or []):
        if not isinstance(entry, dict):
            raise ManifestError(f"sfx[{index}]: entry must be an object")
        unknown = set(entry) - _SFX_KEYS
        if unknown:
            raise ManifestError(f"sfx[{index}]: unknown keys: {', '.join(sorted(unknown))}")
        name = entry.get("name")
        if name not in sfx.PRESETS:
            raise ManifestError(f"sfx[{index}]: unknown preset {name!r}")
        if int(entry.get("count", 1)) < 1:
            raise ManifestError(f"sfx[{index}]: 'count' must be >= 1")
        spec = {key: value for key, value in entry.items() if key != "as"}
        path = _relative_path(entry.get("as", name), index, "sfx")
        manifest.assets.append(Asset("sfx", path, spec, sample_rate))

    for index, entry in enumerate(data.get("bgm", []) or []):
        if not isinstance(entry, dict):
            raise ManifestError(f"bgm[{index}]: entry must be an object")
        unknown = set(entry) - _BGM_KEYS
        if unknown:
            raise ManifestError(f"bgm[{index}]: unknown keys: {', '.join(sorted(unknown))}")
        spec = {key: value for key, value in entry.items() if key != "as"}
        path = _relative_path(entry.get("as", f"bgm_{entry.get('style', 'calm')}"), index, "bgm")
        manifest.assets.append(Asset("bgm", path, spec, sample_rate))

    if not manifest.assets:
        raise ManifestError("manifest contains no assets")
    return manifest


def load(path: str | os.PathLike[str]) -> Manifest:
    """JSON ファイルからマニフェストを読み込む。"""
    with open(path, "r", encoding="utf-8") as fp:
        try:
            data = json.load(fp)
        except json.JSONDecodeError as exc:
            raise ManifestError(f"{path}: invalid JSON ({exc})") from None
    return parse(data)


def _render(asset: Asset) -> list[tuple[str, list[float], int]]:
    """1項目を音にする。``(ファイル名, サンプル, チャンネル数)`` を返す。"""
    spec = dict(asset.spec)
    sr = asset.sample_rate
    if asset.kind == "sfx":
        name = spec.pop("name")
        count = int(spec.pop("count", 1))
        seed = spec.pop("seed", None)
        if count > 1:
            takes = sfx.variations(name, count=count, sr=sr, seed=seed, **spec)
            return [(path, take, 1) for path, take in zip(asset.outputs(), takes)]
        spec.pop("spread", None)
        return [(asset.outputs()[0], sfx.generate(name, sr=sr, seed=seed, **spec), 1)]

    stereo = bool(spec.pop("stereo", False))
    if "drums" in spec:
        spec["drum_pattern"] = spec.pop("drums")
    if "parts" in spec:
        spec["parts"] = tuple(spec["parts"])
    config = bgm_module.BGMConfig(sr=sr, stereo=stereo, **spec)
    samples = bgm_module.generate_stereo(config) if stereo else bgm_module.generate(config)
    return [(asset.outputs()[0], samples, 2 if stereo else 1)]


def _read_index(directory: str) -> dict[str, str]:
    try:
        with open(os.path.join(directory, INDEX_NAME), "r", encoding="utf-8") as fp:
            data = json.load(fp)
    except (OSError, json.JSONDecodeError):
        return {}
    entries = data.get("entries") if isinstance(data, dict) else None
    return entries if isinstance(entries, dict) else {}


def _write_index(directory: str, entries: dict[str, str]) -> None:
    os.makedirs(directory, exist_ok=True)
    with open(os.path.join(directory, INDEX_NAME), "w", encoding="utf-8") as fp:
        json.dump({"version": FORMAT_VERSION, "entries": entries}, fp, indent=2, sort_keys=True)
        fp.write("\n")


def build(
    manifest: Manifest,
    directory: str | None = None,
    force: bool = False,
    dry_run: bool = False,
) -> list[BuildResult]:
    """マニフェストの内容を生成する。

    前回と設定が変わっていない項目は、出力ファイルが揃っていれば飛ばす。
    ``force`` ですべて作り直し、``dry_run`` では何も書かずに予定だけ返す。
    """
    directory = directory or manifest.output
    index = {} if force else _read_index(directory)
    updated = dict(index)
    results: list[BuildResult] = []

    for asset in manifest.assets:
        files = asset.outputs()
        fingerprint = asset.fingerprint()
        unchanged = index.get(asset.path) == fingerprint and all(
            os.path.exists(os.path.join(directory, name)) for name in files
        )
        if unchanged and not force:
            results.append(BuildResult(asset, files, "skipped"))
            continue
        if dry_run:
            results.append(BuildResult(asset, files, "planned"))
            continue

        seconds = 0.0
        for name, samples, channels in _render(asset):
            write_wav(os.path.join(directory, name), samples, sr=asset.sample_rate, channels=channels)
            seconds += duration_of(samples, asset.sample_rate, channels)
        updated[asset.path] = fingerprint
        results.append(BuildResult(asset, files, "written", seconds))

    if not dry_run:
        _write_index(directory, updated)
    return results


def summarise(results: Sequence[BuildResult]) -> dict[str, int]:
    """結果の内訳を数える。"""
    counts: dict[str, int] = {}
    for result in results:
        counts[result.status] = counts.get(result.status, 0) + 1
    return counts
