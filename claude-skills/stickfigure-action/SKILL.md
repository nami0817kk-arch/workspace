---
name: stickfigure-action
description: 棒人間のアクション動画（戦い・物語つき）を、数行の指定から作る手順。「棒人間の動画作って」「戦いを作って」「雪辱戦」「次の回」「棒人間のショート」「アクションの品質を上げて」と言われたときに使う。台本の自動生成（fight）・物語の型（story）・エピソード連結・効果音/BGM・参考との比較（rhythm）まで。
---

# 棒人間アクション動画をつくる

コード: `C:/Users/なみ/dev/workspace/projects/stickfigure`（**worktree を切ってから触る**。作業中の枝は `claude/stickfigure`、`dev/wt-stickfigure`）
決まり・落とし穴は `projects/stickfigure/CLAUDE.md`。ここは**使う順番**と**ユーザーに言われた方針**だけ。

## ユーザーの方針（守る）

- **カメラは引き気味に**（2026-10-20「もう少し遠くから見るように」）。fight の `cam_zoom`（既定 1.25）が全カットを一律に引く。人物の高さ/画面は中央値 0.45〜0.55 が目安。「寄せる」提案はしない
- **色んなアニメの技を足していく**（2026-10-20）。今あるもの: 光線・気弾・衝撃波・撃ち合い・空中コンボ・出だしの気弾/瞬間移動/飛行。足し方の型は CLAUDE.md「アニメの必殺技」

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
1b. **まとめて量産**: `python -m stickfig series --n 5 --out out/series --seed 100 [--vertical] [--build] [--compile]`（`--compile` で全話を題名カードつきの 1 本 `all.mp4` にもする。作成済みなら `--compile-only`）。型・名前・色・seed を回して、エピソード・サムネ・投稿の下書きを順に作る（`--build` なしは指定の yaml だけ。1本 約3〜8分）。story に `seed: 数字` を入れると、台詞の言い回し・技名・連打の clip・溜めの色が変わる（同じ数字は同じ内容）
2. **1本の戦い**: `scenes/x.yaml` に `fight: {weapon: sword|dagger|staff|spear|none, kick: true, hits: 1〜4, counter: true, finisher: launch_slash|launch_kick|random|none, palette: warm|cool, stage: cave|dojo|field|night|sunset, mood: battle|tense|calm|sad, colors: {A:[r,g,b], B:[...]}, ally: {color, x, y, facing, cheer}（3人目の味方。奥行き y で後ろに置き、戦わず見守る。台詞は who: C）, a_scale/b_scale（体格）, seed, lines: [...]}`
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
| 決め技 | `finisher: launch_slash／launch_kick／air_combo／barrage／slash_wave／iai／slam_throw／beam／blast／wave／beam_clash／random／none` | 打ち上げ斬り／蹴り上げ／空中コンボ（打ち上げ→空中で拳 2 発→叩きつけ）／連打乱舞（拳 8 発→大振りで壁へ）／飛ぶ斬撃（振り抜くと三日月の光が飛ぶ。剣だけ）／居合（1 コマで相手の向こうへ抜け、間を置いて斬撃線が走り崩れ落ちる。剣だけ）／投げ（つかんで頭上を回し、背後の地面に叩きつける）／気の光線（カメハメ波の型。溜め→発射→壁まで吹き飛ばす）／気弾（片手の玉を投げて着弾で爆発）／衝撃波（跳んで拳を地面に叩きつけ、地面を走る波で打ち上げる）／光線の撃ち合い（2 人が同時に撃ち、中央でぶつかり、押し勝つ。B の色は `beam_color_b`）。色は `beam_color`／seed で選ぶ。決めたあとは勝ち名乗り（武器を掲げて止め、下ろす）。2026-10-19「アニメチックな技も」の指示で光線を追加。技の足し方は CLAUDE.md「アニメの必殺技」 |
| 出だしの技 | `opening: blast／teleport／fly`（kick なしのとき） | blast: 走り出す前に気弾を投げ、相手がくぐってかわし、玉は壁で爆発。teleport: 走らず一瞬で相手の目の前に現れる（残像の列・閃光）。fly: 跳び上がって水平に飛び、急降下して相手の前に着地（残像の尾・風の筋）。指定なしは走って寄る。そのあと連打へ |
| 相手の連打 | `b_combo: 2` | A の決めの1発の前に、B が 2 発打ち返す（A はくぐってかわし→受け止め）。長い武器では無し |
| Becker 風の線 | 台本 `limb: {base: 0.055, tip: 0.03, tip_color: [0.08,0.08,0.1]}`, `fx: {weapon_glow: true}` | 手足が根元太→先細り・先が暗色、剣が水色に光る。観察は `reference/becker_recent.md` |

| アニメの間 | `timing: true`, `exaggerate: 1.25` | 命中の clip を「素早く振りかぶり→溜めて止め→1〜2 コマで一気→振り抜いてゆっくり戻る」の時間配分に。溜めで腕を引き体を反らし、直後は行き過ぎる。命中は手足が伸び切ったコマ(`reach`)、当て先は手の高さから自動(`auto`)、体の表面を狙う(`surface`) |
| スミア・残像 | `anime: {smear: true, trails: true}`(既定) | どちらも**打つ側の命中の前後だけ**(走りの剣先に残像が出ると床にジグザグが残る)。スミアは振りの 1〜2 コマの間の中割り 3 枚 |
| 走りの誇張 | `fight.RUN_LOOK`(clip の `amp`+`add`) | 前傾 0.2・腕振り 1.35 倍(mocap の走りは直立で腕が低い) |
| 検証用の固定カメラ | `camera: fixed` | カット・反転・連打カットを切って動きだけ見る(`scenes/study_slash.yaml`・`study_kick.yaml`)。**直しは台本でなく fight の既定・plan に入れる**(2026-10-19「一つの作品の質を上げるのではない、スキルとして向上させる」) |

測り方: `build` が出す「人物の高さ/画面」(中央値 0.5〜0.65、1/3 未満のコマ 15% 以下が目安。参考は 1/3〜1/2)、`python -m stickfig motion scenes/x.yaml`、`check` の「キレ」(先端の速さの山÷溜めの平均。目安 4 以上)・「待ち」・「間合い」(命中後の 2 人の距離の最小。0.55 未満は胴が重なる)。コマ送りで見る: ffmpeg の `select+tile` でコマ表(CLAUDE.md「2D アニメの動きの質」)。（体のひねり `spin` の標準偏差、足滑り、歩数、1コマの最大移動、攻防の内訳、接触の距離）。改善前→後で A の spin_sd 0→0.45、歩数 4→11、攻防 A:slash×5 → A:slash×3＋clash/miss＋B の miss/clash/hit。

## 縦画面（ショート）

エピソードは `python -m stickfig episode … --vertical`（全場面・カードが 720x1280）。1本の台本なら `output: {aspect: vertical}`。16:9 を2人の中間で切り出して拡大する（2人が枠に収まらないほど離れているときは主役を追う。命中の瞬間は命中点を中心に）。速い走りの数コマは主役が端に寄ることがある。縦では寄りのカット（impact_cuts／flurry）を 1.6 倍引き、効果音の文字は出さない（切り出しで切れる）。**縦の確認は縦で build したもので見る**（16:9 用に書き出した人物の絵を切っても構図は分からない）。

## 速さ・並列

人物と舞台の書き出し（Blender）は 150 コマで約 50 秒。合成は **プロセスを分けて並列**（`STICKFIG_WORKERS`、既定は CPU 数か 8）で、1場面（約200コマ）が約45秒。25秒のエピソードは約3分。長い物はバックグラウンドで。

## つまずき所（実際に踏んだ）

- **接触の点検は出来上がりのコマで測る**（2026-10-19）。解いた時点の距離を信じていたら、命中の瞬間に剣先が体から 0.3〜0.6 浮いていた。原因は命中のコマに足していた体の動き（傾き・腰・前進・受け側の反応）と、clip の継ぎ目の位置のずれ。`check` の `contact@…` と `teleport` が両方 OK になってから build する
- 走りの clip の輪の継ぎ目で dx が 1 周ぶん飛ぶ不具合は直してある（`mocap.Clip.sample`、テストあり）。走りの区間で 1 コマだけ後ろへ飛ぶ・区間の入りで 2 単位飛ぶのを見たら、これを疑う
- 剣の clip はパンチの clip（02_xx）だと刃が真下を向く。剣は突き・振りの clip（`fight.STRIKES` に手と先端の向きを測ってある）
- clip（モーションキャプチャ）とキーの位置が食い違うと、混ぜる数コマで 1〜2 単位すべる（瞬間移動）。`plan._align_keys_to_clips` が合わせる。**キーを平行移動する方式は 2 人が追いかけ合って発散した**ので、台本の位置（`_dx0`）との間を助走・戻りで寄せる方式にしてある

- モーションキャプチャ clip（`clips/`、gitignore）が無い環境では check が通らない。`python scripts/fetch_cmu.py` で取る
- `--reuse-figs` は plan が同じときだけ。カメラ・台本を変えたら使わない（人物と背景がずれる）
- Blender は人物の書き出しだけ。1場面あたり数分（約200コマ）。長い物はバックグラウンドで回す
- 点検の `interpenetration`（すり抜け）は 400 まで緩めてある。連打の見本は 50〜60 コマ交差する
- 新しい clip を命中に使うときは、命中時の2人の間隔（root_x の差）が 0.7〜1.0 か先に見る（02_07_s1 は届かない）

## まだ無い（次の改善候補）

別の武器の種類を増やす(いまは剣・短剣・棍・槍)／3人以上が戦う場面（3人目の味方は置ける: `ally`）／空中戦・追いかけっこ／3人以上が戦う場面（3人目の味方は置ける: `ally`）／音の聴き比べ（いまは計算で作った効果音とBGM）／縦画面のSFX文字の位置（いまは切り出しで大きく出る）
