"""素材のダウンロードとクレジット（出典表記）ファイルの生成。

どのコネクタで見つけた素材でも扱えるよう、core.types.Asset だけに依存する。
"""

from __future__ import annotations

import json
from concurrent.futures import ThreadPoolExecutor
from itertools import zip_longest
from pathlib import Path

from .core.errors import ConfigError
from .core.http import request
from .core.types import Asset
from .utils import extension_for, slugify

CREDITS_JSON = "credits.json"
CREDITS_MD = "CREDITS.md"


def _extension(url: str, content_type: str) -> str:
    for ext in (".png", ".jpg", ".jpeg", ".svg", ".gif", ".webp"):
        if url.lower().split("?")[0].endswith(ext):
            return ext
    return extension_for(content_type, default=".jpg")


def download(asset: Asset, dest_dir: str | Path, *, timeout: int = 60, sess=None) -> Path:
    """素材1点をダウンロードして保存先パスを返す。"""
    if not asset.image_url:
        raise ConfigError(f"画像URLがありません: {asset.title}")

    directory = Path(dest_dir)
    directory.mkdir(parents=True, exist_ok=True)

    response = request("GET", asset.image_url, sess=sess, label=asset.source, timeout=timeout)

    _notify_source(asset)

    ext = _extension(asset.image_url, response.headers.get("Content-Type", ""))
    name = "_".join(
        part for part in (asset.source, asset.source_id, slugify(asset.title, 30)) if part
    )
    path = directory / f"{name}{ext}"
    path.write_bytes(response.content)
    return path


def _notify_source(asset: Asset) -> None:
    """取得元が通知を求めている場合に知らせる（Unsplash のダウンロード計測など）。

    通知に失敗しても素材の取得自体は成功させる。
    """
    from .core import registry
    from .core.errors import AilabError

    try:
        connector = registry.get(asset.source)
    except AilabError:
        return
    hook = getattr(connector, "notify_download", None)
    if hook is None:
        return
    try:
        hook(asset)
    except AilabError:
        pass


def grab(
    url: str,
    dest_dir: str | Path,
    *,
    page_url: str = "",
    license: str = "unknown",
    creator: str = "",
    title: str = "",
    timeout: int = 60,
    sess=None,
) -> tuple[Asset, Path]:
    """画像のURLを直接指定して取り込み、クレジットにも残す。

    自分でサイトを見て見つけた画像を、出典を書き添えて手元に置くための入口。
    ページのHTMLを解析して画像を探すことはしない（規約上の問題があるため）。
    """
    from urllib.parse import urlparse

    if not url.startswith(("http://", "https://")):
        raise ConfigError(f"画像のURLを指定してください: {url!r}")

    host = urlparse(url).netloc or "web"
    asset = Asset(
        source=host,
        title=title or Path(urlparse(url).path).stem or host,
        image_url=url,
        page_url=page_url,
        license=license,
        creator=creator,
    )

    response = request("GET", url, sess=sess, label=host, timeout=timeout)
    content_type = response.headers.get("Content-Type", "").split(";")[0].strip().lower()
    if content_type and not content_type.startswith("image/"):
        raise ConfigError(
            f"画像ではありません（{content_type}）。"
            "ページのURLではなく、画像そのもののURLを指定してください"
        )

    directory = Path(dest_dir)
    directory.mkdir(parents=True, exist_ok=True)
    ext = _extension(url, content_type)
    path = directory / f"{slugify(host, 20)}_{slugify(asset.title, 30)}{ext}"
    path.write_bytes(response.content)

    write_credits([(asset, path)], directory)
    return asset, path


def download_all(
    assets: list[Asset], dest_dir: str | Path, *, timeout: int = 60, sess=None
) -> list[tuple[Asset, Path]]:
    """複数の素材をまとめて取得し、クレジットファイルも更新する。

    取得先が別サイトなので並列に落とす。順序は入力どおりに保つ。
    """
    if not assets:
        return []

    def fetch(asset: Asset) -> tuple[Asset, Path]:
        return asset, download(asset, dest_dir, timeout=timeout, sess=sess)

    if len(assets) == 1 or sess is not None:
        # セッションを共有している場合（テストなど）は直列にする
        saved = [fetch(asset) for asset in assets]
    else:
        with ThreadPoolExecutor(max_workers=min(len(assets), max_workers())) as pool:
            saved = list(pool.map(fetch, assets))

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


def max_workers() -> int:
    """横断検索・一括ダウンロードの並列数（AILAB_MAX_WORKERS で変更可）。"""
    from .config import get_env

    try:
        return max(1, int(get_env("AILAB_MAX_WORKERS") or 4))
    except ValueError:
        return 4


def search(query: str, *, source: str = "all", limit: int = 10, **kwargs) -> list[Asset]:
    """素材を検索する。source='all' なら使える全コネクタを横断する。

    横断時は各サイトへ並列に問い合わせる（直列だと遅いサイトに引きずられるため）。
    結果の順序はコネクタの優先順位で安定させる。
    """
    from .core import registry
    from .core.errors import ConnectorError

    if source != "all":
        connector = registry.get(source, **kwargs)
        if not hasattr(connector, "search_assets"):
            raise ConfigError(f"{source} は素材検索に対応していません")
        return connector.search_assets(query, limit=limit)

    connectors = registry.by_capability("search_assets", available_only=True, **kwargs)
    if not connectors:
        return []

    def run(connector):
        try:
            return connector.search_assets(query, limit=limit), None
        except ConnectorError as exc:  # 1サイト落ちても他は返す
            return [], f"{connector.name}: {exc}"

    if len(connectors) == 1:
        results = [run(connectors[0])]
    else:
        with ThreadPoolExecutor(max_workers=min(len(connectors), max_workers())) as pool:
            results = list(pool.map(run, connectors))

    groups: list[list[Asset]] = []
    errors: list[str] = []
    for items, error in results:  # 優先順位どおりの並びを保つ
        if items:
            groups.append(items)
        if error:
            errors.append(error)

    if not groups and errors:
        raise ConnectorError(" / ".join(errors))
    return deduplicate(interleave(groups))


def interleave(groups: list[list[Asset]]) -> list[Asset]:
    """サイトごとの結果を1件ずつ交互に並べる。

    連結すると先頭のサイトだけで上位が埋まり、-l で絞ったときに
    他のサイトの結果が1件も見えなくなるため。
    """
    merged: list[Asset] = []
    for row in zip_longest(*groups):
        merged.extend(asset for asset in row if asset is not None)
    return merged


def deduplicate(found: list[Asset]) -> list[Asset]:
    """同じ素材を1件にまとめる（先に来たものを残す）。

    Openverse は Wikimedia の作品も返すので、横断すると同じ画像が重複する。
    """
    seen: set[str] = set()
    unique: list[Asset] = []
    for asset in found:
        key = (asset.image_url or asset.page_url or "").split("?")[0].lower()
        if key and key in seen:
            continue
        if key:
            seen.add(key)
        unique.append(asset)
    return unique
