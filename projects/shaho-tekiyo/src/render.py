"""eligibility.SCHEDULE から Jinja2 テンプレートで output/ に静的HTMLを生成する。

kabu-agari-ranking の src/render.py と同じ形（canonical_url・sitemap・
robots.txt の作り方はそちらの先例に合わせてある）。データ取得が要らない分、
入力は eligibility.SCHEDULE（法定の日程）と data/ の料率（premium.py 経由）だけ。
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

sys.path.insert(0, str(Path(__file__).resolve().parent))

import eligibility
import premium
import site_config

_ROOT = Path(__file__).resolve().parent.parent
_TEMPLATES_DIR = _ROOT / "templates"
_OUTPUT_DIR = _ROOT / "output"

SITE_URL = site_config.SITE_URL

# AdSense の審査を通ったら ca-pub-... を入れる。空のあいだは広告のスクリプトも
# 枠も一切出さない（kabu-agari-ranking と同じ理由。審査前にプレースホルダを置かない）。
ADSENSE_CLIENT = ""

# プライバシーポリシーの文面を最後に直した日。**文面を変えたらここも変える。**
POLICY_UPDATED = "2026年9月26日"

_env = Environment(loader=FileSystemLoader(str(_TEMPLATES_DIR)))
_env.globals["ADSENSE_CLIENT"] = ADSENSE_CLIENT
_env.globals["SITE_URL"] = SITE_URL
_env.globals["SEARCH_CONSOLE_TOKEN"] = site_config.SEARCH_CONSOLE_TOKEN
_env.globals["OWNER"] = site_config.OWNER
_env.globals["CONTACT_EMAIL"] = site_config.CONTACT_EMAIL


def canonical_url(rel_path: str) -> str:
    """output/ 内の相対パスから、実際に配信される URL を組み立てる。

    Cloudflare Pages は `/foo.html` を `/foo` へ、`/dir/index.html` を `/dir/` へ
    308 で飛ばす（kabu-agari-ranking で確認済みの挙動）。sitemap・canonical は
    配信される側の形に揃える。
    """
    rel = rel_path.removeprefix("/")
    if rel == "index.html":
        return f"{SITE_URL}/"
    if rel.endswith("/index.html"):
        return f"{SITE_URL}/{rel[: -len('index.html')]}"
    return f"{SITE_URL}/{rel.removesuffix('.html')}"


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _milestone_slug(regime: eligibility.Regime) -> str:
    d = regime.effective_from
    return f"{d.year}-{d.month:02d}"


def _regime_to_dict(r: eligibility.Regime) -> dict:
    return {
        "effective_from": r.effective_from.isoformat(),
        "company_size_threshold": r.company_size_threshold,
        "wage_requirement_yen": r.wage_requirement_yen,
        "label": r.label,
    }


# 計算機（ブラウザ側 JS）に渡すスケジュール。Python 側の eligibility.SCHEDULE が
# 正で、ここは JSON にシリアライズするだけ。2箇所に別々の表を持つと必ずずれる。
def schedule_json() -> str:
    return json.dumps([_regime_to_dict(r) for r in eligibility.SCHEDULE], ensure_ascii=False)


# 年次ページ用の追加説明。SCHEDULE 自体は判定に使う数字だけを持つので、
# 読み物としての文章はここに分けて持つ。
_MILESTONE_NOTES: dict[str, str] = {
    "2026-10": (
        "これまで「月額8.8万円以上（年収106万円の壁）」だった賃金要件が無くなります。"
        "週20時間以上働いていて、勤務先が51人以上の会社であれば、"
        "月収が8.8万円に届いていなくても加入対象になりえます。"
        "一方で、企業規模の要件（51人以上）はこの段階ではまだ変わりません。"
    ),
    "2027-10": (
        "企業規模要件が「51人以上」から「36人以上」に広がります。"
        "従業員36〜50人の会社で働く人も、新たに対象に入ります。"
    ),
    "2029-10": (
        "企業規模要件がさらに「21人以上」に広がります。"
        "従業員21〜35人の会社で働く人が新たに対象に入ります。"
    ),
    "2032-10": (
        "企業規模要件がさらに「11人以上」に広がります。"
        "従業員11〜20人の会社で働く人が新たに対象に入ります。"
    ),
    "2035-10": (
        "企業規模要件そのものが撤廃されます。会社の人数にかかわらず、"
        "週20時間以上・学生でない・継続2か月超の見込みという要件を満たせば加入対象になります。"
    ),
}


def _build_calculator_page() -> None:
    tmpl = _env.get_template("calculator.html")
    _write(
        _OUTPUT_DIR / "index.html",
        tmpl.render(
            base_url="",
            canonical=canonical_url("index.html"),
            schedule_json=schedule_json(),
            hours_requirement=eligibility.WEEKLY_HOURS_REQUIREMENT,
            milestones=eligibility.MILESTONES,
            prefectures=premium.PREFECTURES,
            rates_json=premium.tables_json(),
        ),
    )


def _build_year_pages() -> None:
    tmpl = _env.get_template("year.html")
    index_tmpl = _env.get_template("year_index.html")
    milestones = eligibility.MILESTONES
    pages = []
    for i, regime in enumerate(milestones):
        slug = _milestone_slug(regime)
        pages.append({"regime": regime, "slug": slug})

    for i, page in enumerate(pages):
        regime = page["regime"]
        slug = page["slug"]
        headline = regime.label.split("：", 1)[1] if "：" in regime.label else regime.label
        _write(
            _OUTPUT_DIR / "year" / f"{slug}.html",
            tmpl.render(
                base_url="../",
                canonical=canonical_url(f"year/{slug}.html"),
                regime=regime,
                slug=slug,
                headline=headline,
                note=_MILESTONE_NOTES[slug],
                schedule=eligibility.SCHEDULE,
                current_index=eligibility.SCHEDULE.index(regime),
                prev_page=pages[i - 1] if i > 0 else None,
                next_page=pages[i + 1] if i + 1 < len(pages) else None,
            ),
        )

    _write(
        _OUTPUT_DIR / "year" / "index.html",
        index_tmpl.render(
            base_url="../",
            canonical=canonical_url("year/index.html"),
            pages=pages,
        ),
    )


# 月収別のページ（/getsushu/10man.html）。8万〜25万円を1万円刻みで。
AMOUNTS_MAN: tuple[int, ...] = tuple(range(8, 26))


def _era(fiscal_year: int) -> str:
    return f"令和{fiscal_year - 2018}年度"


def _build_amount_pages() -> None:
    table = premium.TABLES[-1]
    as_of = table.valid_from
    period = f"{table.valid_from.year}年{table.valid_from.month}月分〜{table.valid_until.year}年{table.valid_until.month}月分"
    era = _era(table.fiscal_year)

    def est(pref: str, pay: int, care: bool = False) -> premium.PremiumResult:
        return premium.estimate(as_of=as_of, prefecture=pref, monthly_pay_yen=pay, age_40_to_64=care)

    all_amounts = [
        {"man": m, "slug": f"{m}man", "r": est("東京", m * 10_000)} for m in AMOUNTS_MAN
    ]
    common = dict(era=era, period=period, source=table.source, all_amounts=all_amounts)
    tmpl = _env.get_template("amount.html")
    for i, a in enumerate(all_amounts):
        pay = a["man"] * 10_000
        rows = [(est(p, pay), est(p, pay, True)) for p in premium.PREFECTURES]
        by_total = sorted((r for r, _ in rows), key=lambda r: r.total_yen)
        rel = f"getsushu/{a['slug']}.html"
        _write(
            _OUTPUT_DIR / rel,
            tmpl.render(
                base_url="../",
                canonical=canonical_url(rel),
                man=a["man"],
                pay=pay,
                tokyo=a["r"],
                tokyo_care=est("東京", pay, True),
                cheapest=by_total[0],
                dearest=by_total[-1],
                rows=rows,
                neighbors=all_amounts[max(0, i - 1): i + 2],
                **common,
            ),
        )
    _write(
        _OUTPUT_DIR / "getsushu" / "index.html",
        _env.get_template("amount_index.html").render(
            base_url="../", canonical=canonical_url("getsushu/index.html"), **common
        ),
    )


def amount_page_paths() -> list[str]:
    return ["getsushu/index.html"] + [f"getsushu/{m}man.html" for m in AMOUNTS_MAN]


def _build_static_pages() -> None:
    for name in ("faq.html", "about.html", "operator.html", "privacy.html", "contact.html"):
        tmpl = _env.get_template(name)
        _write(
            _OUTPUT_DIR / name,
            tmpl.render(
                base_url="",
                canonical=canonical_url(name),
                policy_updated=POLICY_UPDATED,
                schedule=eligibility.SCHEDULE,
                milestones=eligibility.MILESTONES,
            ),
        )

    tmpl_404 = _env.get_template("404.html")
    _write(_OUTPUT_DIR / "404.html", tmpl_404.render(base_url="/", canonical=""))


_ROBOTS_TXT = f"""User-agent: *
Allow: /

Sitemap: {SITE_URL}/sitemap.xml
"""


def _write_robots() -> None:
    (_OUTPUT_DIR / "robots.txt").write_text(_ROBOTS_TXT, encoding="utf-8")


def _ads_txt() -> str | None:
    """ads.txt の中身。pub-ID が無いあいだは置かない（kabu-agari-ranking と同じ理由）。"""
    if not ADSENSE_CLIENT:
        return None
    pub_id = ADSENSE_CLIENT.removeprefix("ca-")
    return f"google.com, {pub_id}, DIRECT, f08c47fec0942fa0\n"


def _write_sitemap() -> None:
    urls: list[tuple[str, str | None]] = [
        (canonical_url("index.html"), None),
        (canonical_url("faq.html"), None),
        (canonical_url("about.html"), None),
        (canonical_url("operator.html"), None),
        (canonical_url("contact.html"), None),
        (canonical_url("privacy.html"), None),
        (canonical_url("year/index.html"), None),
    ]
    urls += [(canonical_url(p), None) for p in amount_page_paths()]
    for regime in eligibility.MILESTONES:
        slug = _milestone_slug(regime)
        urls.append((canonical_url(f"year/{slug}.html"), None))

    entries = "\n".join(
        f"  <url><loc>{loc}</loc>"
        + (f"<lastmod>{lastmod}</lastmod>" if lastmod else "")
        + "</url>"
        for loc, lastmod in urls
    )
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{entries}\n"
        "</urlset>\n"
    )
    (_OUTPUT_DIR / "sitemap.xml").write_text(xml, encoding="utf-8")


def build_all() -> None:
    """output/ を作り直し、全ページを生成する。"""
    if _OUTPUT_DIR.exists():
        shutil.rmtree(_OUTPUT_DIR)
    _OUTPUT_DIR.mkdir(parents=True)

    _build_calculator_page()
    _build_year_pages()
    _build_amount_pages()
    _build_static_pages()
    _write_robots()
    _write_sitemap()

    ads_txt = _ads_txt()
    if ads_txt is not None:
        (_OUTPUT_DIR / "ads.txt").write_text(ads_txt, encoding="utf-8")

    static_src = _ROOT / "static"
    if static_src.exists():
        shutil.copytree(static_src, _OUTPUT_DIR / "static", dirs_exist_ok=True)


if __name__ == "__main__":
    build_all()
    print(f"built into {_OUTPUT_DIR}")
