"""手で投稿するときの受け渡し。

API の1日枠（既定10,000、動画1本で約1,650）を超えたぶんは、Studio から
手で上げることになる（2026-09-05 ユーザー判断）。そのとき**何をどこに
貼るのかを毎回思い出す**のは無駄なので、1枚にまとめて置く。

貼る内容は build が既に書き出している。ここでやるのは、それを投稿画面の
順番に並べ直すことだけ。**新しい情報は作らない。**
"""

from __future__ import annotations

import json
from pathlib import Path


class HandoffError(Exception):
    pass


def build_sheet(out_dir: Path) -> str:
    """投稿画面に貼る順に並べた手順書。"""
    need = ("video.mp4", "thumbnail.png", "description.txt", "subtitles.srt")
    missing = [n for n in need if not (out_dir / n).exists()]
    if missing:
        raise HandoffError(f"足りないファイルがあります: {', '.join(missing)}")

    script_json = out_dir / "script.json"
    data = json.loads(script_json.read_text(encoding="utf-8")) if script_json.exists() else {}
    title = str(data.get("title") or out_dir.name)
    tags = [str(t) for t in (data.get("tags") or [])]
    description = (out_dir / "description.txt").read_text(encoding="utf-8").rstrip()

    lines: list[str] = []
    add = lines.append
    add(f"# 手で投稿する手順　{out_dir.name}")
    add("")
    add("YouTube Studio → 作成 → 動画をアップロード。上から順に貼る。")
    add("")
    add("-" * 60)
    add("【1】動画ファイル")
    add(f"  {(out_dir / 'video.mp4').resolve()}")
    add("")
    add("【2】タイトル（そのまま貼る）")
    add(f"  {title}")
    add("")
    add("【3】説明（次の行から --- までを貼る）")
    add("")
    add(description)
    add("---")
    add("")
    add("【4】サムネイル")
    add(f"  {(out_dir / 'thumbnail.png').resolve()}")
    add("  ※「サムネイルをアップロード」から選ぶ")
    add("")
    add("【5】タグ（詳細設定の中。カンマ区切りでそのまま貼る）")
    add("  " + ", ".join(tags) if tags else "  （なし）")
    add("")
    add("【6】字幕")
    add(f"  {(out_dir / 'subtitles.srt').resolve()}")
    add("  ※ 字幕 → 追加 → ファイルをアップロード → 「タイミング付き」を選ぶ")
    add("")
    add("【7】公開設定")
    add("  最初は「非公開」で上げ、再生して確認してから公開に切り替える")
    add("")
    add("-" * 60)
    add("チャプターは説明の中に入っている（0:00 から始まる行）。")
    add("説明を貼れば自動で付くので、別の操作は要らない。")
    return "\n".join(lines) + "\n"


def write_sheet(out_dir: Path) -> Path:
    target = out_dir / "投稿手順.txt"
    target.write_text(build_sheet(out_dir), encoding="utf-8")
    return target
