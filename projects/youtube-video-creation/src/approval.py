"""台本の確認が済んだかを控える（2026-09-11）。

ユーザー指示「**どんな時も台本確認は必須です**」。
それまでも「台本のOKが出てから書き出す」決まりはあったが、
**人の注意に頼っていたので抜けた。**9/11 にマンUと中村敬斗の回を、
台本を見せないまま書き出し、片方は公開予約まで入れた。

`build` と `short` は、この控えに無い台本を書き出さない。
控えに足すのは `approve <台本>` で、**ユーザーのOKを聞いたときだけ**打つ。
"""

from __future__ import annotations

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


def is_approved(script: str | Path, path: Path = LEDGER) -> bool:
    return key_of(script) in _load(path)


def approved_at(script: str | Path, path: Path = LEDGER) -> str:
    return str(_load(path).get(key_of(script), ""))


def approve(script: str | Path, path: Path = LEDGER, now=None) -> str:
    """OKが出たことを控える。**聞いていないのに打たない。**"""
    stamp = (now or datetime.now(JST)).isoformat(timespec="seconds")
    ledger = _load(path)
    ledger[key_of(script)] = stamp
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(ledger, ensure_ascii=False, indent=1),
                    encoding="utf-8")
    return stamp


def refusal(script: str | Path) -> str:
    return (f"『{key_of(script)}』は台本の確認が済んでいません。"
            "**どんな時も台本確認は必須です**（2026-09-11 ユーザー指示）。"
            "確認ページを見せて、OKをもらってから "
            f"`python -m src.cli approve {script}` を打ってください")
