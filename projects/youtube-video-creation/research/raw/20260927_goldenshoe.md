# 欧州ゴールデンシュー争い：ラフィーニャ・ムバッペ・ハーランドを抑えて首位にいるのは誰か（ESPN）

調査日: 2026-09-27（python requests / curl で取得。ブラウザ・WebSearch 不使用）

## 元記事
- ESPN「European Golden Shoe: Who's leading Raphinha, Mbappé, Haaland in race for top goal award?」Chris Wright、2026-09-25T07:46Z
  - https://www.espn.com/soccer/story/_/id/50010819/european-golden-shoe-whos-leading-raphinha-mbappe-haaland
  - ※ページ本体は requests で読めず（202）。**ESPN ニュースAPI（https://now.core.api.espn.com/v1/sports/news/50010819）で本文を取得して読んだ**。

## 核心
- **首位：ジョセフ・エデ・オロコ（Joseph Ede Oloko）**。ラトビア1部「ヴィルスリーガ（Virslīga）」、**トゥクムス2000（期限付き）→ 親クラブ FKリエパーヤ（FK Liepāja）**。
- **リーグ25得点（27試合）× 係数1 ＝ 25ポイント**。
- 2位ラフィーニャ（バルセロナ）は **12得点 × 係数2 ＝ 24ポイント**。差は**わずか1ポイント**。
  - ESPN "While he may have scored more than double the amount of goals, Oloko is only a hair's breadth ahead of Raphinha"（得点は倍以上なのに、差は紙一重）。
- ラトビアのリーグは11月上旬に終わり、オロコには**残り5試合**（ESPN）。欧州主要リーグは始まったばかりで、ESPN は「ラフィーニャがこのペースなら北欧勢がシーズンを終える前に首位に立つかも」と結ぶ。

## ポイントの計算（係数）
- ESPN の説明：
  - 5大リーグ（英・西・独・伊・仏）のゴール → **×2**
  - UEFA リーグ係数 6〜22位のリーグ → **×1.5**
  - 22位以下（原文 "22 and below"）→ **×1**
  - ※原文は「6-22」と「22 and below」で22位が重なっている。原文どおり。
- ラトビアは係数下位のため ×1（ESPN "Due to the Latvian top division's low-level standing in the UEFA league coefficient, Oloko's 25 goals are multiplied by a factor of 1"）。
- 前季（2025-26）の受賞はハリー・ケイン（バイエルン）：ブンデス36得点 → 72ポイント（2度目の受賞）。
- 上位に北欧・バルトの「夏開催リーグ」（3〜11月）の選手が並ぶのは、シーズンの大半を消化済みだから（ESPN）。

## 上位10人（ESPN 2026-09-25 時点）
「係数」列は ESPN が明記していない。**ポイント÷得点で私が逆算した値**。

| 順位 | 選手 | 所属 | 得点 | 係数（逆算） | ポイント |
|---|---|---|---|---|---|
| 1 | Joseph Ede Oloko | Tukums／FK Liepāja（ラトビア） | 25 | 1.0 | 25 |
| 2 | Raphinha | Barcelona（スペイン） | 12 | 2.0 | 24 |
| 3 | Kristian Stromland Lien | Djurgården（スウェーデン） | 16 | 1.5 | 24 |
| 4 | Robbie Ure | IK Sirius／Sevilla | 15 | 1.5 | 22.5 |
| 5 | Paulos Abraham | Hammarby IF（スウェーデン） | 14 | 1.5 | 21 |
| 6 | Mohamed Badamosi | Riga FC（ラトビア） | 20 | 1.0 | 20 |
| 7 | Amin Chiakha | Rosenborg（ノルウェー） | 13 | 1.5 | 19.5 |
| 8 | Isak Bjerkebo | IK Sirius（スウェーデン） | 13 | 1.5 | 19.5 |
| 9 | Josué Vergara | FK Auda／KAA Gent | 17 | 混在 | 18.5 |
| 10 | Erik Botheim | Malmö FF／Viking FK | 12 | 1.5 | 18 |

- 4位ユーレ：15点×1.5＝22.5 なので、得点はスウェーデン（シリウス）でのもの（セビージャでは未得点）と読める。
- 9位ベルガラ：17点で18.5ポイント。ラトビア（Auda、×1）とベルギー（Gent、×1.5）の合算。例えば「ラトビア14点＋ベルギー3点」なら 14＋4.5＝18.5 になるが、**内訳は ESPN に書かれておらず未確認**。
- ESPN の本文より：ムバッペとヤマルは7得点（14ポイント）で**21位タイ**＝5大リーグ勢でラフィーニャの次。ハーランド5試合5点、ムバッペ7試合7点、ケイン4試合3点（最初の国際Aマッチ期間の時点）。
- 3位リエンもラフィーニャと同じ24ポイント（ESPN は2位ラフィーニャ・3位リエンの順で掲載。並びの理由は書かれていない）。

## オロコの経歴
- 生年月日：**2001年1月10日、ナイジェリア生まれ**。ナイジェリアとベナンの二重国籍（Soccernet.ng がベナンの媒体を引用）。25歳。
  - https://soccernet.ng/2026/09/super-eagles-oloko-rohr-nigeria-benin.html （2026-09-20）
- 経路（Soccernet）：ナイジェリアの 36 Lion FC アカデミー → ベナンの AS Cotonou → チェコで数クラブ → ラトビア。**2025年1月にFKリエパーヤ加入**。2026年は開幕からトゥクムス2000へ期限付き、6月にリエパーヤへ復帰。
- ラトビアでの成績（Sportacentrs、2026-09-09）https://sportacentrs.com/futbols/virsliga/09092026-liepajnieks_ede_domine_augusta_un_virslig
  - 2024：FSイェルガヴァ 26試合11点
  - 2025：リエパーヤ 19試合1点1アシスト
  - 2026：トゥクムス（期限付き）16試合16点 → リエパーヤ復帰後9試合7点5アシスト（9/9 時点）
  - リーグ月間MVP：**5月（トゥクムス）と8月（リエパーヤ）の2回**。8月は4試合5点4アシスト。
  - 9/9 時点でリーグ得点王（23点）、2位はバダモシ（19点）
- その後（FKリエパーヤ公式）：
  - 9/11 第30節 オグレ・ユナイテッド 2-2：オロコ2点（79分、90＋9分PK）→ **リーグ25点目**
    - https://fkliepaja.lv/lv/2026/09/11/oloko-25-uzbrucejs-izglabj-mums-speli/
  - 9/19 第31節 BFCダウガフピルス 0-0：先発フル出場も無得点
    - https://fkliepaja.lv/lv/2026/09/19/neiskirts-sodien-bija-musu-laba/
- 全大会の数字（食い違い）：CAF（Soccernet 経由）は「**全大会30試合26点6アシスト**」。ESPN は「**リーグ27試合25点**」。どちらもあり得る（カンファレンスリーグ予選を含むかどうか）。
- **ベナン代表**：ジェルノ・ロール監督（元ナイジェリア代表監督）が初招集。**9/25 アフリカ杯予選 ブルキナファソ 1-1 ベナン（ワガドゥグー）で、88分にトシン・アイエグンと交代で代表デビュー**（ESPN API 試合記録 https://site.api.espn.com/apis/site/v2/sports/soccer/caf.nations_qual/summary?event=401920037 ）。次は 9/29 モーリタニア戦、10/6 ブエノスアイレスでアルゼンチンと親善試合（ESPN は「メッシのアルゼンチン代表お別れ試合」と記載）。
- 名前の表記ゆれ：ESPN・CAF「Joseph Ede Oloko」／ラトビア語「Džozefs Ede Oloko」／FKリエパーヤ「Oloko Ede」／ESPN 試合データ・Sofascore「Joseph Oloko Ede」。

## 本人の言葉（原文のまま）
### ベナン代表を選んだ理由（フランス語。Africa Top Sports が「Joueurs Béninois」のインタビューを引用、2026-09-23）
https://africatopsports.com/football/elim-can-2027-joseph-ede-oloko-explique-son-choix-du-benin/
> « Ma mère est béninoise, donc j'ai toujours eu ce lien avec le Bénin. J'ai également des origines nigérianes et je suis fier de ces deux facettes de mon identité »

訳：「母がベナン人なので、ずっとベナンとのつながりがあった。ナイジェリアのルーツもあって、自分のどちらの面も誇りに思っている」

> « Le Bénin fait partie de qui je suis et de mon histoire familiale. Pouvoir porter le maillot du Bénin et représenter le pays de ma mère est quelque chose de très spécial. »

訳：「ベナンは自分という人間と家族の歴史の一部。ベナンのユニフォームを着て母の国を代表できるのは、とても特別なことだ」

> « Ce que je peux apporter, c'est ma mentalité, ma capacité à travailler pour l'équipe et, bien sûr, mes buts »

訳：「自分がもたらせるのはメンタリティ、チームのために働けること、そしてもちろんゴールだ」

> « Le plus important reste l'équipe et le fait d'obtenir les résultats dont nous avons besoin lors des éliminatoires »

訳：「一番大事なのはチームであり、予選で必要な結果を取ることだ」

### リエパーヤ復帰後の初ゴールの後（ラトビア語。FKリエパーヤ公式、2026-07-02、聞き手はクラブ広報 M. Koroļovs）
https://fkliepaja.lv/lv/2026/07/02/oloko-ede-futbola-nekas-nav-viegli/
※インタビューがどの言語で行われたかは不明。掲載はラトビア語。
> Esmu laimīgs spēlēt futbolu un spēlēt FK "Liepāja". Vienmēr cenšos izdarīt laukumā visu, ko varu.

訳：「サッカーができて、FKリエパーヤでプレーできて幸せだ。ピッチではいつもできることを全部やろうとしている」

> Tomēr uzbrucējam kaut kādā ziņā jābūt egoistam laukumā, savādāk daudz vārtus neiesitīsi.

訳：「それでもストライカーはピッチの上である意味エゴイストでないといけない。そうでなければたくさん点は取れない」

> Futbolā vispār nekas nav viegli. Nepievērsiet uzmanību rezultātam. Katra spēle prasa ļoti nopietnas pūles, pie tam, no visas komandas.

訳：「サッカーに簡単なことなんてない。スコアに惑わされないで。どの試合もチーム全体の本気の努力が要る」

（「今季の得点王になれ、と願っておくよ」と言われて）
> Paldies, es pilnībā neesmu pret to. Bet saprotu, ka priekš tā vēl vajag ļoti nopietni pastrādāt. Varu tikai atkārtot: katrā spēlē darīšu visu, kas manos spēkos. Priekš tā, lai uzvarētu un priekš tā, lai iesistu.

訳：「ありがとう、まったく異論はないよ。でもそのためにはまだ本気で頑張らないといけないのも分かっている。繰り返すけど、毎試合できることは全部やる。勝つために、そして点を取るために」

- **ゴールデンシュー首位そのものについての本人の発言は見つからなかった**。

## 周りの言葉（ラトビア語、FKリエパーヤ公式）
- クーロ・トーレス監督（9/11 オグレ戦後）https://fkliepaja.lv/lv/2026/09/12/curro-torres-japalidz-oloko-vel-vairak/
  > Viņš glāba komandu, atnesa mums neizšķirtu. Oloko – ļoti svarīga figūra priekš FK "Liepāja". Visi zina, cik daudz vārtus viņš iesitis! Bet mums vajag daudz labāk palīdzēt viņam laukumā, jāpalīdz izveidot priekš viņa asas situācijas. Nepieļaujami, ka Oloko cīnās uzbrukumā vienatnē.

  訳：「彼がチームを救い、引き分けをもたらした。オロコはFKリエパーヤにとってとても重要な存在だ。彼がどれだけ点を取ったか皆知っている！　だが我々はピッチで彼をもっと助け、決定機を作らないといけない。オロコが前線で孤立して戦うのは許されない」
- チームメイト ダニーラ・パティイチュク（9/15）https://fkliepaja.lv/lv/2026/09/15/danila-patijcuks-oloko-tas-ir-kosmoss-vina-speli-vajag-redzet/
  （「オロコはラトビアリーグの、イングランドでいうハーランドのような得点マシンか」と聞かれて）
  > Kādēļ nē?! Man Oloko – tas ir kosmoss. Būšu stipri pārsteigts, ja pēc tādas sezonas viņš neaizbrauks uz klubu no TOP čempionāta. Tas, ko viņš dara, tā ir fantastika.

  訳：「当然だろ！　僕にとってオロコは宇宙だよ。こんなシーズンの後にトップリーグのクラブへ行かなかったらすごく驚く。彼がやっていることはファンタジーだ」
- チームメイト ベクナズ・アルマズベコフ（9/23）https://fkliepaja.lv/lv/2026/09/23/beknazs-almazbekovs-mums-obligati-jaspele-eirokausos/
  > Kad es tikai atbraucu uz Liepāju un uzzināju viņa statistiku, biju šokā – tas vienkārši TOP! Ļoti ceru, ka Oloko iesitīs 30 vārtus. Es viņam tajā obligāti palīdzēšu.

  訳：「リエパーヤに来て彼の数字を知ったときは衝撃だった。とにかくトップだ！　オロコには30点取ってほしい。僕も必ず手伝う」

## 反応（日本語）
- **この題材（オロコの首位・ゴールデンシューの係数）を扱った日本語の記事・コメント・Xの投稿は見つからなかった。**
  - Yahoo!ニュース検索「ゴールデンシュー」→ ケイン受賞（2025-26）の記事ばかり。
  - Yahoo!リアルタイム検索「オロコ ラトビア」→ 0件、「ゴールデンシュー」→ ケイン・メッシ等の話題のみ。
- 参考（ラフィーニャとゴールデンシューを結びつけた投稿。ESPN 記事への反応ではない）
  - @Montaito3（2026-09-10 03:05）https://x.com/Montaito3/status/2097748137637003317
    > ラフィーニャドブレテ！！やっと裏抜けに出してもらえたな。しかしこんな決定力高い人だったっけ？怪我しなけりゃゴールデンシューいけるレベルじゃない？

## 海外の反応
※個人ファンの書き込みは見つけられなかった。Bluesky で拾えたのは報道・まとめ系。Bluesky で「Oloko」を検索するとポルトガル語の感嘆詞「oloko」ばかり出てくるので注意。
- @balticfootball.bsky.social（英語、2026-09-17）https://bsky.app/profile/balticfootball.bsky.social/post/3mvq4ilvqzl2u
  > Joseph Ede Oloko earns first Benin call-up after prolific Virslīga season / FK Liepāja striker Joseph Ede Oloko has received his first call-up to the Benin national team after establishing himself as the leading scorer in the Latvian Virslīga.

  訳：ジョセフ・エデ・オロコ、ヴィルスリーガでの量産でベナン代表初招集。FKリエパーヤのストライカーはラトビア1部の得点王として地位を固め、ベナン代表に初めて呼ばれた。
- @kristil.bsky.social（英語、2026-09-10）https://bsky.app/profile/kristil.bsky.social/post/3mv5yhzixjx2l
  > Ede Oloko wins Virsliga Player of the Month again after explosive August form

  訳：エデ・オロコ、爆発的な8月でまたもヴィルスリーガ月間MVP
- @fcbarcelona-news.bsky.social（英語、2026-09-22）https://bsky.app/profile/fcbarcelona-news.bsky.social/post/3mw2xw2qdon2l
  > Raphinha emerges as a contender for the European Golden Shoe

  訳：ラフィーニャ、欧州ゴールデンシューの有力候補に浮上
- ナイジェリア・ベナンの報道見出し（Google News RSS で確認、本文未読のものあり）
  - The Nation（ナイジェリア、9/26）"Beninese Oloko battles Raphinha, Haaland for Euro Golden Shoe"（訳：ベナンのオロコ、ラフィーニャ・ハーランドと欧州ゴールデンシューを争う）— 本文は 403 で読めず
  - Soccernet.ng（9/20）"Ex-Super Eagles coach Gernot Rohr 'steals' 26-goal Nigerian striker for Benin"（訳：元ナイジェリア代表監督ロール、26得点のナイジェリア人FWをベナンに「かっさらう」）— 本文読了
  - Banouto.bj（ベナン、9/18）"Equipe nationale du Bénin : qui est Joseph Oloko Ede, le néo-Guépard ? 03 choses à savoir"（訳：ベナン代表の新顔オロコ・エデとは？知っておくべき3つのこと）— 本文未読

## 写真候補
- ESPN 記事内: オロコの写真（https://a.espncdn.com/photo/2026/0923/r1720733_1184x666_16-9.jpg）クレジット「**FK Liepaja/Facebook**」— クラブ提供写真。使うならクラブの写真として扱う（ESPN から直接取らず、クラブ公式の元写真を探す方がよい）
- ESPN 記事の見出し画像: https://a.espncdn.com/photo/2026/0923/r1720737_1295x729_16-9.png クレジット「ESPN」（ラフィーニャ・ムバッペ・ハーランドの合成。元写真は代理店の可能性が高く**除外推奨**）
- ESPN 記事内: ケインの写真 クレジット「Christoph Lother/picture alliance via Getty Images」→ **Getty のため除外**
- FKリエパーヤ公式
  - 9/11 記事の画像 https://fkliepaja.lv/wp-content/uploads/2026/09/IMG_8773.jpeg（クラブ撮影、クレジット表記なし）
  - 7/2 インタビューの画像 https://fkliepaja.lv/wp-content/uploads/2026/07/IMG_7588.jpeg（記事末尾に「Foto liepajniekiem.lv」）
- Sportacentrs og:image: https://i1.tiesraides.lv/1200x0s/pictures/2026-09-09/a3cb_joseph_oloko_fk_liepaja.jpg — ページ内に「Foto: Sanita Sparāne/RFS」の表記があるが、この画像のものかは未確認
- Africa Top Sports og:image: https://africatopsports.com/wp-content/uploads/2026/09/Joseph-Ede.jpg — クレジット未確認
- Soccernet.ng: 写真説明「Photo by IMAGO」→ **IMAGO は写真代理店のため除外**
- Wikimedia Commons: **オロコ本人の写真は見つからなかった**。
  - FKリエパーヤ関連：File:FK Liepaja gegen FC Salzburg (CL-Quali) 01.jpg ほか（CC BY-SA 4.0, Werner100359, 2016-07-19）— 2016年の試合。今の選手は写っていない
  - ラフィーニャ：File:Raphinha Brazil V Morocco 13 June 2026-208.jpg ほか（CC BY-SA 4.0, Bryan Berlin, 2026-06-13）、File:Brazil vs Serbia WC2022 Raphinha and Pavlovic.jpg（CC BY 4.0, Hossein Zohrevand, 2022）

## 確かめられなかったこと
- ESPN の記事ページ本体（API で本文は取得済み）。
- 上位10人の「係数」（ESPN は得点とポイントだけ。表の係数は逆算）。ベルガラ（9位）のラトビア／ベルギーの得点内訳。
- 同点24ポイントのラフィーニャ（2位）とリエン（3位）の順位の付け方。
- ESPN の「27試合25点」と CAF の「30試合26点6アシスト」の差の内訳（カンファレンスリーグ予選の得点かどうか）。
- オロコの経歴のうち「チェコでの数クラブ」の具体名、36 Lion FC・AS Cotonou 在籍年（Soccernet の記述のみ）。
- ゴールデンシュー首位についての本人の発言。
- 日本語・海外の一般ファンの反応（見つからず）。
- The Nation（ナイジェリア）の本文（403）。
