---
name: ios-app-release
description: workspace の Flutter アプリを App Store に初めて出す（新しいアプリの初回リリース）一連の流れ。Apple・AdMob・GitHub の画面のどこを押すか、提出フォームの答え、つまずき所まで。「リリースしたい」「App Store に出す」「TestFlight に上げる」「審査に出す」「提出の手順」と言われたとき、新しいアプリで課金や広告を入れて出すときに使う。2026-09-28 に護送ボートを出した流れが元（サカマネは既に公開済みで、アカウントまわりは使い回した）。
---

# iOS アプリの初回リリース（新しいアプリを App Store に出す）

2026-09-28 に護送ボート（projects/goso-boat）を審査提出したときの流れ。
**手本の実装は projects/goso-boat**。ワークフロー・生成器・法務ページは、そこから写して名前を替える。

## 最初に決めておくこと

- 報告・質問は日本語。未決は1つずつ聞く。お金がかかる可能性があれば必ず聞く
- **鍵・パスワード・アカウント作成・Apple/Google の画面操作はユーザーがやる**。私は手順を1クリック単位で案内する
- **公開（ページを出す・TestFlight へ上げる・提出）は、ユーザーの OK を取ってから**
- 名義は「つるはし社」。本名・nami・0817 を公開する文面に出さない

## 使い回せるもの（サカマネで登録済み。作り直さない）

| もの | 置き場所 |
|---|---|
| Apple Developer の契約・有料App契約・銀行口座・税 | 済み。課金アイテムはすぐ作れる |
| 配信用証明書（Apple Distribution） | Secrets `IOS_DIST_CERT_BASE64` / `IOS_DIST_CERT_PASSWORD` |
| チームID | `IOS_TEAM_ID` |
| App Store Connect API キー | `APPSTORE_API_KEY_ID` / `APPSTORE_API_ISSUER_ID` / `APPSTORE_API_KEY_BASE64` |
| AdMob アカウント（パブリッシャー `pub-6409014819339195`） | 同じアカウントにアプリを足すだけ。app-ads.txt の中身も同じ |
| Cloudflare Pages | `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` |

アプリごとに新しく要る Secrets は4つ: `<APP>_IOS_PROVISIONING_PROFILE_BASE64`、`<APP>_ADMOB_APP_ID_IOS`、
`<APP>_ADMOB_REWARDED_IOS`、`<APP>_ADMOB_INTERSTITIAL_IOS`（使う広告の種類に合わせる）。

## 全体の順番

| # | やること | 誰が |
|---|---|---|
| A-1 | App ID を登録 | ユーザー |
| A-2 | プロビジョニングプロファイルを作ってダウンロード | ユーザー |
| A-3 | App Store Connect にアプリを作る | ユーザー |
| A-4 | 課金アイテムを作る | ユーザー |
| A-5 | AdMob にアプリと広告ユニットを作る | ユーザー |
| A-6 | GitHub Secrets を登録 | ユーザー（頼まれたら私が `gh secret set`） |
| B | 法務ページ・app-ads.txt を公開 | 私（OK を取ってから） |
| C | ビルドして TestFlight へ | 私 |
| D | 自分の iPhone で試す | ユーザー |
| E | 掲載画像を生成器で作る | 私 |
| F | 年齢・配信国・ATT を決める | ユーザー |
| G | App Store Connect を埋めて提出 | ユーザー（貼る文面は私がチャットに出す） |
| H | 審査通過後にリリース、AdMob とストアを紐づけ | ユーザー＋私 |

## A. ユーザーの作業（1クリック単位で案内する）

### A-1. App ID
https://developer.apple.com/account/resources/identifiers/list → 「Identifiers」横の **青い ＋** → **App IDs** → Continue →
**App** → Continue → Description、Bundle ID は **Explicit** で `com.namiki.<appName>` → Capabilities は触らない → Continue → **Register**

### A-2. プロファイル
https://developer.apple.com/account/resources/profiles/list → **青い ＋** → Distribution の **App Store Connect** → Continue →
App ID を選ぶ → 証明書は**サカマネと同じもの（一覧に1つ）** → 名前 `<App> AppStore` → **Generate** → **Download**（ダウンロードフォルダに入る）

### A-3. App Store Connect にアプリ
https://appstoreconnect.apple.com/apps → 「アプリ」横の **青い ＋** → **新規App** → iOS、名前、プライマリ言語 **日本語**、
バンドルID、SKU、**フルアクセス** → 作成

### A-4. 課金アイテム
アプリ → 左「収益化」→ **App内課金** → **＋** → 非消耗型、参照名、**製品ID（コードと1文字も違えない）** → 作成 → 次を埋めて保存:
- 価格、**配信状況（国）**、App Store のローカリゼーション（日本語・英語の表示名と説明）
- **審査に関する情報**（ページのいちばん下）: スクリーンショット（値段のボタンが写った画面。生成器で作る）と審査メモ
- 途中の **1024×1024 の画像欄は「App Store のプロモーション」用で任意**。審査用の欄と取り違えやすい
- 参照名・製品IDは利用者に見えない（英語でよい）。利用者に見えるのは表示名

### A-5. AdMob
https://apps.admob.com → 左 **アプリ** → **アプリを追加** → iOS →「ストアに掲載されていますか」**いいえ** → 名前 → 追加 →
**広告ユニットを追加**（リワード／インタースティシャル）。作成画面の答え:
- **「別のメディエーション プラットフォームでのリアルタイム入札に使用」のチェックはオフ**（オンにすると AdMob の広告が出ない）
- リワードの報酬: 量 `1`、アイテム名は何でもよい（アプリは見終えたかだけ見る）
- 広告の種類は全部オン、サーバーサイドの検証オフ、フリークエンシー キャップ無効
- eCPM 下限: **Google による最適化 →「すべての価格」**（広告が来ないとヒントが出ない作りなので、出せることを優先）
- 「アプリの設定」でアプリID（`~` 区切り）、各ユニットID（`/` 区切り）を控える。ブロックのコントロールで広告の上限 G
- ユーザーが貼ってきた ID は、形（`ca-app-pub-16桁~10桁` / `ca-app-pub-16桁/10桁`）と発行元の16桁がそろっているかを確かめて返す

### A-6. Secrets
https://github.com/nami0817kk-arch/workspace/settings/secrets/actions → **New repository secret**。
- 登録後は `gh secret list --repo nami0817kk-arch/workspace | grep <APP>` で名前がそろったか確かめる（中身は見えない）
- **プロファイルの Base64 は Git Bash で作る**: `base64 -w0 "$USERPROFILE/Downloads/<file>.mobileprovision" | gh secret set NAME --repo ...`
  - **PowerShell のパイプで渡すと末尾に CRLF が付き、Mac の `base64 -D` で落ちる**（2026-09-28 に1回落ちた）
  - ユーザーが PowerShell にコマンドプロンプト用の書き方を貼って構文エラーになった。こちらで実行するか、クリップボードに入れる
  - Name 欄にクリップボードの長い文字列を貼る事故があった。名前を先に入れてから中身をクリップボードへ

## B. 法務ページと app-ads.txt（私。公開の OK が要る）

- `projects/<app>/legal/{privacy,terms,support}.html`（日英1ページ）、`site/index.html`、`site/app-ads.txt`
- `.github/workflows/<app>-site.yml` で Cloudflare Pages `<app>` プロジェクトへ（goso-boat-site.yml を写す）。
  最後に `https://<app>.pages.dev/privacy.html` などを curl で確かめる
- privacy には: AdMob が集める情報（IP・端末ID・広告の表示と操作・性能とクラッシュ）、ATT を使わず IDFA を渡さない、
  My Ad Center、13歳未満向けではない、返金で広告が戻る、Google が同等の保護・削除方法。support に「不適切な広告の報告」
- アプリの設定画面からプライバシーポリシーとサポート（広告の報告）を開けること（Apple 5.1.1・2.5.18）

## C. ビルドして TestFlight

```bash
gh workflow run <app>-ios-release.yml --repo nami0817kk-arch/workspace --ref master -f upload_to_testflight=true
```
- リリースの CI は Secrets の有無・テスト用IDでない・形・発行元の一致・Info.plist の置換・法務ページが開けるかを確かめてから作る
- 成功は `UPLOAD SUCCEEDED with no errors` で確かめる。ビルド番号は `pubspec.yaml` の `+N`（同じ番号は二度上げられない）

## D. ユーザーが iPhone で試す

App Store Connect → TestFlight → 内部テストの **＋** → グループ → テスターに自分 → iPhone の TestFlight アプリからインストール。
確かめる: 購入（Sandbox で無料）、購入後の動き、削除して入れ直すと広告なしに戻る、全画面広告・動画広告。
- **公開前は本番の広告が届かないのが普通**（新しい広告ユニット・ストア未掲載の配信制限）。
  「動画の準備ができていません」ならアプリは正常。審査メモにその旨と「Remove Ads を Sandbox で買えば試せる」を書く
- 自分の端末で本番の広告を押させない（AdMob 規約違反）

## E. 掲載画像（生成器で作る。手で撮らない）

`projects/<app>/tool/screenshots/capture_test.dart`（goso-boat のものを写す）を worktree で
`flutter test tool/screenshots/capture_test.dart --update-goldens`（subst したドライブから）。
- iPhone 6.9インチ 430×932@3（1290×2796）と **iPad 13インチ 1032×1376@2（2064×2752）は必須**、日英
- 生成器の中で検査: 値段が写っていない、読み込み中の丸が無い、文字が3つ以上、例外が無い
- **撮ったら必ず Read で1枚ずつ見る**。見つかった失敗: アニメーションは状態が変わった次のコマから動く（`pump()` を1回挟む）、
  舟の上の人をタップすると降りる（手前の岸の人に絞る）、面の名前の帯が残る、脱走の札に実績が出る、自動スクロールで先頭が切れる
- 課金アイテムの審査用に、値段のボタンが写った1枚を別に作る
- できたらダウンロードフォルダに端末・言語ごとのフォルダで置く（`<アプリ名>_掲載画像\1_iPhone_日本語` など）

## F. ユーザーに決めてもらうこと（おすすめ付きで1つずつ）

- 年齢区分（暴力の描写が無ければ 4+）
- 配信国: **EU 27か国と中国本土を外す**（EU はデジタルサービス法で住所公開が要る。中国本土はゲームの許可番号が要る）。
  英国・スイス・ノルウェーは残す（UMP 無しだと広告が絞られるだけで違反ではない）
- ATT は出さない（サカマネと同じ）

## G. App Store Connect を埋めて提出（貼る文面はチャットにコードブロックで出す）

**ユーザーは文面ファイルより「ここで見たい」**。欄ごとにコードブロックで出す。

1. **App 情報**: 名前・サブタイトル（日本語と「言語を追加」で英語）、カテゴリ、年齢制限（広告は「はい」）
   - **コンテンツ配信権: 「はい、サードパーティ製のコンテンツを含み、権利を保有」**（広告と OFL フォントがあるため）
   - **EULA: Apple の標準を全地域に適用**
   - **暗号化の書類: 何も出さない**（Info.plist に `ITSAppUsesNonExemptEncryption=false`。聞かれたら「なし」）
2. **価格および配信状況**: 無料、配信可否の「編集」で EU 27か国と中国本土のチェックを外す
3. **App のプライバシー**: プライバシーポリシー URL。データの収集は **「デバイス ID → サードパーティ広告／関連付けなし／追跡なし」の1行だけ**
   （サカマネで通った答え。「関連付けあり・追跡あり」にしない）→ 右上の **公開**。
   **「ユーザーのプライバシー選択 URL」は任意で空でよい**
4. **iOS App 1.0（バージョンのページ）**: スクショ（iPhone と iPad のタブ、日英）、プロモーションテキスト、概要（説明）、
   キーワード、サポート URL、マーケティング URL（app-ads.txt の置き場所なので空にしない）、ビルド、
   **著作権はページ下の「一般情報」の枠**に `2026 Tsuruhashi-sha`（本名を入れない）、
   App Review に関する情報（サインイン不要、連絡先はサカマネと同じ、メモは英文）、**手動でリリース**
5. **提出**: **課金アイテムはバージョンのページに添付欄が無い**。課金アイテムのページ右上の **審査用に追加** →
   提出の下書き（無ければ新規）→ iOS と版を選ぶ。アプリもバージョンのページの **審査用に追加** で同じ下書きへ。
   下書きに両方が並んだら **審査へ提出**。IDFA は **はい → 「App内で広告を配信する」だけ**

### 「このフィールドには1つ以上の無効な文字が含まれています」

App Store Connect は一部の記号を弾く。**★ で弾かれ、説明文も ■ … ―― • — を外して通した**。
- 日本語の見出しは【】、英語は [ ]、箇条書きは「・」と「-」、区切りは「：」
- どの欄かを聞いてから直す。名前は漢字を弾くことがある（ローマ字）、電話は `+81` の後に数字だけ
- 保存ボタンに赤い「!」が出て赤い欄が見えないときは、言語を英語に切り替えて英語側の欄を見る

## H. 審査のあと

- 1〜3日。「配信準備完了」になったら、バージョンのページの **このバージョンをリリース**（押すまで公開されない）
- 却下されたら文面をもらって直し、返信後に **「審査内容を更新」まで押す**（返信だけでは止まる。記憶 app-review-resubmit）
- 公開後: AdMob でアプリをストアのページと紐づける（広告の配信制限が外れる）、app-ads.txt の確認を待つ
- 公開後の数字は `curl "https://itunes.apple.com/lookup?id=<AppID>&country=jp"` で外から確かめる

## やってはいけないこと（2026-09-28 に踏んだもの）

- **古い画面の手順を言い切らない**。課金アイテムの添付場所を間違えて案内した。自信がなければ Apple の公式ヘルプ
  （developer.apple.com/help/app-store-connect）を WebFetch で確かめてから答える
- メインの作業ツリー（dev/workspace 直下）にファイルを書かない。必ず worktree
- Bash のヒアドキュメントの Python では `\\` が1つ消える。書き換えスクリプトは Write でファイルにして実行、中は `chr(92)`
- 「作ります」と書いたら、書く前に作り始める（掲載画像を「作ります」と言って手を付けていなかった）
