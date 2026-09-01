# CLAUDE.md

このリポジトリ（ai-lab）は、各プロジェクト（PJT）で使うための機能・仕組みを
開発する場所であって、PJT そのものではない。個別のPJTに埋め込むと再利用できない
汎用的な仕組みをここに置き、各PJTから呼び出す。

独立したパッケージを `src/` 以下に並べて置く。パッケージごとに前提が違うので、
触る対象の節を読むこと。

| パッケージ | 内容 |
|---|---|
| `src/imagegen/` | 画像生成・音声合成・フリー素材取得・外部サービス連携の CLI + MCPサーバ |
| `src/adsite/` | 広告収益型ツールサイトのジェネレータ（収支台帳を内蔵） |
| `src/growth/` | 全プロジェクトを定期点検し、次にやることを提示する成長ループ |
| `src/audiogen/` | BGM / 効果音を手続き的に合成して WAV に書き出すツールキット |
| `src/browser/` | Chrome の自動操作（ヘッドレス Chromium / ローカル Chrome を CDP 経由で） |
| `src/videogen/` | 画像・音声・字幕を1本の動画にまとめる（ffmpeg のコマンドを組み立てる） |
| `src/docparse/` | PDF から本文と表を、ページ番号つきで抜き出す |

（他の試作を足すときは、この表と節を増やす）

## 共通

```bash
pip install -e ".[dev]"
pytest
python -m ruff check src/imagegen tests/imagegen
```

- Python 3.11 以上。**実行時の依存は既定でゼロ**。
  moneyloop / growth / audiogen は標準ライブラリだけで動く。
  依存が要るものは extras に切り出してある（`[image]` = imagegen、`[llm]` = Claude 呼び出し）。
  定期実行されるものが多く、依存が増えるほど勝手に壊れる確率が上がるため。
- src レイアウト。テストは `pytest`（`pyproject.toml` で `pythonpath` を通してある）。
- **テストはツールごとに `tests/<ツール名>/` に分ける。**
  同名テストモジュールの衝突を避けるためと、`conftest.py` の autouse フィクスチャが
  他のツールのテストへ漏れないようにするため。共有ヘルパ（`tests/helpers.py`、
  `tests/fakes.py`）だけが `tests/` 直下にある。
- テストは**外部通信をしない**。CI（`.github/workflows/ailab-tests.yml`）は
  Ubuntu × Python 3.11・3.12 で全体を回し、imagegen だけ Windows でも回す。
- APIキーは `.env`（`.gitignore` 済み）。ログにも `--json` 出力にも出さない。
  表示直前に `src/imagegen/core/redact.py` が環境変数の値と突き合わせて伏せる（最後の砦）。
- MCP の `publish_file` はプロジェクト配下のファイルしか送れない。
- Claude Code の web セッションからは多くの外部ホストが egress ポリシーで塞がれる。
  疎通確認が NG でも、手元では通ることがある。
- **web セッションから利用者のPCへは接続できない**（出口は443のHTTPSのみ、宛先も許可リスト制）。
  PC上のファイルやアプリを対象にする作業は、PC側で Claude Code を起動して行う。
  手順と、Football Manager 関連の作業の引き継ぎは [`docs/local-setup.md`](docs/local-setup.md)。

## imagegen

外部サービスは**すべて同じ形（コネクタ）**で `src/imagegen/connectors/` に1ファイルずつ置く。

```
src/imagegen/
  core/          連携基盤（共通契約・登録簿・通信・キャッシュ・型）
  connectors/    連携先。1ファイル1サービス。ここに足すだけで CLI と MCP に出る
  assets.py      素材のダウンロードとクレジット出力
  recipes.py     YAMLレシピの実行
  mcp_server.py  MCPサーバ（stdio / JSON-RPC、依存追加なし）
  cli.py         コマンドの入口
  generation.py  画像生成の入口（コネクタ選択・絵柄・利用量の記録）
```

```bash
imagegen connectors     # 連携先と設定状況
imagegen doctor         # 実際に接続して確認
```

### 設計の決めごと

- **能力はプロトコルで判定する。** 継承ではなくメソッドの有無
  （`search_assets` / `generate` / `publish` / `fetch_items`）で分岐する。
  1コネクタが複数の能力を持ってよい（例: `github` は publish と fetch_items）。
- **CLI と MCP は登録簿だけを見る。** `--provider` `--source` `--to` の選択肢も
  MCP のツール定義も registry から作るので、コネクタ追加時に触る必要はない。
- **再試行・レート制限・キャッシュ・エラーの言い換えは基盤の仕事。**
  コネクタ側には書かない（`src/imagegen/core/http.py`, `src/imagegen/core/cache.py`）。
- **レート制限はコネクタ名で共有する。** インスタンスごとに持つと、
  常駐する MCP サーバで枠を守れない。
- **書き込み系は既定でドライラン。** `imagegen publish` は `--yes`、
  MCP の `publish_file` は `confirm: true` を渡すまで送信しない。
- **ライセンスと出典は必ず持ち回る。** 素材取得時は `CREDITS.md` / `credits.json` を書く。
- **APIがあるものだけ連携する。** HTMLスクレイピングはしない。
- **モデルIDは変わる。** `IMAGEGEN_<コネクタ名>_MODEL` で `.env` から差し替えられる
  （`--model` 引数 > 環境変数 > 既定値）。

### 文字入り画像の合成（compose）

- **乱数を使わない。** 同じ指定から常に同じ画像が出ること。素材として作り直せるため。
- **見出しは大きいほどよい。** 指定した大きさから始めて、行数と高さの両方が
  収まるまで縮める（`fonts.fit`）。下限で必ず止める（縮め続けて固まらせない）。
- **フォント探しは `fonts.py` に集約する。** 日本語が「□□□」になるのは
  Pillow の既定フォントに日本語が無いから。候補を増やすならここ1箇所。
- ロゴは**文字の有無に関係なく**載せる（背景＋ロゴだけの素材も作れる）。
- 背景に使った素材のライセンス表記の義務は、合成しても消えない。

### 音声合成（speech）

- **分割はコネクタに書かない。** 入力の上限はサービスごとに違うので、
  長文の分割とつなぎ直しは `speech.py`（入口）の仕事。コネクタは1回分の合成だけを知る。
  コネクタは `max_chars` を宣言するだけでよい。
- **beep は「読み上げない」ことを必ず伝える。** CLI も MCP も、beep を使ったときは
  プレースホルダである旨を出力に混ぜる。尺だけ合った無音を本番に混ぜないため。
- **VOICEVOX のクレジットは自動で残す。** 表記は `/speakers` から引く（話者IDから
  文言を推測して埋め込まない）。保存先の `CREDITS.md` に追記するところまでが合成の仕事。
- 音声の単価は**1000文字あたり**で、画像の1枚あたりとは単位が違う。
  `usage.DEFAULT_SPEECH_COSTS` と表を分けてあるのはそのため。混ぜない。

### テストの約束

- **外部通信をしない。** `tests/imagegen/conftest.py` が `requests.Session.request` を塞ぐので、
  差し替え漏れがあれば通信前に落ちる。HTTPは `FakeSession` を注入する
  （`Connector(session=FakeSession([...]))`）。
- **待たない。** `time.sleep` も conftest で止めてある。
- **契約テストがある。** `tests/imagegen/test_registry.py` が全コネクタの summary・
  キー取得先URL・能力の有無を検査する。コネクタを足すと自動で効く。
- キー未設定を前提にする。conftest が実環境の APIキー環境変数を消し、
  CLI / MCP が `.env` を読み直さないようにしている（開発機の実キーで
  `doctor` が本当に通信してしまうため）。
- **網羅率90%以上**を CI で守る（`pytest --cov=imagegen --cov-fail-under=90`）。

### コネクタを足すとき

1. `src/imagegen/connectors/<category>_<name>.py` に `Connector` 継承クラス＋`@register`
2. 能力に応じたメソッドを実装（詳細は `docs/connectors.md`）
3. `src/imagegen/connectors/__init__.py` に import を1行
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
- 設計は `docs/ad-monetization.md`、運用は `docs/runbook.md`。

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

## videogen

- **Python の依存を増やさない。** 要るのは ffmpeg の実行ファイルだけ。
  探す順番（`VIDEOGEN_FFMPEG` → PATH → imageio-ffmpeg）は `ffmpeg.py` の1箇所に集める。
- **組み立て（`build_command`）と実行（`render`）を分ける。** 組み立ては純粋な関数にしておく。
  ffmpeg が入っていない環境でもテストが通るのはこの分離のおかげで、
  ここを崩すと CI でも手元でも検証できなくなる。**テストから ffmpeg を起動しない**
  （`tests/videogen/conftest.py` が `subprocess.run` を塞いでいる）。
- **動かすシーンで画像をループさせない。** `zoompan` の `d` は「入力1フレームあたりに
  作る出力フレーム数」なので、`-loop 1 -t` で増やした入力と掛け算になる。
  実際に 5.7秒のつもりが 494秒の動画になった。静止画は1フレームだけ渡し、
  尺は zoompan に作らせる（`build.image_input`）。
- **シーンの長さは音声から決める。** 順序は `seconds` > 音声の長さ + `tail` > 既定4秒。
  WAV は標準ライブラリで測り、ffmpeg を呼ぶのは WAV 以外のときだけ。
- **音の長さはシーンにぴったり揃える**（短ければ無音で埋め、長ければ切る）。
  揃えないと concat のたびに映像と音がずれていく。
  音声の無いシーンにも無音を作り、concat のペアを常に揃える。
- **字幕は焼き込むかに関係なく必ず SRT に残す。** 焼いた字幕は消せないので既定では焼かない。
- 設定の誤りは**描き始める前に**全部出す（素材の不足、size が奇数、未知の motion）。
  ffmpeg を走らせてから失敗させない。

## docparse

- **ページ番号を必ず持ち回る。** 出典を言えない数字は一次情報として使えない。
  本文を連結するときも `--- p.2 ---` の区切りを残す。
- **△ と ▲ は負数**（決算資料の慣習）。素直に `float()` に通すと符号が消えて
  減益を増益と読む。変換は `search.to_float` の1箇所だけに置き、テストで固定する。
  読めなかったものは `None`。**0 とは違う**ので勝手に 0 にしない。
- **文字の無い PDF は空を返さずに落とす**（`NoTextLayer`）。黙って空文字を返すと
  「本文が無い書類」と区別がつかず、読み落としに気づけない。
- **外部ライブラリに触るのは `extract.py` だけ。** 他は pdfplumber 無しでテストできる状態を保つ。
  読み取りは `extractor` 引数で差し替える。
- 表は、列数がずれた行を捨てずに空欄で埋める（捨てると数字が落ちる）。
  逆に罫線だけの空の表は落とす。
- 設計の詳細は `docs/docparse.md`。

## audiogen

- **外部ライブラリを入れない。** 標準ライブラリだけで合成する。
  ここに依存を足すと「pip install なしで素材が作れる」という前提が崩れる。
- `seed` を固定したら毎回まったく同じ WAV が出ること。再現性が素材としての価値。
- 曲想・曲構成の定義は `styles.py` に宣言的に置く。合成のコードに埋めない。
- 設定の検査は `bgm.compose()` の入口でやり、範囲外の値はその場で
  `ValueError`（どの項目にいくつ渡したかをメッセージに出す）。
- 設計の詳細は `docs/audiogen.md`。

## browser

- 操作対象が2つある。**ヘッドレス Chromium**（`headless_demo.py`、どこでも動く）と、
  **手元の Chrome 本体**（`local_chrome.py` / `control.py`、CDP 接続なので PC 上でのみ動く）。
  web セッションから後者は使えない。
- 他PJTから日常的に呼ぶ入口は `control.py`。`local_chrome.py` は最小の接続例として残してある。
  操作を足すなら `control.py` のサブコマンドに足す。
- **標準出力は UTF-8 に固定する**（`control.use_utf8_stdout`）。Windows の CP932 のままだと
  外国語のページ本文で `UnicodeEncodeError` になって落ちる。
- **PDF は CDP の `Page.printToPDF` を直接呼ぶ。** Playwright の `page.pdf()` は
  ヘッドレス専用で、手元の Chrome に繋いだ状態では使えない。差し替えられうる
  公的資料を根拠にするため、取得時点の見た目ごと残せる形を保つ。
- **タブを閉じる操作は利用者のタブを巻き込みやすい。** `close` は `--match` 必須・
  複数一致なら止まる、という約束を崩さない。自分が開いたタブだけ片付ける。
- `scripts/start-chrome-debug.ps1` は **UTF-8 (BOM 付き)** で保存する。BOM を落とすと
  PowerShell 5.1 が CP932 として読み、日本語のコメントで構文エラーになる。
  テスト（`tests/browser/test_browser.py`）で BOM の有無を固定してある。
- デバッグポートを開けた Chrome は、そのポートに繋げる相手にブラウザを丸ごと明け渡す。
  `127.0.0.1` に閉じたままにし、外部公開やポートフォワードはしない。
- 詳細は `docs/chrome-automation.md`。
