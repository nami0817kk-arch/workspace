"""ローカル Chrome(CDP接続)で X のタイムラインを読み、投稿本文を標準出力に出す。

前提: リモートデバッグ有効の Chrome が 127.0.0.1:9222 で動いていること。
      X にログイン済みのプロファイルだと取得できる件数が多い。

使い方:
    python x_timeline.py FabrizioRomano            # 既定 6 スクロール
    python x_timeline.py FabrizioRomano --rounds 3
    python x_timeline.py FabrizioRomano --keep     # 読み終わってもタブを残す
"""

from __future__ import annotations

import argparse
import sys

from playwright.sync_api import Error as PlaywrightError
from playwright.sync_api import sync_playwright

HINT = """\
Chrome に接続できません。リモートデバッグ付きで起動してください:

    powershell -ExecutionPolicy Bypass -File "C:/Users/なみ/dev/workspace/platform/ai-lab/scripts/start-chrome-debug.ps1"
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("handle", help="X のハンドル(@なし)または完全な URL")
    ap.add_argument("--port", type=int, default=9222)
    ap.add_argument("--rounds", type=int, default=6, help="スクロール回数")
    ap.add_argument("--keep", action="store_true", help="読み終わってもタブを閉じない")
    args = ap.parse_args()

    url = args.handle if args.handle.startswith("http") else f"https://x.com/{args.handle}"

    with sync_playwright() as p:
        try:
            browser = p.chromium.connect_over_cdp(f"http://127.0.0.1:{args.port}")
        except PlaywrightError as exc:
            print(f"{HINT}\n詳細: {exc}", file=sys.stderr)
            return 1

        ctx = browser.contexts[0] if browser.contexts else browser.new_context()
        page = ctx.new_page()
        page.goto(url, wait_until="domcontentloaded", timeout=60_000)
        # X は描画が遅い。投稿が出るまで待つ(出なければそのまま診断へ進む)。
        try:
            page.wait_for_selector("article", timeout=30_000)
        except PlaywrightError:
            pass
        page.wait_for_timeout(2_000)

        print(f"URL: {page.url}")
        print(f"TITLE: {page.title()}")

        seen: set[str] = set()
        order: list[str] = []
        for _ in range(args.rounds):
            for art in page.query_selector_all("article"):
                text = (art.inner_text() or "").strip().replace("\n", " | ")
                if text and text not in seen:
                    seen.add(text)
                    order.append(text)
            page.mouse.wheel(0, 2500)
            page.wait_for_timeout(2_500)

        if not order:
            print("投稿を取得できませんでした(未ログイン・レート制限・DOM変更の可能性)。")
            print("BODY:", (page.inner_text("body") or "")[:800])

        for i, text in enumerate(order):
            print(f"--- [{i}] {text[:600]}")

        # 自分が開いたタブは片付ける(--keep で残せる)。
        if not args.keep:
            page.close()
        browser.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
