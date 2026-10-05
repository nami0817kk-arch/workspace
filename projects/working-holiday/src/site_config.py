"""公開先の設定。**ドメインを変えるときに触るのはこのファイルだけ**。

canonical・sitemap・OGP が、すべてここを見ている（shaho-tekiyo と同じ形）。
"""
import os

# 末尾のスラッシュは付けない（URL の組み立て側で付ける）。
SITE_URL = os.environ.get("WH_SITE_URL", "https://wh.dailyquarry.com").rstrip("/")

SITE_NAME = "ワーホリ条件くらべ"

# Search Console の所有確認タグ。同じ Google アカウントならドメインが変わっても
# 同じ値（docs/public-identity.md で確認済み）。
SEARCH_CONSOLE_TOKEN = os.environ.get(
    "WH_SEARCH_CONSOLE_TOKEN", "JLPv6DMxv7h91q8Hzvo-YfdQx6mz-_zZ-MhHaNzPs4c"
)

# 公開名義と連絡先。**個人名は出さない**（屋号で通す。docs/public-identity.md）。
OWNER = os.environ.get("WH_OWNER", "つるはし社")

# Cloudflare の Email Routing（無料）で受けて、個人のメールへ転送する。
# 転送先はここに書かない（workspace は public リポジトリ）。
CONTACT_EMAIL = os.environ.get("WH_CONTACT_EMAIL", "info@dailyquarry.com")

# Amazon アソシエイトのトラッキングID（例: xxxx-22）。**空のあいだは Amazon へのリンクを一切出さない**。
# 審査前に作り物のIDを置かない（AdSense の ca-pub と同じ扱い）。
AMAZON_TAG = os.environ.get("WH_AMAZON_TAG", "")

# AdSense の審査を通ったら ca-pub-... を入れる。空のあいだは広告のスクリプトも枠も出さない。
ADSENSE_CLIENT = ""

# IndexNow のキー。秘密ではない（サイトの直下に {キー}.txt として公開する決まり）。変えない。
INDEXNOW_KEY = "3c8f1e6a9b2d47f0a5e1c7b9d4f62a18"
