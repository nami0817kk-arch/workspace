"""テストから src/ を読めるようにする。

`python -m pytest` はカレントディレクトリを読み込み先に足すが、`pytest` は
足さない（ipa-kakomon で実際に手元とCIの差になった罠と同じ形）。
どちらで走らせても同じになるよう、ここで明示する。
"""
import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parent
for path in (_ROOT, _ROOT / "src"):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))
