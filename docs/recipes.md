# レシピ：手順をYAMLにまとめて再実行する

`ailab run` は「集める → 作る → 送る」の一連の流れを1つのYAMLにまとめて実行する。
毎回同じ手順を打ち込む代わりに、レシピを1本用意して回す。

```bash
ailab run recipes/illust-pack.yaml
ailab run illust-pack                       # recipes/ の中なら名前だけでよい
ailab run weekly-release-banner --set repo=owner/name
ailab run weekly-release-banner --set repo=owner/name --yes   # publish を実際に行う
ailab run illust-pack --json                # 結果を JSON で受け取る
```

## 書き方

```yaml
name: 週次リリースバナー

vars:                     # --set KEY=VALUE で上書きできる
  repo: owner/name

steps:
  - id: releases          # 省略すると step1, step2 … になる
    feed:
      source: github
      query: "{{ vars.repo }}"
      limit: 1

  - id: banner
    gen:
      prompt: "{{ releases.0.title }} のリリース告知バナー、フラットイラスト"
      size: 1200x630
      filename: "release_{{ today }}"

  - publish:
      to: github
      repo: "{{ vars.repo }}"
      dest: "docs/img/release_{{ today }}.png"
```

1手順につき動詞は1つ。使える動詞は連携の能力とそのまま対応している。

| 動詞 | 設定 | 結果 |
|---|---|---|
| `feed` | `source`（必須）, `query`, `limit` | 記事・リリースの一覧 |
| `search` | `query`, `source`（既定 all）, `limit` | 素材の一覧（ダウンロードはしない） |
| `fetch` | `query`, `source`, `limit`, `out` | 素材をDLし `path` とクレジットを残す |
| `gen` | `prompt`（必須）, `provider`, `model`, `style`, `size`, `n`, `out`, `filename`, `format`, `max_width` | 生成画像の `path` |
| `publish` | `to`（既定 github）, `file`, ほかは送信先へそのまま渡す | 送信結果 |

`publish` の `file` を省略すると、**直前までの手順が作った最後のファイル**を送る。

## 参照

前の手順の結果は `{{ 手順id.番号.フィールド }}` で参照する。

- `{{ releases.0.title }}` … 1件目のタイトル
- `{{ releases.title }}` … 番号を省くと先頭の要素を見る
- `{{ vars.repo }}` … `vars` と `--set` の値
- `{{ today }}` / `{{ now }}` … 実行日・実行時刻

値の全体が1つの参照なら型を保ったまま渡す（`limit: "{{ vars.count }}"` は数値のまま）。
参照できないときは黙って空にせず、その場で止める。前の手順が0件なら
「結果が0件です」と手順番号つきで知らせる。

## 送信の扱い

`publish` を含むレシピは**既定でドライラン**。何が送られるかを表示するだけで、
`--yes` を付けるまで実際には送らない。手順ごとに `dry_run: false` と書けば個別指定もできる。

## 同梱レシピ

| ファイル | 内容 |
|---|---|
| `recipes/weekly-release-banner.yaml` | リリース情報 → バナー生成 → リポジトリへコミット |
| `recipes/illust-pack.yaml` | キーワードでフリー素材を集め、クレジット付きで保存 |
