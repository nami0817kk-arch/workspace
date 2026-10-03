# 絵の見え方を確かめる道具

**CI では回らない。** 生成器であって、テストではない。

```bash
flutter test tool/art/face_preview_test.dart --update-goldens
```

`_faces.png`（プロジェクト直下・git には入れない）に、似顔絵を実寸(40/56)と
拡大(120)で並べて書き出す。**絵を直したら必ずこれを出して目で見る。**
コードの上で直っていても、組み合わせによって崩れることがある
（赤毛と中間の肌色で生え際が消える、明るい髪が肌と同化する、
生え際の抜きが顔の外へはみ出す——どれも実際に起きた）。

ほかに `emblem_preview_test.dart`（クラブエンブレム）、
`badge_preview_test.dart`（実績の記章 33件）、
`onboarding_preview_test.dart`（初回チュートリアルの挿絵 5枚）がある。
書き出し先はいずれもプロジェクト直下の `_*.png`（git には入れない）。

見本を出す側は、**アプリ本体のテーマ（`SoccerManagerApp.buildTheme`）を使い、
同梱フォントを2つとも読み、`Material` で包む**こと。自前で `ThemeData` を
組むと頭文字が豆腐（□）になり、`Material` の外に文字を置くと黄色い二重下線が
引かれる（どちらも実際に起きた）。アイコンを含む見本は Flutter SDK の
`materialicons-regular.otf` も読む。
