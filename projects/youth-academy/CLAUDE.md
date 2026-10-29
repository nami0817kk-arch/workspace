# ユースの系譜（仮題）— 試合の試作

サッカーのユース育成ゲーム。日本のクラブユースの指導者になり、高1〜高3の約36人を育てて送り出す。
構想・決定1〜80は記憶 `youth-academy-game`（C:\Users\なみ\.claude\projects\...\memory\）とまとめのページが正。
**いま入っているのは「試合の試作」だけ**（TestFlight で試合の面白さを確かめるため。2026-10-29 のユーザー指示）。

## 構成

| 場所 | 中身 |
|---|---|
| `web/src/data.js` | 能力29＋GK8・特性42・性格8グループ・役割・布陣・戦い方・チーム（あなたのクラブ／相手3つ） |
| `web/src/engine.js` | **試合の中身**（位置と出来事）。見せ方に依存しない。`Match.step()` が tick / scene / stop / full を返す |
| `web/src/render.js` | 見せ方。斜め見下ろしの仮想3D（Canvas）。three.js 等に替えるときはここだけ入れ替える |
| `web/src/ui.js` | 画面（試合前・試合中・停止中パネル・試合後・選手一覧）。左の縦タブ・横向き |
| `web/tool/sim.js` | エンジンの点検（落ちない・得点の釣り合い・特性が効く・交代5人3回・自動停止・指示と声かけ）。CI |
| `web/tool/views.js` | 画面の点検（jsdom）。CI |
| `web/tool/build.js` | 上を1枚にして `app/assets/web/index.html` に置く（コミットしない） |
| `app/` | Flutter の外側（横向き固定の WebView）。手本は projects/hikari7 |

## 決まり

- 試合の中身は見せ方と切り離す（決定3・79）。座標は m、攻める側が +y。`scene.frames` が絵の素。
- 試合は「見どころだけ動く」（決定79）。10〜15の場面だけ動かし、残りは実況1行。型は engine.js の `_through` など10種。
- 特性や性格が場面に効いたら `scene.fx` に記録し、画面の札に出す（守る側は守備が成功したときだけ）。
- 創作の物語を避ける決まり（no-creative-story-content）は動画の決まりで、ゲームの台詞・出来事には当てはめない（ユーザー指示）。
- 広告・課金は試作に入れていない。入れるときは docs/app-pitfalls.md を先に読む。
- 画面を直したら、ブラウザで絵にして目で確かめる（`node web/tool/build.js web/dist/index.html` → `python -m http.server` → 844×390）。
- リリース: `youth-academy-ios-release.yml`（workflow_dispatch、`upload_to_testflight=true`）。Secret は `YOUTH_ACADEMY_IOS_PROVISIONING_PROFILE_BASE64` のみ新規。
  Bundle ID `com.namiki.youthacademy`、App Store Connect の Apple ID 6828073461。ビルド番号は `app/pubspec.yaml` の `+N`。

## まだ入っていないもの（試作の範囲外）

育成（練習・面談・成長）、36人の生成・関係・出来事、スカウト、クラブ運営、日程、名鑑、保存、広告・課金、効果音、本物の3D、
相手の分析の深さ、PK・CK のキッカー指定などの細かい設定、戦術理解による再現度。
