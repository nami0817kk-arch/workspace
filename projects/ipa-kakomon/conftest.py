"""テストから src/ を読めるようにする。

`python -m pytest` は今いるディレクトリを読み込み先に足すが、`pytest` は足さない。
手元は前者、CI は後者で走っていたため、**手元だけ緑で CI が赤くなった**
（2026-09-25）。どちらで走らせても同じになるよう、ここで明示する。
"""
import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parent
for path in (_ROOT, _ROOT / "src"):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))
