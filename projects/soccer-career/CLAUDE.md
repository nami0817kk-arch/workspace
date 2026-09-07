# soccer-career

1人の選手を作って、キャリアを進めるゲーム（FC 系のプレイヤーキャリア相当）。
2部の下位クラブから始まり、試合ごとの判断で評価点を積み上げ、成長し、
移籍して上を目指す。**中核は「試合中の選択」**であって、放置でも数字でもない。

## 前提

- Flutter / Dart。依存は `shared_preferences` のみ。
- **クラブ名・リーグ名はすべて架空**（`lib/game/names.dart`）。実在の名称・商標は使わない。
  公開と収益化を前提にしているため、ここは例外を作らない。
- **1シーズン38試合すべてをプレイする**設計（ユーザーの選択）。
  だから **1試合は短くなければならない**。先発で3局面、途中出場で2局面。
  ここを増やすとシーズンが終わらなくなる。
- セーブは端末ごとに独立（`shared_preferences`）。クラウド同期はしない。

## 構成

```
lib/
  game/formulas.dart       数値定義。バランス調整はここだけ
  game/scenarios.dart      局面と選択肢のデータ
  game/match_engine.dart   1試合の進行・判定・成長
  game/career_engine.dart  シーズンの組み立て・順位表・移籍
  game/names.dart          架空のクラブ名
  models/                  Attributes / Player / Club / Season / CareerState
  state/career_controller.dart  画面が購読する状態
  ui/screens/              選手作成・拠点・試合・シーズン終了
```

## 手を入れるときに気をつけること

- **常に正解になる選択肢を作らない。** 各局面は「難しいが得点に直結する手」と
  「安全だが見返りが小さい手」を対にしてある。どちらを選ぶかがこのゲームそのもの。
  `successChance` が能力＝難易度でも五分を下回るのは意図的で、難しい手にリスクを残すため。
- **評価点が出場機会に効く**（`decideAppearance`）。不調が続くと途中出場→ベンチ外になる。
  この連鎖がキャリアものの緊張感なので、甘くしない。ただし**デビュー前は必ず先発**にする。
  実績ゼロでベンチ外にすると、何もしないまま数試合が過ぎる。
- **順位表は他クラブ同士の試合も毎節シミュレートする**（`_simulateOtherMatches`）。
  自分の試合ぶんしか動かないとリーグが死んで見える。
- **自分が決めた得点は必ずチームのスコアに含める**（`finish` の `max`）。
  ここがずれると「決めたのに 0-1 で負けた」が起きて理不尽になる。
- 保存データが壊れていたら**捨てて新規扱いにする**（`SaveRepository.load`）。
  例外を投げると、一度壊れたユーザーがアプリを開けなくなる。
- **GK は対象外**。局面の性質が他ポジションと全く違うため、作るなら専用の局面プールが要る。

## まだ無いもの

- 収益化（広告・課金）。ストア申請も未着手。`soccer-manager` の `STORE_LISTING.md` が先例。
- 代表招集、カップ戦、負傷、契約交渉。

## 公開

Web版は master への push で Cloudflare Pages に自動デプロイされる
（`.github/workflows/soccer-career-pages.yml`）。公開URLは soccer-career.pages.dev。
検証は `soccer-career-ci.yml` に分けてあり、公開設定のミスでテストまで赤くならない。

**セーブは端末ごとに独立**（localStorage）。PC で進めた内容とスマホの内容は別物になる。

## テスト

合否は CI（`soccer-career-ci.yml`）で見る。手元は analyze まで。
対象を絞って回すときは workflow_dispatch の `target` を使う。
