import pytest

from src.config import load_config
from src.script_model import parse_script
from src.shorts import MAX_SECONDS, SIZE, ShortError, _estimate, portrait, trim

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
    assert len(short.scenes[1].lines) == 1
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
    assert texts[-1] == "賛成しない"


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
