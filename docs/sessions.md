# セッション台帳

**誰が何を持っているか**の唯一の正。迷ったらここを見る。

原則:

- **1プロジェクト = 1セッション**。ここに載っていないセッションは臨時で、仕事を持たせない。
- 担当の追加・変更・セッションの整理は**ユーザーが行う**。調整役は台帳の状態欄を更新するだけ。
- セッション名は担当が分かる名前にする（`Session 2` のような名前は、担当が無い＝畳んでよい印）。

## 常設セッション（PC 上）

| セッション名 | 担当 | 主な作業場所 | 対応ブランチの例 |
|---|---|---|---|
| サッカーアプリ | soccer-manager | `projects/soccer-manager` | `claude/perf-audit` |
| YouTube動画 | youtube-video-creation | `projects/youtube-video-creation` | `claude/matome` |
| 楽天 | price-tracker | `projects/price-tracker` | `claude/price-tracker-daily` |
| 動画編集 | 動画編集スキル（ai-lab videogen） | `platform/ai-lab` | `claude/video-skill-update` |
| Chrome操作 | ブラウザ操作基盤 | `platform/ai-lab/src/browser` | — |
| 画像生成 | imagegen | `platform/ai-lab/src/imagegen` | — |
| ゲーム操作 | kabu-agari-ranking | `projects/kabu-agari-ranking` | — |
| API | gemini-api | `projects/gemini-api` | — |
| 新設ラボ | tool-factory | `projects/tool-factory` | — |
| mcp | stock-investment | `projects/stock-investment` | — |

下の4つは担当が特定できず「要確認」だったものに、2026-09-04 にユーザー指示で
担当を割り当てた。**セッション名と担当が一致していない**（「ゲーム操作」が
株ランキング、など）。名前は担当が分かるものへ変えたほうがよいが、
セッションの改名はユーザーが行う。

割り当ての根拠は「運用中で、壊れても気づかれにくい順」。

- `kabu-agari-ranking` と `tool-factory` は**公開サイトを持ちながら担当が
  いなかった**。収益面に露出しているのに、止まっても誰も見ていない状態だった
- `stock-investment` は未担当のうち最も活発（直近30日で10コミット）
- `gemini-api` はセッション名「API」と実体が一致する唯一の組み合わせ

## まだ担当のいないプロジェクト

1プロジェクト = 1セッションの原則に対し、常設セッションが足りていない。
以下は担当不在のまま動いている。

| プロジェクト | 直近30日 | 備考 |
|---|---|---|
| `quality-gainer-tracker` | 7コミット | kabu-daily スキルがユーザー操作で回している |
| `ir-analysis` | 5コミット | ir-scan スキルがユーザー操作で回している |
| `ai-side-business` | 6コミット | — |
| `cohabitation-budget` | 1コミット | ほぼ休止。畳んだままでよければ対象外にする |

上2つはスキル経由でユーザーが直接回しているため、常設セッションが無くても
気づかれずに止まることはない。下2つは**止まっても誰も気づかない**ので、
セッションを増やすなら次はここ。増やすかどうかはユーザーが決める。

## 定期セッション

| 名前 | 頻度 | 中身 |
|---|---|---|
| Site watch morning | 毎朝 08:57 JST | サイトの見回り |
| workspace 調整役の定期巡回 | 2時間おき 08:00–24:00 JST | CI・PR・`[調整役]` Issue の確認（クラウド） |

## 調整役

現任は `docs/coordinator.txt` を見る。連絡方法もそこに書いてある。

## PC が落ちると止まるもの

PC（`C:\Users\なみ\dev\workspace`）は単一障害点。実際 2026-09-02 に 2 回
`computer_unreachable` が起き、うち 1 回で調整役セッションが落ちた。
**PC でしかできない仕事は次の 3 つに限る。これ以外を PC に依存させない。**

| 仕事 | 理由 |
|---|---|
| kabu-agari-ranking の日次取得（平日 16:10、`run-daily.ps1`） | kabutan が GitHub Actions の IP を 405 で弾く |
| Chrome 操作（ポート 9222 のリモートデバッグ） | ログイン済みプロファイルが要る |
| Flutter の実機確認・ストア提出作業 | 実機と署名が要る |

上記以外は CI（テスト・ビルド・公開）とクラウドセッション（調整役の巡回）に寄せる。
テストをローカルで回さない方針も同じ理由による（`docs/session-faq.md`「テストはクラウドで回す」）。

## 異常の閾値

巡回ごとに判断がブレないよう、**通知する条件を数字で固定する**。
これを超えたものだけをユーザーに知らせる。超えていなければ黙る。

master の CI が赤いかどうかは、**open な `[CI]` Issue の一覧を見れば分かる**
（`ci-alert.yml` が失敗した瞬間に起票し、緑に戻ると自動で閉じる）。
巡回はワークフロー実行を一覧しなくてよい。

| 対象 | 異常とみなす条件 |
|---|---|
| master の CI | `[CI]` Issue が開いたまま **30分以上** |
| open PR（CI 緑） | **3日以上**マージも close もされず滞留 |
| open PR（CI 赤） | 赤いまま **24時間以上** |
| `claude/` ブランチ | 最終コミットから **24時間以上**動かず、master に未取り込み |
| kabu の日次データ | 最終更新から **26時間以上**（平日のみ判定。土日祝は正常） |
| price-tracker の日次 | **24時間以上**成功した実行が無い |
| 巡回そのもの | `docs/patrol-log.md` の最終行から **4時間以上**空いている（＝巡回が落ちている） |

dependabot の PR は滞留の対象外（マージ判断はユーザーが行うため）。

## 止まっていることの検知

| 何を | どこで | 気づき方 |
|---|---|---|
| kabu の日次取得 | `kabu-daily.yml`（平日 17:00 JST） | データが古いと Issue が立つ |
| 各PJTのテスト | `<pjt>-tests.yml` | PR / push で赤くなる |
| master が赤い | `ci-alert.yml`（失敗した瞬間） | `[CI]` の Issue が立つ。緑に戻ると自動で閉じる |
| コード品質の劣化 | `growth-loop.yml`（毎週月曜 09:13 JST） | `platform/ai-lab/GROWTH.md` が更新される |
| 未 push の作業 | 夜間 22:00 の `scripts/wip-sweeper.sh` | `wip/` ブランチへ退避される |
| セッションの停止・CI の赤・放置ブランチ | 調整役の定期巡回（2時間おき） | 異常時のみ通知が来る。見た記録は [docs/patrol-log.md](patrol-log.md) |
