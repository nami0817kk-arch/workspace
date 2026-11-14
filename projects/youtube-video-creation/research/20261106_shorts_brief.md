# 11/6 ニュースのショート 下請けへの指示書

作業場所: C:\Users\なみ\dev\wt-yt-1014\projects\youtube-video-creation（bash は `export PYTHONIOENCODING=utf-8`、Python はシステムの `python`）。
先に読む: CLAUDE.md の「ショートの題材の選び方」「見せる前の決まり」「事実の扱い」「ショートの見せ方を日替わりで試す」「ショートの作成時間の短縮」。手本の取材メモ research/20261104_sakamoto_pl_first_goal.yaml と、その台本 scripts/20261104_sakamoto_pl_first_goal.md。

## 決まり（全部守る）
- 調べは WebFetch と python requests（ブラウザの User-Agent）だけ。**ブラウザの道具は使わない。検索AIの要約は使わない。**
- 分・スコアは ESPN の試合データで確かめる。見出しに無い数字（分・xG・契約年数など）は一次で確かめたものだけ。
- 反応は実在の投稿・記事からだけ。0件でよい。3件まで。作らない。記事の貼り付けは本人の言葉ではない。
- 写真は photopool で3枚以上集める。説明・URL に Getty/AFLO/AFP/ロイター/Reuters/AP/PA がある写真は使わない。`_pool.png` を Read で目で見て、別人・ぼけ・ロゴだけの絵を外す。
- 取材メモは `research/20261106_<key>.yaml`。`no_main: true`。short_style は本人の言葉があれば Y、無ければ X。
- **ショートで写真が1枚のまま続かないよう、山場の節の行に `image:` で写真の入れ替えを2〜4か所入れる。**
- `python -m src.cli draft research/20261106_<key>.yaml`（既にあると黙って何もしない。作り直しは scripts を消して `--allow-repeat`）。
- `python tools/preshow.py scripts/20261106_<key>.md` の × を全部直す。
- 流れの点検 `python tools/flow.py scripts/20261106_<key>.md`（Gemini が429なら `--prompt` で出る問いに自分で答える）。控えを `output/flow/20261106_<key>.md` に書く。
- **approve / short / upload / screen / git はしない。** src・tools・config・CLAUDE.md は編集しない。
- 公開文面に本名・nami・0817 を出さない。台本に語り手の言いわけ（「確かめていません」等）を入れない。
- 取材で前提が崩れた題材（見出しが事実と違う・本人の言葉が確かめられない・既出と同じ話）は作らずに、理由を書いて返す。

## 返すもの（題材ごとに）
key／作れたか／台本のパス／タイトル／short_style／使った写真の枚数と出どころ／反応の件数／事実で食い違っていた点／残った × と理由。
