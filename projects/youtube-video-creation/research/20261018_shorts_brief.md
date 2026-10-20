# 10/18 ショート 共通の決まり（担当エージェント向け）

作業場所: C:\Users\なみ\dev\wt-yt-1014\projects\youtube-video-creation（git worktree。cd で他へ移らない）。bash で `export PYTHONIOENCODING=utf-8` を付けて python を使う。報告は日本語。
読むもの: CLAUDE.md の「ショート」「ショートの見せ方を日替わりで試す（B/G/X/Y・煽り）」「事実の扱い」「ネットの反応」「写真」「読み」の節。見本: research/20261017_*.yaml（short_style 付き）と対応する scripts/20261017_*.md。題材の元: research/20261018_topics_src.yaml の該当番号（出典URL・本人の言葉の有無あり）。
やること（1題材ごと）:
1. 出典URLの本文を実際に読む（検索エンジンのAI要約は使わない。見出しに無い数字・時間は使わない。読めない部分は言わない）。
2. research/20261018_<名前>.yaml（取材メモ。no_main の型。short_style と、X なら short_hook_word、Y なら short_hook_quote を入れる）を作る。
3. `rm -f scripts/20261018_<名前>.md` のうえ `python -m src.cli draft research/20261018_<名前>.yaml --allow-repeat` で台本を作る。
4. `python tools/precheck.py`（台本・preview4 も）で点検。× は直す。流れの点検を自分で行い output/flow/20261018_<名前>.md に控えを書く（1行目は「# 流れの点検: <名前>（読み手: Claude。Gemini は無料枠切れ）」）。
5. 写真は credits.json 付きで assets/images/20261018_<名前>/ に。商用可の Commons 等、CC BY/BY-SA は表示。B は縦写真5枚以上、G は全身〜膝上の単独人物（tools/short_photo_fx.py）。足りなければ short_style を落として理由を報告（ただし「今のまま（文字だけ）」には戻さない。X か Y に切り替える）。
禁止: approve / short / build / upload / screen / git 操作、src・tools・config・CLAUDE.md の編集、FotMob 等の使用禁止サイト（Transfermarkt は最小限）、女子サッカー、Jリーグ。
煽りの版の規則: 煽る語を使ってよいのはタイトルと1行目だけ。事実は変えない。人を貶す語は使わない。答えは伏せる。想定は「見立て」と明記。
本人の言葉が無い題材で本人の言葉を作らない。反応は実在の投稿だけ。
報告（日本語・短く、題材ごと）: ファイルのパス、尺、short_style と選んだ理由、precheck の残りの×/△、流れの点検で直した点、出典と確度、写真の不安、言えなかったこと。
