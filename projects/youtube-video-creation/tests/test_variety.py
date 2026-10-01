"""その日ぶんを並べて見る点検。

**review は1本ずつしか見ない。**個々は正常でも並べると異常、という型は
粒度を変えないと永久に見えない（2026-09-06 に11本で実際に起きた）。
"""


def _script(title, headings, speakers=("キャスター", "解説")):
    from src.script_model import parse_script

    nl = chr(10)
    body = ["---", f"title: {title}", "---", ""]
    body += ["## オープニング", "", "キャスター: つかみ。", ""]
    for i, head in enumerate(headings):
        body += [f"## {head}", ""]
        for who in speakers:
            body.append(f"{who}: {head}の話。")
        body.append("")
    body += ["## まとめ", "", "解説: まとめ。", ""]
    return parse_script(nl.join(body))


def test_入り方が揃いすぎていたら止める():
    """**9本が「何が起きたか」で始まっていた。**review は11本とも合格を出した。"""
    from src.variety import inspect_day

    scripts = [_script(f"T{i}", ["何が起きたか", f"論点{i}", "これからどうなる"])
               for i in range(10)]
    found = {f.label: f for f in inspect_day(scripts)}
    assert not found["入り方"].ok
    assert "何が起きたか" in found["入り方"].detail
    assert not found["締め方"].ok


def test_散らばっていれば通す():
    """外しすぎていないことも確かめる。**✓しか出ない検査は壊れても気づけない。**"""
    from src.variety import inspect_day

    shapes = [["何が起きたか", "なぜ", "これからどうなる"],
              ["試合はどう動いたか", "分かれ目はどこか", "数字で見ると"],
              ["何を言ったのか", "どういう状況か", "どう受け止められたか"],
              ["誰にどんな処分が出たか", "何があったのか", "覆る可能性はあるか"],
              ["何がかかっているか", "当事者は何と言ったか", "どこを見るか"],
              ["試合はどう動いたか", "分かれ目はどこか", "数字で見ると"]]
    scripts = [_script(f"T{i}", s) for i, s in enumerate(shapes)]
    found = {f.label: f for f in inspect_day(scripts)}
    assert found["入り方"].ok, found["入り方"].detail
    assert found["締め方"].ok, found["締め方"].detail


def test_引用を本人の声で読ませていない回を見つける():
    """**キャスター1人で説明する回は正しい**（2026-09-06 ユーザー）。

    人数ではなく、引用カードを出しているのに地の文で読んでいないかを見る。
    """
    from src.script_model import parse_script
    from src.variety import inspect_day

    nl = chr(10)
    head = ["---", "title: A", "cards:", "  q:", "    type: quote",
            "    source: X", "    text: hello", "---", ""]
    body = ["## オープニング", "", "キャスター: つかみ。", "",
            "## 何が起きたか", "", "キャスター: こう話しました。", "  card: q", ""]
    silent = parse_script(nl.join(head + body))

    voiced = parse_script(nl.join(
        head + ["## オープニング", "", "キャスター: つかみ。", "",
                "## 何が起きたか", "", "キャスター: こう話しました。", "  card: q",
                "アルテタ: 私はこう思う。", ""]))

    found = {f.label: f for f in inspect_day([silent, voiced])}
    assert not found["代弁"].ok
    assert "1本" in found["代弁"].detail

    found = {f.label: f for f in inspect_day([voiced, voiced])}
    assert found["代弁"].ok


def test_キャスター1人でも引用が無ければ通す():
    """**引用の無い回は1人で読んでよい。**外しすぎていないことの確認。"""
    from src.variety import inspect_day

    scripts = [_script("A", ["い", "ろ", "は"], speakers=("キャスター",)),
               _script("B", ["に", "ほ", "へ"], speakers=("キャスター",))]
    found = {f.label: f for f in inspect_day(scripts)}
    assert found["代弁"].ok


def test_接頭辞が偏っていたら止める():
    """全部が【速報】だと、速報に見えなくなる。"""
    from src.variety import inspect_day

    scripts = [_script(f"【速報】T{i}", ["い", "ろ", f"は{i}"]) for i in range(4)]
    found = {f.label: f for f in inspect_day(scripts)}
    assert not found["接頭辞"].ok


def test_1本では比べられない():
    from src.variety import inspect_day

    found = inspect_day([_script("A", ["い", "ろ", "は"])])
    assert all(f.ok for f in found)


def test_札が半分を超えたら知らせる():
    """**毎回付けない**（2026-09-08 ユーザー指示）。並ぶと一覧で効かなくなる。"""
    from src.variety import inspect_day

    scripts = [_script(f"【速報】話{i}", ["何が", f"論点{i}", "これから"])
               for i in range(4)]
    found = {f.label: f for f in inspect_day(scripts)}
    assert not found["札の数"].ok


def test_札が少なければ通す():
    from src.variety import inspect_day

    scripts = [_script("【速報】話0", ["何が", "論点0", "これから"])]
    scripts += [_script(f"話{i}", ["何が", f"論点{i}", "これから"])
                for i in range(1, 4)]
    found = {f.label: f for f in inspect_day(scripts)}
    assert found["札の数"].ok


def test_結び方が揃っていたら知らせる():
    """**9本中7本が「〜がこちらです」だった**（2026-09-08 ユーザー指摘）。

    1本ずつの点検は「答えを隠しているか」しか見ない。並べないと気づけない。
    """
    from src.variety import inspect_day

    scripts = [_script(f"話{i}がこちらです", ["何が", f"論点{i}", "これから"])
               for i in range(4)]
    found = {f.label: f for f in inspect_day(scripts)}
    assert not found["結び方"].ok


def test_結び方が散っていれば通す():
    from src.variety import inspect_day

    titles = ["レスター、どこまで落ちたか", "上田が語った移籍の理由",
              "ムバッペの言葉が話題に", "久保に何が起きたのか"]
    scripts = [_script(t, ["何が", t[:3], "これから"]) for t in titles]
    found = {f.label: f for f in inspect_day(scripts)}
    assert found["結び方"].ok


def test_言いさしの結びは字面が違っても揃いとみなす():
    """2026-09-22 に7本中7本が「〜のは」「〜言葉は」で終わっていた。

    末尾6字の一致で見ていたので、1本ずつ字面が違い「散らばっています」と出た。
    """
    from src.variety import inspect_day

    titles = ["上田綺世が決めた1点。並んだ言葉は", "鈴木彩艶がベスト11に。書いたのは",
              "日本代表の値段が出た。上がったのは", "メッシが930点目。届いたのは"]
    scripts = [_script(t, ["何が", t[:3], "これから"]) for t in titles]
    found = {f.label: f for f in inspect_day(scripts)}
    assert not found["結び方"].ok


def test_本のあいだの重なりは語りだけを見て名前は数えない():
    """2026-09-22: ラフィーニャとシメオネが同じ「7戦全勝、31得点7失点」を読んでいた。
    クリスティアーノ・ロナウドの名前が両方に出るだけなら鳴らさない。"""
    from src.script_model import Line, Scene, Script
    from src.variety import _cross_repeats

    def script(title, text):
        return Script(title=title, meta={"title": title}, scenes=[
            Scene(title="本編", lines=[Line(speaker="解説", text=text)])])

    a = script("A", "移籍金は1500万ユーロでした。獲ったときの倍です。")
    b = script("B", "1500万ユーロで移った上田が、初戦で決めました。")
    assert _cross_repeats([a, b])                      # 同じ金額を2本で読んでいる
    a2 = script("A2", "オランダでは、この額に厳しい声が出ていました。")
    b2 = script("B2", "送り出したオランダでは、この額に厳しい声が出ていました。")
    assert _cross_repeats([a2, b2])                    # 同じ言い回し
    c = script("C", "前の5人は、メッシ、クリスティアーノ・ロナウド、イグアイン。")
    d = script("D", "クリスティアーノ・ロナウドは64本、マラドーナは61本です。")
    assert _cross_repeats([c, d]) == []


def test_反応の節で終わるのは締め方に数えない():
    """**news の型は反応の節で終わる決まり**（2026-09-08）。締め方の点検がそれを数えると、
    決まりどおりの台本が毎日止まった（2026-09-27）。手前の節で比べる。"""
    from src.variety import inspect_day

    scripts = [_script("A", ["何が起きたか", "ケインの足もと", "ネットの反応"]),
               _script("B", ["8戦全勝", "98年前の1チーム", "ネットの反応"]),
               _script("C", ["モナコの企画", "夏のワールドカップ", "ネットの反応"])]
    found = {f.label: f for f in inspect_day(scripts)}
    assert found["締め方"].ok, found["締め方"].detail


def test_反応の手前が揃っていれば止める():
    from src.variety import inspect_day

    scripts = [_script(f"T{i}", [f"話{i}", "これからどうなる", "ネットの反応"]) for i in range(3)]
    found = {f.label: f for f in inspect_day(scripts)}
    assert not found["締め方"].ok
    assert "これからどうなる" in found["締め方"].detail


def test_紹介のシリーズは節の並びが同じでも止めない():
    """クラブ紹介・選手紹介は8節の型で量産する企画（2026-09-28）。入り方・締め方・話の型は見ず、本のあいだの重なりだけ見る。"""
    from src.script_model import parse_script
    from src.variety import inspect_day, is_series_intro

    def script(name, first_line):
        return parse_script(
            f"---\ntitle: {name}ってどんな選手？\nseries: 有名選手の紹介\n---\n\n"
            f"## どんな選手か\n\nキャスター: {first_line}\n\n## 基礎DATA\n\nキャスター: {name}、19歳。\n\n## 見立て\n\n解説: {name}の次の試合を見ます。\n")

    scripts = [script("ハーランド", "ボールに触らないのに点だけ取る。"), script("ヤマル", "メッシの腕の中にいた赤ん坊。"),
               script("オリーズ", "3度追い出された少年。")]
    assert all(is_series_intro(s) for s in scripts)
    labels = {f.label: f.ok for f in inspect_day(scripts)}
    assert labels["話の型"] is True and "入り方" not in labels and "締め方" not in labels
    assert "本のあいだ" in labels


def test_見立てのカードは代弁の点検で数えない():
    """2026-10-01：声の無い比較の回が、見立ての引用カードだけで「本人の声で読ませていない」と止まった。"""
    from types import SimpleNamespace
    from src.variety import _spoken_for
    script = SimpleNamespace(cards={"view_card": {"type": "quote", "label": "この動画の見立て", "text": "…"}},
                             scenes=[SimpleNamespace(lines=[SimpleNamespace(speaker="解説")])])
    assert _spoken_for(script) == (0, 0)
    script.cards["q"] = {"type": "quote", "text": "本人の言葉"}
    assert _spoken_for(script)[0] == 1
