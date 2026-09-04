# assets

`python -m src.cli init-assets` で仮の背景・立ち絵が生成される。
生成物と差し替えた素材は git 管理外（.gitignore 済み）。

```
assets/
  backgrounds/default.png          背景
  characters/<key>/<表情>_<close|open>.png   立ち絵（背景透過PNG）
  images/                          本編に差し込む図など（任意）
  audio/                           BGM・効果音（init-assets が仮素材を合成する）
```

表情は normal / smile / angry / surprise。無いものは normal にフォールバックする。

## 素材は2種類ある。復元の手順が違う

台本の `bg:` / `@bg:` が指す先が無くて build が止まったときは、どちらか見分ける。

**1. init-assets が作るもの**（`stadium.png` `pitch.png` `tactics.png` など）

```bash
python -m src.cli init-assets
```

これで作り直せる。既存の台本が参照しているのはほぼこれ。

**2. 外から取ってきた写真から作ったもの**（`chelsea.mp4` `monaco.mp4` など）

`init-assets` では作れない。**元の写真を取り直してから、クリップにし直す。**

```bash
# どの画像から作ったかは、クリップの隣の .source.txt に書いてある
cat assets/backgrounds/chelsea.mp4.source.txt

# その画像の取得元URLとライセンスは credits.json にある（こちらは git 管理下）
python -c "import json;[print(r['file'],r['license'],r['image_url']) for r in json.load(open('assets/images/camara/credits.json',encoding='utf-8'))]"

# 取り直したらクリップにする
python -m src.cli make-clip <画像> --out assets/backgrounds/chelsea.mp4
```

## ライセンス

配布素材を使う場合はライセンスを確認し、必要なクレジットを概要欄に入れること。
**CC BY 系は表示が条件**で、書かないと利用条件を満たさない。

- 素材は `~/.claude/skills/video-edit/fetch_safe.py` で取る。CC0 / PD / CC BY だけに絞る
- 書き出す前に `check_licenses.py` を通す
- この2つは**リポジトリにも `claude-skills/video-edit/` として控えがある**。
  正は `~` 側で、同期は `scripts/sync-skills.ps1 -Export`（ルート CLAUDE.md 参照）。
  `~` 側が無い環境では、リポジトリの控えを使う
- **人物が写る写真は `subject` で本人を確かめる。** ファイル名は根拠にならない

  ```bash
  python -m src.cli subject assets/images/<フォルダ> 上田綺世 "Ayase Ueda"
  ```

  実測で、ファイル名に `Ayase Ueda` と入った写真の被写体が構造化データでは
  別人（Joris Kramer）だった。**ライセンス判定は3件とも OK を返していた。**
  被写体の指定が無い写真は「本人ではない」ではなく「確かめられない」なので、
  使わない
- **判定が OK でも必ず目視する。** ライセンスは写真の著作権しか見ていない。
  実測で6枚中4枚を目視で落とした（被写体が違う / 彫刻が写っている /
  クラブ掲示やメーカーロゴが主役級）
- クレジットは `src/tts.py` の `image_credits` が概要欄に自動で入れる。
  クリップにすると名前が変わるので、`.source.txt` で元画像に繋いでいる

`assets/images/` 自体は git 管理外だが、**`CREDITS.md` と `credits.json` だけは
追跡している**（由来を後から確かめられるようにするため／再取得の手順書を兼ねる）。
