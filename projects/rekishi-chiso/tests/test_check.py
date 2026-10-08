from types import SimpleNamespace as NS

from chiso import check
from chiso.voice import Voice


def _sc(lines, shorts=None):
    return NS(lines=lines, shorts=shorts or {}, short_lines=lambda sid: [l for l in lines if sid in l.shorts])


def L(text, speaker="語り", tone="普通", card=None, shorts=()):
    return NS(index=0, text=text, speaker=speaker, tone=tone, card=card, shorts=shorts, background=None, portrait=None)


def test_lint_long_line_and_short_estimate():
    sc = _sc([L("あ" * 100, shorts=("s1",)), L("い" * 400, shorts=("s1",))], {"s1": {}})
    w = check.lint(sc, short_limit=60)
    assert any("100字" in x for x in w)
    assert any("ショート s1" in x for x in w)


def test_saturation_counts_only_hard_limits():
    sc = _sc([L("え", speaker="聞き", tone="驚き"), L("う", speaker="聞き")])
    strong = {"聞き": Voice(8, speed=1.12, intonation=1.45)}
    calm = {"聞き": Voice(8, speed=1.0, intonation=1.0, tone_strength=0.4, max_intonation=1.3, max_speed=1.08)}
    assert check.saturation(sc, strong)["聞き"] == (1, 2)          # 驚きで 2.0 を超える
    assert check.saturation(sc, calm)["聞き"] == (0, 2)            # 控えめの上限は狙いどおり


def test_missing_assets(tmp_path):
    (tmp_path / "a.jpg").write_bytes(b"x")
    pic = lambda n: NS(image=n)
    sc = _sc([NS(background=pic("a.jpg"), portrait=pic("b.jpg"))])
    assert check.missing_assets(sc, tmp_path) == ["b.jpg"]


def test_episode_rules():
    from chiso import script
    base = {
        "title": "王妃は本当に悪女だったのか",
        "next": {"title": "次", "teaser": "t"},
        "thumbnail": {k: "x" for k in ("image", "crop", "hook", "stamp", "name", "main")},
        "shorts": {"s1": {"title": "x"}},
        "sections": [{"title": "地表", "lines": [{"語り": "《a》", "short": "s1",
                                                  "figure": {"type": "map", "route": ["パリ", "ヴェルサイユ"]}}]},
                     {"title": "見立て：なぜ", "lines": [{"語り": "b"}, {"語り": "今日の地層は、ここまでです。"},
                                                       {"二人": "また一緒に、掘りましょう！"}]}],
    }
    errors, warns = check.episode(script.parse(base))
    assert errors == [] and any("図" in w for w in warns)
    bad = dict(base, next={}, sections=base["sections"][:1])
    errors, _ = check.episode(script.parse(bad))
    assert any("まとめ" in e for e in errors) and any("次回" in e for e in errors)


def test_unknown_place_is_error():
    from chiso import figures
    import pytest
    with pytest.raises(ValueError):
        figures.with_places({"type": "map", "route": ["どこでもない町"]})
    spec = figures.with_places({"type": "map", "route": ["パリ", "ヴェルサイユ"]})
    assert len(spec["places"]) == 2 and len(spec["bounds"]) == 4


def test_section_end_needs_hook():
    from chiso import script
    base = {
        "title": "t", "next": {"title": "次", "teaser": "t"},
        "thumbnail": {k: "x" for k in ("image", "crop", "hook", "stamp", "name", "main")},
        "sections": [{"title": "地表", "lines": [{"語り": "a"}]},                       # 導入は除く
                     {"title": "生涯", "lines": [{"語り": "b"}, {"語り": "c"}, {"語り": "d"}]},
                     {"title": "見立て：なぜ", "lines": [{"語り": "e"}]}],                 # 見立ても除く
    }
    errors, _ = check.episode(script.parse(base))
    assert [e for e in errors if "引き" in e] == ["2節「生涯」の終わり2行に引き（hook: true）がありません"]
    base["sections"][1]["lines"][1]["hook"] = True                                       # 終わりから2行目まではよい
    errors, _ = check.episode(script.parse(base))
    assert not [e for e in errors if "引き" in e]


def test_cast_rules():
    from chiso import script
    def ep(lines):
        return script.parse({"title": "t", "sections": [
            {"title": "地表", "lines": lines},
            {"title": "見立て：なぜ", "lines": [{"語り": "今日の地層は、ここまでです。"}, {"二人": "また一緒に、掘りましょう！"}]}]})
    ok = [{"語り": "はじめます"}, {"聞き": "はーい"}]
    errors, warns = check.cast_rules(ep(ok))
    assert errors == [] and warns == []
    errors, _ = check.cast_rules(ep([{"聞き": "a"}]))                                    # 最初は剣崎
    assert any("最初の行" in e for e in errors)
    bad = ok + [{"聞き": "え！？", "tone": "驚き"}] * 3 + [{"聞き": "そうなんですか？"}, {"聞き": "めすおちゃん"}]
    errors, warns = check.cast_rules(ep(bad))
    assert any("あだ名" in e for e in errors)
    assert any("驚くだけ" in w for w in warns) and any("丁寧語" in w for w in warns)
    sighs = ok + [{"聞き": "そっか……"}, {"聞き": "うん……"}, {"聞き": "ひどい……。"}]
    _, warns = check.cast_rules(ep(sighs))
    assert any("続いて" in w for w in warns)


def test_tsumugi_twice_in_a_row_warned():
    from chiso import script
    sc = script.parse({"title": "t", "sections": [{"title": "地表", "lines": [
        {"語り": "a"}, {"聞き": "b"}, {"聞き": "c"}]}]})
    _, warns = check.cast_rules(sc)
    assert any("2行続いて" in w for w in warns)


def test_lint_warns_stage_card_in_short():
    """見立ての「段階N」の札がショートに入ると唐突（10-06）。"""
    from chiso import script, check
    sc = script.parse({"title": "t", "shorts": {"s1": {"title": "a"}}, "sections": [{"title": "見立て", "lines": [
        {"語り": "一つ目は宣伝です。", "short": "s1", "card": {"head": "段階1", "body": "風刺画"}},
        {"語り": "二つ目。"}]}]})
    assert any("段階1" in w for w in check.lint(sc))


def test_pacing_warns_long_same_background_and_host_share():
    from chiso import script
    long = "あ" * 70                                      # 1行およそ10秒
    sc = script.parse({"title": "t", "sections": [{"title": "s", "background": {"image": "a.jpg"},
                       "lines": [{"語り": long}] * 6 + [{"聞き": "うん"}]}]})
    w = check.pacing(sc)
    assert any("同じ背景" in x for x in w) and any("剣崎の字数" in x for x in w)


# --- 知らせの並べ方（10-08）：同じ種類は1件に、止める → 直すと効く → 参考 ---------------------------

def test_report_folds_same_kind_and_orders_levels():
    warns = ["文体：書き言葉が1か所 「である」[3]（話し言葉に言い換える）",
             "1行目から同じ背景が40秒を超えます（場面ごとに絵を替える）",
             "13行目から同じ背景が40秒を超えます（場面ごとに絵を替える）",
             "12行目：せりふが92字（90字まで推奨）", "40行目：せりふが104字（90字まで推奨）",
             "3〜4行目：つむぎが2行続いています"]
    rows = check.report(["次回予告（next: {title, teaser}）がありません"], warns)
    assert rows[0].startswith("× ")
    assert rows[-1].startswith("・文体")                                     # 参考は最後
    bg = [r for r in rows if "同じ背景" in r]
    assert bg == ["! 1・13行目から同じ背景が40秒を超えます（場面ごとに絵を替える）［2か所］"]
    long = [r for r in rows if "せりふ" in r]
    assert len(long) == 1 and "12行目（92）" in long[0] and "40行目（104）" in long[0]
    assert any("3〜4行目：つむぎ" in r for r in rows)                        # 1件だけならそのまま


def test_report_keeps_messages_whose_other_numbers_differ():
    rows = check.report([], ["ショート s1：1行目（4行目）が…", "ショート s2：1行目（9行目）が…"])
    assert len(rows) == 2                                                    # 行の番号で始まらないものはまとめない


def test_span():
    assert check.span([9, 3, 4, 5]) == "3〜5・9"
    assert check.span([7]) == "7"


def test_staged_card_reported_once_per_card():
    from chiso import script
    lines = [{"語り": "一つ目です。", "short": "s1", "card": {"head": "段階1", "body": "宣伝"}},
             {"聞き": "うん。", "short": "s1"}, {"語り": "そうです。", "short": "s1"}]
    sc = script.parse({"title": "t", "shorts": {"s1": {"title": "x"}}, "sections": [{"title": "a", "lines": lines}]})
    w = [x for x in check.lint(sc) if "段階1" in x]
    assert len(w) == 1 and "1〜3行目" in w[0]


def _q(shorts, extra=()):
    lines = [L("ナポレオンの身長は168センチ", shorts=("s1",)), L("ギルレイがちびのボニーと描いた")] + list(extra)
    for i, l in enumerate(lines):
        l.index = i
    return _sc(lines, shorts)


def test_short_questions_missing_and_not_question():
    w = check.short_question_rules(_q({"s1": {"title": "x"}}))
    assert any("hook" in x and "tease" in x and "s1" in x for x in w)
    w = check.short_question_rules(_q({"s1": {"hook": "低かった。", "tease": "誰が描いた？"}}))
    assert any("？で終わっていません" in x and "hook" in x for x in w)


def test_short_questions_same_and_answer_in_main():
    w = check.short_question_rules(_q({"s1": {"hook": "背は低い？", "tease": "背は低い？"}}))
    assert any("同じ問い" in x for x in w)
    ok = check.short_question_rules(_q({"s1": {"hook": "本当に低い？", "tease": "『チビ』の絵を描いたのは誰？"}}))
    assert ok == []                                    # チビ → ちび（カタカナとひらがなは同じに見る）
    w = check.short_question_rules(_q({"s1": {"hook": "本当に低い？", "tease": "ワーテルローで勝ったのは誰？"}}))
    assert any("見当たりません" in x and "ワーテルロー" in x for x in w)


def test_question_nouns():
    assert check.question_nouns("じゃあ、『チビの独裁者』の絵を／描き続けたのは誰？")[:3] == ["チビの独裁者", "チビ", "独裁者"]


def test_short_length_counts_hook_and_tease():
    body = [L("あ" * 300, shorts=("s1",))]
    assert not any("ショート s1" in x for x in check.lint(_sc(body, {"s1": {}})))
    w = check.lint(_sc(body, {"s1": {"hook": "い" * 40 + "？", "tease": "う" * 30 + "？"}}))
    assert any("ショート s1" in x and "372字" in x for x in w)
    w = check.lint(_sc([L("あ" * 120, shorts=("s1",))], {"s1": {}}))
    assert any("本文が120字" in x for x in w)
