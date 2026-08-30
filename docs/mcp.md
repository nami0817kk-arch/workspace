# MCP サーバとして使う

`ailab mcp` は ailab を MCP サーバ（stdio / JSON-RPC 2.0）として起動する。
Claude から `ailab` の連携先を直接呼べるようになり、コマンドを打たなくても
「猫のイラストを探して」「バナーを作ってリポジトリに置いて」が通る。

## 設定

リポジトリ直下の `.mcp.json` に定義済みなので、このリポジトリで Claude Code を
起動して接続を許可すれば使える。

```json
{
  "mcpServers": {
    "ailab": {
      "command": "python",
      "args": ["-m", "ailab", "mcp"],
      "env": { "PYTHONPATH": "src" }
    }
  }
}
```

APIキーは通常どおり `.env` から読む（サーバ起動時に読み込む）。
手元で動作を確かめるだけなら、標準入力に JSON-RPC を1行ずつ流せばよい。

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | python -m ailab mcp
```

## 公開しているツール

| ツール | 内容 |
|---|---|
| `list_connectors` | 使える連携先と、キーが設定されているか |
| `generate_image` | 画像を生成して保存し、パスを返す |
| `search_assets` | フリー素材を検索する（DLはしない） |
| `fetch_assets` | フリー素材をDLし、CREDITS.md も書き出す |
| `fetch_feed` | 記事・リリース情報を取得する |
| `publish_file` | ファイルを外部サービスへ送る（既定はドライラン） |
| `run_recipe` | レシピを実行する（publish は既定でドライラン） |

選択肢（provider / source の enum）は登録簿から作っているので、
コネクタを足せば MCP 側にも自動で現れる。ツール定義を書き直す必要はない。

## 送信の扱い

外部へ送る操作は取り消せないので、`publish_file` と `run_recipe` は
**`confirm: true` を渡すまでドライラン**。何が送られるかを返すだけにしている。

## 実装メモ

- 標準出力は JSON-RPC 専用。起動メッセージなどは標準エラーへ出す。
- 対応メソッドは `initialize` / `ping` / `tools/list` / `tools/call`。
  通知（id なし）には応答しない。
- `protocolVersion` はクライアントが提示したものをそのまま返す
  （未提示なら `mcp_server.PROTOCOL_VERSION`）。
- 追加の依存ライブラリは無し。`src/ailab/mcp_server.py` の1ファイル。
