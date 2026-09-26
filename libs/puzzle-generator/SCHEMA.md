# 生成器の出力形式（方式5・方式7 共通）

**方式5(KDP紙の本)と方式7(Reddit日替わり)は同じ生成器を使う。** 先にこちらで
決めたので、方式7はこの形式をそのまま使う（変えたい場合はここを直してから
両方の利用側を直す）。宣言は `docs/monetization-plans.md` にも書いてある。

## 方針

- パズルは**プログラムで生成**する（生成AIには作らせない。解の一意性を
  保証できないため）。
- **解が一意であることを機械で検証**し、通らない盤面は使わない
  (`verified: true` のレコードだけを使う。`build_puzzle()` はこの検証を
  内部で行い、落ちれば例外を投げる)。
- 1問 = 1つの JSON 互換 dict（`schema_version` から始まる下記の形）。
  ファイルに保存するときはこの dict を1行1問の JSONL、またはリストの
  JSON配列にする（どちらでも読めるようにしておくこと。個々の利用側の
  都合で選べばよい）。

## 共通のエンベロープ

```json
{
  "schema_version": 1,
  "type": "maze",
  "id": "maze-16x16-1234",
  "seed": 1234,
  "difficulty": "medium",
  "params": {"width": 16, "height": 16},
  "board": { "...": "type ごとの盤面（下記）" },
  "solution": { "...": "type ごとの解答（下記）" },
  "verified": true,
  "generator": {"name": "puzzle-generator", "algorithm": "backtracker"}
}
```

| キー | 型 | 意味 |
|---|---|---|
| `schema_version` | int | この文書のバージョン。破壊的に変えたら上げる |
| `type` | string | パズルの種類。今は `"maze"` のみ |
| `id` | string | `{type}-{width}x{height}-{seed}` 形式。同じ type+seed なら同じ id になる |
| `seed` | int | 乱数シード。同じ seed なら同じ盤面が再現する |
| `difficulty` | `"easy" \| "medium" \| "hard"` | 難易度。type ごとの具体パラメータは `params` |
| `params` | object | 生成に使ったパラメータ（type ごとに中身が違う） |
| `board` | object | 盤面。利用側はここだけを紙面・画面に出す |
| `solution` | object | 解答。答え合わせページ・チェック用 |
| `verified` | bool | 解の一意性検証を通ったか。**false のレコードは使わない** |
| `generator` | object | 生成器の名前とアルゴリズム名（再現・デバッグ用） |

## type: `"maze"`（迷路）

まず迷路から作る。商標の懸念が無く（ニコリ商標は数独系・スリザーリンク系
などパズル名にかかるもので、迷路は当たらない）、生成も印刷レイアウトも
いちばん単純なため。

生成は**棒倒し法（recursive backtracker）で spanning tree を作るだけ**にして
あり、ループ（braiding）は入れていない。木構造なら任意の2点間の単純経路は
数学的に必ず1本になるので、「解の一意性」がアルゴリズムの構造そのもので
保証される。`verify_unique_solution()` は、生成後に「本当に木になっているか
（辺の数 = マス数 - 1 かつ連結）」を機械的に確かめるためのもの。

```json
"board": {
  "width": 16,
  "height": 16,
  "cell_walls": [[13, 9, ...], ...],
  "start": [0, 0],
  "goal": [15, 15]
},
"solution": {
  "path": [[0, 0], [0, 1], ..., [15, 15]],
  "length": 47
}
```

- `cell_walls[y][x]` は、そのマスに**残っている**壁をビット和で表す。
  `N=1, E=2, S=4, W=8`（例: `13 = N|S|W` は東だけ壁が無い＝右のマスに通れる）。
- `start` / `goal` は `[x, y]`。
- `solution.path` は `start` から `goal` までの座標列（`[x, y]` の配列）。
  隣り合う2点の間に壁が無いことは生成器側で保証済み。
- `solution.length` は経路の辺の数（`len(path) - 1`）。

### 難易度とパラメータ

`puzzle_generator.DIFFICULTIES` に定義。盤面が大きいほど、行き止まりと
折り返しが自然に増えて難しくなる。

| difficulty | width × height |
|---|---|
| easy | 10 × 10 |
| medium | 16 × 16 |
| hard | 22 × 30 |

具体的な冊子1ページあたりの物理サイズ（何mm四方のマスにするか等）は
KDPの入稿サイズに依存するため、`projects/puzzle-book` 側で決める。

## type: `"wordsearch"`（ことば探し）

2026-09-26 に追加（方式5の1冊目。介護向けの紙の本）。**文字は1マス1文字の文字列**
として扱うので、言語に依存しない（日本語のひらがな・カタカナでも、英語でも同じ形）。

```json
"params": {"size": 10, "directions": ["E", "S"]},
"board": {
  "size": 10,
  "grid": [["だ", "い", "こ", "ん", ...], ...],
  "words": [{"answer": "だいこん", "label": "だいこん（大根）"}, ...],
  "theme": "畑の野菜"
},
"solution": {
  "placements": [{"answer": "だいこん", "start": [0, 0], "dir": "E"}, ...]
}
```

- `grid[y][x]` は1マスの文字（`len == 1`）。小書き文字（ゃ・っ）や長音（ー）も1マス。
- `words[].answer` が盤面に並ぶ文字列、`label` は語の一覧に出す表記（漢字の添え書きなど）。
- `dir` は `E`（→）`S`（↓）`SE`（↘）`W` `N` `NW` `NE` `SW` のどれか。
  `start` は `[x, y]`。`params.directions` がその盤面で使った向き。
- **検証（`verified: true` の条件）**: 8方向すべてを数えて、どの `answer` も盤面に
  **ちょうど1回だけ**現れ、その位置が `placements` と一致すること。逆向きや斜めに
  偶然もう1回できていたら落とす。加えて、埋め草の文字で**不適切な語**
  （`wordsearch.BLOCKED_WORDS`）が8方向のどこにもできていないこと。

### 難易度とパラメータ

`puzzle_generator.WORDSEARCH_DIFFICULTIES` に定義。高齢者向けの紙面を先に決めたので、
既定は**逆向きを使わない**（→と↓だけ。むずかしいで↘を足す）。

| difficulty | size | directions |
|---|---|---|
| easy | 8 | E, S |
| medium | 10 | E, S |
| hard | 12 | E, S, SE |

## 将来 type を増やすとき

ナンプレ等を足す場合は、この文書に `type: "nanpure"` の節を追加し、
`board` / `solution` の形をここに書いてから実装する。**先に形を決めて
書いてから作る**のは、方式5・方式7のどちらが先に着手しても同じ形を
使えるようにするため。
