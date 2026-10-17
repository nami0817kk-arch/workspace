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
