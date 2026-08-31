# CLAUDE.md

このリポジトリ（PJT008 AIラボ）は、独立した試作パッケージを `src/` 以下に並べて置く。
パッケージごとに前提が違うので、触る対象の節を読むこと。

| パッケージ | 内容 |
|---|---|
| `src/ailab/` | 画像生成・フリー素材取得・外部サービス連携の CLI + MCPサーバ |
| `src/moneyloop/` | 有料ニュースレターの収益化パイプライン（原価・粗利まで計算する） |
| `src/adsite/` | 広告収益型ツールサイトのジェネレータ（収益は moneyloop の台帳へ） |
| `src/growth/` | 全プロジェクトを定期点検し、次にやることを提示する成長ループ |
| `src/audiogen/` | BGM / 効果音を手続き的に合成して WAV に書き出すツールキット |

（他の試作を足すときは、この表と節を増やす）

## 共通

```bash
pip install -e ".[dev]"
pytest
python -m ruff check src/ailab tests/ailab
```

- Python 3.11 以上。**実行時の依存は既定でゼロ**。
  moneyloop / growth / audiogen は標準ライブラリだけで動く。
  依存が要るものは extras に切り出してある（`[image]` = ailab、`[llm]` = Claude 呼び出し）。
  定期実行されるものが多く、依存が増えるほど勝手に壊れる確率が上がるため。
- src レイアウト。テストは `pytest`（`pyproject.toml` で `pythonpath` を通してある）。
- **テストはツールごとに `tests/<ツール名>/` に分ける。**
  同名テストモジュールの衝突を避けるためと、`conftest.py` の autouse フィクスチャが
  他のツールのテストへ漏れないようにするため。共有ヘルパ（`tests/helpers.py`、
  `tests/fakes.py`）だけが `tests/` 直下にある。
- テストは**外部通信をしない**。CI（`.github/workflows/tests.yml`）は
  Ubuntu × Python 3.11・3.12 で全体を回し、ailab だけ Windows でも回す。
- APIキーは `.env`（`.gitignore` 済み）。ログにも `--json` 出力にも出さない。
  表示直前に `ailab/core/redact.py` が環境変数の値と突き合わせて伏せる（最後の砦）。
- MCP の `publish_file` はプロジェクト配下のファイルしか送れない。
- Claude Code の web セッションからは多くの外部ホストが egress ポリシーで塞がれる。
  疎通確認が NG でも、手元では通ることがある。
- **web セッションから利用者のPCへは接続できない**（出口は443のHTTPSのみ、宛先も許可リスト制）。
  PC上のファイルやアプリを対象にする作業は、PC側で Claude Code を起動して行う。
  手順と、Football Manager 関連の作業の引き継ぎは [`docs/local-setup.md`](docs/local-setup.md)。

## ailab

外部サービスは**すべて同じ形（コネクタ）**で `src/ailab/connectors/` に1ファイルずつ置く。

```
src/ailab/
  core/          連携基盤（共通契約・登録簿・通信・キャッシュ・型）
  connectors/    連携先。1ファイル1サービス。ここに足すだけで CLI と MCP に出る
  assets.py      素材のダウンロードとクレジット出力
  recipes.py     YAMLレシピの実行
  mcp_server.py  MCPサーバ（stdio / JSON-RPC、依存追加なし）
  cli.py         コマンドの入口
  imagegen.py / illust.py   後方互換シム
```

```bash
ailab connectors     # 連携先と設定状況
ailab doctor         # 実際に接続して確認
```

### 設計の決めごと

- **能力はプロトコルで判定する。** 継承ではなくメソッドの有無
  （`search_assets` / `generate` / `publish` / `fetch_items`）で分岐する。
  1コネクタが複数の能力を持ってよい（例: `github` は publish と fetch_items）。
- **CLI と MCP は登録簿だけを見る。** `--provider` `--source` `--to` の選択肢も
  MCP のツール定義も registry から作るので、コネクタ追加時に触る必要はない。
- **再試行・レート制限・キャッシュ・エラーの言い換えは基盤の仕事。**
  コネクタ側には書かない（`core/http.py`, `core/cache.py`）。
- **レート制限はコネクタ名で共有する。** インスタンスごとに持つと、
  常駐する MCP サーバで枠を守れない。
- **書き込み系は既定でドライラン。** `ailab publish` は `--yes`、
  MCP の `publish_file` は `confirm: true` を渡すまで送信しない。
- **ライセンスと出典は必ず持ち回る。** 素材取得時は `CREDITS.md` / `credits.json` を書く。
- **APIがあるものだけ連携する。** HTMLスクレイピングはしない。
- **モデルIDは変わる。** `AILAB_<コネクタ名>_MODEL` で `.env` から差し替えられる
  （`--model` 引数 > 環境変数 > 既定値）。

### テストの約束

- **外部通信をしない。** `tests/ailab/conftest.py` が `requests.Session.request` を塞ぐので、
  差し替え漏れがあれば通信前に落ちる。HTTPは `FakeSession` を注入する
  （`Connector(session=FakeSession([...]))`）。
- **待たない。** `time.sleep` も conftest で止めてある。
- **契約テストがある。** `tests/ailab/test_registry.py` が全コネクタの summary・
  キー取得先URL・能力の有無を検査する。コネクタを足すと自動で効く。
- キー未設定を前提にする。conftest が実環境の APIキー環境変数を消している。
- **網羅率90%以上**を CI で守る（`pytest --cov=ailab --cov-fail-under=90`）。

### コネクタを足すとき

1. `src/ailab/connectors/<category>_<name>.py` に `Connector` 継承クラス＋`@register`
2. 能力に応じたメソッドを実装（詳細は `docs/connectors.md`）
3. `connectors/__init__.py` に import を1行
4. テストを書く（HTTPは `FakeSession`）

## moneyloop / adsite

`--dry-run` は Claude API を呼ばずに全工程を通す。テストも追加依存なしで走る。
実際に Claude を呼ぶときだけ `pip install -e ".[llm]"`。

- **冪等性が最優先。** 同日に何度実行しても、号は1つ・配信は1回・計上は1回。
  cron の二重起動で課金が増えてはいけない。
- 料金表は `moneyloop.pricing` が単一の情報源。adsite のサイトもここから生成するので、
  価格改定はここ1箇所だけを直す。
- adsite の広告枠の制約（1ページ3枠まで、ツールUIの隣に置かない等）は
  見た目の好みではなく、Core Web Vitals と AdSense のポリシー由来。緩めない。
- 設計は `docs/architecture.md`、運用は `docs/runbook.md`。

## growth

- 提案の指紋は `ルールID + 対象プロジェクト` から作る。**ルールIDを変えると
  台帳の履歴が切れて、解決済み・却下済みの記録が失われる**。文面の修正は自由。
- ベースライン診断は `rules.py`、横展開は `practices.py`。入口は `rules.run_all`。
- 新しいルールには `topic` を付ける。既存ルールと同じ `topic` なら
  横展開ルールと自動でマージされ、同じ論点を二重に指摘しなくなる。
- 横展開の習慣には、意味を持つ条件があるなら `requires_signal` を必ず書く。
  的外れな指摘が1つ混ざると、正しい指摘まで読まれなくなる。
- 提案には必ず「そのまま貼れる依頼文」が付く状態を保つ。
  指摘して終わりにすると、この仕組みを作った意味がなくなる。
- `growth/ledger.json` は自動生成物だが、**消すと過去の判断（却下・解決）が
  全部消える**。手で編集しない。
- 他PJTに要求していることは、まず ai-lab 自身が満たしていること。

## audiogen

- **外部ライブラリを入れない。** 標準ライブラリだけで合成する。
  ここに依存を足すと「pip install なしで素材が作れる」という前提が崩れる。
- `seed` を固定したら毎回まったく同じ WAV が出ること。再現性が素材としての価値。
- 曲想・曲構成の定義は `styles.py` に宣言的に置く。合成のコードに埋めない。
- 設定の検査は `bgm.compose()` の入口でやり、範囲外の値はその場で
  `ValueError`（どの項目にいくつ渡したかをメッセージに出す）。
- 設計の詳細は `docs/audiogen.md`。
