# tabi-kion — 旅先の気温と服装

旅行先の「その月」の気温・上中下旬の変化・雨や雪の日数・出発地（東京・大阪）との差と、服装の目安を
1ページにまとめる静的サイト。**方式1（`docs/session-briefs/method1.md`）の案4 旅行×気候のパイロット。**
広告と宿泊予約サイトへの紹介料が目的。

公開予定URL: https://tabi.dailyquarry.com/（名義・連絡先・AdSense は `docs/public-identity.md` が正）

## なぜ作ったか（2026-09-26）

「11月 飛騨高山 気温 服装」の検索上位は、2015年の知恵袋と大雑把な旅行ページだった。
データ型の先行（Weather Spark 等）はあるが、服装の問いでは上位にいない。**上位が弱い**ので、
平年値・上中下旬・出発地との差・服装の目安を1ページにまとめれば上に行けるか、を小さく試す。
経緯と判断の基準は `docs/monetization-plans.md` の方式1の節。

**やめる基準は公開前に台帳へ書く。** 決めずに出さない。

## 仕組み

- `data/normals.json` — 数字の正。`tools/import_jma.py` が気象庁の平年値 zip から作る。手で書き換えない。
  平年値は10年ごとの更新（次は2030年平年値、2031年ごろ）。そのときに import を回し直す
- `src/stations.py` — ページを作る地点。**地点名は観測所の名前のまま**（観光地名に置き換えると、
  別の場所の数字をその観光地の数字に見せることになる）。近くの観光地は `nearby` に書き添えるだけ。
  **slug は公開後に変えない**
- `src/climate.py` — 1ページの中身。服装の区切りは `_CLOTHING` の1箇所だけ
- `src/render.py` — `output/` に静的HTML。地点×月（`/takayama/11.html`）と地点ごとの一覧

## 手を入れるときに気をつけること

- **予報は出さない**（気象業務法第17条）。平年値は過去30年の平均。全ページの `.disclaimer` と出典欄で断っている
- **服装の目安は当サイトの決めごと**。気象庁の情報のように書かない（about.html に区切りを全部載せている）
- 出典は「気象庁「平年値」をもとに当サイトで加工して作成」。気象庁の利用規約（PDL1.0 相当）の出典・加工の表示
- 楽天トラベルへのリンクを足すときは、**API を使わずリンクだけ**にする。API を使うとこのサイトは AdSense を失う
  （`docs/public-identity.md` の楽天の節）
- 個人名は出さない（`tests/test_site.py` の `test_公開ページに個人名を出さない`）

## よく使うコマンド

```bash
pip install -r requirements.txt pytest
python src/render.py    # output/ を生成
# データの作り直し（平年値の更新時）
python tools/import_jma.py normal_surface.zip normal_surface_ver5.zip
```
