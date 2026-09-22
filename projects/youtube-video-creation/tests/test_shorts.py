import pytest

from src.config import load_config
from src.script_model import parse_script
from src.shorts import (MAX_SECONDS, SHORT_SUBSCRIBE, SHORT_SUBSCRIBE_2, SIZE, ShortError, _estimate,
                        portrait, trim)

BODY = (
    "---\ntitle: T\n---\n\n"
    "## オープニング\n\nキャスター: つかみです。\n\n"
    "## 何が起きたか\n\nキャスター: いち。\n解説: に。\n解説: さん。\n\n"
    "## 数字で見ると\n\nキャスター: すうじ。\n\n"
    "## まとめ\n\nキャスター: まとめ。\n"
)


def test_portrait_flips_the_frame_and_shrinks_the_text():
    wide = load_config()
    tall = portrait(wide)
    assert (tall.video.width, tall.video.height) == SIZE
    assert tall.video.telop_size < wide.video.telop_size
    assert wide.video.width == 1920      # 元の設定は変えない


def test_the_default_cut_is_the_opening_plus_the_next_section():
    short = trim(parse_script(BODY))
    assert [scene.title for scene in short.scenes] == ["オープニング", "何が起きたか"]


def test_a_named_section_can_be_used_instead():
    short = trim(parse_script(BODY), "数字で見ると")
    assert [scene.title for scene in short.scenes] == ["オープニング", "数字で見ると"]


def test_an_unknown_section_lists_the_choices():
    with pytest.raises(ShortError, match="数字で見ると"):
        trim(parse_script(BODY), "存在しない節")


def test_the_original_script_is_left_alone():
    script = parse_script(BODY)
    trim(script)
    assert len(script.scenes) == 4       # 元の台本は削らない


def test_lines_are_dropped_from_the_back_until_it_fits():
    script = parse_script(BODY)
    short = trim(script, "何が起きたか", max_seconds=1.0)
    # 冒頭は削らず、掘る節から後ろを落とす
    assert len(short.scenes[0].lines) == 1
    # **末尾に締めが2行増える**（2026-09-18 に1行から増やした。
    # ユーザー指示「ショートの最後に本編はチャンネルから見て下さい的な感じを」）。
    # 中身の行は1つのまま
    assert len(short.scenes[1].lines) == 3
    assert short.scenes[1].lines[-2].text == SHORT_SUBSCRIBE
    assert short.scenes[1].lines[-1].text == SHORT_SUBSCRIBE_2
    assert short.scenes[1].lines[0].text == "いち。"


def test_a_one_scene_script_is_refused():
    with pytest.raises(ShortError, match="節が1つ"):
        trim(parse_script("---\ntitle: T\n---\n\n## だけ\n\nキャスター: あ。\n"))


def test_the_estimate_uses_the_pre_build_guess():
    short = trim(parse_script(BODY))
    assert _estimate(short) > 0          # ビルド前でも尺が出る
    assert _estimate(short) < MAX_SECONDS

# **いちばん強い場面を使う**（2026-09-06 ユーザーの指示）。
# 11本を振り返ると、残ったのは全部「誰かの言葉」だった。

def _built(sections):
    """sections は [(見出し, [(話者, カード名)])]。"""
    from src.script_model import parse_script

    nl = chr(10)
    head = ["---", "title: T", "cards:",
            "  q:", "    type: quote", "    source: X", "    text: hello",
            "  n:", "    type: bars", "    title: 数字", "    items: []",
            "---", ""]
    body = ["## オープニング", "", "キャスター: つかみ。", ""]
    for title, lines in sections:
        body += [f"## {title}", ""]
        for who, card in lines:
            body.append(f"{who}: {title}の話。")
            if card:
                body.append(f"  card: {card}")
        body.append("")
    return parse_script(nl.join(head + body))


def test_誰かの言葉がある節を選ぶ():
    """**事実の説明より、本人の口から出た一言が強い。**"""
    from src.shorts import _pick

    script = _built([
        ("何が起きたか", [("キャスター", None), ("キャスター", None)]),
        ("監督は何と言ったか", [("キャスター", None), ("アルテタ", "q")]),
        ("これからどうなる", [("キャスター", None)]),
    ])
    assert _pick(script, "").title == "監督は何と言ったか"


def test_数字のカードは次点で効く():
    from src.shorts import _pick

    script = _built([
        ("何が起きたか", [("キャスター", None)]),
        ("数字で見ると", [("キャスター", "n"), ("キャスター", None)]),
    ])
    assert _pick(script, "").title == "数字で見ると"


def test_まとめは選ばない():
    """**答えを先に言ってしまう。**ショートは本編への入口にする。"""
    from src.shorts import _pick

    script = _built([
        ("何が起きたか", [("キャスター", None)]),
        ("まとめ", [("解説", "q"), ("解説", "q")]),
    ])
    assert _pick(script, "").title == "何が起きたか"


def test_節を名前で指定できる():
    from src.shorts import _pick

    script = _built([
        ("何が起きたか", [("キャスター", None)]),
        ("監督は何と言ったか", [("アルテタ", "q")]),
    ])
    assert _pick(script, "何が起きたか").title == "何が起きたか"


def test_知らない節は弾く():
    from src.shorts import ShortError, _pick

    script = _built([("何が起きたか", [("キャスター", None)])])
    try:
        _pick(script, "存在しない節")
    except ShortError as err:
        assert "ありません" in str(err)
    else:
        raise AssertionError("知らない節を通した")

def test_顔が遅いと知らせる():
    """**ショートは数秒で見るか決められる。**実測で平均12秒目・全体の2割だった。"""
    from src.script_model import parse_script
    from src.shorts import face_problems

    nl = chr(10)
    late = parse_script(nl.join(
        ["## 章", "", "キャスター: いちぎょうめ。ながいながいながい文章です。",
         "キャスター: にぎょうめ。ながいながいながい文章です。",
         "キャスター: さんぎょうめ。", "  image: assets/images/x/01.jpg", ""]))
    problems = face_problems(late)
    assert any("秒目です" in x for x in problems), problems

    early = parse_script(nl.join(
        ["## 章", "", "キャスター: いちぎょうめ。",
         "  image: assets/images/x/01.jpg",
         "キャスター: にぎょうめ。", "キャスター: さんぎょうめ。", ""]))
    # render は指定した行以降そのまま残すので、先頭に置けば通しで出る
    for line in early.lines[1:]:
        line.image = "assets/images/x/01.jpg"
    assert face_problems(early) == []


def test_顔が無ければ知らせる():
    from src.script_model import parse_script
    from src.shorts import face_problems

    nl = chr(10)
    script = parse_script(nl.join(["## 章", "", "キャスター: あ。", ""]))
    assert face_problems(script) == ["顔が1枚も出ていません"]

def test_見積りの甘さを見込んで手前で切る():
    """**見積りは実尺より短く出る。**実測（2026-09-07）で56秒→66秒。

    そのまま上限まで詰めると、書き出したとき60秒を超えて
    ショートとして扱われなくなる。
    """
    from src.shorts import ESTIMATE_SLACK, MAX_SECONDS, _estimate, _fit
    from src.script_model import parse_script

    nl = chr(10)
    long = ["## オープニング", "", "キャスター: つかみ。", "", "## 本編", ""]
    long += [f"キャスター: {i}ぎょうめ。" + "あ" * 60 for i in range(12)]
    script = parse_script(nl.join(long))
    _fit(script, MAX_SECONDS)
    assert _estimate(script) <= MAX_SECONDS * ESTIMATE_SLACK
    assert ESTIMATE_SLACK < 1.0, "見積りをそのまま信じない"


def test_冒頭は削らない():
    from src.shorts import MAX_SECONDS, _fit
    from src.script_model import parse_script

    nl = chr(10)
    body = ["## オープニング", "", "キャスター: つかみ。" + "あ" * 200, "", "## 本編", ""]
    body += [f"キャスター: {i}。" + "あ" * 200 for i in range(8)]
    script = parse_script(nl.join(body))
    _fit(script, MAX_SECONDS)
    assert len(script.scenes[0].lines) == 1, "冒頭が消えている"
    assert len(script.scenes[-1].lines) >= 1, "本編が空になった"


def test_ショートは話速を1割上げる():
    """参考は反応1件3秒台（2026-09-08）。本編の設定は変えず、縦型だけ速くする。"""
    from src.config import load_config
    from src import shorts

    config = load_config()
    portrait = shorts.portrait(config)
    for key, member in config.cast.items():
        assert portrait.cast[key].speed == round(member.speed * shorts.SHORT_SPEED, 3)
    # 元の設定は触らない
    assert all(m.speed <= 1.1 for m in config.cast.values())


def test_ショートの冒頭はタイトルの1行だけ():
    """視聴維持の曲線（2026-09-09 実測）で、捨てられるのは4〜9秒だった。

    4秒で100% → 8秒で39.7%。タイトルを読むところまでは残り、そのあとの
    「今回の問いは〜」で半分以上が消える。読み上げから落とす。
    """
    from src import shorts
    from src.script_model import parse_script

    nl = chr(10)
    script = parse_script(nl.join([
        "---", "title: T", "---", "",
        "## オープニング", "",
        "キャスター: タイトルをそのまま読みます。", "  telop: T",
        "キャスター: 今回の問いは、なぜそうなったのかです。", "  telop: 今回の問い: なぜ",
        "", "## 本編", "",
        "ネット民: 完全に別チームだった。", "ネット民: 中盤の圧力がすごい。", ""]))
    for line in script.lines:
        line.duration, line.pause = 2.0, 0.3
    short = shorts.trim(script)
    opening = short.scenes[0]
    assert len(opening.lines) == 1
    assert "タイトルをそのまま読みます" in opening.lines[0].text
    assert not any("今回の問い" in (l.text or "") for l in short.lines)
    # 元の台本は触らない（本編は今までどおり）
    assert len(script.scenes[0].lines) == 2


def test_ショートは本編と別のタイトルになる():
    """昨夜の12本は本編とショートが同じ題名で並んでいた（2026-09-09）。"""
    from src import shorts
    from src.script_model import parse_script

    nl = chr(10)
    base = [
        "---", "title: 久保建英に起きたことがこちらです", "---", "",
        "## オープニング", "", "キャスター: タイトルを読みます。", "  telop: T",
        "", "## 本編", "",
        "ネット民: 完全に別チームだった。", "  telop: パス成功率95%を出したのは誰か",
        "ネット民: 中盤の圧力がすごい。", ""]
    script = parse_script(nl.join(base))
    for line in script.lines:
        line.duration, line.pause = 2.0, 0.3
    short = shorts.trim(script)
    assert short.title != script.title
    assert short.title == "パス成功率95%を出したのは誰か"

    # 台本が short_title を持っていればそれが勝つ
    named = parse_script(nl.join(base[:2] + ["short_title: 95%という数字の意味"] + base[2:]))
    for line in named.lines:
        line.duration, line.pause = 2.0, 0.3
    assert shorts.trim(named).title == "95%という数字の意味"


def _scene(title, voices=0, narrator_lines=1, text=""):
    from src.script_model import Line, Scene

    lines = [Line(speaker="キャスター", text=text or "説明の行です。")
             for _ in range(narrator_lines)]
    lines += [Line(speaker="監督", text=f"発言{i}") for i in range(voices)]
    return Scene(title=title, lines=lines)


def test_代弁だけで勝たせない():
    """**発言の多い節が必ず勝っていた**（2026-09-10 ユーザー指摘）。

    1行3点で上限が無かったので、発言が10行ある「試合の前に何を言っていたか」が
    27点で選ばれ、タイトルが「5試合で4点目の決勝弾」なのに
    **決勝弾が1秒も入っていなかった**。PSG回も6得点が入っていなかった。
    """
    from src.shorts import VOICE_CAP, strength

    many = _scene("試合の前に何を言っていたか", voices=10)
    assert strength(many, {}) <= VOICE_CAP, "上限が効いていない"


def test_試合の前の話は下げる():
    """結果が出たあとに配るのに、中身が前日の話では古い。"""
    from src.shorts import strength

    before = _scene("試合の前に何を言っていたか", voices=4)
    after = _scene("何が起きたか", voices=4)
    assert strength(before, {}) < strength(after, {})


def test_本題の印がいちばん強い():
    """**書いた人が「ここが山場」と印を付けている。**

    取材メモの決まりで、答えを出す節は「ここからが本題です」で始まる。
    機械の点より、その印を採る。
    """
    from src.shorts import strength

    marked = _scene("数字がおかしい", voices=0,
                    text="ここからが本題です。50得点に届いたのは49試合目でした。")
    talky = _scene("同僚はどう見ているか", voices=4)
    assert strength(marked, {}) > strength(talky, {})


def test_ショートでは本題の印を読み上げない():
    """**ショートには「前」が無い**（2026-09-10）。

    本編では前の節と対比させる言葉だが、いきなり「ここからが本題です」で
    始まると、何かを見落としたように聞こえる。読み上げの文だけ削る。
    """
    from src.script_model import Line, Scene
    from src.shorts import _drop_main_mark

    scene = Scene(title="x", lines=[
        Line(speaker="解説", text="ここからが本題です。監督が世代交代を進めようとしていました。"),
        Line(speaker="解説", text="ここからが本題です。2行目は触らない。"),
    ])
    _drop_main_mark(scene)
    assert scene.lines[0].text == "監督が世代交代を進めようとしていました。"
    assert scene.lines[1].text.startswith("ここからが本題です")   # 1行目だけ

    # 印が無ければ何もしない
    plain = Scene(title="x", lines=[Line(speaker="解説", text="ふつうの行です。")])
    _drop_main_mark(plain)
    assert plain.lines[0].text == "ふつうの行です。"


def test_締めの一言を残して手前から落とす():
    """**いちばん強い一言がいつも先に消えていた**（2026-09-10）。

    ブラジル代表の回で実際に起きた。チアゴ・シウヴァの発言は
    年齢の話 → 進め方の話 → 「賛成しない」と積み上がっているのに、
    尺に収める処理が後ろから1行ずつ削るので、締めの「賛成しない」が落ち、
    途中の一言で終わっていた。**視聴者が最後に聞くのは締めであるべき。**
    """
    from src.script_model import parse_script
    from src.shorts import _fit

    nl = chr(10)
    body = ["## オープニング", "", "キャスター: つかみ。", "", "## 本編", ""]
    body += ["解説: まず状況です。" + "あ" * 40, ""]
    body += ["チアゴ: 年齢の話です。" + "あ" * 40, ""]
    body += ["解説: そして進め方に踏み込みます。" + "あ" * 40, ""]
    body += ["チアゴ: 途中の話です。" + "あ" * 40, ""]
    body += ["解説: 最後にはっきり否定しました。", ""]
    body += ["チアゴ: 賛成しない", ""]
    script = parse_script(nl.join(body))
    _fit(script, 20.0)
    texts = [line.text for line in script.scenes[-1].lines]
    # ここは `_fit` を直接呼ぶので、登録の一言（trim が足す）は入らない
    assert texts[-1] == "賛成しない", texts
    assert texts[-2] == "最後にはっきり否定しました。", texts


def test_振りだけを残さない():
    """代弁を落としたあとに「こう話しています。」だけが残らない（2026-09-10）。

    鎌田の回で、締めが**振りの語り**で終わっていた。
    """
    from src.script_model import parse_script
    from src.shorts import _fit

    nl = chr(10)
    body = ["## オープニング", "", "キャスター: つかみ。", "", "## 本編", ""]
    body += ["解説: まず状況です。" + "あ" * 40, ""]
    body += ["ラーセン: 最初の発言です。" + "あ" * 40, ""]
    body += ["解説: 本人についてもこう話しています。" + "あ" * 40, ""]
    body += ["ラーセン: 途中の発言です。" + "あ" * 40, ""]
    body += ["解説: 最後にこう続けました。", ""]
    body += ["ラーセン: 締めの発言です。", ""]
    script = parse_script(nl.join(body))
    _fit(script, 22.0)
    texts = [line.text for line in script.scenes[-1].lines]
    assert texts[-1] == "締めの発言です。", texts
    # 代弁を落とした「本人についてもこう話しています。」は残さない
    assert not any(text.startswith("本人についても") for text in texts), texts


def test_締めに代弁が無ければ今までどおり後ろから落とす():
    """語りだけの節では、真ん中を抜くと文が飛ぶ。守る値打ちも無い。"""
    from src.script_model import parse_script
    from src.shorts import _fit

    nl = chr(10)
    body = ["## オープニング", "", "キャスター: つかみ。", "", "## 本編", ""]
    body += [f"解説: {i}ぎょうめ。" + "あ" * 40 + nl for i in range(6)]
    script = parse_script(nl.join(body))
    _fit(script, 20.0)
    texts = [line.text for line in script.scenes[-1].lines]
    assert texts[0].startswith("0ぎょうめ"), texts


def test_振りの1行を落として発言を早く出す():
    """**発言までの秒数がそのまま維持に効く**（2026-09-10 の実測）。

    44本で、誰かの言葉が19秒までに出る9本は平均維持50.4%、
    遅い8本は33.7%だった。「こう話しました。」は次に発言が来ることを
    予告するだけで情報を持たないのに、2〜4秒かかる。
    """
    from src.script_model import parse_script
    from src.shorts import trim

    nl = chr(10)
    body = ["## オープニング", "", "キャスター: タイトルです。", "", "## 本編", ""]
    body += ["解説: 状況の説明です。", ""]
    body += ["解説: 異を唱えたのは、チアゴ・シウヴァです。", ""]
    body += ["解説: メンバー発表を前に、こう話しました。", ""]
    body += ["チアゴ: 賛成しない", ""]
    short = trim(parse_script(nl.join(body)))
    texts = [line.text for line in short.scenes[-1].lines]
    assert "メンバー発表を前に、こう話しました。" not in texts, texts
    # 話者を名乗る行は残す（ショート単体で分かるようにするため）
    assert "異を唱えたのは、チアゴ・シウヴァです。" in texts, texts
    # **末尾は締めの2行になる**（2026-09-18）。守りたいのはその手前
    assert texts[-2:] == [SHORT_SUBSCRIBE, SHORT_SUBSCRIBE_2]
    assert texts[-3] == "賛成しない"


def test_発言が遅ければ知らせる():
    """止めはしない。**書き方の問題なので、書き出したところで知らせる。**"""
    from src.script_model import parse_script
    from src.shorts import quote_problems, trim

    nl = chr(10)
    late = ["## オープニング", "", "キャスター: タイトルです。", "", "## 本編", ""]
    late += ["解説: 長い説明です。" + "あ" * 60, ""]
    late += ["解説: まだ説明が続きます。" + "あ" * 60, ""]
    late += ["チアゴ: 賛成しない", ""]
    problems = quote_problems(trim(parse_script(nl.join(late))))
    assert problems and "最初の発言" in problems[0], problems

    # 語りだけの節は、そもそも言葉が無いと知らせる
    only = ["## オープニング", "", "キャスター: タイトルです。", "", "## 本編", ""]
    only += ["解説: 説明だけです。", ""]
    only += ["解説: もう1行。", ""]
    problems = quote_problems(trim(parse_script(nl.join(only))))
    assert problems and "1つも" in problems[0], problems

    # 早ければ何も言わない
    fast = ["## オープニング", "", "キャスター: タイトル。", "", "## 本編", ""]
    fast += ["解説: 短い説明。", ""]
    fast += ["チアゴ: 賛成しない", ""]
    assert quote_problems(trim(parse_script(nl.join(fast)))) == []


def test_落とすのは振りだけで語りはまとめて消さない():
    """**尺に収まっていても削っていた**（2026-09-10 に書き出して発見）。

    マック・アリスターの回で、決勝点の描写がまとめて消えてショートが27秒に
    なっていた。振り（「こう話しました。」）を落とす処理が、
    その手前の語りまで連続して消していたため。
    """
    from src.script_model import parse_script
    from src.shorts import _fit

    nl = chr(10)
    body = ["## オープニング", "", "キャスター: タイトルです。", "", "## 本編", ""]
    body += ["解説: まず状況です。" + "あ" * 30, ""]
    body += ["解説: 17分に先制されました。" + "あ" * 30, ""]
    body += ["解説: 決勝点はボックス手前からでした。" + "あ" * 30, ""]
    body += ["解説: ゴールについては、こう話しました。", ""]
    body += ["本人: 良いシュートだった", ""]
    script = parse_script(nl.join(body))
    _fit(script, 58.0)
    texts = [line.text for line in script.scenes[-1].lines]
    assert any("決勝点は" in text for text in texts), texts
    assert any("17分に" in text for text in texts), texts


def test_山場の印は指定で付ける():
    """**「ここからが本題です」は読み上げから外した**（2026-09-10 ユーザー指示
    「台本のここからが本題ですはいらない」）。

    印は `@main: true`。聞く人には要らない言葉だが、
    ショートがどの節を切り出すかを決めるのには要る。
    """
    from src.script_model import parse_script
    from src.shorts import MAIN_BONUS, strength, trim

    nl = chr(10)
    body = ["## オープニング", "", "キャスター: タイトルです。", ""]
    body += ["## ふつうの節", "", "解説: ここは前置きです。", "", "本人: ひとこと", ""]
    body += ["## 答えの節", "@main: true", "", "解説: ここが答えです。", "", "本人: ふたこと", ""]
    script = parse_script(nl.join(body))
    plain, marked = script.scenes[1], script.scenes[2]
    assert marked.main is True and plain.main is False
    assert strength(marked, {}) - strength(plain, {}) == MAIN_BONUS

    # 印の付いた節がショートに選ばれる
    short = trim(script)
    assert short.scenes[-1].title == "答えの節"

    # 読み上げに「ここからが本題です」は残っていない
    assert "ここからが本題" not in " ".join(line.text for line in script.lines)


def test_古い台本の文字の印も当分は見る():
    """2026-09-10 より前に書いた台本は、セリフに印が入っている。"""
    from src.script_model import parse_script
    from src.shorts import MAIN_BONUS, strength

    nl = chr(10)
    body = ["## オープニング", "", "キャスター: タイトル。", ""]
    body += ["## 古い節", "", "解説: ここからが本題です。答えはこれです。", "", "本人: ひとこと", ""]
    body += ["## ふつうの節", "", "解説: 前置きです。", "", "本人: ひとこと", ""]
    script = parse_script(nl.join(body))
    old, plain = script.scenes[1], script.scenes[2]
    assert strength(old, {}) - strength(plain, {}) == MAIN_BONUS


def test_中身のある行は振りとして落とさない():
    """**「こう振り返っています。」で終わる長い行を丸ごと消していた**（2026-09-11）。

    中村敬斗の回で「17歳で日本を離れ、LASKリンツからランスへ移りました。
    そのときに感じたことを、こう振り返っています。」が消え、ショートが
    いきなり発言から始まっていた。落とすのは**短い振りだけ**。
    """
    from src.script_model import Line
    from src.shorts import LEAD_IN_MAX, _is_lead_in

    short = Line(speaker="解説", text="こう話しました。")
    assert _is_lead_in(short)

    long = Line(speaker="解説",
                text="17歳で日本を離れ、LASKリンツからランスへ移りました。"
                     "そのときに感じたことを、こう振り返っています。")
    assert len(long.text) > LEAD_IN_MAX
    assert not _is_lead_in(long)


def test_marked_section_wins_over_score():
    """@main の印がある節を必ず使う（2026-09-13）。

    反応を7行並べた節が点で勝ち、ショートが試合の話をせず
    ネットの声だけになっていた。印は書いた人の合図なので優先する。
    """
    from src.script_model import Line, Scene, Script
    from src.shorts import _pick

    opening = Scene(title="オープニング", lines=[Line(speaker="キャスター", text="題名")])
    story = Scene(title="山場", main=True,
                  lines=[Line(speaker="解説", text="ここが芯です")])
    voices = Scene(title="見ていた人が書いていたこと",
                   lines=[Line(speaker="ネット民", text="すごい") for _ in range(7)])
    script = Script(title="見出し", scenes=[opening, voices, story])
    assert _pick(script, "").title == "山場"


def test_short_gets_a_few_voices_at_the_end():
    """ショートの最後にもネットの声を少しだけ足す（2026-09-13 ユーザー指示）。

    本編では反応を最後の節にまとめる決まりなので、山場の節を切り出す
    ショートには1件も乗らなくなっていた。
    """
    from src.script_model import Line, Scene, Script
    from src.shorts import trim

    opening = Scene(title="オープニング", lines=[Line(speaker="キャスター", text="題名です")])
    story = Scene(title="山場", main=True,
                  lines=[Line(speaker="解説", text="ここが芯です")])
    voices = Scene(title="見ていた人が書いていたこと",
                   lines=[Line(speaker="ネット民", text=f"声{i}") for i in range(5)])
    short = trim(Script(title="見出し", scenes=[opening, story, voices]))
    said = [l.speaker for l in short.scenes[-1].lines]
    assert "ネット民" in said
    # **上限は 3 → 6**（2026-09-16「ショートが不必要に短くなってる」）。
    # 実尺で収める `enforce_limit` が入ったので、入るだけ足してよい
    from src.shorts import VOICES_TAIL_MAX

    assert said.count("ネット民") <= VOICES_TAIL_MAX
    assert said[0] == "解説"        # 反応は最後に足す


def test_語りが2つ続いたら前のほうは振りとして落とす():
    """**「こう」を含まない振りが残っていた**（2026-09-15 遠藤の回）。

    「もうひとつ、理由を挙げています。」→（発言）→「そのうえで、こう
    続けました。」の**真ん中だけが尺で落ち、振りが2つ並んだ**。
    `LEAD_IN` は「こう」を含む形しか見ないので素通りするが、
    **語りのあいだに発言が無い**ことは形で分かる。
    """
    from src.script_model import parse_script
    from src.shorts import _fit

    nl = chr(10)
    body = ["## オープニング", "", "キャスター: つかみ。", "", "## 本編", ""]
    body += ["解説: まず状況です。" + "あ" * 40, ""]
    body += ["イラオラ: 最初の発言です。" + "あ" * 40, ""]
    body += ["解説: もうひとつ、理由を挙げています。", ""]
    body += ["イラオラ: 途中の発言です。" + "あ" * 40, ""]
    body += ["解説: そのうえで、こう続けました。", ""]
    body += ["イラオラ: 締めの発言です。", ""]
    script = parse_script(nl.join(body))
    _fit(script, 22.0)
    texts = [line.text for line in script.scenes[-1].lines]
    assert texts[-1] == "締めの発言です。", texts
    assert not any(t.startswith("もうひとつ") for t in texts), texts


def test_もともと語りが続く回は触らない():
    """尺に収まっているなら、語りの連続はそのまま。"""
    from src.script_model import parse_script
    from src.shorts import _fit

    nl = chr(10)
    body = ["## オープニング", "", "キャスター: つかみ。", "", "## 本編", ""]
    body += ["解説: ひとつめの語り。", ""]
    body += ["解説: ふたつめの語り。", ""]
    body += ["イラオラ: 締めの発言です。", ""]
    script = parse_script(nl.join(body))
    _fit(script, 60.0)
    texts = [line.text for line in script.scenes[-1].lines]
    assert texts == ["ひとつめの語り。", "ふたつめの語り。", "締めの発言です。"], texts


def _voices_body(reactions):
    """冒頭＋山場＋反応の節、という本編の形。"""
    nl = chr(10)
    body = ["## オープニング", "", "キャスター: つかみ。", "", "## 本編", ""]
    body += ["解説: 語りです。" + "あ" * 30, ""]
    body += ["監督: 締めの発言です。", "", "## 見ていた人が書いていたこと", ""]
    for text, pick in reactions:
        body += [f"ネット民: {text}", ""]
        if pick:
            body[-1] = "  short_voice: true"
            body += [""]
    return nl.join(body)


def test_印を付けた反応を先に締めに使う():
    """**どの反応で締めるかは、書いた人が選べる**（2026-09-15 指示）。

    上から順に取っていたので、松木の回は1件目が
    「松木玖生が今季公式戦初ゴール…平河悠との日本人対決を制す」で、
    **タイトルとほぼ同じ**だった。

    **2026-09-20 に、印のあとは残りで埋める形にした**
    （「ショートの内容が薄い、ちゃんと時間使って」）。
    見るのは**印の付いたものが先に来るか**で、残りが入ること自体は正しい。
    """
    from src.script_model import parse_script
    from src.shorts import trim

    script = parse_script(_voices_body([
        ("見出しの言い直しみたいな1件目。", False),
        ("これを締めに使ってほしい。", True),
    ]))
    got = [line.text for line in trim(script, "本編").scenes[-1].lines]
    assert "これを締めに使ってほしい。" in got, got
    if "見出しの言い直しみたいな1件目。" in got:
        assert got.index("これを締めに使ってほしい。") < got.index("見出しの言い直しみたいな1件目。"), got


def test_印が無ければ今までどおり上から取る():
    from src.script_model import parse_script
    from src.shorts import trim

    script = parse_script(_voices_body([
        ("1件目です。", False),
        ("2件目です。", False),
    ]))
    got = [line.text for line in trim(script, "本編").scenes[-1].lines]
    assert "1件目です。" in got, got


def test_印を付けた反応のぶんは先に空ける():
    """**尺が余っているぶんしか足していなかった**（2026-09-15）。

    松木の回で、印を付けた2件目が0.6秒はみ出して落ちていた。
    印は書いた人の指定なので、語りのほうを詰めて場所を作る。
    """
    from src.script_model import parse_script
    from src.shorts import trim

    nl = chr(10)
    body = ["## オープニング", "", "キャスター: つかみ。", "", "## 本編", ""]
    for i in range(6):
        body += [f"解説: 語り{i}です。" + "あ" * 34, ""]
    body += ["## 見ていた人が書いていたこと", ""]
    body += ["ネット民: 選んだ1件目です。" + "あ" * 12, "  short_voice: true", ""]
    body += ["ネット民: 選んだ2件目です。" + "あ" * 12, "  short_voice: true", ""]
    script = parse_script(nl.join(body))
    got = [line.text for line in trim(script, "本編").scenes[-1].lines]
    picked = [t for t in got if t.startswith("選んだ")]
    assert len(picked) == 2, got


def test_発言より先に語りを削る():
    """**監督の3つの発言のうち真ん中が落ちていた**（2026-09-15 指摘）。

    手前から1行ずつ削っていたので、語りではなく発言が消えた。
    CLAUDE.md は「短くするために発言を削るのは本末転倒」と書いている。
    """
    from src.script_model import parse_script
    from src.shorts import _fit

    nl = chr(10)
    body = ["## オープニング", "", "キャスター: つかみ。", "", "## 本編", ""]
    body += ["解説: まず状況です。" + "あ" * 40, ""]
    # **振りは短い。**あ30字を足して44字の行にしていたが、そんな語りは書かない。
    # 長い行は「見出し」として守られる（2026-09-18）ので、本来の長さに戻した
    body += ["解説: 監督が口を開きました。", ""]
    body += ["イラオラ: ひとつめの発言です。" + "あ" * 30, ""]
    body += ["イラオラ: ふたつめの発言です。" + "あ" * 30, ""]
    body += ["解説: そのうえで、こう続けました。", ""]
    body += ["イラオラ: みっつめの発言です。", ""]
    script = parse_script(nl.join(body))
    # **上限は ESTIMATE_SLACK を掛けてから使う。**0.86 → 0.92 にした
    # （2026-09-16「ショートが不必要に短くなってる」）ので、削りが起きる
    # ところまで上限を下げて、削る順番そのものを見る
    _fit(script, 31.0)
    texts = [line.text for line in script.scenes[-1].lines]
    said = [t for t in texts if t.startswith(("ひとつめ", "ふたつめ", "みっつめ"))]
    assert len(said) == 3, texts
    # 削られたのは語りのほう
    assert not any(t.startswith("監督が口を開") for t in texts), texts


def test_TikTok用は1分を超えるまで台本の中身を足す():
    """**TikTok の報酬は1分以上の動画だけ**（2026-09-16）。ショートの58秒では数えられない。"""
    from src import shorts
    from src.script_model import Line, Scene, Script

    def talk(text, sec, speaker="キャスター"):
        line = Line(speaker=speaker, text=text)
        line.duration = sec
        return line

    script = Script(title="t", scenes=[
        Scene(title="オープニング", lines=[talk("題名です", 4.0)]),
        Scene(title="何があったか", lines=[talk(f"事実{i}", 5.0) for i in range(4)]),
        Scene(title="山場", lines=[talk(f"山場{i}", 5.0) for i in range(5)]),
        Scene(title="見ていた人", lines=[talk(f"反応{i}", 3.0, "ネット民") for i in range(8)]),
    ])
    script.scenes[2].main = True
    cut = shorts.tiktok_cut(script)
    assert shorts._estimate(cut) >= shorts.TIKTOK_MIN_SECONDS / shorts.TIKTOK_ESTIMATE_RATIO
    # 足したのは台本にある行だけ
    texts = ({l.text for sc in script.scenes for l in sc.lines}
             | {shorts.SHORT_SUBSCRIBE, shorts.TIKTOK_OUTRO})
    assert all(l.text in texts for l in cut.lines)
    # **締めは YouTube へ送る一言**（2026-09-16）。TikTok は説明欄のリンクを
    # 押せないので、声で名前を言うしかない
    assert cut.lines[-1].text == shorts.TIKTOK_OUTRO


def test_実尺で上限に収める(tmp_path):
    """**見積りの安全率では、短くなりすぎるか超えるかにしかならない**（2026-09-16）。

    直近5本の実測で 実尺／見積り は 0.923〜1.073 とばらついた。
    合成が終われば1行ずつの秒数が分かるので、そこで落とす。
    """
    from src.config import load_config
    from src.script_model import Line, Scene, Script
    from src.shorts import SHORT_SUBSCRIBE, enforce_limit

    def talk(text, sec, who="キャスター"):
        line = Line(speaker=who, text=text)
        line.duration = sec
        return line

    lines = [talk(f"語り{i}", 8.0) for i in range(6)]
    lines += [talk(f"反応{i}", 4.0, "ネット民") for i in range(3)]
    lines += [talk(SHORT_SUBSCRIBE, 2.0)]
    script = Script(title="t", scenes=[Scene(title="オープニング", lines=[talk("題", 4.0)]),
                                       Scene(title="本編", lines=lines)])
    config = load_config()

    dropped = enforce_limit(script, 58.0, config)
    assert dropped >= 1
    total = sum(l.duration for l in script.lines)
    assert total <= 58.0
    # **締めは残す。**落とすのは後ろ（＝ネットの声）から
    assert script.lines[-1].text == SHORT_SUBSCRIBE
    assert any(l.text.startswith("語り") for l in script.lines)


def test_状況説明の1行があってもネットの声は締めに足す():
    """**反応の節の頭にある `only: short` の語りを、語りとして数えない**
    （2026-09-17 にユーザー指摘「ショートの内容が薄い」から発見）。

    `_is_voices_scene` は「語りが1行でもあれば反応の節ではない」と見ていた。
    ところが取材メモの雛形は、反応の節の頭に**必ず**キャスターの状況説明を
    1行置く（「ショート単体で話が分かるように」2026-09-10 指示）。
    そのため**どの回でも False を返し**、9/17 のショート5本すべてに
    ネットの声が1件も入っていなかった。ユーザー指示は「声は必ず」。

    その1行はショート本体の側へ切り出されるので、ここで数える相手ではない。
    """
    from src.script_model import Line, Scene, Script
    from src.shorts import trim

    opening = Scene(title="オープニング", lines=[Line(speaker="キャスター", text="題名です")])
    story = Scene(title="山場", main=True,
                  lines=[Line(speaker="解説", text="ここが芯です")])
    voices = Scene(
        title="ネットの声",
        lines=[Line(speaker="キャスター", text="前提の説明です", only="short")]
        + [Line(speaker="ネット民", text=f"声{i}") for i in range(5)],
    )
    short = trim(Script(title="見出し", scenes=[opening, story, voices]))
    said = [l.speaker for l in short.scenes[-1].lines]
    assert "ネット民" in said, "状況説明の1行で、反応の節と見なされなくなっている"
    assert "前提の説明です" not in [l.text for l in short.scenes[-1].lines]


def test_2枚並びのサムネはショートで上下に割って両方出す(tmp_path, monkeypatch):
    """**ショートの冒頭が、サムネの1枚目しか出ていなかった**
    （2026-09-17 指示「ショートも横割りで本編のサムネと同じようにして」）。

    鈴木の回はサムネが「顔｜人影」の2枚並びなのに、ショートには顔しか出ず、
    答えを伏せた人影が消えていた。**同じ回に見えない。**
    """
    from PIL import Image

    from src import shorts as shorts_mod

    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(shorts_mod, "STACK_DIR", tmp_path / "_stack")
    for name, color in (("a.jpg", (200, 30, 30)), ("b.jpg", (30, 30, 200))):
        Image.new("RGB", (480, 660), color).save(tmp_path / name)

    made = shorts_mod.stacked_photo({"thumbnail_photos": ["a.jpg", "b.jpg"]})
    assert made, "2枚あるのに組めていない"
    with Image.open(made) as out:
        assert out.size == shorts_mod.SIZE
        assert out.getpixel((540, 480))[0] > 150      # 上は1枚目
        assert out.getpixel((540, 1440))[2] > 150     # 下は2枚目
    assert shorts_mod.stacked_photo({"thumbnail_photos": ["a.jpg"]}) == ""


def test_ショートが題名に答えていなければ知らせる():
    """**同じ日に2回やった**（2026-09-17）。

    鈴木彩艶の回は題名が「鈴木彩艶が後半から出た試合」なのに、ショートの中身は
    相手選手の経歴だけで、**鈴木の話が1行も入っていなかった**。日本代表の回も
    「名前が消えたのは誰だったか」と聞いて、誰なのかを一度も言わずに終わっていた。
    どちらもユーザーが見て気づいた。**山場の節に主語が出てこない台本は普通にある。**
    """
    from src.script_model import Line, Scene, Script
    from src.shorts import subject_problems, trim

    opening = Scene(title="オープニング", lines=[Line(speaker="キャスター", text="鈴木彩艶の話です")])
    story = Scene(title="山場", main=True,
                  lines=[Line(speaker="解説", text="相手の選手は2023年に来ました")])
    voices = Scene(title="ネットの声",
                   lines=[Line(speaker="ネット民", text=f"声{i}") for i in range(3)])
    script = Script(title="見出し", scenes=[opening, story, voices])
    script.meta = {"topic": "鈴木彩艶"}
    found = subject_problems(trim(script), script)
    assert found and "鈴木彩艶" in found[0]

    story.lines.append(Line(speaker="解説", text="鈴木彩艶は45分を無失点で守りました"))
    assert subject_problems(trim(script), script) == []


def test_ショートの締めで本編へ渡す():
    """**ショートから本編へ渡す道が無かった**（2026-09-18 ユーザー指示
    「ショートの最後に本編はチャンネルから見て下さい的な感じを入れたい。5秒くらいの枠で」）。

    それまでの締めは「チャンネル登録、お願いします。」の1行・2秒だけで、
    **本編があることも、どこで見られるかも言っていなかった。**
    本編の再生は86%が登録者から来ていて、ショートを見た人が本編へ回る経路は
    どこにも作られていない。
    """
    from src.shorts import SHORT_OUTRO, SHORT_OUTRO_LINES, SHORT_SUBSCRIBE

    assert SHORT_OUTRO == 5.0, "締めの枠が5秒でない"
    assert "本編" in SHORT_SUBSCRIBE, "本編があることを言っていない"
    assert "チャンネル" in SHORT_SUBSCRIBE, "どこで見られるかを言っていない"
    assert len(SHORT_OUTRO_LINES) == 2

    short = trim(parse_script(BODY), "何が起きたか")
    texts = [line.text for line in short.scenes[-1].lines]
    assert texts[-2:] == list(SHORT_OUTRO_LINES)


def test_締めが2行でもTikTokは行き先を差し替える():
    """TikTok は YouTube へ誘う（2026-09-16）。**2行まとめて置き換える。**"""
    from src.shorts import TIKTOK_OUTRO, _has_outro, tiktok_cut

    short = trim(parse_script(BODY), "何が起きたか")
    assert _has_outro(short.scenes[-1].lines)
    cut = tiktok_cut(short)
    texts = [line.text for line in cut.scenes[-1].lines]
    assert texts[-1] == TIKTOK_OUTRO
    assert not any("チャンネル登録もお願いします" in (x or "") for x in texts)


def test_題名に名前があればショート本文には求めない():
    """**2つの検査が両立しなくなっていた**（2026-09-18 に踏んだ）。

    `subject_problems` は「題材の名前をショート本文にも出せ」と言い、
    `_advise_short_repeats` は「ショート専用の行が題名と8字以上重なるな」と言う。
    題名に「マンチェスター・シティ」が入っている回では、
    **入れれば重複で叱られ、入れなければ主語なしで叱られる。**
    ショートの1行目は題名の読み上げなので、視聴者はそこで聞いている。
    """
    from src.script_model import Line, Scene, Script
    from src.shorts import subject_problems

    def make(lines, title):
        scenes = [Scene(title="本編", lines=[Line(speaker="キャスター", text=x) for x in lines])]
        s = Script(title=title, scenes=scenes)
        s.meta = {"topic": "マンチェスター・シティ"}
        return s

    full = make(["マンチェスター・シティの17歳が2発。監督が聞いたこと。",
                 "空いた9番に置かれたのが、中盤の17歳です。"],
                "マンチェスター・シティの17歳が2発。監督が聞いたこと")
    assert not subject_problems(full, full), "題名に名前があるのに求めている"

    # **略した呼び方でも通す**
    short_name = make(["何かが起きた日。",
                       "シティが10人を入れ替えた一戦でした。"], "何かが起きた日")
    assert not subject_problems(short_name, short_name), "「シティ」を認めていない"

    # 名前がどこにも無ければ、これまでどおり知らせる
    none = make(["何かが起きた日。", "そこで2点が入りました。"], "何かが起きた日")
    assert subject_problems(none, none)


def test_尺を詰めても締めの2行は両方残す():
    """**「本編はチャンネルから」が先に落ちていた**（2026-09-18 ユーザー指摘
    「ショートの最後がチャンネル登録お願いだけになってる」）。

    締めを1行から2行に増やしたのに、尺に収める処理は**1行ぶんしか守って
    いなかった**。後ろから落とすので、2行のうち**前の1行**が消える。
    残るのは「チャンネル登録もお願いします」だけで、
    **本編へ渡すという目的がまるごと失われる。**
    """
    from src.shorts import SHORT_OUTRO_LINES, trim

    for limit in (60.0, 30.0, 20.0, 12.0):
        short = trim(parse_script(BODY), "何が起きたか", max_seconds=limit)
        texts = [l.text for l in short.scenes[-1].lines]
        assert texts[-2:] == list(SHORT_OUTRO_LINES), (limit, texts)


def test_尺を詰めても見出しと発言は対で残る():
    """**見出しだけが抜けて、発言が宙に浮いていた**（2026-09-18 ユーザー指摘
    「ヴァツケのショートを改善して、ちゃんと3つ言う」）。

    9/15 に「発言に欠落がある」と言われて、尺を詰めるときは
    **語りから先に削る**ようにした。「語りは包み紙、発言が中身」という理屈は
    正しいが、**包み紙ではない語り**がある。「二つ目は、バログンの件です」は
    次の発言が**何の話か**を決めていて、これを抜くと発言が何の二つ目か
    分からないまま流れる。ヴァツケの回で「一つ目は」「二つ目は」「三つ目は」が
    **3つとも消えた。**

    落とすなら**対ごと**落とす。
    """
    from src.shorts import _is_narrator, trim

    lines = ["## オープニング", "", "キャスター: 三つの理由を挙げた。", "", "## 本編", ""]
    for name in ("一つ目", "二つ目", "三つ目"):
        lines += [f"キャスター: {name}は、これこれこういうことです。", ""]
        lines += [f"ヴァツケ: {name}についての発言です。とても長い発言をここに置きます。", ""]
    body = "\n".join(lines)

    for limit in (40.0, 28.0, 20.0):
        short = trim(parse_script(body), max_seconds=limit)
        kept = short.scenes[-1].lines
        for i, line in enumerate(kept):
            if _is_narrator(line) or "についての発言" not in (line.text or ""):
                continue
            before = kept[i - 1] if i else None
            assert before is not None and _is_narrator(before), (
                f"{limit}秒: 「{line.text}」の見出しが消えている")


def test_印のあとは残りの反応で上限まで埋める(tmp_path):
    """**ショートが短すぎた**（2026-09-20 指摘「ちゃんと時間使って」）。

    印（`short_voice`）の付いた反応だけで締めていたので、上限58秒に対して
    38〜52秒しか使っていなかった。印のあとは残りの反応で埋める。
    ただし**タイトルの言い直しになる反応は飛ばす**（2026-09-15 の指摘）。
    """
    from src.script_model import parse_script
    from src.shorts import trim

    lines = "\n".join(
        f"ネット民: これは{i}件目の書き込みで、そこそこの長さがあります。" for i in range(10))
    text = f"""# 鈴木彩艶が止めて、蹴って。ヴィラに初勝利をもたらしたのは
title: 鈴木彩艶が止めて、蹴って。ヴィラに初勝利をもたらしたのは

## 何が起きたか

キャスター: ヴィラがトッテナムに3対2で勝ちました。

## 前半に止めた3本
@main: true

キャスター: 前半のうちに3本を止めました。

## 見ていた人が書いていたこと

ネット民: 鈴木彩艶が止めて、蹴って。ヴィラに初勝利をもたらしたのは見事でした。
ネット民: あの時間帯に抑えたのが勝因だと思う。
  short_voice: true
{lines}
"""
    script = parse_script(text)
    short = trim(script)
    said = [l.text for l in short.scenes[-1].lines]
    assert "あの時間帯に抑えたのが勝因だと思う。" in said, "印の付いた反応が入っていない"
    assert sum(1 for t in said if "件目の書き込み" in t) >= 2, \
        f"残りの反応で埋めていない: {said}"
    assert not any("初勝利をもたらしたのは" in t for t in said), \
        "タイトルの言い直しを締めに入れている"


def test_反応が無い回は次の節から足して尺を使う(tmp_path):
    """**コメントが0件の回が38秒で終わっていた**（2026-09-20）。

    締めに足せるのは反応の節だけなので、紹介ものは尺が余ったまま終わる。
    そういう回は、切り出した節の**次の節の語り**で埋める。
    """
    from src.script_model import parse_script
    from src.shorts import trim

    tail = "\n".join(f"キャスター: 次の節の{i}行目です。ここもそれなりの長さがあります。" for i in range(8))
    text = f"""# 2部でプレーする5人
title: モラタもバロテッリも、いま2部にいる。その理由とは

## 5人は誰か
@main: true

キャスター: いま2部でプレーしている5人を見ていきます。

## クラブごと落ちた2人

{tail}
"""
    script = parse_script(text)
    short = trim(script)
    said = [l.text for l in short.scenes[-1].lines]
    assert any("次の節の" in t for t in said), f"続きの節から足していない: {said}"


def test_尺を詰めてもショート専用の前置きと受けの元は残る():
    """2026-09-22: 鈴木彩艶のショートで「2点取られた」の前置きが消え、
    「2点目は、鈴木が蹴ったボールから」も消えて「そのボールが」から始まっていた。"""
    from src.shorts import trim

    body = "\n".join([
        "## オープニング", "", "キャスター: 2失点でもベスト11。", "", "## 本編", "",
        "解説: 鈴木がベストイレブンに選ばれました。選んだのは解説者です。", "  only: short", "",
        "解説: ヴィラは3対2で勝ちましたが、2点を取られています。", "  only: short", "",
        "解説: 2点目は、鈴木が自陣から蹴ったボールから生まれています。", "",
        "解説: そのボールが相手陣の深くまで落ち、味方が決めました。", "",
        "エメリ: 彼はロングボールを選べる。とても長いパスを持っている選手だ。", "",
        "解説: 選んだ人は、2失点についてこう書いています。", "",
        "ディーニー: あの2点で、彼が責められることはない。本当に早く馴染んだ。", "",
    ])
    for limit in (40.0, 30.0, 25.0):
        texts = [l.text for l in trim(parse_script(body), max_seconds=limit).scenes[-1].lines]
        assert any("2点を取られています" in t for t in texts), f"{limit}秒: 前置きが消えた"
        for i, t in enumerate(texts):
            if t.startswith("そのボール"):
                assert i and "2点目は" in texts[i - 1], f"{limit}秒: 受けの元が消えた"
