# 召喚の山札（仮題）

ヴァンパイアサバイバーズ×デッキのゲームの試作を、iPhone の TestFlight で遊ぶための入れ物。
ゲーム本体は HTML の試作（`assets/game/index.html`）で、Flutter の WebView で全画面に開くだけ。
作りは `projects/tounoishi` を写した（広告・課金・法務ページは無い）。

- 試作の正: claude.ai の Artifact（https://claude.ai/artifact/JezSySuQomFh6q3SYKh1eU）。
  更新したら Artifact の HTML を手元に落として `python tool/sync_game.py <HTML>` で assets へ写す
- 保存: ゲームの localStorage（`shokan-yamafuda-v2` と `shokan-mute`）を、同梱 HTML の頭の仕掛けが
  `ShokanStore` でアプリ側にも渡す。起動時に戻す（`lib/main.dart`）。名前を変えたら `storeKeys`・`tool/sync_game.py`・テストの3か所
- バンドルID: `com.namiki.shokan`。プロファイルは Secrets の `SHOKAN_IOS_PROVISIONING_PROFILE_BASE64`
- TestFlight へ: `pubspec.yaml` の `+N` を上げて master へ →
  `gh workflow run shokan-ios-release.yml --repo nami0817kk-arch/workspace --ref master -f upload_to_testflight=true`
- テストは CI（`shokan-ci.yml`）。WebView は動かせないので、同梱物と保存の窓口の約束を確かめる
