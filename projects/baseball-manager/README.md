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
- `lib/game/calendar.dart` — 月単位/季節のターン割り
- `lib/game/exp.dart` — 経験点・やる気・能力への振り分け
- `lib/game/characters.dart` — 登場人物（仲間・ライバル・家族/恋人・コーチ）と絆
- `lib/game/game.dart` — 本体 `Game`。季節の選択→大会→ドラフト→プロ→引退を進める。画面に依存せず、保存/復元もここ
- `lib/main.dart` — 起動確認用の最小画面
- web のみ生成済み。Android/iOS は `flutter create . --platforms=android,ios --project-name baseball_manager` で足す
- `lib/ui/` — 画面（はじめ / 育成 / エンディング）と、保存つきのコントローラ
