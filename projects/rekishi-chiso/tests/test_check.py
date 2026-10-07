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
