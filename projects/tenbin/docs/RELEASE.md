# もじつみ — TestFlight と App Store への出し方

2026-10-05 作成。ひかりの指名（`projects/hikari7/docs/RELEASE.md`）を写した。サカマネ・護送ボート・ひかりの指名と同じ Apple のチームで出す。
作りもひかりの指名と同じで、ゲーム本体（`prototype/index.html`）をアプリの中の WebView で動かす。

## 使い回せるもの（登録済み・作り直さない）

| もの | GitHub Secrets | 備考 |
|---|---|---|
| 配信用証明書（Apple Distribution） | `IOS_DIST_CERT_BASE64` / `IOS_DIST_CERT_PASSWORD` | チームで1つ。アプリごとに作らない |
| チームID | `IOS_TEAM_ID` | |
| App Store Connect API キー | `APPSTORE_API_KEY_ID` / `APPSTORE_API_ISSUER_ID` / `APPSTORE_API_KEY_BASE64` | TestFlight へのアップロードに使う |
| 有料App契約・銀行口座 | — | サカマネで有効化済み。課金アイテムをすぐ作れる |
| Cloudflare | `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` | 公開ページ（`tenbin-site.yml`）に使う |

## 新しく要るもの（もじつみだけ）

| もの | GitHub Secrets |
|---|---|
| プロビジョニングプロファイル（`com.namiki.mojitsumi` 用） | `MOJITSUMI_IOS_PROVISIONING_PROFILE_BASE64` |
| AdMob のアプリID（`~` 区切り） | `MOJITSUMI_ADMOB_APP_ID_IOS` |
| AdMob の広告ユニットID（動画・全画面、`/` 区切り） | `MOJITSUMI_ADMOB_REWARDED_IOS` / `MOJITSUMI_ADMOB_INTERSTITIAL_IOS` |

## 手順

### 0. 公開ページを出す

master に `legal/` `site/` が入ると `tenbin-site.yml` が Cloudflare Pages の `mojitsumi` に出す（https://mojitsumi.pages.dev/ ）。
アプリのリンク（クレジットの画面）と App Store の URL 欄はここを指す。リリースの CI は、ここが開けないと止まる。

### 1. App ID を登録する（Apple Developer）

1. https://developer.apple.com/account/resources/identifiers/list
2. **＋** → **App IDs** → **App**
3. Description に `Mojitsumi`、Bundle ID は Explicit で **`com.namiki.mojitsumi`**
4. Capabilities は何も足さない（課金は既定で使える）

### 2. プロビジョニングプロファイルを作る

1. https://developer.apple.com/account/resources/profiles/list
2. **＋** → Distribution の **App Store Connect**
3. App ID に `com.namiki.mojitsumi`、証明書はサカマネと同じ Apple Distribution
4. 名前は `Mojitsumi AppStore` など。ダウンロードした `.mobileprovision` を Base64 にして `MOJITSUMI_IOS_PROVISIONING_PROFILE_BASE64` に入れる
   （PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("Mojitsumi_AppStore.mobileprovision"))`）

### 3. App Store Connect にアプリを作る

API では作れないので、画面で作る。

1. https://appstoreconnect.apple.com/apps → **＋** → **新規App**
2. プラットフォーム **iOS**、名前 **もじつみ：ひらがな積み上げ ことばパズル**（`STORE_LISTING.md`）、主言語 **日本語**
3. バンドルID **com.namiki.mojitsumi**、SKU は `mojitsumi`、ユーザアクセスは「フルアクセス」
4. **iPhone だけ**（iPad には出さない。`TARGETED_DEVICE_FAMILY = 1`）。掲載画像は 6.9インチの5枚（`marketing/screenshots/`、`node tool/screenshots.js` で撮り直せる）

### 4. 課金アイテム「広告を消す」を作る

1. 作ったアプリ → **App内課金** → **＋** → **非消耗型**
2. 参照名 `Remove Ads`、製品ID **`mojitsumi_remove_ads`**（アプリ側に固定で書いてある）
3. 価格は**ユーザーが決める**（仮に 370円 = 護送ボートと同じ）。表示名「広告を消す」／英語「Remove Ads」、説明「全画面広告が出なくなり、つづける・アイテムも動画なしで使えます」
4. 審査用のスクリーンショット（「広告を消す（¥370）」のボタンが写ったはじめの画面）が無いと提出できない。TestFlight で撮れるようになってから入れる
5. **最初の課金アイテムは、アプリのバージョンと一緒に審査に出す。** 課金アイテムのページ右上の **審査用に追加** → 提出の下書き → iOS と版 1.0。アプリの方もバージョンのページの **審査用に追加** で同じ下書きに入れ、両方が並んだのを見てから **審査へ提出**（入れ忘れると審査の端末で値段が取れずボタンが出ない＝「課金が見つからない」で却下）

### 5. AdMob にアプリと広告ユニットを作る

1. https://apps.admob.com → アプリ → **アプリを追加** → iOS →「まだストアに公開されていない」→ 名前 `もじつみ`
2. 広告ユニットを2つ: **リワード**（つづける・アイテムをもらう）と **インタースティシャル**（結果から次を始めるとき、3回に1回）
3. アプリID（`ca-app-pub-…~…`）と、2つの広告ユニットID（`ca-app-pub-…/…`）を控えて Secrets に入れる
4. app-ads.txt は `site/app-ads.txt`（ほかのアプリと同じ pub-ID）。App Store の「マーケティング URL」かサポート URL のドメインで読まれる

### 6. ビルドして TestFlight へ上げる

**実地の記録（2026-10-17）**
- **手順3（App Store Connect にアプリを作る）を先に済ませる。** 無いと `Upload to TestFlight` が `Cannot determine the Apple ID from Bundle ID` で落ちる（署名・ビルドまでは通る）。
- プロファイルの Base64 は **Git Bash の `base64 -w0 … | gh secret set`** で入れる。PowerShell のパイプだと末尾に CRLF が付き、CI の `Install provisioning profile` が `error decoding base64 input stream` で落ちた。
- アプリ作成画面のプルダウンは、フォーム入力ツールでは値が反映されない。クリックで開いて `End` → `Return` で選ぶ。
- アップロード成功: `1.0.0+1`（テスト広告ビルド。審査には出さない）。App Store Connect の Apple ID は 6823961034。
- TestFlight の内部テストのグループ「自分」を作成し、Account Holder を追加済み（自動配信オン）。
- 課金アイテム `mojitsumi_remove_ads`（Apple ID 6823968728）: 非消耗型・¥370（日本基準、他国は自動換算）・日英の表示名と説明を登録済み。配信国は既定の全国のまま（アプリ側の配信国を絞るなら揃える）。審査用スクリーンショットは未登録。
- 価格の欄は ¥370 が一覧に出ないので、検索欄に 370 と入れて「他の価格を確認」を押す。
- AdMob: ブラウザの Google アカウントが `nami.0817.tt`（authuser=2）でないと新規登録画面になる。アプリ「もじつみ」とリワード・インタースティシャルを作成し、3つの ID を Secrets に登録済み。
- 本番ビルド `1.0.0+2`（test_ads なし）のアップロード成功。審査にはこちらを使う。
- 掲載（2026-10-17 入力済み）: サブタイトル・説明文（■を避け【】で）・キーワード・URL・著作権・審査メモ・自動リリース。カテゴリ=ゲーム（サブ: 単語・パズル）、コンテンツ配信権=はい（サードパーティ含む・権利あり）、価格=無料。
- 配信国（ユーザー決定）: EU 27か国と中国本土を外した147か国。アプリは「配信状況の設定」で「すべて」→外す。課金アイテムの配信可否も同じ147に揃えた。画面のチェックボックスには名前が付かないので、JavaScript でラベルの国名を見てクリックした（EU 27: オーストリア・ベルギー・ブルガリア・クロアチア・キプロス・チェコ共和国・デンマーク・エストニア・フィンランド・フランス・ドイツ・ギリシャ・ハンガリー・アイルランド・イタリア・ラトビア・リトアニア・ルクセンブルグ・マルタ・オランダ・ポーランド・ポルトガル・ルーマニア・スロバキア・スロベニア・スペイン・スウェーデン、＋中国本土）。
- 掲載画像: `marketing/screenshots/` は 1320×2868 で、必須の「中型ディスプレイ」枠には入らない。1206×2622 に縮小して入れた（5枚）。次に撮り直すときは生成器の出力をこの大きさにする。
- ビルドは 2（本番の広告ID）を選択。ビルド 1 はテスト広告なので審査に出さない。
- 年齢区分（2026-10-17、ユーザー決定）: 質問票は7ステップ。広告だけ「はい」、ほかはすべて「いいえ／なし」→ 4+。アプリ情報の「年齢制限指定を設定」から。画面は表示がとても遅いことがあり、空白なら再読み込みして10秒以上待つ。

GitHub の Actions → **Build もじつみ (iOS Release)** → Run workflow → `upload_to_testflight` に印。
（手で回さなくても、`mojitsumi-v*` のタグで走る）

- ビルド番号は `app/pubspec.yaml` の `version: 1.0.0+N` の N。同じ番号は二度上げられない
- テスト用の広告IDのままだと、CI がわざと止まる。AdMob より先に試すときは `test_ads` にも印（そのビルド番号は審査に出さない）

### 7. 自分の iPhone で試す

1. App Store Connect → アプリ → **TestFlight** → 内部テスト → グループを作り、自分（Apple ID）を入れる
2. アップロード後、処理に10〜30分ほど。iPhone の **TestFlight** アプリに出てくる
3. 確かめること（docs/app-pitfalls.md）: 「広告を消す（¥370）」の **¥ が豆腐にならない**（6番）・動画を最後まで見たら つづけられる・途中で閉じたら つづかない・
   購入を復元・アプリを裏に回すと「ひとやすみ」で止まる・音が鳴る・**ホーム画面の名前が「もじつみ」**、言語が日本語と英語（5番、IPA の `ja.lproj`）

### 審査に出すときに書くこと

**審査メモ（App Review Information → Notes、英語で）**

```
No login is required. The app is in Japanese.
The game runs fully offline inside the app (all content is bundled; no remote web content is loaded).
How to play: drag to move the falling hiragana letter, release to drop it. Letters that touch each other and read as a Japanese word score points.
In-app purchase: one non-consumable, "Remove Ads" (mojitsumi_remove_ads), on the start screen ("広告を消す"). The button appears once the App Store price has loaded.
"Restore purchases" ("購入を復元") is on the start screen.
Rewarded video ads are optional and always started by the player: "continue" after the tower collapses (once per game) and "get an item" (once per game).
Interstitial ads: when starting the next game from the result screen, about once every 3 games (never in the first 3 games, never within 2 minutes after a video ad). Not shown after purchasing Remove Ads.
Privacy policy, support (including reporting an inappropriate ad) and licenses open from "クレジット" (Credits) on the start screen.
The app does not use App Tracking Transparency and does not track users.
Before release, AdMob may not fill ads for this new app, so the video may be unavailable. The rewarded features can be checked by purchasing "Remove Ads" (sandbox), which enables them without video.
```

**App のプライバシー**: 護送ボートと同じ答え方（デバイス ID／サードパーティ広告／関連付けなし／トラッキングなし）。

**URL の欄**: プライバシーポリシー `https://mojitsumi.pages.dev/privacy.html`、サポート `https://mojitsumi.pages.dev/support.html`。

**年齢区分**: 質問票の「広告」は「あり」。暴力・性的な表現などは無し（ひらがなとことばだけ。ことばの一覧から性・犯罪・薬物・死の語を除いてある）。答えはユーザーが決める（4+ の見込み）。

**アプリの作り（審査 4.2 への備え）**: ゲーム本体は WebView で動くが、中身はすべてアプリに同梱していて通信なしで遊べる。
外部のページは、プライバシーポリシーなど決めた所だけを端末のブラウザで開く（`app/lib/game/bridge.dart` の `allowedHosts`）。
