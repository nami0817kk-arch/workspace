# psv_sano｜PSV 2-0 sc ヘーレンフェーン（佐野航大フル出場）の材料

調査日: 2026-10-10。使ったのは **WebFetch / WebSearch と python の requests だけ**（ブラウザの道具は不使用）。
**この1本は本編＋ショートの両方を作る。**
数字はすべて「いつ時点か」を付けた。裏が取れなかったものは「9. 取れなかったもの」に書いた。

---

## 0. 先に要点

- **2026年10月9日（金）20:00（現地）／日本時間10日3:00**、フィリップス・スタディオン（アイントホーフェン、収容35,000）。
  **エールディビジ第8節**。**PSV 2-0 sc ヘーレンフェーン**。主審 Joey Kooij。
- 得点は **29分 フース・ティル（ヘッド）** と **68分 マルクス・リンデイのオウンゴール**。PSV の選手が自分で決めたのは1点だけ。
- **佐野航大（23、背番号24、守備的MF）は先発フル出場（90分）。リーグ戦6試合連続先発**。
  FotMob の評点 **8.0（内部値 7.95）は、この試合の22人中2位**。上はGKコバーシュ（8.5、マン・オブ・ザ・マッチ）だけ。
  **フィールドプレーヤーでは最高評点**。
- PSV は **今季エールディビジで初の無失点**（8試合目）。勝ち点19で首位AZと並び、得失点差で2位（10/10 10:00 時点、翌日以降の試合で変動）。
- **代表ウィーク明け初戦**。PSV は **17人**が代表に招集されていた（PSV公式）。
  ボス監督は「昨日はじめて握手できた選手もいる」と言っている → ④break_debate とつながる材料。
- **佐野本人の言葉は、10/10 10:00 時点では見つからなかった**（詳細は「9.」）。
  代わりに**ボス監督の試合後コメント（PSV公式・ESPN）**と、**過去の佐野評（ED紙）**を押さえた。
  ※ goal.com 日本版の見出し「信じてほしい。彼はとても素晴らしい選手になる！」は**佐野のことではなく18歳のコルネシオンのこと**。混同しないこと。

---

## 1. 何が起きたか（一次情報まで）

### 1-1. 試合の枠

| 項目 | 内容 | 出典 |
|---|---|---|
| 大会 | VriendenLoterij エールディビジ 2026/27 第8節（roundName "8"） | リーグ公式の順位表／FotMob infoBox |
| 日時 | 2026-10-09 18:00 UTC（現地20:00、日本時間10日3:00） | ESPN / FotMob |
| 会場 | Philips Stadion（アイントホーフェン、収容35,000、天然芝） | ESPN gameInfo / FotMob infoBox |
| 結果 | PSV 2-0 sc Heerenveen | リーグ公式の順位表で裏取り（下記1-2） |
| 主審 | Joey Kooij（オランダ） | FotMob infoBox |
| 布陣 | PSV 4-3-3／ヘーレンフェーン 4-3-3 | FotMob lineup |

- **リーグ公式（eredivisie.nl）の「Stand」で、PSVとヘーレンフェーンだけが8試合消化**（他16クラブは7試合）。
  つまりこの試合は第8節の金曜開幕カード。**2026-10-10 10:00 取得時点の順位表**：

  ```
  1 AZ               7試合 6-1-0 18-6  +12 19
  2 PSV              8試合 6-1-1 26-10 +16 19
  3 Feyenoord        7試合 5-2-0 25-7  +18 17
  ...
  10 sc Heerenveen   8試合 2-3-3 11-11   0  9
  ```
  - 出典: https://eredivisie.nl/competitie/stand/ （2026-10-10 取得）
  - ※ AZ は同日 10/10 に Feyenoord と対戦予定（ESPN）。**「暫定2位」「暫定で首位と並んだ」が正確な書き方**。

### 1-2. 得点者と時間（**リーグ公式の試合ページは JavaScript 描画で requests では読めなかった**）

eredivisie.nl の `/competitie/wedstrijden/` と `/videos/psv-sc-heerenveen/` は中身が空（JS描画／未掲載）。
そこで**得点者と時間は ESPN の公式データフィードと FotMob のイベント、およびオランダの試合記事3本で一致を確認**した。

| 時間 | 得点 | 内容（原文） | 出典 |
|---|---|---|---|
| 29分 | PSV 1-0 | "Goal! PSV Eindhoven 1, Heerenveen 0. **Guus Til** (PSV Eindhoven) header from the left side of the six yard box to the bottom left corner." | ESPN keyEvents |
| 68分 | PSV 2-0 | "**Own Goal by Marcus Linday**, Heerenveen. PSV Eindhoven 2, Heerenveen 0." | ESPN keyEvents |

- **1点目の流れ（オランダ語の原文）**：
  > "Bajraktarevic bracht de bal vanaf de rechterflank voor het doel, waar Heerenveen-doelman Bernt Klaverboer de voorzet slechts gedeeltelijk kon verwerken. De bal belandde precies op het hoofd van Til, die bij de tweede paal de 1-0 binnenkopte."
  （訳：バイラクタレビッチが右サイドからボールを入れ、ヘーレンフェーンのGKクラーフェルブールがそのクロスを半端にしか処理できなかった。ボールはちょうどティルの頭に落ち、ティルがファーポストで1-0をヘッドで決めた）
  - 出典: Voetbalzone（Jeroen van Poppel、2026-10-09 21:54）https://www.voetbalzone.nl/nieuws/psv-ontsnapt-aan-rode-kaart-en-komt-met-de-schrik-vrij-tegen-sterker-heerenveen/blt818f435a688c2be2
  - NL Times は「バイラクタレビッチが**逆足の右足**でクロスを上げた」と書いている:
    > "Bajraktarevic did well to beat Vasilios Zagaritis before his cross with the weaker right foot was knocked on by Heerenveen keeper Bernt Klaverboer to Guus Til, who was on hand to nod it into the empty net."
    - 出典: https://nltimes.nl/2026/10/09/psv-beat-heerenveen-2-0-first-game-international-break
- **2点目の流れ（原文）**：
  > "in de 68ste minuut verdubbelde PSV de voorsprong uit een hoekschop van Perisic. Kostic kopte de bal richting het doel, waarna die via Linday over de lijn verdween en Maas Willemsen te laat kwam om de treffer te voorkomen."
  （訳：68分、ペリシッチのコーナーキックからPSVがリードを広げた。コスティッチがゴールに向けてヘッドし、そのボールがリンデイに当たってラインを越え、マース・ウィレムセンは防ぐのに間に合わなかった）
  - **両者とも65分に入ったばかりの交代選手で、2人のその試合の初タッチだった**：
    > "Two of Bosz's substitutes made an immediate impact. Perisic took a corner and found Filip Kostic, who headed it back across goal and saw it go in via the unfortunate Linday. **It was both players' first touch of the ball.**"（NL Times）

### 1-3. 判定の論点（動画で触れるなら）

- 42分に警告を受けていた **PSV のオビスポが、2点目の直前に相手を抱えたが2枚目が出なかった**。
  抗議したヘーレンフェーンのリンデイのほうが警告を受けた（60分）。ボスは直後にオビスポを下げた（65分）。
  - 出典: Voetbalzone（上記）、NL Times（上記）、PSVFans「Kijkers zien Kooij duidelijke rode kaart missen bij PSV - Heerenveen」(09-10)
- **ヘーレンフェーンは前半に決定機を3つ外した**（マクサンス・リベラ）。
  > "Rivera kreeg binnen twintig minuten liefst drie mogelijkheden om Heerenveen op voorsprong te zetten."（Voetbalzone）

### 1-4. 交代（FotMob / ESPN）

- PSV: 65分 ペリシッチ←バイラクタレビッチ／コスティッチ←ノア・フェルナンデス／ガシオロフスキ←オビスポ、
  83分 コルネシオン←マウロ・ジュニオール／アヨニ・サントス←ルベン・ファン・ボメル
- ヘーレンフェーン: 64分 ファルジ←リベラ／メールフェルト←スマンス、75分 エグブリング←ブラウデ／マシーン←フェンテ、83分 オイエン←クルテンス
- **18歳のシュリヤノ・コルネシオンが82〜83分に公式戦デビュー**（PSV）。

---

## 2. 佐野航大の数字（この試合）

**出典はすべて FotMob matchDetails（matchId 5781762、2026-10-10 取得、playerStats id 1337282）。**
API: `https://www.fotmob.com/api/data/matchDetails?matchId=5781762`（Chrome の UA を付けた requests で取得）
選手ページ: https://www.fotmob.com/players/1337282/kodai-sano

| 項目 | 値 |
|---|---|
| 評点 | **8.0（内部値 7.95）** |
| 出場時間 | **90分（先発・交代なし）** |
| 得点／アシスト | 0／0 |
| xG / xA / xG+xA | 0.05 / 0.09 / 0.14 |
| シュート | 1（枠内0・枠外1） |
| パス成功 | **54/59（91.5%）** |
| チャンス創出 | 1 |
| タッチ数 | **75**（相手ボックス内 3） |
| 最終3分の1へのパス | 10 |
| ドリブル成功 | 1/2 |
| クロス | 0/2 |
| **CK** | **2本（蹴っている）** |
| 守備アクション | 5 |
| タックル | 2 |
| クリア | 2（うちヘッド1） |
| インターセプト | 1 |
| ボール回収（recoveries） | 5 |
| 剥がされた回数 | **0** |
| ボールロスト（dispossessed） | **0** |
| 地上デュエル | **6/8** |
| 空中戦 | 1/2 |
| デュエル合計 | **勝ち7・負け3** |
| ファウルを受けた | 3 |
| ファウル | 1 |
| 市場価値（FotMob） | €15,263,440（約15.3百万ユーロ） |

### この試合の評点ランキング（FotMob、22人）

```
 1 PSV  マテイ・コバーシュ      8.5  （マン・オブ・ザ・マッチ、90分）
 2 PSV  佐野航大                8.0  ← フィールドプレーヤー最高
 3 PSV  ライアン・フラミンゴ    7.9
 4 PSV  セルジーニョ・デスト    7.6
 4 PSV  フース・ティル          7.6
 4 PSV  スヴェン・マイナンス    7.6
 7 PSV  ノア・フェルナンデス    7.5
 8 PSV  マウロ・ジュニオール    7.3
 9 PSV  ルベン・ファン・ボメル  7.1
10 PSV  バイラクタレビッチ      6.9
11 PSV  アルマンド・オビスポ    6.8
12 HEE  ノルハン・クルテンス    6.6
12 HEE  ヤコブ・トレンスコウ    6.6
...（ヘーレンフェーン最低は オウンゴールのリンデイ 5.8）
```

---

## 3. 佐野航大の今季・経歴の数字

### 3-1. クラブ公式（psv.nl）— **一次情報**

https://www.psv.nl/teams/speler/kodai-sano （2026-10-10 取得）

| 項目 | 内容（クラブ公式の表記） |
|---|---|
| ポジション | Middenvelder（MF） |
| 生年月日 | **25-sep-2003**（23歳） |
| 出身地 | **Tsuyama**（岡山県津山市） |
| 背番号 | 24 |
| 代表出場（Interlands） | **3** |
| 2026-2027 出場 | **7試合 / 568分** |
| 途中出場（Invalbeurten） | **1** |
| 途中交代（Wissels） | **0** |
| 警告 | 1 / 退場 0 |
| シュート | 11（枠内 5） |
| 得点 / アシスト | 1 / 0 |
| 直接FK（Vrije trappen） | 10 |

- クラブ公式の紹介文（原文）:
  > "Kodai Sano is de sinds Ritsu Doan de eerste Japanse voetballer bij PSV. De international kwam over van NEC, waar hij een topseizoen kende. De middenvelder haalde met de Nijmegenaren de finale van de KNVB Beker en plaatste zich voor de voorrondes van de UEFA Champions League. Toch was het met PSV dat hij zijn debuut maakte in die competitie. In zijn eerste duel, thuis tegen Shaktar Donetsk (1-1) maakte de Japanner direct indruk."
  （訳：佐野航大は**堂安律以来はじめての、PSVの日本人選手**。代表選手で、最高の1年を過ごしたNECから加入した。このMFはナイメヘン勢とKNVBカップ決勝に進み、UEFAチャンピオンズリーグの予備予選出場権も得た。それでも彼がその大会でデビューしたのはPSVでだった。最初の一戦、ホームでのシャフタール・ドネツク戦（1-1）で、この日本人はいきなり印象を残した）
  - **「Wissels 0」＝一度も途中で下げられていない**。先発した6試合はすべて90分。

### 3-2. 今季エールディビジ 1試合ごと（FotMob playerData、2026-10-10 取得）

| 日付 | 相手 | 出場 | 得点 | 評点 |
|---|---|---|---|---|
| 8/15 | エクセルシオール | 27分（途中出場） | 0 | 6.3 |
| 8/23 | フローニンゲン | 90分 | 0 | 7.5 |
| 8/30 | ユトレヒト | 90分 | 0 | 7.9 |
| 9/5 | アヤックス | 90分 | 0 | 7.6 |
| 9/13 | スパルタ・ロッテルダム | 90分 | **1** | **8.5** |
| 9/20 | トゥウェンテ | 90分 | 0 | 6.6 |
| 10/9 | **ヘーレンフェーン** | **90分** | 0 | **8.0** |

- CL は 9/10 シャフタール戦（1-1）で90分、評点 7.2（FotMob では 7.23）。
- FotMob のシーズン集計（2026-10-10 時点）: **エールディビジ 7試合・567分・1得点・0アシスト・評点 7.47**、
  全公式戦 **8試合・1得点・評点 7.37**。
- Transfermarkt / キャリア: NEC ナイメヘン 98試合12得点12アシスト（2023-08-17〜2026-08-08）、
  ファジアーノ岡山 50試合5得点6アシスト（2022-01-09〜2023-08-17）。**PSV 加入は 2026-08-08**。
  - 出典: FotMob careerHistory（playerData id 1337282）
- 移籍金の報道：NEC は当初 **2000万ユーロ（約37億円）** を要求、最終的に **1400万ユーロ（約26億円）超**。
  - 出典: フットボールチャンネル 2026-09-11 https://www.footballchannel.jp/2026/10/10/post1008717/ （オランダ『ESPN』の記事を引用）

### 3-3. 代表（この直前の4連戦）

| 日付 | 相手 | 出場 | 評点 |
|---|---|---|---|
| 9/24 | ウルグアイ | 45分 | 6.4 |
| 9/28 | ベネズエラ | 0分（ベンチ） | - |
| 10/1 | エクアドル | 0分（ベンチ） | - |
| 10/5 | ニュージーランド | 0分（ベンチ） | - |

- 日刊スポーツの表現: 「W杯北中米大会後の初活動となった9月から10月の代表4連戦で**2試合に出場**した佐野」
  - 出典: https://news.yahoo.co.jp/articles/5e0f2750f1608ab69f46f6fead3265c2414c6372 （2026-10-10 9:29）
  - **FotMob では出場は9/24ウルグアイ戦の45分だけ**（残り3試合は onBench, 0分）。**ここは食い違っている**（「8.」参照）。

---

## 4. 本人／監督／現地メディアの言葉

### 4-1. 佐野航大本人 → **見つからなかった**

10/10 10:00 時点で、PSV公式・Voetbalzone・NL Times・PSVFans・Voetbal International の見出し一覧・
日刊スポーツ・サッカーキング・超WORLDサッカー・フットボールチャンネルを当たったが、
**この試合についての佐野本人のコメントは出ていない**。推測で書かないこと。
（直近で本人の言葉が取れているのは代表の 9/23 サッカーキング記事「最優先でした」。この試合のものではない）

### 4-2. ペーター・ボス監督（PSV公式の試合後会見・原文オランダ語）

出典: PSV 公式 https://www.psv.nl/media/artikel/persconferentie-dit-soort-wedstrijden-zijn-extra-gevaarlijk （2026-10-09）

- 試合について:
  > "Er waren fases dat het veld te groot was. We waren soms slordig aan de bal. Dat wekt onrust in de hand. We hadden niet genoeg grip. Dan kun je achterkomen. Met name na de wissels kregen we de controle terug. Dan sta je compacter, de bal win je sneller terug. **Maar als je meerekent waar iedereen vandaan komt met de interlandperiode, dan hebben we een goede wedstrijd gespeeld.**"
  （訳：ピッチが広すぎた時間帯があった。ボールを持ったときに雑なところもあった。それが落ち着かなさを生む。十分に掴めていなかった。そうなれば先に失点することもある。とくに交代のあとにコントロールを取り戻した。よりコンパクトになり、ボールを早く奪い返せる。**ただ、代表ウィークでみんながどこから帰ってきたかを勘定に入れれば、我々は良い試合をした**）
- 代表ウィークの影響:
  > "De wedstrijden rond een interlandperiode zijn vaak moeilijker. Je hebt wat minder grip op een groep. Vaak zijn ze bezig met de reis voor of na de wedstrijd en dan zijn ze minder gefocust op het nu. Daarom ben ik extra blij met deze zege."
  （訳：代表ウィークの前後の試合はしばしば難しい。チームを掴みきれない。彼らは試合の前後の移動のことを考えていて、今に集中できていないことが多い。だからこの勝利はとくにうれしい）
  > "Absoluut, dat is altijd juist onze kracht. **Ik heb sommige jongens gister pas voor het eerst de hand kunnen schudden.** Ja dat heeft invloed, maar wij moeten alsnog onze wedstrijden winnen."
  （訳：間違いなく（ボールを持ったときの雑さは代表ウィークと関係がある）。それは本来いつも我々の強みだ。**何人かの選手とは、昨日はじめて握手できた**。そう、それは影響している。それでも我々は試合に勝たなければならない）
- ティルとマイナンスの組み合わせ:
  > "Zeker, maar het belangrijkste in deze samenstelling is dat een van de twee voor de goal is. Dat zag je ook bij de eerste goal."
  （訳：確かに（補完的だ）。ただこの組み合わせで一番大事なのは、2人のうち1人がゴール前にいること。1点目でもそれが見えた）
- ライプツィヒ戦へ:
  > "Er zal een ander PSV moeten staan tegen Leipzig, maar dit is ook maar een momentopname."
  （訳：ライプツィヒ戦には別のPSVが立っていなければならない。ただこれもその時点の切り取りにすぎない）

### 4-3. ボス監督（ESPN オランダ、goal.com 日本版の訳）

出典: goal.com 日本版（Jeroen van Poppel、2026-10-10 06:35）
https://goal.com/jp/ニュース/psv対ヘーレンフェーン戦後-ホ゛ス監督か゛即断言-信し゛てほしい-彼はとても素晴らしい選手になる/blt1b28129393217bbc

- > 「3週間試合をしておらず、選手たちとも会っていなくて、それで復帰後最初の試合に勝てたなら、それは良いことだ」
- > 「1時間のあいだは互角の試合だったと思う。こちらにもチャンスがあり、相手にもあった。良いタイミングで我々がゴールを決めたが、とくに後半はより試合をコントロールできた。60分前後の交代のあとには、完全に主導権を握っていた」
- > 「オーストラリアとインドへ移動し、練習に参加できたのが1日だけだった選手がいることを忘れてはいけない（マウロ・ジュニオールのこと）。その選手は今夜、ここで普通にプレーしなければならないんだ」
- > 「セルジーニョ（デスト）は火曜の夜から水曜の夜にかけて、まだ試合をしていた。時差ボケのある選手もいるし、オビ（スポ）はカリブ海地域から来ている。そんな中でも、ここで結果を出さなければならない。なぜなら我々はこの試合に勝たなければならなかったからだ。そして実際に勝った。そのことに私はとても満足している」
- 無失点について:
  > 「もしかしたら、2-0より3-1で勝つほうがよかったかもしれないね。そうすればゴールが2つ多いから」
  > 「でも、ようやく一度クリーンシートを達成できたのは良いことだ。これでそうしたくだらない騒ぎからも解放される。我々にとって良い夜だった」
- **⚠ 注意**：同記事の「今はまだただの少年だが、信じてほしい。彼は本当に素晴らしい選手になる！」は
  **82分にデビューした18歳のシュリヤノ・コルネシオンについての発言**で、佐野のことではない。

### 4-4. 現地紙の佐野評（**この試合のものではない。過去の評**）

- 『ED（Eindhovens Dagblad）』、9/5 アヤックス戦（PSV 3-1 勝利）について（2026-09-07 掲載）:
  - 佐野の獲得を「**大当たり**」と評価、「ボールを失うことが少なく、多くのピンチを未然に防いでいる」
  - 「**PSVの傑出した選手**」「**まるで掃除機のような足で、非常に多くのボールをインターセプトした**」
  - PSV 番記者 **リク・エルフリンク氏の採点は「8」でチーム単独トップ**
  - 出典: フットボールチャンネル（Yahoo!ニュース、2026-09-07 19:45）
    https://news.yahoo.co.jp/articles/5479f808e0e451205f30d8c0e6d0eef7ee45ed65
- オランダ『ESPN』（2026-09-11、フットボールチャンネル経由）:
  - 「**すでにPSVの主力**」「PSVの中盤における**支柱へと成長した**」
  - ボス監督の評: 「我々は止まった状態ではなく、動きながらプレーしたい。**彼は3つすべてのポジションでプレーできる**」
  - PSV加入後のインターセプト数5回で、フラミンゴの7回に次ぐチーム2位（9/11 時点）
  - 出典: https://www.footballchannel.jp/2026/10/10/post1008717/
- 9/10 シャフタール戦（CL、1-1）の ED 採点では **佐野は 6.5**。
  > "Sano was volgens Bosz voor rust wat zenuwachtig geweest, maar daarna toch een van de mannen die het de tegenstander nog enigszins lastig maakte"
  （訳：ボスによれば佐野は前半やや緊張していたが、その後は相手を多少なりとも苦しめた男たちの1人だった）
  - 出典: PSVFans「PSV op rapport」2026-09-11 https://www.psvfans.nl/psv-op-rapport/

---

## 5. PSV / ヘーレンフェーンの枠の数字

### PSV（クラブ公式・リーグ公式）

- **代表に招集されたPSVの選手は17人**（PSV公式、試合前の「Alles over」記事）:
  > "De afgelopen weken stond het clubvoetbal even stil. **Zeventien PSV'ers werden opgeroepen voor hun nationale ploeg.** Voor Ruben van Bommel en Mauro Júnior was het een bijzondere periode: beiden werden voor het eerst geselecteerd voor Nederland en Brazilië."
  （訳：この数週間クラブサッカーは止まっていた。**17人のPSVの選手が代表に招集された**。ルベン・ファン・ボメルとマウロ・ジュニオールにとっては特別な期間だった。2人はそれぞれオランダとブラジルに初めて選ばれた）
  - 出典: https://www.psv.nl/media/artikel/alles-over-psv-sc-heerenveen-in-het-teken-van-coen-dillen （2026-10-08）
- 同記事より（**どれも試合前＝第7節終了時点の数字**）:
  - 開幕7試合で **22得点**（※リーグ公式の順位表と食い違う。「8.」参照）
  - **ティルとマイナンスが4点ずつでチーム得点王**
  - PSV は7試合で **60%の時間をリードして過ごした（リーグ全18クラブで最高）**、ビハインドだったのは **7%**
  - ヘーレンフェーン戦の通算得点は178。直近9回の対戦で7勝。
    金曜も勝てば **20年ぶりに4連勝**
- この試合は**コーン・ディレン生誕100年**の記念ユニフォーム（ヴィンテージのロゴ、長袖、背中に名前なし）。
  ディレンは **1956-57シーズンにエールディビジで43得点**。**今も残る記録**。
  - 出典: 上記PSV公式、NL Times
- **ティルのこの得点は今季リーグ8試合で5点目**:
  > "Voor de Oranje-international betekende het alweer zijn vijfde competitietreffer in acht wedstrijden dit seizoen."（Voetbalzone）
- 次戦: **10/13（現地）/14 UEFAチャンピオンズリーグ リーグフェーズ第2節 RBライプツィヒ戦（アウェイ）**、
  その後 10/17 ADOデン・ハーグ戦（アウェイ）。
  - 出典: サッカーキング/超WORLDサッカー（2026-10-10）https://web.ultra-soccer.jp/news/all/39438/ ・PSV公式 match-center
  - ※ NL Times は「火曜に RBザルツブルク」と書いているが、**PSV公式のマッチセンターは "rb-leipzig-psv-13-10-2026"**。**NL Times の誤り**。

### ヘーレンフェーン

- 10位、8試合 2勝3分3敗、11得点11失点、勝ち点9（リーグ公式、2026-10-10 時点）
- 次戦は 10/17 ホームでエクセルシオール戦（NL Times）
- この試合で **メース・ヒルハース**が1年半ぶりに選手団に復帰（PSVFans の見出し）

---

## 6. この回だけの数字（自分で計算した。式と元の数字つき）

### ① 佐野の評点はフィールドの22人で最高、全体では2位
- 元の数字: FotMob のこの試合の全選手評点（上の「2.」のランキング）
- 式: 降順に並べると コバーシュ 8.5 → **佐野 8.0** → フラミンゴ 7.9 → …
- **「ゴールキーパーを除けば、ピッチに立った20人で一番高い点が付いたのは佐野だった」**

### ② 佐野は「90分×6」。先発した試合で一度も下げられていない
- 元の数字: PSV公式「Gespeeld 7 / Speelminuten 568 / Invalbeurten 1 / **Wissels 0**」
- 式: 6（先発）× 90 + 27（エクセルシオール戦の途中出場）= **567分**
  （PSV公式の568分と1分だけ差がある →「8.」参照）
- **「先発6試合、交代ゼロ。PSVで先発した日は、まだ一度もベンチに戻っていない」**

### ③ 72秒に1回ボールに触っていた
- 元の数字: タッチ 75回 / 出場 90分
- 式: 90 × 60 ÷ 75 = **72.0秒**
- **「90分で75回。72秒に1回、ボールに触っていた」**

### ④ ボールを渡した相手は10人中9人以上、奪われた回数はゼロ
- 元の数字: パス成功 54/59、dispossessed 0、dribbled past 0
- 式: 54 ÷ 59 = 0.9152 → **91.5%**
- **「59本蹴って54本つないで91.5%。持っていて奪われた回数は0、抜かれた回数も0」**

### ⑤ デュエルは10回やって7回勝った
- 元の数字: 地上 6/8、空中 1/2（FotMob は duels won 7 / lost 3）
- 式: (6+1) ÷ (8+2) = 7 ÷ 10 = **70.0%**

### ⑥ PSV は8試合目でようやく初の無失点。それまで1試合平均1.25失点
- 元の数字: リーグ公式の順位表 26-10（8試合）
- 式: 失点 10 ÷ 8試合 = 1.25。この試合が0なので、前7試合で10 → **10 ÷ 7 = 1.43失点/試合**
- **「7試合で10失点。8試合目で初めてゼロにした」**

### ⑦ 1試合3.25点のPSVが、自分たちで決めたのは1点だけ
- 元の数字: 26得点 ÷ 8試合 = **3.25点/試合**（リーグ公式）
- この試合は 2点、うち1点はオウンゴール → **PSVの選手が決めたのは1点**
- **「平均3.25点のチームが、自分たちの足で決めたのは1点だけだった」**

---

## 7. ショートと本編で使い分ける骨

- **ショート**（佐野1人に寄せる）: 評点8.0＝フィールド最高 → 72秒に1回のタッチ → デュエル7/10 →
  6試合連続先発＆交代ゼロ → 代表帰りでこれ。
- **本編**（試合まるごと）: 代表ウィーク明けで17人が帰ってきたPSV → 内容は押されていた（リベラの決定機3つ） →
  ティルのヘッドで先制 → オビスポの2枚目が出ない論点 → 65分の3枚替えが68分のオウンゴールを呼ぶ →
  8試合目で初の無失点 → 暫定で首位AZと並ぶ → その中で90分やり切った佐野。
  **ボス監督の「昨日はじめて握手できた選手もいる」を軸に置くと、④break_debate と重ならずに両方で使える**
  （break_debate 側では UEFA・フリック・シメオネを軸にすること）。

---

## 8. 数字の食い違い（そのまま残す）

1. **出場時間 567分（FotMob）/ 568分（PSV公式）**。1分差。原因は不明。
2. **開幕7試合で22得点（PSV公式 10/8）/ リーグ公式の順位表では8試合26得点**。
   26 − 2（この試合）= 24 で、PSV公式の22と合わない。どちらが何を数えているかは特定できなかった。
   **動画ではリーグ公式の「8試合26得点」を使うほうが安全**。
3. **代表4連戦の出場数「2試合」（日刊スポーツ）/「1試合（9/24ウルグアイ戦45分）」（FotMob）**。
   FotMob は 9/28・10/1・10/5 をいずれも onBench・0分としている。**どちらが正しいか確定できなかった**。
4. **次のCLの相手「RBザルツブルク」（NL Times）/「RBライプツィヒ」（PSV公式マッチセンター・サッカーキング）**。
   **PSV公式が正。NL Times の誤り**。
5. 評点は媒体で違う。FotMob 8.0 / ED（エルフリンク）は**この試合の採点が 10/10 10:00 時点で未掲載**。

---

## 9. 取れなかったもの

- **佐野航大のこの試合についてのコメント**（オランダ語・日本語とも見つからなかった）。
- **ED（Eindhovens Dagblad）／Voetbal International のこの試合の選手採点**（10/10 10:00 時点で未掲載、
  または有料。VI の「Eredivisie op Rapport」のページは古い節の内容が返ってきた）。
- **リーグ公式（eredivisie.nl）の試合ページそのもの**。`/competitie/wedstrijden/` も
  `/videos/psv-sc-heerenveen/` も JavaScript 描画／未掲載で、requests では得点者を読めなかった。
  得点者と時間は **ESPN の公式フィード + FotMob + Voetbalzone + NL Times の4つで一致**を確認して代用した。
- **入場者数**（ESPN の attendance は 0 と返ってきており、実数ではない）。
- ネットの反応（今回は集めない方針）。

---

## 10. 出典一覧

### 一次情報（クラブ・リーグ）
- PSV公式・佐野航大の選手ページ https://www.psv.nl/teams/speler/kodai-sano
- PSV公式・試合後会見 https://www.psv.nl/media/artikel/persconferentie-dit-soort-wedstrijden-zijn-extra-gevaarlijk
- PSV公式・試合前「Alles over」 https://www.psv.nl/media/artikel/alles-over-psv-sc-heerenveen-in-het-teken-van-coen-dillen
- PSV公式・マッチセンター https://www.psv.nl/match-center/wedstrijd/psv-sc-heerenveen-09-10-2026
- エールディビジ公式・順位表 https://eredivisie.nl/competitie/stand/

### データ
- FotMob matchDetails（matchId 5781762）https://www.fotmob.com/matches/psv-eindhoven-vs-sc-heerenveen/2xzk6a#5781762
- FotMob 佐野航大 https://www.fotmob.com/players/1337282/kodai-sano
- ESPN 試合サマリー https://www.espn.com/soccer/match/_/gameId/401875592

### 報道
- Voetbalzone（オランダ語の試合記事）https://www.voetbalzone.nl/nieuws/psv-ontsnapt-aan-rode-kaart-en-komt-met-de-schrik-vrij-tegen-sterker-heerenveen/blt818f435a688c2be2
- NL Times（英語の試合記事）https://nltimes.nl/2026/10/09/psv-beat-heerenveen-2-0-first-game-international-break
- goal.com 日本版（ボス監督の試合後コメント）https://goal.com/jp/ニュース/psv対ヘーレンフェーン戦後-ホ゛ス監督か゛即断言-信し゛てほしい-彼はとても素晴らしい選手になる/blt1b28129393217bbc
- 日刊スポーツ（Yahoo!ニュース）https://news.yahoo.co.jp/articles/5e0f2750f1608ab69f46f6fead3265c2414c6372
- サッカーキング／超WORLDサッカー https://web.ultra-soccer.jp/news/all/39438/
- フットボールチャンネル（ED紙のアヤックス戦採点）https://news.yahoo.co.jp/articles/5479f808e0e451205f30d8c0e6d0eef7ee45ed65
- フットボールチャンネル（オランダESPNの佐野分析）https://www.footballchannel.jp/2026/10/10/post1008717/
- PSVFans（ED紙のシャフタール戦採点）https://www.psvfans.nl/psv-op-rapport/
