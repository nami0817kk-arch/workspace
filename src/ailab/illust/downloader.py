"""素材のダウンロードとクレジット（出典表記）ファイルの生成。"""

from __future__ import annotations

import json
import mimetypes
from pathlib import Path

from ..http import error_detail, session
from ..utils import slugify
from .base import IllustItem, SourceError

CREDITS_JSON = "credits.json"
CREDITS_MD = "CREDITS.md"


def _extension(url: str, content_type: str) -> str:
    for ext in (".png", ".jpg", ".jpeg", ".svg", ".gif", ".webp"):
        if url.lower().split("?")[0].endswith(ext):
            return ext
    return mimetypes.guess_extension(content_type.split(";")[0].strip()) or ".jpg"


def download(item: IllustItem, dest_dir: str | Path, *, timeout: int = 60) -> Path:
    """素材1点をダウンロードして保存先パスを返す。"""
    if not item.image_url:
        raise SourceError(f"画像URLがありません: {item.title}")

    directory = Path(dest_dir)
    directory.mkdir(parents=True, exist_ok=True)

    response = session().get(item.image_url, timeout=timeout)
    if not response.ok:
        raise SourceError(f"ダウンロードに失敗しました ({error_detail(response)})")

    ext = _extension(item.image_url, response.headers.get("Content-Type", ""))
    name = "_".join(part for part in (item.source, item.source_id, slugify(item.title, 30)) if part)
    path = directory / f"{name}{ext}"
    path.write_bytes(response.content)
    return path


def download_all(
    items: list[IllustItem], dest_dir: str | Path, *, timeout: int = 60
) -> list[tuple[IllustItem, Path]]:
    """複数の素材をまとめて取得し、クレジットファイルも更新する。"""
    saved: list[tuple[IllustItem, Path]] = []
    for item in items:
        saved.append((item, download(item, dest_dir, timeout=timeout)))
    if saved:
        write_credits(saved, dest_dir)
    return saved


def write_credits(saved: list[tuple[IllustItem, Path]], dest_dir: str | Path) -> tuple[Path, Path]:
    """credits.json と CREDITS.md を追記更新する。

    ライセンス表記が必要な素材のために、必ず出典を残しておくのが目的。
    """
    directory = Path(dest_dir)
    directory.mkdir(parents=True, exist_ok=True)
    json_path = directory / CREDITS_JSON
    md_path = directory / CREDITS_MD

    records: list[dict] = []
    if json_path.is_file():
        try:
            existing = json.loads(json_path.read_text(encoding="utf-8"))
            if isinstance(existing, list):
                records = existing
        except json.JSONDecodeError:
            records = []

    known = {record.get("file") for record in records}
    for item, path in saved:
        record = item.to_dict()
        record["file"] = path.name
        if record["file"] not in known:
            records.append(record)
            known.add(record["file"])

    json_path.write_text(
        json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    lines = [
        "# 素材クレジット",
        "",
        "このフォルダの画像の出典とライセンスです。",
        "利用条件は各ライセンスに従ってください（CC BY 系は表示が必須）。",
        "",
        "| ファイル | タイトル | 作者 | ライセンス | 出典 |",
        "| --- | --- | --- | --- | --- |",
    ]
    for record in records:
        license_cell = record.get("license", "")
        if record.get("license_url"):
            license_cell = f"[{license_cell}]({record['license_url']})"
        page = record.get("page_url") or ""
        lines.append(
            "| {file} | {title} | {creator} | {license} | {page} |".format(
                file=record.get("file", ""),
                title=(record.get("title") or "").replace("|", "/"),
                creator=(record.get("creator") or "").replace("|", "/"),
                license=license_cell,
                page=f"[link]({page})" if page else "",
            )
        )
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return json_path, md_path
