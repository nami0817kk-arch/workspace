# dailyquarry-home — dailyquarry.com（ルート）の入口

**AdSense をサブドメインのサイトで使うために置いたPJT**（2026-09-26）。

AdSense はサイトを**ルートドメイン単位**で扱う。サブドメイン（kabu. / shaho. など）は
サイトとして足せず、申請するのは `dailyquarry.com`、`ads.txt` もルートの
`https://dailyquarry.com/ads.txt` に置く必要がある
（[サイト管理の変更](https://support.google.com/adsense/answer/12170421?hl=ja)、
[ads.txt の FAQ](https://support.google.com/adsense/answer/9785052?hl=ja)）。
それまでルートには何も出ておらず、所有確認も ads.txt も置き場が無かった。

中身は、運営しているサイトの一覧・運営者情報・プライバシーポリシー・問い合わせの4枚と、
pub-ID が入ったときの `ads.txt`。

## 動かし方

```
pip install -r requirements.txt pytest
python src/build.py     # output/ に書き出す
pytest
```

master への push で `.github/workflows/dailyquarry-home-deploy.yml` が
Cloudflare Pages（プロジェクト名 `dailyquarry-home`）へ公開する。

## AdSense の手順

1. **利用者:** Cloudflare のダッシュボードで Pages の `dailyquarry-home` に
   カスタムドメイン `dailyquarry.com` を足す（1回だけ。DNS は自動で引かれる）
2. **利用者:** AdSense に登録し、サイト `dailyquarry.com` を追加する。pub-ID（`ca-pub-...`）を控える
3. pub-ID を次の3箇所に入れて push する（同じ値）
   - `projects/dailyquarry-home/src/site_config.py` の `ADSENSE_CLIENT` … ルートの ads.txt と所有確認
   - `projects/kabu-agari-ranking/src/site_config.py` の `ADSENSE_CLIENT`
   - `projects/shaho-tekiyo/src/render.py` の `ADSENSE_CLIENT`
4. `https://dailyquarry.com/ads.txt` と各サイトの `<head>` にスクリプトが出たのを確かめてから、
   AdSense の画面で審査を申し込む

**price-tracker（kakaku.）には入れない。** 楽天ウェブサービス規約 第10条1項(4) で
AdSense を載せられない（`docs/public-identity.md`）。テストで固定してある。

## 気をつけること

- 入口に並べるのは `site_config.SITES` だけ。**独自ドメインで開けるものだけ**を載せる。
  開けないリンクは審査で「サイトが使用できない」に倒れうる
- 個人名・nami・0817 を出さない。`mailto:` を使わない（テストで固定）
- pub-ID が空のあいだは広告スクリプトも ads.txt も出さない。`<ins>` の枠はずっと置かない
