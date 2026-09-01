"""src/browser のテスト。"""

from __future__ import annotations

from pathlib import Path

import pytest

from browser import config, control
from browser.headless_demo import DEMO_PAGE, run_demo_page

playwright_api = pytest.importorskip("playwright.sync_api")


def test_launch_args_are_wellformed():
    """追加引数は、必要なときだけ SPKI 指定の形で返る。"""
    args = config.launch_args()
    assert all(a.startswith("--ignore-certificate-errors-spki-list=") for a in args)
    assert len(args) <= 1


def test_ca_spki_hash_survives_unreadable_cert(monkeypatch):
    """読めない場所にある CA は「無い」扱いにする。

    GitHub Actions のランナーでは /root が読めず、Path.exists() が False では
    なく PermissionError を送出する（EACCES は pathlib の無視対象外）。
    ここを素通しにすると launch_args() ごと落ちて CI 全体が赤くなる。
    """

    def raise_permission_error(self, **kwargs):
        raise PermissionError(13, "Permission denied")

    monkeypatch.setattr(Path, "exists", raise_permission_error)
    assert config._ca_spki_hash(Path("/root/.ccr/agent-proxy-ca.crt")) is None
    assert config.launch_args() == []


def test_demo_page_exists():
    assert DEMO_PAGE.is_file()


def test_powershell_script_has_utf8_bom():
    """BOM がないと Windows PowerShell 5.1 が CP932 として読み、日本語で構文エラーになる。"""
    script = Path(__file__).resolve().parents[2] / "scripts" / "start-chrome-debug.ps1"
    assert script.is_file()
    assert script.read_bytes().startswith(b"\xef\xbb\xbf"), "UTF-8 BOM が必要"


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


def test_select_index_defaults_to_last():
    """match 無しなら最後のタブ(直近に開いたもの)を選ぶ。"""
    entries = [("Google", "https://google.com"), ("X", "https://x.com/home")]
    assert control.select_index(entries, None) == 1


def test_select_index_matches_url_or_title():
    entries = [("Google", "https://google.com"), ("X", "https://x.com/home")]
    assert control.select_index(entries, "x.com") == 1
    assert control.select_index(entries, "google") == 0


def test_select_index_prefers_the_newest_hit():
    """同じ条件に複数一致したら、後に開いたほうを操作対象にする。"""
    entries = [("X", "https://x.com/a"), ("Google", "https://google.com"), ("X", "https://x.com/b")]
    assert control.select_index(entries, "x.com") == 2


def test_select_index_returns_none_when_nothing_matches():
    assert control.select_index([("Google", "https://google.com")], "example") is None
    assert control.select_index([], None) is None


def test_close_requires_match():
    """取り違えて利用者のタブを消さないよう、close は --match 必須。"""
    with pytest.raises(SystemExit):
        control.build_parser().parse_args(["close"])
