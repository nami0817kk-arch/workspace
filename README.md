# gemini-api

Gemini API を叩いて結果を JSON で返す、自分用の FastAPI ゲートウェイ。

アプリから直接 Gemini SDK を呼ぶ代わりにここを経由させると、APIキーを1か所に閉じ込められて、
モデル切り替え・リトライ・キャッシュ・ログを共通化できる。

## セットアップ

```bash
py -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements-dev.txt
cp .env.example .env   # GEMINI_API_KEY を書く
```

APIキーは https://aistudio.google.com/apikey で発行する。`.env` は `.gitignore` 済み。

## 起動

```bash
.venv/Scripts/python.exe -m uvicorn app.main:app --reload
```

- Swagger UI: http://127.0.0.1:8000/docs
- OpenAPI: http://127.0.0.1:8000/openapi.json

## エンドポイント

| メソッド | パス | 用途 |
| --- | --- | --- |
| GET | `/health` | 死活確認（上流には問い合わせない） |
| GET | `/v1/models` | 使えるモデル一覧を取得 |
| POST | `/v1/generate` | プロンプトを投げてテキストを取得 |
| POST | `/v1/generate/stream` | 同上をSSEで逐次受け取る |

### POST /v1/generate

```bash
curl -X POST http://127.0.0.1:8000/v1/generate -H "Content-Type: application/json" -d "{\"prompt\":\"日本の首都は？\"}"
```

リクエスト（`prompt` 以外は任意、未指定なら `.env` の既定値）:

```json
{
  "prompt": "この決算短信を3行で要約して",
  "system_instruction": "あなたは日本株のアナリストです",
  "model": "gemini-3.7-flash",
  "temperature": 0.2,
  "max_output_tokens": 512
}
```

レスポンス:

```json
{
  "text": "...",
  "model": "gemini-3.7-flash",
  "cached": false,
  "elapsed_ms": 1234,
  "usage": { "prompt_tokens": 120, "output_tokens": 88, "total_tokens": 208 }
}
```

### POST /v1/generate/stream

リクエストの形は `/v1/generate` と同じ。`text/event-stream` で届いた順に流れる。

```
data: {"text": "いち
"}

data: {"text": "に
"}

data: [DONE]
```

- 終端は必ず `data: [DONE]`
- 途中で失敗した場合はヘッダ送信済みでステータスを変えられないため、
  `event: error` フレーム（`{"detail": ..., "status": ...}`）を流して打ち切る。
  `[DONE]` が来なければ未完了と判断できる
- ストリーミングはキャッシュ対象外

```bash
curl -N -X POST http://127.0.0.1:8000/v1/generate/stream -H "Content-Type: application/json" -d "{\"prompt\":\"1から5まで数えて\"}"
```

## 設定（.env）

| 変数 | 既定値 | 説明 |
| --- | --- | --- |
| `GEMINI_API_KEY` | （空） | APIキー。未設定なら SDK が環境変数から拾う |
| `GEMINI_MODEL` | `gemini-3.5-flash` | 既定モデル |
| `TEMPERATURE` | `1.0` | 既定の温度 |
| `MAX_OUTPUT_TOKENS` | `2048` | 既定の最大出力トークン |
| `REQUEST_TIMEOUT` | `60.0` | 超えたら 504 を返す |
| `MAX_RETRIES` | `2` | 429/5xx/タイムアウトのみ指数バックオフで再試行 |
| `CACHE_TTL` | `0` | 同一プロンプトのキャッシュ秒数。0 で無効 |
| `API_KEYS` | （空） | このゲートウェイを叩くのに要求するキー（カンマ区切り）。空なら認証なし |
| `RATE_LIMIT_PER_MINUTE` | `0` | 1分あたりの許可リクエスト数。0 で無制限 |
| `REDIS_URL` | （空） | 設定するとキャッシュを Redis に置く。空ならプロセス内メモリ |
| `CORS_ORIGINS` | `*` | カンマ区切り |

## エラーの返り方

- `422` … リクエストのバリデーション失敗（空プロンプト、temperature 範囲外など）
- `4xx` … 上流のステータスをそのまま返す（例: 存在しないモデル指定は `404`）
- `429` / `503` … リトライしきっても混雑・レート制限だった場合。クライアント側で時間を置いて再試行する
- `504` … `REQUEST_TIMEOUT` 超過
- `502` … 上流の 500 系がリトライ後も解消しない、または安全フィルタ等で本文が空

## モデルについて

`GET /v1/models` で、そのAPIキーで実際に使えるモデルを確認できる。
`gemini-2.5-*` は新規ユーザーには提供終了しており、指定すると 404 が返る。
既定は `gemini-3.5-flash`。`gemini-3.7-flash`（より新しい）は混雑時に 503 を返すことが
あったため既定から外している。使いたいときは `GEMINI_MODEL` を変えるか、リクエストごとに
`model` で指定する。

## 認証

`.env` の `API_KEYS` にキーを入れると、`/v1/*` は `X-API-Key` ヘッダ必須になる。
空のままなら認証なし（ローカル用）で、起動時に警告ログが出る。`/health` は常に公開。

```bash
API_KEYS=好きな長いランダム文字列,別のキー
```

```bash
curl -X POST http://127.0.0.1:8000/v1/generate -H "X-API-Key: 好きな長いランダム文字列" -H "Content-Type: application/json" -d "{\"prompt\":\"hello\"}"
```

Swagger UI 右上の Authorize からも入力できる。キーが違えば `401` を返す。

## レート制限

`RATE_LIMIT_PER_MINUTE` を 1 以上にすると `/v1/*` に固定ウィンドウの制限がかかる。
数える単位は `X-API-Key`（未設定なら接続元IP）。超過すると `429` と `Retry-After` を返す。
`/health` は対象外。

プロセス内カウンタなので、uvicorn のワーカーを増やすとワーカー数だけ実効上限が緩くなる。
厳密にやるなら Redis 側にカウンタを持たせる必要がある。

## キャッシュ

`CACHE_TTL` が 1 以上のときだけ有効。同じプロンプト・同じパラメータの結果を使い回す。

- 既定はプロセス内メモリ。再起動で消え、ワーカー間で共有されない
- `REDIS_URL` を設定すると Redis に置き、ワーカー / プロセスを跨いで共有できる
  （`pip install redis` が必要）
- Redis が落ちてもリクエストは通す（キャッシュミス扱いにして続行する）

## トークン消費の注意

Gemini 3 系は思考（thinking）にも出力トークンを使う。`usage` を見ると
`output_tokens: 1` でも `total_tokens: 160` になることがあり、課金はこの合計に対してかかる。
`max_output_tokens` にも思考分が含まれるため、値を小さくしすぎると本文が途中で切れる。
実測では 200 だと短い回答すら切れたので、既定の 2048 から下げるときは注意する。

## テスト

```bash
.venv/Scripts/python.exe -m pytest -q
```

上流は `tests/conftest.py` のスタブに差し替えているので、APIキーなし・ネットワークなしで通る。

## 構成

```
app/
  main.py            アプリ生成、CORS、例外ハンドラ、lifespan
  config.py          .env / 環境変数の設定
  schemas.py         リクエスト・レスポンスの型
  dependencies.py    ルーターが使う依存（テストで override する口）
  clients/gemini.py  google-genai の薄いラッパ（タイムアウト・リトライ・エラー変換）
  security.py        X-API-Key 認証とレート制限
  services/cache.py    キャッシュ（メモリ / Redis の差し替え）
  services/ratelimit.py 固定ウィンドウのレート制限
  routers/           health.py, generate.py
```

## 次に足すとしたら

- レート制限のカウンタを Redis 側に寄せる（今はワーカーごとに独立）
- 画像・音声など、テキスト以外の入出力への対応
