# soccer-manager

サッカークラブ経営・育成シミュレーション。Flutter + Flame のスマホアプリ。

Web版: https://soccer-manager.pages.dev/
（Cloudflare Pages。workspace リポジトリに CLOUDFLARE_API_TOKEN と
CLOUDFLARE_ACCOUNT_ID を登録するまでデプロイは動かない。tool-factory と
同じ値でよい。GitHub Pages は非公開 + Free だとサイトを作成できず、
統合前は毎回失敗していた）

## よく使うコマンド

```bash
flutter pub get
flutter test              # テスト
flutter run               # 実機/エミュレータ
flutter build web --base-href /
```

## 手を入れるときに気をつけること

- Web版はリポジトリ直下の `.github/workflows/soccer-pages.yml` が push 時に
  Cloudflare Pages へ自動デプロイする。base-href は "/" 固定。変えると資産の
  参照先がずれて真っ白な画面になる。
- 検証(analyze + test)は `.github/workflows/soccer-ci.yml` が別に回す。
  デプロイと分けてあるので、赤いワークフローを見たときにコードと公開設定の
  どちらが壊れたか切り分けられる。
- ローカルで `flutter analyze` を回すときは、パスに非ASCII文字が入っていると
  解析サーバーがクラッシュする。`subst X: <このディレクトリ>` してから
  X: 側で実行する。`flutter test` はこの問題を踏まない。
- アプリ内の法務リンク(settings_screen.dart)とストア掲載情報は、まだ旧モノレポ
  claude-code-dev の GitHub Pages を指している。現在は200で生きているが、
  このリポジトリの更新は届かない。先に差し替えると今動いているリンクを404に
  してしまうため、Cloudflare Pages のデプロイが通ってから
  settings_screen.dart / STORE_LISTING.md / README.md / distribution_test.dart
  の4箇所をまとめて移す。
- ポジションは GK/DR/DC/DL/WBR/WBL/DM/MR/MC/ML/AMR/AMC/AML/ST の14種類。
  自動編成は 主ポジション → 副ポジション → 同じ大分類 の順に割り当てる。
  この優先順を変えるとスタメンが総入れ替えになる。
- フォーメーションは具体的な11ポジションで定義されている。
  追加するときは既存の4種（4-4-2 / 4-3-3 / 4-2-3-1 / 3-5-2）の定義に揃える。
- 試合シミュレーション・信頼度・契約まわりは相互に影響する。
  片方だけ調整するとゲームバランスが崩れるので、変更したらテストで挙動を固定する。
- ストア公開の文面は `STORE_LISTING.md` にある。
- ストア提出は `soccer-manager-v*` タグで `soccer-android-release.yml` /
  `soccer-ios-release.yml` が動く。
  署名鍵・API キーは GitHub Secrets に未登録なので、初回は登録が要る。
