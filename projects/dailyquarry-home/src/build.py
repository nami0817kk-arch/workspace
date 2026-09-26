"""dailyquarry.com の静的ページを output/ に書き出す。"""
import shutil
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape

import site_config

_ROOT = Path(__file__).resolve().parents[1]
_OUTPUT_DIR = _ROOT / "output"

PAGES = ["index.html", "operator.html", "privacy.html", "contact.html", "404.html"]


def _env() -> Environment:
    env = Environment(
        loader=FileSystemLoader(_ROOT / "templates"),
        autoescape=select_autoescape(["html"]),
    )
    env.globals.update(
        SITE_URL=site_config.SITE_URL,
        SEARCH_CONSOLE_TOKEN=site_config.SEARCH_CONSOLE_TOKEN,
        ADSENSE_CLIENT=site_config.ADSENSE_CLIENT,
        OWNER=site_config.OWNER,
        CONTACT_EMAIL=site_config.CONTACT_EMAIL,
        POLICY_UPDATED=site_config.POLICY_UPDATED,
        SITES=site_config.SITES,
    )
    return env


def ads_txt() -> str | None:
    """ルートの ads.txt。pub-ID が無いあいだは置かない（kabu-agari-ranking と同じ理由）。

    サブドメインも同じ pub-ID なので、この1行で全サイトぶんを兼ねる。
    """
    if not site_config.ADSENSE_CLIENT:
        return None
    pub_id = site_config.ADSENSE_CLIENT.removeprefix("ca-")
    return f"google.com, {pub_id}, DIRECT, f08c47fec0942fa0\n"


def _sitemap() -> str:
    # Cloudflare Pages は /x.html を /x へ 308 で送るので、転送されない形で載せる。
    urls = [site_config.SITE_URL + "/"] + [
        f"{site_config.SITE_URL}/{p.removesuffix('.html')}" for p in PAGES if p not in ("index.html", "404.html")
    ]
    body = "".join(f"  <url><loc>{u}</loc></url>\n" for u in urls)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{body}</urlset>\n"
    )


def build(output_dir: Path = _OUTPUT_DIR) -> None:
    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)
    env = _env()
    for page in PAGES:
        html = env.get_template(page).render(page=page)
        (output_dir / page).write_text(html, encoding="utf-8")
    (output_dir / "sitemap.xml").write_text(_sitemap(), encoding="utf-8")
    (output_dir / "robots.txt").write_text(
        f"User-agent: *\nAllow: /\nSitemap: {site_config.SITE_URL}/sitemap.xml\n",
        encoding="utf-8",
    )
    ads = ads_txt()
    if ads:
        (output_dir / "ads.txt").write_text(ads, encoding="utf-8")
    print(f"  {output_dir} を生成しました")


if __name__ == "__main__":
    build()
