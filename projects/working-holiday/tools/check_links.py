"""data/ に載せた外部リンク（出典・病院・求人窓口など）が生きているかを確かめる。

    python tools/check_links.py

404・410・名前が引けないものを「切れている」として出す。政府のサイトは機械からのアクセスを
403 や 429 で断ることが多いので、それは「門前払い」として別に数える（切れているとは限らない）。
CI では回さない（外のサイトの調子で落ちるため）。データを足したときに手元で回す。
"""
from __future__ import annotations

import json
import subprocess
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import quote, urlsplit, urlunsplit

DATA = Path(__file__).resolve().parent.parent / "data"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"


def collect() -> dict[str, list[str]]:
    """URL → それを載せているファイル名の一覧。"""
    found: dict[str, list[str]] = {}

    def walk(node, where: str) -> None:
        if isinstance(node, dict):
            for v in node.values():
                walk(v, where)
        elif isinstance(node, list):
            for v in node:
                walk(v, where)
        elif isinstance(node, str) and node.startswith("http"):
            found.setdefault(node, []).append(where)

    for path in sorted(DATA.rglob("*.json")):
        if path.parent.name == "geo":
            continue
        walk(json.loads(path.read_text(encoding="utf-8")), str(path.relative_to(DATA)))
    return found


def _ascii(url: str) -> str:
    """日本語を含む URL（アルゼンチン大使館のページなど）を、送れる形に直す。"""
    parts = urlsplit(url)
    return urlunsplit(parts._replace(path=quote(parts.path, safe="/%"), query=quote(parts.query, safe="=&%")))


def _curl(url: str) -> str:
    """Python の接続が TLS や時間切れで失敗したときの取り直し。HTTP の状態コードを返す（000 はつながらない）。"""
    try:
        out = subprocess.run(
            ["curl", "-s", "-o", "NUL" if sys.platform == "win32" else "/dev/null", "-L", "-m", "30",
             "-A", UA, "-w", "%{http_code}", url],
            capture_output=True, text=True, timeout=40,
        )
        return out.stdout.strip() or "000"
    except Exception:
        return "000"


def check(url: str) -> tuple[str, str]:
    url = _ascii(url)
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "ja,en;q=0.8"})
    try:
        with urllib.request.urlopen(req, timeout=20) as res:
            return "ok", str(res.status)
    except urllib.error.HTTPError as e:
        if e.code in (404, 410):
            return "broken", str(e.code)
        return "blocked", str(e.code)
    except Exception:
        code = _curl(url)
        if code.startswith(("2", "3")):
            return "ok", code
        if code in ("404", "410"):
            return "broken", code
        if code == "000":
            return "broken", "つながらない"
        return "blocked", code


def main() -> int:
    urls = collect()
    with ThreadPoolExecutor(max_workers=12) as pool:
        results = dict(zip(urls, pool.map(check, urls)))
    counts: dict[str, int] = {}
    for kind, _ in results.values():
        counts[kind] = counts.get(kind, 0) + 1
    print(f"{len(urls)} 件: " + " / ".join(f"{k} {v}" for k, v in sorted(counts.items())))
    for url, (kind, code) in sorted(results.items()):
        if kind == "broken":
            print(f"  切れている [{code}] {url}  ← {', '.join(sorted(set(urls[url])))}")
    if "-v" in sys.argv:
        for url, (kind, code) in sorted(results.items()):
            if kind == "blocked":
                print(f"  門前払い [{code}] {url}")
    return 1 if counts.get("broken") else 0


if __name__ == "__main__":
    sys.exit(main())
