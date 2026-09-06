# soccer-clicker

選手を育て、クラブを強くしていく放置・育成型のサッカーゲーム（Flutter）。

`soccer-manager`（クラブ経営シミュレーション）とは別アプリ。あちらが腰を据えて
遊ぶ長時間のシムなのに対し、こちらは数十秒で1周する短いループを狙っている。

## 遊び方

1. **練習**タブをタップして EP（育成ポイント）を貯める
2. EP で強化を買う
   - トレーニング強化 … タップ1回の獲得量が増える
   - コーチ … アプリを閉じていても EP が貯まる（最大8時間分）
3. **スカッド**タブで選手を育成し、新しい選手を獲得する
4. **試合**タブで対戦する。勝つと報酬 EP、規定数勝つとクラブランクが上がる
5. ランクが上がると相手も強くなる。育成に戻る

## 構成

```
lib/
  game/
    models.dart          GameState / Player / MatchResult（純 Dart）
    formulas.dart        数値バランスの定義。調整はここに集約
    engine.dart          状態遷移。すべて純粋関数
    game_controller.dart エンジン・保存・時計をつなぐ層。UI はここだけ見る
  storage/
    save_store.dart      保存のインターフェースと実装（メモリ / shared_preferences）
  ui/
    game_screen.dart     3タブ（練習・スカッド・試合）
    format.dart          大きな数の表示（1.2k / 3.4M）
test/
  engine_test.dart       ロジック（放置上限・時計の巻き戻り・勝敗・セーブ往復）
  controller_test.dart   復帰時の精算・壊れたセーブ・保存の永続化
```

## 開発

```bash
flutter pub get
dart analyze lib test    # flutter analyze は非ASCIIパスでクラッシュするため
flutter run -d chrome
```

テストの合否は CI（`.github/workflows/soccer-clicker-ci.yml`）で判断する。
詳細と注意点は [CLAUDE.md](CLAUDE.md)。
