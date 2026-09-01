"""ローカル Chrome を CDP 経由で操作する汎用 CLI。

各 PJT から呼ぶための入口。タブ一覧・URL を開く・撮影・本文の読み取り・
別ウィンドウへの複製・タブを閉じる、をサブコマンドで提供する。

local_chrome.py が「1回の接続で1つのことをする最小の例」なのに対し、
こちらは他プロジェクトから日常的に呼ぶことを想定した道具箱。接続先は同じ。

事前準備（リモートデバッグ付きで Chrome を起動しておく）:
    powershell -ExecutionPolicy Bypass -File scripts/start-chrome-debug.ps1

使い方:
    python -m src.browser.control list
    python -m src.browser.control open https://example.com --shot output/x.png
    python -m src.browser.control open https://example.com --window   # 別ウィンドウで開く
    python -m src.browser.control text --match example.com
    python -m src.browser.control shot output/tab.png --match x.com
    python -m src.browser.control dup --match x.com                   # 別ウィンドウに複製
    python -m src.browser.control pdf output/genpon.pdf --match go.jp # 表示中のページを PDF で残す
    python -m src.browser.control links --match go.jp --filter .pdf   # ページ内のリンクを探す
    python -m src.browser.control close --match example.com
"""

from __future__ import annotations

import argparse
import base64
import sys
from pathlib import Path

from playwright.sync_api import Error as PlaywrightError
from playwright.sync_api import sync_playwright

from .local_chrome import CONNECT_HINT, DEFAULT_PORT

# 描画が終わるまで待つ既定値（X のような重いページ向け）。
READY_TIMEOUT_MS = 20_000

#: 用紙サイズ（インチ）。CDP の printToPDF はインチで受ける
PAPER_SIZES = {"a4": (8.27, 11.69), "letter": (8.5, 11.0)}


def use_utf8_stdout() -> None:
    """Windows コンソール（CP932）でも外国語の本文を落とさずに出す。"""
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


def select_index(entries: list[tuple[str, str]], match: str | None) -> int | None:
    """(title, url) の一覧から操作対象の位置を選ぶ。

    match があればタイトルか URL に含まれるものの**最後**、無ければ一覧の最後。
    devtools:// は呼び出し側で除いてある前提。該当なしは None。
    """
    if not entries:
        return None
    if match is None:
        return len(entries) - 1
    needle = match.lower()
    hits = [
        i
        for i, (title, url) in enumerate(entries)
        if needle in title.lower() or needle in url.lower()
    ]
    return hits[-1] if hits else None


def _pages(ctx):
    return [p for p in ctx.pages if not p.url.startswith("devtools://")]


def _entries(pages) -> list[tuple[str, str]]:
    return [(p.title(), p.url) for p in pages]


def _pick(ctx, match: str | None):
    pages = _pages(ctx)
    idx = select_index(_entries(pages), match)
    if idx is None:
        return None
    return pages[idx]


def _wait_ready(page) -> None:
    try:
        page.wait_for_load_state("networkidle", timeout=READY_TIMEOUT_MS)
    except PlaywrightError:
        pass


def _shoot(page, path: Path, full_page: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    page.screenshot(path=str(path), full_page=full_page)
    print(f"スクリーンショット: {path}")


def _read_text(page, selector: str | None) -> str:
    if selector:
        parts = [(el.inner_text() or "").strip() for el in page.query_selector_all(selector)]
        return "\n\n".join(p for p in parts if p)
    return (page.inner_text("body") or "").strip()


def decode_pdf(result: dict) -> bytes:
    """printToPDF の戻り（base64）をバイト列にする。"""
    data = (result or {}).get("data")
    if not data:
        raise ValueError("PDF が返ってこなかった。ページの読み込みが終わっているか確認する。")
    return base64.b64decode(data)


def collect_links(raw) -> list[tuple[str, str]]:
    """ページから取り出した生の配列を (文字, URL) に均す。"""
    links: list[tuple[str, str]] = []
    for entry in raw or []:
        if isinstance(entry, dict):
            text, url = entry.get("text", ""), entry.get("href", "")
        elif isinstance(entry, (list, tuple)) and len(entry) >= 2:
            text, url = entry[0], entry[1]
        else:
            continue
        url = (url or "").strip()
        if url and not url.startswith("javascript:"):
            links.append((" ".join((text or "").split()), url))
    return links


def filter_links(links: list[tuple[str, str]], needle: str | None) -> list[tuple[str, str]]:
    """絞り込みつつ、同じ URL は最初の1件だけ残す。

    一次情報を探すときは同じ PDF へのリンクが何本も並ぶので、重複を落とさないと
    一覧が読めなくなる。
    """
    found: list[tuple[str, str]] = []
    seen: set[str] = set()
    lowered = (needle or "").lower()
    for text, url in links:
        if lowered and lowered not in url.lower() and lowered not in text.lower():
            continue
        if url in seen:
            continue
        seen.add(url)
        found.append((text, url))
    return found


def cmd_list(ctx, args) -> int:
    for i, page in enumerate(_pages(ctx)):
        session = ctx.new_cdp_session(page)
        window_id = session.send("Browser.getWindowForTarget")["windowId"]
        session.detach()
        print(f"[{i}] window={window_id} {page.title()}\n    {page.url}")
    return 0


def cmd_open(ctx, args) -> int:
    if args.window:
        # 別ウィンドウで開くのは CDP でしか指示できない（Playwright に API が無い）。
        pages = _pages(ctx)
        anchor = pages[-1] if pages else ctx.new_page()
        session = ctx.new_cdp_session(anchor)
        session.send("Target.createTarget", {"url": args.url, "newWindow": True})
        session.detach()
        print(f"別ウィンドウで開いた: {args.url}")
        return 0

    page = ctx.new_page()
    page.goto(args.url, wait_until="domcontentloaded", timeout=60_000)
    _wait_ready(page)
    print(f"タイトル: {page.title()}")
    print(f"URL: {page.url}")
    if args.shot:
        _shoot(page, args.shot, args.full_page)
    if args.text:
        print(_read_text(page, args.selector))
    return 0


def cmd_shot(ctx, args) -> int:
    page = _pick(ctx, args.match)
    if page is None:
        print("対象のタブが見つからない。list で確認する。")
        return 1
    print(f"URL: {page.url}")
    _shoot(page, args.path, args.full_page)
    return 0


def cmd_text(ctx, args) -> int:
    page = _pick(ctx, args.match)
    if page is None:
        print("対象のタブが見つからない。list で確認する。")
        return 1
    print(f"URL: {page.url}")
    print(f"TITLE: {page.title()}")
    text = _read_text(page, args.selector)
    print(text[: args.limit] if args.limit else text)
    return 0


def cmd_pdf(ctx, args) -> int:
    """表示中のページを PDF で保存する。

    原文をそのまま手元に残すための機能。あとで消えたり差し替わったりする
    公的資料を扱うので、見た目ごと固定できる形で残す。
    Playwright の page.pdf() はヘッドレス専用なので、CDP を直接叩く。
    """
    page = _pick(ctx, args.match)
    if page is None:
        print("対象のタブが見つからない。list で確認する。")
        return 1

    width, height = PAPER_SIZES[args.paper]
    session = ctx.new_cdp_session(page)
    try:
        result = session.send(
            "Page.printToPDF",
            {
                "printBackground": not args.no_background,
                "landscape": args.landscape,
                "paperWidth": width,
                "paperHeight": height,
            },
        )
    except PlaywrightError as exc:
        print(f"PDF にできなかった: {exc}")
        return 1
    finally:
        session.detach()

    args.path.parent.mkdir(parents=True, exist_ok=True)
    args.path.write_bytes(decode_pdf(result))
    print(f"URL: {page.url}")
    print(f"PDF: {args.path}")
    return 0


def cmd_links(ctx, args) -> int:
    """ページ内のリンクを一覧する（原文PDFの在り処を探す用）。"""
    page = _pick(ctx, args.match)
    if page is None:
        print("対象のタブが見つからない。list で確認する。")
        return 1

    raw = page.eval_on_selector_all(
        "a[href]", "els => els.map(e => ({text: e.innerText, href: e.href}))"
    )
    links = filter_links(collect_links(raw), args.filter)
    print(f"URL: {page.url}")
    if not links:
        print("該当するリンクが無い。")
        return 1
    for text, url in links[: args.limit] if args.limit else links:
        print(f"- {text or '(文字なし)'}\n  {url}")
    return 0


def cmd_dup(ctx, args) -> int:
    page = _pick(ctx, args.match)
    if page is None:
        print("対象のタブが見つからない。list で確認する。")
        return 1
    session = ctx.new_cdp_session(page)
    session.send("Target.createTarget", {"url": page.url, "newWindow": not args.same_window})
    session.detach()
    where = "同じウィンドウ" if args.same_window else "別ウィンドウ"
    print(f"{where}に複製した: {page.url}")
    return 0


def cmd_close(ctx, args) -> int:
    # 取り違えると利用者のタブを消すので、close だけは --match を必須にしてある。
    needle = args.match.lower()
    pages = [p for p in _pages(ctx) if needle in (p.title() + p.url).lower()]
    if not pages:
        print(f"一致するタブが無い: {args.match}")
        return 1
    if len(pages) > 1 and not args.all:
        for p in pages:
            print(f"  {p.title()} | {p.url}")
        print(f"{len(pages)} 件一致した。全部閉じるなら --all を付ける。")
        return 1
    for p in pages:
        print(f"閉じる: {p.url}")
        p.close()
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="リモートデバッグポート")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list", help="開いているタブを一覧表示する")

    p_open = sub.add_parser("open", help="URL を新しいタブで開く")
    p_open.add_argument("url")
    p_open.add_argument("--window", action="store_true", help="別ウィンドウで開く")
    p_open.add_argument("--shot", type=Path, help="開いた後に撮影する")
    p_open.add_argument("--full-page", action="store_true", help="ページ全体を撮る")
    p_open.add_argument("--text", action="store_true", help="開いた後に本文を出す")
    p_open.add_argument("--selector", help="本文を絞る CSS セレクタ")

    p_shot = sub.add_parser("shot", help="タブを撮影する")
    p_shot.add_argument("path", type=Path)
    p_shot.add_argument("--match", help="対象タブの URL/タイトルの一部")
    p_shot.add_argument("--full-page", action="store_true")

    p_text = sub.add_parser("text", help="タブの本文テキストを出す")
    p_text.add_argument("--match", help="対象タブの URL/タイトルの一部")
    p_text.add_argument("--selector", help="CSS セレクタ（例: article）")
    p_text.add_argument("--limit", type=int, default=4000, help="出力の上限文字数（0 で無制限）")

    p_pdf = sub.add_parser("pdf", help="表示中のページを PDF で保存する")
    p_pdf.add_argument("path", type=Path)
    p_pdf.add_argument("--match", help="対象タブの URL/タイトルの一部")
    p_pdf.add_argument("--paper", default="a4", choices=sorted(PAPER_SIZES), help="用紙サイズ")
    p_pdf.add_argument("--landscape", action="store_true", help="横向きにする")
    p_pdf.add_argument("--no-background", action="store_true", help="背景色・画像を印刷しない")

    p_links = sub.add_parser("links", help="ページ内のリンクを一覧する")
    p_links.add_argument("--match", help="対象タブの URL/タイトルの一部")
    p_links.add_argument("--filter", help="URL か文字に含まれる語で絞る（例: .pdf）")
    p_links.add_argument("--limit", type=int, default=50, help="表示件数（0 で無制限）")

    p_dup = sub.add_parser("dup", help="タブを複製する（既定は別ウィンドウ）")
    p_dup.add_argument("--match", help="対象タブの URL/タイトルの一部")
    p_dup.add_argument("--same-window", action="store_true", help="同じウィンドウに複製する")

    p_close = sub.add_parser("close", help="タブを閉じる")
    p_close.add_argument("--match", required=True, help="対象タブの URL/タイトルの一部")
    p_close.add_argument("--all", action="store_true", help="一致する全てを閉じる")

    return parser


COMMANDS = {
    "list": cmd_list,
    "open": cmd_open,
    "shot": cmd_shot,
    "text": cmd_text,
    "pdf": cmd_pdf,
    "links": cmd_links,
    "dup": cmd_dup,
    "close": cmd_close,
}


def main(argv: list[str] | None = None) -> int:
    use_utf8_stdout()
    args = build_parser().parse_args(argv)

    with sync_playwright() as p:
        try:
            browser = p.chromium.connect_over_cdp(f"http://127.0.0.1:{args.port}")
        except PlaywrightError as exc:
            print(f"{CONNECT_HINT}\n\n詳細: {exc}")
            return 1

        ctx = browser.contexts[0] if browser.contexts else browser.new_context()
        try:
            return COMMANDS[args.command](ctx, args)
        finally:
            # close() は CDP 接続を切るだけ。Chrome は開いたまま残る。
            browser.close()


if __name__ == "__main__":
    raise SystemExit(main())
