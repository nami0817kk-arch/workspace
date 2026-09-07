"""実写の素材（動画・写真）を、内容に合わせて取ってくる。

背景を決め打ちにしない、というユーザーの判断（2026-09-05）。自前で描いた
PNG は模様を足しても所詮は描いた絵で、**実写のほうが強い**（実際に敷いて
確認した）。

取得先は Pexels と Pixabay。どちらも商用利用可・クレジット表示は不要だが、
写真と同じように撮影者を控えて概要欄に出す（義務ではなく礼儀として）。

鍵は環境変数 `PEXELS_API_KEY` / `PIXABAY_API_KEY`。無ければモノレポ内の
`platform/ai-lab/.env` を読む。**鍵を2か所に置かない**ため。
"""

from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass
from pathlib import Path

import requests

TIMEOUT = 40
UA = "youtube-video-creation/1.0"


class StockError(Exception):
    pass


@dataclass
class Clip:
    """取ってきた素材1件。"""

    source: str          # pexels / pixabay
    url: str             # 配布元のページ
    file_url: str        # 実ファイル
    author: str = ""
    width: int = 0
    height: int = 0
    seconds: float = 0.0
    license: str = ""

    def row(self, name: str) -> dict:
        return {
            "file": name, "source": self.source, "title": self.url,
            "page_url": self.url, "image_url": self.file_url,
            "author": self.author, "license": self.license,
        }


def keys() -> dict[str, str]:
    """鍵を集める。環境変数が優先。"""
    found = {k: os.environ.get(k, "").strip() for k in ("PEXELS_API_KEY", "PIXABAY_API_KEY")}
    if all(found.values()):
        return found
    # モノレポ内の ai-lab に置いてある。鍵を2か所に持たない。
    # **worktree には .env が来ない**（gitignore されているため）。
    # 上に辿って見つからなければ、環境変数で渡してもらう。
    here = Path(__file__).resolve()
    for parent in here.parents:
        env = parent / "platform" / "ai-lab" / ".env"
        if not env.exists():
            continue
        for line in env.read_text(encoding="utf-8").splitlines():
            m = re.match(r"^([A-Z0-9_]+)=(.*)$", line.strip())
            if m and m.group(1) in found and not found[m.group(1)]:
                found[m.group(1)] = m.group(2).strip()
        break
    return found


def require_keys() -> dict[str, str]:
    """鍵が無ければ、どうすればよいかを言って止まる。"""
    found = keys()
    if not any(found.values()):
        raise StockError(
            "PEXELS_API_KEY / PIXABAY_API_KEY が見つかりません。"
            "platform/ai-lab/.env にありますが、worktree には来ないので"
            "環境変数で渡してください"
        )
    return found


def search_video(query: str, want_width: int = 1920, limit: int = 15) -> list[Clip]:
    """横向きの動画を探す。Pexels を先に見て、足りなければ Pixabay。"""
    found: list[Clip] = []
    key = require_keys()
    if key.get("PEXELS_API_KEY"):
        found += _pexels_video(query, key["PEXELS_API_KEY"], want_width, limit)
    if len(found) < 3 and key.get("PIXABAY_API_KEY"):
        found += _pixabay_video(query, key["PIXABAY_API_KEY"], want_width, limit)
    if not found:
        raise StockError(f"素材が見つかりません: {query}")
    return found


def _pexels_video(query: str, key: str, want: int, limit: int) -> list[Clip]:
    try:
        r = requests.get("https://api.pexels.com/videos/search",
                         headers={"Authorization": key, "User-Agent": UA},
                         params={"query": query, "per_page": limit,
                                 "orientation": "landscape"}, timeout=TIMEOUT)
        r.raise_for_status()
    except requests.RequestException as error:
        raise StockError(f"Pexels を引けません: {error}") from error
    out: list[Clip] = []
    for v in r.json().get("videos") or []:
        files = [f for f in v.get("video_files") or []
                 if (f.get("file_type") or "").endswith("mp4") and (f.get("width") or 0) >= 1280]
        if not files:
            continue
        best = min(files, key=lambda f: abs((f.get("width") or 0) - want))
        out.append(Clip(source="pexels", url=v.get("url", ""), file_url=best["link"],
                        author=(v.get("user") or {}).get("name", ""),
                        width=best.get("width") or 0, height=best.get("height") or 0,
                        seconds=float(v.get("duration") or 0), license="Pexels License"))
    return out


def _pixabay_video(query: str, key: str, want: int, limit: int) -> list[Clip]:
    try:
        r = requests.get("https://pixabay.com/api/videos/",
                         params={"key": key, "q": query, "per_page": limit,
                                 "safesearch": "true"},
                         headers={"User-Agent": UA}, timeout=TIMEOUT)
        r.raise_for_status()
    except requests.RequestException as error:
        raise StockError(f"Pixabay を引けません: {error}") from error
    out: list[Clip] = []
    for h in r.json().get("hits") or []:
        sizes = [v for v in (h.get("videos") or {}).values() if (v.get("width") or 0) >= 1280]
        if not sizes:
            continue
        best = min(sizes, key=lambda v: abs((v.get("width") or 0) - want))
        out.append(Clip(source="pixabay", url=h.get("pageURL", ""), file_url=best["url"],
                        author=h.get("user", ""), width=best.get("width") or 0,
                        height=best.get("height") or 0,
                        seconds=float(h.get("duration") or 0),
                        license="Pixabay Content License"))
    return out


def pick(clips: list[Clip], seconds: float = 8.0) -> Clip:
    """使う1本を選ぶ。**横向きで、必要な尺があるものを優先する。**

    短すぎるとループが目立つ。長すぎるぶんには切って使えるので構わない。
    """
    landscape = [c for c in clips if c.width >= c.height] or clips
    enough = [c for c in landscape if c.seconds >= seconds] or landscape
    return max(enough, key=lambda c: (c.width, c.seconds))


def fetch(query: str, target: Path, seconds: float = 8.0) -> Clip:
    """探して落として、クレジットを控える。"""
    clip = pick(search_video(query), seconds)
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        body = requests.get(clip.file_url, headers={"User-Agent": UA}, timeout=180).content
    except requests.RequestException as error:
        raise StockError(f"落とせません: {error}") from error
    target.write_bytes(body)
    trim(target, seconds)
    _record(target, clip)
    return clip


# 落としたクリップを残す長さ。背景は節ごとに20秒ほどしか映らないので、
# 元の尺（実測で30〜120秒）をそのまま置くと重いだけ。
# 2026-09-07 に 120秒576MB の素材を掴み、書き出しが1分から4分21秒に伸びた。
KEEP_SECONDS = 30.0


def trim(target: Path, seconds: float) -> bool:
    """頭から必要なぶんだけ残す。作り直さず、入れ物を詰め替えるだけ。

    再エンコードすると時間がかかるうえ画質も落ちるので、ストリームは複製する。
    失敗したら元のまま残す（背景が無くなるより重いほうがまし）。
    """
    keep = max(float(seconds), KEEP_SECONDS)
    try:
        import imageio_ffmpeg

        ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return False

    import subprocess

    short = target.with_suffix(".trim.mp4")
    try:
        result = subprocess.run(
            [ffmpeg, "-y", "-loglevel", "error", "-t", str(keep), "-i", str(target),
             "-c", "copy", "-movflags", "+faststart", str(short)],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300,
        )
    except (OSError, subprocess.SubprocessError):
        short.unlink(missing_ok=True)
        return False
    if result.returncode != 0 or not short.exists() or short.stat().st_size == 0:
        short.unlink(missing_ok=True)
        return False
    short.replace(target)
    return True


def _record(target: Path, clip: Clip) -> None:
    """同じフォルダの credits.json に足す。写真と同じ形にそろえる。"""
    ledger = target.parent / "credits.json"
    rows = []
    if ledger.exists():
        try:
            rows = json.loads(ledger.read_text(encoding="utf-8"))
        except ValueError:
            rows = []
    rows = [r for r in rows if r.get("file") != target.name]
    rows.append(clip.row(target.name))
    ledger.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
