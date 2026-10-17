# baseball-manager

野球の監督・育成シム。設計の叩き台は CLAUDE.md。

## 現状

- `lib/game/at_bat.dart` — 1打席の結果を決める純Dartのエンジン（投手 vs 打者）
- `lib/game/career.dart` — 年齢→段階(少年〜引退)と伸びやすさの曲線
- `lib/game/player.dart` — 選手(役割・能力・素質)と保存/復元
- `lib/game/training.dart` — `advanceYear`: 1年進めて練習方針に応じて能力を伸ばす/落とす
- `lib/game/path.dart` — ドラフト判定・大学/社会人の再挑戦・戦力外/引退
- `lib/game/season.dart` — 1試合の個人成績と勝ち抜き大会。結果の `achievement` がドラフトの実績に入る
- `lib/game/life.dart` — 1年を4季節に分け、季節ごとの過ごし方(練習/特訓/休養/研究/交流/練習試合)・体調・怪我・出来事(選択つき)
- `lib/game/traits.dart` — 特性(個性)。伸び・怪我・疲労・気持ち・大会・ドラフトへの効き方を1か所に集める
- `lib/game/game.dart` — 本体 `Game`。季節の選択→大会→ドラフト→プロ→引退を進める。画面に依存せず、保存/復元もここ
- `lib/main.dart` — 起動確認用の最小画面
- Android/iOS/web の各フォルダは未生成。`flutter create . --platforms=android,ios,web --project-name baseball_manager` で足す
