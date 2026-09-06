# soccer-clicker

選手を育て、クラブを強くしていく放置・育成型のサッカーゲーム（Flutter）。
`soccer-manager`（クラブ経営シミュレーション）とは**別アプリ**で、コードも共有していない。
あちらが腰を据えて遊ぶ長時間のシムなのに対し、こちらは数十秒で1周する短いループを狙う。

## 前提

- Flutter 3.47.2（このPCの SDK は `C:\Users\Public\flutter`。CI は `channel: stable`）。
- 通貨は **EP（育成ポイント）1種類だけ**。資金・スタミナ等を足すと放置ゲームの
  手触りが鈍るので、増やすときは本当に必要か検討してから。
- 保存は `shared_preferences`。**プラグインは `lib/storage/save_store.dart` の
  インターフェース裏に隠してある**ので、テストは `InMemorySaveStore` を使い、
  プラグインを起動しない。
- `lib/game/` は **Flutter に依存しない純 Dart**。UI を差し替えてもロジックは動く。

## よく使うコマンド

```bash
flutter pub get
flutter analyze          # 手元で回すのはここまで（workspace 規約5）
flutter test             # 合否の判断は CI に置く
flutter run -d chrome    # 手元で触ってみるとき
```

**`flutter analyze` はこのリポジトリのパス（`C:\Users\なみ\...`）から実行すると
クラッシュする。** analysis server が非 ASCII のパスで壊れるため。回避は
`subst X: <プロジェクトのパス>` してドライブから実行するか、`dart analyze lib test`
を使う（後者はクラッシュしない）。

## 手を入れるときに気をつけること

- **数値バランスは `lib/game/formulas.dart` に集約する。** エンジンやUIに数字を
  直接書かない。定数を変えると既存セーブの体感が変わるので、変更時は
  `test/engine_test.dart` の期待値も合わせて見直す。
- **状態遷移は `GameEngine` の純粋関数だけで行う。** 新しい操作を足すときも
  `(GameState, RejectReason?)` を返す形に揃える。UI 側で状態を直接いじらない。
- **乱数と時刻は必ず外から渡す。** `GameController` が `Random` と `Clock` を受け取る
  作りになっているのはテストのため。`DateTime.now()` を内部で直接呼ばない。
- **放置収入は `applyElapsed` の1経路に統一してある。** 起動中の毎秒加算も復帰時の
  精算も同じ関数を通る。別経路を足すと二重加算になる。
- **時計の巻き戻りに耐えること。** 端末の時刻を戻して EP を稼げないよう、
  経過が負なら加算しない（`test/engine_test.dart` に検証あり）。
- **壊れたセーブでは起動を止めない。** JSON が読めなければ新規開始に倒す。
  ここを例外にすると、一度壊れたユーザーがアプリを開けなくなる。
- 放置の上限は 8 時間（`Formulas.offlineCap`）。無いと長期放置で一気に終わる。

## まだ無いもの

- 収益化（リワード広告・課金）。ストア申請も未着手。`soccer-manager` の
  `STORE_LISTING.md` が先例になる。
- 音・アニメーション・演出のたぐい。今はロジックと最低限のUIだけ。
- Web版の公開。足すなら `soccer-pages.yml` に倣って別ワークフローにする。
