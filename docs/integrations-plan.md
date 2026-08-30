# 外部サイト連携プラン

`ailab` を「画像生成＋フリー素材取得ツール」から、**外部サービス連携の共通基盤**へ広げるための計画。
現状（v0.1）は `imagegen/`（生成API 4種）と `illust/`（素材サイト 3種）が別々の構造を持っているが、
どちらも「アダプタ＋APIキー有無の判定＋共通の戻り値型＋CLIサブコマンド」という同じ形をしている。
まずこれを1つの仕組みに統合し、その上に連携先を足していく。

## 0. 方針：何を自前実装し、何をMCPに任せるか

外部連携には2つの経路があり、**用途で使い分ける**。両方作らない。

| | MCPコネクタ（Claudeに接続） | ailab の自前コネクタ（Python） |
|---|---|---|
| 向いている用途 | 対話中の1回きりの操作。「このメールを探して」「Notionに書いて」 | 定型・バッチ・再現性が要る処理。「毎回この手順で素材を集めて加工して投稿」 |
| 認証 | Claude側が管理（OAuth込み） | 自分で `.env` / トークン管理 |
| 実装コスト | ほぼゼロ（既存サーバを繋ぐだけ） | 中〜高 |
| 例 | Gmail、GitHub、Notion、Slack、Google Drive | 画像生成API、素材サイト、Webhook投稿、RSS |

**判断基準**: 公式MCPサーバがあり、対話的に使うだけなら MCP を繋ぐ。
`ailab` に実装するのは「**スクリプトから何度も同じ手順で叩きたいもの**」と
「MCPが無いもの」に限る。この線引きを守らないと、同じ機能が二重にできて壊れる。

## 1. 基盤（Phase 0）

### ディレクトリ構成

```
src/ailab/
  core/
    connector.py     # Connector 基底クラスと能力プロトコル
    registry.py      # 名前 → コネクタの登録簿。CLI/MCPはここだけを見る
    auth.py          # APIキー / Bearer / OAuth2 トークンの取り回し
    http.py          # 再試行・レート制限・キャッシュ付きセッション（現 http.py を拡張）
    errors.py        # AuthError / RateLimitError / NotFoundError / NetworkError
    types.py         # Asset / GeneratedImage / PublishResult / FeedItem
  connectors/
    images_openai.py  images_gemini.py  images_stability.py  images_local.py
    assets_openverse.py  assets_wikimedia.py  assets_pixabay.py ...
    publish_slack.py  publish_discord.py  publish_notion.py ...
    feed_rss.py  feed_github.py ...
  recipes/           # YAMLパイプライン（Phase 4）
  mcp_server.py      # ailab 自体をMCPサーバ化（Phase 5）
  cli.py
```

既存の `imagegen/` `illust/` は**薄いラッパとして残す**（`ailab.imagegen.generate()` は
そのまま動く）。移行で既存テスト50件を壊さないことを Phase 0 の完了条件にする。

### コネクタの共通契約

```python
class Connector(ABC):
    name: str                 # "unsplash"
    category: str             # "assets" | "images" | "publish" | "feed"
    auth: AuthSpec            # 必要な環境変数、取得先URL、無料枠の説明
    terms_url: str            # 利用規約（クレジット義務などを status に出す）
    rate_limit: RateLimit | None

    def is_available(self) -> bool: ...       # キーが揃っているか
    def unavailable_reason(self) -> str: ...  # 揃っていない理由（人が読む用）
    def check(self) -> CheckResult: ...       # 実際に1回叩いて疎通確認（ailab doctor）
```

能力は継承ではなく**プロトコル（duck typing）**で足す。1コネクタが複数持ってよい。

| プロトコル | メソッド | 例 |
|---|---|---|
| `SearchAssets` | `search_assets(query, *, limit) -> list[Asset]` | Openverse, Unsplash, Iconify |
| `GenerateImage` | `generate(prompt, *, size, n) -> list[GeneratedImage]` | OpenAI, Gemini |
| `PublishFile` | `publish(path, *, title, dest) -> PublishResult` | Slack, Drive, GitHub |
| `ReadFeed` | `fetch_items(query, *, limit) -> list[FeedItem]` | RSS, GitHub, Qiita |

CLIは「コネクタ名」ではなく「**能力**」でディスパッチする。
`ailab publish x.png --to slack` は `PublishFile` を持つコネクタだけを候補にする。

### 横断的に基盤へ入れるもの

- **再試行**: 429/5xx は指数バックオフ（`Retry-After` があれば従う）。上限3回。
- **レート制限**: コネクタ宣言のトークンバケット。Unsplash 50req/h のような枠を自動で守る。
- **キャッシュ**: 検索結果を `~/.cache/ailab/` に短期キャッシュ（既定15分、`--no-cache` で無効）。
  同じ検索で無駄にAPI枠を消費しないため。
- **エラーの言い換え**: 401→「キーが違う」、403→「権限/枠」、429→「待って再実行」を日本語で出す。
  現状の「ネットワークエラー: HTTPSConnectionPool(...)」のような生の例外は出さない。
- **秘密情報**: `.env` のみを正とし、OAuthトークンは `~/.ailab/credentials.json`（chmod 600）。
  ログ・エラー・`--json` 出力にキーを絶対に含めない（マスク処理を基盤側で1箇所に置く）。

## 2. 連携先の候補と優先度

「キー不要 > 無料キー > OAuth」の順に着手コストが低い。

### A. 素材の取得（READ・追加が容易）

| 連携先 | 認証 | 価値 | 注意 |
|---|---|---|---|
| **Iconify** | 不要 | アイコン20万点をSVGで直接取得。資料作りに即効性がある | アイコンセットごとにライセンスが違う |
| **Unsplash** | 無料キー | 高品質写真 | クレジット必須、ダウンロード計測エンドポイントの呼び出しが規約上必要 |
| **Pexels** | 無料キー | 写真・動画 | クレジット推奨 |
| **Google Fonts** | 不要 | フォント取得（バナー生成の品質が上がる） | OFL等の同梱条件 |
| **OpenMoji / Noto Emoji** | 不要 | 絵文字SVG。GitHub raw から取得 | CC BY-SA（OpenMoji） |

### B. 画像生成（既存の延長）

| 連携先 | 認証 | 価値 |
|---|---|---|
| **Replicate** | APIキー | SDXL/Flux等をモデル差し替えで試せる。ラボ用途に合う |
| **Hugging Face Inference** | APIキー | 無料枠で試作可能 |

### C. 出力先（WRITE・ここから価値が跳ねる）

| 連携先 | 認証 | 実装コスト | 備考 |
|---|---|---|---|
| **Discord Webhook** | URLのみ | 小 | 最も簡単。動作確認の第一候補 |
| **Slack** | Webhook（投稿のみ）/ Bot token（ファイル添付） | 小〜中 | 画像添付はBot tokenが要る |
| **GitHub** | PAT / 既存MCP | 小 | 生成物をリポジトリへコミット、Releaseへ添付 |
| **Notion** | Integration Token | 中 | ページ作成＋画像は外部URLが要る（Notionは直接アップロード不可） |
| **Google Drive** | OAuth2 | 大 | 認可フローが必要。優先度は下げる |
| **S3 / Cloudflare R2** | キー | 中 | 生成物の公開URL化。Notion連携の前提にもなる |

### D. 情報収集（READ）

RSS/Atom（キー不要）、GitHub（リリース・Issue）、Qiita/Zenn、arXiv、Hacker News。
「調べる→まとめる→画像を作る→投稿する」の**入口**として効く。

## 3. フェーズ計画

| Phase | 内容 | 完了条件 | 目安 |
|---|---|---|---|
| **0. 基盤** | `core/` 新設、既存6コネクタを移行、`ailab connectors` / `ailab doctor` 追加 | 既存テストが全て通る。`ailab doctor` が各サービスの疎通と枠を表示 | 1〜2日 |
| **1. 取得先追加** | Iconify、Unsplash、Pexels | `ailab assets search "cat" --source all` が5サイト横断。ライセンス表記は自動 | 半日 |
| **2. 出力先** | Discord Webhook → Slack → GitHub | `ailab publish output/images/x.png --to slack --channel dev` が通る | 1〜2日 |
| **3. 情報収集** | RSS、GitHub、Qiita | `ailab feed "claude" --source rss,github` | 半日 |
| **4. パイプライン** | YAMLレシピ。`ailab run recipes/weekly-report.yaml` | 「検索→生成→投稿」を1コマンドで再実行できる | 2日 |
| **5. MCP化** | `ailab mcp` でMCPサーバとして起動 | Claude から `ailab` の全コネクタを直接呼べる | 1日 |

Phase 0 と 2 が本体。1・3 は基盤が出来ていれば1コネクタ50行程度で足せる。

### Phase 4 のレシピ例

```yaml
name: 週次まとめ画像
steps:
  - feed:    { source: github, query: "anthropics/claude-code releases", limit: 5 }
  - gen:     { prompt: "{{ steps[0].title }} のアイキャッチ、フラットイラスト", size: 1200x630 }
  - publish: { to: slack, channel: "#dev", text: "今週の更新" }
```

## 4. 守るべきルール（実装前に決めておく）

1. **APIがあるものだけ連携する。** HTMLスクレイピングはしない。規約とrobots.txtで禁じられている
   ことが多く、壊れやすい。いらすとや等はこの方針で対象外（現状の実装と同じ）。
2. **書き込み系は既定でドライラン。** `ailab publish` は `--yes` を付けるまで送信内容を表示するだけ。
   外部への投稿は取り消せないため。
3. **ライセンスと出典は必ず持ち回る。** 取得した素材を投稿するときも、
   クレジットを本文に自動で添える（現行の `CREDITS.md` の仕組みを再利用）。
4. **無料枠を尊重する。** レート制限とキャッシュは基盤側で強制。ループで叩かない。
5. **秘密情報をリポジトリに入れない。** `.env` はコミット禁止（`.gitignore` 済み）。
   CIでは live テストを走らせない。

## 5. テスト方針

- 現行どおり**HTTPは全てモック**（`tests/fakes.py` を流用）。ネットワークなしで全件通る状態を維持。
- **契約テスト**を1本足す: registry の全コネクタに対して「生成できる」「`is_available()` が例外を
  投げない」「`auth` と `terms_url` が埋まっている」をパラメトライズで検証。コネクタ追加時の抜けを防ぐ。
- 実APIを叩くテストは `@pytest.mark.live` を付け、キーがある環境でのみ手動実行（既定でskip）。

## 6. リスクと対策

| リスク | 対策 |
|---|---|
| 連携先を増やすほどAPI仕様変更で壊れる | コネクタは50行以内に保ち、壊れたものは `ailab doctor` で即座に検出できるようにする |
| OAuth（Drive等）の実装が重い | Phase後半に回す。当面はキー1本で済むサービスを優先 |
| APIキーの管理が煩雑 | `ailab doctor` が「どのキーが無くて、どこで取れるか」をURL付きで案内 |
| 課金APIの使いすぎ | Phase 4以降で `ailab usage` に生成回数と概算コストを記録 |
| Claude Code Web環境から外部へ出られない | この環境は組織のegressポリシーで多くのホストが403になる。実行はローカル前提とし、Web側では実通信テストをしない |

なお、ここに書いた各APIの仕様（エンドポイント・無料枠・規約）は**実装時に必ず一次情報で確認する**。
外部サービスの仕様は変わる。

## 7. 次の一手

Phase 0（基盤）と Phase 2 の最初の1つ（Discord か Slack）を同時に作ると、
「基盤が実用に耐えるか」を出力先1つで検証できる。連携先の名前を先に増やすより、
**1本の縦の流れ（取得 → 生成 → 投稿）を通す**ほうが早く価値が出る。
