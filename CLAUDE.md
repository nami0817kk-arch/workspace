# CLAUDE.md

このリポジトリ（PJT008 AIラボ）は、独立した試作パッケージを `src/` 以下に並べて置く。
パッケージごとに前提が違うので、触る対象の節を読むこと。

| パッケージ | 内容 |
|---|---|
| `src/ailab/` | 画像生成・フリー素材取得・外部サービス連携の CLI + MCPサーバ |

（他の試作を足すときは、この表と節を増やす）

## 共通

```bash
pip install -e ".[dev]"
pytest -q
python -m ruff check src tests
```

- テストは**外部通信をしない**。CI（`.github/workflows/tests.yml`）は
  Ubuntu / Windows × Python 3.10・3.12 で回る。
- APIキーは `.env`（`.gitignore` 済み）。ログにも `--json` 出力にも出さない。
  表示直前に `core/redact.py` が環境変数の値と突き合わせて伏せる（最後の砦）。
- MCP の `publish_file` はプロジェクト配下のファイルしか送れない。
- Claude Code の web セッションからは多くの外部ホストが egress ポリシーで塞がれる。
  疎通確認が NG でも、手元では通ることがある。

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

- **外部通信をしない。** `tests/conftest.py` が `requests.Session.request` を塞ぐので、
  差し替え漏れがあれば通信前に落ちる。HTTPは `FakeSession` を注入する
  （`Connector(session=FakeSession([...]))`）。
- **待たない。** `time.sleep` も conftest で止めてある。
- **契約テストがある。** `tests/test_registry.py` が全コネクタの summary・
  キー取得先URL・能力の有無を検査する。コネクタを足すと自動で効く。
- キー未設定を前提にする。conftest が実環境の APIキー環境変数を消している。
- **網羅率90%以上**を CI で守る（`pytest --cov=ailab --cov-fail-under=90`）。

### コネクタを足すとき

1. `src/ailab/connectors/<category>_<name>.py` に `Connector` 継承クラス＋`@register`
2. 能力に応じたメソッドを実装（詳細は `docs/connectors.md`）
3. `connectors/__init__.py` に import を1行
4. テストを書く（HTTPは `FakeSession`）
