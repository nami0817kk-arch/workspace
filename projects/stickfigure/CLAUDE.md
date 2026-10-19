# stickfigure — 棒人間アクションの制作基盤

棒人間のアクション(走る・蹴る・斬る・吹き飛ぶ)を、**台本(YAML)から動画まで、点検つきで作る**。
「日本のなぜ」(@nihonnaze)を棒人間＋グラフの型に転換するにあたり（2026-10-18）、見せ場の動きの質を、
参考(Alan Becker の棒人間アニメ)と見比べて見劣りしない水準に上げるために作った。
**動きの計算は純粋な Python、Blender は人物を書き出す再生係だけ。** 計算が CI でテストでき、不具合を数字で見つけられる。

## 流れ(要の姿勢の旧方式。物理版は下の「物理シミュレーション」)

```
台本 scenes/*.yaml
  └ plan.py     計算: 姿勢のキー列 → PCHIP補間 → バネ → 走りの周期 → 足の接地 → カメラ → plan.json(コマごとの表)
       └ 接触の逆算: 順運動学(fk.py)で「足・手・剣先が相手の体に届く高さ・位置」を解いて、キーを自動で直す
  └ qa.py       点検(ゲート): 接触・ヒットストップ・溜め・速さ・カクつき・飛び・めり込み・走りの振り。通らなければ書き出さない
  └ blender_player.py  Blender で人物を組み、plan を再生して透過PNG(f_####.png)を書き出す
  └ compose.py  背景・壁・ひび・砂ぼこり・残像・衝撃のコマ(白黒反転)・放射線・流線を重ねて mp4 に
  └ video_check.py  動画を画像から二重に点検(意図しない静止・ワープ)
```

## 使い方

```bash
cd projects/stickfigure
pip install -r requirements.txt
python -m stickfig check scenes/showpiece.yaml            # 計算+点検だけ(Blender 不要・数秒)。合否を出す
python -m stickfig build scenes/showpiece.yaml --out out/showpiece   # 点検→書き出し→合成→動画の点検(約5分)
python -m pytest                                          # テスト(CI でも回る)
```

Blender は `STICKFIG_BLENDER`(blender.exe の場所)、無ければ標準の場所、無ければ PATH。Blender 5.2 で確認済み。

## 台本の書き方(scenes/showpiece.yaml が見本)

- `actors`: キャラ。`base_x`(置く位置)、`facing`(+1 右向き/-1 左向き)、`scale`、`heavy`(体の大きい敵の構え)、`weapon: sword`、`plant: false` で足の接地を切る
- `keys`: キャラごとの**要の姿勢**。時刻 `t`(設計時間・秒)と、変えたい項目だけ書く(書かなかった項目は直前を引き継ぐ)。
  角度はラジアン。項目は `pose.py` の頭に一覧。`face` は `fight/pain/ko/win`
- 要の姿勢の間は PCHIP で通る。**関節にはバネ**が掛かり、遅れて追いつき少し行き過ぎて戻る
- `run: 1.0` を入れたキーの区間は、腕・脚・腰・傾きが**走りの周期**に置き換わる(参考から読んだ角度。`reference/run_reading.md`)
- `hits`: 命中。`tau`、`hold`(止める秒)、`kind`(kick/slash/wall/heel)。`contact` を書くと**届く高さ・位置を自動で合わせる**:
  `striker`、`effector`(foot/hand/tip/rear_foot)、`target: {actor, point: hip/chest/head/neck}`、`adjust_keys`(動かすキーの時刻。**その時刻のキーが要る**)、
  `height: false` で高さは触らず位置だけ、`max_anticipation` でその命中だけ溜めの許容を延ばす
- `slow`: スローモーション(`start/end/rate`)。`puffs`: 砂ぼこりの印。`camera`: `[tau, 中心x, 見える幅]`
- `fx`: 残像(`trails`)・流線(`speed_lines`)・白黒反転にする命中の種類(`invert`)
- `qa`: 点検のしきい値の上書き

## モーションキャプチャを使う(2026-10-19、作り方の見直し)

要の姿勢を数字で書く方式では、全コマを描いた参考(Alan Becker)の手足の弧・先端の遅れ・重心移動に届かない。
そこで **人間の実際の動き(CMU Motion Capture Database、cgspeed の BVH 変換版)を、棒人間に写す**。

```bash
python scripts/fetch_cmu.py                  # 15本(走り・剣・蹴り・突き・武術・転倒)を取得して clips/ に変換
python scripts/make_gallery.py 09_01:2.4 135_07_s1:3.6   # clip を順に再生する確認用の台本(scenes/_gallery.yaml)
```

- `stickfig/mocap.py`: BVH を読む → 順運動学で3D位置 → **人物の向きで決めた縦の平面に射影** → 角度(真下から前へ)→ 30fps。
  平面の決め方 `heading`: `face`(つま先)/`travel`(腰の進行方向、走り)/`strike`(突く・蹴る手足の動く向き)。`mirror` で左右を入れ替える(左で突く動きも前の腕として使う)
- `find_strikes`: 手首・足首の最大速度から、突く・蹴る瞬間を自動で見つける(先頭・末尾の0.5秒は、データの継ぎ目の乱れで除く)。clip にその時刻を記録する
- 台本の `clips`: `{file, strike_at: 2.7, start, end, in, out, amp, loop, speed}`。
  **`strike_at` で、clip の「突く・蹴る瞬間」を、台本の命中の時刻に合わせる**。区間ではキーの姿勢と混ざり(in/out 秒でなめらかに)、バネはキー側にだけ掛かる
- clip を使う攻めの接触は、`contact` が **anchor_dx(前後)と hz_off(腰の高さ、±0.3まで)** で合わせる(clip の姿勢そのものは変えない)
- **BVH と clips/ はリポジトリに入れない**(clips/ は gitignore)。出典: CMU Graphics Lab Motion Capture Database(mocap.cs.cmu.edu、NSF EIA-0196217)。
  cgspeed の変換版(github.com/Shriinivas/cmubvh)の説明は「CMU は元データの利用に制限を置かない」。CMU 公式の原文は、サイトの証明書エラーで未確認(2026-10-19)。公開の動画の概要欄に出典を書く
- 見た目の確認用に `scenes/showpiece_mocap.yaml`(回し蹴りだけモーションキャプチャに置き換えた版)

## 物理シミュレーション(2026-10-19、方式の変更)

**接触が不自然に見えた原因**を数字にした(点検 `interpenetration`): 要の姿勢・モーションキャプチャを再生するだけの方式では、
2人の線が重なるだけで、345コマ中234コマ(68%)で交差(すり抜け)していた。敵の反応も「その時刻に折れる」と決めてあるだけで、「当たった結果」に見えなかった。
そこで **棒人間を剛体で作り、姿勢の計画(キー・clip・走り)を目標として、関節のバネ(PD制御)で追従させる**(`physics.py`、pymunk)。

- 台本に `physics:` を書くと有効になる(`scenes/physics_kick.yaml`)。`knockable: [B]`(倒される側)、`knock_seconds`、`holds`(ヒットストップ秒)、`boost`(威力の上乗せ)、`thresholds`
- **流れ**: 目標(従来の plan の姿勢)→ 物理で進める(240Hz)→ 衝突から命中を出す(位置・強さ・種類 kick/slash/hit/wall/land)→ その tau にヒットストップ・放射線・カメラの揺れ → 剛体の姿勢を rig の角度に変換
- 命中された側は、0.12秒で力が抜け(関節のバネと腰のひもが弱まる)、`knock_seconds` 後にゆっくり立ち直る
- `boost`: 衝突だけだと蹴り1発では軽く押されるだけなので、倒される側の全身に、相手から離れる向きの速度を足す(演出としての誇張)
- **rig の腕・脚は6節の曲線、物理は2節の折れ線**。深く折れると先端の位置がずれるので、先端が物理と同じ位置に来るよう角度を解き直す(`convert`)。
  それでも潜る分は、根元を持ち上げる(`_lift_to_ground`、戻りは1コマ0.02まで)
- 物理版では `contact` の逆算は「目標(狙い)」を作るのにだけ使う。命中は物理が決める。点検は `interpenetration`(すり抜け)・`ground`・`stops` などを見る
- **要の姿勢の旧方式(showpiece.yaml)は、すり抜けを前提に書いてある**。物理に流すと2人がもつれて崩れる。物理用に振り付けを書き直す(接近→1発→飛ぶ、のように単純に)
- 落とし穴: **Chipmunk の回転バネは角度を `a - b` で測る**(RotaryLimitJoint は `b - a`)。目標の符号を逆に入れる。
  剛体の質量は Body に直接与える(`shape.density = 0` を書くと質量が0になって落ちる)。腕の `fa` は胴からの相対角

## アニメの演出(2026-10-19、参考6本の実測から)

参考(戦闘アニメ6本)は、カット中央値0.13秒・2コマ撮りが2〜3割・閃光が2秒に1回・画面の揺れが3〜17%のコマ(数字は `reference/anime_rhythm.md`)。
絵は寄りと彩度の高い色、特大の効果が主役だった。台本の `scenes/showpiece_anime15.yaml`(剣)と `scenes/brawl_a.yaml`(素手)が最新の見本(周14。打ち上げ→空中斬り→叩きつけの大技まで入り)。

- `style: flat2d`: **2Dの見た目**(ユーザー指示)。平らな塗り・人物の外形に輪郭線・斜め/見下ろしを弱める(`flat_k` .3)・望遠(`flat_lens` 1.9)・影はぼかさない。3D感を足す提案はしない
- `flurry`: 山場の前に、4〜5コマごとに角度を変える連打カット。angle は `target`(A/B)・`z`・`ox`・`yaw/pitch/scale/lens/dutch`・`hue`(色つき流線の背景。`streak: false` なら舞台のまま)
- `impact_cuts`: 命中のヒットストップ中に、角度を回す。`hue` で背景色
- `fx.charge`: 必殺技の溜め(`start/end/who/color`)。背景を暗くし、光の柱・粒・足もとの輪(`look.py`)
- `fx.flashes`: 1コマだけの白い閃光(tau のリスト)。多すぎるとうるさい(参考は2秒に1回)
- `fx.color_script`: `[[tau, [r,g,b], 強さ], ...]` 場面ごとの色味
- `stepping: {hold: 2, hold_camera: true, ranges: [[a,b,hold],...]}`: 絵ごとの2コマ撮り。命中の前後 `ones_around_hits` コマは1コマごと
- 斬りの連続・反撃は、clip を `strike_at` で並べ、非接触の命中は `pos` を書く。最後の1発だけ `contact`(位置は anchor_dx で合わせる)
- **顔(目)は描かない**(ユーザー指示)。`look.eyes` は残してあるが呼ばない
- 落とし穴: モーションキャプチャの clip の角度は、関節ごとに 2π ずれて入っている(`np.unwrap`)。**読み込みで円の平均を中心に ±π へ収めてある**(`mocap.Clip`)。
  やらないと clip 同士・キーとのつなぎで 2π の飛びが出る。clip を選ぶときは、命中時に相手との間隔(root_x の差)が 0.7〜1.0 になる手の clip を試して選ぶ(02_07_s1 は届かず、13_17_s1 が届いた)

## 量産の道具(2026-10-19、「作品でなくスキルの向上」「YouTubeで継続」の指示から)

使う順番は、スキル `stickfigure-action`(`~/.claude/skills`、バックアップは `claude-skills/`)。ここは部品の一覧。

- 防御(`fight` の `block`、既定 true、hits≧3): 2発目を 受け止め `clash`(ガキィン・金属音・放射線。両腕を上げ腰を落として踏ん張り、少し押される)か かわし `miss`(風切りだけ。高い斬りは沈んでくぐり、低い斬りは後ろへ跳ぶ)。seed があれば選び、hits≧4 なら3発目にもう一方。見本 scenes/fight_dodge.yaml
- 全身の動き(`body_drive`、fight の `body`、既定1.7): 命中ごとに、攻め側は溜め(後ろへひねり・沈む)→ひねり込み・体重移動、受け側はのけぞり・ひねられ・腰が落ち・押される。ユーザー指摘「手だけ動いている」(2026-10-19)への対応。hits に by: A/B を書く(fight は自動)
- `fight.py`: 戦いの台本を数行の指定から自動で組む(`fight: {weapon(sword/dagger/staff/spear/none), kick, hits, counter, finisher, palette, stage, mood, colors, a_scale/b_scale, ally, seed, lines}`)。見本 `scenes/fight_*.yaml`。3人目の味方 `ally` は actors に C を足し、奥行き `y` をずらして置く(blender_player・影・字幕が y を見る。戦う2人の点検・カメラ追従は A/B だけ)
- `captions.py`(既定 off。fight の `captions: true` で出す。ユーザー指示で字幕なし): 台詞の吹き出し(`say`)・ナレーション(`narr`)・叫び文字(`shout`)。台本の `captions` か fight の `lines`
- `sfx.py`: 効果音と BGM を計算で作って動画に付ける(外部の音源は使わない)。台本の `audio: false` で無音、`mood` で雰囲気
- `episode.py`: 複数の場面+カード(タイトル・「一か月後」)を1本に連結。`python -m stickfig episode scenes/episodes/ep_revenge.yaml --out out/…`
- `story.py`: 物語の型(`revenge` 雪辱戦 / `tournament` 勝ち上がり / `duel` 一騎打ち / `protect` 守る戦い / `mentor` 師の教え)。episode.yaml に `story: {arc, hero, rival}`
- 舞台の色の組: 台本 `stage: {theme: cave|dojo|field|night|sunset}`(fight の `stage:`)。`blender_player.THEMES`
- 縦画面(ショート): 台本 `output: {aspect: vertical}`(720x1280。2人の中間を切り出し、字幕は切り出し後)
- `kit.py`: サムネイル(1280x720、字幕なしの見せ場のコマ+題名)と投稿の下書き(題名候補・概要欄・タグ。CMU 出典入り)。`python -m stickfig kit out/ep --title …`
- `series.py`: 何本ものエピソードを、型・名前・色・seed を変えてまとめて作る(`python -m stickfig series --n 5 --out out/series --build`)
- `review.py`: 書き出す前の自動点検(字幕の読む時間・筋・リズム。episode が自動で通す)。`preview.py`: Blender なしの線画の下書き(`episode --preview`)
- `rhythm.py`: 参考6本の範囲との比較。`check` が書き出す前に見積もり、`python -m stickfig rhythm 動画.mp4` が実測
- `build_scene(scene, out)`: cli の中核(台本 dict → 動画)。episode も使う

## Becker 風の見た目(2026-10-19、最近作を見て。観察は reference/becker_recent.md)

- 台本 `limb: {base: 0.055, tip: 0.03, tip_color: [r,g,b]}`: 手足が根元太→先細り、先の2節が暗色(Blender で作る。形を変えたら fk.py の寸法は影響しない太さだけ)
- `fx.weapon_glow: true`(`weapon_glow_color`): 刃の水色の画素から発光の縁を作る。fk の剣の線(`sk["sword"]`)は Blender の刃と向きがずれる場面があるので、描画の画素から取る
- 見本 `scenes/fight_becker.yaml`。fight の `fx` などは、台本で書いた分が土台に足し合わされる(`fight.expand`)

## 決まり・つまずき所(実際に踏んだもの)

1. **参考動画のファイル・切り出した画像は、リポジトリに入れない**(workspace は public、他人の作品)。入れてよいのは数字と読み取った角度だけ(`reference/`)。
2. **区間ごとのイーズで姿勢をつなぐと、要の姿勢ごとに速度が0になり「カクカク」する。** PCHIP で通す(`interp.py`、テストあり)。
3. **腕・脚を「直線2本」にすると関節で折れて硬い。** 6節の鎖に曲がりを配る(`blender_player.py` と `fk.py` の `chain_angles` は同じ式。片方だけ直さない)。
4. **腰を低くしただけだと、足が地面の下に潜る**(2026-10-18、最大36cm)。`Planter` が膝の曲げを足して接地させる。
   脚がほぼ伸びた所は膝の角度が急変するので、補正量にバネを掛けてある(掛けないと膝が1コマで1.6rad 飛ぶ)。
5. **「当たっている」ように見えても、高さがずれていると素通りに見える**(蹴りが敵の太ももを通っていた)。
   `contact` で逆算し、点検(`contact@…`)で距離を見る。
6. **ヒットストップは1〜3コマ**(参考は9割がそれ)。5コマ以上は間延びする。
7. **走りは周期運動**。点検の「止まる回数」は走りの区間を除いてある(折り返しに速度0が出るのが自然)。
8. 画像の色から人物の速度を測る方法(`reference/` の数字の出し方)は、人物が重なる・画面外へ出る場面でぶれる。
   自作の評価には使わず、plan の数字(`qa.py`)で見る。参考との比較は目安。
9. `blender_player.py` は bpy が要るので CI では回らない。形(寸法)を変えたら `fk.py` の定数も同じに直す。
10. 動画の「合成だけ」やり直すなら `build --reuse-figs`(人物PNGを再利用。plan が同じときだけ)。
11. 連続する命中は、放射線が重なって騒がしい。`compose.py` の `BURST_FRAMES`(斬りは7コマ)で調整する。

## 改善の回し方

1. 台本(または `pose.py` の周期・バネ)を直す → `python -m stickfig check` で合否
2. 通ったら `build` で動画を作り、**コマと動画で目視**(点検は機械的な不具合を先に潰すもの。気持ちよさは人の目が最終判断)
3. 参考と差が見つかったら、`reference/` に数字か角度を足し、`qa.py` のしきい値に反映して、次から自動で見る

## 関連

- ユーザーレベルの記憶: `stickfigure-channel-pipeline`(制作分担)、`stickfigure-reference-profile`(参考の数字)
- 一時的な試作(コードのみ・workspace 外): `dev/output/stickfigure/`(この基盤に取り込み済み。元のスクリプトは参照用)
