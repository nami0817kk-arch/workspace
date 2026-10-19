# 野球育成 — TestFlight で実機に出す手順

2026-10-19 作成。ほかのアプリ(`projects/tenbin/docs/RELEASE.md` ほか)と同じ Apple のチームで出す。
このアプリは広告も課金も無いので、AdMob・課金アイテム・法務ページの手順は要らない(TestFlight で試すだけなら、下の 1〜4 で足りる)。

- バンドルID: **`com.namiki.baseballManager`**(`ios/Runner.xcodeproj` に設定済み)
- アプリ名(ホーム画面): 野球育成(`Info.plist` の `CFBundleDisplayName`)
- バージョン: `pubspec.yaml` の `version: 1.0.0+N` の N がビルド番号。**同じ番号は二度上げられない**
- ワークフロー: `.github/workflows/baseball-ios-release.yml`(macOS ランナーで署名→ビルド→TestFlight へ)

## 使い回すもの(登録済み・作り直さない)

| もの | GitHub Secrets |
|---|---|
| 配信用証明書(Apple Distribution) | `IOS_DIST_CERT_BASE64` / `IOS_DIST_CERT_PASSWORD` |
| チームID | `IOS_TEAM_ID` |
| App Store Connect API キー(TestFlight へのアップロード) | `APPSTORE_API_KEY_ID` / `APPSTORE_API_ISSUER_ID` / `APPSTORE_API_KEY_BASE64` |

## このアプリだけ新しく要るもの(**自分の Apple アカウントでしかできない**)

| もの | 置き場所 |
|---|---|
| プロビジョニングプロファイル(`com.namiki.baseballManager` 用) | GitHub Secrets `BASEBALL_IOS_PROVISIONING_PROFILE_BASE64` |

## 手順

### 1. App ID を登録する(Apple Developer)
1. https://developer.apple.com/account/resources/identifiers/list
2. **＋** → **App IDs** → **App**
3. Description に `Baseball Manager`、Bundle ID は Explicit で **`com.namiki.baseballManager`**
4. Capabilities は何も足さない

### 2. プロビジョニングプロファイルを作る
1. https://developer.apple.com/account/resources/profiles/list
2. **＋** → Distribution の **App Store Connect**
3. App ID に `com.namiki.baseballManager`、証明書はほかのアプリと同じ Apple Distribution
4. 名前は `BaseballManager AppStore` など。ダウンロードした `.mobileprovision` を Base64 にして `BASEBALL_IOS_PROVISIONING_PROFILE_BASE64` に入れる
   - **Git Bash で `base64 -w0 BaseballManager_AppStore.mobileprovision | gh secret set BASEBALL_IOS_PROVISIONING_PROFILE_BASE64`**
   - PowerShell のパイプだと末尾に CRLF が付き、CI の `Install provisioning profile` が `error decoding base64 input stream` で落ちる(もじつみで実際に落ちた)

### 3. App Store Connect にアプリを作る(**先に済ませる**)
API では作れないので、画面で作る。**これを先にしないと、アップロードが `Cannot determine the Apple ID from Bundle ID` で落ちる**(署名・ビルドまでは通る)。
1. https://appstoreconnect.apple.com/apps → **＋** → **新規App**
2. プラットフォーム **iOS**、名前 **野球育成**(使われていれば `野球育成：一代記` など)、主言語 **日本語**
3. バンドルID **com.namiki.baseballManager**、SKU は `baseball-manager`、ユーザアクセスは「フルアクセス」

### 4. ビルドして TestFlight へ上げる
GitHub の Actions → **Build 野球育成 (iOS / TestFlight)** → **Run workflow**
- `upload_to_testflight`: 印(既定でオン)
- `test_build`: 印(既定でオン)→ **管理者モードが最初からオンのテスト版**。設定の「対戦テスト」で能力・特性を決めて試せる。印を外すと通常版
- `build_number`: 空なら `pubspec.yaml` の `+N`。同じ番号は二度上げられないので、2回目からは番号を上げる(`+2`、または入力欄に数字だけ)
- タグ `baseball-v*` を打って走らせたビルドは、**必ず通常版**(テスト版にならない)

### 5. 自分の iPhone で試す
1. App Store Connect → アプリ → **TestFlight** → 内部テスト → グループを作り、自分(Apple ID)を入れる(自動配信オン)
2. アップロード後、処理に10〜30分ほど。iPhone の **TestFlight** アプリに出てくる
3. 確かめること:
   - 育成の流れ(6歳→プロ)、分かれ道(幼少期〜進路)の選択
   - 保存(アプリを閉じて開き直しても続きから)
   - 文字の大きさ・暗い画面・横向き(縦長の `390×844` に最適化。横向きは未確認)
   - ホーム画面の名前が「野球育成」、アイコン

## 確認できていないこと(Claude の環境は Linux なので、Xcode のビルドは試せない)
- **iOS のビルドと署名は、まだ一度も通していない。** 初回は CI のログを見て直す前提
- 実機での見た目(ノッチ・セーフエリア、横向き、`NavigationBar` の下の余白)
- iPad(`TARGETED_DEVICE_FAMILY = "1,2"` のまま。iPhone だけにするなら `1` に)
- Web 版で確認した画面(幅360〜1200)と、実機の見え方の差
