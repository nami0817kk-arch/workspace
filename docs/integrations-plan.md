# 外部サイト連携プラン

## 進捗

| Phase | 状態 |
|---|---|
| 0. 基盤（`core/` + `connectors/` + `ailab connectors` / `doctor`） | **完了** |
| 2. 出力先（GitHub） | **完了**（`ailab publish`。Slack / Discord は当面不要と判断） |
| 1. 取得先追加（Iconify / Unsplash / Pexels） | **完了** |
| 生成モデル追加（Replicate / Hugging Face） | **完了** |
| 3. 情報収集（RSS / GitHub / Qiita） | **完了** |
| 4. パイプライン（YAMLレシピ） | **完了** |
| 5. MCP化 | **完了** |

実装の使い方と新しい連携先の足し方は [connectors.md](connectors.md)。

---

`ailab` を「画像生成＋フリー素材取得ツール」から、**外部サービス連携の共通基盤**へ広げるための計画。
出発点（v0.1）では `imagegen/`（生成API 4種）と `illust/`（素材サイト 3種）が別々の構造を持っていたが、
どちらも「アダプタ＋APIキー有無の判定＋共通の戻り値型＋CLIサブコマンド」という同じ形をしていた。
これを1つの仕組みに統合し（Phase 0 で実施済み）、その上に連携先を足していく。

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

実装済みの構成（Phase 0 の結果）。

```
src/ailab/
  core/
    connector.py     # Connector 基底クラス、AuthSpec、能力プロトコル
    registry.py      # 名前 → コネクタの登録簿。CLI はここだけを見る
    http.py          # 再試行・レート制限・エラー言い換え付きの通信
    cache.py         # 検索結果のディスクキャッシュ
    errors.py        # AuthError / RateLimitError / NotFoundError / NetworkError
    types.py         # Asset / GeneratedImage / PublishResult
  connectors/
    images_openai.py  images_gemini.py  images_stability.py  images_local.py
    assets_openverse.py  assets_wikimedia.py  assets_pixabay.py
    publish_github.py
    （今後）assets_iconify.py  assets_unsplash.py  feed_rss.py ...
  assets.py          # 素材のダウンロードとクレジット出力
  imagegen.py        # 後方互換シム（ailab.imagegen.generate は今も動く）
  illust.py          # 後方互換シム
  cli.py
  （今後）recipes/ … YAMLパイプライン、mcp_server.py … MCPサーバ化
```

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
| **Iconify** ✅ | 不要 | アイコン20万点をSVGで直接取得。資料作りに即効性がある | アイコンセットごとにライセンスが違う（`license` 欄に入れている） |
| **Unsplash** ✅ | 無料キー | 高品質写真 | ダウンロード計測エンドポイントの呼び出しを `notify_download` で自動実行 |
| **Pexels** ✅ | 無料キー | 写真・動画 | クレジット推奨 |
| **Google Fonts** | 不要 | フォント取得（バナー生成の品質が上がる） | OFL等の同梱条件 |
| **OpenMoji / Noto Emoji** | 不要 | 絵文字SVG。GitHub raw から取得 | CC BY-SA（OpenMoji） |

### B. 画像生成（既存の延長）

| 連携先 | 認証 | 価値 |
|---|---|---|
| **Replicate** ✅ | APIキー | SDXL/Flux等をモデル差し替えで試せる。ラボ用途に合う |
| **Hugging Face Inference** ✅ | APIキー | 無料枠で試作可能 |

### C. 出力先（WRITE・ここから価値が跳ねる）

| 連携先 | 認証 | 実装コスト | 備考 |
|---|---|---|---|
| **GitHub** | PAT | 小 | **実装済み**。生成物をリポジトリへコミット（`ailab publish`） |
| **Discord Webhook** | URLのみ | 小 | 最も簡単。必要になったら |
| **Slack** | Webhook（投稿のみ）/ Bot token（ファイル添付） | 小〜中 | 画像添付はBot tokenが要る |
| **Notion** | Integration Token | 中 | ページ作成＋画像は外部URLが要る（Notionは直接アップロード不可） |
| **Google Drive** | OAuth2 | 大 | 認可フローが必要。優先度は下げる |
| **S3 / Cloudflare R2** | キー | 中 | 生成物の公開URL化。Notion連携の前提にもなる |

### D. 情報収集（READ）

RSS/Atom（キー不要）✅、GitHub リリース ✅、Qiita ✅、（今後）Zenn、arXiv、Hacker News。
「調べる→まとめる→画像を作る→投稿する」の**入口**。GitHub は送信と同じコネクタが
両方の能力を持つ形にした。

## 3. フェーズ計画

| Phase | 内容 | 完了条件 | 目安 |
|---|---|---|---|
| **0. 基盤** ✅ | `core/` 新設、既存7コネクタを移行、`ailab connectors` / `ailab doctor` 追加 | 完了。契約テストで新コネクタの実装漏れも検出する | 完了 |
| **2. 出力先** ✅ | GitHub（`ailab publish`、既定ドライラン） | 完了。Slack / Discord は要望が出たら追加 | 完了 |
| **1. 取得先追加** ✅ | Iconify（キー不要）、Unsplash、Pexels | 完了。`ailab search "cat"` が6サイト横断 | 完了 |
| **生成モデル追加** ✅ | Replicate / Hugging Face | 完了。`ailab gen --provider replicate --model owner/name` | 完了 |
| **3. 情報収集** ✅ | RSS / Atom、GitHub リリース、Qiita | 完了。`ailab feed "対象" --source rss\|github\|qiita` | 完了 |
| **4. パイプライン** ✅ | YAMLレシピ。`ailab run <レシピ>` | 完了。[recipes.md](recipes.md) |
| **5. MCP化** ✅ | `ailab mcp`（stdio / JSON-RPC、依存追加なし） | 完了。[mcp.md](mcp.md) |

Phase 0 と 2 は完了。残りは基盤の上に1コネクタ50〜80行を足すだけで済む。

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

計画した Phase 0〜5 は完了。15コネクタが同じ基盤に乗り、レシピと MCP から
同じ能力を呼べる状態になった。ここから先は「必要になったら足す」段階で、
候補は次のとおり。

- **送信先**: Slack / Discord（Webhookなので各50行程度）、S3 / R2（公開URL化）、Notion
- **取得先**: Zenn、arXiv、Hacker News、Google Fonts
- **運用**: `ailab usage`（生成APIの利用量と概算コスト）、レシピの定期実行
- **OAuth**: Google Drive など。認可フローが要るので基盤に auth.py を足すところから

新しい連携先は1つ50〜80行、CLI と MCP の両方に自動で現れる。
