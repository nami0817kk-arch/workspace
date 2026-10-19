---
name: stickfigure-action
description: 棒人間のアクション動画（戦い・物語つき）を、数行の指定から作る手順。「棒人間の動画作って」「戦いを作って」「雪辱戦」「次の回」「棒人間のショート」「アクションの品質を上げて」と言われたときに使う。台本の自動生成（fight）・物語の型（story）・エピソード連結・効果音/BGM・参考との比較（rhythm）まで。
---

# 棒人間アクション動画をつくる

コード: `C:/Users/なみ/dev/workspace/projects/stickfigure`（**worktree を切ってから触る**。作業中の枝は `claude/stickfigure`、`dev/wt-stickfigure`）
決まり・落とし穴は `projects/stickfigure/CLAUDE.md`。ここは**使う順番**と**ユーザーに言われた方針**だけ。

## ユーザーの方針（守る）

- **2D（セル画風）**。立体の陰影・斜めの強いカメラで3D感を出す案は出さない（`style: flat2d`）
- **顔（目・眉・口）は描かない**
- **1本を磨くより、毎回その品質で作れる仕組み・道具を上げる**（2026-10-19）。YouTube で継続投稿の予定
- **「やめて」と言われるまで止まらない**。1周ごとに wrap_up で終えず、動画は SendUserFile で途中に送る
- 参考（アニメ戦闘6本）のリズム: カット中央値0.13秒・2コマ撮り2〜3割・閃光2秒に1回。数字は `reference/anime_rhythm.md`。**参考の動画・画像は残さない**

## 作る順

```
物語の型 or fight の指定 → check(数秒) → build(数分) → コマで目視 → 動画を送る
```

1. **一番速いのは物語の型**: `scenes/episodes/*.yaml` に `story: {arc: revenge|tournament|duel|protect|mentor, hero: 名前, rival: 名前}` と書く
   → `python -m stickfig episode scenes/episodes/ep_revenge.yaml --out out/ep_revenge`（約25秒。場面ごとに点検→書き出し→連結）
1b. **まとめて量産**: `python -m stickfig series --n 5 --out out/series --seed 100 [--vertical] [--build]`。型・名前・色・seed を回して、エピソード・サムネ・投稿の下書きを順に作る（`--build` なしは指定の yaml だけ。1本 約3〜8分）。story に `seed: 数字` を入れると、台詞の言い回し・技名・連打の clip・溜めの色が変わる（同じ数字は同じ内容）
2. **1本の戦い**: `scenes/x.yaml` に `fight: {weapon: sword|none, kick: true, hits: 1〜4, counter: true, finisher: launch_slash|none, palette: warm|cool, stage: cave|dojo|field|night|sunset, mood: battle|tense|calm|sad, colors: {A:[r,g,b], B:[...]}, lines: [...]}`
   → `python -m stickfig check scenes/x.yaml`（合否＋演出のリズムの見積もり。Blender 不要・数秒）→ `build scenes/x.yaml --out out/x`
   - `lines`: `{at: opening|kick|rise|combo|counter|last|finisher|ko|end, dt, dur, kind: say|narr|shout, who: A|B, text}`（台詞・ナレーション・叫び文字）
3. 点検の「演出のリズム」が **低い→足す／高い→減らす** なら、台本の `fx.flashes`・`stepping.ranges` で調整。動画ができたら `python -m stickfig rhythm out/x/x.mp4` で実測
4. **投稿の道具**: `python -m stickfig kit out/<エピソード> --title 雪辱戦 --hero ミドリ --rival アカ --arc revenge` → `kit/thumb.png`(1280x720)と `投稿の下書き.md`(題名候補・概要欄・タグ。**CMU の出典入り**)。投稿はしない
5. **目視**: `out/<名前>/frames` から、命中の前後・寄りのカット・字幕を数枚見る（機械の点検は不具合を先に潰すだけ。気持ちよさは目）
6. 見せる前に、公開用なら CLAUDE.md の「動画を見せる関門」（別チャンネルの決まり）と同じく、**ユーザーが見てから投稿**。投稿・公開・課金は勝手にしない

## 縦画面（ショート）

エピソードは `python -m stickfig episode … --vertical`（全場面・カードが 720x1280）。1本の台本なら `output: {aspect: vertical}`。16:9 を2人の中間で切り出して拡大し、字幕は切り出したあとに重ねる。いまは 16:9 を切り出すので、人物が離れたカットでは片方が切れる。

## 速さ・並列

人物と舞台の書き出し（Blender）は 150 コマで約 50 秒。合成は **プロセスを分けて並列**（`STICKFIG_WORKERS`、既定は CPU 数か 8）で、1場面（約200コマ）が約45秒。25秒のエピソードは約3分。長い物はバックグラウンドで。

## つまずき所（実際に踏んだ）

- モーションキャプチャ clip（`clips/`、gitignore）が無い環境では check が通らない。`python scripts/fetch_cmu.py` で取る
- `--reuse-figs` は plan が同じときだけ。カメラ・台本を変えたら使わない（人物と背景がずれる）
- Blender は人物の書き出しだけ。1場面あたり数分（約200コマ）。長い物はバックグラウンドで回す
- 点検の `interpenetration`（すり抜け）は 400 まで緩めてある。連打の見本は 50〜60 コマ交差する
- 新しい clip を命中に使うときは、命中時の2人の間隔（root_x の差）が 0.7〜1.0 か先に見る（02_07_s1 は届かない）

## まだ無い（次の改善候補）

別の武器・キャラの体型／空中戦・追いかけっこ／3人以上の戦い／音の聴き比べ（いまは計算で作った効果音とBGM）／縦画面のSFX文字の位置（いまは切り出しで大きく出る）
