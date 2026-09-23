"""生成物のリンク切れを見る。

ページが階層に散らばっている（`/`, `/archive/<種別>/`, `/weekly/`）ので、
テンプレートで base_url を付け忘れると、その階層だけリンクが死ぬ。
目で見て回れる数ではないため、ここで機械に歩かせる。
"""
import json
import re
from pathlib import Path

import pytest

import render

_HREF = re.compile(r'(?:href|src)="([^"]+)"')
# 検索ページは JS で href を組み立てる。その文字列まで拾うと偽の警告になる。
_SCRIPT = re.compile(r"<script\b.*?</script>", re.S | re.I)


@pytest.fixture(scope="module")
def built(tmp_path_factory):
    tmp_path = tmp_path_factory.mktemp("site")
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    # 週をまたぐ数日分（週まとめの前後ナビも張られる状態にする）
    for rec_date in ("2026-09-14", "2026-09-15", "2026-09-18", "2026-09-24"):
        payload = {
            "rec_date": rec_date,
            "gainers": [{"rank": i + 1, "code": f"{7200 + i}", "name": f"銘柄{i}",
                         "close": 900.0, "change_pct": 12.0 - i, "metric_value": 500}
                        for i in range(3)],
            "losers": [{"rank": 1, "code": "6501", "name": "下落銘柄",
                        "close": 500.0, "change_pct": -8.0, "metric_value": 200}],
            "active": [{"rank": 1, "code": "7203", "name": "活況銘柄",
                        "close": 2500.0, "change_pct": 1.0, "metric_value": 9999}],
        }
        (data_dir / f"{rec_date}.json").write_text(
            json.dumps(payload, ensure_ascii=False), encoding="utf-8"
        )

    out_dir = tmp_path / "output"
    orig = (render._DATA_DIR, render._OUTPUT_DIR, render._ROOT)
    render._DATA_DIR, render._OUTPUT_DIR, render._ROOT = data_dir, out_dir, tmp_path
    try:
        render.build_all()
        yield out_dir
    finally:
        render._DATA_DIR, render._OUTPUT_DIR, render._ROOT = orig


def _local_targets(page: Path, out_dir: Path):
    html = _SCRIPT.sub("", page.read_text(encoding="utf-8"))
    for raw in _HREF.findall(html):
        if raw.startswith(("http://", "https://", "mailto:", "#", "data:")):
            continue
        target = raw.split("#", 1)[0].split("?", 1)[0]
        if not target:
            continue
        base = out_dir if target.startswith("/") else page.parent
        yield raw, (base / target.lstrip("/")).resolve()


def test_ページ内のリンクが全て存在する(built):
    missing = []
    for page in sorted(built.rglob("*.html")):
        for raw, target in _local_targets(page, built):
            if not target.exists():
                missing.append(f"{page.relative_to(built)} -> {raw}")
    assert not missing, "リンク切れ:\n" + "\n".join(missing)


def test_全てのページに辿り着ける(built):
    """トップから辿れないページを作らない（検索エンジンにも読者にも届かない）。"""
    start = built / "index.html"
    seen = {start.resolve()}
    queue = [start]
    while queue:
        page = queue.pop()
        for _raw, target in _local_targets(page, built):
            if target.suffix == ".html" and target.exists() and target not in seen:
                seen.add(target)
                queue.append(target)

    orphans = {p.resolve() for p in built.rglob("*.html")} - seen
    # 404 はリンクを張る対象ではない（存在しないURLに対して返るページ）
    orphans.discard((built / "404.html").resolve())
    assert not orphans, "トップから辿り着けないページ: " + ", ".join(
        str(p.relative_to(built)) for p in sorted(orphans)
    )
