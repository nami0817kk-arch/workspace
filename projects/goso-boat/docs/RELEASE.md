# 護送ボート — TestFlight と App Store への出し方

2026-09-27 作成。サカマネ（`projects/soccer-manager/docs/RELEASE_GUIDE.md`）と同じ Apple のチームで出す。

## 使い回せるもの（登録済み・作り直さない）

| もの | GitHub Secrets | 備考 |
|---|---|---|
| 配信用証明書（Apple Distribution） | `IOS_DIST_CERT_BASE64` / `IOS_DIST_CERT_PASSWORD` | チームで1つ。アプリごとに作らない |
| チームID | `IOS_TEAM_ID` | |
| App Store Connect API キー | `APPSTORE_API_KEY_ID` / `APPSTORE_API_ISSUER_ID` / `APPSTORE_API_KEY_BASE64` | TestFlight へのアップロードに使う |
| 有料App契約・銀行口座 | — | サカマネで有効化済み。課金アイテムをすぐ作れる |

## 新しく要るもの（護送ボートだけ）

| もの | GitHub Secrets |
|---|---|
| プロビジョニングプロファイル（`com.namiki.gosoBoat` 用） | `GOSO_IOS_PROVISIONING_PROFILE_BASE64` |
| AdMob のアプリID（`~` 区切り） | `GOSO_ADMOB_APP_ID_IOS` |
| AdMob の広告ユニットID（動画・全画面、`/` 区切り） | `GOSO_ADMOB_REWARDED_IOS` / `GOSO_ADMOB_INTERSTITIAL_IOS` |

## 手順

### 1. App ID を登録する（Apple Developer）

1. https://developer.apple.com/account/resources/identifiers/list
2. **＋** → **App IDs** → **App**
3. Description に `Goso Boat`、Bundle ID は Explicit で **`com.namiki.gosoBoat`**
4. Capabilities は何も足さない（課金は既定で使える。通知はアプリ内で完結するローカル通知なので Push Notifications は不要）

### 2. プロビジョニングプロファイルを作る

1. https://developer.apple.com/account/resources/profiles/list
2. **＋** → Distribution の **App Store Connect**
3. App ID に `com.namiki.gosoBoat`、証明書はサカマネと同じ Apple Distribution
4. 名前は `Goso Boat AppStore` など。ダウンロードした `.mobileprovision` を Base64 にして `GOSO_IOS_PROVISIONING_PROFILE_BASE64` に入れる
   （PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("Goso_Boat_AppStore.mobileprovision"))`）

### 3. App Store Connect にアプリを作る

API では作れないので、画面で作る。

1. https://appstoreconnect.apple.com/apps → **＋** → **新規App**
2. プラットフォーム **iOS**、名前 **脱獄させるな！護送ボート：川渡りパズル**、主言語 **日本語**
3. バンドルID **com.namiki.gosoBoat**、SKU は `goso-boat`、ユーザアクセスは「フルアクセス」

### 4. 課金アイテム「広告を消す」を作る

1. 作ったアプリ → **App内課金** → **＋** → **非消耗型**
2. 参照名 `Remove Ads`、製品ID **`goso_boat_remove_ads`**（アプリ側に固定で書いてある）
3. 価格 **370円**（ユーザー決定）。表示名「広告を消す」／英語「Remove Ads」、説明「全画面広告が出なくなり、ヒントも動画なしで使えます」
4. 審査用のスクリーンショットは、TestFlight で撮れるようになってから入れればよい

### 5. AdMob にアプリと広告ユニットを作る

1. https://apps.admob.com → アプリ → **アプリを追加** → iOS →「まだストアに公開されていない」を選ぶ → 名前 `護送ボート`
2. 広告ユニットを2つ: **リワード**（ヒント用）と **インタースティシャル**（面と面の間）
3. アプリID（`ca-app-pub-…~…`）と、2つの広告ユニットID（`ca-app-pub-…/…`）を控えて Secrets に入れる

### 6. ビルドして TestFlight へ上げる

GitHub の Actions → **Build 護送ボート (iOS Release)** → Run workflow → `upload_to_testflight` に印。
（手で回さなくても、`goso-boat-v*` のタグで走る）

- ビルド番号は `pubspec.yaml` の `version: 1.0.0+N` の N。同じ番号は二度上げられないので、上げ直すときは N を増やすか、入力欄 `build_number` で上書きする
- テスト用の広告IDのままだと、CI がわざと止まる（本物の広告が出ず収益ゼロになるのを防ぐ）

### 7. 自分の iPhone で試す

1. App Store Connect → アプリ → **TestFlight** → 内部テスト → グループを作り、自分（Apple ID）を入れる
2. アップロード後、処理に10〜30分ほど。iPhone の **TestFlight** アプリに出てくるので、インストール
3. 課金は TestFlight ではお金がかからない（Sandbox）。広告は本物のIDでもテスト表示になることがある
