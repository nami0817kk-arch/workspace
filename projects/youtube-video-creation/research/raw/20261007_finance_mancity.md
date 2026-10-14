# 材料の控え: マンチェスター・シティの判決、ほかのクラブはどう見ているか（シリーズ「クラブの財政」、2026-10-07 公開予定、取材 10/6〜10/7）

前の回で言ったもの（言い直さない）:
- 10/2 公開 city_verdict（research/raw/20261002_city_verdict.md）: 115件中114件で有罪・10項目の中身・スポンサー料 £949.94m／£119.25m／£830.69m・
  前例（エヴァートン 10→6＋2＝計8、フォレスト4）・40倍・「罰の決まった表は無い」・5戦全勝で首位・「2部に1季では足りない」（匿名の声、1行）
- 10/3 公開 city_appeal（research/raw/20261003_city_appeal.md）: 申し立て（10/1 19時）・声明・7日／84日／5日／30日（10/8・12/24・1/23）・
  ピント・控訴で争った点（エヴァートン／フォレスト／シティ2020）
- 10/1 公開 guardiola_letter: 手紙の中身
**この回の主題は「罰の重さをめぐる声」**：ライバルの見方（1季の降格では足りない）・キャラガー（何年も続くべき、3〜5年）・
罰を決める仕組み（誰が決め、何ができるか、クラブが投票する場面）・前例の減点を自分で数えた表。
前例の点数は 10/2 と同じ事実なので、**読み上げの言い回しを変え、「件数」と「その季どうなったか」の物差しで見る**（10/2 は超過額の物差し）。

取り方: python requests＋BeautifulSoup（本文の段落を抜いた）、プレミアリーグの記事は公式の content API（api.premierleague.com/content/premierleague/text/EN/<id>）で本文を取得、
判断・規則集の PDF は pypdf。ESPN は content.core.api.espn.com で本文を取得。WebSearch は URL を探すだけ（要約は根拠にしない）。
Bluesky は公開 API、X は Yahoo!リアルタイム検索の HTML（__NEXT_DATA__）。ブラウザの道具は使っていない。

## 一次情報（突き合わせた文書）

| 何 | URL | 使ったところ |
|---|---|---|
| PL ハンドブック 2026/27（Section W・B・過去の最終順位表） | https://resources.premierleague.pulselive.com/premierleague/document/2026/07/31/8a890ff9-176c-4364-a8ff-e08f995e2c86/TM2040_PL-Handbook-and-Collateral-2026-27_Digital_31.07.pdf | W.63・W.64（委員会の罰の権限）、W.76（双方が控訴できる）、W.85・W.86（7日・84日・30日）、B.6（除名は総会で4分の3）、歴代の最終順位表の注記（減点は4クラブ） |
| PL 公式 9/29（シティの判断） | https://www.premierleague.com/en/news/4727779/premier-league-statement-manchester-city-fc | 罰は同じ独立委員会が別の非公開の審理で決める |
| PL 公式 10/2（控訴の受付） | https://www.premierleague.com/en/news/4729207/premier-league-statement-manchester-city-fc-appeal-decision-of-independent-commission-02-october-2026 | 控訴の委員会は3人、広い裁量 |
| PL 公式 2023-11-17 エヴァートン 10点 | https://www.premierleague.com/news/3788486 | £124.5m の損失、上限 £105m、10点。違反は認めていた |
| 委員会の判断 エヴァートン（2023-11-17、PDF） | https://resources.premierleague.com/premierleague/document/2023/11/17/49989e4e-01a2-44f9-a012-c3a31ae5536b/2023-11-17-Premier-League-v-Everton-FC-Decision-for-Publication.pdf | 86〜89項：リーグの罰の案（6点から、上限を£5m超えるごとに1点）、委員会は「式は規則の広い権限と合わない」として採らず。139項：10点 |
| PL 公式 2024-02-26 エヴァートン 控訴で6 | https://www.premierleague.com/en/news/3912574 | 9つの理由はすべて罰の重さ、2つ認められ 10→6 |
| PL 公式 2024-04-08 エヴァートン さらに2 | https://www.premierleague.com/en/news/3960088 | 認めた超過 £16.6m、2点 |
| PL 公式 2024-05-10 エヴァートン 控訴取り下げ | https://www.premierleague.com/en/news/4001861 | 表の注記「6点、さらに2点、2件の別々の違反」 |
| PL 公式 2024-05-07 フォレスト 控訴棄却 | https://www.premierleague.com/en/news/3999776 | 4点のまま |
| PL の控訴判断 フォレスト（PDF） | https://resources.premierleague.com/premierleague/document/2024/05/07/47658880-3376-45a8-b2f6-4ceb80a5cf2a/Nottingham-Forest-Premier-League-appeal-final-judgment.pdf | 上限 c.£61m、損失 £95m 超＝c.£34.5m 超過、4点（6点から早い認めと協力で2点引いた） |
| PL 公式 2026-03-16 チェルシー | https://www.premierleague.com/en/news/4616198/premier-league-statement-on-chelsea-sanctions-march-2026 | 2011〜2018年の届け出ない支払い。自ら申告。罰金 計1075万ポンド（PL 史上最高）、勝ち点の減点なし。正しく載せても収支の規則は破っていなかった、とリーグが確認 |
| シティ公式 試合案内（リヴァプール戦） | https://www.mancity.com/news/mens/liverpool-v-city-premier-league-match-preview-october-2026-63926279 | 10月11日（日）16:30（英国）アンフィールド。代表戦の前は5-3でサンダーランドに勝ち |

### ハンドブック 2026/27 の原文
- W.63 "Upon finding a complaint to have been proved the Commission shall invite the Board and the Respondent to place any mitigating and/or aggravating factors before the Commission."
  → リーグ（Board）とクラブが、それぞれ軽くする事情・重くする事情を出す
- W.64 委員会ができること: W.64.1 reprimand／W.64.2 "a fine unlimited in amount"／W.64.4.1 suspend it from playing in League Matches／
  W.64.4.2 "deduct points scored or to be scored in League Matches"／W.64.4.4 "recommend that the League expels the Respondent from membership in accordance with the provisions of Rule B.6"／
  W.64.5 compensation unlimited／W.64.7 "any combination of the foregoing or such other penalty as it shall think fit"
  → 台本：罰金は上限なし・勝ち点の剥奪（これから取る勝ち点も）・試合への出場停止・除名を勧める・組み合わせ。
  **「降格」という罰は規則の一覧に無い**（降格は順位の結果。B.5.1 relegation in accordance with Rule C.14）
- B.6 "the League may expel a Club from membership upon a special Resolution to that effect being passed by a majority of not less than three-quarters of such members as (being entitled to do so) vote ... at a General Meeting"
  → 除名は委員会が勧めるだけで、決めるのは総会。投票したクラブの4分の3以上の賛成が要る
  （20クラブ全部が投票すれば15クラブ。シティ自身に投票の権利があるかは確かめていない → 台本では「4分の3以上」とだけ言う）
- W.76.1.2 クラブは "the decision of a Commission ... including the relief, order, measure or sanction imposed" に控訴できる／W.76.2.1 Board も同じ
  → 罰が決まれば、シティもリーグも罰に控訴できる（Sky 10/6 "both sides allowed to appeal the sanctions" と一致）
- W.85（7日以内に控訴の委員会が進め方）・W.86.1.1（84日）・W.86.2（30日）。Guidance に「勝ち点の剥奪を季の終わりまでに科すため急ぐとき」は変えられる
  → 10/3 で日付は言った。この回は1行（「今季からの決まりでは、控訴の答えは1月23日まで」）
- 歴代の最終順位表の注記（ハンドブックの記録の章）: 1996/97 "*Middlesbrough deducted 3 points"、2009/10 "*Portsmouth deducted 9 points"、
  2023/24 "* Everton deducted six points and then a further two points, following two separate breaches of the Profitability and Sustainability Rules." "* * Nottingham Forest deducted four points following a breach ..."
  → 1992/93〜2024/25 の33季ぶんの表で、注記の付いた減点は4クラブ・5回。2025/26 は英語版Wikipedia の季の記事に減点の記載なし（2026/27 も今のところ無し）
  → **34季で4クラブ**と言えるが、2025/26 はハンドブックの表で確かめていない。台本では「プレミアリーグの歴史で、勝ち点を引かれたのは4クラブ」とする（2025/26 は Wikipedia で確認）
- 2023/24 の最終順位（同じ表）: 15位エヴァートン 40、17位フォレスト 32、18位ルートン 26（降格）
  → エヴァートンは18位と14点差、フォレストは6点差で残った
- 1996/97 の最終順位（同じ表）: 17位コヴェントリー 41、18位サンダーランド 40、19位ミドルスブラ 39*
  → 3点を引かれなければ42でコヴェントリーを上回っていた（英語版Wikipedia 1996–97 FA Premier League "would have been placed 14th without a three-point deduction imposed for unilaterally postponing a 21 December 1996 fixture at Blackburn Rovers"）。理由は「ブラックバーン戦を一方的に延期した」
- 2009/10 ポーツマス: 19点で20位。英語版Wikipedia 2009–10 Portsmouth F.C. season "docked nine points for entering administration ... That only confirmed a relegation that was always inevitable, with Portsmouth being last in the league on actual points as well" → 理由は経営破綻、引かれなくても最下位

### 委員会の判断（エヴァートン 2023-11-17）原文
- 87項 "The guidelines advocated by the Premier League ... adopt a fixed starting point of a deduction of 6 points. There would be an increase from that starting point of one point for every £5 million by which the club had exceeded the PSR threshold of £105 million."
- 89項 "the Commission is concerned that the adoption by it of a structured formula such as is advocated by the Premier League would be inconsistent with the unrestricted powers conferred by Rules W50&51"
- 139項 "This was a serious breach that requires a significant penalty. The Commission considers that it should order an immediate deduction of 10 points."
- **「リーグは12点を求めた」**は Guardian 9/30・Sky 10/6 の記事の言葉。判断の公開版の本文には12という数字は見つからなかった（式に当てはめると6＋19.5÷5≒10、重くする事情で12とみられるが確かめていない）→ **台本では12点と言わない**。言うのは式（6点から、500万ポンドごとに1点）と、委員会が採らなかったことだけ

## 報道（発言・見方）

| 媒体 | URL | 中身 |
|---|---|---|
| Sky Sports（10/6 07:24 UK、Chief Correspondent） | https://www.skysports.com/football/news/13595428/man-city-charges-premier-league-clubs-do-not-expect-city-to-be-in-premier-league-next-season-if-appeal-fails | 下の「ライバルの見方」・キャラガー（Legends of Football Awards で Sky Sports News に） |
| Guardian（9/30 18:55 UTC） | https://www.theguardian.com/football/2026/sep/30/rival-clubs-feel-relegating-manchester-city-championship-not-enough-premier-league | 匿名のクラブ関係者「1季の降格では足りない」「何年も続いた意図的な違反に釣り合い、強い歯止めになる罰」・リーグの立場は理事会（議長・CEO・独立取締役3人）がクラブから独立して決める |
| BBC（9/30） | https://www.bbc.com/sport/football/articles/c6vgyg3zv3kwo | 他クラブの幹部（匿名）「できるだけ早く決まるのが皆のため」「今季中に」。キャプション「シティは調査対象の期間に8つのタイトル」 |
| Sky Sports（10/1 08:08 UK） | https://www.skysports.com/football/news/13593535/man-city-premier-league-charges-jamie-carragher-says-clubs-titles-should-be-stripped-and-owners-removed | 2009/10〜2017/18 にシティはリーグ3・FA杯1・リーグ杯3・コミュニティ・シールド1（＝8）。キャラガー「タイトルは外すべき」「オーナーは退くべき」（この回では使わない。10/1 の言葉で、主題は罰の長さ） |
| The Independent（Yahoo 転載、10/6 09:13 UTC） | https://sports.yahoo.com/articles/jamie-carragher-demands-multi-punishment-091303343.html | キャラガー（The Overlap Fan Debate）「80点や100点でも1季だけ」「3年から5年」。シティは5戦全勝、首位、アーセナルに3点差。今週末アンフィールドでリヴァプール戦 |
| GB News（10/6 09:37 UTC） | https://www.gbnews.com/sport/football/jamie-carragher-man-city-punishment | 同じキャラガーの言葉（Overlap）、控訴が退けられたら、の条件 |
| ESPN（10/6、Olley・Ogden・Lindop、題は "How top Premier League clubs view Man City's guilty verdict"） | https://www.espn.com/soccer/story/_/id/50109791/man-city-premier-league-guilty-verdict-legal-action-arsenal-liverpool-man-united-tottenham | 2024年9月に4クラブ（アーセナル・トッテナム・リヴァプール・マンU）が弁護士を通じ、有罪なら補償を求める権利を残すと伝えていた。「どのクラブも罰が確定するまで待ってから決める見込み」。各クラブの事情（下） |

### ライバルの見方（Sky 10/6、原文）
- "their rivals in England and across Europe believe 'the punishment should fit the crime'."
- "City's rivals are not expecting Enzo Maresca's team to be playing in the Premier League next season."
- "Many believe that a points deduction is not a sufficient punishment if it would lead to City spending just one season outside the top flight."
- "It is only natural for clubs to think of their own self-interest and City's relegation would mean one fewer club going down this season as well as removing one of the favourites from the title race and opening up another European place. Self-interest is not the over-riding consideration though."
- "The consensus appears to be that rules have to be respected by all clubs, no matter their size or status - and it would not be sufficient to hand City a punishment that would last only one season for rules which were broken across multiple seasons."
- "City's rival Premier League clubs will not be involved in the sanction hearing, which could take place while the appeal process runs its course."
- "The same three-person panel which heard the evidence at the 42-day hearing in 2024 and delivered its core decision last Tuesday will decide on sanctions after the Premier League, as the prosecutors, put forward their recommendation and City's lawyers argue their case."
- "It will be down to the Premier League board to decide what recommended sanction their lawyers should present to the panel."
- "With both sides allowed to appeal the sanctions, and City appealing the judgment, Premier League clubs are prepared for this marathon dispute to keep on running until at least next year."
→ 台本：ライバルが見るのは「2部に1季なら翌季に戻れる」こと。自分の得（降格枠が1つ減る・優勝争いの相手が消える・欧州の枠が1つ空く）もあるが、それより「どのクラブも同じ規則を守る」が中心、と書かれている（記者の見立てなので「伝えられています」）

### ライバルクラブの関係者（Guardian 9/30、匿名）
> "Relegation to the Championship for one season would be insufficient," a club source told the Guardian. "The commission has to arrive at a punishment that is proportionate for years of sustained and deliberate cheating, as well as providing a strong deterrent to it happening again."
→ 名前が出ていないので声（voice）にはせず語りで「何年も続いた意図的な違反に釣り合い、二度と起こさせない歯止めになる罰を」とだけ言う。10/2 は「2部に1季落とすだけでは足りない、という声」と言っている → この回は Sky の見方（1季で戻る）に重心を置き、言い回しを変える

### ジェイミー・キャラガー（元リヴァプール主将、Sky Sports の解説者）
1. Sky Sports News（Legends of Football Awards で。Sky 10/6 の記事が引用）
   > "Now that we know that they're guilty, yes, there's an appeal, but now that they've got a big guilty verdict initially, now I don't think anybody wants to wait.
   > "It has to be done this season, because Man City need to be affected for next season.
   > "I know the word at the moment is sham; it'll almost make the Premier League of this season, the title to be won would be a sham, if Man City went on to win that league with what we know has gone on.
   > "So it has to be done this season, and I think the punishment, whatever it should be, I don't think it can be a one-off punishment for one season, because this has gone on for years and years, so I think the punishment should go on for years and years."
   → 使う訳（日本語として自然に）:
     「罰は今季のうちに決めないといけない。来季のシティに効かせるためにね」（"It has to be done this season, because Man City need to be affected for next season."）
     「どんな罰であれ、1季で終わる罰ではいけないと思う。」「何年も何年も続いてきたことなんだから、罰も何年も続くべきだ」（最後の文）
   - "sham" の一文（今季の優勝も見せかけに）は入れない（強い言葉で、題の答えに要らない）
2. The Overlap Fan Debate with Sky Bet（Independent・GB News 10/6 が引用。GB News は「控訴が退けられたら」の条件で書く）
   > "If the people talk about (a penalty of) 80 points or 100 points, but that's just over one season that gets you relegated and then you come back again.
   > "And I think players, a few of them would leave, but I think some of them would say, 'I could put up with that for a year'.
   > "But I think, because this has gone on for so long, I do think the punishment should be over a number of years, three to five years, and then players would move on."
   → 「80点や100点を引くと言っても、それは1季だけの話。降格して、また戻ってくる」「選手の何人かは出ていくだろうが、『1年なら我慢できる』と言う選手もいるはずだ」「これだけ長く続いたのだから、罰は何年かにわたるべきだ。3年から5年。そうすれば選手も出ていく」
   - 「キャラガーは控訴が退けられたら、という条件で話した」は GB News の見出し・地の文。Sky 10/6 の言葉は控訴の話の直後（"yes, there's an appeal"）→ 台本は「控訴が通らなければ」と前置きしてよい（Independent・GB News）

### ESPN（10/6）各クラブの事情（台本には4クラブの名前と「罰を見てから決める」だけ）
- "In September 2024, only four clubs instructed lawyers to inform City that they had reserved their right to seek compensation should they be found guilty: Arsenal, Tottenham, Liverpool and Manchester United."
- "All clubs will likely wait until the sanction is confirmed before deciding if, and how, to pursue a compensation case against City."
- Guardian 9/30 も同じ4クラブ、"the extent of City's punishment could prove critical to their thinking"
- 各クラブの細部（ウェンガー2005の「ドーピング」発言、リヴァプール 97・92点の2位、マンU 2015-16 の4位争い、スパーズの5位）は尺と主題（罰の重さ）のため使わない

## 前例の表（見立て。自分で数えた）

| クラブ（季） | 違反 | 引かれた勝ち点 | その季どうなったか | 根拠 |
|---|---|---|---|---|
| ミドルスブラ（1996-97） | 試合の一方的な延期 1件 | 3 | 19位で降格（引かれなければ残留） | ハンドブックの表・Wikipedia |
| ポーツマス（2009-10） | 経営破綻 | 9 | 最下位で降格（引かれなくても最下位） | ハンドブックの表・Wikipedia |
| エヴァートン（2023-24） | 財務の規則 2件 | 6＋2（最初は10） | 15位で残留（18位と14点差） | PL 3788486・3912574・3960088・4001861、ハンドブックの表 |
| フォレスト（2023-24） | 財務の規則 1件 | 4 | 17位で残留（18位と6点差） | PL 3999776・判断 PDF、ハンドブックの表 |
| チェルシー（2026年3月） | 届け出ない支払い（2011〜18年、自ら申告） | 0（罰金1075万ポンド） | ― | PL 4616198 |
| シティ | 114件（10項目のうち9つ） | これから | ― | PL 4727779・判断 |

- 数えたこと: プレミアリーグで勝ち点を引かれたのは**4クラブ・5回**。いちばん多いのはポーツマスの9（1回で）／季で見るとエヴァートンの8
- 財務の規則での減点は**3回（エヴァートン2・フォレスト1）、合わせて12点**。1件あたり平均4点
- 比べ（台本の1行）: 「財務の規則で引かれた前例は、3件で合わせて12点。シティの認定は114件です」（件数の数え方は違う＝前例は「1つの期間の超過」が1件、シティは告発の数え方。台本で「数え方は違います」を添える）
- 減点で降格が決まったのは**ミドルスブラの1回だけ**（3点）。財務の前例の2クラブはどちらも残留
- **何点引かれるかは言わない**（委員会に広い裁量、リーグの式も退けられている）

## 今季と次の予定
- 5戦全勝・勝ち点15で首位、アーセナルと3点差（Independent 10/6、10/2 で使った順位表と同じ）。この回では順位は1行だけ（10/2 で表を出した）
- 10月11日（日）16:30（英国）＝日本時間12日0時30分、アンフィールドでリヴァプール戦（シティ公式）
- 10月8日まで: 控訴の進め方（W.85。10/3 で言った。この回は言わない）
- 罰を決める審理: 日程未定（PL 9/29「別の非公開の審理」）。控訴と並行で開かれる可能性（Sky 10/6・Guardian 9/30、未確定）

## ネットの反応（個人の投稿。3件、全文）

1. Bluesky @eddiegibbs.co.uk（Eddie Gibbs、2026-10-04 10:00 UTC）。本人の連投（スレッド）の7つ目。1つの投稿として頭から終わりまで
   原文 `I want the competitive advantage gained through years of rule breaking destroyed, and those responsible held accountable.\n\nOne enormous points deduction followed by promotion and business as usual wouldn't cut it.\n\nThe consequences should follow City for years.`
   → 何年もの規則違反で得た優位は、なくしてほしい。責任のある人には責任を取らせてほしい。／とてつもない減点のあとに昇格して、元通り、では済まない。／その結果は、何年もシティについて回るべきだ。
   https://bsky.app/profile/eddiegibbs.co.uk/post/3mx25ej5bll2d
   - 前の投稿（同じスレッド）は「シティのクラブそのものを永遠に壊したいわけではない。サポーターは仕組みを作っていない」。罰の案（勝ち点30・20・10を毎季、移籍の制限ほか）と、責任者の実名を挙げる投稿もある → 実名の投稿は使わない
   - Eddie Gibbs は個人のブログ（eddiegibbs.co.uk）を持つ書き手。報道・まとめ・転載のアカウントではない
2. X @SgTMkL（ねこつな、2026-10-04 20:50 JST。Yahoo!リアルタイム検索で取得）
   原文「今季から初めてプレミアリーグ見るしユニも色々買ってマンチェスターシティ応援しはじめたけど、有罪判決で降格とか処分食らうの結構悲しい。」
   https://x.com/SgTMkL/status/2106713678674628754
3. X @koxya（2026-10-01 10:11 JST。Yahoo!リアルタイム検索で取得）
   原文「エヴァートン事件の勝ち点剥奪も残留争いギリギリの状況になったのに、シティはどうなるんだ」
   https://x.com/koxya/status/2105465694695629160
   - short_voice（短い）

当たって入れなかったもの:
- Bluesky: johnnythefox1（「小さな減点と…で済む、外れてほしい」＝10/2 の反応と同じ中身）、1walid1（高等法院の手続きの話で前提の説明が要る）、amff（「国家が持つクラブに効く罰は無い」、embed の記事の受け）、
  mogo-uk（オーナーが去れば地域の損失。投稿の後ろに記事の見出しが貼られている）、mikedeverell（返信で「that」が何を指すか投稿だけで分からない）、xtrahand1（「Cheats」と呼ぶ）、報道・まとめ・転載（Sky・Mirror・Football365・This Is Anfield・Briefly 系・CTV ほか全部）
- X: USHIILOVINSON21（長い。中身は「降格させたらプレミアが終わる」への反論と子どもの話）、jun_rei_bay（チェルシーの話で途中で終わる）、donddon111（「金に支配されたリーグ」で別の話が混ざる）、
  報道の転載（GoalJP_Official・premier_tsushin・gIpQ4DhQHx21760 ほか）、記事の引き写し（fugasansan・SzrH7KMCOMGqUWn・gern3137）

## 写真
- 記事の写真: Sky（クレジット無し）・Independent（PA）・ESPN（Getty）・Guardian（PA/Getty）→ 使わない
- エティハド・スタジアム（Commons、Little Savage、CC BY-SA 4.0、2015年10月）: 26（正面、MANCHESTER CITY FOOTBALL CLUB の字）→ 01、12（クラブのトロフィーの棚）→ 02、22（スタンドの ETIHAD STADIUM の字）→ 03。
  `matchphoto --file` で取得、目で見て透かし無し。`facecrop --top 0.10/0.12 --center` で _w・_v。10/2（空撮 Arne Müseler）・10/3（Ank Kumar 01・12）とは別の写真
- キャラガー: Commons「File:Football against poverty 2014 - Jamie Carragher.jpg」（Ludovic Péron、CC BY-SA 3.0、2014-03-04 Match Against Poverty、ベルン）。
  `portrait --file` で取得（自動選択は「File:Galaga.jpg」＝ゲーム機の写真で Wikidata の誤りなので捨てた）。目で本人と確かめた。
  縦写真なので `pairphoto` でキャラガー（左）＋エティハド正面（右）の1枚 `pair_carra/01.jpg`（ショート用 `01_v.jpg`）
- グアルディオラは今の監督ではない（2025-26 で退任、今はマレスカ）ので使わない

## 確かめられなかったこと
- 罰を決める審理の日程（未発表）・リーグがどんな罰を求めるか（理事会が決める、未発表）
- 除名の総会でシティ自身が投票できるか（B.6 は「投票する権利のあるクラブ」とだけ）→ 台本は「4分の3以上」まで
- 「リーグはエヴァートンに12点を求めた」（記事のみ。判断の公開版で数字を確かめられなかった）→ 台本で言わない
- キャラガーの Sky Sports News の発言の日付（記事は 10/6、Legends of Football Awards の日付は本文に無い）→ 台本は日付を言わない
