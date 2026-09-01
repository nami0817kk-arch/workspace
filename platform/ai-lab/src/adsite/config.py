"""サイト設定。広告IDやドメインはコードに埋めず、ここから注入する。"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_CONFIG_PATH = Path("config/site.json")
EXAMPLE_CONFIG_PATH = Path("config/site.example.json")


@dataclass(frozen=True)
class AdsConfig:
    """AdSenseの設定。

    client が空のときは広告タグを一切出力しない（審査前・ローカル確認用）。
    """

    client: str = ""
    slot_top: str = ""
    slot_inline: str = ""
    slot_bottom: str = ""
    max_units_per_page: int = 3
    min_words_for_ads: int = 400
    reserved_height_px: int = 280
    consent_required: bool = False
    consent_cmp_script: str = ""

    @property
    def enabled(self) -> bool:
        return bool(self.client)


@dataclass(frozen=True)
class SiteConfig:
    base_url: str = "https://example.com"
    site_name: str = "AI Tools"
    tagline: str = ""
    theme: str = ""
    locale: str = "ja"
    author: str = ""
    contact_url: str = ""
    content_dir: Path = Path("site/content")
    assets_dir: Path = Path("site/assets")
    output_dir: Path = Path("output/site")
    db_path: Path = Path("output/adsite.db")
    usd_jpy: float = 150.0
    analytics_snippet: str = ""
    ads: AdsConfig = field(default_factory=AdsConfig)

    @property
    def origin(self) -> str:
        return self.base_url.rstrip("/")

    def url(self, path: str) -> str:
        return self.origin + (path if path.startswith("/") else "/" + path)


def parse_site_config(raw: dict) -> SiteConfig:
    ads_raw = raw.get("ads", {})
    known_ads = set(AdsConfig.__dataclass_fields__)
    ads = AdsConfig(**{k: v for k, v in ads_raw.items() if k in known_ads})
    known = set(SiteConfig.__dataclass_fields__) - {"ads"}
    kwargs = {k: v for k, v in raw.items() if k in known}
    for key in ("content_dir", "assets_dir", "output_dir", "db_path"):
        if key in kwargs:
            kwargs[key] = Path(kwargs[key])
    return SiteConfig(ads=ads, **kwargs)


def load_site_config(path: str | Path | None = None) -> SiteConfig:
    if path is None:
        path = DEFAULT_CONFIG_PATH if DEFAULT_CONFIG_PATH.exists() else EXAMPLE_CONFIG_PATH
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"サイト設定が見つかりません: {path}")
    return parse_site_config(json.loads(path.read_text(encoding="utf-8")))
