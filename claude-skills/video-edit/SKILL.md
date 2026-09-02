---
name: video-edit
description: 手元の動画ファイルを ffmpeg で編集する（尺を測る・切る・つなぐ・縦型(9:16)にする・音量を揃える・BGMを敷く・テロップを焼く・サムネを抜く）。編集結果は必ずコンタクトシートやフレーム抽出で目視確認してから返す。「この動画を切って」「ショートにして」「音が小さい」「字幕を入れて」「尺を測って」「つなげて」と言われたときや、動画ファイルを渡されたときに使う。
---

# 動画編集（ffmpeg）

**動画を「素材から作る」のではなく、既にある動画ファイルを加工する**ときのスキル。
台本から作るほうは別系統（`projects/youtube-video-creation`、`platform/ai-lab/src/videogen`）。

## この環境の制約（先に読む。ここを外すと必ず詰まる）

1. **ffmpeg は PowerShell から呼ぶ。Git Bash からは呼べない。**
   ホームが `C:\Users\なみ\` と非 ASCII で、Bash 経由だとパスが cp932 に化けて
   `No such file or directory` になる。PowerShell ツールなら日本語パスのまま通る。
2. **`ffprobe` は無い。** 同梱されているのは `ffmpeg.exe` 単体。
   尺・解像度は `ffmpeg -i` の stderr を読む（後述）。
3. **`subtitles` フィルタに絶対パスを渡すと壊れる。**
   `C:\...` の `\` と `:` がフィルタの区切りとして食われ、
   `Unable to parse option value ... as image size` で落ちる。
   **作業ディレクトリへ `cd` して相対ファイル名で渡す**（後述）。
4. 長尺をいきなり全部エンコードしない。まず `-t 10` 程度の短い区間で試し、
   目で見てから本番を回す。エンコードは分単位で時間を食う。
5. **入力ファイルを上書きしない。** 出力は必ず別名にする。素材は取り返しがつかない。

## ffmpeg の場所

```powershell
$ff = python -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())"
```

`imageio-ffmpeg==0.6.0` が system python に入っており、ffmpeg 7.1 が同梱されている
（youtube PJT と同じ方式。PATH は汚していない）。無ければ
`python -m pip install imageio-ffmpeg==0.6.0`。

## 手順

### 1. まず測る

```powershell
& $ff -i "入力.mp4" -hide_banner 2>&1 | Select-String -Pattern "Duration|Stream #"
```

尺・解像度・fps・音声トラックの有無を確認してから編集方針を決める。
音声が無い素材に音声フィルタをかけて落ちる、が典型的な事故。

### 2. 編集する（下のレシピ集から選ぶ）

### 3. 必ず目視確認してから報告する

**ここを飛ばさない。** コマンドが exit 0 でも、切る位置がずれている・
黒画面になっている・テロップが枠外に出ている、はすべて素通りする。

```powershell
# 全体を俯瞰: 1秒おきに縮小して 4x2 のタイルに
& $ff -y -loglevel error -i "出力.mp4" -vf "fps=1,scale=320:-1,tile=4x2" -frames:v 1 "sheet.png"

# 一点を詳しく: 指定秒のフレームを1枚
& $ff -y -loglevel error -ss 3.0 -i "出力.mp4" -frames:v 1 "frame.png"
```

書き出した PNG を **Read ツールで開いて自分の目で見る**。
そのうえで「ここを切った」「テロップはこう出ている」と報告する。
長い動画なら `fps=1/5` などタイルの間隔を広げる。

## レシピ集（この環境で実行して通ったものだけ）

### 切る（トリム）

```powershell
# 正確に切る（再エンコード）。2.0秒から5.0秒まで
& $ff -y -loglevel error -ss 2.0 -to 5.0 -i "in.mp4" -c:v libx264 -pix_fmt yuv420p -c:a aac "out.mp4"

# 速いが切り口がキーフレームにずれる（下見・粗選び向け）
& $ff -y -loglevel error -ss 2.0 -to 5.0 -i "in.mp4" -c copy "out.mp4"
```

`-ss` を `-i` の**前**に置くと速く、後ろに置くと正確。再エンコードするなら前で十分正確。

### つなぐ

同じ形式どうしなら concat demuxer が速い。`list.txt` を UTF-8 で作る:

```
file 'a.mp4'
file 'b.mp4'
```

```powershell
& $ff -y -loglevel error -f concat -safe 0 -i "list.txt" -c copy "out.mp4"
```

解像度や fps が違う素材は上ではつながらない。揃えてから concat するか、
`concat` フィルタで一度に再エンコードする。

### 縦型(9:16)にする

```powershell
# 中央を切り抜く
& $ff -y -loglevel error -i "in.mp4" -vf "crop=ih*9/16:ih,scale=1080:1920" -c:v libx264 -pix_fmt yuv420p -c:a copy "short.mp4"

# 全体を残して上下を余白にする（テロップや図が切れて困るとき）
& $ff -y -loglevel error -i "in.mp4" -vf "scale=1080:-2,pad=1080:1920:0:(1920-ih)/2:black" -c:v libx264 -pix_fmt yuv420p -c:a copy "short.mp4"
```

中央クロップは被写体が中央にいる前提。**クロップ後は必ずコンタクトシートで確認する**
（人物や字幕が枠外に出るのがいちばん多い失敗）。

### 音を整える

```powershell
# ラウドネス正規化（YouTube は -14 LUFS 前後）
& $ff -y -loglevel error -i "in.mp4" -af "loudnorm=I=-14:TP=-1.5:LRA=11" -c:v copy -c:a aac "out.mp4"

# BGM を敷く（ナレーションが鳴っている間だけ BGM を下げる）
& $ff -y -loglevel error -i "in.mp4" -i "bgm.mp3" -filter_complex "[1:a]volume=0.25[b];[0:a][b]sidechaincompress=threshold=0.05:ratio=8[a]" -map 0:v -map "[a]" -c:v copy -c:a aac "out.mp4"
```

### テロップ・字幕を焼く

**必ず素材のあるディレクトリへ `cd` してから、相対ファイル名で渡す**（制約3）。

```powershell
Push-Location "素材のフォルダ"
& $ff -y -loglevel error -i "in.mp4" -vf "subtitles=sub.srt:force_style='FontName=Yu Gothic UI,FontSize=24'" -c:v libx264 -pix_fmt yuv420p -c:a copy "out.mp4"
Pop-Location
```

- SRT は **BOM 無し UTF-8** で書く。PowerShell の `>` や `Set-Content` は
  既定の文字コードが環境依存なので、`[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))` で書く。
- 日本語フォントは `Yu Gothic UI` / `Meiryo` / `MS Gothic` がこの PC にある
  （`C:\Windows\Fonts\YuGothR.ttc` 等）。指定しないと豆腐になることがある。
- 短い1枚テロップだけなら `drawtext` より SRT のほうが楽で崩れにくい。

### 静止画・サムネを出す

```powershell
& $ff -y -loglevel error -ss 5.0 -i "in.mp4" -frames:v 1 -q:v 2 "thumb.jpg"
```

### 速度を変える

```powershell
# 1.5倍速（映像と音声を両方）
& $ff -y -loglevel error -i "in.mp4" -vf "setpts=PTS/1.5" -af "atempo=1.5" -c:v libx264 -pix_fmt yuv420p "out.mp4"
```

`atempo` は 0.5〜2.0 の範囲。外れる倍率は `atempo=2.0,atempo=1.5` と連ねる。

## 書き出しの既定

配布・アップロード用は、指定がなければこれ:

```
-c:v libx264 -pix_fmt yuv420p -crf 18 -preset medium -c:a aac -b:a 192k -movflags +faststart
```

`yuv420p` を外すと一部プレイヤーで再生できない。`+faststart` はブラウザ再生用。

## 画像から動画を組む（フリー素材・ナレーション付き）

ゼロから作るときは ffmpeg を直に叩くより、`platform/ai-lab` の 2 つを使うほうが速い。
実行はすべて ai-lab の venv から（`PYTHONPATH=src .venv/Scripts/python.exe -m ...`）。

```bash
# 1. フリー素材を取る（CREDITS.md と credits.json が自動で付く）
python -m imagegen fetch "forest path" --source wikimedia -l 1 -o 出力先/images
#    使えるのは openverse / wikimedia / iconify（キー不要）。
#    pexels・pixabay・unsplash は API キーが要る。

# 2. ナレーションを作る（VOICEVOX ENGINE が要る。未起動なら下記で起動）
python -m imagegen say "読み上げる文章" --provider voicevox --voice 2 -o 出力先/speech --name n1

# 3. 動画に組む（--burn を付けないと字幕は焼かれず SRT が別に出るだけ）
python -m videogen build 構成.yaml -o out.mp4 --burn
```

- **構成 YAML の image / audio は絶対パスで書く。** 相対パスは YAML の位置ではなく
  実行時の cwd 基準で解決されるので、まず確実に外す。
- **`--burn` を忘れない。** 付けないと字幕は別ファイルの SRT になるだけで、映像には乗らない。
- videogen の字幕焼き込みは**日本語の絶対パスでも通る**（`filters.escape_for_filter` が
  処理している）。生 ffmpeg の `subtitles` で必要な「cd して相対パス」の回避策は要らない。
- シーンの長さは音声の長さから自動で決まる。音声が無いシーンだけ `seconds` を書く。
- VOICEVOX ENGINE の起動（ヘッドレス、GUI は開かない）:
  `Start-Process "C:\Users\なみ\AppData\Local\Programs\VOICEVOX\vv-engine\run.exe" -ArgumentList "--host","127.0.0.1","--port","50021" -WindowStyle Hidden`
  起動まで数秒。`http://127.0.0.1:50021/version` が返れば使える。
- **クレジットは必ず持ち回る。** `imagegen fetch` が出す CREDITS.md を捨てない。
  CC BY 系は表示が必須、CC BY-SA は継承つき、GFDL は動画用途には条件が重いので避ける。
  ライセンスと被写体の権利（肖像権・商標）は別物。

## 画像を使う前の権利チェック（公開・収益化する動画では必ず通す）

一次情報で確認した内容（末尾に出典）。**判断に迷ったら使わない。**

### 1. まず「なぜその画像が要るか」を言えるか

**「絵が寂しいから」で貼った他人の写真は、出典を書いても引用にならない。**
文化庁 著作権テキスト p.77 が明記している:

> 自己の著作物に登場する必然性のない他人の著作物の利用や、美術の著作物を実質的に
> 鑑賞するために利用する場合は引用には当たりません。

引用（32条）が成立するのは、その画像**そのものを論評・報道の対象にしている**とき。
賑やかしは対象外。**この場合は「使えるライセンスの素材を探す」しか道がない。**

### 2. ライセンス早見表（YouTube 収益化を前提とした可否）

| ライセンス | 可否 | 理由 |
|---|---|---|
| **CC0 / パブリックドメイン** | ◎ | 条件なし。第一候補 |
| **CC BY** | ◎ | 表示だけで足りる。YouTube も「CC BY なら帰属表示で安全に使用できる」と明記 |
| **CC BY-SA** | △ 避ける | Ken Burns のズームやクロップは CC 4.0 の "Adapted Material"（`altered, arranged, transformed, or otherwise modified`）に当たり、**動画側も BY-SA で出す**必要が生じる |
| **CC BY-ND** | ✗ | 改変禁止。クロップ・ズーム・字幕重ねが改変に当たる |
| **CC BY-NC** | ✗ | 収益化と両立しない |
| **GFDL** | ✗ | ライセンス全文の提示を求める設計で、動画には載せきれない |
| **報道写真（Getty / AFP / ロイター / クラブ公式SNS）** | ✗ | 有償ライセンスが要る。出典明記では代替できない |

### 3. 41条（時事の事件の報道）を過信しない

条文が許すのは「**当該事件を構成し、又は当該事件の過程において見られ、若しくは聞かれる**
著作物」だけ。試合を報じるときのその試合の写真は射程に入りうるが、
**移籍ニュースの解説に無関係な選手写真を貼る**のは射程外。

### 4. 肖像・パブリシティ権（著作権とは別に残る）

最高裁 平成24年2月2日（ピンク・レディー事件）の基準:

> 肖像等を無断で使用する行為は、①肖像等それ自体を独立して鑑賞の対象となる商品等
> として使用し、②商品等の差別化を図る目的で肖像等を商品等に付し、③肖像等を商品等
> の広告として使用するなど、**専ら肖像等の有する顧客吸引力の利用を目的とする**と
> いえる場合に、パブリシティ権を侵害するものとして、不法行為法上違法となる

ニュースとして事実を伝える範囲なら通常は当たらない。**危ないのはサムネイル**で、
選手の顔を大きく置いて客寄せにすると③に近づく。写真のライセンスが清潔でも別問題。

### 5. 商標（クラブエンブレム）

商標権は「出所表示としての使用」を規制するものなので映り込み自体が直ちに侵害には
なりにくいが、**エンブレムの図柄自体が著作物**でもあり、クラブの利用規約も別にある。
**使わないのが安全。**

### 6. YouTube 上で通用しない言い訳（公式ヘルプが名指しで否定）

- 「著作権者を明記すれば使ってよい」→ **誤り**
- 「非営利・教育目的なら使ってよい」→ **誤り**
- 「著作権侵害の意図はありません と書けばよい」→ **誤り**
- 「他のクリエイターもやっている」→ **誤り**
- 「数秒なら問題ない」→ **誤り**

### 7. 実務: 絵を増やしたいときの安全な順番

1. **自前生成** — `projects/youtube-video-creation/src/backgrounds.py`（スタジアム/ピッチ/戦術ボード）。権利ゼロ
2. **CC0 / PD** — `imagegen fetch --source openverse`（`license_type=commercial,modification` で絞り込み済み）
3. **CC BY** — 概要欄に 作品名/作者/ライセンス/リンク を書く
4. **AI生成** — `imagegen gen`（pollinations はキー不要）
5. 人物ではなく**場所・物**（スタジアム外観、街並み、トロフィー、ボール）を狙うと、
   肖像・商標の問題を同時に避けられる

**素材を取るときは `imagegen fetch` を直に使わない。**あれは検索上位から順に落とすので、
ライセンスを見ずに GFDL や BY-SA を掴む（実際に掴んだ）。代わりに同梱の取得スクリプトを使う:

```bash
cd C:/Users/なみ/dev/workspace/platform/ai-lab
PYTHONPATH=src .venv/Scripts/python.exe "C:/Users/なみ/.claude/skills/video-edit/fetch_safe.py" \
  "Emirates Stadium" -n 3 -o 出力先 --dry-run
```

広く検索（既定25件）してから **CC0 / PD / CC BY だけ**に絞り、解像度の大きい順に落とす。
`--dry-run` で選別結果だけ先に見る。**検索母数は減らさないこと** — 実測で
「Emirates Stadium」は25件中22件が CC BY-SA で、使えたのは CC0 の3件だけだった。

`imagegen fetch` が出す `CREDITS.md` / `credits.json` を捨てない。
**書き出す前に、このスキル同梱の判定スクリプトを必ず通す**（目視で見落とすため）:

```bash
python "C:/Users/なみ/.claude/skills/video-edit/check_licenses.py" <素材フォルダ>
```

終了コード 0 = そのまま書き出してよい / 1 = 使用不可が混在（差し替える）/
2 = 要注意・要確認あり（判断してから進む）。GFDL・ND・NC を弾き、SA と不明を警告する。

**判定が全部 OK でも、そこで終わらせない。ライセンスは写真の著作権しか見ていない。**
落としたら必ず一覧画像を作って**自分の目で中身を見る**。実際に、CC0/CC BY で通ったのに
使えなかったものが 12 枚中 5 枚あった:

| 見つかった問題 | 対応 |
|---|---|
| CC0 のスタジアム写真に、クラブのエンブレムと選手の壁画が**主役として**写っていた | エンブレムを外してクロップ、または生成画像に差し替え |
| CC BY のスパイク写真にメーカーロゴが大写し | クロップで縮小。ロゴを主役にしない |
| ファイル名が選手名でも、**本人と断定できない**（代表チームの集合写真など） | Commons のページで撮影情報を確認。確認できないなら顔を使わず、クラブカラー＋名前のカードにする |
| 被写体が**未成年** | 使わない |
| タイトルと中身が合っていない（「ファン」が市場の風景） | 弾く |
| **`football` で検索するとアメフトが混ざる**（審判・練習の写真が NFL 系だった） | サッカーを狙うなら `soccer` / `association football` / 固有名（`Camp Nou`）で引く |
| 画像が 90 度回転していた（縦位置撮影の Exif 無視） | 使う前に向きを直す。一覧画像を見れば気づく |

### SNS（Instagram / X）の画像は使わない

投稿画像の著作権は**投稿者**にある。プラットフォームの規約はサービス側にライセンスを
与えるもので、**第三者に利用権を与えない**。埋め込み表示と、動画に焼き込む複製は別物で、
後者は複製・公衆送信に当たる。

さらに、**切り抜くと著作者名表示が落ちる**。最高裁 令和2年7月21日は、トリミング表示で
著作者名が表示されなくなった事案で氏名表示権の侵害を認めている。動画に入れる時点で
必ずトリミングするので、この問題を避けられない。

このリポジトリの既存方針も同じで、`projects/youtube-video-creation` は X を
**本文（事実の材料）としてのみ**使い、画像は取らない。`@ハンドルは画面に出さない`
（CLAUDE.md）。SNS 段階の情報は確度「未確認」として扱う。

### 出典（すべて原文を確認済み）

- 著作権法 [第32条・第41条・第30条の2・第48条](https://laws.e-gov.go.jp/law/345AC0000000048/)（e-Gov 法令検索）
- 文化庁 [著作権テキスト 令和7年度版](https://www.bunka.go.jp/seisaku/chosakuken/seidokaisetsu/pdf/94283401_01.pdf) p.77（引用の4条件）・p.89（41条の3条件）
- 最高裁 平成24年2月2日 [判決全文PDF](https://www.courts.go.jp/app/files/hanrei_jp/957/081957_hanrei.pdf) p.3
- [CC BY-SA 4.0 legalcode](https://creativecommons.org/licenses/by-sa/4.0/legalcode.en) 第1条 Adapted Material / 第3条(a)(b)
- YouTube ヘルプ [著作権に関するよくある誤解](https://support.google.com/youtube/answer/2797449?hl=ja)

一般的な情報の整理であって法律上の助言ではない。公開規模が大きい案件や、
権利者から連絡が来た場合は弁護士に相談すること。

## 報告するとき

- 何を・どこからどこまで・どう変えたかを、**秒数で**書く
- 目視で見たフレームの内容に触れる（「3秒地点でテロップは下端から60px、切れていない」）
- 尺とファイルサイズの前後を並べる
- 元ファイルは残してあることを添える
