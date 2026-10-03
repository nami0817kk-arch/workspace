# ひかりの指名 — TestFlight と App Store への出し方

2026-10-02 作成。護送ボート（`projects/goso-boat/docs/RELEASE.md`）を写した。サカマネ・護送ボートと同じ Apple のチームで出す。

## 使い回せるもの（登録済み・作り直さない）

| もの | GitHub Secrets | 備考 |
|---|---|---|
| 配信用証明書（Apple Distribution） | `IOS_DIST_CERT_BASE64` / `IOS_DIST_CERT_PASSWORD` | チームで1つ。アプリごとに作らない |
| チームID | `IOS_TEAM_ID` | |
| App Store Connect API キー | `APPSTORE_API_KEY_ID` / `APPSTORE_API_ISSUER_ID` / `APPSTORE_API_KEY_BASE64` | TestFlight へのアップロードに使う |
| 有料App契約・銀行口座 | — | サカマネで有効化済み。課金アイテムをすぐ作れる |

## 新しく要るもの（ひかりの指名だけ）

| もの | GitHub Secrets |
|---|---|
| プロビジョニングプロファイル（`com.namiki.hikari7` 用） | `HIKARI7_IOS_PROVISIONING_PROFILE_BASE64` |
| AdMob のアプリID（`~` 区切り） | `HIKARI7_ADMOB_APP_ID_IOS` |
| AdMob の広告ユニットID（動画・全画面、`/` 区切り） | `HIKARI7_ADMOB_REWARDED_IOS` / `HIKARI7_ADMOB_INTERSTITIAL_IOS` |

## 手順

### 1. App ID を登録する（Apple Developer）

1. https://developer.apple.com/account/resources/identifiers/list
2. **＋** → **App IDs** → **App**
3. Description に `Hikari7`、Bundle ID は Explicit で **`com.namiki.hikari7`**
4. Capabilities は何も足さない（課金は既定で使える。通知はアプリ内で完結するローカル通知なので Push Notifications は不要）

### 2. プロビジョニングプロファイルを作る

1. https://developer.apple.com/account/resources/profiles/list
2. **＋** → Distribution の **App Store Connect**
3. App ID に `com.namiki.hikari7`、証明書はサカマネと同じ Apple Distribution
4. 名前は `Hikari7 AppStore` など。ダウンロードした `.mobileprovision` を Base64 にして `HIKARI7_IOS_PROVISIONING_PROFILE_BASE64` に入れる
   （PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("Hikari7_AppStore.mobileprovision"))`）

### 3. App Store Connect にアプリを作る

API では作れないので、画面で作る。

1. https://appstoreconnect.apple.com/apps → **＋** → **新規App**
2. プラットフォーム **iOS**、名前 **ひかりの指名**（正式名はユーザーが決める）、主言語 **日本語**
3. バンドルID **com.namiki.hikari7**、SKU は `hikari7`、ユーザアクセスは「フルアクセス」

### 4. 課金アイテム「広告を消す」を作る

1. 作ったアプリ → **App内課金** → **＋** → **非消耗型**
2. 参照名 `Remove Ads`、製品ID **`hikari7_remove_ads`**（アプリ側に固定で書いてある）
3. 価格 **370円**（護送ボートと同じ。提出前にユーザーに確かめる）。表示名「広告を消す」／英語「Remove Ads」、説明「全画面広告が出なくなり、動画の特典も動画なしで使えます」
4. 審査用のスクリーンショット（「広告を消す（¥370）」のボタンが写ったタイトル画面）が無いと提出できない。TestFlight で撮れるようになってから入れる
5. **最初の課金アイテムは、アプリのバージョンと一緒に審査に出す。** バージョンのページには添付の欄が無い（2026-09-28 に確認）。課金アイテムのページ右上の **審査用に追加** → 提出の下書きを選ぶ（無ければ新規作成）→ iOS と版 1.0 を選ぶ。アプリの方もバージョンのページの **審査用に追加** で同じ下書きに入れ、下書きに両方が並んだのを見てから **審査へ提出**（課金アイテムを入れ忘れると、審査の担当者の端末で値段が取れずボタンが出ない＝「課金が見つからない」で却下される）

### 5. AdMob にアプリと広告ユニットを作る

1. https://apps.admob.com → アプリ → **アプリを追加** → iOS →「まだストアに公開されていない」を選ぶ → 名前 `ひかりの指名`
2. 広告ユニットを2つ: **リワード**（特訓の枠・制作費・再審査）と **インタースティシャル**（審査と審査の間）
3. アプリID（`ca-app-pub-…~…`）と、2つの広告ユニットID（`ca-app-pub-…/…`）を控えて Secrets に入れる

### 6. ビルドして TestFlight へ上げる

GitHub の Actions → **Build ひかりの指名 (iOS Release)** → Run workflow → `upload_to_testflight` に印。
（手で回さなくても、`hikari7-v*` のタグで走る）

- ビルド番号は `pubspec.yaml` の `version: 1.0.0+N` の N。同じ番号は二度上げられないので、上げ直すときは N を増やすか、入力欄 `build_number` で上書きする
- テスト用の広告IDのままだと、CI がわざと止まる（本物の広告が出ず収益ゼロになるのを防ぐ）

### 7. 自分の iPhone で試す

1. App Store Connect → アプリ → **TestFlight** → 内部テスト → グループを作り、自分（Apple ID）を入れる
2. アップロード後、処理に10〜30分ほど。iPhone の **TestFlight** アプリに出てくるので、インストール
3. 課金は TestFlight ではお金がかからない（Sandbox）。広告は本物のIDでもテスト表示になることがある

### 審査に出すときに書くこと

**審査メモ（App Review Information → Notes、英語で）**

```
No login is required. The app is in Japanese.
The game runs fully offline inside the app (all content is bundled; no remote web content is loaded).
In-app purchase: one non-consumable, "Remove Ads" (hikari7_remove_ads), on the title screen ("広告を消す"). The button appears once the App Store price has loaded.
"Restore purchases" ("購入を復元") is on the title screen.
Rewarded video ads unlock one bonus per audition (an extra intensive-lesson slot, extra budget, or a re-audition).
Interstitial ads: between auditions, from the end of the second audition. Not shown after purchasing Remove Ads.
The app does not use App Tracking Transparency and does not track users.
Privacy policy and licenses are on the title screen.
All characters, shows, and songs are fictional. Trainees are selected by the player's own judgment; there is no real-world voting.
Before release, AdMob may not fill ads for this new app, so the video may be unavailable. The bonuses can be checked by purchasing "Remove Ads" (sandbox), which enables them without video.
```

**App のプライバシー**: 護送ボートと同じ答え方（デバイス ID／サードパーティ広告／関連付けなし／トラッキングなし）。

**URL の欄**: プライバシーポリシー `https://hikari7.pages.dev/privacy.html`、サポート `https://hikari7.pages.dev/support.html`（`hikari7-site.yml` で公開してから）。

**年齢区分**: 質問票の「広告」は「あり」。そのほかの答え方はユーザー判断。

**アプリの作り（審査 4.2 への備え）**: ゲーム本体は WebView で動くが、中身はすべてアプリに同梱していて通信なしで遊べる。
外部のページは、プライバシーポリシーなど決めた所だけを端末のブラウザで開く（`app/lib/game/bridge.dart` の `allowedHosts`）。


## AdMob より先に TestFlight で試す（2026-10-04 追加）

Actions → **Build ひかりの指名 (iOS Release)** → Run workflow で `upload_to_testflight` と **`test_ads`** に印を付ける。
AdMob の Secrets が無くても、Google のテスト広告のまま作って TestFlight に上げる。
- **このビルド番号は審査に出さない**。本番は AdMob の Secrets を入れてから、`pubspec.yaml` の `+N` を上げて作り直す
- タグからのビルドでは選べない。TestFlight に上げないときは止まる
