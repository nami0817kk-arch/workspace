"""src/browser のテスト。"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from src.browser import config  # noqa: E402
from src.browser.headless_demo import DEMO_PAGE, run_demo_page  # noqa: E402

playwright_api = pytest.importorskip("playwright.sync_api")


def test_launch_args_are_wellformed():
    """追加引数は、必要なときだけ SPKI 指定の形で返る。"""
    args = config.launch_args()
    assert all(a.startswith("--ignore-certificate-errors-spki-list=") for a in args)
    assert len(args) <= 1


def test_demo_page_exists():
    assert DEMO_PAGE.is_file()


@pytest.fixture(scope="module")
def browser():
    with playwright_api.sync_playwright() as p:
        try:
            b = p.chromium.launch(
                executable_path=config.chromium_executable(),
                args=config.launch_args(),
            )
        except playwright_api.Error as exc:
            pytest.skip(f"Chromium を起動できない: {exc}")
        yield b
        b.close()


def test_demo_page_interaction(browser):
    """入力・選択・クリックがページに反映される。"""
    page = browser.new_page()
    run_demo_page(page)

    assert page.input_value("#name") == "クロード"
    assert page.input_value("#plan") == "team"
    assert page.text_content("#result") == "受付完了: クロード さん / チームプラン"
    page.close()


def test_screenshot_is_written(browser, tmp_path):
    page = browser.new_page()
    page.goto(DEMO_PAGE.resolve().as_uri())

    out = tmp_path / "shot.png"
    page.screenshot(path=str(out))

    assert out.is_file() and out.stat().st_size > 0
    page.close()
