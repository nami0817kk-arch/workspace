# 11/27 ショート取材の共通の決まり（下請け向け）

作業場所: C:\Users\なみ\dev\wt-yt-1014\projects\youtube-video-creation（git worktree）。bash では必ず `export PYTHONIOENCODING=utf-8`。Python はシステムの `python`。
commit/push はしない。src・tools・config・CLAUDE.md は編集しない。報告は日本語。

まず読む: CLAUDE.md の「事実の扱い」「見せる前の決まり」「ショートの見せ方を日替わりで試す」「ショートの作成時間の短縮」の節（grep -n で探して該当箇所だけ）、スキル soccer-video（C:\Users\なみ\.claude\skills\soccer-video\SKILL.md）、手本 research/20261104_sakamoto_pl_first_goal.yaml と、直近の取材メモ research/20261126_*.yaml（形を写す）。

決まり:
- 調べは **WebFetch と python requests（ブラウザの User-Agent）だけ**。ブラウザの道具（Claude_Browser / claude-in-chrome / computer-use）は使わない。**検索エンジンのAI要約は使わない**（見出しと本文そのものだけ）。
- 分・スコアは ESPN の試合データ（site.api.espn.com/apis/site/v2/sports/soccer/<league>/summary?event=<id>）で確かめる。記事と食い違えば ESPN を正とし、食い違いをメモに残す。
- 反応は**実在の投稿だけ**（0件でよい、3件まで）。作らない。
- 写真は photopool で3枚以上（`python -m src.cli --help` や既存メモの使い方を見る）。説明やURLに Getty/AFLO/AFP/ロイター/Reuters/AP/PA がある写真は使わない。_pool.png を Read で目で見て、別人・ぼけ・小さすぎを外す。
- 取材メモは research/20261127_<key>.yaml。`no_main: true`。short_style は本人の言葉があれば Y（short_hook_quote）、無ければ X（short_hook_word）。
- **ショートで写真が1枚のまま続かないよう、山場の節の行に `image:` で写真の入れ替えを2〜4か所入れる。**
- `python -m src.cli draft research/20261127_<key>.yaml` で台本を作り、ヒントを全部読んで直す。
- `python tools/preshow.py scripts/20261127_<key>.md` の×を直す（--no-preview でもよいが最後に一度は4コマも見る）。
- 流れの点検 `python tools/flow.py scripts/20261127_<key>.md`。Gemini が429なら `--prompt` の問いに自分で答え、控えを output/flow/20261127_<key>.md に書く（既存の output/flow/20261126_*.md の形を写す）。
- **approve / short / build / upload はしない。** VOICEVOX を使う書き出しは親がやる。
- 人の死・法的な問題・女子・年代別は扱わない。選手を小さく見せない。煽りは足さない。
- 取材で前提が崩れたら（事実が違う・写真が揃わない）その題材は作らずに理由を返す。
- 最後に返すもの: 題材ごとに 台本のパス／題（タイトル）／short_style／本人の言葉の有無／反応の件数／写真の枚数と image: の数／preshow の残った×と理由／事実で気をつけた点。
