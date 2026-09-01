"""ローカル PC で動いている実物の Chrome を操作する。

これは自分の PC 上で実行するスクリプト。Claude Code のリモート環境
(クラウド上のコンテナ)から実行しても、PC の Chrome には届かない。

仕組み:
    Chrome をリモートデバッグポート付きで起動しておき、Playwright の
    CDP (Chrome DevTools Protocol) 接続でそこにぶら下がる。ヘッドレスの
    使い捨てブラウザではなく、目の前で開いている Chrome をそのまま操作する。

事前準備:
    Windows:    powershell -ExecutionPolicy Bypass -File scripts\\start-chrome-debug.ps1
    mac/Linux:  ./scripts/start-chrome-debug.sh

使い方:
    python -m src.browser.local_chrome --list                 # 開いているタブ一覧
    python -m src.browser.local_chrome --url https://example.com
    python -m src.browser.local_chrome --shot output/tab.png  # 現在のタブを撮る
    python -m src.browser.local_chrome --url https://example.com --shot output/tab.png
"""

from __future__ import annotations

import argparse
from pathlib import Path

from playwright.sync_api import Error as PlaywrightError
from playwright.sync_api import sync_playwright

DEFAULT_PORT = 9222

CONNECT_HINT = """\
Chrome に接続できませんでした。リモートデバッグを有効にした Chrome が
起動しているか確認してください。

    Windows:    powershell -ExecutionPolicy Bypass -File scripts\\start-chrome-debug.ps1
    mac/Linux:  ./scripts/start-chrome-debug.sh

なお、このスクリプトを操作したい Chrome と同じ PC で実行する必要があります。\
"""


def pick_page(context, url: str | None):
    """操作対象のタブを決める。URL 指定があれば新しいタブで開く。"""
    if url:
        page = context.new_page()
        page.goto(url, wait_until="domcontentloaded", timeout=60_000)
        return page

    pages = [p for p in context.pages if not p.url.startswith("devtools://")]
    if not pages:
        return context.new_page()
    return pages[-1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="リモートデバッグポート")
    parser.add_argument("--url", help="新しいタブで開く URL")
    parser.add_argument("--shot", type=Path, help="スクリーンショットの保存先")
    parser.add_argument("--list", action="store_true", help="開いているタブを一覧表示して終了")
    args = parser.parse_args()

    with sync_playwright() as p:
        try:
            browser = p.chromium.connect_over_cdp(f"http://127.0.0.1:{args.port}")
        except PlaywrightError as exc:
            print(f"{CONNECT_HINT}\n\n詳細: {exc}")
            return 1

        # CDP 接続では既存のプロファイルが contexts[0] として見える。
        context = browser.contexts[0] if browser.contexts else browser.new_context()

        if args.list:
            for i, page in enumerate(context.pages):
                print(f"[{i}] {page.title()}\n    {page.url}")
            browser.close()
            return 0

        page = pick_page(context, args.url)
        page.bring_to_front()

        print(f"タイトル: {page.title()}")
        print(f"URL: {page.url}")

        if args.shot:
            args.shot.parent.mkdir(parents=True, exist_ok=True)
            page.screenshot(path=str(args.shot))
            print(f"スクリーンショット: {args.shot}")

        # close() は CDP 接続を切るだけで、Chrome 自体は開いたまま残る。
        browser.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
