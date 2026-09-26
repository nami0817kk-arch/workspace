# puzzle-generator

パズルをプログラムで生成する共有ライブラリ。**方式5（Amazon KDP の紙の本）と
方式7（Reddit の日替わりアプリ）が共通で使う。** 出力形式の定義は
[`SCHEMA.md`](./SCHEMA.md)。

生成AIには作らせない。解が一意であることを保証できないため、アルゴリズムで
生成し、機械検証（`verify_unique_solution`）を通ったものだけを使う。

## 使い方

```python
from puzzle_generator import build_puzzle, render_svg, validate_record

record = build_puzzle("medium", seed=1)
validate_record(record)  # 例外が出なければ形が正しい

svg_problem = render_svg(record, show_solution=False)  # 問題ページ
svg_answer = render_svg(record, show_solution=True)    # 解答ページ
```

まとめて作るとき:

```python
from puzzle_generator import generate_batch

records = generate_batch(count=60, difficulty="medium", start_seed=0)
```

## 現在の対応パズル

- `maze`（迷路）のみ。ナンプレ等を足す場合は先に `SCHEMA.md` に形を書く。

## テスト

```
pip install -e .[dev]
pytest
```
