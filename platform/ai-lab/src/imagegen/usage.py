"""画像生成・音声合成の利用量と概算コストを記録する。

有料APIは「気づいたら使いすぎていた」が起きやすいので、生成のたびに1行ずつ
残しておき、`imagegen usage` で集計できるようにする。

**金額はあくまで概算**。各社の価格は頻繁に変わるため、請求額とは一致しない。
正確な数字は各社のダッシュボードで確認すること。
単価は `output/costs.json` を置けば上書きできる。
"""

from __future__ import annotations

import json
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

from .config import get_env, output_dir

LOG_NAME = "usage.jsonl"
COSTS_NAME = "costs.json"

#: 1枚あたりの概算単価（USD）。モデル名の前方一致で引く。
#: 2026年8月時点で調べた範囲の値で、公式の価格表とは別物。
DEFAULT_COSTS: dict[str, dict[str, float]] = {
    "openai": {"gpt-image-2": 0.03, "gpt-image-1": 0.02, "": 0.03},
    "gemini": {"": 0.04},
    "stability": {"ultra": 0.08, "core": 0.03, "sd3": 0.035, "": 0.03},
    "replicate": {"flux-schnell": 0.003, "flux": 0.03, "": 0.01},
    "huggingface": {"": 0.0},
    "cloudflare": {"": 0.0},
    "pollinations": {"": 0.0},
    "local": {"": 0.0},
}

#: 音声合成の1000文字あたりの概算単価（USD）。**画像とは単位が違う**ので表を分けてある。
#: 2026年8月時点で調べた範囲の値で、公式の価格表とは別物。
DEFAULT_SPEECH_COSTS: dict[str, dict[str, float]] = {
    "openai_tts": {"": 0.015},
    "elevenlabs": {"": 0.20},
    "voicevox": {"": 0.0},
    "beep": {"": 0.0},
}

#: costs.json の中で音声の単価を書くキー（画像のプロバイダ名と衝突させないため）
SPEECH_KEY = "speech"


def record_prompts() -> bool:
    """プロンプトを記録するか（IMAGEGEN_USAGE_PROMPTS=0 で止める）。"""
    return (get_env("IMAGEGEN_USAGE_PROMPTS") or "1").strip().lower() not in ("0", "false", "no")


def log_path() -> Path:
    return Path(output_dir()) / LOG_NAME


def cost_table() -> dict[str, dict[str, float]]:
    """単価表。output/costs.json があればそちらで上書きする。"""
    override = Path(output_dir()) / COSTS_NAME
    table = {provider: dict(models) for provider, models in DEFAULT_COSTS.items()}
    if override.is_file():
        try:
            custom = json.loads(override.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return table
        for provider, models in (custom or {}).items():
            if provider != SPEECH_KEY and isinstance(models, dict):
                table.setdefault(provider, {}).update(
                    {str(k): float(v) for k, v in models.items()}
                )
    return table


def speech_cost_table() -> dict[str, dict[str, float]]:
    """音声合成の単価表。output/costs.json の "speech" があればそちらで上書きする。"""
    override = Path(output_dir()) / COSTS_NAME
    table = {provider: dict(models) for provider, models in DEFAULT_SPEECH_COSTS.items()}
    if override.is_file():
        try:
            custom = json.loads(override.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return table
        for provider, models in ((custom or {}).get(SPEECH_KEY) or {}).items():
            if isinstance(models, dict):
                table.setdefault(provider, {}).update({str(k): float(v) for k, v in models.items()})
    return table


def unit_cost(provider: str, model: str, table: dict | None = None) -> float:
    """1枚あたりの概算単価。分からなければ 0。"""
    models = (table or cost_table()).get(provider)
    if not models:
        return 0.0
    matches = [price for name, price in models.items() if name and model.startswith(name)]
    if matches:
        return max(matches)
    return float(models.get("", 0.0))


def record(images, *, path: Path | None = None) -> None:
    """生成結果を1行追記する。記録の失敗で生成を無駄にしないこと。"""
    if not images:
        return
    first = images[0]
    entry = {
        "ts": datetime.now().isoformat(timespec="seconds"),
        "provider": first.provider,
        "model": first.model,
        "images": len(images),
        "bytes": sum(len(image.data) for image in images),
        # プロンプトには社外に出したくない語が混ざりうるので、切れるようにしておく
        "prompt": (first.prompt or "")[:120] if record_prompts() else "",
        "cost_usd": round(unit_cost(first.provider, first.model) * len(images), 4),
        "kind": "image",
    }
    _append(entry, path)


def record_speech(clips, *, path: Path | None = None) -> None:
    """合成結果を1行追記する。記録の失敗で合成を無駄にしないこと。

    課金は**つなぐ前の文字数**で決まるので、分割した各回をまとめて1行にする。
    """
    if not clips:
        return
    first = clips[0]
    chars = sum(clip.chars for clip in clips)
    entry = {
        "ts": datetime.now().isoformat(timespec="seconds"),
        "kind": "speech",
        "provider": first.provider,
        "model": first.model,
        "voice": first.voice,
        "clips": len(clips),
        "chars": chars,
        "bytes": sum(len(clip.data) for clip in clips),
        # 読み上げ文にも社外に出したくない語が混ざりうるので、切れるようにしておく
        "text": (first.text or "")[:120] if record_prompts() else "",
        "cost_usd": round(unit_cost(first.provider, first.model, speech_cost_table()) * chars / 1000, 4),
    }
    _append(entry, path)


def _append(entry: dict, path: Path | None = None) -> None:
    """記録を1行追記する。**記録できなくても本体の処理は成功させる**。"""
    target = path or log_path()
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except OSError:  # 記録できなくても生成そのものは成功させる
        pass


def load(path: Path | None = None) -> list[dict]:
    """記録を読み込む（壊れた行は飛ばす）。"""
    target = path or log_path()
    if not target.is_file():
        return []
    entries = []
    for line in target.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if isinstance(entry, dict):
            entries.append(entry)
    return entries


def summarize(days: int | None = None, path: Path | None = None) -> dict:
    """プロバイダ・モデルごとに集計する。"""
    entries = load(path)
    if days:
        since = (datetime.now() - timedelta(days=days)).isoformat(timespec="seconds")
        entries = [entry for entry in entries if str(entry.get("ts", "")) >= since]

    rows: dict[tuple[str, str, str], dict] = defaultdict(
        lambda: {"calls": 0, "images": 0, "clips": 0, "chars": 0, "cost_usd": 0.0}
    )
    for entry in entries:
        # kind が無い行は音声を足す前の記録なので画像として数える
        kind = str(entry.get("kind") or "image")
        key = (str(entry.get("provider", "")), str(entry.get("model", "")), kind)
        row = rows[key]
        row["calls"] += 1
        row["images"] += int(entry.get("images", 0) or 0)
        row["clips"] += int(entry.get("clips", 0) or 0)
        row["chars"] += int(entry.get("chars", 0) or 0)
        row["cost_usd"] += float(entry.get("cost_usd", 0) or 0)

    breakdown = [
        {
            "provider": provider,
            "model": model,
            "kind": kind,
            **values,
            "cost_usd": round(values["cost_usd"], 4),
        }
        for (provider, model, kind), values in sorted(
            rows.items(), key=lambda item: -item[1]["cost_usd"]
        )
    ]
    return {
        "entries": len(entries),
        "images": sum(row["images"] for row in breakdown),
        "clips": sum(row["clips"] for row in breakdown),
        "chars": sum(row["chars"] for row in breakdown),
        "cost_usd": round(sum(row["cost_usd"] for row in breakdown), 4),
        "breakdown": breakdown,
        "since_days": days,
    }
