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
SITE_URL = os.environ.get("KABU_SITE_URL", "https://kabu.dailyquarry.com").rstrip("/")

# Search Console の所有確認タグ。**同じ Google アカウントなら、ドメインが
# 変わっても同じ値**（2026-09-25 に kakaku.dailyquarry.com と比べて確認）。
# 新しいドメインを登録するとき、この値が既に入っていればそのまま通る。
# 画面に別の値が出たら差し替えるか、DNS(TXT) で確認する
# （DNS のほうがコードを触らずに済む）。
SEARCH_CONSOLE_TOKEN = os.environ.get(
    "KABU_SEARCH_CONSOLE_TOKEN", "JLPv6DMxv7h91q8Hzvo-YfdQx6mz-_zZ-MhHaNzPs4c"
)

# AdSense。**審査を通すまでは両方とも空のまま。**
#   ADSENSE_CLIENT … "ca-pub-..."。入れると head にスクリプトが出る（自動広告が動く）。
#     審査を申し込むときは、これだけ入っていればよい。
#   ADSENSE_SLOT   … 手で置く枠の ID。自動広告に任せるなら空のままでよい。
# 空のあいだは広告のスクリプトも枠も一切描かない。
ADSENSE_CLIENT = os.environ.get("KABU_ADSENSE_CLIENT", "ca-pub-6409014819339195")
ADSENSE_SLOT = os.environ.get("KABU_ADSENSE_SLOT", "")

# 同じ運営者が出している他のサイト。フッタから相互に行き来できるようにする。
#
# 入口（dailyquarry.com）からは3サイトへリンクされているのに、こちらから
# 戻る線が無かった。読み手が他のものを見つけられないうえ、検索側から見ても
# 一群のサイトとして繋がっていない状態だった。
SIBLING_SITES = [
    {"url": "https://dailyquarry.com/", "name": "つるはし社", "note": "運営しているサイトの一覧"},
    {"url": "https://kakaku.dailyquarry.com/", "name": "楽天 値下がりウォッチ", "note": "毎日の値下がりと最安値圏"},
    {"url": "https://shaho.dailyquarry.com/", "name": "社会保険 加入判定チェッカー", "note": "106万円の壁の判定"},
]

# 公開名義と連絡先。**個人名は出さない**（屋号で通す）。
# AdSense の審査は「誰が運営し、どこへ連絡できるか」が分かることを求めるので、
# この2つが空のまま審査に出さない。
OWNER = os.environ.get("KABU_OWNER", "つるはし社")

# Cloudflare の Email Routing（無料）で受けて、個人のメールへ転送する。
# 転送先はここに書かない（公開リポジトリなので、転送元だけを置く）。
CONTACT_EMAIL = os.environ.get("KABU_CONTACT_EMAIL", "info@dailyquarry.com")
