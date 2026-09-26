"""公開先の設定。**ドメインを変えるときに触るのはこのファイルだけ**。

canonical・sitemap・OGP が、すべてここを見ている。1箇所に集めてあるのは、
他のサイトと同じ理由（`projects/kabu-agari-ranking/src/site_config.py`）。
"""
import os

# 末尾のスラッシュは付けない（URL の組み立て側で付ける）。
SITE_URL = os.environ.get("TABI_SITE_URL", "https://tabi.dailyquarry.com").rstrip("/")

# Search Console の所有確認タグ。同じ Google アカウントならドメインが変わっても
# 同じ値（docs/public-identity.md で確認済み）。
SEARCH_CONSOLE_TOKEN = os.environ.get(
    "TABI_SEARCH_CONSOLE_TOKEN", "JLPv6DMxv7h91q8Hzvo-YfdQx6mz-_zZ-MhHaNzPs4c"
)

# 公開名義と連絡先。**個人名は出さない**（屋号で通す）。
OWNER = os.environ.get("TABI_OWNER", "つるはし社")

# Cloudflare の Email Routing（無料）で受けて、個人のメールへ転送する。
# 転送先はここに書かない（workspace は public リポジトリ）。
CONTACT_EMAIL = os.environ.get("TABI_CONTACT_EMAIL", "info@dailyquarry.com")
