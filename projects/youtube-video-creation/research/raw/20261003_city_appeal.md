# 材料の控え: マンチェスター・シティが有罪の判定に控訴／告発の発端の内部告発者ピントの保護打ち切り（2026-10-03 取材）

前の回（10/2 公開 scripts/20261002_city_verdict.md・research/raw/20261002_city_verdict.md）で扱ったもの：
115件中114件で有罪・10項目の中身・スポンサー料 £949.94m／£119.25m／£830.69m・上訴の期限 10/2・3人の新しい委員会・
「今季からの規則どおりなら結論は1月末まで。今回に当てはまるかは不明」・罰は別の非公開の審理で時期未定・
エヴァートン 10→上訴で6＋別件2＝計8・フォレスト4・5戦全勝で首位。
**この回はそれを言い直さない。**新しく言うのは：申し立ての事実と声明／規則の中身（7日・84日・5日・30日・新しい規則であること）／
控訴で争った点（前例は罰の重さ、シティ2020は違反そのもの）／控訴は証拠の見直しの場（新しい証拠の制限）／
クラブが主張する見込みの「政府の資金」説明は既に退けられている／ピントの保護打ち切り。

取り方: python requests＋BeautifulSoup（本文の段落を抜いた）、PL ハンドブック PDF と委員会の判断 PDF は pypdf、判断の画像だけのページ（21）は画像を抜いて目で読んだ。
WebSearch は URL を探すだけ（要約は根拠にしない）。Bluesky は公開 API。Yahoo!ニュースのコメント欄は HTML を requests で取得。ブラウザの道具は使っていない。

## 一次資料

| 何 | URL | 使ったところ |
|---|---|---|
| PL 公式の声明（10/2）控訴を受け付けた | https://www.premierleague.com/en/news/4729207/premier-league-statement-manchester-city-fc-appeal-decision-of-independent-commission-02-october-2026 | "Manchester City FC has appealed the decision of an independent Commission" / "The club lodged the appeal to the Chair of the Judicial Panel." / "The independent Appeal Board hearing will remain private and confidential until publication of the outcome is permitted." / 注記 "Appeal Boards ... must have three members, one of whom should have held judicial office, and would sit as the chair" / "An Appeal Board has wide discretion ... may allow it, dismiss it, or make any other order that it thinks fit (including varying the order of Commission)" / Judicial Panel の議長は今は Sir Gary Hickinbottom |
| シティの声明（10/2、Sky・ESPN が全文を引用） | Sky https://www.skysports.com/football/news/11661/13593606/man-city-lodge-appeal-premier-league-club-contest-guilty-verdict-of-independent-commission | 下の「発言」 |
| PL ハンドブック 2026/27（Section W） | https://resources.premierleague.pulselive.com/premierleague/document/2026/07/31/8a890ff9-176c-4364-a8ff-e08f995e2c86/TM2040_PL-Handbook-and-Collateral-2026-27_Digital_31.07.pdf | W.76〜W.97（下） |
| PL ハンドブック 2025/26（SEC に出ている写し） | https://www.sec.gov/Archives/edgar/data/1549107/000110465925091251/manu-20250630xex4d24.htm | "Appeal Board Standard Directions" の語が**無い**（PSR の訴えの審理を84日で、という別の決まりはある）→ 控訴の12週は 2026/27 から |
| 委員会の判断（Core Decision）黒塗り版 | https://resources.premierleague.pulselive.com/premierleague/document/2026/09/29/9bb3f063-6312-4d15-a1f1-77280d356a49/Premier-League-Manchester-City-independent-Commission-Redacted-Core-Decision.pdf | 76・77項（21ページ、画像）／103・104項 |
| PL 9/29 の声明 | https://www.premierleague.com/en/news/4727779/premier-league-statement-manchester-city-fc | 調べ始め 2018年12月、告発 2023年2月、42日の審理は 2024年12月に終わった |
| PL 公式 エヴァートン 控訴（2024-02-26） | https://www.premierleague.com/en/news/3912574 | "appealed the sanction ... on nine grounds, each of which related to the sanction rather than the fact of the breach, which the club admitted." "Two of those nine grounds were upheld ... substituted the original points deduction of 10 for six." |
| PL 公式 エヴァートン 10点（2023-11-17） | https://www.premierleague.com/news/3788486 | 10点、違反は認めていた（"the Club admitted it was in breach"） |
| PL 公式 フォレスト 控訴（2024-05-07） | https://www.premierleague.com/en/news/3999776 | "upheld the decision ... to deduct four points ... following an admitted breach" / 2つの理由はどちらも罰の重さ（選手の売却を酌むべき事情に・執行猶予）"Each of these grounds was rejected" / "The four-point deduction will therefore remain in place." |

### ハンドブック 2026/27 の Section W（原文）
- W.76.1.2 クラブは "the decision of a Commission ... including the relief, order, measure or sanction imposed" に控訴できる → **罰が決まれば罰にも控訴できる**
- W.77 "three members of the Appeals Panel of whom one, who shall have held judicial office, shall sit as chair"
- W.85 "**Within seven days of receipt of the appeal** pursuant to Rule W.81, the Appeal Board shall give directions as it thinks fit for the future conduct of the appeal **including whether to vary or disapply the Appeal Board Standard Directions**"
  → 10/1 申し立て＋7日＝**10月8日**。台本は「決まりでは、申し立てから7日以内に進め方を示す」「12週の決まりを使うかどうかも、そこで決められる」
- W.86.1.1 "conclude no later than **12 weeks (84 days)** after the filing of the appeal" → 10/1＋84日＝**12月24日**
- W.86.1.2 "not exceed **five days** in duration and be heard in one block"
- W.86.2 decision "within **30 days** after the final day of the appeal hearing" → 12/24＋30日＝**1月23日**（W.95 も同じ）
- Guidance: Standard Directions を変える・外す例として「勝ち点の剥奪を季の終わりまでに科すために急ぐとき」など
- W.88 新しい証拠は "only be granted if it can be shown that the evidence was not available to the party and could not have been obtained by such party with reasonable diligence, at the time at which the Commission ... heard the complaint"
- W.92 "an appeal shall be by way of a **review of the evidence** adduced before the Commission"
- W.96 控訴の委員会は allow／dismiss／vary any penalty／remit／other order
- W.97 "the decision of an Appeal Board shall be final"（Section X の仲裁を除く）

### 委員会の判断（原文）
- 76項(b)（クラブの主張＝CPC Explanation）"AD Sponsors had from time to time applied for financial assistance from the AD Government ... financial assistance had been provided to the AD Sponsors by the AD Government via the CPC."
- 77項 "We rejected that explanation ... as untrue. We concluded that it was an 'explanation' that the Club had **concocted well after the event** in an attempt to obscure and conceal the realities of the Disguised Funding Scheme."
  → 台本「委員会はそれを、後になってこしらえた説明として退けています」
- 103項 "In November 2018, following a hack of the Club's servers in 2017, Der Spiegel published a series of articles making allegations about ... the true source of recorded Sponsorship Fees"
- 104項 "Those Articles prompted a) An investigation by UEFA ... led to the CAS proceedings ... b) An investigation by the PL"
  → 台本「2018年11月にドイツの雑誌が出した記事」「前の年にクラブのサーバーへの侵入があった」「2020年の件も、きっかけは同じ記事」。**判断の文書にピントの名前は無い**（ピントとの結びつきは報道）

## 報道

| 媒体 | URL | 中身 |
|---|---|---|
| Sky Sports（10/2） | https://www.skysports.com/football/news/11661/13593606/man-city-lodge-appeal-premier-league-club-contest-guilty-verdict-of-independent-commission | 声明全文・「12週で…クリスマスの前の週」「5日間」「30日で…1月の第3週」「シティは、古い事件には当てはまらないと争える」（Sky の記者の言葉。話者は本文で特定できない）・Lyall Thomas「資金はオーナーでなくアブダビ政府から出たと主張する見込み」・Solhekol/Mehta「告発は2023年、審理は2024年で、そのとき規則には無かった」「法律の専門家は、シティには強い言い分がある」 |
| ESPN（10/2、Rob Dawson） | https://www.espn.com/soccer/story/_/id/50083711/ | 10/1 19時に申し立て・声明の引用・「控訴では資金がアブダビ政府から出たと主張する可能性（ESPN の情報源）」 |
| Guardian（AOL 転載、10/2） | https://www.aol.co.uk/articles/manchester-city-whistleblower-rui-pinto-194359000.html | ピントの X の声明・弁護団の声明（下） |
| Independent（Yahoo 転載） | https://sports.yahoo.com/articles/rui-pinto-whistleblower-abandoned-portuguese-153346816.html | 保護は **10月10日（土）** で終わる・2023年9月に4年の執行猶予つき判決・2018年に Der Spiegel の記事のもとの資料 |
| Yahoo Sports（Guardian を引用） | https://sports.yahoo.com/articles/man-city-whistleblower-rui-pinto-042341408.html | 2020年に保護の対象に（警察に数百万の資料への接触を許した）・**4月のリスボンの暴行で眉にあざ、ただ地元の警察は今の危険を「低い」と見た**・2023年9月 不正なデータアクセス・恐喝未遂・通信の秘密の侵害で4年の執行猶予つき |
| RTÉ（2023-09-11） | https://www.rte.ie/sport/soccer/2023/0911/1404704-football-leaks-founder-pinto-avoids-jail-in-portugal/ | **有罪判決の裏**："A Lisbon court on Monday handed a four-year suspended prison sentence to Rui Pinto ... for attempted extortion, illegal access to data and breach of correspondence." 裁判官「内容を知る前に罪を犯して情報を得たので、内部告発者の保護は受けられない」 |
| 東スポWEB（10/3） | https://www.tokyo-sports.co.jp/articles/-/405330 | BBC を引いて：2018年に Der Spiegel に提供、2020年に証人保護、2日に SNS で10日の打ち切りを明かす |
| Euronews（10/1） | https://www.euronews.com/2026/10/01/manchester-city-not-above-the-rules-says-downing-street | 首相官邸「シティはルールの上にはいない」 |
| Bloomberg（10/2、見出しのみ） | https://www.bloomberg.com/news/articles/2026-10-02/man-city-verdict-puts-uk-uae-diplomatic-relations-under-strain | UAE と英国の関係に負担（本文は読めていない。話した人の名前は無い、と題材メモ） |
| Al Jazeera（2020-07-13） | https://www.aljazeera.com/sports/2020/7/13/manchester-citys-two-year-european-football-ban-lifted | CAS がシティの控訴を認め2年の欧州出場停止を取り消し、罰金は1000万ユーロ（UEFA は2月に3000万ユーロ）。調べのきっかけは2018年11月の Der Spiegel |
| Sky Sports（2020-07-28） | https://www.skysports.com/football/news/11679/12038109/manchester-city-court-of-arbitration-for-sport-releases-reasons-for-lifting-clubs-european-ban | "Payments from Etisalat were time-barred ... Etihad Airways' payments were partially time-barred ... the CAS panel was not satisfied that UEFA had properly established their case." "CAS overturned the ban and reduced their initial €30m fine to €10m" |

- CAS の公式の発表（CAS_Media_Release_6785）は tas-cas.org が JavaScript のページで本文を取れなかった。数字（3000万→1000万ユーロ・2季の出場停止の取り消し）は Al Jazeera・Sky が一致

## 発言（原文と訳）

### マンチェスター・シティの声明（10/2）
> Manchester City Football Club can confirm that at 7pm on Thursday 1st October 2026 the club lodged its comprehensive appeal against the opinion of the Premier League Commission, in relation to the Premier League disciplinary matter.
> The club's firm position is that, on multiple grounds, the opinion contains clear material errors, of law, principle and fact and is unsafe.
> The club is innocent of the accusations made by the Premier League and a comprehensive body of irrefutable evidence exists in support of all of its positions, relating to this case.
→ 判断には、いくつもの点で、法と原則と事実の、明らかで重大な誤りがある。／クラブは無実で、すべての主張を支える、覆しようのない証拠がそろっている
（"irrefutable" は「反論の余地のない」とも訳せるが、反応の投稿（sar*****）と同じ言い回しになるので声明は「覆しようのない」にした）
- 声明の "Premier League Commission" は誤り（独立委員会）と Sky が注記。台本では「委員会」とだけ言う
- 7pm は英国時間（BST）。日本時間では10月2日の午前3時 → 台本は「イングランドの時間で10月1日の夜7時」

### ピント（10/2、X。Guardian の引用）
> On 30 September 2026, just hours after the verdict officially confirming Manchester City's guilt, the commission responsible for Portugal's witness protection programme informed me of its decision to terminate my participation in the programme and withdraw my police protection
> I have no alternative but to relocate, within the next few days, to an undisclosed location for an indefinite period of time
- GoFundMe（目標300万ユーロ）は台本に入れない
- 判定（9/29 の発表）の翌日 9/30 に伝えられた →「有罪の判定の翌日」

### ピントの弁護団（10/2、Guardian・Independent）
> His situation is now critical ... last April, he was assaulted in Lisbon. ... Abruptly deprived of his protected residence and placed in a situation of extreme precariousness, Rui Pinto will now be more vulnerable than at any point since 2020.
→ 保護された住まいを突然奪われ、／ピントは、2020年以来、いちばん危うい立場に置かれる
- 「国家によるテロ行為」という言い方は台本に入れない（強い言葉で、題の答えに要らない）

## 日付の表（台本の表）

| 日付 | 何 | 根拠 |
|---|---|---|
| 10月1日 | 控訴の申し立て（英国時間19時） | シティの声明・PL 声明 |
| 10月8日まで | 控訴の委員会が進め方を示す（12週の決まりを使うかも） | W.85（7日）。委員会の顔ぶれの発表は確かめられていない |
| 10月10日 | ピントの保護が終わる | Independent・東スポ（BBC） |
| 12月24日まで | 控訴の審理を終える | W.86.1.1（84日） |
| 1月23日まで | 控訴の判断 | W.86.2・W.95（審理の最終日から30日） |
| 未定 | 罰を決める審理 | PL 9/29 の声明・前の回の控え |

- 「12週の決まりが今回に当てはまるか」は**誰も確定していない**（Sky の専門家はシティに強い言い分と）。台本は「この決まりどおりなら」「争う可能性も伝えられている」

## 前例の表（見立て）

| 例 | 争った点 | 結果 | 根拠 |
|---|---|---|---|
| エヴァートン（2024年） | 罰の重さ（違反は認めていた） | 勝ち点10→6 | PL 3912574 |
| フォレスト（2024年） | 罰の重さ（違反は認めていた） | 勝ち点4のまま | PL 3999776 |
| シティ対ウエファ（2020年） | 違反そのもの | 2季の欧州出場停止を取り消し、罰金3000万→1000万ユーロ | Al Jazeera・Sky 2020（CAS） |
| シティ（今回） | 違反そのもの（判断の誤り） | これから | シティ声明 |

- 前の回は「上訴で6に減りました」（エヴァートン）を言っている。この回は「何を争ったか」の比べとして1行だけ触れ、言い回しを変えた
- 2020年の件は UEFA の規則・CAS（スポーツ仲裁裁判所）で、今回の控訴の委員会とは別の場。台本は「場は違いますが」とは言わず、事実（どこが取り消したか）だけを言う

## ネットの反応（個人の投稿。3件、全文）

1. Bluesky @jasethevillain.bsky.social（Jason、2026-10-02 18:44 UTC）
   原文 `And then we have to wait for the Premier League to come up with a punishment. Then we have to wait for Man City to appeal that. Then, finally, we might see something actually happen.\n\nThe only ones I feel sorry for are the fans. The proper ones who were there before the success. But still. #MCFC`
   （「12週・12月24日・30日」を伝える投稿 plnews.bsky.social への引用。ハッシュタグだけ外した）
   → このあと、プレミアリーグが罰を決めるのを待たなきゃいけない。／次は、シティがそれに控訴するのを待つ。／そこでやっと、何かが本当に動くかもしれない。／気の毒なのはファンだけ。／成功する前からいた、本物のファンたち。／それでもね。
   https://bsky.app/profile/jasethevillain.bsky.social/post/3mwvzqmuyns2f
2. Yahoo!ニュース（サッカーキング 10/2「マンチェスター・シティ、財務規定違反認定に対し正式に控訴…」）のコメント欄 2ページ目 sar*****。全文
   「反論の余地のない証拠があるならもうとっくに提出してるだろうしこういう状況になっていないと思うけどね。」
   https://news.yahoo.co.jp/articles/3195ebc122f9cf1d9010740bcfc0c74966683683/comments
3. Yahoo!ニュース（東スポWEB 10/3「マンチェスターＣ　財務規定違反の〝告発者〟が「暗殺の危機」…」）のコメント欄 1ページ目 ex1********。全文
   「覚悟の上での告発だっただろう。安全に過ごせるよう祈っております。」
   https://news.yahoo.co.jp/articles/cbcc73f374f9f71c23d02235f00bc4218b3b5ccc/comments

当たって入れなかったもの:
- Yahoo（控訴の記事）: jun********（「政府に圧力をかけてうやむやに」と動機を決めつける）、lwt********（「気持ち悪い」の罵り、裏の取れない「リアムが上層部から聞いた処分」）、par********（国の圧力の決めつけ）、yuk********（「35件も調査協力しなかった」は数が判断と合わない）、m******（処分の空想）
- Yahoo（ピントの記事）: 暗殺を誰かに結びつける投稿（hi_********・yui******* ほか）は名誉にかかわるので入れない。Red Dragon は「商人保護」の打ち間違いがあり、全文で載せると誤読を招く
- Bluesky: 罵り（marcdjcooper）、冗談（utdheisenberg）、報道・まとめ・転載（Briefly 系・ESPN FC・City Xtra・Mirror など全部）

## 写真
- 記事の写真: Sky はクレジット無し、ESPN・Guardian・Independent は Getty／PA／AFP（Independent の本文にも "AFP/Getty"）→ 使わない
- エティハド・スタジアム正面: Commons「File:Etihad Stadium, Manchester City Football Club (Ank Kumar, Infosys) 01.jpg」（Ank kumar／CC BY-SA 4.0、2013年）。`matchphoto --file` で取得、目で見て透かし無し。`facecrop --top 0.08 --center 0.46` で 01_w・01_v
- スタジアムの中: 同じ作者の「… 12.jpg」（CC BY-SA 4.0）。02_w・02_v
- 前の回（20261002_city_verdict）の空撮とは別の写真
- ピント本人: Commons に自由に使える写真は見つからない（検索で出たのは弁護士の動画1本だけ）→ 使わない

## 確かめられなかったこと
- 控訴の委員会の顔ぶれ（発表なし）。10月8日に本当に進め方が示されるか（W.85 の期限の計算のみ）
- 12週の決まりが今回に当てはまるか（新しい決まりであることは 2025/26 と 2026/27 の規則集の比べで確かめた）
- 罰を決める審理の日程（未定のまま）
- ピントが実際にポルトガルを出たか（10/2 に「数日のうちに移る」と表明まで）
- UAE 側の「関係に大きな負担」の発言者（Bloomberg の本文は読めていない）→ 台本に入れない。首相官邸の言葉（Euronews）も題の答えに要らないので入れない
