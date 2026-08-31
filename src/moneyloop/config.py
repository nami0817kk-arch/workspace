"""設定ファイル(JSON)の読み込みとバリデーション。"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path

from .models import Niche, Source
from .pricing import Plan

DEFAULT_CONFIG_PATH = Path("config/moneyloop.json")
EXAMPLE_CONFIG_PATH = Path("config/moneyloop.example.json")


@dataclass(frozen=True)
class LLMConfig:
    model: str = "claude-opus-5"
    scoring_model: str = "claude-opus-5"
    effort: str = "high"
    max_tokens: int = 16000
    enable_fallbacks: bool = True


@dataclass(frozen=True)
class CurationConfig:
    lookback_hours: int = 48
    max_items_per_source: int = 20
    score_batch_size: int = 20
    min_score: int = 60
    items_per_issue: int = 6


@dataclass(frozen=True)
class DeliveryConfig:
    file: bool = True
    webhook_url_env: str = "MONEYLOOP_WEBHOOK_URL"

    @property
    def webhook_url(self) -> str:
        return os.environ.get(self.webhook_url_env, "").strip()


@dataclass(frozen=True)
class Config:
    db_path: Path = Path("output/moneyloop.db")
    output_dir: Path = Path("output/issues")
    usd_jpy: float = 150.0
    llm: LLMConfig = field(default_factory=LLMConfig)
    curation: CurationConfig = field(default_factory=CurationConfig)
    delivery: DeliveryConfig = field(default_factory=DeliveryConfig)
    plans: tuple[Plan, ...] = ()
    niches: tuple[Niche, ...] = ()

    def niche(self, code: str) -> Niche:
        for n in self.niches:
            if n.code == code:
                return n
        raise KeyError(f"未定義のニッチです: {code}")

    def plan(self, code: str) -> Plan:
        for p in self.plans:
            if p.code == code:
                return p
        raise KeyError(f"未定義のプランです: {code}")


def _subset(cls, raw: dict, defaults):
    """未知キーを無視しつつ dataclass を組み立てる（設定の前方互換のため）。"""
    known = {f for f in defaults.__dataclass_fields__}
    return cls(**{k: v for k, v in raw.items() if k in known})


def load_config(path: str | Path | None = None) -> Config:
    """JSON設定を読み込む。パス省略時は config/moneyloop.json → .example の順で探す。"""
    if path is None:
        path = DEFAULT_CONFIG_PATH if DEFAULT_CONFIG_PATH.exists() else EXAMPLE_CONFIG_PATH
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"設定ファイルが見つかりません: {path}")
    raw = json.loads(path.read_text(encoding="utf-8"))
    return parse_config(raw)


def parse_config(raw: dict) -> Config:
    plans = tuple(
        Plan(
            code=p["code"],
            name=p.get("name", p["code"]),
            monthly_usd=float(p.get("monthly_usd", 0.0)),
            paywalled=bool(p.get("paywalled", False)),
        )
        for p in raw.get("plans", [])
    )
    if not plans:
        plans = (Plan("free", "Free", 0.0, False),)

    niches = tuple(
        Niche(
            code=n["code"],
            name=n.get("name", n["code"]),
            audience=n.get("audience", ""),
            angle=n.get("angle", ""),
            sources=tuple(Source(name=s.get("name", s["url"]), url=s["url"]) for s in n.get("sources", [])),
        )
        for n in raw.get("niches", [])
    )
    if not niches:
        raise ValueError("設定に niches が1つも定義されていません")

    return Config(
        db_path=Path(raw.get("db_path", "output/moneyloop.db")),
        output_dir=Path(raw.get("output_dir", "output/issues")),
        usd_jpy=float(raw.get("usd_jpy", 150.0)),
        llm=_subset(LLMConfig, raw.get("llm", {}), LLMConfig()),
        curation=_subset(CurationConfig, raw.get("curation", {}), CurationConfig()),
        delivery=_subset(DeliveryConfig, raw.get("delivery", {}), DeliveryConfig()),
        plans=plans,
        niches=niches,
    )
