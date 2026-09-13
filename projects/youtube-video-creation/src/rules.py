"""**決まりと、実際に動いているものを突き合わせる**（2026-09-13）。

CLAUDE.md に書いた決まりと、コードや config の値がズレる事故が続いた。

- 2026-09-07 に「報道の出典は1社でよい」と決め、CLAUDE.md は直したのに
  `config/sources.yaml` は `needs_sources: 2` のまま**5日間**残っていた。
  そのあいだ、取材メモは2本目のURLを埋めるために**同じ記事を並べる欄**になっていた
- CLAUDE.md には「機械の点より印を優先する」と書いてあったのに、
  実装は点の加算でしかなく、反応を並べた節に負けていた

**人が両方を見比べ続けるのは無理**なので、機械に突き合わせさせる。
CLAUDE.md の中に、次の形の印を置く（画面には出ない HTML コメント）。

    <!-- 突き合わせ: config/sources.yaml tiers.報道.needs_sources = 1 -->
    <!-- 突き合わせ: src/shorts.py MAX_SECONDS = 58.0 -->

`.yaml` は点でつないだ道、`.py` はモジュールの変数を見る。
値が違えば `doctor` が × を出す。**どちらが正しいかは機械には決められない**ので、
「食い違っている」とだけ言う。直すのは人（または私）の仕事。
"""

from __future__ import annotations

import ast
import importlib
import re
from dataclasses import dataclass
from pathlib import Path, PurePath

import yaml

MARK = re.compile(r"<!--\s*突き合わせ:\s*(\S+)\s+(\S+)\s*=\s*(.+?)\s*-->")


@dataclass
class Mismatch:
    target: str
    key: str
    wanted: str
    found: str
    note: str = ""

    def line(self) -> str:
        if self.note:
            return f"{self.target} {self.key}　{self.note}"
        return f"{self.target} {self.key}　決まりは {self.wanted} / いまは {self.found}"


def marks(text: str) -> list[tuple[str, str, str]]:
    """CLAUDE.md から突き合わせの印を拾う。"""
    return [(m.group(1), m.group(2), m.group(3)) for m in MARK.finditer(text)]


def _from_yaml(path: Path, key: str):
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    for part in key.split("."):
        if not isinstance(data, dict) or part not in data:
            raise KeyError(key)
        data = data[part]
    return data


def _from_python(target: str, key: str):
    """`.py` の中の定数を読む。

    **クラスの中に置いた定数も読む**（2026-09-14）。`STACK_KEEP` のように
    レンダラのクラス属性で持っているものが指せず、「その名前がありません」に
    なっていた。`Klass.ATTR` と点でつないで書ける
    """
    module = importlib.import_module(target.replace("/", ".").removesuffix(".py"))
    found = module
    for part in key.split("."):
        if not hasattr(found, part):
            raise KeyError(key)
        found = getattr(found, part)
    return found


def check(root: Path | None = None) -> list[Mismatch]:
    """食い違っているものだけを返す。"""
    root = Path(root or ".")
    doc = root / "CLAUDE.md"
    if not doc.exists():
        return []
    out: list[Mismatch] = []
    for target, key, wanted_text in marks(doc.read_text(encoding="utf-8")):
        path = root / target
        try:
            if target.endswith((".yaml", ".yml")):
                found = _from_yaml(path, key)
            elif target.endswith(".py"):
                found = _from_python(target, key)
            else:
                out.append(Mismatch(target, key, wanted_text, "",
                                    "見方が分かりません（.yaml か .py だけ）"))
                continue
        except FileNotFoundError:
            out.append(Mismatch(target, key, wanted_text, "", "ファイルがありません"))
            continue
        except KeyError:
            out.append(Mismatch(target, key, wanted_text, "", "その名前がありません"))
            continue
        except Exception as err:  # 読めない理由はそのまま出す
            out.append(Mismatch(target, key, wanted_text, "", f"読めません（{err}）"))
            continue
        try:
            wanted = ast.literal_eval(wanted_text)
        except Exception:
            wanted = wanted_text
        if isinstance(wanted, (int, float)) and isinstance(found, (int, float)):
            same = float(wanted) == float(found)
        elif isinstance(found, PurePath):
            # **Path で持っている定数は文字で突き合わせる**（2026-09-13）。
            # CLAUDE.md に書けるのは文字だけなので、そのままだと
            # 'research/screened.json' と WindowsPath(...) が必ず食い違う。
            # 区切りは / に寄せる（Windows とそれ以外で同じ印になるように）
            same = str(wanted).replace(chr(92), "/") == found.as_posix()
        else:
            same = wanted == found
        if not same:
            out.append(Mismatch(target, key, repr(wanted), repr(found)))
    return out


def counted(root: Path | None = None) -> int:
    """印の数。0なら、そもそも突き合わせていない。"""
    doc = Path(root or ".") / "CLAUDE.md"
    return len(marks(doc.read_text(encoding="utf-8"))) if doc.exists() else 0
