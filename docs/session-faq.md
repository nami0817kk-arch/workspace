# セッション FAQ — ユーザーに聞く前にここを読む

workspace で作業する Claude セッション向け。ここに無い疑問は
`docs/coordinator.txt` に書かれた調整役セッションへ **SendMessage** で聞く。
**ユーザーへの質問は最終手段**（調整役が不在・応答しない・ユーザーにしか決められない事項のみ）。

## 構成・場所

- **全PJTはモノレポ `C:\Users\なみ\dev\workspace`**（private、nami0817kk-arch/workspace）。
  旧 dev/ 直下の個別フォルダ・個別リポジトリは**もう使わない**（アーカイブ待ち）。
- レイアウト: `projects/<pjt>`（採番なし: stock-investment / ai-blog 等）、`libs/kabutan`、
  `platform/ai-lab`、ルート `.github/workflows`（**必ず paths: で絞る**）。
- 新しいPJTを足したら: `projects/<name>/` に置き、`<name>-tests.yml` を既存パターン
  （python-tests.yml の workflow_call）で作り、ルート `.github/dependabot.yml` の
  pip `directories:` に追加する。

## 作業の始め方（規約の要点）

- **メインツリーで checkout 禁止。必ず worktree**:
  `git -C C:/Users/なみ/dev/workspace worktree add C:/Users/なみ/dev/wt-<topic> -b claude/<topic> origin/master`
- 区切りごとに push（WIP可）。毎晩22時の wip-sweeper が未pushを `wip/` へ退避するが保険にすぎない。
- 小さな単一PJT変更は master 直 push 可（worktree 上で）。それ以外は fetch→検証→merge。

## よくある質問（実際に出たもの）

**Q. 旧リポジトリ（dev/ai-lab 等）で作業してしまった / 作業中のものがある**
A. ブランチを旧リポジトリの origin に push した上で、workspace 側から
`git subtree pull --prefix=<配置先> C:/Users/なみ/dev/<旧リポ> <ブランチ>` で合流させる。
衝突は「統合後に workspace 側が触った箇所」（projects.toml、入れ子 .github の削除等）に限られ、
**workspace 側を正**として解消する。

**Q. 入れ子の `.github/`（projects/*/github 等）が消えている**
A. 意図的。モノレポでは動かないため削除した。ワークフローの実体はルート
`.github/workflows/` にあり、変更したい場合はそちらの `<pjt>-*.yml` を直す。

**Q. soccer の web.yml が無い**
A. GitHub Pages が private リポジトリで使えないため意図的に未移植。
Cloudflare Pages 方式の `soccer-pages.yml` として作り直す（tool-factory-pages.yml が先例。
Flutter ビルドは `--base-href "/"` に変更が必要）。担当セッションが作業中。

**Q. kabu-daily / tool-factory-pages がデプロイ段で failure**
A. 既知。Cloudflare の Secrets（CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID）の
ユーザー登録待ち。デプロイ以外のステップが緑なら正常。
`gh secret list` が空かどうかで、まだ未登録かを判定できる。

**Q. Cloudflare の API トークンは1本を使い回せるか**
A. **使い回せない。** 画像生成（imagegen の Workers AI コネクタ）用に発行したトークンでは
Pages デプロイができない。実測値:

| 叩いた先 | Workers AI 権限のトークン |
|---|---|
| `GET /client/v4/user/tokens/verify` | HTTP 200 `success: true` |
| `GET /client/v4/accounts/<id>/pages/projects` | **HTTP 403 Authentication error** |

`verify` が通るのでトークン自体は有効に見えるが、Pages API は権限不足で弾かれる。
**「トークンは有効」を Pages が使える根拠にしないこと。** 切り分けるなら
`pages/projects` を直接叩く。

用途ごとに別トークンを発行する。

| 用途 | 必要な権限（ダッシュボード → カスタムトークンを作成する） |
|---|---|
| 画像生成（imagegen） | アカウント / **Workers AI** / 読み取り |
| Pages デプロイ（CI の Secrets） | アカウント / **Cloudflare Pages** / 編集 |

`CLOUDFLARE_ACCOUNT_ID` は秘密情報ではない公開識別子なので両方で共用してよい。
**トークンの値を Claude セッションが `gh secret set` に投入するのは禁止**（認証情報の
取り扱いとして、調整役を含むどのセッションでも行わない）。登録はユーザーが実施する。

**Q. kabu の取得を CI に戻したい / 取得が動いていない**
A. kabutan は GitHub Actions の IP を 405 でブロックする。**CI からの取得に戻さない**。
取得はこのPCのタスク `kabu-daily-fetch`（平日16:10、projects/kabu-agari-ranking/run-daily.ps1）。
ログは同ディレクトリの run-daily.log。

**Q. youtube のテストが CI に無い**
A. **2026-09-01 に復活済み**（`youtube-tests.yml`、590件が ubuntu で緑・約1分）。
「マシン依存」の実体は**日本語フォント1つだけ**だった。VOICEVOX も ffmpeg も
テストは差し替えで動くので要らない。CI では `fonts-noto-cjk` を apt で入れている。
フォントのファイル名と置き場所は版ごとに変わるので、`config.FONT_CANDIDATES` で
当たらなければ `/usr/share/fonts` を舐めて探す（`config._font_in_system`）。

**Q. kabutan の解析を直したい**
A. 実体は `libs/kabutan`（kabu と qgt が共用）。公開名と出力列は両PJTのテストが
前提にしているので、変えるときは両方のテストを回す。

**Q. 他セッションの worktree・ブランチ・未コミットに遭遇した**
A. 触らない。報告も不要（作業中が正常）。自分の worktree で作業を続ける。

**Q. `git worktree remove` が「Permission denied」で失敗する**
A. Windows でディレクトリにハンドルが残っていると起きる。多くの場合**登録解除だけは完了していて、
空ディレクトリが残る**状態になる。`git worktree list` に出なくなっていれば、残ったディレクトリを
`rmdir <path>` で消せば整合が取れる（消えない場合はそのパスを cwd にしているシェルやエディタを
閉じてから再実行）。`git worktree prune` は登録が既に消えているため効かない。
ブランチ削除は別途 `git branch -D claude/<topic>` が要る。

**Q. projects/ai-blog が無い**
A. 2026-09-01 にユーザー判断でクローズした（テスト・CI・依存固定なしの最薄PJTで、投資判断の結果）。
書きかけ（generator.py 等）は git 履歴に残っている。復活させる場合:
`git log --oneline -- projects/ai-blog` で最終コミットを見つけ、`git checkout <sha> -- projects/ai-blog`。
**Q. master に追従したい / ブランチが遅れている（統合済みPJTを触っている場合）**
A. **`git rebase` を使わない。`git merge origin/master` で追従する。**
`projects/<pjt>` の多くは旧リポジトリを subtree merge（`merge -s ours` + `read-tree --prefix`）
で取り込んだもので、履歴には**元リポジトリのルート直下パスのままのコミット**が含まれている。
rebase はそれを現在のブランチ上に再生しようとするため、`projects/<pjt>/` 配下ではなく
リポジトリ直下にファイルを作ろうとして衝突する（2026-09-01、gemini-api 取り込み時に発生）。
衝突を手で潰しても履歴が平坦化されて取り込み構造が壊れるので、`git rebase --abort` して
merge に切り替えるのが正しい。新規追加した PJT でも、取り込みコミットを含むブランチは同じ。

**Q. growth を手元で回したい / 件数が他セッションの報告と合わない**
A. `growth run` の `--workspace` には **`growth fetch` で取得した実クローンを渡す**。
作業ツリーを渡すと、gitignore 済みのローカルファイルや他セッションの未コミット物まで
観測して誤検知が出る（実例: `projects/gemini-api/.env` は gitignore 済みで git 追跡も
履歴も無いのに、作業ツリー観測では `[critical] .env がリポジトリに入ってしまっている`
と判定された）。週次 Actions と同条件のクリーンクローンが正。

```
py -m growth fetch --workspace <scratch>/growth-ws
py -m growth run   --workspace <scratch>/growth-ws
```

`dismiss` は**誤検知・恒久的に対象外のものにだけ**使う。既に直って自動解決した項目に
かけると、恒久抑止だけが残って将来の退行を検出できなくなる。

**Q. 旧リポジトリはいつ消える?**
A. 消さずアーカイブ（読み取り専用化）する。時期は全セッションの移住完了をユーザーが
確認してから。ai-lab は imagegen 合流後、kabu は日次パイプラインの完走確認後。

## Dart / Flutter のリファクタで踏んだ罠（2026-09-01 実測）

game_state.dart(4733行)を part + extension で6分割したときに実際に出たもの。
同種の作業では最初に読むこと。

**flutter analyze の緑を安全網に数えない。テストのコンパイルを正とする。**
static を未修飾のまま解析したとき `No issues found` を返したが、
`flutter test` のコンパイルは10件以上のエラーで落ちた。実行時間が通常19秒に対し
9.5秒だったので解析サーバーのキャッシュと思われる。この分割作業で見つかった
不備5件は、すべて analyze ではなくテストのコンパイルが検出した。
通過条件は `flutter test` に置く。

**1つのクラスは複数ファイルに分割できない。**`part` はライブラリを分ける仕組みで、
クラス本体は分けられない。`extension Xxx on GameState` を part ファイルに置いて
メソッドを移す形になる。private(`_`)は Dart ではライブラリ単位なので、
part 間では素通しで触れる。

**移動すると参照の解決規則が変わる。4種類ある。**

- `notifyListeners()` は `@protected` かつ `@visibleForTesting`。extension から
  直接呼ぶと analyze が赤になる。クラス本体に `void _notify() => notifyListeners();`
  を1つ置いて経由させる。
- クラス直下の `static` への**無修飾参照**は解決されない。`GameState.xxx` と書く。
- 文字列補間の `$staticName` も同じ。`${GameState.staticName}` に直す。
- extension は**インスタンスフィールドを宣言できない**。フィールドと static 宣言は
  本体に残すしかない。

**自動置換スクリプトで区画を行番号で指定しない。**移動のたびに行番号がずれる。
しかも**ずれてもテストは通ってしまう**ため、意図と違うグルーピングに気付けない。
実際 `buyPlayer` が取り残されたまま無関係の領域が混入したが、453件は全部緑だった。
メンバー名から宣言行を毎回引き直すこと。

**Python の `\w` は Unicode 対応。**`$continentalTieWinPrize万円` の「万」が
単語文字と判定され、`(?![\w])` の否定先読みが成立せず置換が効かなかった。
日英混在のコードベースで識別子を置換するときは `[A-Za-z0-9_]` を明示する。

**ブロックの先頭は宣言行とは限らない。**`///` だけでなく `//` のセクション見出しも
飛ばさないと、直後のフィールドや static を「移せる」と誤判定する。

**Q. Chrome 操作（ai-lab の control / romano-latest）が接続でタイムアウトする**
A. `connect_over_cdp: Timeout ... exceeded` が出るのに、
`curl http://127.0.0.1:9222/json/version` は応答し `/json/list` でタブも取れる、
という状態になることがある（2026-09-02 に発生）。ブラウザ内部の状態が原因で、
新規に立てた Chrome では起きない。**デバッグ用の Chrome を再起動すれば直る。
プロファイルは残るのでログイン状態も維持される。**

普段使いの Chrome を巻き込まないよう、**PID で特定して落とす**こと
（`Get-Process chrome` は通常の Chrome も含む。実測で34プロセスあった）。

```powershell
# 1. デバッグ用の親プロセスだけを探す
Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" |
  Where-Object { $_.CommandLine -like '*remote-debugging-port=9222*' } |
  Select-Object ProcessId, CommandLine
# 2. --remote-debugging-port を持つ親（--type= が付いていないもの）を止める
Stop-Process -Id <親のPID>
# 3. 立て直す
powershell -ExecutionPolicy Bypass -File platform/ai-lab/scripts/start-chrome-debug.ps1
```

**Q. X（Twitter）の取得が1アカウント5件で頭打ちになる**
A. 未ログイン。ログイン済みプロファイルなら20件以上読める（実測）。
ログイン操作は利用者にしてもらう（スキルの決まり）。`x.com/login` を開くところまで:

```bash
curl -s -X PUT "http://127.0.0.1:9222/json/new?https://x.com/login"
```

ログインは**永続プロファイル側（9222、`%LOCALAPPDATA%` 直下の `ai-lab/chrome-debug-profile`）**で
行うこと。一時プロファイルで立てた Chrome に入れても、消えると失われる。

## 調整役への連絡方法

```
ListAgents で docs/coordinator.txt のセッション名を確認
→ SendMessage({to: "<その名前>", message: "<質問>"})
```

質問には「どの worktree / ブランチで」「何をしようとして」「何に詰まったか」を含める。
