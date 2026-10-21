# 10/21 シリーズ10本の共通の指示（2026-10-20）

作業ディレクトリは `C:\Users\なみ\dev\wt-yt-1014\projects\youtube-video-creation`（git worktree）。`PYTHONIOENCODING=utf-8` を付ける。
決まりの本体は `CLAUDE.md`（特に「毎日固定のシリーズは10」の表、「シリーズの質の決まり」「見せる前の決まり」「サムネの構図」「画像の数」）。

## やること（台本を見せる手前まで）
1. 取材メモ `research/20261021_<key>.yaml` を書き、`python -m src.cli draft research/20261021_<key>.yaml --allow-repeat`（既存の台本があれば先に rm）で台本 `scripts/20261021_<key>.md` を作る。ヒントは全部読む。
2. `python tools/precheck.py scripts/20261021_<key>.md`（本編を作らないショートは不要。シリーズは `--no-preview` ではなく preview4 まで通す）。× は直す。
3. 流れの点検：`python tools/flow.py --prompt` の5つの問いを自分で当てて直し、`output/flow/20261021_<key>.md` に書く（1行目「# 流れの点検: 20261021_<key>（読み手: Claude。Gemini は無料枠切れ）」、台本より新しいこと）。
4. サムネを作る（`python -m src.cli thumbnail scripts/20261021_<key>.md` か `tools/thumblayout.py`）。**型はシリーズごとに決定済み**（下）。出来た絵を自分で見て、字・顔・黒の割合・名前を確かめる。
5. approve・build・upload・git・`src/` `tools/` `config/` `CLAUDE.md` の編集はしない。VOICEVOX を使う処理（build/short/audio）はしない（他の作業が1本ずつ回す）。ブラウザの道具は使わない（WebFetch と requests だけ）。
6. 最後に日本語で簡潔に報告：ファイルの場所、題、尺（preview4 の見積り）、precheck の残り、サムネの文字と根拠の事実、写真の出典と不安、確かめられなかったこと。**事実は出典で確かめた値だけ。確かめられない数字は台本に入れない。**

## 共通の決まり（抜粋）
- シリーズの地の文は解説1人。本編は実尺6分まで（preview4 の見積りは5分半まで。見積りは実物より短く出る）。
- 題は人名かクラブ名で始め、答えを言い切らず、問いで終える。見立ての節を置く（数字2つ以上＋比べ）。節の見出しは中身の問い。
- 同じ画面・同じ写真を20秒以上続けない。写真は3枚以上。代理店（Getty/AFLO/AFP/Reuters/IMAGO）と放送映像は使わない。取り込んだら目で見て本人か確かめる。出典は credits.json に控える。
- 概要欄に出すのは、出さなければならないもの（CC BY の撮影者名など）だけ。**credits.json の撮影者名に HTML（`<a ...>`）が残っていないか見る**（今日 `<` `>` で投稿が弾かれた）。
- 女子サッカー・Jリーグは扱わない。選手・監督を小さく見せる言い方（「〜だけ」「最下位」）をしない。病気・私生活・法的な問題は入れない。
- FotMob は使わない（基本の数と、自分で割った90分あたり）。
- 今日（10/20）の実物を見本にする：スタジアム=`scripts/20261020_stadium_etihad.md`、財政=`20261020_finance_villa.md`、ユニフォーム=`20261020_kit_tottenham.md`、選手紹介=`20261020_sobosslai_intro.md`、レジェンド=`20261020_beckham_legend.md`、比べる=`20261017_compare_pedri_vitinha.md`、クラブ紹介=`scripts/20260926_ll20_villarreal.md`。
- 直近30日に公開した本と、人名・クラブ名の組み合わせが重ならないか `research/posted.json` と `research/covered.yaml` で見る。

## サムネの型（シリーズごとに決定済み。2026-10-20）
- クラブ紹介：基礎DATAの板（`thumbnail_board`）＋エンブレム主役。黒の基準は見ない。
- 選手紹介／レジェンド／監督紹介：選手紹介（ヤマル）型＝全面写真＋`tools/thumbpanel.py` の通算の表（左）＋クラブのエンブレム（右）＋黄色い帯（黒1行目「◯◯、通算N試合M点」14字以内・赤2行目）。札は付けない。見本は `output/thumb_samples/監督サムネA_選手紹介型.png`（グアルディオラ）、`assets/images/20261020_sobosslai_intro/panel_09.jpg`。
- 代表チーム紹介：基礎DATAの板。見本は `output/thumb_samples/team_brazil_A_board.png`。
- スタジアム紹介：scene 型（全景＋下の黒い帯。2行目14字まで）。
- クラブの財政：number 型（最強の数字を大きく。写真は横長）。
- ユニフォームとエンブレム：classic（写真＋黄色い帯＋吹き出し2つ）。
- 比べる：ペドリとヴィティーニャ型（2人を左右に、`thumbnail_photos` 2枚＋`face_link: VS`、エンブレムは上隅、黄色い帯）。
