# つるはし採掘 — TestFlight と App Store への出し方

2026-10-05 作成。ひかりの七席（`projects/hikari7/docs/RELEASE.md`）を写した。サカマネ・護送ボート・ひかりの七席と同じ Apple のチームで出す。
ビルドは `.github/workflows/tsuruhashi-ios-release.yml`（`tsuruhashi-v*` のタグか、Actions の画面から手で回す）。

## 出す前に決めること（ユーザー）

- **アプリの名前**（今は仮題「つるはし採掘」。ホーム画面の名前は `app/ios/Runner/Info.plist` と `ja.lproj`・`en.lproj` の `InfoPlist.strings`、ゲームの中の文字、`legal/`・`site/`、`STORE_LISTING.md`、リリースビルドの法務ページの確認文字列にある）
- **課金アイテムの値段**（コードには書かない。App Store Connect で決める）
- **公開ページを出すか**: `legal/`・`site/` は master に入れたときに `tsuruhashi-site.yml` が `tsuruhashi.dailyquarry.com` に出す。
  **リリースビルドはこのページが開けないと止まる**（設定の「プライバシー」のリンク先が 404 だと審査で却下されるため）

## 使い回せるもの（登録済み・作り直さない）

| もの | GitHub Secrets | 備考 |
|---|---|---|
| 配信用証明書（Apple Distribution） | `IOS_DIST_CERT_BASE64` / `IOS_DIST_CERT_PASSWORD` | チームで1つ |
| チームID | `IOS_TEAM_ID` | |
| App Store Connect API キー | `APPSTORE_API_KEY_ID` / `APPSTORE_API_ISSUER_ID` / `APPSTORE_API_KEY_BASE64` | TestFlight へのアップロードに使う |
| 有料App契約・銀行口座 | — | サカマネで有効化済み |

## 新しく要るもの（つるはし採掘だけ）

| もの | GitHub Secrets |
|---|---|
| プロビジョニングプロファイル（`com.namiki.tsuruhashi` 用） | `TSURUHASHI_IOS_PROVISIONING_PROFILE_BASE64` |
| AdMob のアプリID（`~` 区切り） | `TSURUHASHI_ADMOB_APP_ID_IOS` |
| AdMob の広告ユニットID（**リワード1つだけ**、`/` 区切り） | `TSURUHASHI_ADMOB_REWARDED_IOS` |

## 手順

### 1. App ID を登録する（Apple Developer）

1. https://developer.apple.com/account/resources/identifiers/list
2. **＋** → **App IDs** → **App**
3. Description に `Tsuruhashi`、Bundle ID は Explicit で **`com.namiki.tsuruhashi`**
4. Capabilities は何も足さない（課金は既定で使える。通知は端末の中だけのローカル通知なので Push Notifications は不要）

### 2. プロビジョニングプロファイルを作る

1. https://developer.apple.com/account/resources/profiles/list
2. **＋** → Distribution の **App Store Connect**
3. App ID に `com.namiki.tsuruhashi`、証明書はほかのアプリと同じ Apple Distribution
4. 名前は `Tsuruhashi AppStore` など。`.mobileprovision` を Base64 にして `TSURUHASHI_IOS_PROVISIONING_PROFILE_BASE64` に入れる
   （PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("Tsuruhashi_AppStore.mobileprovision"))`）

### 3. App Store Connect にアプリを作る

1. https://appstoreconnect.apple.com/apps → **＋** → **新規App**
2. プラットフォーム **iOS**、名前（ユーザーが決めた名前）、主言語 **日本語**
3. バンドルID **com.namiki.tsuruhashi**、SKU は `tsuruhashi`、ユーザアクセスは「フルアクセス」

### 4. 課金アイテムを4つ作る（製品IDはアプリに固定で書いてある）

| 製品ID | 種類 | 表示名 | 説明 |
|---|---|---|---|
| `tsuruhashi_canteen` | 非消耗型 | 社員食堂 | 仲間の力が +25%。ずっと効き、代替わりしても残ります |
| `tsuruhashi_cart` | 非消耗型 | 大きな荷車 | 留守の間に掘れる時間が4時間のびます（8→12時間） |
| `tsuruhashi_bento3` | 消耗型 | 特製弁当 3個 | 1個で30分、仲間の力が2倍。使うときは自分で選べます |
| `tsuruhashi_bento10` | 消耗型 | 特製弁当 10個 | 同上（10個） |

- 値段はユーザーが決める
- 審査用のスクリーンショット（「社」タブの売店が写った画面）が各商品に要る。TestFlight で撮れるようになってから入れる
- **最初の課金アイテムは、アプリのバージョンと一緒に審査に出す**（手順はひかりの七席の RELEASE.md の4-5と同じ。下書きに5件（アプリ＋4商品）が並んだのを見てから提出）
- 弁当は消耗型で「購入を復元」では戻らない。届け方は docs/app-pitfalls.md の1番・7番の手当て済み（`onDelivered` で渡してから `completePurchase`、取引番号で二重を捨てる）

### 5. AdMob にアプリと広告ユニットを作る

1. https://apps.admob.com → アプリ → **アプリを追加** → iOS →「まだストアに公開されていない」→ 名前
2. 広告ユニットは **リワード** を1つだけ（採掘の倍率・留守の3倍・代替わりの名声2倍・鉱脈の3倍はすべてこれを使う）
3. アプリID（`ca-app-pub-…~…`）と広告ユニットID（`ca-app-pub-…/…`）を Secrets に入れる
4. 広告のコンテンツの上限は **G（全年齢）** にする（年齢区分 4+ のため）
5. `app-ads.txt` は `site/app-ads.txt`（公開ページと一緒に出る）。AdMob のアプリ設定で、ストアのURLを結びつけた後に確認される

### 6. ビルドして TestFlight へ上げる

GitHub の Actions → **Build つるはし採掘 (iOS Release)** → Run workflow → `upload_to_testflight` に印。

- ビルド番号は `app/pubspec.yaml` の `version: 1.0.0+N` の N。上げ直すときは N を増やすか入力欄 `build_number` で上書き
- 止まる所（わざと）: Secrets の未設定・テスト用の広告ID・法務ページが開けない・IPA に `ja.lproj` やゲーム本体が入っていない

### 7. 自分の iPhone で試す（実機でしか見えないもの）

TestFlight で入れて、次を目で見る:
- [ ] 起動 → はじめる → 仲間が掘る・BGM が鳴る（消音スイッチ・音量）
- [ ] 動画: 採掘の倍率（2本見て ×3 になり、右上の札に「mm:ss後に×2」）・留守の3倍・代替わりの名声2倍・鉱脈の3倍。見ている途中にアプリを裏に回しても受け取れるか
- [ ] 課金（Sandbox、お金はかからない）: 4商品の値段が出る（**「¥」が豆腐にならないか**。docs/app-pitfalls.md 6番）、買うと届く、アプリを消して入れ直し→「購入を復元」で食堂と荷車が戻る
- [ ] 通知: 初めて留守から戻ったときに許可を求める／裏に回すと留守の上限の時刻に1件だけ来る
- [ ] 設定の「プライバシー」が `tsuruhashi.dailyquarry.com/privacy.html` を開く
- [ ] レビューのお願いが出すぎないか

## 審査に出すときに書くこと

**審査メモ** は `STORE_LISTING.md` の「審査へのメモ」をそのまま貼る。

**App のプライバシー**: ほかのアプリと同じ答え方（デバイス ID／サードパーティ広告／関連付けなし／トラッキングなし）。

**URL の欄**: プライバシーポリシー `https://tsuruhashi.dailyquarry.com/privacy.html`、サポート `https://tsuruhashi.dailyquarry.com/support.html`。

**年齢区分**: 質問票の「広告」は「あり」。暴力・恐怖の表現はない（4+ の想定。答えはユーザー判断）。

**掲載画像**: `store/screenshots/01〜06.png`（6.7インチ 1290×2796、`node tool/make_shots.js`）。
**iPad**: Xcode の設定が iPhone・iPad 両対応（`TARGETED_DEVICE_FAMILY = "1,2"`、ほかのアプリと同じ）なので、App Store Connect が iPad の掲載画像（13インチ）を求めてきたら、
`make_shots.js` の大きさを変えて撮るか、iPhone 専用（`"1"`）に変えるかをユーザーに聞く。

**アプリの作り（審査 4.2 への備え）**: ゲーム本体は WebView で動くが、中身（絵・BGM 含む）はすべてアプリに同梱していて通信なしで遊べる。
外部のページは、プライバシーポリシーなど決めた所だけを端末のブラウザで開く（`app/lib/game/bridge.dart` の `allowedHosts`）。
