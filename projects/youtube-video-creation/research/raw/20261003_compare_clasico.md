# 取材の控え：クラシコの数字（バルセロナ対レアル・マドリード）2026-10-03

シリーズ「クラブ同士の比較」。過去に同じ題材は出していない（research/covered.yaml に clasico の行なし。scripts/ では
20260926_ll05_barcelona.md の「直近のタイトルは昨シーズンのリーグ。クラシコの勝利で決めたのは、初めてでした」と、
20261004_player_342229.md の「10月25日のクラシコで、大一番の相性を変えられるか」の各1行だけ。research/20260914b_derby.yaml はマンチェスター・ダービーで別題材）。
取り方：ESPN の API（site.api.espn.com / now.core.api.espn.com）、Wikipedia の原文（action=raw）、Transfermarkt と各サイトは Python requests。ブラウザは使っていない。

## 1. 次のクラシコ

- ESPN 2026-10-01「Clásico match ball for Barcelona vs. Real Madrid LaLiga clashes unveiled」
  https://www.espn.com/soccer/story/_/id/50075555/clasico-match-ball-barcelona-real-madrid-laliga-clashes-unveiled
  （本文は https://now.core.api.espn.com/v1/sports/news/50075555 で取得）
  > The next time that happens will be later this month, when Barça host Madrid at Camp Nou on Sunday, Oct. 25
  > Puma has revealed their new bespoke match ball that is to be used for the two league meetings
  > For the second year running, Puma has designed a special "ELCLASICO" ball
  > White with flashes of gold and black, the new ball is a custom variant of the official LaLiga 2026-27 match ball -- the Stellar Nitro Ultimate. It is an updated version of the inaugural Puma ELCLASICO model, a ball which was first used in October 2025.
  > On that day, Madrid beat Barça 2-1 at the Bernabéu thanks to goals from Kylian Mbappé and Jude Bellingham.
  > Barça have made a flying start to the 2026-27 season, winning all seven of their league games so far and scoring 31 along the way.
  - 本文の「Madrid are six points and three points below them」は文が崩れている。順位表（下）で6差を確かめた。
- 日程（ESPN のチーム日程 API、site.api.espn.com/apis/site/v2/sports/soccer/all/teams/83/schedule?fixture=true と /86/）
  - 2026-10-25T20:00Z Real Madrid at Barcelona（Spotify Camp Nou）。ラ・リーガ 2026-27
  - 2027-05-09T18:00Z Barcelona at Real Madrid（Santiago Bernabéu）
  - Transfermarkt の対戦一覧（下）も「26/27 LaLiga 10 H 25/10/2026 9:00 PM」「26/27 LaLiga 35 A 09/05/2027」→ 第10節と第35節
  - 時刻：10/25 は欧州の夏時間が終わる日（UTC 01:00 に CET へ）。20:00Z＝現地21:00＝日本時間10月26日（月）朝5時
- それまでの日程（同じ API）
  - バルセロナ：10/10 ヘタフェ（H）／10/13 ガラタサライ（A、CL）／10/17 ベティス（A）／10/20 パリ・サンジェルマン（A、CL）
  - レアル：10/10 ビジャレアル（H）／10/14 ローマ（A、CL）／10/18 セビージャ（H）／10/21 RBライプツィヒ（H、CL）
  - 日付は UTC。ESPN の日付で書く（日本時間ではずれることがある）ので、台本では「リーグ戦2試合とチャンピオンズリーグ2試合」と数だけ言う

## 2. 通算の対戦成績（数え方が3通り）

| 数え方 | 試合 | レアル勝 | 分 | バルサ勝 | 得点（レ-バ） | 出典 |
|---|---|---|---|---|---|---|
| 公式戦。1902年のコパ・デ・ラ・コロナシオンを含む | 264 | 106 | 52 | 106 | 444-441 | 英語版Wikipedia（updated 10 May 2026）、FC Barcelona 公式（2026-05-12）、365Scores（2026-05-10） |
| 公式戦。1902年を含まない（スペイン連盟が公式と認めていない） | 263 | 106 | 52 | 105 | 443-438 | スペイン語版Wikipedia（Datos actualizados al último partido jugado el 10/5/2026） |
| 親善試合も含む | 307 | 112 | 64 | 131 | 500-547 | 英語版Wikipedia「Exhibition games 43試合 6-25-12」を足した行 |

- 英語版Wikipedia El Clásico（action=raw）https://en.wikipedia.org/wiki/El_Cl%C3%A1sico
  - 「All competitions 264 || 106 || 106 || 52 || 444 || 441」（列は 試合・RMA勝・BAR勝・分・RMA得点・BAR得点）
  - 大会別：La Liga 192 80-77（分35）309-312／Copa del Rey 38 13-17（分8）71-71／Copa de la Liga 6 0-2（分4）8-13／Supercopa 19 10-7（分2）42-32／UCL 8 3-2（分3）13-10／Copa de la Coronación 1 0-1（3-1でバルサ）
  - 注：「Although not recognized by the current Royal Spanish Football Federation as an official match, it is still considered a competitive match between Barcelona and Real Madrid by statistics sources」
  - Exhibition games 43 || 6 || 25 || 12 || 56 || 106 ／ All matches 307 || 112 || 131 || 64 || 500 || 547
  - 「Most consecutive matches without a draw: 21 | 1 March 2020 – 10 May 2026 (ongoing)」
  - Top scorers：メッシ26、ディ・ステファノ18、C・ロナウド18
- スペイン語版Wikipedia El Clásico（action=raw）https://es.wikipedia.org/wiki/El_Cl%C3%A1sico
  - 「Total 263 || 106 || 52 || 105 || 443 || 438」（列は 試合・RMA勝・分・FCB勝・G.RMA・G.FCB）
  - 「La Copa de la Coronación no figura en estas estadísticas. «La RFEF ya había manifestado que no la reconocía…»」
  - 「Último partido sin goles: 18 de diciembre de 2019 (Jornada 10 de la Liga 2019-20)」
- FC Barcelona 公式 2026-05-12「FC Barcelona match Real Madrid for Clásico wins」
  https://www.fcbarcelona.com/en/football/first-team/news/4502686/fc-barcelona-match-real-madrid-for-clasico-wins
  > Barça also pulled level with Real Madrid in all-time Clásico victories. They now have 106 each.
  > win number 106, matching Real Madrid's total. Add in 52 draws, and the overall tally now stands at 441 goals scored by Barça and 444 by Madrid.
  > Barça actually held the edge after the first 13 meetings (seven in the cup and six in the league) with six wins to Real Madrid's five, plus two draws. But by the 1931/32 season the balance had evened out, and from 1932/33 onward the all-whites began to take control of the rivalry.
  > It wasn't until 2012 that Barça finally drew level again, thanks to a 2-1 win at the Bernabéu in the Copa del Rey … That result made it 86 wins each
  > On 2 March 2019, Ivan Rakitić's goal secured a 1-0 league win at the Bernabéu, putting the blaugrana ahead 96-95
  > But a run of five straight Real Madrid victories soon reopened a small gap.
  > Including last season, Flick has now faced Real Madrid seven times and boasts a remarkable record: six wins and just one defeat.
- FC Barcelona 公式 2026-05-12「Four of the last five titles won against Real Madrid」
  https://www.fcbarcelona.com/en/football/first-team/news/4502224/four-of-the-last-five-titles-won-against-real-madrid
  > Only Johan Cruyff with 9 wins in 25 matches and Pep Guardiola with 9 in 15 matches have won more Clásicos than Hansi Flick.
  > Over the last two seasons Barça have faced Real Madrid in two Spanish Super Cup finals, a Copa del Rey final and most recently in Sunday's league decided at Spotify Camp Nou.
- 365Scores 2026-05-10「Barcelona vs Real Madrid: Historial tras el Clásico」https://www.365scores.com/es/news/barcelona-vs-real-madrid-historial-2/
  - 表「Victorias Barcelona 106 / Victorias Real Madrid 106 / Empates 52」
  - 「La paridad es tal que el próximo enfrentamiento oficial definirá quién toma la delantera en esta carrera histórica.」
- **食い違い**：El Diario NY 2026-05-10 https://eldiariony.com/2026/05/10/historial-barcelona-vs-real-madrid-quien-ha-ganado-mas-clasicos/
  は「265試合、バルサ107勝・レアル106勝、得点443-444」「リーグ戦193試合 80-78」と書く。英語版Wikipedia のリーグ戦の一覧は5/10の試合を192試合目として数えており、
  クラブ公式も「106 each」なので、5/10の試合を二重に数えたものと見て使わない。
- **台本での扱い**：主に使うのはクラブ公式と同じ数え方（264試合・106勝52分106敗・444対441）。1902年を除く数え方（レアル1勝リード）と親善試合込み（バルサ131勝・レアル112勝）を「数え方で変わる」として並べる。

## 3. 直近10試合（公式戦）

英語版Wikipedia「List of El Clásico matches」（action=raw）と Transfermarkt の対戦一覧
https://www.transfermarkt.com/vergleich/bilanzdetail/verein/131/gegner_id/418 （日付・大会・スコア・観客数）で突き合わせ、全部一致。

| 日付 | 大会 | 会場 | スコア（勝った側） | 得点者 |
|---|---|---|---|---|
| 2026-05-10 | リーグ第35節 | カンプ・ノウ（観客62,213） | バルサ 2-0 | ラッシュフォード9分、フェラン・トーレス18分 |
| 2026-01-11 | スーペルコパ決勝 | ジッダ | バルサ 3-2 | ラフィーニャ2、レヴァンドフスキ／ヴィニシウス、ゴンサロ・ガルシア |
| 2025-10-26 | リーグ第10節 | ベルナベウ | レアル 2-1 | エムバペ、ベリンガム／フェルミン |
| 2025-05-11 | リーグ第35節 | モンジュイック | バルサ 4-3 | エリック・ガルシア、ヤマル、ラフィーニャ2／エムバペ3 |
| 2025-04-26 | 国王杯決勝（延長） | セビージャ | バルサ 3-2 | ペドリ、フェラン、クンデ116分 |
| 2025-01-12 | スーペルコパ決勝 | ジッダ | バルサ 5-2 | |
| 2024-10-26 | リーグ第11節 | ベルナベウ | バルサ 4-0 | レヴァンドフスキ2、ヤマル、ラフィーニャ |
| 2024-04-21 | リーグ第32節 | ベルナベウ | レアル 3-2 | |
| 2024-01-14 | スーペルコパ決勝 | リヤド | レアル 4-1 | ヴィニシウス3、ロドリゴ |
| 2023-10-28 | リーグ第11節 | モンジュイック | レアル 2-1 | ベリンガム2 |

- 10試合でバルサ6勝・レアル4勝・引き分け0。得点はバルサ26・レアル20（自分で足した：1+1+2+4+5+3+4+1+3+2／2+4+3+0+2+2+3+2+2+0）
- 2020-03-01 から 2026-05-10 までの21試合はすべて決着（Transfermarkt の一覧で数え直して21。延長で決まった2試合を含む）。最後の引き分けは 2019-12-18 リーグ 0-0（カンプ・ノウ）
- レアルがカンプ・ノウで最後に勝ったのは 2023-04-05 国王杯準決勝第2戦 0-4（Transfermarkt：観客94,902、Wikipedia：Barcelona 0–4 Real Madrid、ベンゼマのハットトリック）。
  その後のバルサのホームは 2023-10-28（モンジュイック、レアル2-1）、2025-05-11（モンジュイック、バルサ4-3）、2026-05-10（カンプ・ノウ、バルサ2-0）
- フリック監督のクラシコ：7試合6勝1敗（クラブ公式）。唯一の負けは 2025-10-26 ベルナベウ
- モウリーニョ監督の前回のクラシコ：2013-03-02 リーグ（レアル2-1、Transfermarkt の一覧）。2026年6月にレアルの監督に戻った（ll17 の取材：realmadrid.com comunicado-oficial-mourinho-11-06-2026）。**台本では使わなかった**（監督の比べは見立ての芯ではないため）

## 4. 今季ここまで（10/3 時点。代表ウィークでクラブの試合は 10/10 まで無い）

- ESPN 順位表 API https://site.api.espn.com/apis/v2/sports/soccer/esp.1/standings
  - 1位 バルセロナ 7試合 7勝0分0敗 得点31 失点7 得失点+24 勝ち点21
  - 2位 アトレティコ 16、3位 ベティス 16
  - 4位 レアル・マドリード 7試合 5勝0分2敗 得点18 失点8 得失点+10 勝ち点15
- FotMob（src/standings.fetch('spain')、fotmob.com/api/data）：Barcelona 7-7-0-0 +24 21／Real Madrid 7-5-0-2 +10 15。ESPN と一致
- 試合ごと（ESPN の試合の summary API、boxscore の totalShots / shotsOnTarget / possessionPct）
  - バルセロナ：エルチェ 5-0（A、シュート11）／アスレティック 2-0（H、22）／ラージョ 5-2（H、26）／バレンシア 5-0（A、25）／レバンテ 4-2（A、12）／ラシン 7-2（H、30）／セビージャ 3-1（A、24）
    - 合計 シュート150（1試合21.4）、枠内58、打たれたシュート51（7.3）、打たれた枠内22、保持率の平均68.6%
  - レアル：エスパニョール 2-1（A、21）／ソシエダ 4-1（H、20）／マラガ 4-0（H、19）／ベティス 0-1（A、20）／ラージョ 4-1（H、24）／エルチェ 3-2（A、20）／アトレティコ 1-2（A、8）
    - 合計 シュート132（18.9）、枠内53、打たれたシュート89（12.7）、打たれた枠内31、保持率の平均52.6%
    - アウェーは4試合2勝2敗（負けはベティスとアトレティコ）。ホームは3戦3勝
    - アトレティコ戦は保持率39.1%、シュート8本、打たれたシュート18本
  - 点になった割合（自分で割った）：バルサ 31/150＝20.7%、レアル 18/132＝13.6%
- 数字は ESPN の試合記録から自分で足したもの。台本では「今季のリーグ戦7試合」と言う

## 5. 写真

- 01.jpg（＋01_w・01_v）：FC Barcelona 公式（4502686 の og:image、2026-05-10 のクラシコ。カンプ・ノウの電光掲示板に「2」「REAL MADRID」。フェルミン・ガビ・ダニ・オルモが喜ぶ）。代理店の透かしなし
- 02.jpg：FC Barcelona 公式（4502224 の og:image、同じ夜の優勝の場面）
- 03.jpg：レアル公式（2026-09-12 ラージョ戦の記事、エムバペが両手を広げる）。03 の切り抜き（_w は頭頂が縁に接し、_v は顔が外れた）は使わない
- 04.jpg：レアル公式（同じ記事、得点を喜ぶ輪。7番ヴィニシウス・5番ベリンガム）
- scene.jpg：Commons「File:El Clásico match.jpg」CC BY-SA 2.0 / Jan S0L0（ベルナベウでの過去のクラシコ。試合は特定しない）
- 下地の写真：assets/backgrounds/stadium_バルセロナ_in.png（ll05 で使ったカンプ・ノウの中。クレジットは assets/backgrounds/credits.json）

## 6. 確かめられなかったこと

- 10/25 の日本での中継の有無・放送局（台本に入れない）
- レアル公式が通算成績をどう数えているか（クラブ公式はバルサ側しか見ていない）
- 両監督の今季の発言でクラシコに触れたもの（当たっていない。本人の言葉は台本に入れていない）
