# docparse — PDF から本文と表を、ページ番号つきで抜く

決算短信・有価証券報告書・官公庁の資料といった**一次情報の原文**を機械で読む道具。
`imagegen feed --source edinet` で見つけた書類や、`browser control pdf` で残したページを
そのまま渡す想定。

```bash
docparse info 決算短信.pdf                # ページ数・文字の有無・表の数
docparse find 決算短信.pdf 営業利益        # 語を含む行をページ番号つきで探す
docparse text 決算短信.pdf --pages 1-3     # 本文を出す
docparse tables 決算短信.pdf -d output/    # 表を CSV に書き出す
```

```
$ docparse find 決算短信.pdf 利益
p.1  営業利益 1,234 百万円
       数値: 1,234=1234.0
p.1  経常利益 △567 百万円
       数値: △567=-567.0
```

## 準備

このリポジトリで唯一、**標準ライブラリだけでは代替できない**処理なので依存を認めている。

```bash
pip install -e ".[docs]"     # pdfplumber
```

## 決めごと

### ページ番号を必ず持ち回る

抜き出した行にも表にも、必ず出典のページ番号が付く。
**出典を言えない数字は一次情報として使えない**（引用のたびに人が原文を開き直すことになる）。
`docparse text` が本文を連結するときも `--- p.2 ---` の区切りを残す。

### △ と ▲ は負数

決算資料の負数は `△567` や `▲1,234` と書かれる。素直に `float()` に通すと符号が消え、
**減益を増益と読む**ことになる。変換は `search.to_float` の1箇所に集めてテストで固定してある。
全角マイナス（`−`）と桁区切り（`,`）も同じところで吸収する。

読めなかったものは `None` を返す。**0 とは違う**ので、勝手に 0 にしない。

### 文字の無い PDF は、はっきり失敗させる

紙をスキャンしただけの PDF（画像しか入っていない）に空文字を返すと、
「本文が無い書類」と区別がつかず、読み落としたことに気づけない。
そういう PDF は `NoTextLayer` で止めて、OCR が要ることを伝える。

### 表は、崩れたまま捨てない

PDF の表は結合セルのせいで行ごとに列数がずれる。短い行を捨てると数字が落ちるので、
**足りないぶんは空欄で埋めて残す**。逆に、罫線だけを拾った中身の無い表は落とす
（空の表が並ぶと、本当に中身のある表が埋もれる）。

## 構成

```
src/docparse/
  extract.py   PDF を読むところ。外部ライブラリに触るのはここだけ
  document.py  Page / Document（ページ番号つき）とページ範囲の解釈
  search.py    語の検索と数値の読み取り（△ の扱いはここ）
  tables.py    表 → CSV / Markdown
  cli.py       コマンドの入口
```

`extract.py` に依存を閉じてあるので、他のモジュールは pdfplumber が無くてもテストできる。
読み取り部分は `extractor` 引数で差し替えられる。

## Python から使う

```python
from docparse import extract, search

document = extract.load("決算短信.pdf", pages=[1, 2])
for hit in search.find(document, "営業利益"):
    print(hit.page, hit.line, [search.to_float(n) for n in hit.numbers])
```

## つながり

```bash
imagegen feed "7203" --source edinet          # 提出書類を見つける
# 原文PDFを手元に置く（ブラウザで開いている場合）
python -m browser.control links --filter .pdf
python -m browser.control pdf output/genpon.pdf
docparse find output/genpon.pdf 営業利益      # 数字を出典つきで拾う
```
