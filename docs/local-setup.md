# ローカルPCで Claude Code を動かす

クラウド（Claude Code on the web）のセッションからは、手元のPCのファイルにもアプリにも触れない。
PC上のものを対象にした作業は、PC側で Claude Code を起動して行う。

この文書は「PC側に移る」ための手順と、移った先で拾うべき文脈をまとめたもの。
Python 環境の作り方そのものは [README](../README.md#セットアップ) にある。

## なぜ PC 側で動かすのか

Claude Code の web セッションは、Anthropic 側の隔離コンテナで動いている。
そこから利用者のPCへ接続する経路は無い。2026-08 時点でこのリポジトリのセッションから実測した結果:

| 試したこと | 結果 |
|---|---|
| `api.github.com` への HTTPS | 通る |
| 任意のホスト（`example.com` 等）への HTTPS | egress ポリシーで拒否 |
| 生TCP（SSH の 22番など） | 遮断 |
| 443 以外のポートへの HTTPS | 遮断 |

出口は 443 番の HTTPS プロキシ1本で、宛先は GitHub・パッケージレジストリ・Anthropic API に限られる。
プロキシ自体も WebSocket のアップグレード・生TCP・443以外のポート・証明書ピンニングを行うクライアントに非対応。
このため SSH / VNC / RDP / Tailscale / ngrok / Cloudflare Tunnel はいずれも成立しない。
仮に出口が開いていても、PC は NAT の内側にいるので外から呼びかけて届く相手ではない。

**結論: PC を対象にする作業は、PC 側で Claude Code を動かす。**
クラウドのセッションは、リポジトリの中だけで完結する作業（コードを書く、テストを回す、push する）に使う。

## 導入

推奨はネイティブインストーラ。Node.js は要らず、バックグラウンドで自動更新される。

**macOS**

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows（PowerShell）**

```powershell
irm https://claude.ai/install.ps1 | iex
```

管理者権限は不要。Homebrew（`brew install --cask claude-code`）や
WinGet（`winget install Anthropic.ClaudeCode`）でも入るが、その場合は自動更新されないので
手で `brew upgrade` / `winget upgrade` する必要がある。

入ったか確認する。

```bash
claude --version
claude doctor
```

### 初回起動と認証

リポジトリのディレクトリで `claude` を実行するとブラウザが開き、claude.ai のアカウントでログインする。
ブラウザが開かないときは `c` を押すとログインURLがクリップボードに入る。
Pro / Max / Team / Enterprise のサブスクリプションでそのまま使える（別途 APIキーを買う必要はない）。

なお `ANTHROPIC_API_KEY` を環境変数に設定していると、ブラウザ認証を飛ばしてそのキーを使うか聞かれる。
このリポジトリの `.env` は moneyloop 用にこの変数を持ちうるので、意図せず従量課金のキーが使われないよう
どちらで動いているかは初回に確認しておくとよい。

### Windows の注意

Windows ではネイティブに動き、WSL は必須ではない。ただし2点ある。

- [Git for Windows](https://git-scm.com/downloads/win) を入れておくと Bash が使える。
  無い場合は PowerShell にフォールバックするため、このリポジトリの README にある
  `bash` 前提のコマンドがそのままでは通らない。
- 入れてあるのに検出されない場合は、`~/.claude/settings.json` の `env` に
  `CLAUDE_CODE_GIT_BASH_PATH` として `bash.exe` の絶対パス
  （既定では `C:\Program Files\Git\bin\bash.exe`）を設定すると認識される。

### ターミナルを使わない選択肢

CLI のほかに、同じエンジンをGUIで包んだデスクトップアプリ（macOS / Windows / Linux）がある。
セッションの並行管理・差分表示・エディタが1画面にまとまっており、
CLAUDE.md・MCP サーバ・スキル・設定は CLI と共有される。どちらを使っても同じ結果になる。
入手先と対応OSは [公式ドキュメント](https://code.claude.com/docs/en/desktop-quickstart) を参照。

## このリポジトリを手元で動かす

```bash
git clone https://github.com/nami0817kk-arch/ai-lab.git
cd ai-lab
```

Python 環境は [README のセットアップ](../README.md#セットアップ) の通り。
そのうえで、ローカル特有の注意が2つある。

- **`.env`**: `.env.example` をコピーして `.env` を作る。APIキーはクラウドのセッションには渡っていないので、
  ローカルで初めて設定することになる。`.env` は `.gitignore` 済みで、コミットしてはいけない。
- **`.mcp.json`**: このリポジトリは `ailab` の MCP サーバを `python -m ailab mcp` で起動する設定を持つ。
  Claude Code をリポジトリ直下で起動すると読み込まれるので、`python` が仮想環境のものを指している状態
  （= venv を有効化してから `claude` を起動する）にしておく。
  Windows で `python` が Microsoft Store のスタブに取られている場合はここで失敗する。

## Football Manager の作業をここから続ける

### 決まっていること

- **FM に操作用の公式 API は無い。** 外部から盤面を動かす正規の口が存在しない。
- **「読む」側は、FM のエクスポート機能を使う。**
  FM は選手検索やスカッドなどの画面の表示内容を HTML / RTF で書き出せる
  （多くのバージョンでは印刷のショートカットから「Web Page」を選ぶ）。
  出力されたファイルを解析すれば、選手データを安定して取り込める。
  正確な手順はバージョンとスキンで変わるので、実機で確認すること。
- **「書く」側（実際のクリック操作）は脆い。**
  `pyautogui` や AutoHotkey による GUI 自動化は、解像度・UIスキン・ゲームのバージョンが変わるたびに壊れる。
  やるとしても必要最小限にとどめ、自動化の中心に据えない。

したがって、**取り込みと分析を自動化し、操作は人間が行う**という切り分けを既定とする。

### 次にやること

1. FM から選手データのエクスポートを1つ出し、`fm-data/` に置く。
   このディレクトリは `.gitignore` 済み。ゲームの著作物なのでコミットしないこと。
2. そのファイルを読むパーサを書く。出力の実物を見てからスキーマを決める。
3. 分析（スカウティング、選手比較、契約状況の棚卸しなど）を載せる。

新しいパッケージとして作る場合は、[CLAUDE.md](../CLAUDE.md) の共通方針に従う。

- `src/<パッケージ名>/` に置き、テストは `tests/<パッケージ名>/` に分ける
- 実行時の依存は増やさない（標準ライブラリの `html.parser` で足りるはず）
- テストは外部通信をしない
- CLAUDE.md の表と節を1行足す
