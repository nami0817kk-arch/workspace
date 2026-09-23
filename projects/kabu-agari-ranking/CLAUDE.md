# kabu-agari-ranking

日本株の値上がり/値下がり/活況ランキングを平日毎日取得し、静的サイトとして公開する。
広告による収益化が目的なので、**サイトが止まること・中身が空になることが一番の損失**。

公開URL: https://kabu-agari-ranking.pages.dev/

## 前提

- Python 3.12。依存は `requirements.txt` に `==` で固定してある。
  上流の新版で毎朝のジョブが勝手に壊れるのを防ぐため、**`>=` に緩めない**。
  更新は Dependabot の PR で受け取り、CI が通るのを見てから上げる。
- 取得先は kabutan.jp のHTML。先方の都合で構造が変わりうる。

## よく使うコマンド

```bash
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt pytest

pytest                      # テスト
python src/build_site.py    # 取得 → data/ 保存 → output/ 生成
```

## 手を入れるときに気をつけること

- kabutan の HTML 取得・解析は **共有パッケージ [kabutan-client](https://github.com/nami0817kk-arch/kabutan-client)** にある
  （quality-gainer-tracker と共通）。列位置の依存・解析の修正は kabutan-client 側で行い、
  こちらは requirements.txt のコミット固定を進めて取り込む。
  `src/fetcher.py` に残っているのはランキングの組み立て（絞り込み・順位付け）だけ。
- `_extract_asof_date` は休場日対策。取得日ではなくページ上の終値日付を使う。
  ここを `date.today()` に戻すと、休日実行で日付がずれる。
- `render._normalize_day` は旧形式（`rows`/`gain_pct`/`volume`）の変換。
  消すと過去のアーカイブが読めなくなる。
- `data/*.json` は CI が自動コミットしている実データ。手で消さない。
- `output/` は毎回作り直すビルド成果物（gitignore 済み）。
- 秘密情報は `.env`（gitignore 済み）か GitHub Secrets へ。
  必要なキーは `.env.example` にある。
- **取得は手元PCのタスクスケジューラ**（run-daily.ps1、毎平日16:10）が行い、data/ を push する。
  kabutan は GitHub Actions の IP を 405 でブロックするため、CI から取得する形に戻さない。
  CI は push された data/ からのビルド・公開と、17:00 JST の鮮度監視を担当する。
  **X への投稿は手元の run-daily.ps1 から**（重複投稿を防ぐ記録 data/last_tweet.txt が
  残る場所が手元しか無いため）。キーが未設定なら何もせず飛ばす。
- **ページは取れたのに0件、は休場日ではない。** 休場日でも kabutan は直近営業日の
  ランキングを出すので、0件なら解析が壊れている。`fetcher.parse_failures` に記録し、
  build_site.py が exit 1 にする（run-daily.ps1 が通知を出す）。
- **保存の前に `src/validate.py` が検査する。** 日付がその時点で出るはずの相場日と
  違う、件数が少なすぎる、騰落率が全て0、といったものは保存せずに落とす（exit 1）。
  data/ は取り直しがきかないので、疑わしいものを弾いてその日を落とすほうがまし。
  検査が誤って弾いたときは中身を見たうえで `--force` を付けて実行する。
- **取り逃した営業日は二度と取れない。** kabutan のランキングは当日分しか出さないので、
  取得が失敗した日はその日のうちに再実行する（翌日には次の営業日に切り替わっている）。
  16:10 の自動実行が失敗していたら、気づいた時点で `src/build_site.py` を手で回す。
- **日付は `<time>` の先頭から採ってはいけない。** ページ冒頭の指数ヘッダは
  NYダウ → 国内指数の順で、先頭は米国市場の終値日。国内ランキングが1営業日ずれる
  （2026-09-07 に発生し、月曜分が金曜のファイルを上書きした）。判定は
  `libs/kabutan` の `extract_asof_date` がランキング表自身の日付から行う。
- 定期実行のワークフローには失敗時に Issue を立てるステップがある。
  ジョブを触るときはこれを消さない。**黙って止まるのが最悪の壊れ方**。
- **鮮度の警報は Deploy より後に置く。** 以前は手前にあったため、警報が出た日は
  公開まで道連れで止まった（2026-09-22）。古いデータで出続けるほうが、
  サイトが更新されないより損が小さい。
- **AdSense を有効にするのは `render.ADSENSE_CLIENT` の1箇所**。空のあいだは
  広告スクリプトも枠も一切描かない。審査前にプレースホルダの `<ins>` を置くと、
  中身の無い点線の箱が全ページに並ぶだけ。
- **ストップ高／ストップ安の判定は `src/price_limit.py`。** 東証の制限値幅の表を
  持っていて、終値と騰落率から前日終値を逆算して判定する。表の出典は
  https://www.jpx.co.jp/equities/trading/domestic/06.html （取引所が変えうる）。
  通常の値幅を超える動きは「ストップ高」と言い切らない（値幅の拡大や
  株式分割の可能性がある）。**推測で言い切らないのが要点**。
- **グラフは `src/charts.py` がビルド時に SVG を書く。** 外部のグラフ
  ライブラリは入れない（表示が遅くなり、JSを切ると読めなくなる）。
  作図の決まりは同ファイルの冒頭にまとめてある。**狭い画面基準（幅360）で
  組む**こと。PC幅で組むとスマホで縮小されて文字が読めなくなる。
  値は必ず同じページの表にも載せる（グラフでしか読めない値を作らない）。
- **日付が疑わしいときは `tools/verify_rec_date.py` で確定できる。** 株探の個別銘柄の
  日足（時系列）に過去の終値と前日比が残っているので、そこに同じ数字がある日を探す。
  2026-09-24 にこの方法で、掲載開始直後の4日分の相場日を確定させた（読み替えは
  `render.DATE_CORRECTIONS`）。**ファイル名は変えていない**（データの移動は
  取り返しがつかないため、読み込み時に読み替える）。
- **日付の書き方**: 文章の中は `format_date_ja` / `format_date_short_ja`（日本語表記）、
  表のセル・URL・sitemap は ISO。混ざると読みづらく、直すたびに揺れる。
- 休場日の判定は `src/market_calendar.py` の祝日表（内閣府CSVから転記）。
  **表は2027年までしか無く、範囲外は例外にしてある**（黙って平日扱いにしない）。
  年末に一度 https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv から追記する。
