"""ベースライン診断のルール定義。

モジュールを import した時点で `ruleset` に登録される。
新しいルールは、観点の近いモジュールに `@rule` を付けて足す。
"""

from . import automation, docs, reliability  # noqa: F401  登録のための import

__all__ = ["automation", "docs", "reliability"]
