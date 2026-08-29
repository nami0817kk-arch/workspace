---
title: "【サッカーニュース】{{TITLE}}"
thumbnail_title: "{{THUMB_TITLE}}"
thumbnail_badge: まとめ
thumbnail_subtitle: {{DATE_SHORT}}のまとめ
bg: assets/backgrounds/stadium.mp4
date: {{DATE}}
intro_title: "{{INTRO_TITLE}}"
intro_label: 海外サッカー ニュース
outro_title: 続報は次回お伝えします
outro_sub: チャンネル登録でお待ちください
description: |
  {{DATE}}時点の海外サッカーの動きをまとめました。
  ※各社の報道をもとにしています。クラブが発表した「確定」情報と、
  メディアが伝えている「報道段階」の情報を分けて紹介しています。
tags: [サッカー, 海外サッカー, 移籍情報, サッカーニュース]
sources:
  # 使った記事・投稿のURLをすべてここに。概要欄に自動で載る
  - https://example.com/CHANGE_ME
cards:
  # 引用カード（原文＋訳）。海外紙の見出しをそのまま見せたいとき
  # quote_1:
  #   type: quote
  #   text: "英語の見出しをそのまま"
  #   translation: 日本語訳
  # 移籍カード
  # move_1:
  #   type: transfer
  #   player: 選手名
  #   from: 移籍元
  #   to: 移籍先
  #   fee: 移籍金（報道ベースなら「〜と報道」と書く）
  # 数量の比較（数字は必ず出典を確認したものだけ）
  # compare_1:
  #   type: bars
  #   title: グラフの見出し
  #   unit: 点
  #   items:
  #     - {label: 選手A, value: 0, highlight: true}
  #   note: ※数値の出典
  wrap:
    type: points
    title: 今回のまとめ
    items:
      - "確定 … {{TOPIC_1}}"
      - "注目 … {{TOPIC_2}}"
      - "{{TOPIC_3}}"
---

## オープニング

キャスター: 海外サッカーのニュースです。{{LEAD}}
  telop: {{LEAD_TELOP}}

## {{SECTION_1}}
@bg: assets/backgrounds/pitch.png

キャスター: まずは、すでに決まったニュースから。
  telop: {{TELOP_1}}
  source: 確定
  se: assets/audio/se_pon.wav
解説: {{セリフ2}}
  telop: {{TELOP_2}}
  source: 報道

## {{SECTION_2}}
@bg: assets/backgrounds/tactics.png

キャスター: 続いて、まだ決まっていない案件です。ここからは報道の段階であることを、あらかじめお伝えしておきます。
  telop: {{TELOP_3}}
  source: 未確認
解説: {{セリフ4}}
  telop: {{TELOP_4}}
  source: 未確認

## まとめ

キャスター: まとめます。
  telop: {{WRAP_TELOP}}
  card: wrap
キャスター: 動きがあり次第、あらためてお伝えします。続報はチャンネル登録してお待ちください。
  telop: 続報はチャンネル登録でチェック
  se: assets/audio/se_jingle.wav
  pause: 1.2
