# リリース手順（App Store）

出す先は **iOS だけ**。掲載する文面と絵は [`../STORE_LISTING.md`](../STORE_LISTING.md)、
収益化の設計は [`MONETIZATION.md`](MONETIZATION.md) が正。

**証明書・プロビジョニングプロファイル・GitHub Secrets の作り方は、
[`soccer-manager/docs/RELEASE_GUIDE.md`](../../soccer-manager/docs/RELEASE_GUIDE.md)
が正。** Mac なしで CSR を作る手順もそちらにある。ここには**このアプリだけの差分**を書く。

`soccer-manager` は 2026-09-24 に公開済みで、同じ手順を一度通してある。

---

## 1. このアプリの値

| 項目 | 値 |
|---|---|
| Bundle ID | `com.namiki.soccercareer` |
| タグ | `soccer-career-v*`（例: `soccer-career-v1.0.0`） |
| ワークフロー | `.github/workflows/soccer-career-ios-release.yml` |
| 広告 | **インタースティシャルだけ**（リワードは無い） |
| App内課金 | `soccer_career_no_ads`（非消耗型） / `soccer_career_tip`（消耗型） |

## 2. GitHub Secrets

**`soccer-manager` と共有するもの**（同じ Apple アカウント）:

| 名前 | 中身 |
|---|---|
| `IOS_DIST_CERT_BASE64` | 配布証明書の .p12 を base64 |
| `IOS_DIST_CERT_PASSWORD` | その .p12 のパスワード |
| `IOS_TEAM_ID` | Apple Developer の Team ID |
| `APPSTORE_API_KEY_ID` ほか2つ | TestFlight へ自動で上げるとき（任意） |

**このアプリ専用**（`_CAREER` が付く）:

| 名前 | 中身 |
|---|---|
| `IOS_PROVISIONING_PROFILE_BASE64_CAREER` | `com.namiki.soccercareer` のプロファイル |
| `ADMOB_APP_ID_IOS_CAREER` | AdMob のアプリID（`~` 区切り） |
| `ADMOB_INTERSTITIAL_IOS_CAREER` | インタースティシャルの広告ユニットID（`/` 区切り） |

> **名前を分けてあるのは、取り違えると気付けないから。**
> 同じ名前にすると `soccer-manager` のIDでこのアプリをビルドすることになる。
> プロファイルは Bundle ID ごとに別なので署名の段で落ちるが、**AdMob のIDは
> 落ちずに通る**——広告は出るのに、収益が別のアプリに付く。
> ワークフローはプロファイルの App ID と Bundle ID を突き合わせて、
> 食い違ったらその場で止める。

## 3. 出す

```bash
git tag soccer-career-v1.0.0
git push origin soccer-career-v1.0.0
```

ワークフローが次の順で走る。**どれか1つでも欠けたらそこで止まる。**

1. `flutter test`
2. **`python3 tool/preflight.py`**（出す前の点検28項目）
3. 署名の Secrets が揃っているか
4. **AdMob が本番IDか**——Google のテスト用ID（`ca-app-pub-3940256099942544`）が
   登録されていたら止める。置換したあと、置換できたことも確かめる
5. 証明書とプロファイル（**App ID と Bundle ID の突き合わせ**）
6. IPA ビルド → TestFlight（`workflow_dispatch` で選んだときだけ）

**テスト用IDのまま公開すると、広告は出るのに収益がゼロになる。しかも審査は
通ってしまうので、気づくのが遅れる。** だから署名と同じ扱いで止めている。

## 4. バージョンの上げ方

`pubspec.yaml` の1行だけ。

```yaml
version: 1.0.0+1
#        ^^^^^ ^
#        |     └─ ビルド番号（CFBundleVersion）。提出のたびに +1
#        └─ ユーザーに見えるバージョン（CFBundleShortVersionString）
```

App Store Connect は**同じビルド番号を二度受け付けない**。上げ忘れたときは
`workflow_dispatch` の `build_number` で上書きできる。

## 5. 実機で確かめること

**この環境では一度も実機で動かしていない。** 広告・課金・復元・評価ダイアログは
ストアとネットワークが要るので、TestFlight のビルドで次を確かめる。

### まず一巡

- [ ] 起動して選手を作れる（名前と代理人だけで始められる）
- [ ] 第1節の試合に入り、3つの手から選べて、結果が出る
- [ ] シーズンを終えて、シーズン終了の画面が出る
- [ ] 引き継ぎコードを出して、別の端末（かアプリの再インストール後）で読める

### 広告

- [ ] **1シーズン目の終わり**に全画面広告が出る（`adsFromSeason` = 1）
- [ ] 試合中とメニュー操作には**割り込まない**
- [ ] バナー広告が**どこにも出ない**
- [ ] シーズンを続けて飛ばしても、前の広告から3分以内なら出ない（`adInterval`）
- [ ] 「広告はテスト用のままです」の**赤字が出ていない**（本番IDが効いている証拠）

### 課金

- [ ] メニュー →「広告・応援」が開き、売り物が**2つだけ**
- [ ] 「広告を消す」を買うと、以降**シーズン終了で広告が出ない**
- [ ] 「応援する」を買うと**回数だけ増える**（ゲームには何も起きない）
- [ ] **「購入を復元」が動く**（iOS の審査要件。復元で戻るのは「広告を消す」だけ）
- [ ] アプリを消して入れ直し、「購入を復元」で広告が消えたままになる

### 評価

- [ ] 3季目以降の**良い季**（目標達成・優勝・昇格）の後に評価ダイアログが出る
      ——ただし**出すかどうかは OS が決める**ので、出なくても不具合ではない
- [ ] 全画面広告を閉じた直後には**出ない**

### 見た目

- [ ] 文字が豆腐（□）になっていない
- [ ] ノッチのある端末で、上下が切れていない
- [ ] 明るいテーマと暗いテーマの両方で読める

## 6. よくある詰まりどころ

`soccer-manager` の RELEASE_GUIDE にある表がそのまま当てはまる。
このアプリで足すとすれば:

| 症状 | 原因と対処 |
|---|---|
| プロファイルの App ID が一致しないと言われる | `soccer-manager` のプロファイルを `IOS_PROVISIONING_PROFILE_BASE64_CAREER` に登録していないか |
| 「Google のテスト用IDが登録されています」で止まる | `ADMOB_APP_ID_IOS_CAREER` にテスト用IDを入れている。AdMob で作った自分のIDに置き換える |
| preflight が「アルファチャンネルが無い」で落ちる | `python tool/make_icons.py` を回し直す（iOS 用は `convert("RGB")` を通している） |
| 審査で却下された | **返信だけでは審査は再開しない。**「審査内容を更新」まで押す（`soccer-manager` で踏んだ） |

## 7. 提出のときに埋めるもの

[`../STORE_LISTING.md`](../STORE_LISTING.md) の「申請チェックリスト」。
App 名・サブタイトル・説明・キーワード・レビュー用メモ・App プライバシーの申告まで
文面が揃えてある。
