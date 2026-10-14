# 材料の控え A: キャリック（マンU）がシティの判定に答えた（key: city_carrick／2026-10-10 取材。**この本は本編も作る**）

## この本の軸（1行）

> **タイトルを失った側の当事者が、「取り返せない」と言った回。**
> 争った2季のどちらもマンUが2位で、キャリックは**対象9季の全部をユナイテッドの選手として過ごしていた**。
> 罰や処分の見通しを語る回ではない（それは B・C と重ならせない）。

- B（city_maresca）の軸：**告発されたクラブ自身の監督**が、就任92日で「上訴に勝ったときに話す」と言った回
- C（city_around）の軸：**メダルが懸かっている人と、1つも懸かっていない人**が、同じ日に別のことを言った回

---

## 0. 取材の条件と、依頼の前提の訂正（**先に読む**）

取り方: **WebSearch（URL を探すだけ）・WebFetch・python requests + pypdf** のみ。**ブラウザの道具は使っていない。**
ネットの反応は集めていない（指示どおり）。

**依頼の表に誤りが3つあった。言葉の持ち主を取り違えると本が成り立たないので、先に直す。**

| 依頼の表 | 正しい | 根拠 |
|---|---|---|
| マレスカ（**チェルシー**） | マレスカは**マンチェスター・シティの監督**（2026-06-29 就任、グアルディオラの後任） | Sky 見出し "Manchester City boss Enzo Maresca"／ESPN／英語版Wikipedia 2026–27 Premier League |
| シャビ・アロンソ（所属を書かず） | **チェルシーの監督**（2026-07-01 就任） | football365 10/9「Xabi Alonso (Chelsea manager)」／ESPN の監督一覧 |
| イラオラ（ボーンマスの含み） | **リヴァプールの監督**（2026-06-04 就任）。**10/11 にシティを迎える当事者**。ボーンマスはマルコ・ローゼ | football365 10/9「Andoni Iraola (Liverpool Manager)」／ESPN |

→ **A は「争った側のマンU」、B は「告発されたクラブ自身」、C は「周りと、元キャプテン・現選手」**という割り方になる。
C の「シャビ・アロンソとイラオラ」は**他リーグの第三者ではなく、同じリーグで同じ週に戦う監督**である。

**ロマーノの投稿の文面は、媒体の原文と一致しない行がある**（下 3-3）。移籍情報の記者の投稿なので、**台本には媒体の原文を使う。**

---

## 1. 何が起きたのか（事実の土台。**B・C はこの節を繰り返さない**）

### 1-1. 判定（2026-09-29）

一次情報は 2026-10-01〜10-03 に委員会の判断の黒塗り版 PDF（40ページ）まで辿って1行ずつ突き合わせてある。
**この回で土台を作り直さない。**控え: `research/raw/20261002_city_verdict.md`（10の告発の項ごと）・`research/raw/20261003_city_appeal.md`（控訴と規則）。

| 何 | URL |
|---|---|
| プレミアリーグ公式の声明（9/29） | https://www.premierleague.com/en/news/4727779/premier-league-statement-manchester-city-fc |
| 委員会の判断（Redacted Core Decision、40ページ） | https://resources.premierleague.pulselive.com/premierleague/document/2026/09/29/9bb3f063-6312-4d15-a1f1-77280d356a49/Premier-League-Manchester-City-independent-Commission-Redacted-Core-Decision.pdf |
| シティ公式の声明（9/29） | https://www.mancity.com/news/club/manchester-city-club-statement-premier-league-63926128 |

言ってよいのは、公開された文書で裏が取れる次の形だけ（**確定**）。

- **財務の規則をめぐる告発は、すべて認められた。調査への非協力は4つのうち3つが認められた**
  （判断7項 "we found each of the Charges proven against the Club bar Charge 4(B)"、
  PL 声明 "the majority of charges in relation to its failure to co-operate"・"(three of the four alleged breaches were upheld)"）
- 対象は **2009-10季から2017-18季の9季**（判断101項・PL 声明）
- 告発の件数は、判断の本文では「**100を超える個々の違反**」（1項 "well over 100 individual breaches"）。
  **「115件中114件」「114件の違反」は報道の言い方で、公開された判断には出てこない。台本で件数を言わない**
- **「すべての告発で有罪」は誤り**（10/1 にユーザーから指摘を受けた箇所）。非協力の 4(B) は不成立

### 1-2. 上訴の手続きが、いまどの段階にあるか（2026-10-10 時点）

| 日付 | 何 | 根拠 |
|---|---|---|
| 2026-10-01 19時（英国時間） | シティが控訴を申し立て | シティ声明／PL 声明（10/2） |
| 2026-10-02 | PL が受け付けを公表。**審理は結論の公表が許されるまで非公開** | https://www.premierleague.com/en/news/4729207/premier-league-statement-manchester-city-fc-appeal-decision-of-independent-commission-02-october-2026 |
| 2026-10-08 まで | 規則では、申し立ての受領から**7日以内**に控訴委員会が進め方を示す（W.85） | ハンドブック原文（下） |
| 2026-12-24 まで | 控訴の審理を終える（**84日**・W.86.1.1）。審理は**5日以内で一括**（W.86.1.2） | 同 |
| 2027-01-23 まで | 控訴の判断（審理の最終日から**30日**・W.86.2／W.95） | 同 |
| 未定 | **罰を決める審理は別**（同じ独立委員会の非公開の審理）。日程は未発表 | PL 声明（9/29） |

**2026-10-10 時点で公表されていないこと**（＝台本で言ってはいけないこと）
- 控訴委員会の顔ぶれ（3人のうち1人は裁判官経験者が議長。任命するのは司法パネル議長の Sir Gary Hickinbottom）
- **審理の日付**。10/9 時点で発表された気配がない（WebSearch で 10/9 付けの発表は見つからなかった）
- **10/8 に実際に進め方が示されたか**。W.85 の期限の計算だけで、審理は非公開なので外からは見えない
- **罰の中身**。勝ち点剥奪・罰金・除名のどれも決まっていない

**確度の線は越えない**：「上訴中」「処分は確定していない」まで。**判決の中身を断定しない。**

#### ハンドブック 2026/27 Section W（原文。pypdf で抽出した本文そのまま）

> W.85. Within seven days of receipt of the appeal pursuant to Rule W.81, the Appeal Board shall give directions as it thinks fit for the future conduct of the appeal including whether to vary or disapply the Appeal Board Standard Directions, addressed in writing to the parties, or require the parties to attend a directions hearing.
> W.86.1.1. conclude no later than 12 weeks (84 days) after the filing of the appeal pursuant to Rule W.81;
> W.86.1.2. not exceed five days in duration and be heard in one block (i.e. it will not go part-heard); and
> W.86.2. set the dates for all remaining procedural steps … which shall be within 30 days after the final day of the appeal hearing;
> W.92. Except in cases in which the Appeal Board gives leave to adduce fresh evidence pursuant to Rule W.88, an appeal shall be by way of a review of the evidence adduced before the Commission …
> W.96. Upon the hearing of an appeal, an Appeal Board may: W.96.1. allow the appeal; W.96.2. dismiss the appeal; W.96.3. except in the case of a fixed penalty, vary any penalty imposed …
> W.97. Subject to the provisions of Section X (Arbitration) of these Rules, the decision of an Appeal Board shall be final.

- 取得: https://resources.premierleague.pulselive.com/premierleague/document/2026/07/31/8a890ff9-176c-4364-a8ff-e08f995e2c86/TM2040_PL-Handbook-and-Collateral-2026-27_Digital_31.07.pdf （460ページ、14.6MB。2026-10-10 取得。Section W は 313〜314ページ）
- 計算: 10/1＋84日＝**12/24**、＋30日＝**2027-01-23**、10/1＋7日＝**10/8**

> **食い違いを1つ見つけた（報道 対 規則の原文）。**
> ESPN（10/8、"What's next for Man City?" https://www.espn.com/soccer/story/_/id/50132069/ ）は
> **「判断の期限は 2027-02-08。クリスマスと新年の休止を W.95 で勘案した」**と書いている。
> だが**W.95 の原文に休止の規定は無く**、ハンドブック全文を `shutdown` / `excluded period` / `Christmas` / `New Year` で検索しても、
> 懲罰の期限を延ばす条文は**見つからなかった**（Christmas の2件は育成年代の試合日程と放送の話、New Year の1件は元日の試合）。
> → **台本は規則の原文から出る 1/23 を使い、「2月まで」と言わない。**どちらかが誤りだが、こちらで断定はしない。

---

## 2. 言葉が出た会見（日付・場所・どの試合の前か）

- **2026-10-09（金）、マンチェスター・ユナイテッドの試合前の記者会見**。
  **トッテナム戦の前**（プレミアリーグ再開の週。判定は代表ウィーク中の 9/29 に出たので、**監督たちが口を開いたのはこの日が最初**）
- 判定から**10日後**の会見（9/29 → 10/9）
- **会見の場所（キャリントンの練習場か会場か）は、当たった4媒体のどれにも書かれていない。→「試合前の記者会見で」と言う**
- 同じ日に、プレミアの監督がほぼ全員この件を聞かれている（ESPN が20クラブ分をまとめている。C の控えを見る）

### 報じた媒体（原文の突き合わせに使ったもの）

| 媒体 | 日付 | URL |
|---|---|---|
| The Independent（Yahoo Sports 転載） | 2026-10-09 | https://sports.yahoo.com/articles/michael-carrick-reacts-unprecedented-manchester-134322299.html |
| football365 | 2026-10-09 | https://www.football365.com/news/andoni-iraola-michael-carrick-enzo-maresca-liverpool-manchester-united-manchester-city |
| Sports Mole | 2026-10-09 | https://www.sportsmole.co.uk/football/man-utd/news/it-has-affected-me-personally-carrick-reacts-to-man-city-charges_606554.html |
| Read Man Utd | 2026-10-09 | https://readmanutd.com/2026/10/09/michael-carrick-man-city-charges-verdict/ |
| ESPN（20クラブの監督のまとめ） | 2026-10-09 | https://www.espn.com/soccer/story/_/id/50130966/man-city-charges-managers-said-scandal-ahead-premier-league-return |

---

## 3. キャリックの言葉（**原文のまま**＋訳）

### 3-1. 媒体で裏の取れた原文（これを台本に使う）

**①問いが山ほど出た**（Independent・football365 とも同じ文）
> "Very difficult to say in many ways. It's thrown up a lot of questions, some have had answers, some haven't."
訳：いろいろな意味で、とても言いにくい。たくさんの問いが浮かび上がった。答えが出たものもあるし、出ていないものもある。

**②自分は個人として影響を受けた**（Independent・football365）
> "Certainly I've got my own questions about it, it's affected me personally in different ways over a period of time."
訳：確かに、自分自身の問いがある。長いあいだ、いろいろな形で自分に個人として影響してきた。

- Sports Mole は同じ内容を短く：> "I have my own questions about it because it has affected me personally."

**③まだ続いているので、言えることは限られる**（football365。**原文の "we don't how long" は媒体の表記のまま**。sic）
> "As it's still ongoing, and we don't how long it's going to go, there's only so much I can say."
訳：まだ続いていて、どれだけ長くかかるのかも分からないので、言えることは限られる。

**④早いことが欠かせない**（Independent）
> "There's so many angles to look at from so many different perspectives, but really speed is essential for everyone."
訳：いろいろな立場から見るべき角度がたくさんある。ただ、本当に、早いことが誰にとっても欠かせない。

（football365 の長い版）
> "But as the case is going now I don't know where that stands and how it's going to end up, so we'll just have to wait and see. What I will say, the sooner it gets sorted I think for everyone's benefit is essential."
訳：いまの進み方では、それがどこにあって、どう終わるのかが分からない。だから待って見るしかない。言えるのは、早く片がつくほど、みんなのためになるということ。

**⑤みんな、何が起きるのかを知る必要がある**（Sports Mole・Read Man Utd。**"..." は媒体が省略した印なので、省略されたまま引く**）
> "Speed is essential, as I just said... We all need to know what is going to happen."
訳：早いことが欠かせない。いま言ったとおり。…私たちはみんな、何が起きるのかを知る必要がある。

**⑥前例が無い**（Independent）
> "It's unprecedented, you know, a unique situation to be in this, at this level with such a huge impact."
訳：前例が無い。これだけ大きな影響があって、このレベルでこういう状況になるのは、他に無いことだ。

**⑦勝った瞬間は取り返せない**（Read Man Utd・Sports Mole）
> "When you're in football the strive to win and the emotion, the feeling about winning is a lot of it is in the moment."
> "There's no getting that back in any direction. The feeling we all crave is coming out on top."
訳：サッカーの中にいると、勝とうとする力と感情、勝つことの手ざわりは、その多くがその瞬間にある。
／どちらの方向にも、それを取り返す道は無い。私たちみんなが渇くように求めている感覚は、いちばん上に出ることだ。

- Sports Mole は⑦の1行目に **媒体の補いの角括弧**を入れている：> "There's no getting that back [winning moments] in any direction."
  → **角括弧は媒体が足したもの。台本では角括弧ごと引かない**

**⑧2011-12 のタイトルについて**（Read Man Utd。**"…" は媒体の省略**）
> "I think it doesn't change how you feel in that moment. You can't take it back, so whichever way this goes, and I don't really want to speak about which way it could go, but whether we did end up getting… [a trophy], it doesn't change that moment, we can't get it back."
訳：その瞬間の気持ちは変わらないと思う。取り戻すことはできない。だから、これがどちらに転んでも——どちらに転びうるかは、あまり話したくないが——最後に受け取ることになったとしても…（トロフィーを）、あの瞬間は変わらない。取り返せない。

- Sports Mole の短い版：> "It doesn't change how you feel in that moment. You can't take it back."

**⑨メダルでは戻らない**（Sports Mole）
> "A medal here and there does not bring the feeling back for winning."
訳：あちこちでメダルをもらっても、勝ったときの感覚は戻ってこない。

- Independent の同じ趣旨の行：> "That doesn't bring the feeling of when you initially win or you don't win."
  訳：それは、最初に勝ったとき、あるいは勝てなかったときの感覚を連れてこない。

**⑩どちらに転ぶかは、いまは言わない**（Independent）
> "I think at the moment, as it's still not finalised, I think I'll hold that one until later on."
訳：いまのところ、まだ確定していないので、それについては後にとっておく。

### 3-2. 台本に使うときの注意

- **⑦と⑧と⑨は、同じ1つの問い（「さかのぼってメダルやタイトルが動いたらどうか」）への答え**。
  **3つをつなげて1つの発言にしない。**使うなら1つを選ぶか、問いを添えて並べる
- **⑩があるので、「キャリックはタイトル剥奪を求めた」と読める形にしてはいけない。**本人は中身の見通しを避けている
- キャリックは**「cheating」「剥奪」「罰」に当たる語を一度も使っていない**（当たった4媒体のどこにも無い）

### 3-3. ロマーノの投稿の文面と、媒体の原文の食い違い（**重要**）

| ロマーノの投稿（依頼の表） | 媒体の原文 | 判定 |
|---|---|---|
| "It's unprecedented to be in this situation at this level" | "It's unprecedented, you know, a unique situation to be in this, at this level with such a huge impact."（Independent） | **縮めてある。原文を使う** |
| "We all NEED to know what is going to happen" | "We all need to know what is going to happen."（Sports Mole・Read Man Utd） | 中身は一致。**大文字の強調は投稿者が足したもの** |
| "Speed is essential to be clear, deal with it and move on" | 当たった4媒体に**この文は無い**（"the sooner it gets sorted … is essential" が近い） | **裏が取れない。使わない** |
| "There are so many angles, but speed is essential for everybody to be clear" | "There's so many angles to look at from so many different perspectives, but really speed is essential for everyone."（Independent） | **縮めてある。原文を使う** |
| "On my view, there's no getting that back in any direction" | "There's no getting that back in any direction."（Read Man Utd） | 一致（頭の "On my view," は媒体に無い） |
| "The feeling we all crave is coming out on top. That sums it up" | "The feeling we all crave is coming out on top."（Read Man Utd） | 前半は一致。**"That sums it up" は裏が取れない** |
| "Whatever is done in the past, is done in the past" | **見つからなかった** | **使わない** |
| "It's the moment that you STRIVE for" | "the strive to win and the emotion, the feeling about winning is a lot of it is in the moment"（Read Man Utd） | **別の文。言い換えなので使わない** |
| "I think at the moment, it's not finalised. I think I'll hold that one until later on" | "I think at the moment, as it's still not finalised, I think I'll hold that one until later on."（Independent） | ほぼ一致。**原文を使う** |
| "But a medal here and there does not bring the feeling back for winning" | "A medal here and there does not bring the feeling back for winning."（Sports Mole） | 一致（頭の "But" は媒体に無い） |
| ユナイテッド対スパーズの重圧："It's just another game" | **見つからなかった**（トッテナム戦の前の会見であることは4媒体とも一致） | **使わない** |

---

## 4. それぞれの立場が分かる数字

### 4-1. マンUがシティと争った季（順位・勝ち点差）

| 季 | 優勝 | 2位 | 勝ち点 | 差 |
|---|---|---|---|---|
| **2011-12** | **マンチェスター・シティ 89**（得失点差 **+64**） | **マンチェスター・ユナイテッド 89**（得失点差 **+56**） | **0** | 得失点差 **8** |
| **2017-18** | **マンチェスター・シティ 100** | **マンチェスター・ユナイテッド 81** | **19** | — |

- 2011-12 は**プレミアリーグの歴史で、優勝が得失点差で決まった唯一の季**（英語版Wikipedia「2011–12 Premier League」
  "the first and (to date) only time the Premier League had been won on goal difference"）。
  最終節は 2012-05-13。シティは後半アディショナルタイムにアグエロが決め、ユナイテッドは同じ時刻にサンダーランドに勝っていた
  - https://en.wikipedia.org/wiki/2011%E2%80%9312_Premier_League
- 2017-18 のシティは**勝ち点100・32勝・106得点・得失点差+79・18連勝**でいずれもプレミアの記録
  - https://en.wikipedia.org/wiki/2017%E2%80%9318_Premier_League
- **キャリックが「ピッチにいた」とは書かない**。Independent は 2011-12 の最終節に触れているが、
  ユナイテッドは別会場（サンダーランド戦）で戦っていた。**出場の有無は確かめていない**

### 4-2. 対象9季の優勝と2位（2009-10〜2017-18）

| 季 | 優勝 | 2位 |
|---|---|---|
| 2009-10 | チェルシー | **マンチェスター・ユナイテッド** |
| 2010-11 | **マンチェスター・ユナイテッド** | チェルシー |
| 2011-12 | **マンチェスター・シティ** | **マンチェスター・ユナイテッド** |
| 2012-13 | **マンチェスター・ユナイテッド** | **マンチェスター・シティ** |
| 2013-14 | **マンチェスター・シティ** | リヴァプール |
| 2014-15 | チェルシー | **マンチェスター・シティ** |
| 2015-16 | レスター・シティ | アーセナル |
| 2016-17 | チェルシー | トッテナム |
| 2017-18 | **マンチェスター・シティ** | **マンチェスター・ユナイテッド** |

- 出典: https://en.wikipedia.org/wiki/List_of_English_football_champions （2026-10-10 取得）

### 4-3. キャリックの現役時代

- **1981-07-28 生まれ（2026-10-10 時点で45歳）**
- マンチェスター・ユナイテッドの選手：**2006年〜2018年**。**公式戦 464試合**（うちリーグ戦 316試合）
  - https://en.wikipedia.org/wiki/Michael_Carrick
- **プレミアリーグ優勝5回：2006-07・2007-08・2008-09・2010-11・2012-13**
- **UEFAチャンピオンズリーグ優勝1回：2007-08**（2008年5月、モスクワでチェルシーにPK戦で勝ち、キャリックは2人目を決めた）
- そのほか：FAカップ 2016、リーグカップ3回、ヨーロッパリーグ、クラブワールドカップ、コミュニティシールド6回
  （「12年で18個」は ESPN・Premier League 公式のプロフィールの数え方。**台本で総数を言うなら、数え方が媒体によって違うので「優勝5回」だけにする**）
  - https://premierleague.com/players/1634
- 監督：**2026-01-13 にマンチェスター・ユナイテッドの監督に就任**（その前はミドルズブラ 2022-10〜2025-06、2021年11月に暫定）
  - 就任から 2026-10-09 の会見まで **269日**

---

## 5. この回だけの数字（自分で計算した。式と元の数字つき）

### ① キャリックは、告発の対象9季の**すべて**をユナイテッドの選手として過ごしていた

- 対象: **2009-10季 〜 2017-18季 の9季**（判断101項・PL 声明）
- キャリックのユナイテッド在籍: **2006年〜2018年**（英語版Wikipedia）
- 式: 2009-10〜2017-18 の9季 ∩ 2006-07〜2017-18 の在籍 = **9季（9/9＝100%）**
- → **「いま問いを並べている監督は、問われている9年のあいだ、ずっと向かい側のピッチにいた」**
- **注意**：在籍の年は季の単位。移籍日（2006年7月・2018年夏）までは確かめていないので「2009-10から2017-18の9季はすべてユナイテッドの選手だった」と言う

### ② 争った2季の「差」は、勝ち点では0、得点では8

- 2011-12：勝ち点 89 − 89 = **0**／得失点差 +64 − (+56) = **8**
- 2017-18：勝ち点 100 − 81 = **19**
- → **「1回は8点の差で、もう1回は19点の差。前者は勝ち点では1点も離れていない」**

### ③ 対象9季のタイトルは、シティ3・ユナイテッド2

- 式（4-2 の表から数えた）：シティ優勝 = 2011-12・2013-14・2017-18 = **3**／ユナイテッド優勝 = 2010-11・2012-13 = **2**
- マンUがシティに次ぐ2位だったのは **2季**（2011-12・2017-18）
- → **「9季のうち、2つのクラブで5回の優勝。そのうちシティが3つ」**

### ④ あの最終節から、判定まで 5,252日

- 2012-05-13（2011-12 の最終節）→ 2026-09-29（判定）＝ **5,252日＝約14年5か月**
- 2018-05-13（2017-18 の最終節）→ 2026-09-29 ＝ **3,061日＝約8年5か月**
- 告発（2023-02-06）→ 判定（2026-09-29）＝ **1,331日＝約3年8か月**
- → **「取り返せない、と言うまでに14年かかった」**
- 計算は python の `date` の差。元の日付の根拠は 4-1（最終節）・1-1（判定）・`20261002_city_verdict.md`（告発日）

### ⑤ 判定から会見まで10日、キャリックの監督就任から269日

- 2026-09-29 → 2026-10-09 ＝ **10日**（代表ウィークを挟んだので、クラブの監督が最初に口を開いた日）
- 2026-01-13（就任）→ 2026-10-09 ＝ **269日**

---

## 6. 精査（前 → 後と根拠）

| # | 何 | 前（依頼・ロマーノの投稿のまま作ると） | 後 | 根拠 |
|---|---|---|---|---|
| 1 | 発言の文面 | ロマーノの投稿の文（縮めた形・大文字の強調） | **媒体の原文**。縮めた4行と裏の取れない3行は落とす | 3-1・3-3 |
| 2 | 「すべての告発で有罪」 | そう書きたくなる | **財務の告発はすべて／非協力は4つのうち3つ** | 判断7項・157項、PL 声明 |
| 3 | 件数 | 「115件中114件」 | **件数を言わない**（判断は「100を超える」だけ） | 判断1項 |
| 4 | 控訴の結論の時期 | ESPN の「2027-02-08」 | **2027-01-23 まで**（規則の原文から計算）。「2月」と言わない | ハンドブック W.86.2／W.95 の原文。休止の条文は全文検索で見つからなかった |
| 5 | 2011-12 の最終節 | 「キャリックはピッチでアグエロの得点を見た」 | **別会場で戦っていた。出場の有無は書かない** | ユナイテッドはサンダーランド戦 |
| 6 | 発言の束ね方 | ⑦⑧⑨をつないで「メダルはいらない」と言わせる | **1つを選ぶ。つなげない** | 発言は原文のまま・言い換えない |
| 7 | 罰の見通し | キャリックの言葉から処分の話へ流す | **本人が⑩で避けている。流さない**（処分の話は B・C にも置かない） | ⑩ |

---

## 7. 見つからなかったもの（推測で埋めない）

- **会見の場所**（4媒体とも「金曜の会見」までで、練習場か会場かを書いていない）
- **ロマーノの3行**："Speed is essential to be clear, deal with it and move on" ／ "Whatever is done in the past, is done in the past" ／ "It's just another game"（トッテナム戦の重圧について）。
  当たった4媒体＋ESPN のまとめのどこにも無い。**ロマーノの投稿そのものは読んでいない**（ブラウザの道具を使わないため X を開いていない）
- **キャリックが 2012-05-13 のサンダーランド戦に出場したか**
- **控訴委員会の顔ぶれ・審理の日付**（10/10 時点で未発表）
- **罰の中身と、罰を決める審理の日程**（未定）
- **10/8 に W.85 の進め方が実際に示されたか**（審理は非公開）
- キャリックの通算のタイトル数（媒体によって数え方が違う。「18個」は ESPN・PL 公式の数え方で、こちらで検算していない）
