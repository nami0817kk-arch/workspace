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

- 相手から仕掛ける出だし(`fight` の `b_first`、蹴り無しのとき既定 true): B が先に2発(A が沈んでかわす miss → A が受け止める clash)、そのあと A の溜め→連打。`_ground_fix` は速いしゃがみで潜った脚を IK で地面に戻す最後の保険(plant: false なら触らない)
- 受けて返す(`fight` の `riposte`、既定 true): 受け止めの直後に B が打ち返し(clash by B、接触は contact で解く)、A が BLOCK で受ける。次の1発までの間を 0.40 空ける
- 足運び(`footwork`、fight では既定 on): 接地した足を世界座標に固定(`fk.leg_ik`)し、股が stride(0.42)を越えたら 5 コマで踏み替える。足滑りが A 37%/B 57% → 22%/21%(fight_dodge で測定)。空中・倒れ・走りの周期は触らない
- 防御(`fight` の `block`、既定 true、hits≧3): 2発目を 受け止め `clash`(ガキィン・金属音・放射線。両腕を上げ腰を落として踏ん張り、少し押される)か かわし `miss`(風切りだけ。高い斬りは沈んでくぐり、低い斬りは後ろへ跳ぶ)。seed があれば選び、hits≧4 なら3発目にもう一方。見本 scenes/fight_dodge.yaml
- 連打の中の蹴り(`mix_kick`、既定 true、hits≧3、seed があれば半々)と、踏み込みの前進(`lunge`: 接触を解かない命中で攻め側が前へ出て残る)
- 全身の動き(`body_drive`、fight の `body`、既定1.7): 命中ごとに、攻め側は溜め(後ろへひねり・沈む)→ひねり込み・体重移動、受け側はのけぞり・ひねられ・腰が落ち・押される。ユーザー指摘「手だけ動いている」(2026-10-19)への対応。hits に by: A/B を書く(fight は自動)
- `fight.py`: 戦いの台本を数行の指定から自動で組む(`fight: {weapon(sword/dagger/staff/spear/none), kick, hits, counter, finisher, palette, stage, mood, colors, a_scale/b_scale, ally, seed, lines}`)。見本 `scenes/fight_*.yaml`。3人目の味方 `ally` は actors に C を足し、奥行き `y` をずらして置く(blender_player・影・字幕が y を見る。戦う2人の点検・カメラ追従は A/B だけ)
- `captions.py`(既定 off。fight の `captions: true` で出す。ユーザー指示で字幕なし): 台詞の吹き出し(`say`)・ナレーション(`narr`)・叫び文字(`shout`)。台本の `captions` か fight の `lines`
- `sfx.py`: 効果音と BGM を計算で作って動画に付ける(外部の音源は使わない)。台本の `audio: false` で無音、`mood` で雰囲気
- `episode.py`: 複数の場面+カード(タイトル・「一か月後」)を1本に連結。`python -m stickfig episode scenes/episodes/ep_revenge.yaml --out out/…`
- `story.py`: 物語の型(`revenge` 雪辱戦 / `tournament` 勝ち上がり / `duel` 一騎打ち / `protect` 守る戦い / `mentor` 師の教え)。episode.yaml に `story: {arc, hero, rival}`
- 舞台の色の組: 台本 `stage: {theme: cave|dojo|field|night|sunset}`(fight の `stage:`)。`blender_player.THEMES`
- 縦画面(ショート): 台本 `output: {aspect: vertical}`(720x1280。2人の中間を切り出し、字幕は切り出し後)
- `kit.py`: サムネイル(1280x720、字幕なしの見せ場のコマ+題名)と投稿の下書き(題名候補・概要欄・タグ。CMU 出典入り)。`python -m stickfig kit out/ep --title …`
- `series.py`: 何本ものエピソードを、型・名前・色・seed を変えてまとめて作る(`python -m stickfig series --n 5 --out out/series --build`)。`--compile` で全話を題名カードつきの 1 本(`all.mp4`、長尺用)にもする。作成済みなら `--compile-only`
- 決め技(`fight` の `finisher`): `launch_slash`(決めの斬りで打ち上げ→空中斬り→叩きつけ)/`launch_kick`(決めは高い蹴り 75_16_s1 で胸を蹴り上げる)/`random`(seed で選ぶ。物語の型の決戦はこれ)/`none`
- `review.py`: 書き出す前の自動点検(字幕の読む時間・筋・リズム。episode が自動で通す)。`preview.py`: Blender なしの線画の下書き(`episode --preview`)
- `motion.py`: 動きの数字(`python -m stickfig motion scenes/x.yaml`): ひねり sd・足滑り・歩数・1コマの最大移動・攻防の内訳・接触の距離。「手だけ動いている」を数字で見つける
- `rhythm.py`: 参考6本の範囲との比較。`check` が書き出す前に見積もり、`python -m stickfig rhythm 動画.mp4` が実測
- `build_scene(scene, out)`: cli の中核(台本 dict → 動画)。episode も使う

## Becker 風の見た目(2026-10-19、最近作を見て。観察は reference/becker_recent.md)

- 台本 `limb: {base: 0.055, tip: 0.03, tip_color: [r,g,b]}`: 手足が根元太→先細り、先の2節が暗色(Blender で作る。形を変えたら fk.py の寸法は影響しない太さだけ)
- `fx.weapon_glow: true`(`weapon_glow_color`): 刃の水色の画素から発光の縁を作る。fk の剣の線(`sk["sword"]`)は Blender の刃と向きがずれる場面があるので、描画の画素から取る
- 見本 `scenes/fight_becker.yaml`。fight の `fx` などは、台本で書いた分が土台に足し合わされる(`fight.expand`)

- **舞台も2D**(2026-10-19 ユーザー「フィールドも2d」): `stage: {style: flat, theme: …}`(fight では既定)。Blender の立体の舞台を使わず、`look.flat_bg` が平らな帯・単色の柱・右の壁と、舞台ごとの切り絵の飾り(草原=丘と木、夜=月と星、夕焼け=夕日と山、道場=障子、洞窟=つらら岩。`_flat_props`)を PIL で描く(色は `look.FLAT_THEMES`)。stage の書き出しも飛ばす
- 演出のリズムは参考の範囲に入れてある(fight の既定): 閃光は決めの1発と大技だけ(`fx.flashes`)、2コマ撮りは全体(`stepping` に ranges なし、命中の前後 3 コマは 1 コマごと)。`check` の「演出のリズム」で見る
- 場面カードの色は、次の場面の舞台の色を暗くしたもの(`episode.build_episode`)
- **clip の継ぎ目の位置合わせ**(`plan._align_keys_to_clips`、`align_clips: false` で切る): 接触で決めた clip(`_solved`)は動かさず、その区間のキーは clip の値、前後 0.3 秒は台本の位置(キーの `_dx0`)との間をなめらかに寄せる(助走と戻り)。自由な clip(走り・pos 指定)は anchor をキーに寄せ、接触で決めた clip の直前なら終わりを次の始まりに合わせる(鎖)。この人物が関わる別の命中の瞬間はまたがない。**解く→合わせる を anchor が動かなくなるまで繰り返す**(最大 12 回。キーを平行移動する方式は 2 人が追いかけ合って発散したのでやめた)。点検 `teleport`(1 コマ 0.8 単位以上は 0 まで)、接触の距離は出来上がりのコマで測り直す(`contacts`)。走りの clip は区間の終わりで位置を止める
- **モーションキャプチャの clip は、突く瞬間の手と先端の向きで選ぶ**(`fight.STRIKES`、2026-10-19 に fk で測った): 02_xx はボクシングのパンチで、剣を持たせると刃が真下を向く。剣は 76_01_s1(水平の突き)・90_05_s2(前へ振る)・13_17(高く)。先端の高さに合わせて狙う点を変える(低い clip は腰、高い clip は頭)。長い武器(棍・槍)は相手の拳が届かないので反撃・受け返し・先に仕掛けるは無し
- 相手の連打(`fight` の `b_combo`、既定 2、長い武器では無し): A の決めの1発の前に B が打ち返す(1発目は A がくぐってかわす=狙いは頭の上 `offset`、2発目は A が受け止める)。かわされる1発も接触で位置を決める(点検 `contact` は kind=miss を飛ばす)
- **位置の決め方で学んだこと(2026-10-19)**: 続けざまの clip の間は「前の終点の位置を保ち、次の始点の 0.3 秒前から動く」。終点から始点へすぐ直線で動かすと、A の斬り(B との間合い 1.3)の最中に B が反撃の間合い(0.8)へ寄り始め、2人で左へ流れていった(B root 3.0 → 0.2)。反撃は命中の 0.40 秒後(踏み込みの時間)。解く→合わせる が行ったり来たりしたら anchor を半分だけ動かす(収束)。B の拳の clip は dx_scale 0.3(踏み込みの移動を小さく)
- **命中のコマでは体の動き(body_drive)を 0 に**: 攻め側の傾き・腰・前進、受け側の反応は命中の次のコマから。前進(lunge)・押され(pushback)は次の命中の 2 コマ前までに戻す。これを守らないと接触を解いた位置が崩れ、剣先が 0.3〜0.6 浮く

- 冒頭の対峙(fight の既定): 0.42 秒で 2 人が一歩ずつ踏み出し、0.5 秒に止め絵(pose、カメラが寄る)→ A が走り出す
- **走りの clip の輪の継ぎ目(2026-10-19 に発見)**: 最後のコマ→最初のコマを補間する 1 コマで dx が 1 周ぶん(2.8)後ろへ飛んでいた(`mocap.Clip.sample`)。最初のコマの dx は 1 周進んだ値として補間する。走りの区間で 0.73 秒ごとに 1 コマ後ろへ飛ぶ・区間の入りで 2 単位飛ぶ原因だった

## 2D アニメの動きの質(2026-10-19 夜、「物語は後でいいから動きの質を」の指示から。全部 fight の既定・plan の仕組みに入れてある)

実写の動き(mocap)をそのまま再生すると「ゆっくり振りかぶって、ふつうに振る」で、コマ送りすると構えのまま数コマ止まり、刃が 2 コマで出て、命中は効果に埋もれていた。
アニメの原則(溜め→一気→振り抜き、弧、伸び切り)を **姿勢を変えずに時間と上乗せで作る**。検証は `scenes/study_slash.yaml`・`study_kick.yaml`(`fight: {camera: fixed}` でカット・反転・連打カット無し。コマ送りで見るための場面。直しは共通側に入れる)。

- **間(`clip_timing`、fight の `timing: true`)**: `strike_at` のある clip の時間配分を変える(`plan.ClipBank.warped_u`)。命中の前 0.4 秒(連打の 2 発目以降は 0.3): 最初の 35% で振りかぶりの 53% まで、次の 50% はほぼ止め(溜め)、最後の 15%(1〜2 コマ)で残り 42% を一気に。命中の後 0.3 秒: 最初の 25% で 55%(振り抜き)、あとはゆっくり。命中の瞬間の u は変えない(接触の解きと一致)
- **振りかぶりの引き・振り抜きの行き過ぎ(`antic_phase`)**: 溜めの間、打つ腕(脚)を後ろへ引き(0.45 rad)・体を反らし・腰を沈める。命中の直後は腕が行き過ぎてから戻る。時間配分だけだと「構えのまま止まる」で振りかぶりに見えなかった
- **振りの誇張(fight の `exaggerate: 1.25`)**: 命中の clip の腕の角度を平均からの差で 1.25 倍(`amp`)
- **命中は手足が伸び切ったコマ(clip の `reach: true`)**: mocap の strike は手首の最大速度のコマで、伸び切る 5〜6 コマ前。そこで接触を解くと 2 人の胴が重なった。`ClipBank.reach_shift` が前後 0.2 秒で先端が最も前へ出るコマを選ぶ(素手・蹴り。剣は先端で解くので変えない)
- **当て先は手の高さから自動(`target.point: auto`)**: 伸び切りに移すと拳の高さが STRIKES の表と合わず、腰を 0.45 沈めて合わせていた(深くしゃがんで突く絵)。腰/胸/頭のうち手の高さに最も近い所を狙う。素手の `hz_range` は 0.25 まで
- **体の表面を狙う(`contact.surface: 0.16`)**: 中心を狙うと拳が胴に潜る。手前の表面を狙うと腕が伸び切った間合いになる(命中後の間合い 0.33→0.49)
- **命中のあと**: 攻め側の前進(lunge)は 0.08(0.22 だと押される相手に追いついて胴が重なる)、当たった側の押されは 0.42
- **スミア(`compose._limb_smear`、`anime.smear`)**: 打つ側の、命中の 4 コマ前〜命中で、手(剣先)・足が身長比 0.12/コマ以上動いたコマに、前の位置と今の位置の間の中割り 3 枚を薄く描く(剣は刃の色で光らせる)。振りを 1〜2 コマにしたぶん、絵が「跳ぶ」のを埋める。押されて下がる足などには出さない(striker の窓だけ)。fk の剣先は Blender の刃と少しずれるので、しきい値は手と剣先の大きい方
- **物差し(`check`・`motion` の「キレ」)**: 命中ごとに 先端の速さの山(命中の 5 コマ前〜命中)÷ 溜めの区間(16〜7 コマ前)の平均。目安 4 以上。「待ち」は溜めの区間で止まっているコマ数、「間合い」は命中後 10 コマの 2 人の根元の距離の最小(0.55 を切ると胴が重なって見える)。連打の 2 発目以降は前の振り抜きが溜めの区間に掛かるので低く出る(1.5〜3)
- コマ表の作り方: `ffmpeg -i x.mp4 -vf "select='between(n,a,b)',crop=640:400:320:160,scale=320:-1,tile=10x2" -vsync 0 -frames:v 1 sheet.png`(ffmpeg は PATH に無い。`cli.find_ffmpeg()` で場所を取る)

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
