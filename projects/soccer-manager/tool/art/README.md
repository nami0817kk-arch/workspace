# 絵の見え方を確かめる道具

**CI では回らない。** 生成器であって、テストではない。

```bash
flutter test tool/art/face_preview_test.dart --update-goldens
```

`_faces.png`（プロジェクト直下・git には入れない）に、似顔絵を国ごとに
実寸(40)と拡大(96)で並べて書き出す。**絵を直したら必ずこれを出して目で見る。**
顔は描いた絵（`assets/faces/` の体と髪）の重ねなので、型と髪の組み合わせに
よってずれることがある（2026-11-25 に描画の顔から差し替えた）。

ほかに `emblem_preview_test.dart`（クラブエンブレム）、
`badge_preview_test.dart`（実績の記章 33件）がある
（初回チュートリアルの挿絵は、チュートリアルごと 2026-11-25 に外した）。
書き出し先はいずれもプロジェクト直下の `_*.png`（git には入れない）。

見本を出す側は、**アプリ本体のテーマ（`SoccerManagerApp.buildTheme`）を使い、
同梱フォントを2つとも読み、`Material` で包む**こと。自前で `ThemeData` を
組むと頭文字が豆腐（□）になり、`Material` の外に文字を置くと黄色い二重下線が
引かれる（どちらも実際に起きた）。アイコンを含む見本は Flutter SDK の
`materialicons-regular.otf` も読む。

`moment_preview_test.dart` はタイトル画面と、昇格・優勝の演出を書き出す
（`_title.png` / `_moments.png`）。**絵を差し替えたら必ず出して見る。**
`Image.asset` のパスを間違えても画面に赤い枠が出るだけで、テストは落ちない。

`player_preview_test.dart` は選手詳細を書き出す（`_player.png`）。
**この画面は掲載画像に入らない**ので、ここで見ないと誰も見ないまま出る。
実際、能力レーダーの軸ラベルが豆腐（□）のままだったのをここで見つけた
（`CustomPainter` の `TextPainter` はウィジェットの木の外にいるので、
テーマの書体が当たらない。同梱フォントしか無い Web版で崩れる）。
同じ穴は `test/painter_font_test.dart` が見ている。
