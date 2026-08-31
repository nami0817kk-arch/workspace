# Chrome の自動操作

ブラウザを自動操作する方法を 2 通り用意した。目的によって使い分ける。

| | 何を操作するか | 主な用途 | 実行場所 |
|---|---|---|---|
| ① ヘッドレス | 使い捨ての Chromium | スクレイピング、E2E テスト、定期取得 | どこでも(クラウド含む) |
| ② ローカル Chrome | 自分の PC で開いている Chrome 本体 | ログイン済みの業務サイト操作、手作業の半自動化 | 自分の PC のみ |

どちらも [Playwright](https://playwright.dev/python/) を使う。

## セットアップ

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
playwright install chromium
```

`playwright install chromium` は ① で使う Chromium を取得する。② だけを使う場合は不要
(すでに PC に入っている Chrome を使うため)。

## ① ヘッドレス Chromium

画面のないブラウザを起動して操作する。人間が見ている画面とは無関係に動くので、
バックグラウンド処理や CI に向く。

```bash
# 同梱のデモページを操作する(入力 → 選択 → クリック → 結果読み取り → 撮影)
python -m src.browser.headless_demo

# 任意の URL を開いて撮影
python -m src.browser.headless_demo --url https://example.com --out output/shot.png

# 動いている様子を目で見たいとき(GUI のある PC のみ)
python -m src.browser.headless_demo --headed
```

実装は `src/browser/headless_demo.py`。環境ごとの差分は `src/browser/config.py` に寄せてある。

### Claude Code のリモート環境で動かす場合

クラウド上のコンテナでも動作確認済み。ただし 2 点、環境固有の事情がある。
どちらも `src/browser/config.py` が自動で吸収するので、コード側の対応は不要。

- **Chromium の場所**: `/opt/pw-browsers/chromium` にプリインストールされているが、
  pip で入る Playwright とビルド番号がずれているため `executable_path` の明示が要る。
  `playwright install` は実行しないこと。
- **証明書**: 外向き HTTPS がプロキシで再終端されるため、そのままだと
  `ERR_CERT_AUTHORITY_INVALID` になる。プロキシ CA の公開鍵だけを SPKI 指定で
  例外にしている(証明書検証そのものは有効なまま)。

**外向き通信の制限**: リモート環境の egress ポリシーは組織側で設定されている。
2026-08-31 時点のこのセッションでは `pypi.org` などのパッケージレジストリと、
セッションにスコープされた GitHub リポジトリ以外は CONNECT が 403 で拒否された
(`example.com`、`www.google.com`、`docs.anthropic.com`、`www.wikipedia.org` などは不可)。
一般の Web サイトをクラウド側から巡回したい場合は、環境のネットワークポリシーの
見直しが必要になる。ローカル PC で実行する分にはこの制限はない。

## ② ローカル Chrome 本体の操作

**このスクリプトは自分の PC で実行する。** クラウド上の Claude Code セッションから
実行しても PC の Chrome には届かない(セッションは隔離されたコンテナで動いていて、
手元のマシンとは接続されていないため)。

Chrome をリモートデバッグポート付きで起動しておき、Playwright の CDP
(Chrome DevTools Protocol) 接続でそこにぶら下がる。使い捨てブラウザではなく、
目の前で開いている Chrome のタブをそのまま操作できる。

### 手順

1. デバッグポート付きで Chrome を起動する。

   ```powershell
   # Windows
   powershell -ExecutionPolicy Bypass -File scripts\start-chrome-debug.ps1
   ```

   ```bash
   # macOS / Linux
   ./scripts/start-chrome-debug.sh
   ```

   既定では専用プロファイル(Windows: `%LOCALAPPDATA%\ai-lab\chrome-debug-profile`)で
   起動するため、普段使いの Chrome を閉じる必要はない。このプロファイルでのログイン状態は
   次回以降も残るので、業務サイトに一度ログインしておけば以後は自動操作できる。

2. 接続を確認する。ブラウザで `http://127.0.0.1:9222/json/version` が JSON を返せば成功。

3. 操作する。

   ```bash
   python -m src.browser.local_chrome --list                  # 開いているタブ一覧
   python -m src.browser.local_chrome --url https://example.com
   python -m src.browser.local_chrome --shot output/tab.png   # 現在のタブを撮影
   ```

実装は `src/browser/local_chrome.py`。`browser.close()` は CDP 接続を切るだけで、
Chrome 自体は開いたまま残る。

### 普段のプロファイルを使いたい場合

ログイン済みセッションや拡張機能をそのまま使いたいときは、起動スクリプトに
`-UseDefaultProfile`(Windows)/ `--default-profile`(mac, Linux)を付ける。
ただし **Chrome を完全に終了してから** 実行すること。プロファイルが使用中だと
デバッグポートが開かない。

### PowerShell スクリプトの文字コード

`scripts/start-chrome-debug.ps1` は **UTF-8 (BOM 付き)** で保存すること。
Windows PowerShell 5.1 は BOM のない `.ps1` を ANSI(日本語環境では CP932)として
読むため、BOM を落とすとコメントやメッセージ内の日本語が壊れ、
`文字列に終端記号 " がありません` のような構文エラーで起動できなくなる。

編集時に BOM を落とすエディタもあるので、`tests/test_browser.py` に BOM の
有無を確認するテストを入れてある。

## 注意点

- **`--remote-debugging-port` を開いた Chrome は、そのポートに繋げる相手に
  ブラウザを丸ごと明け渡す。** Cookie もログイン状態も読み取れてしまうため、
  ポートは `127.0.0.1` に閉じたままにし(既定でそうなっている)、
  外部公開やポートフォワードはしないこと。使い終わったらその Chrome は閉じる。
- 認証情報をスクリプトに直書きしない。必要なら `.env`(gitignore 済み)から読む。
- スクリーンショットの保存先 `output/` は gitignore 済み。
- 自動操作の対象サイトの利用規約を確認すること。特に大量アクセスを伴う場合。

## できないこと

- 手元の PC のデスクトップ画面のキャプチャ、マウス・キーボードの遠隔操作
  (ブラウザの中だけが操作範囲)
- クラウド上のセッションから、手元の Chrome のタブや拡張機能を直接触ること
