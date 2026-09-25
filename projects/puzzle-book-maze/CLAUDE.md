# puzzle-book-maze

収益化プラン 方式5（Amazon KDP パズル本）。関連文書:
`docs/session-briefs/method5.md`、`docs/monetization-plans.md`、
`docs/public-identity.md`（公開名義は「つるはし社」のみ。個人名を出さない）。

- パズルの生成・検証は `libs/puzzle-generator` の責務。ここでは
  紙面のレイアウトだけを持つ。生成ロジックをここに複製しないこと
  （方式7 と共有しているため、ここで直しても方式7には反映されない）
- 出力形式が変わったら `libs/puzzle-generator/SCHEMA.md` を先に見る
- 日本語フォントは `assets/fonts/`（Noto Sans JP、OFL）に同梱してあり、
  soccer-manager / soccer-career と同じ書体・同じライセンス表記。
  reportlab 標準フォントには日本語グリフが無く文字化けする
  （2026-09-25 に実際に見つけた。自動テストは通っていたが、
  PDFを画像化して目で見るまで気づかなかった）
- **紙面の実サイズ・綴じ側マージンは未確認のまま。** KDP登録後、
  実際のペーパーバック版下テンプレートと照合してから入稿すること
- 表紙・奥付・著作権表記ページはまだ無い。入稿前に必要
- 「数独」等ニコリの登録商標には触れていない（迷路のみのため）。
  ナンプレを足す場合は方式5のブリーフの商標節に従うこと
