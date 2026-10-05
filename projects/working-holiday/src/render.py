"""data/ の国別データから Jinja2 テンプレートで output/ に静的HTMLを生成する。

入力は2つだけ:
- data/mofa.json … 外務省の一覧（32か国・地域、開始年、年間発給枠）。全国共通の土台
- data/countries/<id>.json … 各国の公式サイトで確かめた条件（年齢・期間・費用・資金・申請方法など）。
  無い国・確かめられなかった項目は「公式サイトで確認」と出し、推測で埋めない

shaho-tekiyo の src/render.py と同じ形（canonical・sitemap・robots の作り方はそちらに合わせてある）。
"""
from __future__ import annotations

import json
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import quote_plus
from zoneinfo import ZoneInfo

from jinja2 import Environment, FileSystemLoader

sys.path.insert(0, str(Path(__file__).resolve().parent))

import geo  # noqa: E402
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
    {"group": "書類・お金", "icon": "passport", "items": [
        {"name": "パスポート（残りの有効期間を確認）", "q": ""},
        {"name": "ビザの許可の控え（印刷と端末の両方）", "q": ""},
        {"name": "海外で使えるクレジットカード・デビットカード（2枚以上）", "q": ""},
        {"name": "資金の証明に使う残高証明（英文）", "q": ""},
    ]},
    {"group": "電気まわり", "icon": "phone", "items": [
        {"name": "変換プラグ（渡航先のコンセントの形に合わせる）", "q": "変換プラグ 海外"},
        {"name": "モバイルバッテリー（機内持ち込みの容量の決まりに注意）", "q": "モバイルバッテリー"},
        {"name": "USB 充電器（複数口）", "q": "USB 充電器 複数ポート 海外対応"},
    ]},
    {"group": "荷物", "icon": "suitcase", "items": [
        {"name": "大きめのスーツケース（1年分の荷物）", "q": "スーツケース 大型"},
        {"name": "圧縮袋", "q": "衣類 圧縮袋 旅行"},
        {"name": "スーツケースベルト・TSA ロック", "q": "TSAロック"},
        {"name": "折りたためるサブバッグ", "q": "折りたたみ バッグ 旅行"},
    ]},
    {"group": "仕事探し・暮らし", "icon": "briefcase", "items": [
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


# 現地の手続きの見出しから、添えるアイコンを決める（上から順に最初に当たったもの）。
_STEP_ICONS = [
    ("在留届", "pin"), ("税", "id"), ("番号", "id"), ("TFN", "id"), ("SIN", "id"), ("IRD", "id"),
    ("銀行", "bank"), ("口座", "bank"), ("住民", "home"), ("登録", "home"), ("住所", "home"),
    ("保険", "shield"), ("医療", "hospital"), ("許可", "passport"), ("ビザ", "passport"), ("電話", "phone"),
]


def step_icon(title: str) -> str:
    return next((name for word, name in _STEP_ICONS if word in title), "form")


def _hours(delta) -> float:
    return delta.total_seconds() / 3600


def time_difference(tz: str, year: int) -> dict:
    """日本との時差（時間）。1月と7月の正午で比べ、夏時間がある国は両方を返す。"""
    from datetime import datetime as _dt
    jp = ZoneInfo("Asia/Tokyo")
    out = {}
    for key, month in (("winter", 1), ("summer", 7)):
        t = _dt(year, month, 15, 12, tzinfo=ZoneInfo(tz))
        out[key] = _hours(t.utcoffset()) - _hours(t.astimezone(jp).utcoffset())
    return out


def fmt_diff(h: float) -> str:
    """-8.0 → 「日本より8時間遅い」。0 → 「日本と同じ」。"""
    if h == 0:
        return "日本と同じ"
    n = abs(h)
    text = f"{int(n)}時間" if n == int(n) else f"{int(n)}時間{int((n - int(n)) * 60)}分"
    return f"日本より{text}{'進んでいる' if h > 0 else '遅い'}"


def load_data() -> tuple[dict, list[dict]]:
    """外務省の一覧に、各国のデータを重ねる。各国のデータが無い国は外務省の分だけになる。"""
    mofa = json.loads((_DATA / "mofa.json").read_text(encoding="utf-8"))
    links_path = _DATA / "links.json"
    links = json.loads(links_path.read_text(encoding="utf-8"))["countries"] if links_path.exists() else {}
    basics = json.loads((_DATA / "basics.json").read_text(encoding="utf-8"))["countries"]
    year = datetime.now(ZoneInfo("Asia/Tokyo")).year
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
        merged["filled"] = any(merged[k] for k, _ in FIELDS)
        merged["quota_n"] = int(c["quota"].replace(",", "")) if c["quota"].replace(",", "").isdigit() else 0
        merged["flag"] = geo.FLAG[c["id"]]
        merged["links"] = links.get(c["id"], {})
        arrival_path = _DATA / "arrival" / f"{c['id']}.json"
        merged["arrival"] = json.loads(arrival_path.read_text(encoding="utf-8")) if arrival_path.exists() else None
        for step in (merged["arrival"] or {}).get("steps", []):
            step["icon"] = step_icon(step.get("title", ""))
        b = basics[c["id"]]
        diff = time_difference(b["tz"], year)
        if diff["summer"] > diff["winter"]:  # 北半球の夏時間（7月が夏時間）
            label = f"{fmt_diff(diff['winter'])}（夏時間は{fmt_diff(diff['summer']).removeprefix('日本より')}）"
        elif diff["summer"] < diff["winter"]:  # 南半球の夏時間（1月が夏時間）
            label = f"{fmt_diff(diff['summer'])}（夏時間は{fmt_diff(diff['winter']).removeprefix('日本より')}）"
        else:
            label = fmt_diff(diff["winter"])
        merged["basics"] = {**b, "diff": label}
        merged["twice"] = c["name"] in ("カナダ", "スロバキア", "韓国", "台湾")
        countries.append(merged)
    return mofa, countries


_CUT = re.compile(r"[。（(／;；]")


def short(text: str, limit: int = 40) -> str:
    """比較表に入れる短い形。最初の句点・かっこ・区切りまでで切り、長ければ limit 文字で止める。
    全文は国のページに出すので、ここでは比べるのに要る頭だけを残す。"""
    head = _CUT.split(text, maxsplit=1)[0].strip(" 、,")
    if not head:
        head = text
    return head if len(head) <= limit else head[: limit - 1] + "…"


_PHONE = re.compile(r"(?<![\d.,])(\d{2,4})(?![\d.,時歳か年月日%])")


def numbers_only(text: str) -> str:
    """緊急番号の一覧表向け。文中の電話番号だけを順に拾って並べる
    （「15（SAMU）/ 112（EU共通）」→「15 / 112」、「112。救急車の直通は999」→「112 / 999」）。"""
    seen: list[str] = []
    for n in _PHONE.findall(text):
        if n not in seen:
            seen.append(n)
    return " / ".join(seen)


# 2か国の比較ページを作る国（行く人が多く、現地情報もくわしい9か国）。この順で組み合わせる。
COMPARE_TOP = ["australia", "canada", "new-zealand", "uk", "ireland", "korea", "taiwan", "germany", "france"]


def pair_slug(a: dict, b: dict) -> str:
    """組み合わせの URL 名。COMPARE_TOP の順に並べる（どちらから押しても同じページ）。"""
    x, y = sorted((a["id"], b["id"]), key=COMPARE_TOP.index)
    return f"{x}-{y}"


def build_faq(mofa: dict, countries: list[dict]) -> list[dict]:
    """よくある質問。答えは外務省の一覧と各国のデータから作る（文章は決まった形、国の並びはデータから）。"""
    pick = lambda pred: [c for c in countries if pred(c)]
    unlimited = pick(lambda c: c["quota"] == "無")
    biggest = max(countries, key=lambda c: c["quota_n"])
    smallest = min((c for c in countries if c["quota_n"]), key=lambda c: c["quota_n"])
    free = pick(lambda c: c["fee"].startswith("無料"))
    newest_year = max(c["since"] for c in countries)
    newest = pick(lambda c: c["since"] == newest_year)
    hosp = pick(lambda c: c["arrival"] and c["arrival"].get("medical", {}).get("hospitals"))
    nostat = pick(lambda c: c["arrival"] and c["arrival"].get("jobs", {}).get("no_statutory"))
    twice = pick(lambda c: c["twice"])
    n = len(countries)
    return [
        {"id": "nansai", "q": "ワーホリは何歳まで行けますか？",
         "a": f"原則として、ビザを申請する時点で18歳以上30歳以下です（外務省）。オーストラリア・カナダ・韓国・アイルランドとの間では協定上18〜25歳ですが、相手国が認める場合は30歳まで申請できます。細かい数え方（「31歳の誕生日の前日まで」など）は国ごとに違うので、各国のページで確かめてください。",
         "countries": [], "link": ("32か国の年齢を比較表で見る", "index.html#compare")},
        {"id": "nankai", "q": "ワーホリは何回行けますか？",
         "a": f"原則として1つの国につき1回です。{'・'.join(c['name'] for c in twice)}は一生のうち2回まで参加でき、英国は最長2年間滞在できます（外務省）。別の国なら、それぞれの国の条件を満たせば行けます。",
         "countries": twice},
        {"id": "kazu", "q": "ワーホリで行ける国はいくつありますか？",
         "a": f"{mofa['source']['as_of']}現在、{n}か国・地域です（外務省）。最も新しいのは{newest_year}年に加わった{'・'.join(c['name'] for c in newest)}です。",
         "countries": newest, "link": ("世界地図で見る", "index.html")},
        {"id": "waku", "q": "人数の枠に上限がない国はどこですか？",
         "a": f"{len(unlimited)}か国です。枠がある国で最も多いのは{biggest['name']}（年{biggest['quota']}人）、最も少ないのは{smallest['name']}（年{smallest['quota']}人）です（外務省）。",
         "countries": unlimited, "link": ("年間発給枠のグラフを見る", "index.html#quota")},
        {"id": "muryou", "q": "ビザの申請費用が無料の国はどこですか？",
         "a": f"公式情報で無料と確かめられた国は{len(free)}か国・地域です。申請費用が確かめられていない国もあるので、載っていない国は各国の公式ページで確かめてください。",
         "countries": free},
        {"id": "zairyu", "q": "在留届は出さないといけませんか？",
         "a": "外国に3か月以上滞在するなら、住む場所を管轄する日本大使館・総領事館に在留届を出す義務があります（旅券法第16条）。外務省の「ORRネット」からオンラインで出せます。",
         "countries": [], "link": ("現地に着いてからの流れを見る", "genchi.html")},
        {"id": "byouin", "q": "日本語が通じる病院がある国はどこですか？",
         "a": f"外務省の「世界の医療事情」や現地の日本大使館・総領事館の一覧で、日本語での対応が書かれている医療機関を載せている国は{len(hosp)}か国・地域です。日本語の対応は曜日や担当者で変わるので、かかる前に確かめてください。",
         "countries": hosp, "link": ("国ごとの緊急の番号と医療情報を見る", "genchi.html")},
        {"id": "saiteichingin", "q": "最低賃金が法律で決まっていない国はありますか？",
         "a": f"{len(nostat)}か国は、法律で決まった全国一律の最低賃金がなく、業種ごとの労働協約で賃金の下限が決まります。",
         "countries": nostat},
        {"id": "dairi", "q": "ビザの申請は代行業者に頼んでもいいですか？",
         "a": "外務省は、申請代行をうたう業者による書類の不適正な処理のトラブルが報じられているとして、業者を使う場合でも書類の準備を任せきりにせず、自分で公式の情報を確かめ、必要なら直接問い合わせるよう呼びかけています。",
         "countries": []},
    ]


def faq_ld(faq: list[dict]) -> str:
    data = {"@context": "https://schema.org", "@type": "FAQPage", "mainEntity": [
        {"@type": "Question", "name": q["q"], "acceptedAnswer": {"@type": "Answer", "text": q["a"]}} for q in faq
    ]}
    return json.dumps(data, ensure_ascii=False).replace("</", "<\\/")


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
    env.filters["short"] = short
    env.filters["numbers_only"] = numbers_only
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
        pair_slug=pair_slug,
    )
    return env


def build(out: Path = _OUTPUT_DIR) -> list[str]:
    """サイトを作り、作ったページの相対パスを返す。"""
    # フォルダごと消さずに中身だけ消す（Windows では開発用サーバーがフォルダを掴んでいて消せないため）
    out.mkdir(parents=True, exist_ok=True)
    for child in out.iterdir():
        shutil.rmtree(child) if child.is_dir() else child.unlink()
    env = _env()
    mofa, countries = load_data()
    updated = jst_today()
    by_region = [(r, [c for c in countries if c["region"] == r]) for r in REGIONS]
    pages: list[str] = []

    def write(rel: str, template: str, crumbs: list[tuple[str, str]] | None = None, **ctx) -> None:
        """crumbs は検索エンジン向けのパンくず（名前, output 内の相対パス）。トップから順に並べる。"""
        depth = rel.count("/")
        crumbs_ld = ""
        if crumbs:
            crumbs_ld = json.dumps({
                "@context": "https://schema.org", "@type": "BreadcrumbList",
                "itemListElement": [
                    {"@type": "ListItem", "position": i + 1, "name": name, "item": canonical_url(path)}
                    for i, (name, path) in enumerate(crumbs)
                ],
            }, ensure_ascii=False).replace("</", "<\\/")  # script の中で </ が終わりに読まれないように
        html = env.get_template(template).render(
            base_url="../" * depth, canonical=canonical_url(rel), updated=updated, mofa=mofa,
            crumbs=crumbs, crumbs_ld=crumbs_ld, **ctx
        )
        path = out / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(html, encoding="utf-8")
        pages.append(rel)

    for c in countries:
        c["compare"] = [{"slug": pair_slug(c, o), "other": o["name"]} for o in countries
                        if c["id"] in COMPARE_TOP and o["id"] in COMPARE_TOP and o["id"] != c["id"]]
    write("index.html", "index.html", countries=countries, by_region=by_region,
          world=geo.world(), europe=geo.europe())
    for i, c in enumerate(countries):
        same_region = [o for o in countries if o["region"] == c["region"] and o["id"] != c["id"]]
        prev_c = countries[i - 1] if i > 0 else None
        next_c = countries[i + 1] if i + 1 < len(countries) else None
        write(f"country/{c['id']}.html", "country.html", c=c, same_region=same_region, loc=geo.locator(c["id"]),
              prev=prev_c, next=next_c,
              crumbs=[("トップ", "index.html"), ("国から探す", "country/index.html"), (c["name"], f"country/{c['id']}.html")])
    write("country/index.html", "country_index.html", by_region=by_region,
          crumbs=[("トップ", "index.html"), ("国から探す", "country/index.html")])
    write("junbi.html", "junbi.html", countries=countries, crumbs=[("トップ", "index.html"), ("出発までの準備", "junbi.html")])
    write("genchi.html", "genchi.html", countries=countries, crumbs=[("トップ", "index.html"), ("現地に着いたら", "genchi.html")])
    by_id = {c["id"]: c for c in countries}
    top = [by_id[i] for i in COMPARE_TOP]
    pairs = [{"a": a, "b": b, "slug": pair_slug(a, b)} for i, a in enumerate(top) for b in top[i + 1:]]
    for p in pairs:
        others = [o for o in pairs if o is not p and (o["a"] in (p["a"], p["b"]) or o["b"] in (p["a"], p["b"]))]
        write(f"hikaku/{p['slug']}.html", "hikaku.html", a=p["a"], b=p["b"], others=others,
              crumbs=[("トップ", "index.html"), ("2か国を比べる", "hikaku/index.html"),
                      (f"{p['a']['name']}と{p['b']['name']}", f"hikaku/{p['slug']}.html")])
    write("hikaku/index.html", "hikaku_index.html", top=top, pairs=pairs,
          crumbs=[("トップ", "index.html"), ("2か国を比べる", "hikaku/index.html")])
    faq = build_faq(mofa, countries)
    write("faq.html", "faq.html", faq=faq, faq_ld=faq_ld(faq), crumbs=[("トップ", "index.html"), ("よくある質問", "faq.html")])
    write("hayami.html", "hayami.html", countries=countries,
          crumbs=[("トップ", "index.html"), ("現地に着いたら", "genchi.html"), ("手続き早見表", "hayami.html")])
    write("mochimono.html", "mochimono.html", packing=PACKING, crumbs=[("トップ", "index.html"), ("持ち物", "mochimono.html")])
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
