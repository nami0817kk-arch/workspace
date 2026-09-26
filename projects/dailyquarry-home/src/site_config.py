"""dailyquarry.com（ルート）の設定。**AdSense の pub-ID を入れるのはここ**。

AdSense はサイトを**ルートドメイン単位**で扱う（サブドメインはサイトとして足せない）。
審査を申し込むサイトは `dailyquarry.com` で、`ads.txt` もルートに置く必要がある。
このPJTはそのためのもの。各サブドメインのサイトは、それぞれの site_config に
同じ pub-ID を入れる（ads.txt はルートの1枚で足りる。販売者が同じなら subdomain= は要らない）。
"""
import os

SITE_URL = os.environ.get("DQ_SITE_URL", "https://dailyquarry.com").rstrip("/")

# Search Console の所有確認タグ。Google アカウント単位で同じ値（docs/public-identity.md）。
SEARCH_CONSOLE_TOKEN = os.environ.get(
    "DQ_SEARCH_CONSOLE_TOKEN", "JLPv6DMxv7h91q8Hzvo-YfdQx6mz-_zZ-MhHaNzPs4c"
)

# "ca-pub-..."。**空のあいだは広告スクリプトも ads.txt も出さない。**
# 入れると head にスクリプト（所有確認を兼ねる）と、ルートの ads.txt が出る。
ADSENSE_CLIENT = os.environ.get("DQ_ADSENSE_CLIENT", "ca-pub-6409014819339195")

# 公開名義と連絡先。個人名は出さない。転送先はここに書かない（リポジトリは public）。
OWNER = "つるはし社"
CONTACT_EMAIL = "info@dailyquarry.com"

POLICY_UPDATED = "2026年9月26日"

# 入口に並べるサイト。**公開済みで、独自ドメインで開けるものだけ**を載せる
# （開けないリンクがあると審査で「サイトが使用できない」側に倒れうる）。
#   ads … そのサイトに AdSense を載せるか。price-tracker は楽天ウェブサービス規約
#         第10条1項(4) で AdSense を載せられない（docs/public-identity.md）。
SITES = [
    {
        "name": "値上がり株ランキング",
        "url": "https://kabu.dailyquarry.com/",
        "summary": "東証全市場の値上がり率・値下がり率・売買の活発さを、営業日ごとに自動で集計して残しています。",
        "ads": True,
    },
    {
        "name": "社会保険 加入判定チェッカー",
        "url": "https://shaho.dailyquarry.com/",
        "summary": "週の労働時間・月収・勤務先の従業員数から、パート・アルバイトが社会保険の加入対象になるかと保険料の目安を出します。",
        "ads": True,
    },
    {
        "name": "楽天 値下がりウォッチ",
        "url": "https://kakaku.dailyquarry.com/",
        "summary": "楽天市場の商品の価格を毎日記録し、最安値への近さやポイント込みの下げ幅を並べています。",
        "ads": False,
    },
]
