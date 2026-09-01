"""ヘッドレス Chromium でブラウザを自動操作するデモ。

このスクリプトが動く場所のブラウザを操作する。Claude Code のリモート環境で
実行すればコンテナ内の Chromium が、ローカル PC で実行すれば PC 上の
Chromium が動く(ローカル Chrome 本体を操作したい場合は local_chrome.py)。

使い方:
    # 同梱のデモページを開いて入力・選択・クリックし、スクリーンショットを撮る
    python -m src.browser.headless_demo

    # 任意の URL を開いてスクリーンショットだけ撮る
    python -m src.browser.headless_demo --url https://example.com --out output/shot.png

    # ブラウザの画面を表示しながら動かす(GUI のあるローカル PC のみ)
    python -m src.browser.headless_demo --headed
"""

from __future__ import annotations

import argparse
from pathlib import Path

from playwright.sync_api import sync_playwright

from . import config

DEMO_PAGE = Path(__file__).with_name("demo_page.html")
DEFAULT_OUT = Path("output/headless_demo.png")


def run_demo_page(page) -> None:
    """同梱のデモページを実際に操作して、結果テキストを読み取る。"""
    page.goto(DEMO_PAGE.resolve().as_uri())

    page.fill("#name", "クロード")
    page.select_option("#plan", "team")
    page.click("#submit")

    result = page.text_content("#result")
    print(f"ページ上の結果: {result}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", help="開く URL(省略時は同梱のデモページを操作する)")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="スクリーンショットの保存先")
    parser.add_argument("--headed", action="store_true", help="ブラウザ画面を表示する")
    parser.add_argument("--full-page", action="store_true", help="ページ全体を撮る")
    args = parser.parse_args()

    args.out.parent.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(
            executable_path=config.chromium_executable(),
            args=config.launch_args(),
            headless=not args.headed,
        )
        page = browser.new_page(viewport={"width": 1280, "height": 860})

        if args.url:
            page.goto(args.url, wait_until="domcontentloaded", timeout=60_000)
            page.wait_for_timeout(2_000)
        else:
            run_demo_page(page)

        print(f"タイトル: {page.title()}")
        print(f"URL: {page.url}")

        page.screenshot(path=str(args.out), full_page=args.full_page)
        print(f"スクリーンショット: {args.out}")

        browser.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
