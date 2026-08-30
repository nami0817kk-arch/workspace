# CLAUDE.md

このリポジトリで作業するときの前提をまとめたもの。

## これは何か

`ailab` は「画像生成・フリー素材取得・外部サービス連携」をまとめた CLI + MCP サーバ。
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
recipes/         同梱レシピ
docs/            使い方・連携の増やし方・レシピ・MCP・計画
```

## よく使うコマンド

```bash
pip install -r requirements-dev.txt && pip install -e .
python -m pytest -q          # テスト（外部通信は一切しない）
python -m ruff check src tests
ailab connectors             # 連携先と設定状況
ailab doctor                 # 実際に接続して確認
```

## 設計の決めごと

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
- **キーはログにも `--json` 出力にも出さない。**
- **モデルIDは変わる。** `AILAB_<コネクタ名>_MODEL` で `.env` から差し替えられる
  （`--model` 引数 > 環境変数 > 既定値）。

## テストの約束

- **外部通信をしない。** `tests/conftest.py` が `requests.Session.request` を塞いでいるので、
  差し替え漏れがあれば通信前に落ちる。HTTPは `FakeSession` を注入する
  （`Connector(session=FakeSession([...]))`）。
- **待たない。** `time.sleep` も conftest で止めてある。
- **契約テストがある。** `tests/test_registry.py` が全コネクタに対して
  summary・キー取得先URL・能力の有無を検査する。コネクタを足したらここが自動で効く。
- キー未設定を前提にする。conftest が実環境の APIキー環境変数を消している。

## コネクタを足すとき

1. `src/ailab/connectors/<category>_<name>.py` に `Connector` 継承クラス＋`@register`
2. 能力に応じたメソッドを実装（詳細は `docs/connectors.md`）
3. `connectors/__init__.py` に import を1行
4. テストを書く（HTTPは `FakeSession`）

## 環境

- 開発は Windows 想定（README のセットアップも Windows）。CI は Windows と Ubuntu で回す。
- Claude Code の web セッションからは多くの外部ホストが egress ポリシーで塞がれる。
  `ailab doctor` が NG でも、手元では通ることがある。
