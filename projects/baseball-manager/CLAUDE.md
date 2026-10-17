# baseball-manager

野球の監督・育成シミュレーション。Flutter のスマホアプリ（広告・課金・ストア公開前提）。
soccer-manager / soccer-career の野球版。**中核は「試合中の采配と、シーズンを通した育成」**。

## 前提

- Flutter / Dart。依存は最小（`shared_preferences` は保存を入れるとき）。
- **国名は実在のもの、リーグ名・球団名・選手名・大会名は架空**（soccer-career と同じ線）。
  公開と収益化が前提なので商標・肖像のリスクを避ける。この線は動かさない。
  「ワールド・ベースボール・クラシック」等は商標なので「世界大会」と呼ぶ。
- 広告・課金を入れるときは**着手前に `docs/app-pitfalls.md` を読む**。
- 試合の確率計算は `lib/game/` の純Dart（Flutter非依存）に置き、`test/` で挙動を固定する。
  バランスは片方だけ触ると崩れるので、変えたらテストも更新する。
- 保存データを足すときは `fromJson` に既定値を置く（既存セーブを壊さない）。

## テスト

ローカルではなく CI（`.github/workflows/baseball-ci.yml`）で回す。手元は analyze まで。
