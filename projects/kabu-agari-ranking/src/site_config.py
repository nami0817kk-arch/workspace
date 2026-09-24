"""公開先の設定。**ドメインを変えるときに触るのはこのファイルだけ**。

canonical・sitemap・RSS・OGP・X への投稿文が、すべてここを見ている。
1箇所に集めてあるのは、独自ドメインへ移すときに直し漏れると
「canonical は旧ドメイン、sitemap は新ドメイン」のような
検索エンジンに矛盾した指示を出す状態になるため。

独自ドメインへ移す手順は README の「独自ドメインへ移す」を見る。
"""
import os

# 末尾のスラッシュは付けない（URL の組み立て側で付ける）。
# 環境変数があればそちらを優先する（本番と手元で別ドメインを見たいときのため）。
SITE_URL = os.environ.get("KABU_SITE_URL", "https://kabu-agari-ranking.pages.dev").rstrip("/")

# Search Console の所有確認タグ。**ドメインごとに値が変わる**。
# 新しいドメインを Search Console に登録したら、ここを差し替えるか、
# DNS(TXT) で確認する（DNS のほうがコードを触らずに済む）。
SEARCH_CONSOLE_TOKEN = os.environ.get(
    "KABU_SEARCH_CONSOLE_TOKEN", "0hcqlTHZBjIT-I9RKazTzGUVa2pZKmFREjTWbpvXRlk"
)
