# 材料の控え（2026-10-07 シリーズ「仕組みの解説」、key: explain_callup）

題（ユーザーが○）：アジアカップで久保建英は最大11試合いなくなる？代表の招集とクラブのルール
集めた日: 2026-10-06〜07（WebFetch・WebSearch・Python requests のみ。ブラウザは使っていない）

## 1. 規定の原文（一次情報）

### FIFA Regulations on the Status and Transfer of Players（RSTP）
- 現行版: https://digitalhub.fifa.com/m/696d877ea35ca761/original/Regulations-on-the-Status-and-Transfer-of-Players-January-2026-edition.pdf
  （ファイル名は January-2026-edition。表紙は「JANUARY 2025」。第29条「approved by the Bureau of the FIFA Council on 22 December 2024 and come into force on 1 January 2025」。付属文書1は p.56〜64）
- 2027年版: FIFA Legal Handbook 2026（September edition 2026）収録。
  https://digitalhub.fifa.com/asset/5c0e740b-0810-4349-a7ba-256b16bda300/FIFA-Legal-Handbook-2026.pdf
  第29条「These regulations were approved by the Bureau of the Council on 10 June 2026 and come into force on 1 January 2027.」
  → **付属文書1（Annexe 1）の第1〜6条は現行版と一字一句同じ**（下の原文を両方で突き合わせた）。
  解放の始まり（2026-12-28）は現行版、大会中（2027-01）は2027年版の下だが、中身は変わらない。

#### Annexe 1 第1条「Principles for men's football」（原文）
- 1項: "Clubs are obliged to release their registered players to the representative teams of the country for which the player is eligible to play on the basis of his nationality if they are called up by the association concerned. Any agreement between a player and a club to the contrary is prohibited."
- 2項: "The release of players under the terms of paragraph 1 of this article is mandatory for all international windows listed in the international match calendar (cf. paragraphs 3 and 4 below) as well as for the final competitions of the FIFA World Cup™, the FIFA Confederations Cup and the championships for "A" representative teams of the confederations, subject to the relevant association being a member of the organising confederation."
- 3項: "...Following the publication of the international match calendar only the final competitions of the FIFA World Cup™, the FIFA Confederations Cup and the championships for "A" representative teams of the confederations will be added."
- 4項: "An international window is defined as a period of nine days starting on a Monday morning and ending on Tuesday night the following week ... a maximum of two matches ..."
  4項 i.: "The international window of September-October as from 2026 shall consist of a period of 16 days, during which a maximum of four matches may be played by each representative team."
- 6項: "It is not compulsory to release players outside an international window or outside the final competitions (as per paragraph 2 above) included in the international match calendar. It is not compulsory to release the same player for more than one "A" representative team final competition per year."
- 7項: "...For a final competition in the sense of paragraphs 2 and 3 above, players must be released and start the travel to their representative team no later than Monday morning the week preceding the week when the relevant final competition starts and must be released by the association in the morning of the day after the last match of their team in the tournament."
- 8項: "The clubs and associations concerned may agree a longer period of release or different arrangements with regard to paragraph 7 above."
- 9項: "Players complying with a call-up ... shall resume duty with their clubs no later than 24 hours after the end of the period for which they had to be released. This period shall be extended to 48 hours if the representative teams' activities concerned took place in a different confederation to the one in which the player's club is registered. Clubs shall be informed in writing of a player's outbound and return schedule ten days before the start of the release period."
- 10項: 戻りが遅れたら、クラブの申し立てで Players' Status Chamber が次の招集の解放期間を短くできる "b) final competition of an international tournament: by five days."
- 11項: 繰り返せば "a) issue a fine; b) further reduce the period of release; c) ban the association from calling up the player(s) for subsequent representative-team activities."

#### Annexe 1 第2条「Financial provisions and insurance」
- 1項: "Clubs releasing a player in accordance with the provisions of this annexe are not entitled to financial compensation."
- 2項: 旅費は呼ぶ協会が持つ。
- 3項: "The club with which the player concerned is registered shall be responsible for his insurance cover against illness and accident during the entire period of his release."
- 4項: 代表の「A」の試合のための解放中のけがで一時的に全く働けなくなったら "the club ... will be indemnified by FIFA"（Technical Bulletin – Club Protection Programme）。

#### Annexe 1 第3条「Calling up players」
- 1項: "As a general rule, every player registered with a club is obliged to respond affirmatively when called up by the association he is eligible to represent on the basis of his nationality to play for one of its representative teams."
- 2項: "Associations wishing to call up a player for the final competition of an international tournament must notify the player in writing at least 15 days before the beginning of the relevant release period. The player's club shall also be informed in writing at the same time. ... The club must confirm the release of the player within the following six days."

#### Annexe 1 第4条「Injured players」
- けがや病気で応じられない選手は、協会が求めれば協会の選んだ医師の診察を受ける。

#### Annexe 1 第5条「Restrictions on playing」
- "A player who has been called up by his association for one of its representative teams is, unless otherwise agreed by the relevant association, not entitled to play for the club with which he is registered during the period for which he has been released or should have been released pursuant to the provisions of this annexe, plus an additional period of five days."

#### Annexe 1 第6条「Disciplinary measures」
- "Violations of any of the provisions set forth in this annexe shall result in the imposition of disciplinary measures to be decided by the FIFA Disciplinary Committee based on the FIFA Disciplinary Code."

### FIFA Men's International Match Calendar 2023-2030（April 2026 版）
https://digitalhub.fifa.com/m/3123d37097318f7f/original/Men-s-International-Match-Calendar-2023-2030_EN.pdf
- 2027 の頁: "7 January – 5 February　AFC Asian Cup　AFC"（注記なし）。
- 2025・2026 の頁の注: "* The mandatory release period for the CAF Africa Cup of Nations 2025 starts on Monday, 15 December 2025"
  → アフリカ・ネイションズカップ2025（12/21 日曜開幕）は第1条7項どおりなら 12/8（月）。FIFA が1週間遅らせた。報道（Guardian Nigeria・theScore 等、2025-12 初め）も「8日→15日」。
- アジアカップ2027には同じ注が無い → 第1条7項どおり **2026-12-28（月）の朝** が解放の始まり。

## 2. アジアカップ2027 の日程
- AFC が決めた日程：2027-01-07〜02-05、サウジアラビア（リヤド・ジェッダ・アルホバル、8会場）。FIFA の暦（上）とも一致。
- 組分け（2026-05-09 抽選）と試合日（英語版Wikipedia「2027 AFC Asian Cup」、AFC の発表の写し。https://en.wikipedia.org/wiki/2027_AFC_Asian_Cup ）
  - 日本はF組（F1）。1/11 日本－インドネシア、1/16 タイ－日本、1/20 日本－カタール。
  - 16強: F組1位は 1/24（第41試合、E組2位と）。8強: 第46試合 1/28（W38 対 W41）。4強: 第49試合 2/1。決勝: 2/5（リヤド、キング・ファハド）。
  - F組2位は 16強 1/24（第42試合）→ 8強 1/29（第48試合）→ 4強 2/2（第50試合）。
- 大会は 1/7（木）開幕。開幕の週は 1/4（月）〜1/10（日）。その前の週の月曜＝**12/28（月）**。開幕の10日前、日本の初戦の14日前。
- 第3条2項：知らせは解放の15日前まで＝**12/13**。クラブの返事はそこから6日以内＝12/19。
- 第5条：日本が決勝なら 12/28〜2/6朝＋5日＝**2/11まで**。12/28〜2/11 は46日（大会の30日より16日長い）。

## 3. 欧州のクラブの日程（2026-27。FotMob のリーグ日程 API、10/6 取得。research の取り方は tools/next_opponent.py と同じ）
- 数えた期間：**2026-12-28〜2027-02-05**（日本が決勝まで進んだ場合に解放の期間に重なる日。2/6 以降は代表を離れたあと）。
- プレミア（FotMob 47）: 第18節 12/29・30／第19節 1/1〜3／第20節 1/5〜7／第21節 1/16／第22節 1/23／第23節 1/30 → **6試合**（第24節 2/6）。
  - 公式：premierleague.com「All 380 fixtures for 2026/27」（6/19 公開）。1/5（火）にブライトン－ボーンマス、サンダーランド－リバプール等（検索の要約で確認）。
  - FA杯3回戦は 1/9（土）（thefa.com round dates：Third Round Proper "Saturday 9 January 2027"、4回戦 2/13）。
- ラ・リーガ（87）: 第18節 1/3／第19節 1/10／第20節 1/17／第21節 1/24／第22節 1/31 → **5試合**（第23節 2/7。日付は FotMob の仮置き＝週末の日曜）。
- ブンデス（54）: 第14節 12/19 のあと、第15節 1/9／第16節 1/12（火）／第17節 1/16／第18節 1/23／第19節 1/30 → **5試合**。12/20〜1/8 は試合なし。
- リーグ・アン（53）: 第15節 1/2・3／第16節 1/16／第17節 1/23／第18節 1/30 → **4試合**。
- 欧州カップ（FotMob 42/73/10216）:
  - CL 第7節: 1/19 インテル－リバプール、1/19 リール－スロヴァン・ブラチスラヴァ、1/20 マンU－バイエルン。第8節: 1/27 リバプール－ランス、バイエルン－ベティス、ローマ－リール。
  - EL 第7節: 1/21 ソシエダ－ヴィクトリア・プルゼニ、クリスタル・パレス－スパルタ・プラハ、ヤギェウォニア－リヨン。第8節: 1/28 ユヴェントス－ソシエダ、ザルツブルク－パレス、リヨン－レヴァークーゼン。
  - ECL（ブライトン・モナコ等）は1月の試合なし。フランクフルトは1月の欧州の試合なし。

### 日本人選手ごとの数（自分で数えた。所属は config/japan_abroad.yaml＝Transfermarkt 2026-27）
| 選手 | クラブ | リーグ | 欧州 | 計 |
|---|---|---|---|---|
| 遠藤航 | リバプール | 6 | 2（CL） | 8 |
| 鎌田大地 | クリスタル・パレス | 6 | 2（EL） | 8 |
| 久保建英 | レアル・ソシエダ | 5 | 2（EL） | 7 |
| 伊藤洋輝 | バイエルン | 5 | 2（CL） | 7 |
| 三笘薫 | ブライトン | 6 | 0 | 6 |
| 上田綺世 | リール | 4 | 2（CL） | 6 |
（堂安律 フランクフルト 5・0・5、中村敬斗 リヨン 4・2・6、南野拓実 モナコ 4・0・4 は表に入れていない）
- 招集されるかは分からない（代表は 12/13 までに知らせる）。「招集されれば」の数。

### ソシエダ（久保）の1月
- 国王杯 2026-27（英語版Wikipedia「2026–27 Copa del Rey」の Schedule。elgoldigital 6/30 も RFEF の発表として同じ日付）: 2回戦 12/2、**32強 12/16、16強 1/6、8強 1/13**、準決勝 2/10・3/3、決勝 4/24。ソシエダは前回王者・スーパーカップ組なので32強から。
  - ソシエダが前回王者：2026-04-18 決勝でアトレティコに勝った（ESPN の試合記録、Wikipedia の脚注）。
- スーパーカップ2027（英語版Wikipedia「2027 Supercopa de España」、RFEF の見出し「Semi Final draw: Barça-Atlético and Real Sociedad-Real Madrid」）: トルコ・イスタンブール、**準決勝 2/3 ソシエダ－レアル・マドリード（ベシクタシュの競技場）**、決勝 2/6（RAMS Park）。サウジアラビアがアジアカップの開催国のため移した。rfef.es は 403 で本文は読めず、見出しと検索の抜粋まで。
- 日本の勝ち上がりごとの数（12/28〜日本の最後の試合の日まで。国王杯は勝ち進んだ場合）:
  | 日本の最後の試合 | 重なる試合 | うちリーグ戦 | 中身 |
  |---|---|---|---|
  | 1次リーグ 1/20 | 5 | 3 | L 1/3・杯 1/6・L 1/10・杯 1/13・L 1/17 |
  | 16強 1/24 | 7 | 4 | ＋EL 1/21・L 1/24 |
  | 8強 1/28 | 8 | 4 | ＋EL 1/28 |
  | 4強 2/1 | 9 | 5 | ＋L 1/31 |
  | 決勝 2/5 | 10 | 5 | ＋スーパーカップ準決勝 2/3 |
  - 決勝の翌日 2/6 にスーパーカップの決勝（勝ち上がれば）→ **11**。規則上は 2/6 の朝に代表を離れられるが、リヤドで前夜に決勝を戦った翌日の夜にイスタンブール。
- 題の「11」は、ソシエダが国王杯の32強・16強とスーパーカップ準決勝に勝ち、日本が決勝まで進んだ場合の最大。

## 4. 過去の大会で欠けた試合（Transfermarkt の試合記録 tmapi、participationState が "absent"＝代表で不在。10/6 取得）
### 2019年（UAE、1/5〜2/1。日本は準優勝）
- 柴崎岳（ヘタフェ）: L 1/6・杯 1/9・L 1/12・杯 1/15・L 1/18・杯 1/22・L 1/26・杯 1/29・L 2/2 → **9**
- 武藤嘉紀（ニューカッスル）: FA杯 1/5・L 1/12・FA杯 1/15・L 1/19・FA杯 1/26・L 1/29・L 2/2 → **7**
- 吉田麻也（サウサンプトン）: FA杯 1/5・L 1/12・FA杯 1/16・L 1/19・L 1/30・L 2/2 → 6（1/2 のリーグ戦には出ている）
- 堂安律（フローニンゲン）3、大迫勇也（ブレーメン）3、原口元気（ハノーファー）3、遠藤航・冨安健洋（シントトロイデン）2、南野拓実（ザルツブルク）0（冬休み）
### 2024年（カタール、2024/1/12〜2/10。日本は8強）
- 遠藤航（リバプール）: FA杯 1/7・リーグ杯準決勝 1/10・L 1/21・リーグ杯準決勝 1/24・FA杯 1/28・L 1/31・L 2/4 → **7**。解放の初日 1/1（月）の夜のニューカッスル戦には出場（played）。
- 久保建英（ソシエダ）: 国王杯 1/7・L 1/13・国王杯 1/17・L 1/20・国王杯 1/23・L 1/27・L 2/3 → **7**（1/2 のリーグ戦には出場）
- 守田英正（スポルティング）6、上田綺世（フェイエノールト）5、中村敬斗（スタッド・ランス）5、冨安健洋（アーセナル）4、堂安律 4、伊藤洋輝 4、南野拓実 4
### アフリカ・ネイションズカップ2025（モロッコ、2025/12/21〜2026/1/18）
- サラー（リバプール、エジプトは4位）: L 12/20・12/27・1/1・1/4・1/8・FA杯 1/12・L 1/17 → **7**
- ムベウモ、アマド・ディアロ（マンU）各5、ハキミ（PSG）4、オシムヘン（ガラタサライ）5

## 5. 精査（記事の言い換え → 原文）
- スペインの記事（FútbolFantasy 2026-10-01「La Copa Asia 2027 amenaza…」）は「liberación previo de 12 días」「12月26日ごろ」と書く。
  → **原文（第1条7項）は日数ではなく「開幕の週の前の週の月曜の朝」**。2027年は 12/28（開幕の10日前）。12日前は男子サッカーの規定に無い（フットサルの第1条ter 6項が「12 days before」）。台本は原文どおり 12/28。
- 同じ記事は 1/21 のプルゼニ戦を「Champions League」、スーパーカップ準決勝を「2月2日」と書く → FotMob では EL、準決勝は 2/3（2/2 はバルセロナ－アトレティコ）。台本は EL・2/3。
- 「断れない」は第1条1項（義務）と第5条（出られない＋5日）。「罰金」は第1条11項（戻りが遅れる違反を繰り返したとき）で、断ったときの罰そのものは第6条（懲戒委員会が FIFA懲戒規程で決める）。懲戒規程2026年版に「解放」を名指しした条は見当たらなかった → 台本は「懲戒委員会が処分を決める」まで。
- 補償：第2条1項「補償を受ける権利はない」。けがのときの FIFA の補償（第2条4項）は「A代表の試合のための解放中」「一時的に全く働けない」が条件 → 台本は「けがで長く離れれば」。
- 遠藤 2024/1/1：解放の初日に出場 → 第1条8項（クラブと協会で取り決めを変えられる）の例として「出てから合流した」と言える範囲。合意の中身そのものは確かめていない（台本は「出てから合流」まで）。
- 欧州の日程の日付は FotMob（リーグ発表の写し）。ラ・リーガ第19節以降の日付は週末の仮置きで、試合日が前後に1日ずれることはある（節の数は変わらない）。

## 6. 他人の声
- 本人・監督の言葉は取っていない（この回は規定が主役）。規定の原文を「国際サッカー連盟（規則の原文）」として2か所で訳して引く。
- ネットの反応は入れない（シリーズの回は無くてよい。同じ日のニュースの回 kubo_january が反応を入れている）。

## 7. 写真
- 01.jpg：Commons「File:Takefusa Kubo.jpg」（Ali Mohammed Mahdi、CC BY-SA 4.0、2026年アップロード、日本代表20番・AFC の袖章＝アジアカップの試合）。`portrait` で取得。01_w・01_v は facecrop。
- 同じ日のニュースの回（kubo_january）はゲキサカの写真（Yahoo! 経由）。重ならない。
