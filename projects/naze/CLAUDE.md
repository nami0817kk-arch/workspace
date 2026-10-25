# naze — 解説ショート（地形のなぜ・作って試す）

2026-10-25 開始。ショートは3分以内。他チャンネルの題材の並び・題名の型・見た目をまねない。数学の題材と創作の物語は扱わない。

## 作り方

`python -m naze <手順> episodes/<題材>`（題材のフォルダに `ep.py` の `EP` を置く。出力は `out/<題材>/`）

- 地形の回（kind: terrain）: `kana` → `voice` → `prep` → `stills 1,60,…`（目で見る）→ `render` → `compose`
  - 標高は国土地理院の標高タイル（`cache/dem` に保存）。地形は Blender（`NAZE_BLENDER` か既定のパス）で描く
  - 座標の原点は範囲の真ん中（km、x が東・y が北）。カメラの yaw は 0 で南から北を見る
- 計算の回（kind: sim）: `kana` → `voice` → `stills` → `compose`。画面は `ep.py` の `draw(img, dr, t, ctx)` が描く
- 声は VOICEVOX（127.0.0.1:50021、No.7 アナウンス）。読みは `kana` で全行を見て、違えば `say` で直す

## 決まり

- 出典は `ep.py` の冒頭に書く。数字は自分で計算したか一次資料のものだけ
- 投稿の前に必ず動画をユーザーに見せる
