# baseball-manager

野球の監督・育成シム。設計の叩き台は CLAUDE.md。

## 現状

- `lib/game/at_bat.dart` — 1打席の結果を決める純Dartのエンジン（投手 vs 打者）
- `lib/game/career.dart` — 年齢→段階(少年〜引退)と伸びやすさの曲線
- `lib/main.dart` — 起動確認用の最小画面
- Android/iOS/web の各フォルダは未生成。`flutter create . --platforms=android,ios,web --project-name baseball_manager` で足す
