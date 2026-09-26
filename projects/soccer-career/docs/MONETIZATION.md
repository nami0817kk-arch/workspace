# 収益化（iOS）

**2026-09-25 に仕組みを入れた。** 出す先は iOS だけ（Android の雛形は残してあるが、
出す予定は無い）。Web 版には広告も課金も無い。

`soccer-manager` が同じ形で動いているので、そちらを先例にしている
（`projects/soccer-manager/docs/RELEASE_GUIDE.md`）。

## 何を売るか

| 商品 | 商品ID | 種別 | 中身 |
|---|---|---|---|
| 広告を消す | `soccer_career_no_ads` | 非消費型（買い切り） | シーズンの切れ目の全画面広告が出なくなる |
| 応援する | `soccer_career_tip` | 消費型 | **ゲームには何も起きない。** 回数が表示されるだけ |

**強くなるものは売らない。** 伸びしろも金も出場機会も `balance_sim` で測って
釣り合わせてきたもので、売った瞬間にその調整が意味を失う。
`test/monetize_test.dart` の「強くなるものは1つも無い」が、商品を足したときに落ちる。

リワード広告も置いていない。**見返りに渡せるものが「金」か「伸びしろ」しか無い**
——どちらも売らないと決めたものなので、広告で配るのも同じこと。

## 広告をいつ出すか

`lib/monetize/monetization.dart` の `shouldShowSeasonAd` が1か所で決める。

- **シーズンの画面を閉じたあと**だけ（`HubScreen._endSeason`）。試合中にも
  メニューにも割り込まない。バナーは出さない。
- 最初の **3シーズン**（`freeSeasons`）は出さない。始めたばかりの人にとって
  シーズンの切れ目は「続きが見たい」瞬間そのもので、ここで挟むと離れる。
- 前の広告から **4分**（`adInterval`）あいていること。シーズンは自動で
  飛ばせるので、置かないと連発する。
- 買った人には出さない。

## 手元で済んでいること

- `lib/monetize/`（広告・課金・出す条件）。Web とテストでは**何もしない実装**に
  切り替わる（`createAdService` / `createPurchaseService`）。
- `lib/ui/screens/support_screen.dart`（広告・応援の画面。**購入の復元**を含む）。
  メニューの「広告・応援」から開く。
- `ios/Runner/Info.plist` に `GADApplicationIdentifier`・`SKAdNetworkItems`（50件）・
  `ITSAppUsesNonExemptEncryption`・`CFBundleLocalizations`。
- `legal/privacy.html` / `terms.html` / `support.html`。Pages のデプロイで
  `/legal/` に出る。
- `web/app-ads.txt`（AdMob の発行者ID。`soccer-manager` と同じ発行者）。
- `test/monetize_test.dart`（13本）と `ui_test` の2本。

## 残っていること（コンソール側の作業）

**既定のままでは収益は発生しない。** 広告IDは Google のテスト用にしてあり、
差し替え忘れても規約違反にならないようにわざとそうしている。

### 1. AdMob

1. https://apps.admob.com で **iOS アプリを1つ登録**する（発行者アカウントは
   `soccer-manager` と同じものが使える）。
2. **インタースティシャル**の広告ユニットを1つ作る。リワードは要らない。
3. 控えるもの:
   - **アプリID**（`ca-app-pub-xxx~yyy`、`~` 区切り）
   - **広告ユニットID**（`ca-app-pub-xxx/zzz`、`/` 区切り）
4. アプリIDを `ios/Runner/Info.plist` の `GADApplicationIdentifier` に書く。
5. ユニットIDはビルド時に渡す:

```bash
flutter build ipa --release \
  --dart-define=ADMOB_INTERSTITIAL_IOS=ca-app-pub-xxxx/zzzz
```

> 渡し忘れると、アプリ内の「広告・応援」画面に
> **「広告はテスト用のままです」** と赤字で出る（`usingTestAdUnit`）。

### 2. App Store Connect

1. 新しい App を作る。**Bundle ID は `com.namiki.soccercareer`**
   （`ios/Runner.xcodeproj` に既に入っている）。
2. **App内課金を2つ**登録する。IDは上の表のとおりで、1文字でも違うと
   アプリ側から見つからない。
   - `soccer_career_no_ads` — 非消耗型
   - `soccer_career_tip` — 消耗型
   価格はストア側で決める（アプリには持たせていない）。
   どちらもアプリ本体とは**別に審査**がある。
3. URL を入れる:
   - プライバシーポリシー `https://soccer-career-49p.pages.dev/legal/privacy.html`
   - サポート `https://soccer-career-49p.pages.dev/legal/support.html`
4. プライバシー（App のプライバシー）の申告:
   - 提供者が集めるものは**無し**。
   - 第三者（AdMob）が**識別子**と**利用状況データ**を広告のために取得する。
   - **トラッキングは求めない**（ATT の導線を入れていないので、
     非パーソナライズ広告になる）。

### 3. リリースの仕組み

soccer-career には iOS のリリース用ワークフローがまだ無い。
`soccer-manager` の `.github/workflows/soccer-ios-release.yml` が動いているので、
**App ID とプロビジョニングプロファイルを作ったあとで**それを写すのが早い。
証明書は同じ Apple Developer アカウントのものが使えるが、
**プロファイルは Bundle ID ごとに別**なので作り直しが要る。

### 4. 実機での確認

手元では確認できない（広告も課金もストアとネットワークが要る）。
実機で次を見ること。

- 4シーズン目のシーズン終了後に全画面広告が出る。
- 続けてシーズンを飛ばしても、4分以内には二度出ない。
- 「広告を消す」を買うと、以降のシーズン終了で出ない。
- アプリを消して入れ直し、「購入を復元」で広告が消えたままになる。
- 「応援する」は何度でも買えて、ゲームの中では何も変わらない。
