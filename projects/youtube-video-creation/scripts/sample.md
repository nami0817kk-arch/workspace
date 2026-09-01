---
title: 台本を書くだけでニュース動画ができる仕組み
thumbnail_title: 台本を書くだけで\nニュース動画が完成
thumbnail_subtitle: 作り方をまとめました
description: |
  台本Markdownを書くだけで、音声・テロップ・字幕・サムネイルまで自動で組み上がる仕組みを説明します。
tags: [サッカー, 海外サッカー, 動画制作]
---

## オープニング
@bg: assets/backgrounds/default.png

キャスター: こんにちは。今日は、この動画がどうやって作られているかをお話しします。
  telop: 動画を自動で作る仕組み
キャスター: 台本のテキストを書くだけで、音声もテロップも字幕も自動で付きます。
  telop: 台本を書くだけでOK
  pause: 0.7

## 台本の書き方
@bg: assets/backgrounds/tactics.png

キャスター: 台本は、見出しでシーンを区切り、話者名に続けてセリフを書きます。
  telop: 見出し＝シーンの区切り
解説: セリフの下の字下げした行で、テロップや間の長さを指定できます。
  telop: テロップ・間も台本で指定
キャスター: 背景はシーンごとに切り替えられます。いまの画面がその例です。
  telop: 背景はシーンごとに切替

## 音声はVOICEVOX
@bg: assets/backgrounds/stadium.png

キャスター: 読み上げはVOICEVOXです。アプリを起動しておけば、そのまま音声が付きます。
  telop: 読み上げはVOICEVOX
解説: 見つからないときは無音で書き出されるので、構成と尺だけ先に確認できます。
  telop: 無音でも尺の確認はできる

## まとめ
@bg: assets/backgrounds/default.png

キャスター: 書式の確認はチェック、書き出しはビルド。まずはこのファイルで試してください。
  telop: check → build の順で
キャスター: ご視聴ありがとうございました。
