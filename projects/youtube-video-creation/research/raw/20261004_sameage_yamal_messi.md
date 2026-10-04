# ヤマルとメッシ、同じ19歳83日の時点の数字（key: sameage_yamal_messi、2026-10-04 取得）

調べ方: Transfermarkt の API（`tools/japan_abroad.py` の `_get` と同じ入口 https://tmapi-alpha.transfermarkt.technology）、
FotMob の API（`tools/fotmob_player.py`）、英語版 Wikipedia（API で wikitext を取得）、WebFetch で記事本文。ブラウザ不使用。
数えた控え（作業用スクリプト）は scratchpad の tm_count.py / tm_share.py / tm_next.py（試合ごとの記録を足しただけ）。

## 数え方（いちばん大事）
- **比べる日**: ヤマル（2007-07-13 生）は 2026-10-04 で **19歳83日**。メッシ（1987-06-24 生）の19歳83日は **2006-09-15**。
  「19歳と約3か月（2006年10月初め）」ではなく、**日数をそろえた**。10月初めまで延ばすとメッシのクラブは 43試合12点になる（9/17 ラシン戦・9/24・9/27 ブレーメン戦で1点・9/30）。
- **クラブ**: バルセロナの一軍（TM club 131）の公式戦で、出場1分以上。Bチーム（2464）・年代別（U19・アルヘンティーナU20 11940 など）は除く。親善試合は入っていない（TM の記録に無い）。
- **代表**: A代表（スペイン 3375／アルゼンチン 3437）の試合。親善試合（FS）は国際Aマッチなので含める。年代別（スペインU17 12395、アルゼンチンU20 11940）は除く。
- 日付は TM の試合日（UTC）。2006年の試合は1日ずれて入っているものがある（セルタ戦は実際は 8/27 だが TM は 8/28）。切る日の前後に試合が無いので、数には効かない。

## 19歳83日までの通算（Transfermarkt 試合ごとの記録）
| | ヤマル（〜2026-10-04） | メッシ（〜2006-09-15） |
|---|---|---|
| バルサ一軍 試合 | 159 | 39 |
| 先発 | 131 | 23 |
| 出場時間 | 11,890分 | 2,044分 |
| 得点 | 57（PK 7） | 11（PK 0） |
| アシスト | TM 58／**FotMob 51** | TM 6 |
| 90分あたりの得点 | 57×90/11890 = **0.43** | 11×90/2044 = **0.48** |
| 代表 試合・得点 | 36試合11点（2,577分） | 11試合2点（531分） |

- **アシストはヤマル紹介（10/2）の数字に合わせて FotMob の 51 を使う**（FotMob の careerHistory: Barcelona 159試合 57得点 51アシスト）。TM で数えると 58。メッシの 6 は TM（2006年の FotMob の試合ごとの記録は無い）。数え方の違うものが1行に並ぶが、差（51 対 6 か 58 対 6）の大きさは変わらない。台本ではアシストの行は数を読むだけで、倍率は言わない。
- 内訳（バルサ）: ヤマル リーガ108試合37点・CL34試合12点・国王杯11試合5点・スーパーカップ6試合3点。メッシ リーガ26試合9点・CL7試合1点・国王杯3試合1点・スーペルコパ2試合0点・UEFAスーパーカップ1試合0点。
- メッシの季ごと: 04/05 9試合1点（239分）、05/06 25試合8点5アシスト（1,414分）、06/07（9/15まで）5試合2点（391分）。
- ヤマルの季ごと（バルサのみ）: 22/23 1試合、23/24 50試合7点、24/25 55試合18点、25/26 45試合24点、26/27 8試合8点。

### ヤマル紹介（scripts/20261002_player_937958.md）との突き合わせ
- 紹介の通算表（2026年9月末まで）: バルサ 159試合57点51アシスト／スペイン代表 35試合10点／合計194試合67点。
- この回（10/4 時点）: バルサ 159試合57点51アシスト（**変わらない**。9/19 セビージャ戦のあとバルサの試合が無い）／スペイン代表 **36試合11点**。
  **差は 10/3 のネーションズリーグ、チェコ戦（アウェー3-1、先発45分・1点）の1試合1点**（TM と FotMob の直近5試合で確認）。台本では合計は言わない。

## デビューと初ゴールの年齢（生年月日から計算）
| | ヤマル | メッシ |
|---|---|---|
| バルサ一軍の初出場 | 2023-04-29 ベティス戦（7分、背番号41）＝15歳290日 | 2004-10-16 エスパニョール戦（8分、背番号30）＝17歳114日 |
| バルサ一軍の初得点 | 2023-10-08 グラナダ戦＝16歳87日 | 2005-05-01 アルバセテ戦（出場2分で得点）＝17歳311日 |
| A代表の初出場 | 2023-09-08 ジョージア戦（得点）＝16歳57日 | 2005-08-17 ハンガリー戦＝18歳54日 |
| A代表の初得点 | 同じ試合＝16歳57日 | 2006-03-01 クロアチア戦＝18歳250日 |
| W杯の初ゴール | 2026-06-21（TM。対戦相手 club 3807）＝18歳343日 | 2006-06-16 セルビア・モンテネグロ戦（6-0）＝18歳357日 |

- メッシのハンガリー戦: 英語版 Wikipedia "Career of Lionel Messi"「He came on in the 63rd minute, but was ejected from the match after two minutes for a perceived foul.」（BBC Sport 2005-08-22 を出典に引く）。
- メッシのリーガのデビュー: 同記事「Messi made his La Liga debut … on 16 October, against Espanyol」。
- ヤマルの W杯初ゴールの年齢は、ヤマル紹介の材料（research/raw/20261002_yamal_material.md「数字の食い違い」）で 18歳343日と計算済み。超WORLDサッカーの「18歳323日」は使わない。

## 18歳の季の前線（立場の比較。TM、バルサの公式戦）
| 季 | 選手 | 試合 | 先発 | 出場時間 | 得点 |
|---|---|---|---|---|---|
| 2005-06（メッシ18歳） | ロナウジーニョ | 45 | 45 | 3,914分 | 26（PK10） |
| | エトー | 47 | 47 | 4,181分 | 34 |
| | メッシ | 25 | 17 | 1,414分 | 8 |
| 2025-26（ヤマル18歳） | ヤマル | 45 | 42 | 3,702分 | 24 |
| | レヴァンドフスキ | 46 | 27 | 2,486分 | 19 |
| | ラフィーニャ | 33 | 27 | 2,194分 | 21 |

- メッシの 05/06 はバルサの公式戦57試合のうち出場25、負傷で18試合欠場（TM の participationState: injured 18）。
- 英語版 Wikipedia "Career of Lionel Messi":
  - 「Messi missed the start of La Liga, but on 26 September he acquired Spanish citizenship and became eligible to play. Wearing the number 19, he gradually established himself as the first-choice right winger, forming an attacking trio with Ronaldinho and striker Samuel Eto'o.」
  - 「Messi's season ended prematurely on 7 March 2006, when he suffered a torn hamstring. Messi worked to regain fitness in time for the 2006 Champions League final, but he was eventually ruled out.」
  - 「Rijkaard put Messi on the right flank, allowing him to cut into the centre of the pitch and shoot with his dominant left foot.」
- 英語版 Wikipedia "2005–06 FC Barcelona season": エトーはチーム最多の26点（リーガ）・全公式戦34点。この季に獲ったのはスーペルコパ・リーガ・CL。
- ヤマルの 25/26 は FotMob でも 45試合24点（アシストは FotMob 17／TM 18。台本ではこの季のアシストは言わない）。負傷で11試合欠場（TM）。
- 「この3人の中でいちばん長い」はレヴァンドフスキ・ラフィーニャとの比較だけ。チーム全体で1位かは数えていないので言わない。

## 19歳83日までに獲ったタイトル（FotMob の trophies）
| 大会 | ヤマル | メッシ |
|---|---|---|
| ラ・リーガ | 3（22/23・24/25・25/26） | 2（04/05・05/06） |
| チャンピオンズリーグ | 0 | 1（05/06。決勝は負傷で出ていない） |
| 国王杯 | 1（24/25） | 0 |
| スペイン・スーパーカップ | 2（24/25・25/26） | 2（05/06・06/07） |
| ユーロ／コパ・アメリカ | 1（ユーロ2024。決勝 7/14 は17歳1日） | 0 |
| ワールドカップ | 1（2026） | 0（2006 はチームが準々決勝で敗退） |
- 親善の大会（ジョアン・ガンペール杯）は数えない。メッシの UEFAスーパーカップ 2006 は敗戦（0-3 セビージャ）。
- メッシの年代別: 2005年の20歳以下の世界大会（FIFA World Youth Championship）で優勝、6点2アシストで最優秀選手（Golden Ball）。英語版 Wikipedia "Lionel Messi"。
- ヤマルのユーロ2024: 7試合1点4アシスト。W杯2026: 8試合1点1アシスト（決勝は120分、1-0）。メッシのW杯2006: 3試合1点1アシスト（TM）。

## メッシの次の1年（見立て）
- 2006-09-16〜2007-06-23（20歳の誕生日の前日まで）: バルサ 31試合27先発 2,372分 15点（TM）。
- その中に 2007-04-18 国王杯準決勝第1戦 ヘタフェ戦（5-2、76分、2点1アシスト）。英語版 Wikipedia "Career of Lionel Messi":
  「On 18 April, in a Copa del Rey match against Getafe, he ran 60 m (66 yd) with the ball, beating five defenders before scoring in a similar fashion to Maradona in his Goal of the Century.」「In 2019, Messi's goal against Getafe was voted Barcelona's best goal ever in a poll of the club's fans.」
- **ヤマルの次の試合**: 2026-10-11 バルセロナ対ヘタフェ（ラ・リーガ、FotMob の nextMatch）。TM の club id もヘタフェ 3709 で同じクラブ。
- ヤマルの20歳の誕生日 2027-07-13 まで、10/4 から 282日。

## 本人の言葉
1. メッシ（ヤマル17歳の 2025年4月、YouTube『Simplemente Fútbol』のインタビュー。ムンド・デポルティボが報道）
   サッカーダイジェストWeb 2025-04-19 https://www.soccerdigestweb.com/news/detail/id=171944
   > 「まだ17歳で、いままさに成長している最中だ。僕がそうだったように、これからも選手としてレベルアップを続け、さらにプレーに磨きをかけていくだろう。彼は信じられないほどの才能の持ち主であり、すでに世界最高の選手のひとりだ」
   - 検索の要約に出た「17歳の時点での完成度はヤマルのほうが上」は**本文に無い**（要約の作文）。使わない。
2. ヤマル（17歳、2025-04-29 CL準決勝インテル戦の前日会見）
   サッカーキング 2025-05-01 https://www.soccer-king.jp/news/world/cl/20250501/2013692.html
   > 「僕と同じくらいの年齢で、バルサのようなクラブでこれほど多くの試合に出場した選手はほとんどいないよね。」
   - 同じ会見の英語（Goal 2025-04-30 https://www.goal.com/en-us/lists/lamine-yamal-responds-to-lionel-messi-one-of-the-best-in-the-world-barcelona-wonderkid-no-such-thing-as-age-football/blt5f428ac9d2eec3df）: "I think few players at my age have played as many games as I have for Barca" / "In football, there is no such thing as age. If you're ready, you're ready." / "I don't compare myself with anyone, same with Messi… I admire Leo, he's the best in history."（後ろの2つは台本に使っていない）
- ヤマル紹介で使った言葉（「メッシは自分の道を歩んだ」ほか）は重ねない。

## 写真（Wikimedia Commons。代理店なし）
| 置き場 | File | 権利 | 撮影 | 中身 |
|---|---|---|---|---|
| messi2005 | File:Leo messi barce 2005.jpg | CC BY-SA 4.0 / Josep Tomàs | 2005-10-26 マラガ戦 | 18歳のメッシ、バルサのユニ。縦 1100x1567 |
| messi2007 | File:Lionel Messi 31mar2007.jpg | CC BY-SA 2.5 es / Darz Mol | 2007-03-31 | 19歳の顔。500x675（小さいので表の節だけ） |
| messi_getafe | File:Lionel Messi goal 19abr2007.jpg | CC BY-SA 2.5 es / Darz Mol | 2007-04-18 | ヘタフェ戦のドリブル（Wikipedia の記事でもこの場面の写真として使われている）。720x540 |
| yamal_esp | File:Lamine Yamal Argentina v Spain 19 July 2026-144.jpg | CC BY-SA 4.0 / Bryan Berlin | 2026-07-19 W杯決勝 | 赤の19番、立ち姿。横 |
| yamal_run | File:Lamine Yamal France v Spain 7.24.26-092.jpg | CC BY-SA 4.0 / Bryan Berlin | 2026-07-14 W杯準決勝 | 白の19番、走る。横 |
| pair | 上の yamal_esp と messi2005 を `tools/pairphoto.py` で並べた1枚 | | | 冒頭用 |
| yamal_thumb / messi_thumb | yamal_esp・messi2005 から上半身を切った | | | サムネ用 |
- 10/2 のヤマル紹介で使った写真（-214・-319・-167・-142・2025年のブルガリア戦）は使っていない。
- バルサのユニ姿のヤマルは Commons に 2026-03-07 アスレティック戦の倒れ込んだ1枚しか無い（顔が小さい）ので使わない。
