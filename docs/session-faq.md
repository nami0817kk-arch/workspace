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

**Q. master に追従したい / ブランチが遅れている（統合済みPJTを触っている場合）**
A. **`git rebase` を使わない。`git merge origin/master` で追従する。**
`projects/<pjt>` の多くは旧リポジトリを subtree merge（`merge -s ours` + `read-tree --prefix`）
で取り込んだもので、履歴には**元リポジトリのルート直下パスのままのコミット**が含まれている。
rebase はそれを現在のブランチ上に再生しようとするため、`projects/<pjt>/` 配下ではなく
リポジトリ直下にファイルを作ろうとして衝突する（2026-09-01、gemini-api 取り込み時に発生）。
衝突を手で潰しても履歴が平坦化されて取り込み構造が壊れるので、`git rebase --abort` して
merge に切り替えるのが正しい。新規追加した PJT でも、取り込みコミットを含むブランチは同じ。

**Q. 旧リポジトリはいつ消える?**
A. 消さずアーカイブ（読み取り専用化）する。時期は全セッションの移住完了をユーザーが
確認してから。ai-lab は imagegen 合流後、kabu は日次パイプラインの完走確認後。

## 調整役への連絡方法

```
ListAgents で docs/coordinator.txt のセッション名を確認
→ SendMessage({to: "<その名前>", message: "<質問>"})
```

質問には「どの worktree / ブランチで」「何をしようとして」「何に詰まったか」を含める。
