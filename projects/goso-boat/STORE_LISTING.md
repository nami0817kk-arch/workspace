# 護送ボート / Prison Boat — ストア掲載文の下書き（iOS のみ）

2026-09-26 作成。ユーザーの指示「iOS でインストールされる可能性をあげて」に向けたもの。
公開名義は「つるはし社」。本名・nami・0817 は入れない。

## 調べたこと（App Store 日本、iTunes Search API で上位の評価数を見た）

| 検索語 | 上位10の評価数（中央値） | 読み |
|---|---|---|
| 川渡り / River crossing | 0 / 1 | 競合がほぼいない。1位は取りやすいが、探す人も少ないと見られる |
| 脱獄 / 脱獄ゲーム | 2,145 / 6,829 | 囚人ものの需要はある（脱獄ごっこ 10万件） |
| 論理パズル | 116 | 需要はあり、競合が弱い。**狙い目** |
| 思考力 | 10,442 | 中くらい |
| 頭の体操 / ひらめき / 脳トレ | 14,585 / 25,409 / 103,448 | 需要が大きいが強い競合がいる。名前・サブタイトルに入れて拾う |
| パズルゲーム / 暇つぶし | 205,150 / 82,160 | 大手の独占。キーワード欄だけに入れる |

検索の回数そのものは Apple の公開情報では見られない（Apple Search Ads の人気度が要る）。
上の表は「その語で出てくるアプリがどれだけ遊ばれているか」の目安で、需要の直接の数字ではない。

英語版を作ることにした（2026-09-26 ユーザー決定）。英語（米国）の掲載情報は海外の人が読むので、
キーワード欄は英語の検索語で埋める（日本の検索のために日本語を入れる案はやめた）。

## 名前・サブタイトル・キーワード

| 項目 | 日本語（17／19／93字） | English (US)（27／27／94字） |
|---|---|---|
| 名前（30字まで） | 護送ボート：囚人を渡す川渡りパズル | Prison Boat: River Crossing |
| サブタイトル（30字まで） | 脱獄させるな！頭の体操・ひらめき脳トレ | Logic puzzle & brain teaser |
| キーワード（100字まで） | 脱出,刑務所,警察,警官,看守,IQ,IQテスト,論理,ロジック,思考力,謎解き,クイズ,暇つぶし,オフライン,無料,舟,船,中州,知育,推理,難問,頭脳,ブレイン,頭を使う,考える | prisoner,jail,escape,police,cop,guard,brain,iq,test,riddle,logic,think,ferry,wolf,goat,cabbage |

- 名前とサブタイトルに入れた語（護送・ボート・囚人・渡す・川渡り・パズル・脱獄・頭の体操・ひらめき・脳トレ）はキーワード欄に重ねない
- ホーム画面の表示名は 日本語「護送ボート」、英語「Prison Boat」（ios/Runner/*.lproj/InfoPlist.strings）
- 英語のキーワードの wolf, goat, cabbage は「狼と山羊とキャベツ」の川渡り（英語圏で一番知られた形）を探す人向け

## 配信する国

日本と、EU を除く全地域。EU はサカマネと同じく対象外（配信すると販売者として住所などの公開を求められる）。
中国本土はゲームの配信に許可番号が要るので対象外。

## English description

You're the escort: ferry prisoners across the river — but if the guards are outnumbered, they escape!
Load officers and prisoners into the boat and get everyone to the far bank without losing a single one.

■ One simple rule
On a bank or in the boat, prisoners escape if they outnumber the guards. Leave prisoners with no guard, and they escape too.

■ Plan your moves on a river island
Leave people on an island mid-river. The boat can't go straight across — it stops at the island on the way.
But the island needs guards too. Who stays where?

■ New helpers, tougher prisoners
• Boss — needs two guards alone
• Police dog — guards, but can't row
• Chief — guards two prisoners alone
• Cuffed pair — chained together, takes two seats

■ 120 levels, 3 stars for the shortest route
Every level is solvable. Cross in the fewest trips to earn 3 stars.
Stuck? A hint shows your next move. Undo and restart any time. Plays offline.

Promotional text: Escort prisoners across the river without letting one escape. A river island, a boss, a police dog and cuffed pairs. 120 levels; the shortest route earns 3 stars.

## カテゴリ

ゲーム ＞ パズル（主）、ゲーム ＞ ボード（副）。年齢区分は 4+ を目指す（暴力の表現は無し。警棒は持っているだけ）。

## 似たアプリ（2026-09-26 調査、iTunes Search API）

| アプリ | 評価件数 | 中身 | こちらとの違い |
|---|---|---|---|
| ぷくぷく川渡り（BEAK、日本、2026-06） | 0 | 動物の川渡り32面。「2席使う子」「漕げる子」「人数の釣り合い」がある | **いちばん近い。** こちらは題材が護送、**中州・ボス・警察犬**が向こうに無い、120面、英語あり |
| River Crossing IQ（米国、2017〜） | 529 | 狼・羊・キャベツ、夫婦などの古典集。絵は簡素 | 古典の詰め合わせ。こちらは1つの世界観で段階的に仕掛けが増える |
| River Crossing IQ Logic（米国、2017〜） | 213 | 古典の詰め合わせ＋新作 | 同上 |

- **「警官が囚人を逃がさず護送する」川渡りは、App Store に見当たらない。** 広告ではよく見る遊びなのに、それを遊べるアプリが無い。ここを1枚目で見せる
- 川渡りの分野は探す人も競合も少ない（米国最大でも評価529件）。人は「脳トレ」「論理パズル」「脱獄」の検索から呼ぶ
- **Apple 4.3（似たアプリ）への備え:** 掲載文・画像では、向こうに無い要素（護送の題材・中州・ボス・警察犬・最短手数の星）を前に出す。
  動物・食べられる、といった向こうの言葉や絵は使わない。審査で聞かれたら、面は自前の探索で作り全面を機械で検査している、と答えられる

## スクリーンショット（6.9インチ縦、最初の3枚が検索結果に出るので勝負はそこ）

1. 「警官が囚人を護送。1人も逃がすな！」 … 舟に警官と囚人が乗って渡っている場面（**ほかに無い題材を一目で**）
2. 「見張りが足りないと…脱走！」 … 囚人に「!」が出て逃げる場面と「脱走された」の札
3. 「川の中州で作戦を立てろ」 … 中州のある面（**ほかの川渡りアプリに無い仕掛け**）
4. 「ボス・警察犬・看守長・手錠の2人」 … 役の紹介を並べる
5. 「全120面。最短で渡れば★3」 … ステージ選択（ヒントで光っている場面を添える）

広告で見た人が「あの広告のゲームだ」と気づけるよう、1枚目は広告と同じ構図（川・舟・警官と囚人）にする。
ただし広告の絵柄そのものは真似しない（Apple 4.3 と著作権の両方のため）。

## プロモーションテキスト（170字まで・審査なしで差し替えられる）

警官が囚人を舟で護送する川渡りパズル。見張りが足りないと、すぐに脱走！ 川の中州、ボス、警察犬、手錠の2人。全120面、最短で渡れば★3。

## 説明文

あなたの仕事は、囚人を舟で向こう岸へ運ぶ「護送」。
でも見張りが足りないと、囚人はすぐに逃げ出してしまう――。
警官と囚人を舟に乗せ、1人も逃がさずに全員を向こう岸へ渡しきる、頭を使う川渡りパズルです。

■ 決まりはひとつ
岸でも舟の上でも、見張りが囚人より少ないと逃げる。見張りのいない所に囚人を残しても逃げる。

■ 川の中州で作戦を立てる
川の途中にある中州に、人を残しておける。岸から岸へ直接は行けず、中州を経由して1区間ずつ運ぶ。
でも中州でも見張りが要る。誰をどこに残すか、先を読む力が試される。

■ 新しい仲間と、やっかいな囚人
・ボス … 1人でも見張りが2人分いる
・警察犬 … 見張れるけれど舟は漕げない
・看守長 … 1人で2人分を見張れる
・手錠の2人 … 離れられず、舟の席も2つ使う

■ 全120面・最短クリアで★3
すべての面は必ず解けます。最短の回数で渡りきれば星3つ。
詰まったらヒントで次の一手がわかります。一手戻す・最初からも自由です。

■ こんな人に
・ひらめき系、論理パズル、頭の体操が好きな人
・家族や友だちと一緒に考えたい人
・通信なしで、すき間時間に遊べるゲームを探している人
