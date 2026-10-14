# エリオット・アンダーソン（マンチェスター・シティ）の材料（2026-10-14）

集め方：WebFetch と python の requests（普通のブラウザの User-Agent）だけ。ブラウザ操作の道具・検索エンジンの要約は使っていない。
読めたものは**一次情報（クラブ公式・本人の取材記事・リーグ／協会・試合記録）まで辿った**。読めなかったものは各項に「未確認」と書いた。
FotMob の控えは research/player_pool/fotmob_1089691.json（今季＝2026/27 のプレミア6試合）。ライスの比較は FotMob 654096 を引き直した（控えは作業用フォルダのみ）。

## 0. 先に：雛形の数字の直し・食い違い

- **雛形の「18歳の市場価値は1500万ユーロ」は誤り。** Transfermarkt の履歴（`/player/567576/market-value-history`）は
  2021-03-17（18歳）**20万ユーロ** → 2022-09-15（19歳）150万 → 2023-06-20 800万 → 2024-05-27（21歳、ニューカッスル最後）**1500万**（ニューカッスル時代の最高）
  → 2024-10-01 2200万（フォレスト）→ 2025-12-09 6000万 → 2026-06-03 7500万 → 2026-07-22 **1.1億**（フォレストでの最高）→ 2026-10-07 **1.2億**（シティ、最高）。
  「1500万」は在籍期間の最高額であって18歳の値ではない。読み上げは「18歳で20万ユーロ」に直した。20万→1.2億は**600倍**（自分で計算）。
- **レーダー（FotMob traits）と棒グラフ（雛形の武器・弱点）で数字が違う。** 雛形のコメント「パス成功100・ボールタッチ100・ラインを破るパス96・得点0」は
  FotMob の今季プレミア6試合の statsSection（percentileRank。ボールタッチ100、パス成功100、ラインを破るパス97、得点0）。
  板のレーダー画像は traits（stats_comparison_midfielders：ボールタッチ97・空中戦91・守備の関与84・チャンス創出68・シュート数67・得点45）。
  **画面に出るレーダーに合わせて、棒グラフもレーダーの数字（97／91／84／68／45）にした。**今季6試合の絶対値（90分あたり）は季の節で数として読む。
- **シティ公式の「クラブでの出場174試合」は、同じ記事の季ごとの表（2＋21＋27＋26＋42＋50＝168）と合わない。**
  FotMob・英語版Wikipedia（55／21／92）・サッカーキング（フォレスト92試合6得点11アシスト）は一致するので、168（＋シティ8）を使った。
- **ブリストル・ローヴァーズの得点：** BBC（最終節の記事）は途中の文で「8得点」、FotMob・シティ公式・Wikipedia は **21試合7得点**。7を使う（BBC の8は最終節の得点を足した別の数え方の可能性。未確認）。
- **パス数：** BBC（Opta）は中央のMFで最多の 2,038 本、シティ公式は 2,080 本。**パスの本数は読み上げない**。使うのは両方に出る「ボールタッチ3,300回」だけ。
- **移籍金：** シティ公式の発表に金額は無い。サッカーキング（ジ・アスレティック）・Sky Sports は 1億1600万ポンド。「報道で」と言う。
  Sky は「英国人選手の史上最高額（ベリンガムの1億1500万ポンドを上回る）」と書いた。のちにモーガン・ロジャーズが1億1700万ポンドで抜いた（英語版Wikipedia・Sky）が、翌日の回の主役なので台本では触れず、「発表の時点で」とだけ言う。
- **試合の日付は現地の日付**（ESPN で確認）：10/11 リバプール戦（0対3でシティの勝ち）。**ドクの68分のゴールをアンダーソンがアシスト**（ESPN の試合記録 event 401879264）。
- **シティの次の試合：** ESPN は 2026-10-14 19:00Z（＝日本時間 10月15日 午前4時）、シティ対パリ・サンジェルマン（エティハド）。

## 1. 一言の定義と意外な事実

- **昨季（2025/26）のプレミアで、全選手のなかでボールタッチが最多＝3,300回**（Opta の集計。BBC Sport「Opta's team of the season」、シティ公式の加入記事も同じ 3,300）。
  原文（BBC）：「Among all the players, he had the most touches (3,300), won the most duels (297), won the most fouls (80) and won the most possession overall (306).」
  https://www.bbc.com/sport/football/articles/cgmppp4x34eo
  → 38試合（全試合出場）で割ると1試合あたり約87回（自分で計算）。
- **同じ記事：**「He was the first player to win possession more than 300 times and make more than 100 tackles in a Premier League season since Declan Rice in 2019-20.」／「his 297 duels won were the best by an English midfielder in a campaign since records began in 2006-07」／
  「Among the central midfielders, he made the most line-breaking passes (376), completed the most overall passes (2,038) and made the most dribbles (95).」／「1,895 high-intensity pressures being the most applied by a central midfielder」
- シティ公式（加入記事、2026-07-23）：昨季プレミアの走行距離 **411キロ**（「only one player covered more ground」＝2番目）、タックル **104**（4番目に多い）、「appeared in every single league game for Forest last term」。
  https://www.mancity.com/news/mens/elliot-anderson-signs-for-man-city-63920416
- 生まれ：イングランド北東部ウィットリー・ベイ（Premier League 公式「grew up in Whitley Bay, close to Newcastle's St James' Park」、英語版Wikipedia・FotMob の生年月日 2002-11-06 と一致）。
  地元の名門 **ウォールセンド・ボーイズクラブ（2007〜10）→ 8歳でニューカッスルの下部組織**。クラブ公式（NUFC、2020-11）「A former Wallsend Boys Club player, Anderson joined the Magpies' Academy at the age of eight」。
  ウォールセンドの出身者にアラン・シアラー、ピーター・ビアズリー、マイケル・キャリック（ガーディアン 2025-09-04。英語版Wikipedia「Wallsend Boys Club」も同じ）。
- **幼少期の逸話（スタンドの最上段）：** クロニクル・ライブ（2019年に本人に取材した記事を2026年に再掲した「From idolising Cabaye to World Cup role…」）
  原文：「I was a supporter of the team as a kid. I watched players like Yohan Cabaye, Hatem Ben Arfa and Peter Lovenkrands. I used to watch from right at the top of Level 7 so it is quite surreal to be around the place now. I just continue to work hard though.」
  https://www.chroniclelive.co.uk/sport/football/football-news/how-toon-teen-elliot-anderson-17267757
  日本語（自訳）：「子どものころ、ずっとサポーターでした。いつもスタンドのいちばん上の席から見ていた。だから、いまここにいるのは、不思議な気分です」（"Level 7" は「7階席」だが、聞いて通じるよう「いちばん上の席」とした）。

## 2. プレースタイル

- 同じMFの中の位置（FotMob traits、100が最上位）：ボールタッチ **97**・空中戦 **91**・守備の関与 **84**・チャンス創出 68・シュート数 67・得点 45。
- 今季（2026/27）プレミア6試合・505分（FotMob statsSection）：ボールタッチ **641**（90分あたり114.2）・パス成功 470（83.8）・ラインを破るパス **126**（22.5）・競り合いの勝ち 46（8.2）・タックル14・走った距離。
  シュート6本（ペナルティエリアの中1、外5。うち5本がコーナーキックのあとの場面）、xG 0.20、決定率0%、最高速度 時速30.0キロ。
- **他者の評（トゥヘル監督、代表デビュー戦のあと、ガーディアン 2025-09-06）：**
  原文「He's just a very, very good football player. He has the physicality, he's very mobile at No 6. He has the body, he loves to defend, he loves to put his body inside to duels. He loves passing, he loves to break the lines, he's very mobile in this game. It was a pleasure to see.」
  https://www.theguardian.com/football/2025/sep/06/thomas-tuchel-hints-elliot-anderson-will-start-for-england-in-serbia
  日本語（自訳）：「守ることが好きで、競り合いに体を入れる。パスが好きで、ラインを破る」。
- ジョーイ・バートン（ブリストル・ローヴァーズ監督、2022-03-16）：「slows down in the penalty area, exactly like Elliot Anderson does」とマラドーナになぞらえた（クロニクル・ライブ）。**使わなかった**（19歳への大げさな比較で、ペナルティエリアの話は今の形と合わない）。
- シティのスポーツ・ディレクター、ウーゴ・ヴィアナ（公式）：「He offers energy, outstanding work rate and an exceptional range of passing」「we feel he can become a complete midfielder」。使わなかった（評は1つまで）。
- 弱点：得点（traits で45＝真ん中。今季プレミアは0得点、xG 0.2）。**体の数字**：身長179センチ（Transfermarkt 1.79m・FotMob 179cm・シティ公式で一致）、走行距離 411キロ（昨季）、最高速度 時速30.0キロ（今季、FotMob）。

## 3. 転機

1. **2022-05-07、リーグ2最終節、ブリストル・ローヴァーズ 7-0 スカンソープ**（BBC Sport）：ローヴァーズは3位のノーサンプトンに得失点差で並び、**得点数で上回って自動昇格**。
   アンダーソンは**3アシスト**（コリンズの17点目で3つ目）と、**残り5分のヘディングで7点目**。原文「Elliot Anderson completed a hat-trick of assists」「And with five minutes left, Evans' cross was deflected to Anderson to head in」。
   https://www.bbc.co.uk/sport/football/61281127
   背景：2022-01-31 にニューカッスルから期限付きで加入（19歳）。2月19日ステヴェニッジ戦でプロ初ゴール、3月のコルチェスター戦は決勝点（監督バートンが「Maradona」と評した試合）。EFL 4月の月間若手選手賞（EFL 公式 2022-05。**ページは JS で読めず未確認**。英語版Wikipedia・日本語版Wikipedia の記載）。21試合7ゴール6アシスト（FotMob・シティ公式）。
2. **2024年7月、ニューカッスル → ノッティンガム・フォレスト（5年契約、報道で3500万ポンド）：** Sky Sports「Although Anderson did not want to leave his boyhood club...」（記者 Keith Downie）。ニューカッスルは PSR の理由で売る必要があった。
   https://www.skysports.com/football/news/12040/13161291/newcastle-transfers-elliot-anderson-completes-35m-move-to-nottingham-forest-and-yankuba-minteh-joins-brighton-for-30m
   本人（ガーディアン 2025-09-04）：「It was a tough move at the time but ultimately, I probably wouldn't be sitting here now if I didn't make the move. Sometimes you've got to step out of your comfort zone and believe in yourself, which is what I've done. I believed I was ready to go and play in the Premier League every week」
   日本語（自訳）：「あのときはつらい移籍でした。でも、あの決断をしていなければ、いまここにいなかったと思います」。
   フォレスト初のプレミア得点：**2025-01-19、サウサンプトン戦（3-2）の11分**（ESPN の試合記録で確認。Wikipedia・BBC の記載とも一致）。
3. **2025年の代表：** U-21欧州選手権（スロバキア）。準々決勝のスペイン戦（3-1）で90+4分にPKを決め（ガーディアン 2025-06-21）、決勝は先発してドイツに3-2（延長）で優勝（ESPN で 2025-06-28・3-2 を確認）。
   **A代表デビュー：2025-09-06、アンドラ戦（2-0、ビラ・パーク）、先発の「No 6」**（ガーディアン 2025-09-06。ESPN の試合記録 2-0）。
4. **2026-07-02：シティが獲得で合意**（シティ公式。ワールドカップ参加中で、メディカルはカンザスで済ませた）。報道で1億1600万ポンド（サッカーキング／ジ・アスレティック、Sky）。**7月23日に5年契約で正式加入**（シティ公式）。
   ワールドカップは3位（3位決定戦でフランスに6-4。ESPN 2026-07-18。アンダーソンは11分出場、準決勝のアルゼンチン戦は90分）。大会初出場は初戦のクロアチア戦（イングランド公式プロフィール）。

## 4. エピソード・人物像

1. **祖父ジェフ・アレン（母方）**：1960年代のニューカッスルの左ウイング。1964年4月ノーリッチ戦で17歳でデビュー、**1968年9月11日、クラブ初のヨーロッパ（フェアーズカップ）の試合＝フェイエノールト戦で最優秀選手級の活躍**（クラブ初の欧州でのゴールをお膳立て、クロスバーも叩く）。
   数週間後のノッティンガム・フォレスト戦で大けが、**23歳で現役を終えた**（26試合1得点）。
   https://www.chroniclelive.co.uk/sport/football/football-news/elliot-anderson-newcastle-geoff-allen-19622397（2021年1月、デビュー直後）
   クラブ公式（NUFC、2020-11-06、18歳の誕生日に新契約）：https://www.newcastleunited.com/en/news/anderson-wants-to-keep-following-in-grandfathers-footsteps-after-signing-new-contract
   本人原文：「You just want to sort of try and carry it on. He got injured quite early which was a shame, but it gives you that bit more motivation to do it. Every kid's dream is to play for Newcastle - and it's mine too, so hopefully I can be successful with it.」
   日本語（自訳）：「祖父の歩んだ道を、受け継いでいきたい。祖父は早くにケガで終わってしまった。だから、その分、力が湧くんです」。
   **注意：**ここは祖父の選手経歴（クラブ公式・地元紙が書いている）だけで、家族の私生活には入らない。母・父の名前は出さない。祖父のフルネームの読み「ジェフ・アレン」は未確認（日本語の記事が見つからない）。
2. **憧れの選手はケヴィン・デ・ブライネ。**
   ガーディアン（2025-09-04）原文：「He was my favourite player over the past four or five seasons in the Premier League. I was watching him all the time, just his eye for a pass for me. The way he plays, how nice he is to watch, really caught my eye. He was the player I was trying to copy. He's a top, top player so I'll be doing something right if I can half copy him.」
   https://www.theguardian.com/football/2025/sep/04/elliot-anderson-england-scotland-newcastle-nottingham-forest-world-cup-qualifiers
   日本語（自訳）：「この4、5年、プレミアでいちばん好きな選手でした。いつも見ていた。パスを出す目に、引きつけられた。僕が真似しようとした選手です」。
   シティ公式（2026-07-23、加入初日のインタビュー）：「I think Kevin De Bruyne is someone who I've hugely looked up to over the past seven or eight years. As I came up through the academy at Newcastle, I always wanted to play like him. I've watched him all the time and to be sat here in the same team he was doing it for is so special.」
   https://www.mancity.com/citytv/mens/elliot-anderson-says-he-has-joined-the-kings-of-manchester-watch-his-first-manchester-city-interview-63920407
   日本語（自訳）：「ニューカッスルの下部組織にいたころから、彼のようにプレーしたかった。いつも見ていた彼のいたチームにいま座っているのは、特別なことです」。
   同じガーディアンの記事：2025年の開幕戦（ブレントフォード戦、3-1）で**クリス・ウッドの2つ目のゴールを鋭いパスで演出**。
3. **「俺は間違いなくイングランド人」**：スコットランドの祖母の血で年代別代表（U16〜U21）に出たが、2023年8月のA代表招集を辞退してイングランドを選んだ（ガーディアン 2025-09-04）。「I'm definitely English」。**使わなかった**（代表選択の話は本題から外れ、デイリー・レコードには推測記事もあり裏が薄い）。
4. 子どもの頃のお気に入りは、ヨアン・カバイェ、ハテム・ベン・アルファ、ペーター・ロヴェンクランズ（上の1の引用に含まれる）。ベン・アルファの日本語表記は未確認（Hatem Ben Arfa）。

## 5. 本人の言葉（台本で使う4件・原文は上の各項）

| 使う場所 | 原文の出典 | 日本語 |
|---|---|---|
| フック | クロニクル・ライブ（2019年の取材） | 「ずっと、スタンドのいちばん上の席から見ていた。いまここにいるのは、不思議な気分です」 |
| 歩み（語りに言い換え） | ガーディアン 2025-09-04 | あの移籍がなければ、いまここにいない |
| マル秘話1 | NUFC 公式 2020-11-06 | 「祖父の歩んだ道を、受け継いでいきたい。祖父は早くにケガで終わってしまった。だから、その分、力が湧くんです」 |
| マル秘話2 | ガーディアン 2025-09-04 | 「この4、5年、プレミアでいちばん好きな選手でした。…パスを出す目に、引きつけられた。僕が真似しようとした選手です」 |
| マル秘話3 | シティ公式 2026-07-23 | 「いつも見ていた彼のいたチームに、いま座っているのは、特別なことです」 |

## 6. 写真の候補（Commons）

**未取得**（ユーザーが取る）。英語版Wikipedia の画像は「Elliot Anderson England v Ghana 23 June 2026-059 (cropped).jpg」（2026年ワールドカップ）。ライセンス・撮影者は未確認。

## 7. 日本語の呼び方

- サッカーキング・日本語版Wikipedia は「エリオット・アンダーソン」。ニューカッスル、ノッティンガム・フォレスト、ブリストル・ローヴァーズ（日本語版 Wikipedia の表記）、スカンソープ・ユナイテッド、ウォールセンド・ボーイズクラブ（日本語版 Wikipedia にページなし）。
- 「ケヴィン・デ・ブライネ」（日本語版 Wikipedia のページ名）。「トゥヘル」（サッカーキングほか）。「ジェレミー・ドク」「クリス・ウッド」（リポジトリ内の台本の表記）。

## 7.5 入れなかった材料

- 兄の話・家族の暮らし（私生活）。デイリー・レコードの「スコットランド代表が楽しくなかった」という推測記事。ジョーイ・バートンのマラドーナ評。
- ニューカッスルを売った背景の PSR の細かい話・ニューカッスル側の内情（クラブの話）。
- ワールドカップ決勝トーナメントの詳細（本人の出場は短い・本題から遠い）。

## 8. 数字の食い違い（上の0に集約）

0 を見る。
