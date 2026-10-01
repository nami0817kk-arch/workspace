# 材料の控え: マンチェスター・シティ、財務規則違反で「すべての告発で有罪」（2026-10-01 取材、公開 10/2）

題材: プレミアリーグの独立委員会が 9/29、シティを財務規則の重大な違反について「すべての告発で有罪」と認定した件。罰は別の審理。
同じ日に「グアルディオラの手紙」（10/1 公開）が出ているので、手紙の中身は扱わない。翌日にハーランド紹介が出るので、ハーランドの話も入れない。
9/30 の city_titles（判決前の前提）は使わない。

取り方: curl＋python requests（HTML から段落を抜いた）、WebSearch（見出しと URL を探すだけ。要約は根拠にしない）、Google News の RSS（見出しと時刻だけ）、Bluesky の公開検索 API、Yahoo!リアルタイム検索。ブラウザの道具は使っていない。

## 出典（読めたもの）

| 媒体 | URL | 中身 |
|---|---|---|
| プレミアリーグ公式（9/29） | https://www.premierleague.com/en/news/4727779/premier-league-statement-manchester-city-fc | 認定の中身・£900m 超・マスターズの言葉・罰は別の非公開の審理・上訴は 10月2日（金）まで・調べ始め 2018年12月／告発 2023年2月／審理42日は 2024年12月に終了 |
| シティ公式の声明（9/29） | https://www.mancity.com/news/club/manchester-city-club-statement-premier-league-63926128 | 「クラブは無実」「上訴に進む」「法律・原則・事実に明らかな誤り」 |
| Sky Sports 要点（9/29 23:34 UK） | https://www.skysports.com/football/news/11661/13593407/man-city-charges-verdict-key-findings-the-fordham-arrangement-effectively-a-front-for-abu-dhabi-united-group | スポンサー料の内訳（£949.94m／£119.25m／£830.69m）・2009-10 の最大赤字回避・Fordham・証人27人／42日・偽りの証言・上訴の期限 |
| Sky Sports 上訴の手順（9/30 13:52 UK） | https://www.skysports.com/football/news/13593377/man-city-premier-league-charges-appeal-process-punishment-hearing-and-what-happens-now-after-guilty-verdict | 新しい3人の委員会・CAS には行けない・罰の上限は決まっていない・過去の勝ち点剥奪（エヴァートン6＋2、フォレスト4、ルートン30、ダービー21） |
| BBC（9/29） | https://www.bbc.com/sport/football/articles/c63reg93xwzro | 優勝3季の £360m のうち本物は £43m・バーンスタイン「プレミアに残れない」・証人の偽証 |
| BBC（9/30 13:17 UTC） | https://www.bbc.com/sport/football/articles/c9y7zr4l6de1o | 上訴は12週＋30日・シティは5戦全勝で首位・ユヴェントス2006の降格 |
| BBC（9/30 19:10 UTC） | https://www.bbc.com/sport/football/articles/c6vgyg3zv3kwo | 他クラブ幹部「今季中に罰を」・エティハドの声明 |
| Guardian（9/30） | https://www.theguardian.com/football/2026/sep/30/rival-clubs-feel-relegating-manchester-city-championship-not-enough-premier-league | 他クラブ幹部「2部へ1季では足りない」・上訴は期限から12週＋30日＝1月末・前例は無い・エヴァートン £19.5m で 10→6 |
| Guardian（9/29） | https://www.theguardian.com/football/2026/sep/29/manchester-city-ceo-soriano-says-guilty-verdicts-are-a-premier-league-conspiracy-theory | ソリアーノの職員向け動画の言葉 |
| Guardian（9/30） | https://www.theguardian.com/football/2026/sep/30/etihad-airways-considering-legal-action-premier-league-manchester-city | エティハド航空の声明（"categorically rejects"・法的措置を検討） |
| Al Jazeera（9/30） | https://www.aljazeera.com/sports/2026/9/30/what-will-happen-to-man-city-after-the-premier-leagues-guilty-verdict | 規則 W64 の罰の幅・エヴァートン／フォレストの前例 |
| Football Today（9/29、The Athletic の引用） | https://footballtoday.com/2026/09/29/former-spurs-boss-pochettino-on-man-city-guilty-verdict-we-lived-through-a-period-of-deception | ポチェッティーノの言葉 |
| City Xtra（9/29） | https://cityxtra.co.uk/news/mauricio-pochettino-launches-scathing-attack-on-manchester-city-after-premier-league-guilty-verdict | ポチェッティーノの言葉（"impossible to turn back time"） |
| Guardian（2024-03-18） | https://www.theguardian.com/football/2024/mar/18/nottingham-forest-docked-four-points-premier-league-financial-rules-breach-profitability-and-sustainability | フォレストは上限 £61m を £34.5m 超え、勝ち点4。エヴァートンは £19.5m で 10→6 |
| プレミアリーグ公式（2023-11-17） | https://www.premierleague.com/news/3788486/ | エヴァートンの損失 £124.5m が上限 £105m を超えた（＝£19.5m） |
| 英語版Wikipedia Calciopoli | https://en.wikipedia.org/wiki/Calciopoli | ユヴェントスは Serie B へ降格、2004-05 の優勝は取り消し（空位）、2005-06 は最下位扱いで優勝はインテルへ |
| 手元の順位表の控え | research/standings/2026-09-28.json | 5節まで：シティ 5勝0分0敗 勝ち点15、アーセナル12、ブライトン10 |

読めなかったもの: ESPN（202 で本文が空）。Telegraph の専門家の罰の案は Yahoo 転載で読めたが、記者ごとの案（114点・リーグ2から・9季の段階的剥奪）がばらばらなので台本では使わない。
Kieran Maguire「Forest と Everton にゼロを1つ足す（40〜60点）」は Al Jazeera が「米メディアの報道」として孫引きしている2月の発言で、今回の認定のあとの言葉ではないので使わない。

## 10/1 時点で確かめられたこと／確かめられなかったこと

- 上訴: シティは 9/29 の声明で「上訴の道を進む」と表明。**期限は 10月2日（金）**（PL 公式・Sky・BBC）。
  **実際に提出したかは 10/1 15時（日本時間）までの報道で確かめられなかった**（Google News の直近2日の見出しにも「提出」は無い）→ 台本は「上訴すると表明。期限は10月2日」まで
- 上訴の流れ: 新しい3人の委員会（PL 公式・Sky）。今季から入った規則で、上訴の期限から12週以内に審理を終え、その後30日以内に結論 → **1月末ごろ**（Guardian）。
  BBC は「申し立てから12週」と書く。シティが「規則は今季からなので当てはまらない」と争う可能性も Guardian は書いている（台本では「規則では」と言い、1月末は「見込み」）
- 罰: 同じ独立委員会が別の非公開の審理で決める。時期は未定。上訴の結論を待ってから公表、の見方（Guardian・BBC「前例では上訴の結論が先」）。他クラブは「今季中に」（BBC）
- CAS には行けない。高等法院で手続きの公正を争う道はある（Sky・BBC）

## 数字

### スポンサー料（Sky が委員会の報告書から）
| | 額 |
|---|---|
| 帳簿に載せたアブダビのスポンサー料（2009-10〜2017-18） | £949.94m |
| スポンサーが実際に払った額 | £119.25m |
| 残りをオーナー側（ADUG）が出した額 | £830.69m |
- 830.69 ÷ 949.94 = 87.4% →「9割近く」。119.25 ÷ 949.94 = 12.6%
- BBC: 優勝3季（2011-12・2013-14・2017-18）の帳簿のスポンサー料 £360m のうち、本物は £43m（11.9%）
- PL 公式は「収入の水増しと費用の圧縮で £900m 超」。BBC は画像の権利・契約を足して £920m。**台本はスポンサー料の内訳（Sky）だけを言い、£900m は言わない**（同じことを別の数で二度言わない）
- 「2009-10 は、この仕組みでプレミア史上最大の1季の赤字を記録せずに済んだ」（委員会の報告書、Sky・BBC）
- 委員会「クラブの重要な証人の何人かは、重要な点で偽りの証言をし、何人かは承知のうえで不正直な証言をした」（BBC・Sky）

### 前例
| クラブ | 違反 | 罰 |
|---|---|---|
| エヴァートン（2023年11月） | PSR の上限 £105m に対し損失 £124.5m（£19.5m 超過） | 勝ち点10 → 上訴で6（2024年4月に別件で2） |
| ノッティンガム・フォレスト（2024年3月） | 上限 £61m を £34.5m 超過 | 勝ち点4（上訴は退けられた） |
| ユヴェントス（2006年、カルチョーポリ） | 審判の割り当てへの働きかけ | Serie B へ降格、2004-05 の優勝取り消し、2005-06 は最下位扱い |
| シティ | 9季でスポンサー料 £830.69m を偽装（ほかに費用の付け替え） | これから |
- 830.69 ÷ 19.5 = 42.6 →「40倍を超える」（エヴァートンの「超過額」と、シティの「偽装した資金」は違う物差し。台本では「スポンサー料に見せかけた額は、エヴァートンが上限を超えた額の40倍を超える」と、何と何を比べたかを言う）
- Sky「プレミアリーグには財務違反の罰の決まった表が無い」・Guardian「比べられる前例は無い」

### 今季
- 5節まで5戦全勝・勝ち点15で首位、2位アーセナル12（research/standings/2026-09-28.json、BBC も「5試合で満点の15」）
- 1月末はおよそ23〜24節（38節の半分を過ぎる）。台本では「シーズンの半分を過ぎる」

## 発言（原文と訳）

### リチャード・マスターズ（プレミアリーグ最高経営責任者、PL 公式）
> It details how the club systematically broke Premier League Rules for nearly a decade.
→ クラブが10年近く、組織的にリーグの規則を破っていたことが示された
（頭の "The core decision establishes the facts of what happened at Manchester City during this period." は省いた）

### フェラン・ソリアーノ（シティ最高経営責任者、職員向けの動画。Guardian）
> The whole Premier League case against us is based on a single false accusation – that the owner's personal money was somehow and secretly put into the club via some sponsors from Abu Dhabi. This is just not true.
→ リーグの訴えはすべて、たった1つの誤った告発に基づいている。／オーナー個人の金が、アブダビのスポンサーを通して、ひそかにクラブへ入れられたというものだ。／それは真実ではない

### エティハド航空（声明、Guardian・BBC）
> Etihad categorically rejects any finding, conclusion or implication that suggests the airline has ever been involved in improper commercial arrangements.
→ 台本は語りで「認定を断固として否定し、リーグへの法的措置を検討」とだけ言う（報告書の伏せ字版にエティハドの名前は出ていない、と本人が言っているので「エティハドが偽装の相手」とは言わない）

### マウリシオ・ポチェッティーノ（元トッテナム監督・現アメリカ代表監督。The Athletic の取材、Football Today・City Xtra が引用）
> "Whatever punishment [they choose], it's impossible to turn back time," Pochettino said. "It's done a lot of damage. Many clubs followed the rules and some didn't."
> "If it's true that the 114 rules were broken, then we lived through a period of deception"
→ どんな罰を選んでも、時間は巻き戻せない。／多くのクラブはルールを守り、守らなかったクラブもあった。／それが本当なら、私たちは欺瞞の時代を生きてきたことになる
（3つめは "that the 114 rules were broken" を「それが」と受けた。件数は報道で 114／115／「100を超える」と割れるので声に出さない。補ってはいない）
- 背景: トッテナムは 2018〜19年に18か月補強なし（本人）。2016-17 はチェルシーに次ぐ2位

### デヴィッド・バーンスタイン（1998〜2003年のシティ会長。BBC 9/29）
> If this all stands up and the appeal fails, Manchester City cannot stay in the Premier League - they have to suffer a serious penalty that takes them out of the Premier League and I say that as a supporter and fan of 70 years.
→ これがすべて認められ、上訴も退けられたら、シティはプレミアリーグに残れない。／リーグから外れるほどの重い罰を受けるべきだ。／70年応援してきたファンとして、そう言う
（10/1 のグアルディオラの回では、同じ人の別の発言（役員は退くべき）を Guardian から引いた。こちらは BBC の別の発言）

### 他クラブの幹部（Guardian、匿名）
> Relegation to the Championship for one season would be insufficient
→ 語りで「2部へ1季落とすだけでは足りない」

## ネットの反応（個人の投稿だけ。3件）

1. Bluesky @yellowyorkie.bsky.social（2026-09-29 17:39 UTC）
   原文 `Do people really think the premier League is going to meaningfully punish Manchester City. Can't see it myself . Maybe a small points deduction that makes it difficult to get into the champions League or a cosmetically large fine which will be water off the owners back. / I hope I'm wrong.`
   → プレミアリーグが本気でシティを罰すると、みんな本当に思ってる？ 自分には思えない。／チャンピオンズリーグに出にくくなる程度の小さな勝ち点剥奪か、／見た目だけ大きくて、オーナーには痛くもかゆくもない罰金がいいところ。／外れてほしいけど
   https://bsky.app/profile/yellowyorkie.bsky.social/post/3mwoeplbapk2t
2. X @ATM_jpn（2026-10-01 04:25 JST。Yahoo!リアルタイム検索で取得）
   原文「有罪判決を受けたシティが今シーズン処罰されないと更に被害を被るし、無駄なシーズンになる。」（後ろは引用元のURLだけ）
   https://x.com/ATM_jpn/status/2105378432628690978
3. X @haarpymuse（2026-10-01 09:20 JST。Yahoo!リアルタイム検索で取得。@kobasho_01 @BenMabley への返信。宛先は外した）
   原文「裁判が長びく、シティ無罪、シティ有罪  もはやどう転んでも、以前のようにもっと単純でtheエンタメだったPLには戻れないですね 悲しい」
   https://x.com/haarpymuse/status/2105452870099415166

当たって入れなかったもの:
- Bluesky: garywhitta（作家。「トランプ流の法廷戦術」で政治の話が混ざる）、j0hnbev（「夏に判決を知っていた」は裏が取れない報道の受け売り）、doctoad・leanderalphabet・thedaftestlap（エヴァートンとの割り算で、見立ての節と同じことを言う）、listermj（前半が別の話）、luckytran（テッド・ラッソの冗談で前提の説明が要る）、sachinnakrani（記者）、報道・まとめのアカウント全部
- X: 罵り（6SaJhBqHx937100・aisenal10）、エティハドの訴訟の法律論の応酬（OutUlncc0q86128・Skybluecity6 のスレッド）、ニュースの転載（bbcnewsjapan・kieyza・SpursJapan・pleagueradar など）

## 写真
- 記事の写真は使わない:
  - BBC: 本文の写真は Getty（クレジット14か所）
  - Guardian: PA（Martin Rickett）・Reuters・Getty・Alamy。唯一の自社撮影（Tom Jenkins）は 2011〜12年のストーク戦・リーグ杯の古い写真
  - Al Jazeera: Reuters（ファイル名 RC…）・AP
  - Sky: クレジットが無く代理店か確かめられない
- エティハド・スタジアム: Commons「File:City of Manchester Stadium 2023 cropped.jpg」（Arne Müseler, cropped by Blackcat／CC BY-SA 3.0 de、2023年の空撮）。`matchphoto --file` で取得、目で見て透かし無し。16:9 に切った `assets/images/20261002_city_verdict_w/01.jpg`（`widecrop --top 0.06`）
- ポチェッティーノ: Commons「File:Mauricio Pochettino, 2025 CONCACAF Gold Cup.jpg」（u/reepers_hellcat／CC BY 4.0、2025-06-19 サウジアラビア対アメリカ）。被写体の記載が無く `portrait` が弾いたので手で取り、目で本人と確かめた。左に本人・右にスタジアムの2枚並べ `assets/images/20261002_pair_pochettino/01.jpg`
  - `portrait` の自動選択は 2016年の 303x468 の小さい写真だったので使わない
- ソリアーノ: `portrait` が取ってきたのは**同名の彫刻家**（File:Escultor Ferran Soriano al seu estudi.jpg）。捨てた。本人の自由な写真は見つからず、ソリアーノの行はスタジアムのまま
- バーンスタイン: 写真なし（スタジアムのまま）
