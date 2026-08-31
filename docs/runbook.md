# 運用手順

## セットアップ

```bash
python -m venv .venv && . .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -e .

cp config/site.example.json config/site.json
```

`config/site.json` で最低限これらを埋めます。

| 項目 | 内容 |
|---|---|
| `base_url` | 公開するURL。canonicalとsitemapに使う |
| `site_name` | サイト名 |
| `author` | 運営者名（フッターと構造化データに出る） |
| `contact_url` | 問い合わせ先。審査項目なので必須 |
| `usd_jpy` | 円換算の表示レート |

`ads.client` は**審査に通ってから**入れてください。空の間は広告タグを出力しません。

## 公開までの手順

1. **`site/content/privacy.md` と `about.md` を書き換える**
   雛形のままでは審査に通りません。運営者名・連絡先・実際に使うサービスに合わせます。
2. **`adsite check` を通す**
   説明文の欠落、リンク切れ、孤立ページ、ページ数不足がここで出ます。
3. **GitHub Pages を有効にする**
   Settings → Pages → Source を "GitHub Actions" に設定。
   `main`/`master` への push で `.github/workflows/deploy-site.yml` が公開します。
4. **Search Console にサイトを登録し、sitemap.xml を送信する**
   `https://<ドメイン>/sitemap.xml`。ここをやらないと認識まで余計に時間がかかります。
5. **数週間運用してからAdSenseに申請する**
   公開直後の申請は落ちます。コンテンツが揃い、多少でもアクセスがある状態で出します。
6. **通ったら `ads.client` と各 `slot_*` を設定して再デプロイする**

## 日次・月次の運用

| コマンド | 頻度 |
|---|---|
| `adsite check` | コンテンツを足したとき |
| `adsite ingest <csv>` | 月1回。AdSenseの管理画面からCSVを落として取り込む |
| `adsite report` | 月1回。PLとRPMの確認 |
| `adsite cost add --category domain --amount N` | 固定費が発生したとき（月次で冪等） |
| `adsite ideas --dry-run` | ネタが尽きたとき。案は人がレビューして選ぶ |

CSVの落とし方: AdSense管理画面 → レポート → ディメンションに「日付」と「ページ」、
指標に「表示回数」「クリック数」「推定収益額」「ページビュー」を入れてエクスポート。
列名は英語・日本語どちらでも取り込めます。

## 想定される障害と対処

| 症状 | 原因 | 対処 |
|---|---|---|
| `リンク切れ` の警告 | 内部リンクの参照先がない | パスを直す。末尾スラッシュの有無に注意 |
| `どのページからもリンクされていない` | 孤立ページ | index かハブページから導線を張る |
| `本文量が不足` で広告非掲載 | ページが薄い | 内容を足すか、`ads: false` を明示する |
| `必須列が見つかりません` | CSVの列構成が違う | 日付と収益の列を含めてエクスポートし直す |
| CTRが10%超の警告 | 広告配置が誤クリックを誘発 | 枠の位置を見直す。放置するとアカウント停止 |
| デプロイが動かない | Pages のソース設定 | Settings → Pages → Source を "GitHub Actions" に |

## コンテンツを追加する

`site/content/` に `.md` を置くだけです。フロントマターで挙動が決まります。

```markdown
---
title: ツール名
description: 検索結果に出る説明（160字以内）
keywords: 検索, キーワード
tool: my-tool          # 対応するJSを /assets/tools/my-tool.js に置く
priority: 0.8
updated: 2026-08-31
ads: true              # false で広告非掲載
noindex: false
---

導入文。

[[tool]]               # ここにツールUIが入る

## 解説
```

ツールのJSは `site/assets/tools/<name>.js` に置き、
`window.AdsiteTools.mount("<name>", render)` で描画します。
共通ヘルパー（料金表の読み込み、入力欄の生成、値の保存）は `_common.js` にあります。

## バックアップ

`output/adsite.db` が収支の唯一の状態です。定期的にコピーしてください。
サイト自体は `site/` から再生成できるので、失っても復旧できます。
