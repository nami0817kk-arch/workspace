# stickfigure — 棒人間アクションの制作基盤

棒人間のアクション(走る・蹴る・斬る・吹き飛ぶ)を、**台本(YAML)から動画まで、点検つきで作る**。
「日本のなぜ」(@nihonnaze)を棒人間＋グラフの型に転換するにあたり（2026-10-18）、見せ場の動きの質を、
参考(Alan Becker の棒人間アニメ)と見比べて見劣りしない水準に上げるために作った。
**動きの計算は純粋な Python、Blender は人物を書き出す再生係だけ。** 計算が CI でテストでき、不具合を数字で見つけられる。

## 流れ

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
