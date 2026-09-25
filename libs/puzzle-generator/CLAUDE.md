# puzzle-generator

方式5（KDP紙の本）と方式7（Reddit日替わり）が共通で使う生成器。出力形式の
正は [`SCHEMA.md`](./SCHEMA.md)（`docs/monetization-plans.md` にも要約がある）。

- **出力形式（SCHEMA.md）を変えるときは、方式5・方式7 両方の利用側を確認する。**
  片方しか見ずに変えると、もう片方が壊れる。
- **`verify_unique_solution` が false を返すレコードを本・アプリに出さない。**
  `build_puzzle()` はこれを内部でチェックして例外にしているので、
  この関数を経由せずに `Maze` を直接組み立てて使うことはしないこと。
- 迷路は棒倒し法（recursive backtracker）で spanning tree だけを作っており、
  ループ（braiding）を意図的に入れていない。木構造なら「2点間の経路は
  必ず1本」が構造上保証されるため。difficultyを上げる目的でループを
  足す変更をするなら、`verify_unique_solution` の検証方法も見直すこと
  （現状の「辺の数 = マス数 - 1」という判定はループがある前提が崩れる）。
- 公開API（`puzzle_generator/__init__.py` の `__all__`）は他PJTから
  コミット固定で参照される想定。名前を変えたら利用側のテストも直す。
