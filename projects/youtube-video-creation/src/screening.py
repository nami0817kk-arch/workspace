"""出来上がった動画を見せたかを控える（2026-09-13）。

ユーザー指示「**今後は投稿する前に動画見して**」。

台本の確認（`approval`）は通っていても、**画面に何が映るかは台本に書いていない。**
下地・写真・テロップの重なりは書き出してみるまで分からない。実際、
9/13 に公開したショートは**開いた瞬間が玉ぼけの抽象画**で、人もピッチも
写っていなかった。台本はどれも確認済みだった。

`upload` は、この控えに無い動画を投げない。
控えに足すのは `screen <出力先>` で、**実物を見せて OK を聞いたときだけ**打つ。

**控えは中身まで見る。**動画を作り直したら印が変わるので、もう一度見せる。
`approval` と同じ作りにしてある（名前だけの控えは、直したあとに素通りする）。
"""

from __future__ import annotations

import hashlib
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

LEDGER = Path("research/screened.json")
JST = timezone(timedelta(hours=9))

# 見せる対象。出力先の中のこのファイルを見てもらう
VIDEO = "video.mp4"


def _load(path: Path = LEDGER) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, OSError):
        return {}


def key_of(build_dir: str | Path) -> str:
    """出力先の名前。置き場所が変わっても同じ鍵になるよう、末尾の名前で持つ。"""
    return Path(build_dir).name


def video_of(build_dir: str | Path) -> Path:
    return Path(build_dir) / VIDEO


def digest_of(build_dir: str | Path) -> str:
    """動画の中身の印。**先頭だけでは足りない**ので全部を読む。

    無ければ空。無い動画は投稿でどのみち止まる。
    """
    path = video_of(build_dir)
    try:
        sha = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                sha.update(chunk)
        return sha.hexdigest()[:16]
    except OSError:
        return ""


def _entry(build_dir: str | Path, path: Path) -> dict:
    got = _load(path).get(key_of(build_dir))
    return got if isinstance(got, dict) else {}


def is_screened(build_dir: str | Path, path: Path = LEDGER) -> bool:
    """名前があるだけでは足りない。**見せた中身と同じかまで見る。**"""
    got = _entry(build_dir, path)
    if not got:
        return False
    return bool(got.get("digest")) and got["digest"] == digest_of(build_dir)


def changed_since_screening(build_dir: str | Path, path: Path = LEDGER) -> bool:
    """控えはあるが、動画が作り直されている。"""
    got = _entry(build_dir, path)
    return bool(got) and got.get("digest", "") != digest_of(build_dir)


def screened_at(build_dir: str | Path, path: Path = LEDGER) -> str:
    return str(_entry(build_dir, path).get("at", ""))


def screen(build_dir: str | Path, path: Path = LEDGER, now=None) -> str:
    """見せて OK が出たことを控える。**見せていないのに打たない。**"""
    stamp = (now or datetime.now(JST)).isoformat(timespec="seconds")
    ledger = _load(path)
    ledger[key_of(build_dir)] = {"at": stamp, "digest": digest_of(build_dir)}
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(ledger, ensure_ascii=False, indent=1),
                    encoding="utf-8")
    return stamp


def refusal(build_dir: str | Path, path: Path = LEDGER) -> str:
    name = key_of(build_dir)
    if changed_since_screening(build_dir, path):
        return (f"『{name}』は見せたあとに**動画を作り直しています**"
                f"（控えは {screened_at(build_dir, path)}）。"
                "**投稿する前に動画を見せます**（2026-09-13 ユーザー指示）。"
                "もう一度見せて OK をもらってから "
                f"`python -m src.cli screen {build_dir}` を打ってください")
    return (f"『{name}』はまだ動画を見せていません。"
            "**投稿する前に動画を見せます**（2026-09-13 ユーザー指示）。"
            f"{video_of(build_dir)} を見せて、OKをもらってから "
            f"`python -m src.cli screen {build_dir}` を打ってください")
