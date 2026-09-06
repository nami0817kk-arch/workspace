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
