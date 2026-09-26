# 方式7 Reddit — コミュニティの数え上げ（2026-09-26）

`docs/session-briefs/method7.md` の手順1・2の結果。台帳（`docs/monetization-plans.md`）の方式7の行はここを指す。

## 調べ方

- WAU は各コミュニティのページに Reddit 自身が埋め込んでいる `weekly-active-users` の値（サイドバーの「週の訪問者」と同じもの）。
  規約の「300 Weekly Active Users」と同じ指標かは規約に定義が無く、**同じものとみなした**
- 候補は Reddit のコミュニティ検索に 60 語（puzzle / riddle / crossword / wordle / sudoku / trivia / quiz / chess puzzle …）を
  入れて 3,929 件集め、名前か説明にパズル・ゲーム系の語があり登録者 3,000 以上の 295 件の WAU を測った。
  300 以上は 265 件。そこから話題違い（r/mildlyinteresting、r/psychology、ドラマのファン等）と、
  **他の作者のゲーム専用コミュニティ**（下の節）を手で外して **93 件**
- 既に入っているアプリは、各コミュニティの新着 100 投稿から「Devvit の投稿（リンク先ドメインが空で本文投稿でない）」を
  数えた。クロスポスト（転載）も同じ形になるので除いた
- 取得は手元の Chrome（CDP）から。Reddit はクラウドや curl からは 403 になる

## 結果

1. **300WAU 以上のパズル・ゲーム系コミュニティは 93 件ある。** 50 件の数そのものは足りる
2. **その 93 件の新着各 100 投稿に、コミュニティ内で動いている Devvit アプリの投稿は 0 件。**
   Devvit の形をした投稿は全部、作者が自分のゲーム専用コミュニティから転載したもの
3. **アプリ一覧（developers.reddit.com/apps）でも、導入 50 を超えるゲーム系アプリは Quiz Planet（80）だけ。**
   以下 Unscramble-Game 48、Interactive Guess and Choices 31、worldtrivia 29、Daily Guess 19。
   「puzzle」で検索した人気順の1位は Tarot Cat Puzzle の **6**。数独・チェス・迷路はどれも一桁。
   この導入数は 300WAU 未満や作者自身のコミュニティも含んだ数なので、条件を満たす導入はさらに少ない
4. 導入数の上位は**モデレーターが自分のコミュニティ向けに中身を入れられる型**（利用者がクイズを作る Quiz Planet、
   単語を入れる Unscramble、設定式の Guess）。固定のパズルを配る型は伸びていない

→ **インストール型（50件で $500）は、数は足りるが、パズル系の管理人がゲームを入れている実例がほぼ無い。**
置き換える相手もいないが、入れてもらえる根拠も無い。

### 規約で指示書に無かった点（H2 2026 Terms を読み直した）

- **自分がモデレーターのコミュニティへの導入は、原則として数えない**（そのコミュニティに役立つ場合を除く）
- 「Qualified Install」は**パズル系に限らず、300WAU 以上で SFW のコミュニティならどこでも**よい
- 利用者型の「1日の利用者」は、**300WAU 以上のコミュニティ内で**遊んだログイン利用者だけを数える
- 同じ作者の似たアプリは1本として数えられうる
- 開発者規約（2026-03-24 改訂）に利用者サポート・返金の義務は無い。
  あるのはプライバシーポリシーへのリンクと、利用者が投稿する中身を扱うなら削除依頼の窓口（DMCA 等）

### 利用者型（1日 5,000 人）の目安

公式の公開手順（Launch Guide）では**ゲームは専用コミュニティを持つことが前提**で、
配られ方はおすすめ表示での反応（クリック・滞在・投票）で決まる。上位の取り上げ（Featuring）は
初日・3日目の再訪率と滞在時間で選ばれる。

日替わりゲームの専用コミュニティの WAU（同じ日に測定。アプリの1日利用者数ではない）:

| コミュニティ | WAU | 中身 |
|---|---:|---|
| r/FitTheWord | 91,344 | 単語ゲーム集 |
| r/DesignerEye | 59,875 | 色の記憶 |
| r/PigmentPourDaily | 38,486 | 色の注ぎ分け（日替わり） |
| r/DailyGuess | 30,729 | Wordle 型 |
| r/DailyGrid | 20,389 | 単語の格子 |
| r/pocketgrids | 17,434 | ミニクロスワード（日替わり） |
| r/DailyMix | 10,056 | Connections 型 |
| r/arrowspuzzle | 8,198 | 矢印の論理パズル |
| r/LETTERSET | 7,390 | 単語（日替わり） |
| r/Pixelary | 6,936 | お絵かき当て（公式の見本） |
| r/TileUp / r/Sneakle / r/CrosswordChef / r/Laddergram / r/hexaword / r/Blokkit / r/WordFusions / r/Redactle | 3,761〜1,069 | 日替わりの単語・パズル |

## 93 件の一覧（WAU は 2026-09-26 の値）

### パズル・なぞなぞ（26件）

| コミュニティ | WAU | 週の投稿・コメント |
|---|---:|---:|
| r/puzzles | 117,381 | 1,594 |
| r/opticalillusions | 85,039 | 961 |
| r/Jigsawpuzzles | 80,197 | 4,272 |
| r/Cubers | 63,754 | 2,451 |
| r/riddles | 53,599 | 232 |
| r/rebus | 51,302 | 343 |
| r/escaperooms | 18,390 | 178 |
| r/Rubiks_Cubes | 11,184 | 519 |
| r/VisualPuzzles | 9,198 | 763 |
| r/LogicPuzzles | 5,807 | 44 |
| r/wimmelbilder | 5,191 | 63 |
| r/brainteasers | 4,027 | 218 |
| r/mathpuzzles | 2,171 | 90 |
| r/adventofcode | 2,133 | 92 |
| r/mazes | 1,982 | 72 |
| r/Enigmes | 1,894 | 16 |
| r/Spottit | 1,878 | 59 |
| r/mathriddles | 1,784 | 34 |
| r/puzzle | 1,746 | 87 |
| r/pipepanic | 1,482 | 27 |
| r/RiddlesForRedditors | 1,078 | 28 |
| r/PuzzleBox | 979 | 4 |
| r/BlackboxPuzzles | 803 | 2 |
| r/whereswaldo | 717 | 3 |
| r/Puzzlexchange | 469 | 31 |
| r/SmartPuzzles | 399 | 6 |

### ことば・クロスワード（18件）

| コミュニティ | WAU | 週の投稿・コメント |
|---|---:|---:|
| r/words | 154,885 | 3,837 |
| r/wordle | 60,102 | 2,308 |
| r/NYTLetterBoxed | 51,438 | 84 |
| r/NYTConnections | 46,861 | 2,436 |
| r/crossword | 30,165 | 823 |
| r/NYTgames | 19,515 | 155 |
| r/NYTCrossword | 19,213 | 465 |
| r/NYTSpellingBee | 10,808 | 375 |
| r/scrabble | 10,662 | 55 |
| r/crosswords | 9,930 | 581 |
| r/WordsWithFriends | 6,131 | 279 |
| r/4pics1word | 5,107 | 215 |
| r/wordgames | 4,857 | 404 |
| r/rockbusters | 4,222 | 211 |
| r/Minute_Cryptic | 3,508 | 542 |
| r/wordlegame | 2,962 | 174 |
| r/dictionary | 2,736 | 37 |
| r/crackingthecryptic | 1,141 | 68 |

### ロジック・数字（8件）

| コミュニティ | WAU | 週の投稿・コメント |
|---|---:|---:|
| r/sudoku | 35,377 | 1,211 |
| r/Minesweeper | 29,118 | 825 |
| r/puzzlevideogames | 26,522 | 587 |
| r/Tetris | 25,770 | 574 |
| r/murdoku | 17,962 | 294 |
| r/nonograms | 3,899 | 183 |
| r/Picross | 2,745 | 85 |
| r/2048 | 2,432 | 51 |

### 暗号（4件）

| コミュニティ | WAU | 週の投稿・コメント |
|---|---:|---:|
| r/codes | 9,400 | 215 |
| r/ciphers | 4,528 | 160 |
| r/Decoders | 4,205 | 105 |
| r/Cipher | 1,028 | 55 |

### クイズ・知識（14件）

| コミュニティ | WAU | 週の投稿・コメント |
|---|---:|---:|
| r/Jeopardy | 101,388 | 1,208 |
| r/quiteinteresting | 62,255 | 288 |
| r/cognitiveTesting | 48,957 | 2,628 |
| r/RedactedCharts | 43,157 | 2,762 |
| r/GeographyTrivia | 38,667 | 649 |
| r/onlyconnect | 36,137 | 994 |
| r/trivia | 23,085 | 1,250 |
| r/TriviaChat | 22,720 | 301 |
| r/quiz | 18,349 | 441 |
| r/thechase | 17,932 | 283 |
| r/iqtest | 9,860 | 311 |
| r/UniversityChallenge | 3,664 | 32 |
| r/Sporcle | 1,502 | 94 |
| r/Quizbowl | 731 | 1 |

### 当てっこ（画像を当てる）（10件）

| コミュニティ | WAU | 週の投稿・コメント |
|---|---:|---:|
| r/tipofmytongue | 396,955 | 12,403 |
| r/guessthecity | 266,670 | 6,889 |
| r/geoguessr | 97,877 | 1,832 |
| r/namethatcar | 93,682 | 1,148 |
| r/guessthegolfcourse | 66,503 | 6,723 |
| r/ExplainAFilmPlotBadly | 64,798 | 7,621 |
| r/GeoPuzzle | 59,116 | 708 |
| r/GuessTheMovie | 35,714 | 8,253 |
| r/GuessTheCoaster | 4,020 | 4,345 |
| r/geochallenges | 985 | 65 |

### チェス（9件）

| コミュニティ | WAU | 週の投稿・コメント |
|---|---:|---:|
| r/chess | 538,039 | 13,804 |
| r/chessbeginners | 227,950 | 7,233 |
| r/AnarchyChess | 209,754 | 3,207 |
| r/Chesscom | 142,313 | 6,212 |
| r/ChessPuzzles | 23,044 | 361 |
| r/chessmemes | 19,493 | 110 |
| r/chessMateInX | 11,413 | 202 |
| r/lichess | 11,136 | 602 |
| r/chessquiz | 7,632 | 1,256 |

### ボードゲーム（4件）

| コミュニティ | WAU | 週の投稿・コメント |
|---|---:|---:|
| r/boardgames | 542,815 | 14,552 |
| r/soloboardgaming | 63,740 | 2,343 |
| r/abstractgames | 1,139 | 120 |
| r/boardgame | 1,119 | 170 |
