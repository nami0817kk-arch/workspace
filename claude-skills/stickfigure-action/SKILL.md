---
name: stickfigure-action
description: 棒人間のアクション動画（戦い・物語つき）を、数行の指定から作る手順。「棒人間の動画作って」「戦いを作って」「雪辱戦」「次の回」「棒人間のショート」「アクションの品質を上げて」と言われたときに使う。台本の自動生成（fight）・物語の型（story）・エピソード連結・効果音/BGM・参考との比較（rhythm）まで。
---

# 棒人間アクション動画をつくる

コード: `C:/Users/なみ/dev/workspace/projects/stickfigure`（**worktree を切ってから触る**。作業中の枝は `claude/stickfigure`、`dev/wt-stickfigure`）
決まり・落とし穴は `projects/stickfigure/CLAUDE.md`。ここは**使う順番**と**ユーザーに言われた方針**だけ。

## ユーザーの方針（守る）

- **2D（セル画風）**。人物は `style: flat2d`、**舞台も2D**（`stage: {style: flat}`。2026-10-19「フィールドも2d」。Blender の立体の床・壁は使わず、平らな帯と単色の柱を PIL で描く）。立体の陰影・斜めの強いカメラで3D感を出す案は出さない
- **顔（目・眉・口）は描かない**
- **字幕（吹き出し・ナレーション・叫び文字）は付けない**（2026-10-19「字幕はいらない」。fight の `captions: true` を明示したときだけ出る）
- **「手だけ動いている」はダメ**（2026-10-19）。全身（ひねり・体重移動・弓足・のけぞり・足運び）と攻防の往復で見せる。数字で見る: `spin` の標準偏差が 0 なら体はひねっていない、接地した足の横滑りは 20% 前後まで
- **1本を磨くより、毎回その品質で作れる仕組み・道具を上げる**（2026-10-19）。YouTube で継続投稿の予定
- **「やめて」と言われるまで止まらない**。1周ごとに wrap_up で終えず、動画は SendUserFile で途中に送る
- 参考（アニメ戦闘6本）のリズム: カット中央値0.13秒・2コマ撮り2〜3割・閃光2秒に1回。数字は `reference/anime_rhythm.md`。**参考の動画・画像は残さない**

## 作る順

```
物語の型 or fight の指定 → review(数秒・字幕と筋) → preview(下書き・数十秒) → build(本番・数分/場面) → コマで目視 → 動画を送る
```

- `python -m stickfig review scenes/episodes/ep.yaml`: 字幕の長さ・読む時間・場面からのはみ出し・倒れた人物の台詞(最後の一言は `last_words: true`)・リズムの目安。`episode` は書き出す前に自動でこれを通し、直すところがあれば止まる(`--force` で続ける)
- `python -m stickfig episode … --preview`(または `preview scenes/x.yaml --out x.mp4`): **Blender なしの線画の下書き**。台本・字幕・カメラのカット・命中・音のタイミングを、本番を待たずに確かめる。見た目(陰影・輪郭・光の演出)は本番と違う
- 台詞は `lines`（`dur` は最低の長さ。読む時間は自動で確保し、しゃべる系は重ならないよう順に並べ、収まらなければ場面の終わりを延ばす）

1. **一番速いのは物語の型**: `scenes/episodes/*.yaml` に `story: {arc: revenge|tournament|duel|protect|mentor, hero: 名前, rival: 名前}` と書く
   → `python -m stickfig episode scenes/episodes/ep_revenge.yaml --out out/ep_revenge`（約25秒。場面ごとに点検→書き出し→連結）
1b. **まとめて量産**: `python -m stickfig series --n 5 --out out/series --seed 100 [--vertical] [--build]`。型・名前・色・seed を回して、エピソード・サムネ・投稿の下書きを順に作る（`--build` なしは指定の yaml だけ。1本 約3〜8分）。story に `seed: 数字` を入れると、台詞の言い回し・技名・連打の clip・溜めの色が変わる（同じ数字は同じ内容）
2. **1本の戦い**: `scenes/x.yaml` に `fight: {weapon: sword|dagger|staff|spear|none, kick: true, hits: 1〜4, counter: true, finisher: launch_slash|none, palette: warm|cool, stage: cave|dojo|field|night|sunset, mood: battle|tense|calm|sad, colors: {A:[r,g,b], B:[...]}, ally: {color, x, y, facing, cheer}（3人目の味方。奥行き y で後ろに置き、戦わず見守る。台詞は who: C）, a_scale/b_scale（体格）, seed, lines: [...]}`
   → `python -m stickfig check scenes/x.yaml`（合否＋演出のリズムの見積もり。Blender 不要・数秒）→ `build scenes/x.yaml --out out/x`
   - `lines`: `{at: opening|kick|rise|combo|counter|last|finisher|ko|end, dt, dur, kind: say|narr|shout, who: A|B, text}`（台詞・ナレーション・叫び文字）
3. 点検の「演出のリズム」が **低い→足す／高い→減らす** なら、台本の `fx.flashes`・`stepping.ranges` で調整。動画ができたら `python -m stickfig rhythm out/x/x.mp4` で実測
4. **投稿の道具**: `python -m stickfig kit out/<エピソード> --title 雪辱戦 --hero ミドリ --rival アカ --arc revenge` → `kit/thumb.png`(1280x720)と `投稿の下書き.md`(題名候補・概要欄・タグ。**CMU の出典入り**)。投稿はしない
5. **目視**: `out/<名前>/frames` から、命中の前後・寄りのカット・字幕を数枚見る（機械の点検は不具合を先に潰すだけ。気持ちよさは目）
6. 見せる前に、公開用なら CLAUDE.md の「動画を見せる関門」（別チャンネルの決まり）と同じく、**ユーザーが見てから投稿**。投稿・公開・課金は勝手にしない

## 戦いの動きの部品（fight の既定で全部 on。2026-10-19 に「バトルしてる感」の指摘で追加）

| 部品 | 指定 | 何をするか |
|---|---|---|
| 全身の動き | `body: 1.7`（0 で切る） | 命中ごとに、攻め側は溜め→ひねり込み・体重移動・弓足、受け側はのけぞり・腰落ち・押される。戦闘中は足でリズムを取る弾み |
| 足運び | `footwork: true` | 接地した足を床に固定（IK）、股が開いたら踏み替える。速いときは小刻み。足音も鳴る |
| 防御 | `block: true`（hits≧3） | 2発目を 受け止め `clash`（ガキィン・多角度カット）か かわし `miss`（くぐる／跳ぶ）。seed で選ぶ、hits≧4 なら両方 |
| 受けて返す | `riposte: true` | 受け止めの直後に相手が打ち返し、こちらが受け止める |
| 相手から仕掛ける | `b_first: true`（蹴り無しのとき） | 相手が先に2発（かわし→受け止め）→ こちらの溜め→連打 |
| 蹴りを混ぜる・踏み込み | `mix_kick: true` | 連打の中の1発を蹴りに（seed で半々）。接触を解かない命中では踏み込んで前へ出る（lunge） |
| Becker 風の線 | 台本 `limb: {base: 0.055, tip: 0.03, tip_color: [0.08,0.08,0.1]}`, `fx: {weapon_glow: true}` | 手足が根元太→先細り・先が暗色、剣が水色に光る。観察は `reference/becker_recent.md` |

測り方: `python -m stickfig motion scenes/x.yaml`（体のひねり `spin` の標準偏差、足滑り、歩数、1コマの最大移動、攻防の内訳、接触の距離）。改善前→後で A の spin_sd 0→0.45、歩数 4→11、攻防 A:slash×5 → A:slash×3＋clash/miss＋B の miss/clash/hit。

## 縦画面（ショート）

エピソードは `python -m stickfig episode … --vertical`（全場面・カードが 720x1280）。1本の台本なら `output: {aspect: vertical}`。16:9 を2人の中間で切り出して拡大する（2人が枠に収まらないほど離れているときは主役を追う。命中の瞬間は命中点を中心に）。速い走りの数コマは主役が端に寄ることがある。

## 速さ・並列

人物と舞台の書き出し（Blender）は 150 コマで約 50 秒。合成は **プロセスを分けて並列**（`STICKFIG_WORKERS`、既定は CPU 数か 8）で、1場面（約200コマ）が約45秒。25秒のエピソードは約3分。長い物はバックグラウンドで。

## つまずき所（実際に踏んだ）

- **接触の点検は出来上がりのコマで測る**（2026-10-19）。解いた時点の距離を信じていたら、命中の瞬間に剣先が体から 0.3〜0.6 浮いていた。原因は命中のコマに足していた体の動き（傾き・腰・前進・受け側の反応）と、clip の継ぎ目の位置のずれ。`check` の `contact@…` と `teleport` が両方 OK になってから build する
- clip（モーションキャプチャ）とキーの位置が食い違うと、混ぜる数コマで 1〜2 単位すべる（瞬間移動）。`plan._align_keys_to_clips` が合わせる。**キーを平行移動する方式は 2 人が追いかけ合って発散した**ので、台本の位置（`_dx0`）との間を助走・戻りで寄せる方式にしてある

- モーションキャプチャ clip（`clips/`、gitignore）が無い環境では check が通らない。`python scripts/fetch_cmu.py` で取る
- `--reuse-figs` は plan が同じときだけ。カメラ・台本を変えたら使わない（人物と背景がずれる）
- Blender は人物の書き出しだけ。1場面あたり数分（約200コマ）。長い物はバックグラウンドで回す
- 点検の `interpenetration`（すり抜け）は 400 まで緩めてある。連打の見本は 50〜60 コマ交差する
- 新しい clip を命中に使うときは、命中時の2人の間隔（root_x の差）が 0.7〜1.0 か先に見る（02_07_s1 は届かない）

## まだ無い（次の改善候補）

別の武器の種類を増やす(いまは剣・短剣・棍・槍)／3人以上が戦う場面（3人目の味方は置ける: `ally`）／空中戦・追いかけっこ／3人以上が戦う場面（3人目の味方は置ける: `ally`）／音の聴き比べ（いまは計算で作った効果音とBGM）／縦画面のSFX文字の位置（いまは切り出しで大きく出る）
