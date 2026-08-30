# コネクタ基盤と外部サービス連携

`ailab` の外部サービス連携は、すべて**コネクタ**という同じ形をしている。
画像生成APIも素材サイトも送信先も区別なく `src/ailab/connectors/` に1ファイルずつ置き、
CLI は登録簿（registry）だけを見る。

計画の全体像は [integrations-plan.md](integrations-plan.md)。

## 使う側

```bash
ailab connectors          # 連携先の一覧と、必要な環境変数が揃っているか
ailab connectors --json   # スクリプト用
ailab doctor              # 実際に接続して確認（キー未設定は -- で未確認扱い）
ailab doctor github       # 1つだけ確認
```

```
画像生成:
  NG  openai     環境変数 OPENAI_API_KEY が未設定です（取得: https://platform.openai.com/api-keys）
  OK  local      APIキー不要のローカル生成（プレースホルダ画像）

素材取得:
  OK  openverse  CC素材の横断検索（キー不要）

送信先:
  OK  github     生成物をリポジトリへコミットする
```

### 情報を集める

```bash
ailab feed https://example.com/feed.xml --source rss     # RSS / Atom
ailab feed owner/name --source github                    # リリース一覧
ailab feed "claude code" --source qiita                  # Qiita 記事検索
ailab feed owner/name --source github --json             # 他のスクリプトへ渡す
```

対象の指定方法が取得元ごとに違う（URL / owner/name / キーワード）ので、`--source` は必須。

### GitHub へ送る

```bash
# 既定はドライラン。何が送られるかだけ表示する
ailab publish output/images/banner.png --repo owner/name --path docs/img/banner.png

# 実際にコミットする
ailab publish output/images/banner.png --repo owner/name --path docs/img/banner.png --yes \
  -m "バナーを追加"
```

- リポジトリは `--repo`、省略時は `.env` の `AILAB_GITHUB_REPO`。
- ブランチは `--branch`、省略時はリポジトリの既定ブランチ。
- 同じパスに既にファイルがあれば上書き（内部で sha を取得して更新する）。
- 25MB を超えるファイルは弾く（Contents API に向かないため）。
- 必要な権限は contents:write。`GITHUB_TOKEN` か `GH_TOKEN` を読む。

## 作る側：新しい連携先の足し方

1. `src/ailab/connectors/<category>_<name>.py` を作る。
2. `Connector` を継承し、`@register` を付ける。
3. 能力に応じたメソッドを実装する。

| 能力 | 実装するメソッド | CLI |
|---|---|---|
| 素材検索 | `search_assets(query, *, limit) -> list[Asset]` | `ailab search` / `fetch` |
| 画像生成 | `generate(prompt, *, size, n, model) -> list[GeneratedImage]` | `ailab gen` |
| 送信 | `publish(path, *, dry_run, **options) -> PublishResult` | `ailab publish` |
| 情報収集 | `fetch_items(query, *, limit) -> list[FeedItem]` | `ailab feed` |

継承ではなくメソッドの有無（プロトコル）で判定するので、1つのコネクタが複数の能力を
持ってもよい。実例が `github` で、`publish`（コミット）と `fetch_items`（リリース取得）の
両方を持ち、`ailab connectors` では両方の見出しに現れる。

```python
from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.registry import register
from ..core.types import Asset


@register
class ExampleAssets(Connector):
    name = "example"
    category = "assets"                 # images / assets / publish / feed
    summary = "サンプル素材サイト"
    priority = 40                       # 小さいほど auto / all で先に使われる
    auth = AuthSpec(env=("EXAMPLE_API_KEY",), signup_url="https://example.com/api")
    terms_url = "https://example.com/terms"
    license_note = "CC0"
    rate_limit = RateLimit(requests=100, per_seconds=3600)

    def default_headers(self):
        key = self.api_key()
        return {"Authorization": f"Bearer {key}"} if key else {}

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        self.get_json("https://example.com/api/ping", use_cache=False)
        return CheckResult(self.name, ok=True, detail="接続できました")

    def search_assets(self, query: str, *, limit: int = 10) -> list[Asset]:
        body = self.get_json("https://example.com/api/search", params={"q": query})
        return [Asset(source=self.name, title=x["title"], image_url=x["url"]) for x in body["items"]]
```

4. `src/ailab/connectors/__init__.py` に import を1行足す。CLI 側の変更は不要
   （`--source` や `--to` の選択肢は registry から自動で作られる）。
5. テストを書く。`Connector(session=FakeSession([...]))` でHTTPを差し替えられるので、
   実際の通信は不要。`tests/test_registry.py` の契約テストが自動で新コネクタも検査する。

## 基盤が面倒を見ること

コネクタ側で書かなくてよい。

| 機能 | 場所 | 内容 |
|---|---|---|
| 再試行 | `core/http.py` | 429/5xx を指数バックオフで最大3回。`Retry-After` に従う |
| レート制限 | `core/http.py` | `rate_limit` 宣言に基づくトークンバケット。枠内はバースト可 |
| キャッシュ | `core/cache.py` | `get_json` の結果を既定15分キャッシュ（`--no-cache` で無効） |
| エラーの言い換え | `core/http.py` | 401/403→AuthError、404→NotFoundError、429→RateLimitError |
| キーの扱い | `core/connector.py` | `AuthSpec` が未設定の変数名と取得先URLを案内する |

## 決めごと

- **APIがあるものだけ連携する。** HTMLスクレイピングはしない。
- **書き込み系は既定でドライラン。** `--yes` を付けるまで送信しない。
- **ライセンスと出典は必ず持ち回る。** 素材は `CREDITS.md` / `credits.json` に記録する。
- **キーはログに出さない。** `--json` 出力にも含めない。
