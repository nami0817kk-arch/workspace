"""画像生成の利用量と概算コストを記録する。

有料APIは「気づいたら使いすぎていた」が起きやすいので、生成のたびに1行ずつ
残しておき、`ailab usage` で集計できるようにする。

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


def record_prompts() -> bool:
    """プロンプトを記録するか（AILAB_USAGE_PROMPTS=0 で止める）。"""
    return (get_env("AILAB_USAGE_PROMPTS") or "1").strip().lower() not in ("0", "false", "no")


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
            if isinstance(models, dict):
                table.setdefault(provider, {}).update(
                    {str(k): float(v) for k, v in models.items()}
                )
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
    }
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

    rows: dict[tuple[str, str], dict] = defaultdict(
        lambda: {"calls": 0, "images": 0, "cost_usd": 0.0}
    )
    for entry in entries:
        key = (str(entry.get("provider", "")), str(entry.get("model", "")))
        row = rows[key]
        row["calls"] += 1
        row["images"] += int(entry.get("images", 0) or 0)
        row["cost_usd"] += float(entry.get("cost_usd", 0) or 0)

    breakdown = [
        {"provider": provider, "model": model, **values, "cost_usd": round(values["cost_usd"], 4)}
        for (provider, model), values in sorted(
            rows.items(), key=lambda item: -item[1]["cost_usd"]
        )
    ]
    return {
        "entries": len(entries),
        "images": sum(row["images"] for row in breakdown),
        "cost_usd": round(sum(row["cost_usd"] for row in breakdown), 4),
        "breakdown": breakdown,
        "since_days": days,
    }
