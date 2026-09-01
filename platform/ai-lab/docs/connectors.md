# コネクタ基盤と外部サービス連携

`imagegen` の外部サービス連携は、すべて**コネクタ**という同じ形をしている。
画像生成APIも素材サイトも送信先も区別なく `src/imagegen/connectors/` に1ファイルずつ置き、
CLI は登録簿（registry）だけを見る。

計画の全体像は [integrations-plan.md](integrations-plan.md)。

## 使う側

```bash
imagegen connectors          # 連携先の一覧と、必要な環境変数が揃っているか
imagegen connectors --json   # スクリプト用
imagegen doctor              # 実際に接続して確認（キー未設定は -- で未確認扱い）
imagegen doctor github       # 1つだけ確認
imagegen doctor --json       # スクリプトから使う（失敗があれば終了コード1）
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
imagegen feed https://example.com/feed.xml --source rss     # RSS / Atom
imagegen feed owner/name --source github                    # リリース一覧
imagegen feed "claude code" --source qiita                  # Qiita 記事検索
imagegen feed "リオネル・メッシ" --source wikipedia          # Wikipedia の見出しと導入文
imagegen feed "en:Lionel Messi" --source wikipedia          # 言語を指定する
imagegen feed owner/name --source github --json             # 他のスクリプトへ渡す
```

Wikipedia は既定で日本語版を引く（`IMAGEGEN_WIKIPEDIA_LANG` か `en:` の前置きで変更）。
本文は CC BY-SA なので、引用するときは出典表示が要る。
画像は別サイトなので `--source wikimedia`（Commons）を使う。

対象の指定方法が取得元ごとに違う（URL / owner/name / キーワード）ので、`--source` は必須。

### GitHub へ送る

```bash
# 既定はドライラン。何が送られるかだけ表示する
imagegen publish output/images/banner.png --repo owner/name --path docs/img/banner.png

# 実際にコミットする
imagegen publish output/images/banner.png --repo owner/name --path docs/img/banner.png --yes \
  -m "バナーを追加"
```

- リポジトリは `--repo`、省略時は `.env` の `IMAGEGEN_GITHUB_REPO`。
- ブランチは `--branch`、省略時はリポジトリの既定ブランチ。
- 同じパスに既にファイルがあれば上書き（内部で sha を取得して更新する）。
- 25MB を超えるファイルは弾く（Contents API に向かないため）。
- 必要な権限は contents:write。`GITHUB_TOKEN` か `GH_TOKEN` を読む。

## 作る側：新しい連携先の足し方

1. `src/imagegen/connectors/<category>_<name>.py` を作る。
2. `Connector` を継承し、`@register` を付ける。
3. 能力に応じたメソッドを実装する。

| 能力 | 実装するメソッド | CLI |
|---|---|---|
| 素材検索 | `search_assets(query, *, limit) -> list[Asset]` | `imagegen search` / `fetch` |
| 画像生成 | `generate(prompt, *, size, n, model) -> list[GeneratedImage]` | `imagegen gen` |
| 送信 | `publish(path, *, dry_run, **options) -> PublishResult` | `imagegen publish` |
| 情報収集 | `fetch_items(query, *, limit) -> list[FeedItem]` | `imagegen feed` |

継承ではなくメソッドの有無（プロトコル）で判定するので、1つのコネクタが複数の能力を
持ってもよい。実例が `github` で、`publish`（コミット）と `fetch_items`（リリース取得）の
両方を持ち、`imagegen connectors` では両方の見出しに現れる。

```python
from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.registry import register
from ..core.types import Asset


@register
class ExampleAssets(Connector):
    name = "example"
    category = "assets"                 # images / speech / assets / publish / feed
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

4. `src/imagegen/connectors/__init__.py` に import を1行足す。CLI 側の変更は不要
   （`--source` や `--to` の選択肢は registry から自動で作られる）。
5. テストを書く。`Connector(session=FakeSession([...]))` でHTTPを差し替えられるので、
   実際の通信は不要。`tests/imagegen/test_registry.py` の契約テストが自動で新コネクタも検査する。

## 基盤が面倒を見ること

コネクタ側で書かなくてよい。

| 機能 | 場所 | 内容 |
|---|---|---|
| 再試行 | `src/imagegen/core/http.py` | 429/5xx を指数バックオフで最大3回。`Retry-After` に従う |
| レート制限 | `src/imagegen/core/http.py` | `rate_limit` 宣言に基づくトークンバケット。枠内はバースト可 |
| キャッシュ | `src/imagegen/core/cache.py` | `get_json` の結果を既定15分キャッシュ（`--no-cache` で無効） |
| エラーの言い換え | `src/imagegen/core/http.py` | 401/403→AuthError、404→NotFoundError、429→RateLimitError |
| キーの扱い | `src/imagegen/core/connector.py` | `AuthSpec` が未設定の変数名と取得先URLを案内する |

## 決めごと

- **APIがあるものだけ連携する。** HTMLスクレイピングはしない。
- **書き込み系は既定でドライラン。** `--yes` を付けるまで送信しない。
- **ライセンスと出典は必ず持ち回る。** 素材は `CREDITS.md` / `credits.json` に記録する。
- **キーはログに出さない。** `--json` 出力にも含めない。
