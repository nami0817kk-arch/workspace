import pytest

from moneyloop.config import parse_config
from moneyloop.storage import Storage

RSS = """<?xml version="1.0"?>
<rss version="2.0"><channel>
  <item><title>自動化で経理を月40時間削減</title><link>https://ex.test/a</link>
        <description>&lt;p&gt;事例の詳細&lt;/p&gt;</description></item>
  <item><title>APIの料金改定</title><link>https://ex.test/b</link>
        <description>値下げの詳細</description></item>
  <item><title>新しいエージェント基盤</title><link>https://ex.test/c</link>
        <description>発表内容</description></item>
</channel></rss>
"""

CONFIG_RAW = {
    "db_path": ":memory:",
    "output_dir": "output/test-issues",
    "usd_jpy": 150.0,
    "llm": {"model": "claude-opus-5", "scoring_model": "claude-opus-5", "max_tokens": 4000},
    "curation": {"lookback_hours": 48, "min_score": 60, "items_per_issue": 3, "score_batch_size": 10},
    "delivery": {"file": False, "webhook_url_env": "MONEYLOOP_TEST_WEBHOOK_UNSET"},
    "plans": [
        {"code": "free", "name": "Free", "monthly_usd": 0.0, "paywalled": False},
        {"code": "pro", "name": "Pro", "monthly_usd": 30.0, "paywalled": True},
    ],
    "niches": [
        {
            "code": "ai-ops",
            "name": "AI運用ウィークリー",
            "audience": "AI導入責任者",
            "angle": "実務で効く自動化",
            "sources": [{"name": "Example", "url": "https://ex.test/feed"}],
        }
    ],
}


@pytest.fixture
def config():
    return parse_config(CONFIG_RAW)


@pytest.fixture
def storage():
    with Storage(":memory:") as s:
        yield s


@pytest.fixture
def fetcher():
    def _fetch(url, timeout=20.0):
        return RSS

    return _fetch
