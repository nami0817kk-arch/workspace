"""公開したあとに、sitemap の全 URL を IndexNow で知らせる（Bing・Yandex・Naver など。Google は参加していない）。

    python tools/indexnow.py            # output/sitemap.xml を読んで送る
    python tools/indexnow.py --dry-run  # 送らずに中身だけ表示

キーは site_config.INDEXNOW_KEY。render.py がサイト直下に {キー}.txt を置く（検索エンジンがそれを読みに来て、
このサイトの持ち主が送ったことを確かめる）。送信に失敗しても公開そのものは止めない（知らせるだけの補助なので）。
仕様: https://www.indexnow.org/documentation
"""
from __future__ import annotations

import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

import site_config  # noqa: E402

ENDPOINT = "https://api.indexnow.org/indexnow"
SITEMAP = Path(__file__).resolve().parent.parent / "output" / "sitemap.xml"


def payload() -> dict:
    urls = re.findall(r"<loc>([^<]+)</loc>", SITEMAP.read_text(encoding="utf-8"))
    host = urlparse(site_config.SITE_URL).netloc
    return {
        "host": host,
        "key": site_config.INDEXNOW_KEY,
        "keyLocation": f"{site_config.SITE_URL}/{site_config.INDEXNOW_KEY}.txt",
        "urlList": urls,
    }


def main() -> None:
    body = payload()
    print(f"IndexNow: {len(body['urlList'])} 件を送る（{body['host']}）")
    if "--dry-run" in sys.argv:
        print(json.dumps(body, ensure_ascii=False, indent=1)[:800])
        return
    req = urllib.request.Request(
        ENDPOINT,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            print(f"IndexNow: 応答 {res.status}（200=受け付け、202=キーの確認待ち）")
    except urllib.error.HTTPError as e:
        # 400=形の誤り 403=キーが読めない 422=URL がホストと合わない 429=送りすぎ
        print(f"IndexNow: 応答 {e.code} {e.reason}（公開は済んでいる。次の公開で送り直される）")
    except Exception as e:  # ネットワークの失敗でも公開は止めない
        print(f"IndexNow: 送れなかった: {e}")


if __name__ == "__main__":
    main()
