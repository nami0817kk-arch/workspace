# puzzle-book

KDP の紙のパズル本。**ことば探し**（`src/build_kotoba.py`、1冊目 `books/kotoba-vol1.json`）と
**迷路**（`src/build_book.py`、`books/vol1.json`。売れ行きの比較で見送り、入稿データのまま保留）。
2026-09-26 に `puzzle-book-maze` から改名した（フォント12MBを二重に持たないため）。

収益化プラン 方式5（Amazon KDP パズル本）。関連文書:
`docs/session-briefs/method5.md`、`docs/monetization-plans.md`、
`docs/public-identity.md`（公開名義は「つるはし社」のみ。個人名を出さない）。

- パズルの生成・検証は `libs/puzzle-generator` の責務。ここでは
  紙面のレイアウトだけを持つ。生成ロジックをここに複製しないこと
  （方式7 と共有しているため、ここで直しても方式7には反映されない）
- 出力形式が変わったら `libs/puzzle-generator/SCHEMA.md` を先に見る
- **KDP の寸法・費用は `src/kdp_spec.py` に集めてある**（出典の topic ID 付き、2026-09-26 に
  kdp.amazon.co.jp の公式ヘルプで確認）。別の場所に数字を直書きしない
- 1冊 = `books/<slug>.json` 1つ。巻を増やすときは `seed_start` をずらす（問題が重ならない）
- **amazon.co.jp の大判は 108 ページまで印刷コストが一律 530 円。** 超えると1ページ3円ずつ
  印税が減るので、問題数はこの枠に収まるように決める（`test_vol1_stays_in_flat_print_cost`）
- 日本語フォントは `assets/fonts/`（Noto Sans JP、OFL）に同梱してあり、
  soccer-manager / soccer-career と同じ書体・同じライセンス表記。
  reportlab 標準フォントには日本語グリフが無く文字化けする
- **同梱フォントには無い字がある（© が無い）。** 無い字は四角に化け、自動テストでは
  見えなかった。紙面の全文字を字形の有無で確かめるテストがある（`test_every_character_has_a_glyph`）
- **PDF は必ず画像にして目で見る。** 2026-09-25 の文字化けも、2026-09-26 の
  「スタートとゴールの入口が無い」も、テストは通っていて画像で初めて分かった
- 表紙の絵は生成器の盤面を描いている（画像生成AIを使わない）。迷路本の AI 申告は「いいえ」。
  **ことば探しは語の一覧を Claude が書いたので、テキストの AI 申告は「はい」**
- ことば探しは高齢者・介護の現場向け。逆向きには並べない（→↓、むずかしいで↘）。
  埋め草で不適切な語ができないことを生成器が検査している（`BLOCKED_WORDS`）
- 矢印の字形（↘など）も同梱フォントに無いものがある。向きは言葉で書く
- 「数独」等ニコリの登録商標には触れていない（迷路のみのため）。
  ナンプレを足す場合は方式5のブリーフの商標節に従うこと
- 題名は J-PlatPat の商標（第16類）で確かめてから決める。確認の記録は README の表
