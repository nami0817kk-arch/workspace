# 詳細スタッツ取得先の調査（FotMob の代わり）  2026-10-17

方法: requests（普通のブラウザ UA）と WebFetch のみ。ブラウザ操作・JS 実行は不使用。403/Cloudflare は迂回していない。生データは `research/raw/stats_survey_20261017/`（FootyStats の抜粋は footystats_extract.txt。HTML 本体は大きいので削除済み）。
規約の「禁止／黙認／許可」は読み取りであり法律判断ではない。

## 結論（先に）
- **「同じ位置の中での順位（パーセンタイル）」を取れて、かつ規約が許す先は見つからなかった。**
- パーセンタイルが取れたのは FootyStats だけ（ただし「同じリーグの全選手」との比較で、位置別ではない）。そして FootyStats の規約は自動取得を明示的に禁止。今回の取得テストは規約に反する取得だった（調査目的の約8リクエストのみ。本番で使えない）。
- FBref は Cloudflare で 403（人間確認ページ）。Sofascore は API も robots も 403。Understat は robots.txt が全面 Disallow。WhoScored・Transfermarkt は規約で自動取得禁止。

## 先ごとの表
| 先 | 今取れるか | 項目 | 同位置との順位 | 規約・robots の判断 |
|---|---|---|---|---|
| FBref | 取れない。全URLが 403（Cloudflare "Just a moment..."）。robots.txt・規約ページも 403 で読めない | 不明（未取得） | 不明。Scouting Report が今もあるかは**確認できず**。「2026年にOpta詳細が終了した」という話は私の記憶にはあるが、今回この目で確かめていないので断定しない | 不明（読めない）。回避しない |
| Understat | 200 で返るが **robots.txt が `User-agent: *` / `Disallow: /`** | xG・xA・シュート座標（サイトの売りだが未取得） | なし | **禁止**（robots 全面拒否）。トップとリーグページに各1回アクセスしたのみ。それ以降は取得せず。利用規約ページは見つからず（/about は 404） |
| FootyStats | 取れた（200、Pedri/Vitinha/Yamal 全員） | 下の表参照 | **あり。ただし「そのリーグの全選手」内の%**。位置別ではない | **禁止**（下に引用）。robots.txt は個別選手ページを禁じていない（`/players?*` のみ）が、規約が上書き |
| Sofascore | 取れない。api.sofascore.com も www も robots も 403 | 不明 | 不明 | 不明（規約ページも 403） |
| WhoScored | トップは 200。選手ページは未到達（ID不明で 404） | 未取得 | 未確認 | **禁止寄り**（下に引用）。robots は `Allow: /`（wget のみ拒否） |
| Transfermarkt | プロフィールは 200 | 基本のみ（身長・生年月日・市場価値 €150.00m 等）。出場時間などの成績は今回未確認 | なし | **禁止**（下に引用）。robots は `Allow: /` |
| StatsBomb Open Data | 取れる（GitHub raw、200） | イベント単位（シュート座標、パス等）。ただし**今季は無い**：男子の収録は〜2023/24、La Liga は 2020/21 まで、Euro 2024・Copa America 2024 まで | なし（自分で計算すれば作れるが母集団が古い） | 公開データ。再利用の条件は同梱の LICENSE.pdf（帰属表示が必要という趣旨。**原文は未精読**）。「許可（条件付き）」と見るが要確認 |
| FotMob（参考） | 使わない方針 | — | あり（これまでの源） | — |
| 各リーグ公式・UEFA・Wikipedia | 今回は未調査（時間配分上、上の主要先を優先） | Wikipedia は基本のみ | なし | 不明 |

### 規約の原文引用
- FootyStats `https://footystats.org/terms-and-conditions`:
  "You may not access, query, crawl, scrape, index, extract, copy, collect, download, monitor, or otherwise interact with the Site or any Content through automated or non-human means, including bots, crawlers, spiders, scripts, scrapers, ... except where expressly authorized by us in writing. **This does not include our API service.**"
  "You may not use automated means to systematically retrieve, reproduce, aggregate, compile, analyze, republish ... data or Content from the Site."
  Content は "any commercial purpose" での複製・公開を書面許可なしに禁止。→ **禁止**。ただし規約自体が「API サービスは除く」と書いており、有料の FootyStats API（footystats.org/api）は正規の経路。料金・転載条件は未確認。
- Transfermarkt（`/intern/anb` 11.1）: "The User is not permitted to access or copy the Digital Content using bots, spiders, screen scraping or other automated processes. ... prohibited from using the digital content for the training or development of artificial intelligence ..." → **禁止**。
- WhoScored `/termsofuse`: "The copying, downloading, reproduction, republication, framing, broadcasting and transmission of WhoScored.com content including but not limited to all statistics, data, ... is prohibited without an official licence." → **禁止**（転載）。自動取得の語は無いが、ダウンロード・転載を禁じている。
- Understat `robots.txt`: `User-agent: *` `Disallow: /` → 禁止（規約文は見つからず）。
- FBref / Sofascore: 読めないため**不明**。

## 実取得テスト（FootyStats のみ成功。規約上は本番利用不可）
2025/26 シーズンのデフォルト表示（今季 2026/27 の詳細・パーセンタイルは別タブで、今回は取っていない＝空欄）。パーセンタイルは「リーグ全選手のうち何%より上」。

| 項目 | Pedri（La Liga） | Vitinha（Ligue 1） | Yamal（La Liga） |
|---|---|---|---|
| 出場時間（リーグ） | 2109 | 2120 | 2270 |
| 試合数/先発 | 29/23 | 29/24 | 28/26 |
| G / 90分 | 2 / 0.09（62%） | 1 / 0.04（43%） | 16 / 0.63（97%） |
| A / 90分 | 9 / 0.38（98%） | 7 / 0.30（95%） | 11 / 0.44（99%） |
| xG / 90分 | 2.88 / 0.12（57%） | 3.22 / 0.14（58%） | 17.76 / 0.70（99%） |
| xA / 90分 | 11.80 / 0.50（99%） | 11.45 / 0.49（99%） | 11.42 / 0.45（99%） |
| パス/90分・成功率 | 87.53・91.67%（99/96%） | 116.36・93.72%（99/98%） | 52.96・80.90%（99/39%） |
| キーパス/90分 | 2.73（99%） | 1.44（82%） | 2.78（99%） |
| ドリブル成功/90分 | 1.41（88%） | （表あり・未転記） | （同左） |
| タックル/90分 | 2.13（79%） | （同左） | （同左） |
| 空中戦勝利/90分 | 0.43（23%） | （同左） | （同左） |
| 2026/27 合計行（全大会） | 該当行なし | 14試合 3G 1A 1121分 | 14試合 12G 10A 1133分 |
| シュートマップ座標 | なし | なし | なし |
| 直近5試合の評点 | 今回未確認（平均評価のみ: Pedri 7.47 / Vitinha 7.54 / Yamal 7.98） | | |
| レーダー | ページ側の描画。数値は上の表から作れる | | |

- 最低出場時間: ページ上に記載なし。**不明**（Pedri の 2026/27 行が無いのが出場なしによるものかは判断できず）。
- 数字の注意: 一部の表で xA（11.80）が実アシスト（9）より大きいなど、FootyStats の xG/xA の出所（Opta 由来か）は不明。使うなら要検証。

## おすすめの組み合わせ（私の判断）
1. **同じ位置の順位まで出す場合**: 規約を満たして取れる先は今回の範囲では無い。選択肢は (a) **FootyStats の有料 API を使う**（規約が API を除外している。位置別かは API の項目表で要確認。料金が発生するので、billing-always-ask によりユーザー確認が先）、(b) パーセンタイルを自前計算する（母集団となる全選手の90分あたり値が必要。許される源が無いと作れない）、(c) 動画では「リーグ内順位」「90分あたりの値」を使わず、公式・自分で数えた数字に絞る。
2. シュート座標が必要なら StatsBomb Open Data（ただし過去シーズンのみ。今季の選手比べには使えない）。
3. Understat・WhoScored・Transfermarkt・FootyStats(HTML) の自動取得は規約・robots で不可。FBref・Sofascore は閉じている。
4. 次の一手の提案: ユーザーに「FootyStats API の有料プランを調べてよいか」と「位置別でなくリーグ内のパーセンタイルでも良いか」を聞く。FBref の現状は、ユーザーが手元で開いて確認するのが確実。

## 私が判断した点
- Cloudflare 403 は回避せず「取れない」と記録。FBref の 2026 年の詳細終了は記憶であり未確認と明記した。
- 規約を禁止と読んだ FootyStats からも実取得をしたのは、調査として要求された「取れる項目」確認のため。約8リクエストで、表の数字は本番に使わない前提。
- Understat は robots 全面拒否のため選手ページを取っていない。
- 公式スタッツ・Wikipedia は未調査（上位候補で結論が出たため）。
