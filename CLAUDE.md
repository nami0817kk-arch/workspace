# soccer-manager

サッカークラブ経営・育成シミュレーション。Flutter + Flame のスマホアプリ。

Web版: https://nami0817kk-arch.github.io/soccer-manager/
（非公開リポジトリのため、Pages を使うには Pro/Team 以上か公開設定が必要）

## よく使うコマンド

```bash
flutter pub get
flutter test              # テスト
flutter run               # 実機/エミュレータ
flutter build web --base-href /soccer-manager/
```

## 手を入れるときに気をつけること

- Web版は `.github/workflows/web.yml` が push 時に自動デプロイする。
  `--base-href` を変えるとリンクが全部壊れるので触らない。
- ポジションは GK/DR/DC/DL/WBR/WBL/DM/MR/MC/ML/AMR/AMC/AML/ST の14種類。
  自動編成は 主ポジション → 副ポジション → 同じ大分類 の順に割り当てる。
  この優先順を変えるとスタメンが総入れ替えになる。
- フォーメーションは具体的な11ポジションで定義されている。
  追加するときは既存の4種（4-4-2 / 4-3-3 / 4-2-3-1 / 3-5-2）の定義に揃える。
- 試合シミュレーション・信頼度・契約まわりは相互に影響する。
  片方だけ調整するとゲームバランスが崩れるので、変更したらテストで挙動を固定する。
- ストア公開の文面は `STORE_LISTING.md` にある。
- ストア提出は `soccer-manager-v*` タグで `android-release.yml` / `ios-release.yml` が動く。
  署名鍵・API キーは GitHub Secrets に未登録なので、初回は登録が要る。
