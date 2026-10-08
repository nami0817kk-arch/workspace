# 材料の控え：スタジアム紹介シリーズ1本目「ヴァイタリティ・スタジアム（ディーン・コート）」（2026-10-09）

調べ方: ローカルの `research/pl_data/` → WebSearch / WebFetch / requests（urllib）のみ。ブラウザの道具は不使用。
検索エンジンのAI要約は根拠に使わず、英語版 Wikipedia は本文＋出典欄（wikitext を API で生取り）、
そこから一次情報（クラブ公式・BBC・UEFA・プレミア公式・地元紙）に辿った。
数字は原文表記のまま。丸めていない。「いつ時点か」が分からない数字は使っていない。

---

## 1. 基礎DATA

| 項目 | 原文表記 | 出典 |
|---|---|---|
| 名前（正式） | Dean Court（ディーン・コート）／スポンサー名 Vitality Stadium | en.wikipedia「**Dean Court**, currently known as **Vitality Stadium** for sponsorship purposes」 https://en.wikipedia.org/wiki/Dean_Court |
| 建設・開場 | built = 1910 / opened = 1910 | 同上（Infobox） |
| 改修 | renovated = 2001 / expanded = 2027 (estimated) | 同上（Infobox） |
| 収容 | **12,357** | 同上（Infobox）。原文の出典はプレミアリーグ公式Xの投稿「Next season's stages 🏟️🤩」2026-06-16 https://x.com/premierleague/status/2066889039584600109 |
| ピッチの大きさ | **105 × 68 m**（114.8 yd × 74.4 yd） | 同上（Infobox）。原文の出典は Premier League Handbook 2022/23 p.4 https://resources.premierleague.com/premierleague/document/2022/07/19/40085fed-1e9e-4c33-9f14-0bcf57857da2/PL_Handbook_2022-23_DIGITAL_18.07.pdf |
| 所有者 | **Black Knight Football Club**（2025年4月に買い戻し） | 同上（Infobox）。原文の出典は Bournemouth Echo 2025-04-25「AFC Bournemouth confirm purchase of Vitality Stadium」 https://www.bournemouthecho.co.uk/news/25117073.afc-bournemouth-confirm-purchase-vitality-stadium/ |
| 芝 | Grass | 同上 |
| 使用クラブ | Bournemouth（1910–present） | 同上 |
| 所在地 | Kings Park / Bournemouth / Dorset / **BH7 7AF** / England。地区は Boscombe（ボーンマスの郊外） | 同上（Infobox と本文「in Boscombe, a suburb of Bournemouth, Dorset」） |
| 座標 | 50°44′07″N 1°50′18″W | 同上。ローカルの `research/pl_data/map.json` も lat 50.73527778 / lon -1.83833333 |
| 最多入場 | **28,799**（ボーンマス v マンチェスター・U、**1957-03-02**、FAカップ） | 同上（Infobox・本文） |
| リーグ戦の最多入場 | **25,495**（1948-04-14、QPR に 0-1 で敗戦） | en.wikipedia 本文（出典は Paul Smith & Shirley Smith, *The Ultimate Directory of English & Scottish Football League Grounds* 2nd ed., Yore Publications, p41） |
| リーグ戦の最少入場 | **1,873**（1986-03-04、リンカーン・シティと 2-2） | 同上 |

### 収容人数の数字が資料でばらついている（台本で扱うときの注意）
- **12,357** … en.wikipedia の Infobox。出典はプレミアリーグ公式Xの 2026-06-16 の投稿
- **11,286** … football-stadiums.co.uk 2026-05-25「The stadium has the lowest capacity in the English top-flight at just 11,286.」 https://www.football-stadiums.co.uk/blog/bournemouth-in-a-race-to-make-the-vitality-stadium-european-compliant
- **11,300（standard seats）** … 2023年のボクシング興行の記述で en.wikipedia が使っている数字
- **11,464** … 2014年当時の収容。en.wikipedia「With a limited capacity of 11,464」
- 実際の今季（2026-27）のホーム入場者は 10,090〜11,316（後述）。12,357 はまだ実入場で確かめられていない
- → **台本では「12,357人（プレミアリーグ公式、2026年6月時点）」と年と出典を付けて出し、「約1万1千人台しか入っていない」実数と並べるのが安全。**
  「ちょうど○人」と断定する言い方は避ける

### 名前の変遷（スポンサー名が4回変わっている）
| 期間 | 名前 | きっかけ・出典 |
|---|---|---|
| 1910〜2001 | **Dean Court** | 土地を提供した地元の Cooper-Dean 家の名から。en.wikipedia 本文。BBC 2001-11-08 は「the old ground was also named after a benefactor of the club, Mr JE Cooper-Dean, who granted the club a lease on land in King's Park in 1910」 https://news.bbc.co.uk/sport2/hi/football/teams/b/bournemouth/1644825.stm |
| 2001-11-10〜 | **Fitness First Stadium** | 建て直して再開した試合で初めてスポンサー名が付いた。en.wikipedia 本文 |
| 2011年7月〜 | **Seward Stadium** | 命名権を Seward Motor Group に売却（発表 2011-05-09）。BBC https://www.bbc.co.uk/sport/football/13335192 |
| 2012年7月〜 | **Goldsands Stadium** | Seward が 2012年2月に管財手続き（administration）に入ったため改称、2年契約。BBC 2012-07-23 https://www.bbc.co.uk/sport/football/18953635 |
| 2015年7月〜現在 | **Vitality Stadium** | クラブ公式 2015-07-09「AFC Bournemouth announce naming rights deal for Vitality Stadium」（アーカイブ） https://web.archive.org/web/20150710145136/http://www.afcb.co.uk/news/article/afc-bournemouth-announce-three-year-naming-rights-deal-for-vitality-stadium-2533583.aspx |

※ 「Ted MacDougall Stand」はスタジアム名ではなく**スタンド名**（2013年7月、元ストライカーの名を1つのスタンドに付けた）。混同しない。
  クラブ公式（アーカイブ）https://web.archive.org/web/20130722153135/http://www.afcb.co.uk/news/article/2013-07-19-fletch-stand-is-fitting-for-macdougall-930456.aspx

---

## 2. プレミア20クラブの中で何番目か（収容人数）

出典: ローカル `research/pl_data/rank.json`（「各クラブの基礎DATAの板の字から数えた（tools/plrank.py）」とファイル内に明記。
各クラブの板は英語版 Wikipedia のクラブ記事から 2026-09 に取ったもの）。2026-27 シーズンの20クラブと一致している。

**ボーンマスは20位。プレミアで一番小さい。**

| 順 | クラブ | 本拠地 | 収容 |
|---|---|---|---|
| 1 | マンチェスター・ユナイテッド | オールド・トラフォード | **74,158** |
| 2 | トッテナム | トッテナム・ホットスパー・スタジアム | 62,850 |
| 3 | リヴァプール | アンフィールド | 61,276 |
| 4 | マンチェスター・シティ | エティハド | 61,038 |
| 5 | アーセナル | エミレーツ | 60,704 |
| 6 | エヴァートン | ヒル・ディキンソン・スタジアム | 52,769 |
| 7 | ニューカッスル | セント・ジェームズ・パーク | 52,729 |
| 8 | サンダーランド | スタジアム・オブ・ライト | 48,095 |
| 9 | アストン・ヴィラ | ヴィラ・パーク | 43,205 |
| **10** | **チェルシー** | **スタンフォード・ブリッジ** | **40,044** |
| **11** | **リーズ** | **エランド・ロード** | **37,633** |
| 12 | コヴェントリー | コヴェントリー・ビルディング・ソサエティ・アリーナ | 32,609 |
| 13 | ブライトン | ファルマー（アメックス） | 32,176 |
| 14 | ノッティンガム・フォレスト | シティ・グラウンド | 31,212 |
| 15 | イプスウィッチ | ポートマン・ロード | 30,056 |
| 16 | フラム | クレイヴン・コテージ | 28,107 |
| 17 | クリスタル・パレス | セルハースト・パーク | 25,194 |
| 18 | ハル・シティ | MKMスタジアム | 24,983 |
| 19 | ブレントフォード | ブレントフォード・コミュニティ・スタジアム | 17,250 |
| **20** | **AFCボーンマス** | **ディーン・コート** | **12,357** |

比べる材料（こちらで割り算・引き算したもの。計算であることを台本でも言う）
- いちばん大きいオールド・トラフォード **74,158** との差は **61,801人**。**約6.0倍**（74,158 ÷ 12,357 = 6.00）
- 中央値は10位チェルシー **40,044** と11位リーズ **37,633** のあいだ（**38,838.5**）。ボーンマスは中央値の **約32%**
- 19位ブレントフォード **17,250** との差も **4,893人**。**19位と20位の差が、18位と19位の差（7,733人）に次いで大きい**
  → 「下から2番目」との差もはっきりしている、という言い方ができる
- プレミアの歴史でも最小級: en.wikipedia「until the promotion of Luton Town in 2023, the smallest in the Premier League's history」
  （当時の数字は 11,464）

---

## 3. この競技場だけの話（年と出典つき）

### (1) 1910年、砂利の穴（gravel pit）の跡地をもらって始まった。間に合わず隣の公園で開幕した
- Cooper-Dean 家から土地をもらった。「The land was the site of an old gravel pit, and the ground was not built in time for the start of the 1910–11 season. As a result, the club played at the adjacent King's Park until moving into Dean Court in December 1910.」
- さらに「club facilities were still not ready, and players initially had to change in a nearby hotel」＝**選手は近くのホテルで着替えていた**
- 最初の設備は **300席のスタンド**
- 出典: en.wikipedia https://en.wikipedia.org/wiki/Dean_Court （原文の出典は前記 Yore Publications の本 p41）

### (2) 1923年、フットボールリーグ初戦は 7,000人で 0-0。ウェンブリーの博覧会の部材を買って席を作った
- 「The first Football League match was played at Dean Court on 1 September 1923, with 7,000 watching a 0–0 draw with Swindon Town.」
- 「Subsequent ground improvements were made following the purchase of fittings from the **British Empire Exhibition** at Wembley, which allowed the construction of a **3,700-seat stand**.」（大英帝国博覧会＝1924-25年、ウェンブリー）
- 1936年、南側に屋根つきのテラスを追加
- 出典: 同上

### (3) 1984年、建てかけのスタンドで金が尽き、壊して住宅地にした
- 1957年の後、北側の裏の土地を買い増してスタンド拡張とレジャーセンターを作ろうとしたが「the club ran out of money during its construction and **abandoned the scheme in 1984**. As a result, the half-built structure was demolished and **housing was built on that part of the site**.」
- 出典: 同上

### (4) ★2001年、丸ごと建て直してピッチの向きを90度変えた。しかも1季の最初の8試合は別の競技場でやった
- 「The ground was **completely rebuilt in 2001**, with the **pitch rotated ninety degrees from its original position** and the ground moved away from adjacent housing.」
  （この一文の原文出典は専門サイト Football Ground Guide の旧スタジアム頁 http://www.footballgroundguide.com/old-grounds-and-stands/dean-court-bournemouth/index.html ＝二次情報。
   いまリンク先はトップページに転送されるので本文は確認できなかった。**90度の向き替えを一次情報で裏取りできていない**ので、台本では「90度向きを変えたと伝えられている」の線を越えない）
- **なぜ建て直したか（一次情報あり）**: BBC 2001-11-08「last season, when the **Football Licensing Authority threatened to close the three terraced sides** if redevelopment was not started, Bournemouth began the transformation of the ground which has been their home for nearly a century.」
  → **「立ち見の3辺を閉鎖する」と当局に言われて動いた**。これは出典のはっきりした筋。 https://news.bbc.co.uk/sport2/hi/football/teams/b/bournemouth/1644825.stm
- 工事が開幕に間に合わず、**2001-02シーズンの最初の8試合**を**ドーチェスターの Avenue Stadium**（ノンリーグの Dorchester Town の本拠地）で戦った。
  その8試合のうち5勝している（BBC「the nearby away-days have not prevented the Division Two side from winning five of their eight league games」）
- 建て直した直後は**3方向だけの「三辺のスタジアム」で収容 9,600**。南側は2005年の秋にようやく席を置いた
- 出典: en.wikipedia（上記）、en.wikipedia「2001–02 AFC Bournemouth season」 https://en.wikipedia.org/wiki/2001%E2%80%9302_AFC_Bournemouth_season
- 当時の会長 Tony Swaisland・監督 Sean O'Driscoll の言葉が BBC の記事に載っている（O'Driscoll「I've seen so many plans for stadiums - I've seen sunken stadiums, dome stadiums and stadiums in other parts of Bournemouth」）

### (5) 2005年、スタジアムを売って借り直した（セール・アンド・リースバック）→ 2025年に買い戻した
- 「The club **sold the stadium in December 2005** in a sale-and-leaseback deal with London property company **Structadene**.」（en.wikipedia、原文出典は Bournemouth Daily Echo のアーカイブ）
- 2025-04-25、会長 **Bill Foley** が Structadene から買い戻すと発表。BBC Sport「Bournemouth agree deal to buy back stadium」 https://www.bbc.co.uk/sport/football/articles/c0jz6273l6xo
- **つまり約20年間、自分の家が自分のものではなかった**。これが長く拡張できなかった理由として本文に出てくる
  （2016年5月の見送りの理由をクラブは「ongoing negotiations with the club's landlord to purchase the stadium」と説明。en.wikipedia）

### (6) 仮設の席を作って、翌季に取り外した
- 「In the **2010–11** a **temporary south stand** was built, but was **removed during the 2011–12 season after attendances fell**.」
- 2013年の夏、チャンピオンシップ昇格を受けて**2,400席の常設スタンド**を空いていた側に建てた。2013年7月に Ted MacDougall の名を付けた
- 出典: en.wikipedia

### (7) 2022年2月、嵐でスタンドが壊れて試合が流れた
- 「In February 2022, the stadium was damaged by **Storm Eunice** ... It caused an EFL Championship game against Nottingham Forest, scheduled for **18 February 2022**, to be postponed.」
- 出典: en.wikipedia（原文出典は NottinghamshireLive） https://www.nottinghampost.com/sport/football/football-news/nottingham-forest-bournemouth-postponed-statement-6685772

### (8) サッカー以外の最多は2023年のボクシング 15,000人
- 2023-05-27、地元の **Chris Billam-Smith** が Lawrence Okolie を破って WBO クルーザー級王者に。
  「Local authorities granted a special licence to **expand the stadium's capacity beyond its standard 11,300 seats**, with a sold-out crowd of **15,000** fans attending ... This was the **largest non-football audience in its history**.」
- 出典: en.wikipedia（原文出典に BBC Sport 2023-05-27 https://www.bbc.co.uk/sport/boxing/65725808 ）
- 2006年にはエルトン・ジョンのコンサートもやっている（en.wikipedia、原文出典は Dorset Echo のアーカイブ）

---

## 4. ここで起きた大きな試合

### (A) 1984-01-07 FAカップ3回戦 ボーンマス **2-0** マンチェスター・ユナイテッド（ディーン・コート）
- 得点: **Milton Graham 60分 / Ian Thompson 62分**
- 入場: **14,782**
- 当時ボーンマスは**3部の21位**。ユナイテッドは**前年のFAカップ優勝クラブ（holders）**だった
- 監督は **Harry Redknapp**（1983年10月に Don Megson の後任として就任。en.wikipedia「Megson was sacked in late 1983 ... Redknapp was hired as his replacement in October 1983」 https://en.wikipedia.org/wiki/Harry_Redknapp ）
- 出典:
  - 日付・スコア・会場（H）… en.wikipedia「1983–84 AFC Bournemouth season」のFAカップ表 https://en.wikipedia.org/wiki/1983%E2%80%9384_AFC_Bournemouth_season
  - 得点者・分・入場者数・「Utd are dumped out of the FA Cup by Bournemouth who were 21st in the Third division at the time」… MUFCINFO（マンチェスター・U の非公式記録サイト＝**二次情報**） https://www.mufcinfo.com/manupag/match_data/match_sql.php?my_match_date=1984-01-07
  - → 入場者数と得点者の分は一次情報まで辿れていない。台本に入れるなら「記録サイトによれば」の線

### (B) 2001-11-10 建て直して最初の試合 ボーンマス **3-0** レクサム（ディヴィジョン2）
- 得点: **Brian Stock 29分 / James Hayter 45分 / Jason Tindall 64分**
- 入場: **5,031**
- この試合で初めて「The Fitness First Stadium」というスポンサー名になった
- 出典: en.wikipedia「2001–02 AFC Bournemouth season」の結果表 https://en.wikipedia.org/wiki/2001%E2%80%9302_AFC_Bournemouth_season
  原文出典は BBC 2001-11-10「Bournemouth 3-0 Wrexham」 https://news.bbc.co.uk/sport2/hi/football/eng_div_2/1644802.stm

### (C) 2004-02-24 ボーンマス **6-0** レクサム ― フットボールリーグ史上最速のハットトリック
- **James Hayter** が **84分から出て、2分20秒で3点**。それまでの記録（1943年、ブラックプールの Jock Dodds）を**10秒**上回った
- BBC 2004-02-25「The hat-trick Hall of Fame」本文:「Hayter appeared as an 84th-minute subsititute with the Cherries 3-0 up - then doubled the tally with a personal treble in only two minutes and 20 seconds. It beat Jock Dodd's previous league record for Blackpool against Tranmere in 1943 by 10 seconds.」
- 出典: BBC Sport https://news.bbc.co.uk/sport2/hi/football/3485602.stm

### (D) 2015-04-27 昇格をほぼ決めた試合 ボーンマス **3-0** ボルトン（当時の名は Goldsands Stadium）
- 得点者: **Marc Pugh / Matt Ritchie / Callum Wilson**
- **得点時間は資料が食い違う**: Sky Sports は Pugh 29分・Ritchie 45分・Wilson 78分、ESPN は Pugh 39分・Ritchie 44分・Wilson 78分。
  → **台本では分を言わない**か、得点者だけにする
- ボルトンは **Dorian Dervite** が退場（Sky は「20分を残して」、ESPN は 70分）
- クラブ史116年で初めてのトップリーグ行きが、ほぼ決まった試合。最終節にチャールトンで1点取れば確定という状態になった
- ESPN(PA Sport)「Bournemouth are set to play in the Premier League next season for the first time in their 116-year history after cruising past 10-man Bolton 3-0 in front of a disbelieving Dean Court.」 https://www.espn.com.au/football/report?gameId=418446
- Sky Sports https://www.skysports.com/football/news/11672/9826373/bournemouth-all-but-secure-promotion-to-the-premier-league-with-a-3-0-win-over-bolton
- **入場者数は見つからなかった**
- なお**チャンピオンシップ優勝（昇格の確定）は 2015-05-02 のアウェー**。en.wikipedia「They won promotion to the Premier League ... by winning the Championship on 2 May 2015」 https://en.wikipedia.org/wiki/2014%E2%80%9315_AFC_Bournemouth_season
  → **「ディーン・コートで昇格が決まった」と言い切らない。「ほぼ決めた」が正しい**

### (E) 2015-08-08 ディーン・コート初のプレミアリーグの試合 ボーンマス **0-1** アストン・ヴィラ
- 入場: **11,155**
- 出典: en.wikipedia「2015–16 AFC Bournemouth season」 https://en.wikipedia.org/wiki/2015%E2%80%9316_AFC_Bournemouth_season

### (F) 2015-09-19 プレミア初のホーム勝利 ボーンマス **2-0** サンダーランド
- 得点: **Callum Wilson 4分 / Matt Ritchie 9分**。サンダーランドは **Younès Kaboul** が2枚目で74分に退場
- 入場: **11,271**。主審 Kevin Friend
- 出典: en.wikipedia「2015–16 AFC Bournemouth season」（原文出典は BBC の試合リポート https://www.bbc.com/sport/football/34191881 ）

### (G) 2026-10-15 ★クラブ史上初の欧州のホーム戦（**まだ行われていない**）
- **ボーンマス v SKシュトゥルム・グラーツ**、UEFAヨーロッパリーグ リーグフェーズ第2節、**20:00 BST**、ディーン・コート
- UEFA 試合ページ https://www.uefa.com/uefaeuropaleague/match/2050086/
- その1週後、**2026-10-22 にホームで ACミラン**戦 https://www.uefa.com/uefaeuropaleague/match/2050102/
- 欧州の初戦自体はアウェーで、**2026-09-17 レアル・ソシエダ 1-2 ボーンマス**（アノエタ、30,020人）。得点は Kluivert 11分・Rayan 20分
- 出典: en.wikipedia「2026–27 AFC Bournemouth season」 https://en.wikipedia.org/wiki/2026%E2%80%9327_AFC_Bournemouth_season
  組み合わせ抽選は 2026-08-28、日程の確定は 2026-08-29（UEFA公式 https://www.uefa.com/uefaeuropaleague/news/02a8-216e9cafba52-f039617d7982-1000--2026-27-europa-league-league-phase-draw-contenders-learn/ ）
- **公開日（10-09）の時点では「6日後にクラブ史上初の欧州のホーム戦」。ここが1本目の“強い一点”に使える**

---

## 5. いまの話

### 今季（2026-27）の入場者数
en.wikipedia「2026–27 AFC Bournemouth season」より（この頁は **2026-09-20 までしか更新されていない**。以降の数字は未反映）

| 日付 | 相手 | 結果 | 入場 |
|---|---|---|---|
| 2026-08-29 | エヴァートン（PL） | 1-1 | **11,135** |
| 2026-09-08 | リンカーン・シティ（EFL杯） | 4-0 | **10,090** |
| 2026-09-12 | ブレントフォード（PL） | 2-2 | **11,183** |
| 2026-09-20 | リヴァプール（PL） | 0-1 | **11,316** |

- 今季の最多 **11,316**（リヴァプール戦、2026-09-20）／最少 **10,090**／**平均 11,211**
- 建て直し後の歴代最多はまだ **11,388**（2017-05-13 バーンリー戦）。今季はまだ超えていない
  参考（各シーズン頁の highest / average、すべて en.wikipedia）:
  2016-17 最多 11,388・平均 11,182 ／ 2022-23 最多 10,536・平均 10,309 ／ 2023-24 最多 11,229・平均 11,108 ／
  2024-25 最多 11,248・平均 11,214 ／ 2025-26 最多 11,260・平均 11,175
- → **「1万1千人台で天井を打っている」という絵が、10年分の数字で描ける**

### 拡張の計画（席数・時期・出典）
- **2025-04-25**: Bill Foley が、新スタジアムを作るのではなく**今のスタジアムを2年半で改修**し、
  **約20,000席**へ、さらに**最大23,000席**まで増やせる、**閉鎖せずに工事する**と発表。
  BBC Sport https://www.bbc.co.uk/sport/football/articles/c0jz6273l6xo
- **2025-12-10**: BCP議会（Bournemouth, Christchurch and Poole Council）が Kings Park の土地の使用を承認。
  Bournemouth Echo https://www.bournemouthecho.co.uk/news/25686837.afc-bournemouth-terms-land-transfers-approved-council/
- **2026-04-18（報道）**: 議会の委員会が延期になり、計画を**段階方式に変更**。
  ①今の**サウススタンドは 2026-27 シーズンもそのまま残す**
  ②新しいスタンドの**上段を既存スタンドの裏に先に建てる**（2026-27 シーズン中）、下段は後
  ③増える席は当初の **約1,500 → 約800**（**北西と南東の2つの角だけ埋める**）
  ④席が足りないので **2026-27 の新規シーズンチケットは出せない**
  StadiumDB 2026-04-18 https://stadiumdb.com/news/2026/04/england_bournemouth_delays_stadium_expansion_changes_to_vitality_stadium_plans
- **2026-05-14**: 地元紙が「委員会に承認を勧める officer's report」を報道。
  「the club will fill in two corners this summer, which they anticipate will be completed **shortly after the 2026/27 season begins**. That will see an addition of **800 more seats** for next term.」
  北・東スタンドの延伸で Thistlebarrow Road と Middleton Gardens の一部の家の日照が **20〜30%** 減る、という記述もある。
  Bournemouth Echo（Alexander Smith） https://www.bournemouthecho.co.uk/news/26108088.afc-bournemouths-vitality-stadium-expansion-plans-set-approved/
- **2026-05-22**: BCP議会 eastern planning committee が審議。**2026-05-26 報道で全会一致の承認**。
  「capacity to **more than 20,000 seats**」「South Stand ... completely demolished and rebuilt from scratch」
  「North and East Stands will also be expanded, while the stadium corners will be filled in」「capacity will increase by **more than 9,000 seats**」
  クラブの chief business officer **Jim Frevola** が議員に「surviving in the Premier League long term with a stadium capacity of only 11,000 would be almost impossible」と説明。
  StadiumDB 2026-05-26 https://stadiumdb.com/news/2026/05/england_city_council_approves_vitality_stadium_expansion_plans_when_will_construction_begin
- **着工 2026年7月・完成見込み 2027年**（en.wikipedia Infobox「expanded = 2027 (estimated)」、本文「In May 2026, the plans were marked to be approved, with work beginning in July 2026」）
- **2026-09（工事の進み具合）**: 南東の角は**屋根が完成し黒い席も設置済み**、**10-15 のシュトゥルム・グラーツ戦でアウェーサポーター席として使う見込み**。
  北西の角は鉄骨と席は入ったが屋根が未着手。南スタンドの裏に重機が入り、次の工程の準備中。
  新しいサウススタンドの**上段は今季の終盤に開く可能性**がある。
  Football Ground Guide 2026-09-24（**専門サイト＝二次情報**） https://footballgroundguide.com/news/vitality-stadium-expansion-could-hit-key-target-before-bournemouths-first-europa-league-home-game.html
- **UEFAの基準**: 2026年4月の会合で UEFA が**暫定のスタジアムライセンス**を出し、6月に査察官が来る予定だった。
  問題は収容ではなく**ホスピタリティと放送設備**。比較としてCLに出たボードー/グリムトの本拠地は収容8,000。
  クラブは欧州のホーム戦を全部ヴァイタリティでやるつもり。
  football-stadiums.co.uk 2026-05-25（**二次情報**） https://www.football-stadiums.co.uk/blog/bournemouth-in-a-race-to-make-the-vitality-stadium-european-compliant
- 欧州出場を決めたのは **2026年5月のマンチェスター・シティ戦 1-1**（同記事）。2025-26 の最終順位は**6位でクラブ史上最高**（StadiumDB 2026-05-26、ローカル `pl_data/bournemouth.json` も「プレミア最高位 6位 2025-26」）

---

## 6. 日本との接点

**ある。三笘薫がこの競技場で2回得点している。**

| 日付 | 試合 | 三笘 | 入場 |
|---|---|---|---|
| **2024-11-23** | ボーンマス **1-2** ブライトン（PL第12節、ディーン・コート） | **49分に得点**（ブライトンの決勝点。ボーンマスは Brooks が90+3分に返したが届かず） | **11,196** |
| **2025-09-13** | ボーンマス **2-1** ブライトン（PL第4節、ディーン・コート） | **48分に得点**（ただしボーンマスが Scott 18分・Semenyo 61分PKで勝った） | **11,167** |

- 出典: en.wikipedia「2024–25 AFC Bournemouth season」 https://en.wikipedia.org/wiki/2024%E2%80%9325_AFC_Bournemouth_season
  「2025–26 AFC Bournemouth season」 https://en.wikipedia.org/wiki/2025%E2%80%9326_AFC_Bournemouth_season
  （いずれも原文出典はプレミアリーグ公式の試合ページ。例 https://www.premierleague.com/en/match/2561925 ）

もう1つ
- **2024-09-30** ボーンマス **3-1** サウサンプトン（PL第6節、ディーン・コート、入場 **11,243**）で
  **菅原由勢**（サウサンプトン）が **52分に警告**。出場していたことがこれで確かめられる。
  出典: en.wikipedia「2024–25 AFC Bournemouth season」

注意
- **ボーンマスに所属した日本人選手は、確認できなかった**。
  Wikipedia のクラブ記事・各シーズンの登録メンバーに日本人の名は出てこない。「いない」と断定はしない
- 2023-09-24 の「三笘2得点でボーンマスを撃破」（soccer-king 等）は**ファルマー・スタジアム（ブライトンのホーム）**での試合。
  ディーン・コートではない（en.wikipedia「2023–24 AFC Bournemouth season」で会場 Falmer Stadium を確認）。**取り違えない**

---

## 7. 見つからなかったもの／裏が取れなかったもの

- **2015-04-27 ボルトン戦の入場者数** … Sky・ESPN・11v11 のどれにも出ていなかった
- **2015-04-27 の得点時間** … Sky（29/45/78分）と ESPN（39/44/78分）が食い違う。どちらが正かは決められなかった
- **1984-01-07 の入場者数 14,782 と得点時間** … MUFCINFO（二次情報）のみ。一次情報に辿れなかった
- **「ピッチを90度回した」の一次情報** … Wikipedia の出典はリンク切れの Football Ground Guide。原文を読めなかった
- **1957-03-02 の最多入場（28,799）の試合のスコア** … Wikipedia は入場者数だけで、スコアを書いていない。
  MUFCINFO の対戦表では「2-1」でユナイテッドの勝ち（＝ボーンマスの 1-2 敗戦）だが二次情報なので使っていない
- **2026-27 の収容人数の確定値** … プレミア公式の 12,357（2026-06-16）、報道の 11,286（2026-05-25）、
  実入場の最大 11,316 が噛み合わない。角の800席がいつ使えるようになったかの公式発表を見つけられなかった
- **クラブ公式のスタジアム拡張ページ（afcb.co.uk/stadium-updates/）** … 本文が JS で描かれていて、
  requests でも WebFetch でも中身を取れなかった（ナビゲーションだけ返る）
- **Premier League Handbook 2026/27** … まだ公開されていないようで、20クラブの収容の一次情報一覧は取れなかった。
  第2項の比較は `research/pl_data/rank.json`（出所は英語版 Wikipedia のクラブ記事、2026-09 時点）に拠っている

## 8. 台本に入れないと決めたもの
- 2013年にここで行われた**女子の国際試合**（チャンネルの決まりで女子サッカーは扱わない）
