# 10/24 シリーズ10本の共通の指示（2026-10-20）

作業ディレクトリは `C:\Users\なみ\dev\wt-yt-1014\projects\youtube-video-creation`（git worktree）。`PYTHONIOENCODING=utf-8` を付ける。
決まりの本体は `CLAUDE.md`（特に「毎日固定のシリーズは10」の表、「シリーズの質の決まり」「見せる前の決まり」「サムネの構図」「画像の数」）。

## やること（台本を見せる手前まで）
1. 取材メモ `research/20261024_<key>.yaml` を書き、`python -m src.cli draft research/20261024_<key>.yaml --allow-repeat`（既存の台本があれば先に rm）で台本 `scripts/20261024_<key>.md` を作る。ヒントは全部読む。
2. `python tools/precheck.py scripts/20261024_<key>.md`（本編を作らないショートは不要。シリーズは `--no-preview` ではなく preview4 まで通す）。× は直す。
3. 流れの点検：`python tools/flow.py --prompt` の5つの問いを自分で当てて直し、`output/flow/20261024_<key>.md` に書く（1行目「# 流れの点検: 20261024_<key>（読み手: Claude。Gemini は無料枠切れ）」、台本より新しいこと）。
4. サムネを作る（`python -m src.cli thumbnail scripts/20261024_<key>.md` か `tools/thumblayout.py`）。**型はシリーズごとに決定済み**（下）。出来た絵を自分で見て、字・顔・黒の割合・名前を確かめる。
5. approve・build・upload・git・`src/` `tools/` `config/` `CLAUDE.md` の編集はしない。VOICEVOX を使う処理（build/short/audio）はしない（他の作業が1本ずつ回す）。ブラウザの道具は使わない（WebFetch と requests だけ）。
6. 最後に日本語で簡潔に報告：ファイルの場所、題、尺（preview4 の見積り）、precheck の残り、サムネの文字と根拠の事実、写真の出典と不安、確かめられなかったこと。**事実は出典で確かめた値だけ。確かめられない数字は台本に入れない。**

## 共通の決まり（抜粋）
- シリーズの地の文は解説1人。本編は実尺6分まで（preview4 の見積りは5分半まで。見積りは実物より短く出る）。
- 題は人名かクラブ名で始め、答えを言い切らず、問いで終える。見立ての節を置く（数字2つ以上＋比べ）。節の見出しは中身の問い。
- 同じ画面・同じ写真を20秒以上続けない。写真は3枚以上。代理店（Getty/AFLO/AFP/Reuters/IMAGO）と放送映像は使わない。取り込んだら目で見て本人か確かめる。出典は credits.json に控える。
- 概要欄に出すのは、出さなければならないもの（CC BY の撮影者名など）だけ。**credits.json の撮影者名に HTML（`<a ...>`）が残っていないか見る**（今日 `<` `>` で投稿が弾かれた）。
- 女子サッカー・Jリーグは扱わない。選手・監督を小さく見せる言い方（「〜だけ」「最下位」）をしない。病気・私生活・法的な問題は入れない。
- FotMob は使わない（基本の数と、自分で割った90分あたり）。
- 今日（10/22）の実物を見本にする：スタジアム=`scripts/20261020_stadium_etihad.md`、財政=`20261020_finance_villa.md`、ユニフォーム=`20261020_kit_tottenham.md`、選手紹介=`20261020_sobosslai_intro.md`、レジェンド=`20261020_beckham_legend.md`、比べる=`20261017_compare_pedri_vitinha.md`、クラブ紹介=`scripts/20260926_ll20_villarreal.md`。
- 直近30日に公開した本と、人名・クラブ名の組み合わせが重ならないか `research/posted.json` と `research/covered.yaml` で見る。

## サムネの型（シリーズごとに決定済み。2026-10-20）
- クラブ紹介：基礎DATAの板（`thumbnail_board`）＋エンブレム主役。黒の基準は見ない。
- 選手紹介／レジェンド／監督紹介：選手紹介（ヤマル）型＝全面写真＋`tools/thumbpanel.py` の通算の表（左）＋クラブのエンブレム（右）＋黄色い帯（黒1行目「◯◯、通算N試合M点」14字以内・赤2行目）。札は付けない。見本は `output/thumb_samples/監督サムネA_選手紹介型.png`（グアルディオラ）、`assets/images/20261020_sobosslai_intro/panel_09.jpg`。
- 代表チーム紹介：基礎DATAの板。見本は `output/thumb_samples/team_brazil_A_board.png`。
- スタジアム紹介：scene 型（全景＋下の黒い帯。2行目14字まで）。
- クラブの財政：number 型（最強の数字を大きく。写真は横長）。
- ユニフォームとエンブレム：classic（写真＋黄色い帯＋吹き出し2つ）。
- 比べる：ペドリとヴィティーニャ型（2人を左右に、`thumbnail_photos` 2枚＋`face_link: VS`、エンブレムは上隅、黄色い帯）。

## 10/23 の実績から足す決まり（追加）
- **題・題材の重なりと現役／引退は、台本を作る最初に自分でも確かめる**（`research/posted.json`・`research/covered.yaml`・`scripts/` を grep。レジェンドは引退の事実を一次情報で）。10/23 に「公開済み」「現役」の取り違えが3件あった。確かめて重なる・現役なら、作らずに報告する。
- **次回予告**（台本末尾の `outro_title`・取材メモの `watch`）を雛形のままにしない（10/23 のムシアラは「22.パブロ・バリオス」が残っていた）。中立の文（例「毎日、数字でサッカーを読み解きます」）にする。
- **サムネの人物の点検**（review）は、写真の credits.json の被写体名（subject_check）が英語だけだと、台本のカタカナ名と突き合わない。`被写体に デクラン・ライス / Declan Rice が…` のように**日本語名を併記**する。
- **同じカードが20秒以上続く**（review のカードの持ち）は、節の途中で `card: none` を入れて写真だけにする。
- **サムネの新機能**：財政の number 型は `thumbnail_layout: {layout: number, number: ..., crest_pos: right}` でクラブのロゴを数字の右の隙間（白い丸い台）に置ける。比べる型は `thumbnail_layout: {layout: classic, names: [左, 右], name_colors: ["#色", "#色"]}` で左右に色枠の名前を入れる。サムネの黒は55%まで（暗い夜の写真は昼の写真に）。
- **日本との接点（ヒットの条件）を台本に入れる**：2026-10-21 の分析で、登録が付くのは日本代表・W杯に絡む話と、題の人物本人の言葉。シリーズでも、日本との接点（日本人選手の縁・日本との対戦）があれば、基礎DATAの次の早い節に置く（無理に押し込まない。10/6 の決定どおり、無ければ入れない）。
- 出力ファイル名の鍵は、シリーズごとの見本の命名に合わせる（例：`20261024_player_<番号>`、`20261024_manager_ancelotti`、`20261024_team_spain`）。

## 10/24 の追加（2026-10-23）
- 今日（10/23）の実物を見本にする：スタジアム=`scripts/20261023_stadium_palace.md`、財政=`20261023_finance_acmilan.md`（サムネは赤黒の縞の自作グラフ型もある）、ユニフォーム=`20261023_kit_brighton.md`、選手紹介=`20261023_player_687626.md`、レジェンド=`20261023_ibrahimovic_legend.md`・`20261023_ono_shinji_legend.md`、監督=`20261023_manager_mourinho.md`、代表=`20261023_team_argentina.md`、比べる=`20261023_compare_598577_503743.md`、クラブ紹介=`20261023_bd_leverkusen.md`。
- **10/23 の自分の失敗を繰り返さない**：
  - 題材が公開済みと重ならないか、**台本を作る最初に自分で** `scripts/`・`research/covered.yaml`・`research/posted.json` を grep（10/23 は3件が重なって作り直した）。重なっていたら作らずに報告。
  - 台本の `image:` を1枚で全行に書かない。写真は3枚以上、節ごとに回す。
  - 比べるのサムネは、左右の名前の色枠が**顔の口元にかかる**ことがある。出来た絵を見て、かかるなら `thumbnail_layout.names` を外す（名前は帯に出る）。
  - 財政のサムネは、収入と損益の棒グラフを自作して「何の話か」を分かりやすくしてよい（見本は `output/thumb_samples/milan_chart_stripes.png`。数字は台本と同じ一次情報で）。
  - 名前の読みは requests で VOICEVOX の audio_query（`http://127.0.0.1:50021/audio_query?text=…&speaker=3`）で見る。割れる名前は報告に書く（config は触らない）。
  - 写真は「Getty などの代理店クレジットが入ったものは不可」。ネット（クラブ公式・Flickr・Commons・記事の主写真）から探してよい。
