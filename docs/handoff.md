# いま詰まっていること

**2026-08-31 に ① と ② を片付けた。** 残りは ③ だけで、これは設定ではなく
「本数を出していない」というだけのもの。`doctor` の × も1件になった。

```bash
python -m src.cli doctor    # まずこれで現状を見る
```

以下、①と②に何をしたかを残しておく（同じ確認を繰り返さないため）。

## なぜ確かめられなかったのか

このリポジトリの作業は Claude Code のクラウド環境（ネットワークポリシー
"trusted network access"）で行った。外に出られるのは次だけだった。

| 通る | 通らない |
|---|---|
| パッケージレジストリ、GitHub、Anthropic API | ニュースサイト全般、RSSフィード、x.com、claude.ai |

検索は「見出しとURLだけ」返る状態で、記事本文は開けなかった。
**「見出しに書いてあることしか使わない」という編集ルールは、
もともとこの制約から生まれたもの**で、ネットが開いたあとも
（AI要約が捏造するため）そのまま守る価値がある。

**これは解決した。** ①②はこのWindows実機で片付けた。フィードも公式サイトも
公式PDFも普通に開ける。下の `blocked:` の測り直しも、いまなら回せる。

---

## ① RSSフィード ― 済（2026-08-31）

`fetch --check` を実機で回したところ、書いてあった8本は**すべて生きていた**。
死んだURLは無し。全部 `verified: true` にした。

ただし Sky だけ差し替えた。`/rss/12040` は**全競技の「News」**で、
20件のうちサッカーは7件しかなく、クリケット・競馬・F1・テニス・ゴルフ・NFLが
混ざってくる。枠の3分の2が無駄になっていた。

| | |
|---|---|
| `/rss/11661` | **Sky Sports Football。** 20件すべてサッカー。これに差し替えた |
| `/rss/12691` | **Transfer Centre。** 20件すべて移籍の話。期限日に効くので足した |
| `/rss/11660` | Premier League。最新が2025年4月で止まっている。**使わないこと** |

いまは9本。`doctor` の「RSSフィード」は ✓。

### フィードを足すとき

```bash
python -m src.cli fetch --discover "https://www.skysports.com/football"
python -m src.cli fetch --url "https://..."    # 見出しを20件出す。設定は触らない
```

`--discover` はそのページが宣言しているフィードを返す。**当て推量をしないこと。**
連番のIDから中身は読めないし、検索エンジンのAI要約は当てにならない
（11095 が全スポーツ版かサッカー版かで食い違う答えを返してきた）。

**生きていることと、狙った内容が返ることは別の話。** Sky で3分の2を捨てたのが実例。
`--url` で中身を見てから `config/sources.yaml` に足す。

この確認の途中で、Windows でしか出ない不具合を3つ踏んだ。直さないと ① の確認
自体ができなかった。詳細は下の「Windows で見つかった不具合」。

---

## ② 移籍期限の日付 ― 済（2026-08-31）

5リーグすべて、リーグ／協会の公式発表まで辿って確かめた。全部 `confirmed: true`。
**推定値は4件とも間違っていた。**

| リーグ | 現地（公式） | 日本時間 | 出典 |
|---|---|---|---|
| プレミアリーグ | 9/1 23:00 BST | 9/2 07:00 | premierleague.com |
| ラ・リーガ | 9/1 23:59 CEST | 9/2 06:59 | laliga.com ＋ RFEF競技規則62条5項 |
| **ブンデスリーガ** | **8/31 20:00 CEST** | **9/1 03:00** | bundesliga.com (DFL) ＋ DFL LOS |
| セリエA | 9/1 20:00 CEST | 9/2 03:00 | FIGC 公示235号 |
| リーグアン | 9/1 19:59 CEST | 9/2 02:59 | LFP 公示 |

### 気をつけること（次に更新する人へ）

- **ブンデスリーガだけ1日早い。** 他の4リーグは9/1だが、ドイツは8/31に閉まる。
  bundesliga.com が「open from 1 July to **31 August** 2026」と書いている。
  「5大リーグは同じ日」と書いている記事が多いが、**あれは違う**
- 締切時刻は3種類に割れる（20:00 / 23:00 / 23:59）。「だいたい深夜」で埋めない
- ドイツの締切時刻は DFL のライセンス規程（LOS）の
  「letzter Tag … bis spätestens **20:00 Uhr**」。
  DFL用語集のページはいまも「18.00 Uhr」と書いているが、**これは古い**
  （2025/26 から18時→20時に変わった）
- 検索エンジンの要約は**この件でも割れた**。「9/1 20:00」と「8/31」の両方を
  自信ありげに返してくる。公式PDFと公式ページの本文を読んで決めた

### 終わったか

```bash
python -m src.cli today     # 「※日付は未確認」が消える
python -m src.cli doctor    # 「日程」が ✓ に
```

### 期限日の当日

```bash
python -m src.cli scan                                  # 特別編ぶんの検索が末尾に足される
python -m src.cli plan --routine deadline_day --write
```

節は「何が決まったか（確定）／壊れた話（報道）／数字で見ると（確定）／
世の中はどう見ているか（未確認）／これからどうなる（報道）」。
期限日は記者の投稿が飛び交うが、**それは報道どまり。
確定はクラブの公式発表まで辿ること。**

---

## ③ 6リーグを一度も扱っていない

ラ・リーガ、ブンデスリーガ、セリエA、リーグアン、エールディヴィジ、Jリーグ。
これは設定の問題ではなく、**本数を出していないだけ。** 1本作れば1つ消える。

網も検索もリーグごとに用意してある（`leagues:` に現地語の検索語と公式サイト）。

### 手順

```bash
python -m src.cli gather --league germany --hours 24    # フィードがあるリーグ
python -m src.cli gather --paste --no-feeds             # 検索結果を貼る場合

python -m src.cli lint  research/YYYYMMDD_candidates.yaml
python -m src.cli saga  research/YYYYMMDD_candidates.yaml
python -m src.cli pick  research/YYYYMMDD_candidates.yaml

python -m src.cli plan --routine morning --write        # 雛形 → 中身を埋める
python -m src.cli draft research/YYYYMMDD_morning.yaml
python -m src.cli build scripts/YYYYMMDD_morning.md
python -m src.cli review scripts/YYYYMMDD_morning.md
python -m src.cli upload output/YYYYMMDD_morning --dry-run
```

どこで止まっても `python -m src.cli today` が次の一手を1つ返す。
進み具合は `python -m src.cli stats` で見る。

### どこから手を付けるか

フィードが生きているリーグから。収集がいちばん速く、1本目までの摩擦が小さい。
フィードが全滅していたら、現地語の検索が効くドイツ・イタリアから。

---

## `blocked:` の測り直し ― 済（2026-08-31）

`blocked:` に入っていた**26サイトを運用PCから測り直したら、24件が普通に開いた。**
以前の26件は Claude Code のクラウド環境（外向きが塞がれている）で測った結果で、
サイト側の問題ではなかった。網は 62サイト → **86サイト** になった。

移した先は、その媒体だけを根拠に置ける確度で決めた。

| 移した先 | サイト |
|---|---|
| `english`（報道） | bbc.com / theguardian.com / independent.co.uk / standard.co.uk / football.london / theathletic.com / nytimes.com |
| `spanish`（報道） | marca.com / as.com / mundodeportivo.com / relevo.com / sport.es / ole.com.ar / tycsports.com |
| `french`（報道） | lequipe.fr / sofoot.com |
| `italian`（報道） | gazzetta.it |
| `japanese`（報道） | hochi.news / nikkansports.com / sponichi.co.jp |
| `stats`（報道） | transfermarkt.com / transfermarkt.de |
| `rumour`（**未確認**） | bild.de / mirror.co.uk |

- **Transfermarkt が使えるようになった。** 移籍金・契約年数の裏取りはここで引く
- **nytimes / theathletic は本文が有料。** 見出しは読める。もともと見出ししか
  使わない決まりなので支障はないが、本文を引いたつもりにならないこと
- **bild と mirror は大衆紙なので `rumour`（未確認）に置いた。**
  移籍を最初に書くことはあるが、単独では根拠にしない。
  報道扱いに上げたくなったら、2社一致を確かめてからにする

### 残った2件

| | |
|---|---|
| `telegraph.co.uk` | HTTP 402。有料の壁で、本文どころか見出しも返らない |
| `talksport.com` | 200 だが 1.3KB の入口だけ。中身は JS でしか出ない |

`verified_on` は 2026-08-31 に更新済み（`doctor` が90日で再確認を促す）。

---

## Windows で見つかった不具合（修正済み）

実運用のPCで初めて動かして出たもの。**開発コンテナが Linux だったので、
どちらもそこでは絶対に見つからなかった。**

- **出力をパイプに渡すと落ちる** … Windows はコンソール直書きなら平気だが、
  パイプやファイルに渡した瞬間 cp932 で書こうとする。kicker の見出しの `ü` や
  画面の `✓` は cp932 に無いので、そこで止まる。
  `fetch | collect` は本来つないで使う流れなので致命的だった。
  → `cli._use_utf8()` で出力を UTF-8 にそろえるようにした
- **ffmpeg のエラー文が読めない** … `text=True` だけだと読む側がロケールの
  文字コードを使うので、エラーの中身によっては読み取り自体が落ちる。
  本当の失敗理由が見えなくなる。
  → `ffmpeg.CAPTURE` で UTF-8 固定にした
- **`today` が書式で落ちる** … `%-m` というゼロ詰めを外す strftime 書式が
  Windows に無く `ValueError: Invalid format string`。
  → 月日を自分で組み立てるようにした

`tests/test_cli_output.py` に戻り防止を置いてある。

同じ種類の事故を疑うなら、ファイル入出力は全箇所 `encoding="utf-8"` 指定済み
（監査済み）。残るリスクは外部プロセスの出力を読むところ。

## クラウド環境でも音声つきでビルドできる

制約の中で1つ大きく開けた。**VOICEVOX CORE はクラウド環境でも組める**
（取得元が GitHub Releases で、GitHub はクラウド環境からも通るため）。

```bash
bash scripts/setup_voicevox_direct.sh   # クラウド環境用（Linux x64・約5GB）
```

公式ダウンローダ（setup_voicevox_core.py）はクラウド環境では動かない。
GitHub API でファイル名を聞く設計で、そこだけが通らない（認証は Bad
credentials・匿名はレート制限）。上のスクリプトはファイル名を確かめ済みの
直接URLで取るので API を使わない。ふつうのPCでは公式のほうを使えばよい。

vendor/ は .gitignore 済みで、コンテナは使い捨て。新しいクラウドセッションでは
スクリプトを回し直すこと（約10分）。

これでクラウド側でも `build` が音声つきで最後まで通る
（実測: 2分36秒の動画、review 全✓）。**クラウドの限界は「情報を取る」だけになった。**

## 変わらないこと

ネットワークが開いても、次の2つは変わらない。

- **X（旧Twitter）は別問題。** ページは開けてもログインなしでは投稿本文が読めない。
  `api.x.com` は有料プランのトークンが要る（`X_BEARER_TOKEN` を環境変数で渡す設計にしてある。
  **ファイルに書かないこと**）
- **AI要約は使わない。** 検索エンジンの要約が事実でないものを混ぜてくるのは
  ネットワークの制約とは無関係。本文が読めるようになったら
  「要約に頼らず原文を引く」を徹底する方向に効く
