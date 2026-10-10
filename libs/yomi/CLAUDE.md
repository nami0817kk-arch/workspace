# yomi

合成音声の読み違いの点検（共有ライブラリ）。使い方・チャンネル側で持つもの・関門の作り方は README.md。
利用側は projects/rekishi-chiso（requirements.txt の `-e ../../libs/yomi`、chiso/reading.py）。

- **チャンネルの言葉を入れない**。歴史の語（斉・都・小谷…）は rekishi-chiso の `yomi.yaml`。共通の一覧は `src/yomi/data/base.yaml`
- 一覧・型・知らせない組を変えたら、利用側の過去の台本に流して数を見る（rekishi-chiso の `tests/test_reading.py` の
  `RULE_HITS` が、型に当たる所を固定している。こちらを変えると利用側の CI が落ちることがある）
- 知らせの文（`Report.lines()`）は「読み：」「読み（人名・地名」「読みが割れる語」で始まる。利用側の check がこの頭で並べ分けている
- 手順はユーザーレベルのスキル `voice-reading-check`
