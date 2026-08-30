"""素材のダウンロードとクレジット（出典表記）ファイルの生成。

どのコネクタで見つけた素材でも扱えるよう、core.types.Asset だけに依存する。
"""

from __future__ import annotations

import json
import mimetypes
from pathlib import Path

from .core.errors import ConfigError
from .core.http import request
from .core.types import Asset
from .utils import slugify

CREDITS_JSON = "credits.json"
CREDITS_MD = "CREDITS.md"


def _extension(url: str, content_type: str) -> str:
    for ext in (".png", ".jpg", ".jpeg", ".svg", ".gif", ".webp"):
        if url.lower().split("?")[0].endswith(ext):
            return ext
    return mimetypes.guess_extension(content_type.split(";")[0].strip()) or ".jpg"


def download(asset: Asset, dest_dir: str | Path, *, timeout: int = 60, sess=None) -> Path:
    """素材1点をダウンロードして保存先パスを返す。"""
    if not asset.image_url:
        raise ConfigError(f"画像URLがありません: {asset.title}")

    directory = Path(dest_dir)
    directory.mkdir(parents=True, exist_ok=True)

    response = request("GET", asset.image_url, sess=sess, label=asset.source, timeout=timeout)

    ext = _extension(asset.image_url, response.headers.get("Content-Type", ""))
    name = "_".join(
        part for part in (asset.source, asset.source_id, slugify(asset.title, 30)) if part
    )
    path = directory / f"{name}{ext}"
    path.write_bytes(response.content)
    return path


def download_all(
    assets: list[Asset], dest_dir: str | Path, *, timeout: int = 60, sess=None
) -> list[tuple[Asset, Path]]:
    """複数の素材をまとめて取得し、クレジットファイルも更新する。"""
    saved: list[tuple[Asset, Path]] = []
    for asset in assets:
        saved.append((asset, download(asset, dest_dir, timeout=timeout, sess=sess)))
    if saved:
        write_credits(saved, dest_dir)
    return saved


def write_credits(saved: list[tuple[Asset, Path]], dest_dir: str | Path) -> tuple[Path, Path]:
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
    for asset, path in saved:
        record = asset.to_dict()
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


def search(query: str, *, source: str = "all", limit: int = 10, **kwargs) -> list[Asset]:
    """素材を検索する。source='all' なら使える全コネクタを横断する。"""
    from .core import registry
    from .core.errors import ConnectorError

    if source != "all":
        connector = registry.get(source, **kwargs)
        if not hasattr(connector, "search_assets"):
            raise ConfigError(f"{source} は素材検索に対応していません")
        return connector.search_assets(query, limit=limit)

    found: list[Asset] = []
    errors: list[str] = []
    for connector in registry.by_capability("search_assets", available_only=True, **kwargs):
        try:
            found.extend(connector.search_assets(query, limit=limit))
        except ConnectorError as exc:  # 1サイト落ちても他は返す
            errors.append(f"{connector.name}: {exc}")
    if not found and errors:
        raise ConnectorError(" / ".join(errors))
    return found
