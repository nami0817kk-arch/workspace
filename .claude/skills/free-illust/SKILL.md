---
name: free-illust
description: Web上のフリーイラスト・フリー素材を検索してダウンロードする。ユーザーが「フリー素材が欲しい」「イラストを探して」「商用利用できる画像を取ってきて」と言ったときに使う。Openverse / Wikimedia Commons / Pixabay を横断し、ライセンス表記も出力する。
---

# フリーイラストの取得

`ailab search` / `ailab fetch` を使う。実装は `src/ailab/connectors/assets_*.py`。使える検索先は `python -m ailab connectors` で分かる。

## 手順

1. まず検索して候補を見せる（勝手に大量ダウンロードしない）。

   ```bash
   python -m ailab search "cat illustration" -l 5
   ```

   英語のキーワードのほうがヒットしやすい（Openverse / Wikimedia は英語中心）。

2. ダウンロードする。

   ```bash
   python -m ailab fetch "cat illustration" -l 3 -o output/illust
   ```

   画像と一緒に `CREDITS.md` / `credits.json`（出典・作者・ライセンス）が書き出される。

3. ユーザーには保存先に加えて**ライセンスと必要なクレジット表記**を必ず伝える。

## 注意

- Openverse は既定で「商用利用可・改変可」に絞って検索する。それでも
  CC BY / CC BY-SA は**クレジット表示が必須**、CC BY-SA は継承も必要。
- Pixabay は `PIXABAY_API_KEY`（無料）が要る。未設定ならスキップされる。
- 検索結果は15分キャッシュされる。最新を見たいときは `--no-cache` を付ける。
- いらすとや等の国内素材サイトはAPIが無く規約上も一括取得を制限しているため、
  スクレイピングしない。必要なら手動で保存するようユーザーに案内する。
