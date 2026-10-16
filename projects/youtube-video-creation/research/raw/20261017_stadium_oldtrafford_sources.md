# オールド・トラッフォード回（2026-10-17）の取材控え

取得日 2026-10-17。ブラウザ操作の道具は使わず、requests（ブラウザの User-Agent）だけで本文を読んだ。manutd.com の記事ページは 404（JS 描画）で読めなかった。

## 1. 収容（PL公式ハンドブック 2026/27）
- URL: https://resources.premierleague.pulselive.com/premierleague/document/2026/07/31/8a890ff9-176c-4364-a8ff-e08f995e2c86/TM2040_PL-Handbook-and-Collateral-2026-27_Digital_31.07.pdf
- 各クラブの「Club Directory」ページの「Ground Capacity at start of the Season」を20クラブ全部抽出（pypdf）。ユナイテッドのページ（PDF p.21）は 74,158、ピッチ「Length: 105 metres Width: 68 metres」。
- 大きい順：ユナイテッド 74,158／トッテナム 62,850／リヴァプール 61,276／マンチェスター・シティ 61,038／アーセナル 60,704／エヴァートン 52,769／ニューカッスル 52,729／サンダーランド 48,095／チェルシー 40,044／リーズ 37,633／アストン・ヴィラ 36,887／コヴェントリー 32,609／ブライトン 32,176／フォレスト 31,212／イプスウィッチ 30,294／フラム 28,107／パレス 25,194／ハル 24,983／ブレントフォード 17,250／ボーンマス 12,357。合計 822,365（20クラブ平均 41,118.25）。
- チェルシー回（10/16）の抽出（合計 822,365）と一致。

## 2. 昨季のホーム入場（PL公式の試合データ API、2025年シーズン全38節）
- https://sdp-prem-prod.premier-league-prod.pulselive.com/api/v1/competitions/8/seasons/2025/matchweeks/{1..38}/matches
- ユナイテッドのホーム19試合：合計 1,405,516、平均 73,974.53、最多 74,257（2025-08-30 バーンリー）、最少 73,475（2025-08-17 アーセナル）。
- 2026年シーズン：第7節 10/18 リーズ（アウェー）、第8節 10/25 ボーンマス（ホーム、14:00）、第9節 10/31 チェルシー（アウェー）。今季の3ホーム戦の入場は 74,148／74,161／74,129（収容 74,158 を超える日がある＝開幕時の収容と実際の数え方が違う。台本では使わない）。

## 3. クラブ公式（ir.manutd.com の歴史ページ。投資家向け）
- https://ir.manutd.com/company-information/history.aspx
- 開場 1910年2月19日、収容約8万。1941年3月11日のドイツ空襲で大きな被害、戦後再建して 1949年8月24日に再開。照明は1957年、屋根の工事は1959年に完了。
- 収容の推移：1985年 56,385、全席イス席化で1992年までに約44,000（クラブ史上最少）、1996年 約58,000、2000年 約68,000、2006年 約76,000。「現在の収容 75,454」は 2016/17 のまま古いので使わない。
- 設計 Archibald Leitch（1909）。愛称 Theatre of Dreams。

## 4. FIFA の記事
- https://inside.fifa.com/en/news/old-trafford-history-and-innovation-combine-2156320
- 1940-12-22 と 1941-03-11 の2度の空襲、メインスタンド（南）が壊れた、メイン・ロードを借りた、借金 15,000 ポンド、リーグ戦が開かれない期間はほぼ10年（1949年に再開）、バンク・ストリートの工場の煙。

## 5. Wikipedia（Old Trafford／Maine Road／History of Manchester United 1945–1969／Manchester United F.C.／New Trafford Stadium）
- 開場の経緯（デイヴィス会長・リーチ・100,000 → 約80,000・南スタンドだけ屋根・リヴァプール戦 3-4）、1936年の北スタンドの屋根、1939年3月25日の 76,962（ウルヴス対グリムズビー、FAカップ準決勝）、2007-03-31 の 76,098（7万6212席のうち空き114）、2005-06 の拡張（+約8000）、2009年の 75,957。
- **建設費は記事どうしで食い違う**：Old Trafford 記事「土地を入れて総額6万ポンド、10万人にするにはあと3万ポンド」、Manchester United 記事「土地代が約6万ポンド、建設の予算が3万ポンド」→ 台本は金額を言わない。
- メイン・ロードを借りた年：Old Trafford 記事「1941〜1949」、History 記事「1945〜1949」→ 台本は年を言わない。借り賃（年5000ポンド＋入場料の一部）は Maine Road・Old Trafford 記事のみ → 台本では言わない。
- New Trafford Stadium 記事：2025年3月に約100,000席の案を発表、フォスター・アンド・パートナーズ設計、新スタジアムは現在地の北西約350メートル、2030-31 の入居をめざす（台本では言わない）。

## 6. 記録の裏取り
- 83,260（1948-01-17 ユナイテッド対アーセナル 1-1、メイン・ロード）：Guinness World Records の記録ページ本文（Largest attendance at an English football top division match）で確認。Wikipedia の 1947-48 シーズン記事には 81,962 とあり食い違うが、Guinness・Maine Road 記事・mufcinfo は 83,260。https://www.guinnessworldrecords.com/world-records/85339-largest-attendance-at-an-english-football-soccer-top-division-match
- 76,962：11v11 の試合記録（Attendance 76,962）、Wolves Complete History（「76,962 is a record for any match held at Old Trafford」）、Wikipedia が一致。
- mufcinfo の記事（https://www.mufcinfo.com/manupag/articles/article_pages/old-trafford-attendance-records-decade-by-decade.html）は 1939年の記録・1948年・2007年の 76,098（全席イス席での最多）を同じ数字で書く（二次）。

## 7. 新スタジアム計画（報道）
- Architects' Journal（2026-06-22）：https://www.architectsjournal.co.uk/news/man-utd-bags-site-for-new-100000-capacity-foster-partners-stadium — 約10ヘクタールの土地を約350メートル先に取得（売り手 Indurent、Blackstone 傘下）、収容 100,000・フォスター・アンド・パートナーズ、2024年に幹部が新築（約20億ポンド）を推奨、改修は10〜12億ポンドで工事中は収容が減る、「旧スタジアムをどうするかははっきりしない」。
- StadiumDB（2026-09）：https://stadiumdb.com/news/2026/09/england_manchester_united_officially_appoints_architect_for_new_stadium — 設計者を正式にフォスター・アンド・パートナーズとし、新スタジアムは収容約100,000・約20億ポンド。
- ファンのブログ（Stretty News 2026-07-09）は「総席104,000・2030-31入居・旧スタジアムは取り壊さず女子とアカデミーに」と書くが、一次の裏付けが無く AJ と食い違うので**使わない**。

## 8. 使わなかった写真
- Commons の「Old trafford stadium 1920s.jpg」（PD、919x567）：引き伸ばしが2.09倍で使えない。
- 手元の stadium_マンチェスターユナイテッド_in.png（Tom Morrison 原版 1024x768 を 1920 へ拡大）：引き伸ばし1.9倍で使えない。
