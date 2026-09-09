"""公開と同時に、自分の最初のコメントを書く（2026-09-08）。

Gemini の答え（docs/gemini_answer_20260908.txt の1）。動画の中で「登録して」と
言うより、コメント欄に問いを置いて議論に誘うほうが効く。コメント欄が動くと
アルゴリズムが動画を押す。

**固定（ピン留め）は API にない。**書き込みまでを自動にし、固定は Studio で行う。
文面は毎回変える（結びを決め打ちにすると、それ自体が定型になる）。
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from . import quota

# 問いのあとに付ける誘い。同じ動画には同じものが選ばれ、動画が変われば変わる
INVITES = (
    "「納得」なら高評価、「それは違う」ならコメントで教えてください。",
    "同じ意見なら高評価、別の見方があればコメントで聞かせてください。",
    "賛成なら高評価を、反対ならその理由をコメントに。",
    "そう思うなら高評価、そうでないならコメントで反論を。",
    "納得したら高評価、引っかかったところはコメントで。",
)
MAX_LENGTH = 200


class CommentError(RuntimeError):
    pass


def _question(build_dir: Path) -> str:
    """概要欄の「この動画が答える問い」を拾う。無ければ空。"""
    path = build_dir / "description.txt"
    if not path.exists():
        return ""
    for line in path.read_text(encoding="utf-8").splitlines():
        head, sep, tail = line.partition("この動画が答える問い:")
        if sep:
            return tail.strip()
    return ""


def _title(build_dir: Path) -> str:
    path = build_dir / "script.json"
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if data.get("title"):
                return str(data["title"]).strip()
        except (OSError, ValueError):
            pass
    desc = build_dir / "description.txt"
    if desc.exists():
        first = desc.read_text(encoding="utf-8").splitlines()
        if first:
            return first[0].strip()
    return ""


def compose(build_dir: Path, choices: tuple[str, str] | None = None) -> str:
    """その動画の最初のコメント。問い＋誘い。

    問いがあれば「〜、皆さんはどう見ますか？」と投げ、無ければタイトルから作る。
    """
    build_dir = Path(build_dir)
    title = _title(build_dir)
    question = _question(build_dir)
    if not title and not question:
        raise CommentError(f"題名も問いもありません: {build_dir}")
    if question:
        ask = re.sub(r"[。？?]+$", "", question)
        lead = f"{ask}――皆さんはどう見ますか？"
    else:
        ask = re.sub(r"[。？?]+$", "", title)
        lead = f"「{ask}」、皆さんはどう思いますか？"
    pick = int(hashlib.sha1((title or question).encode("utf-8")).hexdigest(), 16)
    if choices and all(str(c).strip() for c in choices):
        # **具体的な二択にする**（2026-09-09）。12本に書いて返信ゼロだったのは、
        # 「納得なら高評価」が動画ごとに同じで、答えようが無かったから。
        left, right = (str(c).strip() for c in choices)
        tail = f"「{left}」なら高評価、「{right}」ならコメントで教えてください。"
    else:
        tail = INVITES[pick % len(INVITES)]
    text = lead + " " + tail
    if len(text) > MAX_LENGTH:
        text = text[:MAX_LENGTH - 1] + "…"
    return text


def post(service, video_id: str, text: str) -> str:
    """動画にチャンネルのコメントを1件書く。コメントの id を返す。"""
    if not text.strip():
        raise CommentError("コメントが空です")
    body = {
        "snippet": {
            "videoId": video_id,
            "topLevelComment": {"snippet": {"textOriginal": text}},
        }
    }
    got = service.commentThreads().insert(part="snippet", body=body).execute()
    return str(got.get("id") or "")
