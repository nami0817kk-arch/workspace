# puzzle-book-maze

Amazon KDP のペーパーバック（迷路パズル本）の入稿用PDFを組むプロジェクト
（収益化プラン 方式5）。パズルの生成自体は共有ライブラリ
`libs/puzzle-generator` が持ち、ここでは紙面のレイアウトだけを行う。

## 使い方

```
pip install -r requirements.txt
python src/build_book.py --count 60 --difficulty medium --out output/interior.pdf
```

`output/` は `.gitignore` 済み（生成物は都度作り直せるので置かない）。

## 現状（骨組み）

- 表題ページ → 問題ページ（1ページ1問）→ 解答ページ（1ページ4問）の
  順で1つのPDFを組む
- 日本語は Noto Sans JP（OFL、`assets/fonts/`）を埋め込んでいる。
  reportlab 標準フォントは日本語グリフを持たず文字化けするため
- **KDP入稿前に確認が要ること**（`build_book.py` 冒頭のdocstring参照）:
  - トリムサイズ（今は仮に8.5×11インチを使用）
  - 綴じ側マージン（gutter。ページ数で必要値が変わる。KDPのテンプレートと照合）
  - 表紙は別（このPDFは本文＝interiorのみ）
- まだ無いもの: 表紙データ、奥付・著作権表記ページ、目次

## テスト

```
pip install -r requirements.txt pypdf pytest
pytest
```
