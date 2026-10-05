"""data/ の国別データから Jinja2 テンプレートで output/ に静的HTMLを生成する。

入力は2つだけ:
- data/mofa.json … 外務省の一覧（32か国・地域、開始年、年間発給枠）。全国共通の土台
- data/countries/<id>.json … 各国の公式サイトで確かめた条件（年齢・期間・費用・資金・申請方法など）。
  無い国・確かめられなかった項目は「公式サイトで確認」と出し、推測で埋めない

shaho-tekiyo の src/render.py と同じ形（canonical・sitemap・robots の作り方はそちらに合わせてある）。
"""
from __future__ import annotations

import json
import shutil
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import quote_plus
from zoneinfo import ZoneInfo

from jinja2 import Environment, FileSystemLoader

sys.path.insert(0, str(Path(__file__).resolve().parent))

import site_config  # noqa: E402

_ROOT = Path(__file__).resolve().parent.parent
_DATA = _ROOT / "data"
_TEMPLATES_DIR = _ROOT / "templates"
_STATIC_DIR = _ROOT / "static"
_OUTPUT_DIR = _ROOT / "output"

SITE_URL = site_config.SITE_URL

# プライバシーポリシーの文面を最後に直した日。**文面を変えたらここも変える。**
POLICY_UPDATED = "2026年10月5日"

# 国のページに並べる項目。順番がそのまま表の行の順番になる。
FIELDS: list[tuple[str, str]] = [
    ("age", "年齢"),
    ("stay", "滞在できる期間"),
    ("fee", "申請費用"),
    ("funds", "必要な資金"),
    ("apply", "申請先・方法"),
    ("timing", "申請の時期・方式"),
    ("work", "働くときの制限"),
    ("study", "学校に通うときの制限"),
    ("insurance", "保険"),
]

# 一覧の表に出す項目（狭い画面でも読めるよう絞る）。
TABLE_FIELDS = ["age", "stay", "fee", "funds", "timing"]

REGIONS = ["オセアニア", "北米", "アジア", "ヨーロッパ", "中南米"]

# 持ち物のページ。Amazon のリンクは AMAZON_TAG があるときだけ出す。
# 国ごとに違う物（変換プラグの形など）は、ここでは決め打ちしない。
PACKING: list[dict] = [
    {"group": "書類・お金", "items": [
        {"name": "パスポート（残りの有効期間を確認）", "q": ""},
        {"name": "ビザの許可の控え（印刷と端末の両方）", "q": ""},
        {"name": "海外で使えるクレジットカード・デビットカード（2枚以上）", "q": ""},
        {"name": "資金の証明に使う残高証明（英文）", "q": ""},
    ]},
    {"group": "電気まわり", "items": [
        {"name": "変換プラグ（渡航先のコンセントの形に合わせる）", "q": "変換プラグ 海外"},
        {"name": "モバイルバッテリー（機内持ち込みの容量の決まりに注意）", "q": "モバイルバッテリー"},
        {"name": "USB 充電器（複数口）", "q": "USB 充電器 複数ポート 海外対応"},
    ]},
    {"group": "荷物", "items": [
        {"name": "大きめのスーツケース（1年分の荷物）", "q": "スーツケース 大型"},
        {"name": "圧縮袋", "q": "衣類 圧縮袋 旅行"},
        {"name": "スーツケースベルト・TSA ロック", "q": "TSAロック"},
        {"name": "折りたためるサブバッグ", "q": "折りたたみ バッグ 旅行"},
    ]},
    {"group": "仕事探し・暮らし", "items": [
        {"name": "英文の履歴書（現地で印刷できるようデータでも）", "q": ""},
        {"name": "常備薬（成分の英語名を控える）", "q": ""},
        {"name": "日本の調味料・だしなど（持ち込みの決まりは国ごとに確認）", "q": ""},
        {"name": "旅行用の英会話・語学の本", "q": "ワーホリ 英会話 本"},
    ]},
]


def jst_today() -> str:
    d = datetime.now(ZoneInfo("Asia/Tokyo")).date()
    return f"{d.year}年{d.month}月{d.day}日"


def amazon_url(query: str) -> str:
    """Amazon の検索結果へのリンク（アソシエイトのタグ付き）。タグが空なら空文字。"""
    if not site_config.AMAZON_TAG or not query:
        return ""
    return f"https://www.amazon.co.jp/s?k={quote_plus(query)}&tag={site_config.AMAZON_TAG}"


def load_data() -> tuple[dict, list[dict]]:
    """外務省の一覧に、各国のデータを重ねる。各国のデータが無い国は外務省の分だけになる。"""
    mofa = json.loads((_DATA / "mofa.json").read_text(encoding="utf-8"))
    countries = []
    for c in mofa["countries"]:
        detail_path = _DATA / "countries" / f"{c['id']}.json"
        detail = json.loads(detail_path.read_text(encoding="utf-8")) if detail_path.exists() else {}
        merged = {**c}
        for key, _ in FIELDS:
            merged[key] = (detail.get(key) or "").strip()
        merged["points"] = [p for p in detail.get("points", []) if p.strip()]
        merged["sources"] = [s for s in detail.get("sources", []) if s.get("url", "").startswith("http")]
        merged["unverified"] = detail.get("unverified", [])
        merged["checked"] = max((s.get("checked", "") for s in merged["sources"]), default="")
        merged["twice"] = c["name"] in ("カナダ", "スロバキア", "韓国", "台湾")
        countries.append(merged)
    return mofa, countries


def canonical_url(rel_path: str) -> str:
    """output/ 内の相対パスから、実際に配信される URL を組み立てる。

    Cloudflare Pages は `/foo.html` を `/foo` へ、`/dir/index.html` を `/dir/` へ
    308 で飛ばす（kabu-agari-ranking で確認済みの挙動）。sitemap・canonical はそちらに揃える。
    """
    rel = rel_path.removeprefix("/")
    if rel == "index.html":
        return f"{SITE_URL}/"
    if rel.endswith("/index.html"):
        return f"{SITE_URL}/{rel[: -len('index.html')]}"
    return f"{SITE_URL}/{rel.removesuffix('.html')}"


def _env() -> Environment:
    env = Environment(loader=FileSystemLoader(str(_TEMPLATES_DIR)), autoescape=True)
    env.globals.update(
        SITE_URL=SITE_URL,
        SITE_NAME=site_config.SITE_NAME,
        SEARCH_CONSOLE_TOKEN=site_config.SEARCH_CONSOLE_TOKEN,
        OWNER=site_config.OWNER,
        CONTACT_EMAIL=site_config.CONTACT_EMAIL,
        CONTACT_TEXT=site_config.CONTACT_EMAIL.replace("@", " [at] "),
        ADSENSE_CLIENT=site_config.ADSENSE_CLIENT,
        AMAZON_ON=bool(site_config.AMAZON_TAG),
        FIELDS=FIELDS,
        TABLE_FIELDS=TABLE_FIELDS,
        POLICY_UPDATED=POLICY_UPDATED,
        amazon_url=amazon_url,
    )
    return env


def build(out: Path = _OUTPUT_DIR) -> list[str]:
    """サイトを作り、作ったページの相対パスを返す。"""
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    env = _env()
    mofa, countries = load_data()
    updated = jst_today()
    by_region = [(r, [c for c in countries if c["region"] == r]) for r in REGIONS]
    pages: list[str] = []

    def write(rel: str, template: str, **ctx) -> None:
        depth = rel.count("/")
        html = env.get_template(template).render(
            base_url="../" * depth, canonical=canonical_url(rel), updated=updated, mofa=mofa, **ctx
        )
        path = out / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(html, encoding="utf-8")
        pages.append(rel)

    write("index.html", "index.html", countries=countries, by_region=by_region)
    for i, c in enumerate(countries):
        same_region = [o for o in countries if o["region"] == c["region"] and o["id"] != c["id"]]
        write(f"country/{c['id']}.html", "country.html", c=c, same_region=same_region)
    write("country/index.html", "country_index.html", by_region=by_region)
    write("junbi.html", "junbi.html", countries=countries)
    write("mochimono.html", "mochimono.html", packing=PACKING)
    for name in ("about", "operator", "privacy", "contact"):
        write(f"{name}.html", f"{name}.html")
    write("404.html", "404.html")

    if _STATIC_DIR.exists():
        shutil.copytree(_STATIC_DIR, out / "static")
    (out / f"{site_config.INDEXNOW_KEY}.txt").write_text(site_config.INDEXNOW_KEY, encoding="utf-8")
    (out / "robots.txt").write_text(
        f"User-agent: *\nAllow: /\n\nSitemap: {SITE_URL}/sitemap.xml\n", encoding="utf-8"
    )
    urls = "".join(
        f"  <url><loc>{canonical_url(p)}</loc></url>\n" for p in pages if p != "404.html"
    )
    (out / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + urls + "</urlset>\n",
        encoding="utf-8",
    )
    return pages


if __name__ == "__main__":
    built = build()
    print(f"{len(built)} ページを output/ に作った")
