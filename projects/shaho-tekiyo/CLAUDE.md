# shaho-tekiyo — 社会保険 加入判定チェッカー

社会保険（健康保険・厚生年金）の短時間労働者への適用拡大について、
「自分は加入対象になるか」を厚生労働省の公表基準に沿って判定する計算機。
広告収入が目的。**方式1（`docs/session-briefs/method1.md`）の中で最優先の案。**

公開予定URL: https://shaho.dailyquarry.com/（AdSense・ドメインは `projects/ipa-kakomon` と共用）

企画書: https://claude.ai/artifact/JvCm7MmGbxE1y7gz9jEgcH

## できていること（2026-09-26 時点）

- **加入判定**（`src/eligibility.py`）。日程は一次情報で確認済み。賃金要件の撤廃日は
  令和8年政令第275号（2026-09-11 公布）で **2026-10-01** に確定している。
  厚労省・年金機構のページは公布前の「撤廃予定」のまま
- **保険料の目安**（`src/premium.py`）。協会けんぽ 令和8年度 保険料額表（47都道府県）の料率で、
  健康保険（40〜64歳は介護込み）・子ども・子育て支援金・厚生年金の本人負担を出す。
  **収録範囲は 2026-04-01〜2027-02-28**。範囲外の時点では金額を出さない

クラウドのセッションが v1（加入判定のみ）を作り、2026-09-26 に PC のセッションが一次情報で
読み直して保険料の目安を足した。

### 毎年やること（料率の改定）

協会けんぽの料率は**毎年3月分から改定**され、例年2月ごろに新しい額表が出る。
**やらないと 2027-03-01 以降は「今日時点」でも金額が出なくなる**（間違った金額は出さない作り）。

1. 協会けんぽの「保険料額表」のページから、エクセル版（全都道府県分）を落とす
2. `python tools/import_kyoukaikenpo.py <xlsx> --fiscal-year 2027 --valid-from 2027-03-01 --valid-until 2028-02-29 --xlsx-url <URL>`
   （openpyxl が要る。額表の全等級の折半額と照合して、ずれたら書き出さずに止まる）
3. `src/premium.py` の `RATE_FILES` に1行足す。古い年度のファイルは消さない
4. `tests/test_premium.py` の期待値（北海道の額表の数字）を新しい額表で足す

**4月にもう1つ**: 雇用保険料率と国民年金保険料は4月から変わる。`data/other_rates.json` の
`employment` と `kokumin_nenkin` に新しい年度を1件ずつ足す（出典の URL も）。やらないと4月以降は
雇用保険料・手取り・国民年金との比較が出なくなる（間違った額は出さない作り）。
`src/render.py` の `HISTORY`（計算方法と出典のページの更新履歴）にも1行足す。

等級表（標準報酬月額の区切りと上限）も額表から読むので、制度改正で等級が変わっても
取り込みで入る。ただし import は全都道府県で等級表が同じことを前提にしている。

### まだやっていないこと

- 都道府県別の料率ページ（企画書の47ページ）
- 公開（Cloudflare Pages のプロジェクト作成とカスタムドメイン `shaho.dailyquarry.com`）

## 仕組み

- `src/eligibility.py` — 判定ロジックの正。`SCHEDULE`（企業規模要件・賃金要件が変わる時点の表）は
  **法定の日程なので、料率と違って毎年の更新は不要**。国会で日程自体が変わったらここを直す。
- `src/render.py` — Jinja2 テンプレートから `output/` に静的HTMLを生成する。
  `kabu-agari-ranking/src/render.py` と同じ形（`canonical_url`・sitemap・robots.txt の作り方）。
- **計算機はブラウザだけで完結する。** `templates/calculator.html` に `eligibility.SCHEDULE` と
  料率（`data/*.json`）を JSON で埋め込み、計算は `static/calc.js` が行う（サーバーには何も送信しない）。
  **JS は Python（`eligibility.py`・`premium.py`）の写し。** `tests/test_calc_js.py` が node で
  calc.js を動かし、判定と保険料が Python と全件一致することを確かめている。
  片方を直したら、もう片方も同じように直すこと。
- `src/extras.py` と `data/other_rates.json` — 雇用保険料・国民年金保険料・将来の年金（報酬比例 5.481/1000）・
  傷病手当金（標準報酬月額÷30×2/3）。calc.js に同じ計算があり、`tests/test_calc_js.py` が突き合わせる
- `data/kyoukaikenpo_<年度>.json` — 料率の正。手で書き換えない（`tools/import_kyoukaikenpo.py` で作る）。
  料率は 1/100000 単位の整数（10.28% → 10280）。端数処理は「50銭以下切り捨て・超えたら切り上げ」
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
- 学生の扱い（卒業前に就職・夜間/定時制・休学中は加入対象）は日本年金機構のページで確認済み。
- **保険料は労使折半のままの額。** 2026年10月から、勤務先が本人負担を肩代わりすると国が支援する
  「保険料調整制度」（3年間）がある。使うかどうかは勤務先次第なので、計算には入れず注記だけしている
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
