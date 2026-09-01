---
title: 【ゆっくり解説】台本を書くだけで動画ができるパイプラインの話
thumbnail_title: 台本を書くだけで\n動画が完成する
thumbnail_subtitle: ゆっくり実況の作り方
description: |
  台本Markdownを書くだけで、音声・口パク・テロップ・字幕まで自動で組み上がる仕組みを解説します。
tags: [ゆっくり解説, VOICEVOX, 動画制作, 自動化]
---

## オープニング
@bg: assets/backgrounds/default.png

霊夢: ゆっくり霊夢よ。今日は動画を自動で作る仕組みの話をするわ。
  telop: 動画を自動で作る仕組み
魔理沙: ゆっくり魔理沙だぜ。自動って、どこまで自動なんだ？
  emotion: surprise
霊夢: 台本のテキストを書くだけ。音声も口パクもテロップも勝手に付くわ。
  telop: 台本を書くだけでOK
  se: assets/audio/se_pon.wav
  pause: 0.7

## 台本の書き方

魔理沙: へえ、その台本ってのはどう書くんだ？
霊夢: 「話者: セリフ」って1行ずつ書くだけよ。見出しを付ければチャプターになるわ。
  telop: 「話者: セリフ」と書くだけ
魔理沙: なるほど、Markdownそのものだな。
  emotion: smile
霊夢: 行の下にインデントして telop や emotion を書けば、表示や表情も変えられるわ。
  telop: telop / emotion / pause で微調整

## 音声はVOICEVOX

霊夢: 読み上げはVOICEVOXを使うの。ローカルで起動しておけば自動で喋ってくれるわ。
  telop: 音声合成はVOICEVOX
魔理沙: タダで、しかも高品質なやつだな。
霊夢: そう。キャラごとの声はconfigのstyle_idを変えるだけで差し替えられるわ。
  telop: style_id を変えるだけで声を変更

## まとめ

魔理沙: つまり、台本さえ書けば動画が出てくるってわけか。
  emotion: smile
霊夢: そういうこと。あとはサムネと概要欄も一緒に出てくるから、投稿するだけね。
  telop: 字幕・サムネ・概要欄も自動生成
魔理沙: 便利すぎるぜ。チャンネル登録、よろしくな！
  emotion: smile
  se: assets/audio/se_jingle.wav
  pause: 1.2
