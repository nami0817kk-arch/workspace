# 公開名義・ドメイン・連絡先

**外向きに出すもの（名前・URL・連絡先）の唯一の正。** 公開ページ・ストア掲載文・
X への投稿・問い合わせ先を書くときは、まずここを見る。

2026-09-25 に、それまで `*.pages.dev` に散っていた公開サイトを 1 つのドメインの
サブドメインへ寄せた。ここはその結果を書いたもので、各PJTの設定はここの写しではなく
**それぞれの設定ファイルが正**（下の表の「設定の置き場所」）。

## 名義

| 項目 | 値 |
|---|---|
| 公開名義 | **つるはし社**（屋号。個人による運営） |
| 問い合わせ | **info@dailyquarry.com** |

**個人名・Windows のユーザー名・生年を公開物に出さない。**
kabu-agari-ranking には、生成した全HTMLを走査して混入を止めるテストがある
（`test_公開ページに個人名を出さない`）。他のPJTで公開物を作るときも同じ線を引く。

問い合わせは **Cloudflare の Email Routing（無料）** で受け、個人のメールへ転送する。
**転送先アドレスはリポジトリに書かない**（workspace は public）。受け側だけを置く。
2サイトで同じ窓口を共有しているのは、転送規則を増やさないため。

**ページに書くときは `mailto:` を使わない。** Cloudflare の Email Address
Obfuscation が `mailto:` のリンクを `[email protected]` に差し替え、JS で復号する形に
変える。JS が動かない相手からは連絡先が読めず、**AdSense の審査はまさにそこを見る**。
`@` を `[at]` に割った素のテキストで書き、「送信時は @ に置き換えてください」と
添える（2サイトともこの形）。2026-09-25 に kabu で実際に化けているのを見て直した。

## ドメイン

`dailyquarry.com` を 2026-09-25 に **Cloudflare Registrar** で取得した。
原価販売（上乗せなし）で、WHOIS の代理公開・DNSSEC・メール転送が追加費用なしに付く。
**1つ取ってサブドメインを足す形**にしてあるので、サイトが増えても追加費用はかからない。

| サブドメイン | PJT | 設定の置き場所 |
|---|---|---|
| `kabu.dailyquarry.com` | kabu-agari-ranking | `projects/kabu-agari-ranking/src/site_config.py` |
| `kakaku.dailyquarry.com` | price-tracker | `projects/price-tracker/config.json` |

新しいサイトを公開するときは、`<名前>.dailyquarry.com` を Cloudflare Pages の
カスタムドメインに足す。DNS は Cloudflare が自動で引くので、こちらの作業は
**Pages プロジェクトの Custom domains に足すだけ**。

### ドメイン名に検索上の効果は無い

ドメインにキーワードを入れても順位は上がらない（Google の EMD アップデート、2012年）。
`kabu-ranking.com` のような名前を取りに行く理由は無いので、**短くて覚えやすいほうを選ぶ**。

## Search Console

**所有確認タグは Google アカウント単位で、ドメインが変わっても同じ値になる。**
2026-09-25 に kakaku と kabu で同じ値が出ることを実測した。

現在の値: `JLPv6DMxv7h91q8Hzvo-YfdQx6mz-_zZ-MhHaNzPs4c`

新しいサブドメインを登録するときは、コードに既にこの値が入っていればそのまま通る。
画面に別の値が出たときだけ差し替える（DNS の TXT で確認する手もあり、
そちらならコードを触らずに済む）。

- ドメインを移したら、Search Console に**新しい URL プレフィックスのプロパティを作り直す**。
  古いプロパティの数字は引き継がれない。
- 移したあとは sitemap を送信し直す。

## AdSense

- **`*.pages.dev` では申請できない。** 自分のドメインが要る。これが
  `dailyquarry.com` を取った直接の理由。
- サブドメインは**1回の申請で全部まとめて扱われる**（`ads.txt` で紐づく）。
  サイトごとに申請し直す必要は無い。
- 審査は「誰が運営し、どこへ連絡できるか」が読めることを求める。
  **運営者情報・プライバシーポリシー・問い合わせの3枚が揃うまで出さない。**
  kabu は 2026-09-25 に3枚とも揃えた（`projects/kabu-agari-ranking/templates/`
  の `operator.html` / `privacy.html` / `contact.html` が先例）。
- 広告タグを出すのは `render.ADSENSE_CLIENT` の1箇所だけ。
  **審査前にプレースホルダの `<ins>` を置かない**（中身の無い点線の箱が並ぶだけ）。

## 楽天アフィリエイト（price-tracker だけの制約）

楽天ウェブサービスの規約により、price-tracker には次ができない。
**ここを踏むと API の利用資格ごと失う**ので、他PJTの都合で緩めない。

- AdSense・他社アフィリエイトの掲載（第8条4項）
- 取得データの販売・API としての再公開（第10条1項・4項）
- 他サイトへのリンク（第10条7項・9項）

つまり **price-tracker は AdSense の対象外**。収益は楽天アフィリエイトのみ。
