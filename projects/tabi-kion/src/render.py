"""data/normals.json と stations.STATIONS から output/ に静的HTMLを生成する。

作りは shaho-tekiyo・kabu-agari-ranking と同じ（canonical_url・sitemap・robots.txt）。
ページは「地点×月」（/takayama/11.html）と地点ごとの一覧（/takayama/）。
"""
from __future__ import annotations

import shutil
import sys
from itertools import groupby
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

sys.path.insert(0, str(Path(__file__).resolve().parent))

import climate  # noqa: E402
import site_config  # noqa: E402
from stations import STATIONS  # noqa: E402

_ROOT = Path(__file__).resolve().parent.parent
_TEMPLATES_DIR = _ROOT / "templates"
_OUTPUT_DIR = _ROOT / "output"

SITE_URL = site_config.SITE_URL

# AdSense の審査を通ったら ca-pub-... を入れる。空のあいだは広告のスクリプトも枠も出さない。
ADSENSE_CLIENT = ""

POLICY_UPDATED = "2026年9月26日"

_env = Environment(loader=FileSystemLoader(str(_TEMPLATES_DIR)))
_env.globals.update(
    ADSENSE_CLIENT=ADSENSE_CLIENT,
    SITE_URL=SITE_URL,
    SEARCH_CONSOLE_TOKEN=site_config.SEARCH_CONSOLE_TOKEN,
    OWNER=site_config.OWNER,
    CONTACT_EMAIL=site_config.CONTACT_EMAIL,
    SOURCE=climate.SOURCE,
    diff_text=climate.diff_text,
    comparison_sentence=climate.comparison_sentence,
)


def canonical_url(rel_path: str) -> str:
    """Cloudflare Pages は /foo.html を /foo へ、/dir/index.html を /dir/ へ飛ばす。配信される側に揃える。"""
    rel = rel_path.removeprefix("/")
    if rel == "index.html":
        return f"{SITE_URL}/"
    if rel.endswith("/index.html"):
        return f"{SITE_URL}/{rel[: -len('index.html')]}"
    return f"{SITE_URL}/{rel.removesuffix('.html')}"


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _clothing_rows() -> list[tuple[str, str]]:
    rows = []
    prev = None
    for threshold, text in climate._CLOTHING:
        if threshold <= -99:
            label = f"{prev}℃未満"
        elif prev is None:
            label = f"{threshold}℃以上"
        else:
            label = f"{threshold}℃以上{prev}℃未満"
        rows.append((label, text))
        prev = threshold
    return rows


def month_pages() -> list[str]:
    return [f"{st.slug}/{m}.html" for st in STATIONS for m in range(1, 13)]


def build_all() -> None:
    if _OUTPUT_DIR.exists():
        shutil.rmtree(_OUTPUT_DIR)
    _OUTPUT_DIR.mkdir(parents=True)

    month_tmpl = _env.get_template("month.html")
    rich_tmpl = _env.get_template("month_rich.html")
    station_tmpl = _env.get_template("station.html")
    for st in STATIONS:
        months = [climate.month_climate(st.code, m) for m in range(1, 13)]
        for c in months:
            i = c.month - 1
            neighbors = [months[(i - 1) % 12], c, months[(i + 1) % 12]]
            rel = f"{st.slug}/{c.month}.html"
            g = climate.guide(st.slug, c.month)
            if g is not None:
                _write(
                    _OUTPUT_DIR / rel,
                    rich_tmpl.render(
                        base_url="../",
                        canonical=canonical_url(rel),
                        c=c,
                        g=g,
                        dks=climate.dekads(st.code, c.month),
                        snow=climate.first_snow(st.code),
                        near=climate.nearby_points(st.code, c.month),
                        elevation=climate.NORMALS[st.code]["elevation"],
                        chart=climate.year_chart_svg(st.code, c.month),
                    ),
                )
                continue
            _write(
                _OUTPUT_DIR / rel,
                month_tmpl.render(
                    base_url="../",
                    canonical=canonical_url(rel),
                    c=c,
                    neighbors=neighbors,
                    comparisons=climate.comparisons(st.code, c.month),
                    same_month_others=[o for o in STATIONS if o.code != st.code],
                ),
            )
        rel = f"{st.slug}/index.html"
        _write(_OUTPUT_DIR / rel, station_tmpl.render(base_url="../", canonical=canonical_url(rel), st=st, months=months))

    by_pref = [(pref, list(group)) for pref, group in groupby(STATIONS, key=lambda s: s.pref)]
    _write(_OUTPUT_DIR / "index.html", _env.get_template("index.html").render(base_url="", canonical=canonical_url("index.html"), by_pref=by_pref))
    _write(_OUTPUT_DIR / "about.html", _env.get_template("about.html").render(base_url="", canonical=canonical_url("about.html"), clothing_rows=_clothing_rows()))
    for name in ("operator.html", "privacy.html", "contact.html"):
        _write(_OUTPUT_DIR / name, _env.get_template(name).render(base_url="", canonical=canonical_url(name), policy_updated=POLICY_UPDATED))
    _write(_OUTPUT_DIR / "404.html", _env.get_template("404.html").render(base_url="/", canonical=""))

    static_src = _ROOT / "static"
    if static_src.exists():
        shutil.copytree(static_src, _OUTPUT_DIR / "static", dirs_exist_ok=True)

    (_OUTPUT_DIR / "robots.txt").write_text(f"User-agent: *\nAllow: /\n\nSitemap: {SITE_URL}/sitemap.xml\n", encoding="utf-8")
    urls = ["index.html", "about.html", "operator.html", "contact.html", "privacy.html"]
    urls += [f"{st.slug}/index.html" for st in STATIONS] + month_pages()
    entries = "\n".join(f"  <url><loc>{canonical_url(u)}</loc></url>" for u in urls)
    (_OUTPUT_DIR / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{entries}\n</urlset>\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    build_all()
    print(f"built into {_OUTPUT_DIR}")
