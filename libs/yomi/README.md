# yomi — 合成音声の読み違いを、音を出す前に見つける

VOICEVOX などの読み上げで起きる誤読（「万石」をマンゼキ、「織田家」をオダカ、「披露」をツユ…）を、
台本の文とエンジンが返したカナから機械で拾う。チャンネルに依存しない部分だけを持つ。
2026-10-10 に rekishi-chiso（歴史の地層）から切り出した。10/12〜13 の4本で聞いて分かる誤読が約50か所あったのがきっかけ。

```
pip install -e libs/yomi        # fugashi・unidic-lite・PyYAML も入る
```

## 何をするか（4つ）

| | 中身 | 関数 |
|---|---|---|
| ① | 文を fugashi（UniDic）でも読み、エンジンのカナと語ごとに突き合わせて、食い違う語を出す。長音・助詞の「は／わ」「へ／え」・数字・連濁は同じとみなす | `diff_line(文, カナ)` |
| ② | 読みが割れる語（家・方・表・上・下…）を1語で使った所の一覧。文脈で読みが決まる型（名字＋家＝ケ・数字＋石＝コク・名前＋の方＝カタ・表＋の/に/と＝オモテ）に当たり、エンジンがその読みでなければ止める | `ambiguous_hits` / `rule_of` |
| ③ | 読み替え辞書のキーが、もっと長い語の一部に当たって読みが変わるもの（「露: つゆ」が「披露」に） | `collisions` |
| ⑤ | 見つけた誤読を「この文はこう読む」としてテストに残す道具 | `Case` / `check` / `check_kana` |

まとめて回すのは `review(items, readings, kana, lexicon, strip)`。`Report.lines()` が（止めるもの, 知らせるもの）の文を返す。

```python
import yomi
lex = yomi.Lexicon.load("yomi.yaml")                          # 共通の一覧＋チャンネルの一覧
src = yomi.VoicevoxKana("http://127.0.0.1:50021", speaker=13, cache="work/kana_cache.json")
items = [("1行目", "約12万石の大名でした。"), ...]               # (見出し, 文)
rep = yomi.review(items, readings, src.kana if src.available else None, lex, strip=lambda t: t.replace("《", "").replace("》", ""))
src.save()
errors, warns = rep.lines()                                   # 「読み：…」
```

- 入力は「文（読み替え辞書で置き換える前）と読み替え辞書（dict）」と「置き換えたあとの文 → エンジンのカナ」の関数。
  カナは VOICEVOX の audio_query の形（「／」区切りでもよい）。ほかのエンジンでも、カナを返す関数を渡せば使える
- エンジンが無いとき（CI）は ① を飛ばし、② の型に当たった所は確かめられないので止める
- fugashi が無ければ何もしない（`Report.lines()` が1行で知らせる）

## 分かっている穴（拾えない型）

- **両方の辞書が同じ間違いをした所**は ① で拾えない（UniDic も「織田家＝オダカ」「表＝ヒョウ」「方＝ホウ」「床＝ユカ」と読む）。
  型（②）にできるものは型に、できないものは一覧（②）に出して人が耳で確かめる
- **数字と数え方**は同じとみなすので、「1尺＝ヒトシャク」のような数字まわりの誤読は拾えない
- **区切り（アクセント句）の崩れ**（「勝家」が「〜とか／ついえ」に切れる）は読みのカナが合っているので拾えない
- **抑揚・高さ**は見ない。カナだけ
- 人名・地名は両方の辞書が外しやすいので、食い違いは別の1行にまとめて出す（人が確かめる）

## チャンネル側で持つもの

| もの | 例（rekishi-chiso） |
|---|---|
| 読み替え辞書（画面の文字 → 読む文字） | `readings.yaml` |
| チャンネルだけの一覧（`ambiguous`・`rules`・`alike`。形は `src/yomi/data/base.yaml` と同じ） | `yomi.yaml`（斉・都・明、都＋助詞の型、歴史の語） |
| 台本から (見出し, 文) を並べる所・読まない印を外す関数 | `chiso/reading.py` の `items`・`strip` |
| check から呼んで知らせを並べる所 | `chiso/cli.py` の `preflight` |
| 見つけた誤読のテスト（`Case` の並び） | `tests/test_reading.py` の `MISREADS` |
| 読みの確認の関門（下） | `chiso/cli.py` の `reading-ok` と `approve` |

一覧を足すときは、そのチャンネルの過去の台本に全部流して、正しく読めている所で止めないことを確かめる
（rekishi-chiso は `tests/test_reading.py` の `RULE_HITS` に、型に当たる所を OK／NG で並べている）。

## 関門の作り方（ほかのチャンネルが真似する形）

人が全行のカナを確かめたことを、ファイルに残して次の工程の前で確かめる。rekishi-chiso の作り：

1. `kana 台本` で全行のカナを出し、check の「読み：」を片づける（× は読み替え辞書に足して消す）
2. 全行を目で確かめたら `reading-ok 台本`：`approvals/<台本>.reading.json` に
   `{"script", "sha256": 台本のハッシュ, "readings_sha256": 読み替え辞書のハッシュ（改行は LF にそろえる）}` を書く
3. 次の工程（台本の承認 `approve`）は、この控えが無いか、どちらかのハッシュが合わないと止まる
   - 台本を変えたら確かめ直し。読み替え辞書を変えたら全台本の控えが外れる（それでよい。辞書の変更は他の回の読みも変える）
   - 予約・公開済みの回（作り直さない回）は対象外にする（rekishi-chiso は posted.json に `<台本>:main` がある回）
4. テストで、控えが無い・台本が変わった・辞書が変わったときに止まることを確かめる

手順の全体はユーザーレベルのスキル `voice-reading-check` にある。

## テスト

```
cd libs/yomi && PYTHONIOENCODING=utf-8 python -m pytest
```

CI は `.github/workflows/yomi-lib-tests.yml`。VOICEVOX が要るテスト（`@pytest.mark.voicevox`）は繋がらなければ飛ぶ。
