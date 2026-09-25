# shaho-tekiyo — 社会保険 加入判定チェッカー

社会保険（健康保険・厚生年金）の短時間労働者への適用拡大について、
「自分は加入対象になるか」を厚生労働省の公表基準に沿って判定する計算機。
広告収入が目的。**方式1（`docs/session-briefs/method1.md`）の中で最優先の案。**

公開予定URL: https://shaho.dailyquarry.com/（AdSense・ドメインは `projects/ipa-kakomon` と共用）

企画書: https://claude.ai/artifact/JvCm7MmGbxE1y7gz9jEgcH

## v1 のスコープ（2026-09-26 時点）

**加入判定チェッカーのみを公開する。保険料の金額試算（手取りがいくら減るか）は次のフェーズ。**

理由: 手取り試算には協会けんぽの都道府県別健康保険料率が要るが、**このクラウドセッションの
ネットワーク方針が `kyoukaikenpo.or.jp` への到達を遮断しており、一次情報を確認できなかった**
（`curl` でも `CONNECT tunnel failed, response 403`）。WebSearch経由で全国平均9.9%・介護保険料率1.62%
などの数字は複数の社労士事務所サイトから得られたが、47都道府県ぶんの一次情報は未確認のまま。
不正確な金額を「計算結果」として出すより、**確認できた部分（加入要件は法定で、期日・人数は
企画書と厚労省サイトに一致するもの）だけを先に出す**方を選んだ。

次にやること（次のセッションかユーザー）:
1. このクラウド環境のネットワーク設定で `kyoukaikenpo.or.jp` への到達を許可する、
   または一次情報（都道府県別保険料額表 R8年度）を取得してこのリポジトリに置く
2. `src/rates.py` を新設し、47都道府県ぶんの健康保険料率・介護保険料率（令和8年度）を
   一次情報から転記する（**料率は毎年3月に改定される。表は1箇所にまとめ、範囲外の年は
   黙って計算せず例外にする** — `eligibility.ScheduleOutOfRange` や
   `kabu-agari-ranking/src/market_calendar.py` と同じ形にする）
3. `src/calc.py` で手取り概算を実装し、計算機に「保険料はどれくらい引かれるか」を追加する
4. 都道府県別ページ（企画書にある47ページ）を追加する

## 仕組み

- `src/eligibility.py` — 判定ロジックの正。`SCHEDULE`（企業規模要件・賃金要件が変わる時点の表）は
  **法定の日程なので、料率と違って毎年の更新は不要**。国会で日程自体が変わったらここを直す。
- `src/render.py` — Jinja2 テンプレートから `output/` に静的HTMLを生成する。
  `kabu-agari-ranking/src/render.py` と同じ形（`canonical_url`・sitemap・robots.txt の作り方）。
- **計算機はブラウザだけで完結する。** `templates/calculator.html` に `eligibility.SCHEDULE` を
  JSON で埋め込み、同じロジックを vanilla JS で実装している（サーバーには何も送信しない）。
  **2箇所に別々のロジックを持つと必ずずれるので、`tests/test_render.py` の
  `test_計算機に埋め込まれたスケジュールがeligibilityと一致する` で、埋め込まれたJSONが
  `eligibility.SCHEDULE` と完全に一致することを固定している。** JS 側のロジックを変えたら、
  Python 側 (`eligibility.regime_for` / `evaluate`) も同じ変更をすること。
- 年次ページ（`templates/year.html`、5ページ）は `eligibility.MILESTONES`
  （2026-10-01 以降の5段階）から自動生成する。読み物としての説明文は
  `render.py` の `_MILESTONE_NOTES` に分けて持つ（`SCHEDULE` 自体は判定に使う数字だけ）。

## 手を入れるときに気をつけること

- **加入の可否を断定しない。** 出すのは公表基準に照らした結果で、個別の事情
  （複数事業所勤務・特殊な雇用形態など）は年金事務所・社労士へ、と全ページの
  `.disclaimer`（`templates/base.html`）で必ず断っている。文面を削らないこと。
- **「106万円の壁」と「130万円の壁」を混同しない。** 前者は自分が勤務先の社会保険に
  入るかどうか（このサイトの対象）、後者は配偶者・親の扶養から外れるかどうかで別制度。
  `templates/faq.html` で明示的に書き分けている。
- 学生の除外規定（夜間部・定時制課程・休学中は対象外に当たらない）は一般的な取り扱いとして
  紹介しているが、一次情報（日本年金機構）での確認はまだ。断定的な書き方にしないこと。
- 継続雇用2か月超の要件は、入力項目にせず前提として注記している（通常の継続雇用なら
  満たすため。UIを複雑にしない判断）。
- 公開名義・ドメイン・AdSense・連絡先は `docs/public-identity.md` が正。
  個人名は出さない（`tests/test_render.py` の `test_公開ページに個人名を出さない`）。

## よく使うコマンド

```bash
pip install -r requirements.txt pytest
pytest                  # テスト
python src/render.py    # output/ を生成
```
