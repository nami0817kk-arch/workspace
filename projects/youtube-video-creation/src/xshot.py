"""X の投稿そのものを1枚の画像として取る。**有名人の投稿だけ。**

2026-09-08 にユーザーが「有名人の投稿は許可します」と判断した。それまでは
SNS の投稿画像を一切使わない方針だった（2026-09-02）。理由は2つあって、
**片方だけが解けている**ことを忘れないために書いておく。

  1. **他人の著作物である。**投稿の文も、貼られた写真も、書いた人のもの。
     静止画は Content ID の対象外なので自動検出はされないが、削除要請が来れば
     著作権の警告が付き、3回でアカウントごと止まる。
     → **この危険はユーザーが引き受けると決めた。**引用の体裁（出典を明示し、
       必要な長さに留め、本編の主役にしない）は守る
  2. **@ハンドルが画面に写る。**匿名の一般人については「@ハンドルを画面に
     出さない」という決まりがあり、**これは解けていない。**
     → だから**誰の投稿でもよいわけではない。**`config/sources.yaml` の
       `accounts:` に載っている人だけを通す。記者・クラブ公式・選手など、
       公の場で発言している人。載っていなければ止める（人が足す）

    python -m src.cli xshot https://x.com/FabrizioRomano/status/… assets/posts/romano

取った画像は台本の `image:` に指定する。出典は `sources:` に投稿URLを入れる
（`review` の「投稿の出典」が突き合わせる）。
"""

from __future__ import annotations

import json
import re
from pathlib import Path

STATUS = re.compile(r"^https?://(?:www\.)?(?:x|twitter)\.com/([^/]+)/status/(\d+)")
PORT = 9222


class ShotError(Exception):
    pass


def parse(url: str) -> tuple[str, str]:
    """投稿URLから handle と ID を取り出す。"""
    match = STATUS.match((url or "").strip())
    if not match:
        raise ShotError(f"投稿のURLではありません: {url}")
    return match.group(1), match.group(2)


def allowed(handle: str, accounts: list[dict]) -> dict | None:
    """`accounts:` に載っている人か。**載っていない人は撮らない。**"""
    wanted = handle.strip().lstrip("@").lower()
    for row in accounts or []:
        if str(row.get("handle", "")).strip().lstrip("@").lower() == wanted:
            return dict(row)
    return None


def capture(url: str, folder: Path, accounts: list[dict], port: int = PORT) -> dict:
    """投稿を1枚の画像にして、出どころを控える。

    手元の Chrome（リモートデバッグ）にぶら下がって撮る。**ログイン操作はしない。**
    """
    handle, post_id = parse(url)
    row = allowed(handle, accounts)
    if row is None:
        raise ShotError(
            f"@{handle} は accounts: に載っていません。"
            "**有名人の投稿だけ**を使う決まりです（2026-09-08）。"
            "公の場で発言している人なら config/sources.yaml の accounts: に足してください"
        )

    try:
        from playwright.sync_api import sync_playwright
    except ImportError as error:      # pragma: no cover - 環境依存
        raise ShotError("playwright がありません") from error

    folder.mkdir(parents=True, exist_ok=True)
    target = folder / f"{handle}_{post_id}.png"
    with sync_playwright() as play:
        try:
            browser = play.chromium.connect_over_cdp(f"http://127.0.0.1:{port}")
        except Exception as error:      # pragma: no cover - 環境依存
            raise ShotError(
                "リモートデバッグの Chrome に繋げません。"
                "scripts/start-chrome-debug.ps1 で起動してください"
            ) from error
        context = browser.contexts[0]
        page = context.new_page()
        try:
            page.goto(url, wait_until="domcontentloaded", timeout=60_000)
            page.wait_for_timeout(4000)
            article = page.locator("article").first
            if article.count() == 0:
                raise ShotError("投稿が見つかりません（ログイン壁の可能性）")
            article.screenshot(path=str(target))
        finally:
            page.close()

    entry = {
        "file": target.name,
        "source": "x",
        "title": f"@{handle} の投稿",
        "page_url": url,
        "author": f"@{handle}",
        # **CC ではない。**引用として使う。出典を必ず概要欄に出す
        "license": "引用（出典明記）",
        "no_derivatives": True,     # 切って文字を重ねない。サムネには使わない
        "subject_check": f"accounts: に登録済み（{row.get('name', '')}）",
    }
    ledger = folder / "credits.json"
    rows = []
    if ledger.exists():
        try:
            rows = json.loads(ledger.read_text(encoding="utf-8"))
        except ValueError:
            rows = []
    rows = [r for r in rows if r.get("file") != target.name] + [entry]
    ledger.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    return entry
