# いま詰まっていること

`python -m src.cli doctor` が × を3件出す。**いずれも「まだやっていない」のではなく、
開発コンテナから外に出られなくて確かめられなかったもの。**
ネットに出られる環境なら、そのまま片付けられる。

```bash
python -m src.cli doctor    # まずこれで現状を見る
```

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

解き方は2つ。

- **A** … 環境のネットワークポリシーを広げ、新しいセッションを開く
- **B** … ローカルPCで `claude` を起動する（実機なので制約がない）

---

## ① RSSフィード8本がすべて未確認

`config/sources.yaml` の `feeds:`（160行目あたり）。URLは書いたが、
**生きているかを一度も確かめていない。** そのため全部 `verified: false` で、
`gather` はフィードを1本も読みに行かない。

### 手順

```bash
python -m src.cli fetch --check
```

```
■ フィードの生死確認　8本
  ✓ Sky Sports News　30件　最新 1.2時間前
  × kicker　取得できません: HTTP 404
```

`config/sources.yaml` を直す。

- ✓ … `verified: false` → `verified: true`
- × … その行を消す。または正しいURLに差し替える
  （サイトのHTMLソースで `application/rss+xml` を検索すると見つかる）

**生きていることと、狙った内容が返ることは別の話。**
Sky は全スポーツ版とサッカー版が別URLで並んでいて、全スポーツ版を引くと
クリケットも競馬もゴルフも混ざる（実測）。差し替える前に中身を見ること。

```bash
python -m src.cli fetch --discover "https://www.skysports.com/football"
python -m src.cli fetch --url "https://..."    # 見出しを20件出す。設定は触らない
```

`--discover` はそのページが宣言しているフィードを返す。**当て推量をしないこと。**
連番のIDから中身は読めないし、検索エンジンのAI要約は当てにならない
（11095 が全スポーツ版かサッカー版かで食い違う答えを返してきた）。

### 終わったか

```bash
python -m src.cli fetch --hours 12    # 見出しが流れてくるか
python -m src.cli doctor              # 「RSSフィード」が ✓ に
python -m src.cli gather              # ここから使えるようになる
```

---

## ② 移籍期限4件の日付が未確認

`config/sources.yaml` の `calendar.deadlines`（149行目あたり）。
イングランドだけ確認済み。**残り4リーグは推定値**なので `confirmed: false` で入れてある。
告知には「※日付は未確認」が付く。

### 手順

各リーグの発表で確かめる。

| リーグ | 確かめ先 |
|---|---|
| ラ・リーガ | laliga.com |
| ブンデスリーガ | bundesliga.com |
| セリエA | legaseriea.it |
| リーグアン | ligue1.com |

```yaml
- {league: spain, at: "2026-09-02 07:00", local: "現地 9/2 00:00 CEST", confirmed: false}
```

- `at` は**日本時間**で書く（現地23:00 BST → 日本の翌朝07:00）。
  ここを現地時刻のまま書くと告知が丸ごとずれる
- 確かめられたものだけ `confirmed: true` にする。
  **確かめられなかったものは false のまま残す。** 確かめたふりをしない

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

## ネットワークが開いたら、もう1つやる価値があること

`config/sources.yaml` の `blocked:` に**26サイト**入っている。

```
bbc.com / theguardian.com / theathletic.com / marca.com / as.com /
transfermarkt.com / football.london / lequipe.fr / gazzetta.it / bild.de ...
```

**これは全部、制限つきの環境で測った結果。** ネットワークを開けたら測り直すべきで、
半分でも開けば情報源の網（現在62サイト）が大きく広がる。
特に Transfermarkt が使えると、移籍金・契約年数の裏取りが桁違いに楽になる。

測り直したら `verified_on` の日付も更新すること（`doctor` が90日で再確認を促す）。

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
