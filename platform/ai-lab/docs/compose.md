# compose — 画像に見出しを載せる

生成AIも素材サイトも「絵」までしか用意してくれない。実際に要るのは
**その絵に見出しを載せた1枚**（サムネイル・OGP・共有画像）なので、その工程がこれ。

```bash
imagegen compose --title "今日の値上がりランキング" --subtitle "2026-09-01" --preset ogp --band
imagegen compose --title "バルセロナが新加入選手を発表" --bg output/images/stadium.png --dim 0.45 --stroke 3
```

生成AIを使わないので待たされず、**同じ指定からは常に同じ画像**が出る。
依存は Pillow だけで、`imagegen` の他のコマンドと同じ `[image]` extras に入っている。

## 仕上がりサイズ

| プリセット | サイズ | 用途 |
|---|---|---|
| `youtube`（既定） | 1280x720 | 動画のサムネイル |
| `ogp` | 1200x630 | ブログ・SNS のカード |
| `shorts` | 1080x1920 | 縦動画 |
| `square` | 1080x1080 | 正方形の投稿 |
| `wide` | 1920x1080 | スライド・全画面 |

`--size 1280x720` と直接書けば、プリセットより優先される。

## 文字の収め方

**見出しは大きいほどよい**ので、指定した大きさから始めて、収まるまで縮める。

1. 枠幅で折り返す（日本語は1文字単位。書いた人が入れた改行は残す）
2. 3行を超える、または高さの55%を超えるなら文字を小さくして1に戻る
3. 下限（12px）まで来たら、そこで止めて3行に切る

読ませるための道具も用意してある。

| 指定 | 効果 |
|---|---|
| `--band` | 文字の背後に半透明の帯を敷く（端に寄せたときは画面の端まで伸びる） |
| `--stroke 3` | 袋文字にする。写真の上でいちばん効く |
| `--dim 0.45` | 背景を暗くする |
| `--blur 6` | 背景をぼかす |
| `--position top/center/bottom` `--align left/center/right` | 文字の置き場所 |

日本語が「□□□」になるときはフォントが見つかっていない。`--font C:/Windows/Fonts/meiryo.ttc`
のように渡すか、`imagegen/fonts.py` の候補に足す。

## ロゴ

```bash
imagegen compose --title "見出し" --logo assets/logo.png
```

`--logo` は四隅のどこかに重ねる（既定は右下）。**文字が無くても載る**ので、
背景＋ロゴだけの素材も作れる。

## レシピから使う

集めた見出しをそのままサムネイルにできる。

```yaml
name: 週次サムネイル
steps:
  - id: news
    feed: { source: github, query: "anthropics/claude-code", limit: 1 }
  - compose:
      title: "{{ news.0.title }}"
      subtitle: "{{ today }}"
      preset: ogp
      band: true
      out: output/compose
      filename: "{{ today }}_release"
```

`compose` が返すのは `path` と `size`。そのまま次の `publish` に渡せる。

## Claude から使う（MCP）

`imagegen mcp` で起動すると `compose_image` が生えている。
背景を省けばベタ塗りになるので、素材が無くても1枚作れる。

## Python から使う

```python
from imagegen import compose

image = compose.compose(
    title="今日の値上がりランキング",
    subtitle="2026-09-01",
    background="output/images/bg.png",
    preset="ogp",
    band=True,
    dim=0.4,
)
image.save("output/compose/rank.png")
```

戻り値は生成画像と同じ型（`GeneratedImage`）なので、`imagegen.imaging.convert()` で
webp に変換したり、`imagegen publish` でそのまま送ったりできる。
`provider` は `compose` になる。

## 決めごと

- **乱数を使わない。** 同じ指定から同じ画像が出ることが素材としての価値。
- **設定の誤りは描く前に返す**（未知のプリセット・色・位置、素材の不足）。
- 生成AIの絵（`imagegen gen`）や取得した素材（`imagegen fetch`）を背景にできるが、
  **素材のライセンス表記の義務は消えない**。`CREDITS.md` は取得時のものを持ち回ること。
