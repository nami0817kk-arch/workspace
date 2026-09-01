# videogen — 画像 + 音声 + 字幕 → 動画

`imagegen`（画）と `imagegen say` / `audiogen`（音）で作った素材を、
1本の mp4 にまとめる。**構成（タイムライン）を書いて `videogen build` を打つだけ。**

```bash
videogen doctor                       # ffmpeg が使えるか
videogen build news.yaml -o news.mp4  # 書き出す
videogen build news.yaml --dry-run    # 実行せず、組み上がった ffmpeg のコマンドを見る
```

## ffmpeg の用意

Python の依存は増やしていない。要るのは ffmpeg の実行ファイルだけで、探す順番は次のとおり。

1. 環境変数 `VIDEOGEN_FFMPEG`（場所を明示する）
2. PATH 上の `ffmpeg`
3. `imageio-ffmpeg` が同梱しているもの

システムに入れたくなければ、これで足りる。

```bash
pip install -e ".[video]"
```

テストは ffmpeg を**起動しない**（組み立てたコマンドを検証する）ので、`[dev]` には入れていない。

## 構成（タイムライン）

```yaml
size: 1920x1080     # 既定。縦動画にするなら 1080x1920
fps: 30
fade: 0.5           # 先頭と末尾の暗転（秒）
bgm: assets/bed.wav
bgm_gain_db: -18    # ナレーションを消さないよう下げる
tail: 0.3           # 音声から尺を決めたときの余白

scenes:
  - image: output/images/opening.png
    audio: output/speech/n1.wav
    text: バルセロナが新加入選手を発表      # 字幕
    motion: zoom_in
  - image: output/images/stadium.png
    audio: output/speech/n2.wav
    text: 移籍市場は今週末まで
    motion: pan_right
  - image: output/images/end.png
    seconds: 3                              # 音声が無いシーンは秒で指定する
```

JSON でも書ける（`.json` なら PyYAML すら要らない）。

### シーンの長さの決まり方

**音声の長さがそのままシーンの長さになる。** ナレーションを先に作ってから画を並べる
作り方に合わせてある。優先順位は次のとおり。

1. `seconds`（明示した値）
2. 音声の長さ + `tail`（読み終わりで画がすぐ切り替わらないように）
3. 4.0秒（音声も `seconds` も無いとき）

WAV の長さは標準ライブラリで測る。ffmpeg を呼ぶのは MP3 など WAV 以外のときだけ。

### 画の動き（motion）

| 値 | 動き |
|---|---|
| `none`（既定） | 動かさない。**画の全体を見せる**（切り取らないので図やサムネイル向き） |
| `zoom_in` / `zoom_out` | ゆっくり寄る / 引く |
| `pan_left` / `pan_right` | ゆっくり横に流す |

`none` 以外は画面を埋めるため上下左右が切れる。がたつきを抑えるために一度大きく
作ってから縮めている。

## 字幕

**焼き込むかどうかに関係なく、SRT は必ず動画の隣に書き出す。**
YouTube にはこのファイルをそのまま渡せる。字幕の無いシーンは飛ばして番号を振る。

映像に焼き込むときは `--burn`（ffmpeg 側に libass が要る）。
フォントは構成の `font` で指定する。焼いた字幕は消せないので、既定では焼かない。

```bash
videogen build news.yaml --burn
videogen srt news.yaml            # 字幕だけ作り直す
```

## 縦動画（Shorts）

同じ構成のまま、サイズだけ差し替えて出せる。

```bash
videogen build news.yaml --size 1080x1920 -o news_vertical.mp4
```

## 音の扱い

- シーンの音声は、シーンの長さに**必ず**合わせる（短ければ無音で埋め、長ければ切る）。
  ここを揃えないと、つないだときに映像と音がずれていく。
- 音声の無いシーンには無音を作る。concat のペアが常に揃うので、構成が変わっても壊れない。
- BGM は `-stream_loop -1` で足りない分を繰り返す。`amix` は既定で入力の音量を等分に
  下げてしまうため `normalize=0` にし、下げるのは BGM 側だけにしている。

## 組み立てと実行を分けてある

`build.build_command()` は ffmpeg を呼ばない純粋な関数で、返すのは引数のリスト。
実行するのは `build.render()` だけ。おかげで、

- ffmpeg が入っていない環境でも中身をテストできる
- `--dry-run` で、何が実行されるのかを目で確かめられる
- 失敗したとき、同じコマンドを手で叩いて切り分けられる

## Python から使う

```python
from videogen import build, timeline

tl = timeline.load("news.yaml")
print(tl.durations())          # 各シーンの尺
result = build.render(tl, "news.mp4")
print(result.seconds, result.srt)
```

## 作り方の流れ（imagegen と合わせて）

```bash
imagegen say "今日のニュースです。" -o output/speech --name n1   # 音
imagegen gen "ニューススタジオ" --style flat -o output/images    # 画
videogen build news.yaml -o output/video/news.mp4                # 動画
```
