"""台本の確認が済んだかを控える（2026-09-11）。

ユーザー指示「**どんな時も台本確認は必須です**」。
それまでも「台本のOKが出てから書き出す」決まりはあったが、
**人の注意に頼っていたので抜けた。**9/11 にマンUと中村敬斗の回を、
台本を見せないまま書き出し、片方は公開予約まで入れた。

`build` と `short` は、この控えに無い台本を書き出さない。
控えに足すのは `approve <台本>` で、**ユーザーのOKを聞いたときだけ**打つ。

**控えは中身まで見る**（2026-09-11 に足した）。名前だけで持っていたので、
**OKをもらったあとに台本を直すと、そのまま書き出せてしまった。**
実際、伊藤涼太郎の回で「まとめサイトの」という一行を直したあとも素通りした。
直したら、もう一度見せて OK をもらう。
"""

from __future__ import annotations

import hashlib
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

LEDGER = Path("research/approved.json")
JST = timezone(timedelta(hours=9))


def _load(path: Path = LEDGER) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, OSError):
        return {}


def key_of(script: str | Path) -> str:
    """台本の名前。置き場所が変わっても同じ鍵になるよう、拡張子なしの名前で持つ。"""
    return Path(script).stem


def digest_of(script: str | Path) -> str:
    """台本の中身の印。読めなければ空（読めない台本は書き出しでどのみち止まる）。"""
    try:
        raw = Path(script).read_bytes()
    except OSError:
        return ""
    return hashlib.sha256(raw).hexdigest()[:16]


def _entry(script: str | Path, path: Path) -> dict:
    got = _load(path).get(key_of(script))
    if isinstance(got, dict):
        return got
    if isinstance(got, str):          # 中身を持つ前の控え
        return {"at": got, "digest": ""}
    return {}


def is_approved(script: str | Path, path: Path = LEDGER) -> bool:
    """名前があるだけでは足りない。**OKをもらった中身と同じかまで見る。**"""
    got = _entry(script, path)
    if not got:
        return False
    # **中身の印が無い控えは通さない。**印を持つ前の古い控えは、
    # もう一度見せて OK をもらい直す。迷ったら聞く側に倒す。
    return bool(got.get("digest")) and got["digest"] == digest_of(script)


def changed_since_approval(script: str | Path, path: Path = LEDGER) -> bool:
    """控えはあるが、中身が変わっている（印の無い古い控えも含む）。"""
    got = _entry(script, path)
    return bool(got) and got.get("digest", "") != digest_of(script)


def approved_at(script: str | Path, path: Path = LEDGER) -> str:
    return str(_entry(script, path).get("at", ""))


def approve(script: str | Path, path: Path = LEDGER, now=None) -> str:
    """OKが出たことを控える。**聞いていないのに打たない。**"""
    stamp = (now or datetime.now(JST)).isoformat(timespec="seconds")
    ledger = _load(path)
    ledger[key_of(script)] = {"at": stamp, "digest": digest_of(script)}
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(ledger, ensure_ascii=False, indent=1),
                    encoding="utf-8")
    return stamp


def refusal(script: str | Path, path: Path = LEDGER) -> str:
    if changed_since_approval(script, path):
        return (f"『{key_of(script)}』は OK をもらったあとに**中身が変わっています**"
                f"（控えは {approved_at(script, path)}）。"
                "**どんな時も台本確認は必須です**（2026-09-11 ユーザー指示）。"
                "直したところを見せて、もう一度 OK をもらってから "
                f"`python -m src.cli approve {script}` を打ってください")
    return (f"『{key_of(script)}』は台本の確認が済んでいません。"
            "**どんな時も台本確認は必須です**（2026-09-11 ユーザー指示）。"
            "確認ページを見せて、OKをもらってから "
            f"`python -m src.cli approve {script}` を打ってください")
