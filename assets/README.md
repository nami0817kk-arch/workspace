# assets

`python -m src.cli init-assets` で仮の背景・立ち絵が生成される。
生成物と差し替えた素材は git 管理外（.gitignore 済み）。

```
assets/
  backgrounds/default.png          背景
  characters/<key>/<表情>_<close|open>.png   立ち絵（背景透過PNG）
  images/                          本編に差し込む図など（任意）
```

表情は normal / smile / angry / surprise。無いものは normal にフォールバックする。
配布素材を使う場合はライセンスを確認し、必要なクレジットを概要欄に入れること。
