# 塔の意志（仮題）

掘って生き物を育てる防衛ゲームの試作を、iPhone で遊ぶための入れ物アプリ。
ゲーム本体は HTML の試作で、Flutter 側は全画面の WebView で開くだけ。

- バンドルID: `com.namiki.tounoishi`（iPhone のみ・縦画面）
- 試作の正: リポジトリの外の `game-assets/fukaana/prototype-v*.html`。
  更新したら `python tool/sync_game.py <試作>` で `assets/game/index.html` へ写す
- 仕様書: Claude Docs「塔の意志 仕様書」
- 広告・課金はまだ入れていない（TestFlight で手触りを確かめる段階）。入れるときは `docs/app-pitfalls.md` を先に読む

## ビルドと TestFlight

`.github/workflows/tounoishi-ios-release.yml`（goso-boat のものから広告・法務ページの検査を外した版）。

```
gh workflow run tounoishi-ios-release.yml --repo nami0817kk-arch/workspace --ref <branch> -f upload_to_testflight=true
```

- ビルド番号は `pubspec.yaml` の `+N`。同じ番号は二度上げられない
- 要る Secrets: 共通の `IOS_DIST_CERT_*`・`IOS_TEAM_ID`・`APPSTORE_API_*` と、このアプリの `TOUNOISHI_IOS_PROVISIONING_PROFILE_BASE64`
- App Store Connect にアプリが無いと、アップロードが `Cannot determine the Apple ID from Bundle ID` で落ちる
