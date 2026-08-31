import pytest

from adsite.config import parse_site_config
from adsite.storage import Storage

CONFIG_RAW = {
    "base_url": "https://t.example",
    "site_name": "テストサイト",
    "theme": "AI導入の計算ツール",
    "db_path": ":memory:",
    "usd_jpy": 150.0,
    "ads": {},
}


@pytest.fixture
def site():
    return parse_site_config(CONFIG_RAW)


@pytest.fixture
def storage():
    with Storage(":memory:") as s:
        yield s
