# 塔の意志（仮題）

掘って生き物を育てる防衛ゲームの試作を、iPhone で遊ぶための入れ物アプリ。
ゲーム本体は HTML の試作で、Flutter 側は全画面の WebView で開くだけ。

- バンドルID: `com.namiki.tounoishi`（iPhone のみ・縦画面）
- 試作の正: リポジトリの外の `game-assets/fukaana/prototype-v*.html`（0.4.0 は v11：縦画面1枚・2本指で拡大・なぞって印→離して掘る・一覧と遊び方は下のシート。0.5.0 は v12：掘る力・主役を鍛える・養分を運ぶ・ピュア種・塔の全体図・コアの台詞・音。0.6.0 は v13：初代との差を全部（掘ったマスの隣だけ掘れる・コケの運び方と花・ドラゴンの生まれ変わりと炎・ふん・フェロモン・巣・魔法陣・冒険者の MP と技・たいまつ・系統の強化・軍・ヒント・チャレンジ・朝昼夜）。初代の調べは game-assets/fukaana/research-shodai.md）。
  更新したら `python tool/sync_game.py <試作>` で `assets/game/index.html` へ写す
- 仕様書: Claude Docs「塔の意志 仕様書」
- 保存: ゲームは `window.TouStore` 経由でアプリ側（shared_preferences）にも保存し、起動時に `window.__boot` で戻す（鍵は tou-save・tou-hall・tou-best・tou-dex）
- 広告と課金（0.3.0 から。ひかりの指名 `projects/hikari7/app` を写して絞ったもの。触る前に `docs/app-pitfalls.md` を読む）
  - 全画面広告だけ。ゲームが頼んだときに出す: 負けて結果画面を出す前（`finishTower()`）と、塔が1階伸びる前（`grow()`）。リワード広告と ATT は入れない
  - 課金は非消耗型1つ「広告を消す」（370円、`com.namiki.tounoishi.removeads`）。買うと全画面広告が出ない。タイトルに「広告を消す（値段）」「購入を復元」、買った後は「広告なし」
  - Dart 側: `lib/monetization/`（ad_service・purchase_service・monetization）と `lib/game/bridge.dart`。購入の受け取りは `onDelivered` の1か所、受け取り後に completePurchase。広告は55分で捨て、読み込みと表示は Completer で待つ
  - ゲームとの約束: 窓口は JS チャンネル `TouApp`（無ければブラウザとみなし何もしない）。ゲームから `{type:'inter',at:'lose'|'grow'}`・`prepInter`・`buy`・`restore`・`refresh`。ゲームから `{type:'haptic',kind}` で掘った時の振動。裏に回る時はアプリが `window.__pause()`（止めて保存）を呼ぶ。アプリから `touSetApp({adFree,price,canBuy,storeOk,msg?})`・`touAdShowing()`・`touInterDone()`。ゲーム側は `appInter(at,next)`（5秒で表示が始まらなければ進める）・`appPrep()`・`renderShop()`
  - AdMob の ID は既定で Google のテスト用。本番は CI が Secrets `TOUNOISHI_ADMOB_APP_ID_IOS`・`TOUNOISHI_ADMOB_INTERSTITIAL_IOS` で差し替える（未設定ならビルドは止まる）
  - 検査は `test/monetization_test.dart`

## ビルドと TestFlight

`.github/workflows/tounoishi-ios-release.yml`（goso-boat のものを写した版。AdMob の本番IDの検査と差し替えはあり、法務ページと app-ads.txt の検査はまだ無い。App Store に出す前に goso-boat から写す）。

```
gh workflow run tounoishi-ios-release.yml --repo nami0817kk-arch/workspace --ref <branch> -f upload_to_testflight=true
```

- ビルド番号は `pubspec.yaml` の `+N`。同じ番号は二度上げられない
- 要る Secrets: 共通の `IOS_DIST_CERT_*`・`IOS_TEAM_ID`・`APPSTORE_API_*` と、このアプリの `TOUNOISHI_IOS_PROVISIONING_PROFILE_BASE64`・`TOUNOISHI_ADMOB_APP_ID_IOS`・`TOUNOISHI_ADMOB_INTERSTITIAL_IOS`
- App Store Connect にアプリが無いと、アップロードが `Cannot determine the Apple ID from Bundle ID` で落ちる
