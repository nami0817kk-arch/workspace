"""moneyloop: AI自動リサーチ→有料ニュースレター配信による収益化パイプライン。

パイプライン全体は :func:`moneyloop.orchestrator.run_daily` が実行する。
収集(collect) → 選別(curate) → 生成(generate) → 分割(paywall) →
配信(deliver) → 計上(ledger) の6段で、各段は独立してテスト可能。
"""

__version__ = "0.1.0"
