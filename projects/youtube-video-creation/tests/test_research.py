from datetime import datetime, timedelta

import pytest

from src import coverage
from src.plan import build_plan
from src.research import (
    ResearchError,
    build_notes,
    check_repeats,
    to_script,
    verify,
)
from tests.test_plan import RAW

NOW = datetime(2026, 8, 29, 19, 0)


def _section(**overrides):
    base = {
        "id": "what",
        "heading": "何が起きたか",
        "tier": "確定",
        "telop": "A → B",
        "say": "えーからびーへうつりました。",
        "official": True,
        "sources": ["https://example.com/1"],
    }
    return {**base, **overrides}


def _raw(**overrides):
    base = {
        "date": "2026年8月29日",
        "slot": "evening",
        "theme": {
            "id": "move",
            "title": "なぜ移籍が決まらないのか",
            "hook": "大きな移籍が動いています。",
            "question": "なぜ金の問題ではないのか",
        },
        "answer": "ライバルに売りたくないから",
        "watch": "本人の決断",
        "sections": [
            _section(),
            # **節ごとに別のことを言う。**同じ一文を3節に置くと
            # 「節をまたいだ言い直し」の点検に引っかかる（2026-09-14 に追加）
            _section(id="why", heading="なぜそうなったか", tier="背景", sources=[],
                     say="ちーむのじじょうがありました。", official=False),
            _section(id="next", heading="これからどうなる", tier="未確認",
                     say="つぎのしあいはどようびです。", official=False),
        ],
    }
    return {**base, **overrides}


def _plan():
    plan = build_plan(RAW)
    plan.tiers["背景"] = {"needs_sources": 0, "needs_official": False}
    plan.policy = {"min_sections": 3, "require_question": True}
    return plan


def test_valid_notes_pass():
    assert verify(build_notes(_raw()), _plan()) == []


def test_theme_is_required():
    with pytest.raises(ResearchError, match="1本＝1テーマ"):
        build_notes({"date": "d", "sections": [_section()]})


def test_sections_are_required():
    with pytest.raises(ResearchError, match="sections が空"):
        build_notes({"theme": {"title": "t"}, "sections": []})


def test_question_is_required():
    raw = _raw()
    raw["theme"] = {**raw["theme"], "question": ""}
    problems = verify(build_notes(raw), _plan())
    assert any("question" in p for p in problems)


def test_answer_is_not_required_anymore():
    """2026-09-08 ユーザー「まとめはいらない」。答えの節が無いので answer は求めない。"""
    assert verify(build_notes(_raw(answer="")), _plan()) == []


def test_too_few_sections_is_not_a_deep_dive():
    problems = verify(build_notes(_raw(sections=[_section()])), _plan())
    assert any("深掘りには3つ以上" in p for p in problems)


def test_context_tier_needs_no_sources():
    """背景の説明は新規の報道ではないので、出典を求めない。"""
    raw = _raw()
    raw["sections"][1]["sources"] = []
    assert verify(build_notes(raw), _plan()) == []


def test_report_tier_needs_one_source():
    """報道は**1本でよい**（2026-09-07 のユーザー判断）。

    config だけ 2 のまま残っていたので、取材メモが「2本目の欄」を
    埋めるために同じ記事を並べるようになっていた（2026-09-12 に発覚）。
    """
    raw = _raw()
    raw["sections"][0] = _section(tier="報道", official=False)
    assert not any("出典が" in p for p in verify(build_notes(raw), _plan()))


def test_report_tier_needs_at_least_one_source():
    raw = _raw()
    raw["sections"][0] = _section(tier="報道", official=False, sources=[])
    problems = verify(build_notes(raw), _plan())
    assert any("出典が1本必要" in p for p in problems)


def test_confirmed_tier_needs_an_official_announcement():
    raw = _raw()
    raw["sections"][0] = _section(official=False)
    problems = verify(build_notes(raw), _plan())
    assert any("発表が条件" in p for p in problems)


def test_problems_name_the_section():
    raw = _raw()
    raw["sections"][0] = _section(id="zzz", telop="", say="")
    problems = verify(build_notes(raw), _plan())
    assert any(p.startswith("zzz:") and "telop" in p for p in problems)


def test_sources_are_collected_without_duplicates():
    raw = _raw()
    raw["sections"][2]["sources"] = ["https://example.com/1", "https://example.com/2"]
    assert build_notes(raw).sources == ["https://example.com/1", "https://example.com/2"]


def test_to_script_refuses_notes_that_fail_verification():
    raw = _raw()
    raw["theme"]["question"] = ""
    with pytest.raises(ResearchError, match="不備"):
        to_script(build_notes(raw), _plan())


def test_generated_script_opens_with_the_question():
    from src.script_model import parse_script

    script = parse_script(to_script(build_notes(_raw()), _plan()))
    # **まとめは無い**（2026-09-08 ユーザー「まとめはいらない」）。最後の節で終わる
    assert [s.title for s in script.scenes] == [
        "オープニング", "何が起きたか", "なぜそうなったか", "これからどうなる"
    ]
    # **問いは画面に出さない**（2026-09-14 指摘「この今回の問はいらない」）。
    # 冒頭の2行目は、喋っているつかみがそのまま画面に出る
    assert not any("今回の問い" in line.telop_text() for line in script.lines)
    assert any("大きな移籍が動いています" in line.telop_text() for line in script.lines)
    assert "wrap" not in script.cards


def test_generated_script_carries_the_context_tier():
    from src.script_model import parse_script

    script = parse_script(to_script(build_notes(_raw()), _plan()))
    assert "context" in {line.source for line in script.lines}


def test_repeat_is_flagged(tmp_path):
    ledger = tmp_path / "covered.yaml"
    coverage.save(
        ledger, [coverage.Entry("move", "なぜ移籍が決まらないのか", "morning",
                                NOW - timedelta(hours=6))]
    )
    plan = _plan()
    plan.coverage = {"ledger": str(ledger), "repeat_within_hours": 36}
    problems = check_repeats(build_notes(_raw()), plan, now=NOW)
    assert len(problems) == 1 and "morning" in problems[0]


def test_follow_up_is_allowed(tmp_path):
    ledger = tmp_path / "covered.yaml"
    coverage.save(
        ledger, [coverage.Entry("move", "なぜ移籍が決まらないのか", "morning",
                                NOW - timedelta(hours=6))]
    )
    plan = _plan()
    plan.coverage = {"ledger": str(ledger), "repeat_within_hours": 36}
    assert check_repeats(build_notes(_raw(follow_up=True)), plan, now=NOW) == []


def test_video_title_takes_a_prefix():
    raw = _raw()
    raw["theme"] = {**raw["theme"], "prefix": "速報"}
    assert build_notes(raw).video_title == "【速報】なぜ移籍が決まらないのか"
    assert build_notes(_raw()).video_title == "なぜ移籍が決まらないのか"


def test_breaking_prefix_without_solid_sections_is_flagged():
    """未確認だけの回に【速報】を付けると、内容と釣り合わない。"""
    from src.research import advise

    raw = _raw()
    raw["theme"] = {**raw["theme"], "prefix": "速報"}
    raw["sections"] = [
        _section(id="a", tier="未確認", official=False),
        _section(id="b", tier="未確認", official=False),
        _section(id="c", tier="未確認", official=False),
    ]
    assert any("速報" in w for w in advise(build_notes(raw)))


def test_breaking_prefix_is_fine_with_a_confirmed_section():
    from src.research import advise

    raw = _raw()
    raw["theme"] = {**raw["theme"], "prefix": "速報"}
    raw["thumbnail"] = {"line1": "短い見出し", "line2": "赤帯の文字"}
    # 2026-09-07: 他人の声が足りないヒントは、どの取材メモにも出るようになった
    # （参考3チャンネルは尺の58%が他人の声、こちらは14%だった）。札の点検とは別の話
    # 2026-09-08: 中身の量（数字・出典）のヒントも同様にどのメモにも出る
    volume = ("他人の声", "数字を含む行", "出典が")
    assert [h for h in advise(build_notes(raw)) if not any(v in h for v in volume)] == []


def test_unknown_prefix_is_flagged():
    """2026-09-07: 札を12種類に増やしたので、見本を本当に無い札に変えた。

    向こうは動画ごとに強い言葉を作っていた（【激ヤバ】【緊急事態】【崩壊】）。
    こちらも増やしたが、**定番の外は止める**という決まりはそのまま。
    """
    from src.research import advise

    raw = _raw()
    raw["theme"] = {**raw["theme"], "prefix": "大爆笑"}
    raw["thumbnail"] = {"line1": "短い見出し", "line2": "赤帯の文字"}
    assert any("定番ではありません" in w for w in advise(build_notes(raw)))


def test_増やした札は通る():
    from src.research import advise

    raw = _raw()
    raw["theme"] = {**raw["theme"], "prefix": "衝撃"}
    assert not any("定番ではありません" in w for w in advise(build_notes(raw)))


def test_long_thumbnail_lines_are_flagged():
    from src.research import advise

    raw = _raw(thumbnail={"line1": "あ" * 20, "line2": "い" * 25})
    hints = advise(build_notes(raw))
    assert any("line1 が長め" in w for w in hints)
    assert any("line2 が長め" in w for w in hints)


def test_thumbnail_lines_reach_the_script():
    from src.script_model import parse_script

    raw = _raw(thumbnail={"line1": "黄色帯の文字", "line2": "赤帯の文字",
                          "tags": ["反応1", "反応2"]})
    script = parse_script(to_script(build_notes(raw), _plan()))
    assert script.meta["thumbnail_line1"] == "黄色帯の文字"
    assert script.meta["thumbnail_tags"] == ["反応1", "反応2"]


def test_stale_x_sources_are_flagged():
    from src.research import advise

    plan = _plan()
    plan.accounts = [{"handle": "FabrizioRomano", "name": "Fabrizio Romano"}]
    plan.social = {"stale_hours": 24}
    raw = _raw()
    # 2019年の投稿。開かなくてもURLから古さが分かる
    raw["sections"][2]["sources"] = [
        "https://x.com/FabrizioRomano/status/1183028368629010432"
    ]
    hints = advise(build_notes(raw), plan)
    assert any("時間前" in h and "これからどうなる" in h for h in hints)


def test_unknown_x_accounts_are_flagged():
    from src.research import advise

    plan = _plan()
    plan.accounts = [{"handle": "FabrizioRomano"}]
    plan.social = {"stale_hours": 24}
    raw = _raw()
    raw["sections"][2]["sources"] = ["https://x.com/whoever/status/2092546263447146991"]
    assert any("登録済み" in h for h in advise(build_notes(raw), plan))


def test_non_x_sources_are_left_alone():
    from src.research import advise

    plan = _plan()
    plan.accounts = []
    raw = _raw()
    raw["sections"][2]["sources"] = ["https://www.skysports.com/football/news/1"]
    assert not any("時間前" in h for h in advise(build_notes(raw), plan))


def test_advise_skips_the_x_checks_without_a_plan():
    from src.research import advise

    raw = _raw()
    raw["sections"][2]["sources"] = [
        "https://x.com/FabrizioRomano/status/1183028368629010432"
    ]
    assert not any("時間前" in h for h in advise(build_notes(raw)))


def test_regenerating_the_same_slot_today_is_not_a_repeat(tmp_path):
    plan = _plan()
    ledger = tmp_path / "covered.yaml"
    plan.coverage = {"ledger": str(ledger), "repeat_within_hours": 36}
    notes = build_notes(_raw(slot="evening"))

    coverage.record(ledger, "evening", [("move", "なぜ移籍が決まらないのか")], NOW)
    assert check_repeats(notes, plan, NOW) == []          # 同じ枠の作り直し


def test_the_same_theme_in_another_slot_is_still_a_repeat(tmp_path):
    plan = _plan()
    ledger = tmp_path / "covered.yaml"
    plan.coverage = {"ledger": str(ledger), "repeat_within_hours": 36}
    notes = build_notes(_raw(slot="evening"))

    coverage.record(ledger, "morning", [("move", "なぜ移籍が決まらないのか")], NOW)
    assert check_repeats(notes, plan, NOW)                # 朝に出した話を夜にも出そうとしている


def test_recording_the_same_slot_twice_replaces_rather_than_piles_up(tmp_path):
    ledger = tmp_path / "covered.yaml"
    coverage.record(ledger, "morning", [("move", "1回目")], NOW)
    coverage.record(ledger, "morning", [("move", "2回目")], NOW)
    entries = coverage.load(ledger)
    assert len(entries) == 1
    assert entries[0].headline == "2回目"


def test_long_notes_are_shortened_for_the_screen():
    """**収まるなら丸ごと出す**（2026-09-10 に変更）。

    前は「。」で切って1文目だけにしていた。2文目以降は必ず落ちるので、
    19本513行を数えたら**読み上げの46%しか画面に出ていなかった**
    （ユーザー指摘）。上限も1行ぶん（26字）から2行ぶん（54字）へ広げた。
    """
    from src.research import TELOP_LIMIT, _telop

    two = "問題は金額ではなく「誰に売るか」。ライバルに主力を渡すこと自体を拒んでいる"
    assert len(two) <= TELOP_LIMIT
    assert _telop(two) == two                       # 2文とも出す
    # **読み上げる文はぜんぶ出す**（2026-09-14 指示）。100字でも切らない。
    # 入りきらないぶんは render が字を小さくして収める
    assert _telop("あ" * 100) == "あ" * 100
    # 上限そのものは残す。桁違いに長いものだけ落とす
    assert _telop("あ" * 300).endswith("…")
    assert len(_telop("あ" * 300)) == TELOP_LIMIT
    assert _telop("") == ""
    # 末尾の。は付けない（枠が狭く見える）
    assert _telop("短い一文です。") == "短い一文です"


def test_収まらないときは文の切れ目で切る():
    """**途中でぶつ切りにしない。**限度の中に「。」や「、」があればそこで切る。"""
    from src.research import _telop

    text = "9月4日のプレミアリーグ第3節、イプスウィッチ戦。途中出場でのデビューでした"
    got = _telop(text, 30)
    assert got == "9月4日のプレミアリーグ第3節、イプスウィッチ戦"
    assert "…" not in got


def test_地の文もテロップにする():
    """**16字に収まる行だけ出していた**ので、513行のうち198行で画面が止まっていた。"""
    from src.research import _telop

    long_line = "一方のレアル・マドリードは同じ節でベティスに0対1で敗れ、今季初黒星"
    assert len(long_line) > 16
    assert _telop(long_line) == long_line          # 前は "" だった


def test_written_notes_are_turned_into_spoken_lines():
    from src.research import _spoken

    # 動詞の言い切り → 「ということです」
    assert _spoken("主力を渡すこと自体を拒んでいる").endswith("拒んでいる、ということです。")
    # 名詞止め → 「です」
    assert _spoken("期限は9月2日の朝7時").endswith("朝7時です。")
    # すでに ですます なら触らない
    assert _spoken("移籍は成立しました") == "移籍は成立しました。"
    assert _spoken("") == ""


def test_only_the_last_sentence_is_made_polite():
    from src.research import _spoken

    assert _spoken("A。Bを拒んでいる") == "A。Bを拒んでいる、ということです。"


def _plan_with_domains():
    plan = _plan()
    plan.domains = {
        "official": ["atleticodemadrid.com"],
        "english": ["skysports.com"],
        "rumour": ["caughtoffside.com"],
        "blocked": ["bbc.com"],
    }
    plan.domain_tiers = {"official": "確定", "english": "報道", "rumour": "未確認"}
    return plan


def test_a_confident_claim_backed_only_by_rumour_sites_is_flagged():
    from src.research import advise

    plan = _plan_with_domains()
    raw = _raw()
    raw["sections"][0]["tier"] = "確定"
    raw["sections"][0]["sources"] = ["https://www.caughtoffside.com/2026/08/29/x/"]
    hints = advise(build_notes(raw), plan)
    assert any("出典が弱い" in h and "rumour" in h for h in hints)


def test_an_official_source_supports_a_confident_claim():
    from src.research import advise

    plan = _plan_with_domains()
    raw = _raw()
    raw["sections"][0]["tier"] = "確定"
    raw["sections"][0]["sources"] = ["https://en.atleticodemadrid.com/noticias/statement"]
    assert not any("出典が弱い" in h for h in advise(build_notes(raw), plan))


def test_the_strongest_source_in_a_section_decides():
    from src.research import advise

    plan = _plan_with_domains()
    raw = _raw()
    raw["sections"][0]["tier"] = "確定"
    raw["sections"][0]["sources"] = [
        "https://www.caughtoffside.com/2026/08/29/x/",
        "https://en.atleticodemadrid.com/noticias/statement",
    ]
    assert not any("出典が弱い" in h for h in advise(build_notes(raw), plan))


def test_an_unknown_domain_is_reported():
    from src.research import advise

    plan = _plan_with_domains()
    raw = _raw()
    raw["sections"][0]["sources"] = ["https://example.com/article"]
    assert any("どの情報源の群にも入っていません" in h for h in advise(build_notes(raw), plan))


def test_a_blocked_domain_in_the_sources_is_flagged():
    from src.research import advise

    plan = _plan_with_domains()
    raw = _raw()
    raw["sections"][0]["sources"] = ["https://www.bbc.com/sport/football/12345"]
    hints = advise(build_notes(raw), plan)
    assert any("取得できないサイト" in h for h in hints)


def test_a_blocked_domain_does_not_prop_up_the_tier():
    from src.research import advise

    plan = _plan_with_domains()
    raw = _raw()
    raw["sections"][0]["tier"] = "確定"
    raw["sections"][0]["sources"] = [
        "https://www.bbc.com/sport/1",
        "https://www.caughtoffside.com/2026/08/29/x/",
    ]
    hints = advise(build_notes(raw), plan)
    assert any("出典が弱い" in h for h in hints)   # bbc は数に入れない


def _reaction_raw(**card_overrides):
    raw = _raw()
    card = {
        "type": "reactions",
        "items": [{"text": "補強しても勝てないのか", "label": "X"}],
    }
    card.update(card_overrides)
    raw["sections"][2].update({
        "tier": "未確認",
        "card": card,
        "sources": ["https://x.com/someone/status/2093440301448737183"],
    })
    return raw


def test_出典の無い反応カードも書き出す():
    """**止めない**（2026-09-11 ユーザー「出しても良い」）。

    反応そのものを実在する投稿から引く決まりは変えていない。
    URL を後から足す回まで止めないだけ。
    """
    plan = _plan()
    raw = _reaction_raw()
    raw["sections"][2]["sources"] = []
    problems = verify(build_notes(raw), plan)
    assert not any("出典がありません" in p for p in problems)


def test_a_reactions_card_with_sources_passes():
    assert verify(build_notes(_reaction_raw()), _plan()) == []


def test_an_account_name_on_a_reaction_is_blocked():
    raw = _reaction_raw(items=[{"text": "補強しても勝てないのか", "label": "@spursfan"}])
    problems = verify(build_notes(raw), _plan())
    assert any("アカウント名" in p for p in problems)


def test_other_cards_are_not_subject_to_the_reaction_rules():
    raw = _raw()
    raw["sections"][2].update({"card": {"type": "points", "items": ["a"]}, "sources": []})
    problems = verify(build_notes(raw), _plan())
    assert not any("反応カード" in p for p in problems)


def test_reactions_reported_as_a_majority_are_flagged():
    from src.research import advise

    raw = _reaction_raw()
    raw["sections"][2]["say"] = ["補強を疑問視する声が多いようです。"]
    hints = advise(build_notes(raw))
    assert any("数を数えた言い方" in h for h in hints)


def test_reactions_presented_as_reporting_are_flagged():
    from src.research import advise

    raw = _reaction_raw()
    raw["sections"][2]["tier"] = "報道"
    hints = advise(build_notes(raw))
    assert any("未確認" in h for h in hints)


def _sourced(*per_section):
    raw = _raw()
    for section, sources in zip(raw["sections"], per_section):
        section["sources"] = list(sources)
        section["tier"] = "報道" if len(sources) >= 2 else "未確認"
        section["official"] = False
    return raw


def test_reusing_one_article_across_sections_is_flagged():
    from src.research import advise

    same = "https://www.skysports.com/football/news/1/2/a"
    raw = _sourced([same, "https://www.espn.com/soccer/story/_/id/1/x"], [same], [same])
    hints = advise(build_notes(raw), _plan_with_domains())
    assert any("同じ記事を3つの節" in h for h in hints)


def test_using_an_article_twice_is_not_flagged():
    from src.research import advise

    same = "https://www.skysports.com/football/news/1/2/a"
    raw = _sourced([same, "https://www.espn.com/soccer/story/_/id/1/x"], [same], [])
    assert not any("同じ記事を" in h for h in advise(build_notes(raw), _plan_with_domains()))


def test_leaning_on_one_outlet_is_flagged():
    from src.research import advise

    plan = _plan_with_domains()
    raw = _sourced(
        ["https://www.skysports.com/football/news/1/2/a", "https://www.skysports.com/football/news/1/3/b"],
        ["https://www.skysports.com/football/news/1/4/c"],
        [],
    )
    hints = advise(build_notes(raw), plan)
    assert any("1社の報道に乗っている" in h for h in hints)


def test_a_spread_of_outlets_is_not_flagged():
    from src.research import advise

    plan = _plan_with_domains()
    raw = _sourced(
        ["https://www.skysports.com/football/news/1/2/a", "https://www.espn.com/soccer/story/_/id/1/b"],
        ["https://www.footballchannel.jp/2026/08/29/post1/"],
        [],
    )
    assert not any("1社の報道" in h for h in advise(build_notes(raw), plan))


def test_official_sources_are_not_counted_as_leaning():
    from src.research import advise

    plan = _plan_with_domains()
    official = "https://en.atleticodemadrid.com/noticias/"
    raw = _sourced([official + "a", official + "b"], [official + "c"], [])
    # 公式は1社に寄って当然
    assert not any("1社の報道" in h for h in advise(build_notes(raw), plan))


# まとめのカードに問い・答え・次の焦点の3つを詰めていたので、2分の動画の締めに
# しては字が細かく、下のテロップとも重なっていた（作った動画を目視して発見）。


def test_まとめのカードは作らない():
    """2026-09-08 ユーザー「まとめはいらない」。答えのカードも出さない。"""
    from src.research import _cards, load_notes

    notes = load_notes("research/20260903_evening.yaml")
    assert "wrap" not in _cards(notes)


# 4本とも1行目がタイトルの読み上げで、まとめの節は1つも無かった。

def test_1行目はタイトルをそのまま読む():
    from src.script_model import parse_script

    notes = build_notes(_raw())
    script = parse_script(to_script(notes, _plan()))
    first = next(line for line in script.lines if (line.text or "").strip())
    assert notes.title in first.text
    assert first.telop_text() == notes.title


def test_反応の節のあとに語りの節があれば止める():
    """参考の動画は反応の最後の1件で終わる（2026-09-08 サッカーラボの文字起こし）。

    こちらは反応のあと「これから何を見るか」と「まとめ」を語っていた。
    """
    raw = _raw()
    raw["sections"] = [
        _section(),
        _section(id="net", heading="ネットの声", tier="未確認", official=False,
                 say=[{"voice": "ネット民", "text": "まだ序盤やしな"},
                      {"voice": "ネット民", "text": "お茶会で干されたか"}]),
        _section(id="next", heading="これから何を見るか", tier="未確認", official=False),
    ]
    problems = verify(build_notes(raw), _plan())
    assert any("反応の節のあとに" in p and "これから何を見るか" in p for p in problems)


def test_反応で終わる並びは通る():
    raw = _raw()
    raw["sections"] = [
        _section(),
        _section(id="next", heading="これから何を見るか", tier="未確認", official=False),
        _section(id="net", heading="ネットの声", tier="未確認", official=False,
                 say=[{"voice": "ネット民", "text": "まだ序盤やしな"},
                      {"voice": "ネット民", "text": "お茶会で干されたか"}]),
    ]
    assert verify(build_notes(raw), _plan()) == []


def test_締めの挨拶を読み上げない():
    """毎回同じ8秒。最後のカードと概要欄で足りる。"""
    body = to_script(build_notes(_raw()), _plan())
    assert "チャンネル登録してお待ちください" not in body
    assert "次の焦点です" not in body


def test_他人の声が足りないと助言する():
    from src.research import advise

    hints = advise(build_notes(_raw()))
    assert any("他人の声" in h for h in hints)


def test_反応を入れれば助言は出ない():
    from src.research import advise

    raw = _raw()
    voices = [{"voice": "ネット民", "text": f"これは強い{i}"} for i in range(12)]
    raw["sections"] = raw["sections"] + [{
        "id": "voices", "heading": "どう受け止められたか", "tier": "未確認",
        "telop": "ネットの反応", "say": voices,
        "sources": ["https://footballnet.example/1"],
    }]
    assert not any("他人の声が" in h for h in advise(build_notes(raw)))


def test_過去形の答えが壊れない():
    """「判断した」が「判断したです」になっていた（2026-09-07、書き出して発見）。"""
    from src.research import _spoken

    assert _spoken("UEFAは重大な暴行と判断した") == "UEFAは重大な暴行と判断した、ということです。"
    assert _spoken("移籍は決まりました") == "移籍は決まりました。"
    assert _spoken("次の焦点は来週") == "次の焦点は来週です。"


def test_同じ声になる2人は取材メモで止まる(monkeypatch):
    """書き出す前に気づけるようにする（2026-09-07）。"""
    from src.config import CastMember
    from src.research import verify

    def same_voice(self, name):
        return CastMember(name=name, key="voiced_42", style_id=42, speed=1.0,
                          pitch=0.0, intonation=1.05, position="none", color="#fff")

    monkeypatch.setattr("src.config.ProjectConfig.resolve_speaker", same_voice)
    raw = _raw()
    raw["sections"] = raw["sections"] + [{
        "id": "voices", "heading": "何と言ったか", "tier": "報道",
        "say": [{"voice": "メッシ", "text": "引退します。"},
                {"voice": "モウリーニョ", "text": "おめでとう。"}],
        "sources": ["https://example.com/1"],
    }]
    problems = verify(build_notes(raw), _plan())
    assert any("同じ声" in p for p in problems)


def test_まとめの答えが長いと知らせる():
    """**書き出してから気づくと、音声から作り直しになる**（2026-09-08 に3回）。

    45字でおよそ12秒。review の「カードの持ち」に当たる長さ。
    """
    from src.research import ANSWER_MAX, Notes, advise

    notes = Notes(date="2026年9月8日", title="題", question="問い",
                  answer="あ" * (ANSWER_MAX + 1))
    assert any("answer が" in w for w in advise(notes))


def test_短い答えなら知らせない():
    from src.research import Notes, advise

    notes = Notes(date="2026年9月8日", title="題", question="問い", answer="短い答え")
    assert not any("answer が" in w for w in advise(notes))


def test_サムネに答えを書いたら知らせる():
    """**タイトルで隠しているのに、サムネで答えていた**（2026-09-08 指摘）。

    参考チャンネルは答えの位置を ●● で伏せている。
    """
    from src.research import Notes, advise

    notes = Notes(date="2026年9月8日", title="題", question="問い",
                  answer="クヴァラツヘリア、ハリー・ケイン、ムバッペの3人です",
                  thumbnail={"line1": "見出し",
                             "points": ["ハリー・ケイン", "1人目 ●●●"]})
    said = [w for w in advise(notes) if "サムネの" in w]
    assert len(said) == 1 and "ハリー・ケイン" in said[0]


def test_伏せ字なら知らせない():
    from src.research import Notes, advise

    notes = Notes(date="2026年9月8日", title="題", question="問い",
                  answer="クヴァラツヘリア、ハリー・ケイン、ムバッペの3人です",
                  thumbnail={"line1": "見出し", "points": ["1人目 ●●●●", "2人目 ●●●"]})
    assert not [w for w in advise(notes) if "サムネの" in w]


# ---- 型（format）2026-09-08 ------------------------------------------------

def _voices_raw():
    """反応の型の取材メモ。問いも答えも無く、事実1節＋反応1節。"""
    raw = _raw()
    raw["format"] = "voices"
    raw["theme"] = {"id": "zion_reaction", "title": "ハル戦の鈴木彩艶を見た現地サポの反応"}
    raw.pop("answer")
    raw["sections"] = [
        _section(id="facts", heading="何があったか", tier="報道", official=False,
                 sources=["https://example.com/1", "https://example.com/2"],
                 say=["ハル戦で無失点でした。"]),
        _section(id="reactions", heading="現地の声", tier="未確認", official=False,
                 sources=["https://example.com/thread"],
                 say=[{"voice": "現地サポ", "text": "本物のGKを手に入れたぞ"},
                      {"voice": "現地サポ", "text": "中盤より前にボールを出せる"},
                      {"voice": "現地サポ", "text": "もう前線で使っちゃえよ"}]),
    ]
    return raw


def test_反応の型は問いと答えが無くても通る():
    assert verify(build_notes(_voices_raw()), _plan()) == []


def test_反応の型に反応の行が無ければ止める():
    raw = _voices_raw()
    raw["sections"][1]["say"] = ["反応を紹介します。"]
    problems = verify(build_notes(raw), _plan())
    assert any("voices" in p for p in problems)


def test_知らない型は止める():
    import pytest

    raw = _raw()
    raw["format"] = "podcast"
    with pytest.raises(ResearchError):
        build_notes(raw)


def test_反応の型の台本にまとめは無い():
    from src.script_model import parse_script

    script = parse_script(to_script(build_notes(_voices_raw()), _plan()))
    assert [s.title for s in script.scenes] == ["オープニング", "何があったか", "現地の声"]
    assert "wrap" not in script.cards
    assert script.meta.get("format") == "voices"
    assert script.meta.get("intro_label") == "みんなの反応"
    # 1行目はタイトルを読む。問いのテロップは出さない
    assert "ハル戦の鈴木彩艶を見た現地サポの反応" in script.lines[0].text
    assert not any("今回の問い" in line.telop_text() for line in script.lines)


def test_ニュースの型は今まで通り問いが要る():
    raw = _raw()
    raw["format"] = "news"
    raw["theme"].pop("question")
    problems = verify(build_notes(raw), _plan())
    assert any("question" in p for p in problems)


def test_つかみが空なら冒頭はタイトルの1行だけ():
    """視聴維持の曲線（2026-09-09 実測）で捨てられるのは4〜9秒だった。

    hook が空のときは question をそのまま読んでいた＝クリックした人が
    もう知っている話の言い直し。その行ごと出さない。
    """
    from src.script_model import parse_script

    raw = _raw()
    raw["theme"] = {**raw["theme"], "hook": ""}
    script = parse_script(to_script(build_notes(raw), _plan()))
    opening = script.scenes[0]
    assert len(opening.lines) == 1
    assert raw["theme"]["title"] in opening.lines[0].text
    assert not any("今回の問い" in line.telop_text() for line in script.lines)


def test_つかみが問いの言い直しなら出さない():
    from src.research import advise
    from src.script_model import parse_script

    raw = _raw()
    raw["theme"] = {**raw["theme"], "hook": "なぜ金の問題ではないのか。"}
    script = parse_script(to_script(build_notes(raw), _plan()))
    assert len(script.scenes[0].lines) == 1
    hints = advise(build_notes(raw), _plan())
    assert any("問いと同じ" in h for h in hints)


def test_つかみが別の一言なら残る():
    from src.script_model import parse_script

    script = parse_script(to_script(build_notes(_raw()), _plan()))   # hook は別の文
    assert len(script.scenes[0].lines) == 2
    # つかみの行は残る。画面に出るのは**その一言**で、問いではない
    assert any("大きな移籍が動いています" in line.telop_text() for line in script.lines)
    assert not any("今回の問い" in line.telop_text() for line in script.lines)


def test_節ごとに地の文の読み手を決められる():
    """2026-09-09 ユーザー「何が起きたかはキャスターが伝えて良い」。

    交互は既定であって決まりではない。節に narrator を書けばその人が読む。
    """
    from src.script_model import parse_script

    raw = _raw()
    raw["sections"][0]["narrator"] = "キャスター"
    raw["sections"][1]["narrator"] = "解説"
    raw["sections"][0]["say"] = ["いちぎょうめ。", "にぎょうめ。", "さんぎょうめ。"]
    raw["sections"][1]["say"] = ["いちぎょうめ。", "にぎょうめ。"]
    script = parse_script(to_script(build_notes(raw), _plan()))
    first, second = script.scenes[1], script.scenes[2]
    assert {l.speaker for l in first.lines} == {"キャスター"}
    assert {l.speaker for l in second.lines} == {"解説"}
    # narrator が無い節は今までどおり交互
    assert len({l.speaker for l in script.scenes[3].lines}) >= 1


def test_サムネの帯と伏せ字が同じなら知らせる():
    """3本とも line2 と points の1つが同じ文だった（2026-09-09 ユーザー指摘）。"""
    from src.research import advise

    raw = _raw(thumbnail={"line1": "短い見出し", "line2": "ベンチにいたのは ●●●●",
                          "points": ["ベンチにいたのは ●●●●", "初先発は9日目"]})
    hints = advise(build_notes(raw))
    assert any("line2 と同じ" in h for h in hints)


def test_サムネに重複が無ければ黙っている():
    from src.research import advise

    raw = _raw(thumbnail={"line1": "短い見出し", "line2": "ベンチにいたのは ●●●●",
                          "points": ["初先発は9日目", "現地紙の採点は ●点"]})
    assert not any("同じ" in h and "サムネ" in h for h in advise(build_notes(raw)))


def test_名前のある人の発言は反応ではない():
    """監督の会見を反応と見て「反応で終わる」の点検が誤って鳴った（2026-09-09）。"""
    raw = _raw()
    raw["sections"] = [
        _section(),
        _section(id="said", heading="監督は何と言ったか", tier="報道", official=False,
                 sources=["https://example.com/1", "https://example.com/2"],
                 say=[{"voice": "ブライトン監督", "text": "辛抱強くならなければならない"},
                      {"voice": "ブライトン監督", "text": "適応しなければならない"}]),
        _section(id="next", heading="これからどうなる", tier="未確認", official=False),
    ]
    assert verify(build_notes(raw), _plan()) == []      # 監督の発言のあとに節が来てよい

    # 匿名の反応のあとなら、今までどおり止まる
    raw["sections"][1] = _section(
        id="net", heading="ネットの声", tier="未確認", official=False,
        say=[{"voice": "ネット民", "text": "まだ序盤やしな"},
             {"voice": "ネット民", "text": "お茶会で干されたか"}])
    assert any("反応の節のあとに" in p for p in verify(build_notes(raw), _plan()))


def test_tableカードにcolumnsが無いと取材メモの段階で止まる():
    """**書き出しまで気づけなかった**（2026-09-09）。

    columns を書き忘れた台本が draft を通り、音声を合成し終えたあとの
    render で落ちた。落ちる条件はカードの側が知っているので、
    取材メモの検証で同じことを見る。
    """
    from src.research import Section, _check_card

    def make(card):
        return Section(id="s", heading="h", tier="報道", telop="t",
                       say=["a"], sources=["https://example.com/1"], card=card)

    assert _check_card(make({"type": "table", "rows": [["1", "2"]]}))
    assert _check_card(make({"type": "table", "columns": ["a", "b"],
                             "rows": [["1"]]}))
    assert _check_card(make({"type": "bars", "title": "x"}))
    assert not _check_card(make({"type": "table", "columns": ["a", "b"],
                                 "rows": [["1", "2"]]}))
    assert not _check_card(make(None))


def test_short_titleが台本に書き出される():
    """**書いても効いていなかった**（2026-09-09）。

    取材メモに short_title を書いても Notes が受け取らず、to_script も
    書き出していなかった。shorts._retitle は台本の front matter を見るので、
    いつも空になり、節のテロップが題名になっていた
    （「試合登録は20人。2人が外れる」という題名のショートが3本並んだ）。
    """
    from src.plan import load_plan
    from src.research import build_notes, to_script

    raw = {
        "date": "2026年9月9日",
        "short_title": "南野拓実、9か月ぶりの招集メンバー",
        "theme": {"id": "t", "title": "南野拓実が戻った日、なぜ出番が無かったのか",
                  "question": "なぜ外れたのか", "topic": "南野拓実",
                  "league": "france", "kind": "other"},
        "thumbnail": {"line1": "a", "line2": "b", "tags": ["南野拓実"],
                      "photo": "assets/photos/x/01.jpg"},
        "sections": [
            {"id": f"s{n}", "heading": f"見出し{n}", "tier": "報道",
             "telop": f"テロップ{n}", "say": ["ひとこと。"],
             "sources": ["https://example.com/1", "https://example.com/2"]}
            for n in range(3)
        ],
    }
    notes = build_notes(raw)
    assert notes.short_title == "南野拓実、9か月ぶりの招集メンバー"
    assert "short_title: 南野拓実、9か月ぶりの招集メンバー" in to_script(notes, load_plan())

    del raw["short_title"]
    assert "short_title:" not in to_script(build_notes(raw), load_plan())


def test_crest_fills_in_when_there_is_no_photo():
    """写真が無い回は、エンブレムをカードと入れ替える絵に使う（2026-09-13）。

    エンブレムを主役にした回は `thumbnail.photo` が無い。カードを消すと
    「カードも写真も無い」画面が続き、実測でアーセナル27秒・
    チェルシー55秒・リヴァプール58秒、同じ絵のままになっていた。
    消さないようにすると、今度は同じカードが33秒出たままになった。
    """
    raw = _raw()
    raw["thumbnail"] = {"line1": "帯", "line2": "●●", "crest_main": ["アーセナル", "チェルシー"]}
    raw["sections"] = [
        {
            "id": f"s{n}", "heading": "見出し", "tier": "背景", "telop": "テロップ",
            "narrator": "キャスター", "official": False, "sources": [],
            "card": {"type": "points", "title": "表", "items": ["あ", "い"]},
            "say": ["1行目です。", "2行目です。", "3行目です。", "4行目です。"],
        }
        for n in (1, 2, 3)
    ]
    text = to_script(build_notes(raw), _plan())
    # **エンブレムは全画面の下地に使わない**（2026-09-14 指摘
    # 「右側が黒くなってる」「ユベントスのロゴか見えない」）。写真用の作りは
    # 同じ写真をぼかして敷くので、背景が透明なエンブレムだと右半分が黒くなる。
    # 写真が無い回は下地を最後まで替えない
    assert "assets/crests" not in text
    # 入れ替える相手が無いので、カードも消さない（意味のない none を出さない）
    assert "card: none" not in text


def test_card_stays_when_there_is_nothing_to_swap_to():
    """写真もエンブレムも無いなら、カードは消さない（2026-09-13）。"""
    raw = _raw()
    raw["thumbnail"] = {"line1": "帯", "line2": "●●", "crest_main": ["実在しないクラブ"]}
    raw["sections"] = [
        {
            "id": f"s{n}", "heading": "見出し", "tier": "背景", "telop": "テロップ",
            "narrator": "キャスター", "official": False, "sources": [],
            "card": {"type": "points", "title": "表", "items": ["あ", "い"]},
            "say": ["1行目です。", "2行目です。", "3行目です。", "4行目です。"],
        }
        for n in (1, 2, 3)
    ]
    text = to_script(build_notes(raw), _plan())
    assert "card: none" not in text


def test_first_line_of_a_section_shows_what_is_said():
    """節の1行目も、読み上げた文を画面に出す（2026-09-13 ユーザー指示「A」）。

    それまでは節のテロップ（見出し）で上書きしていたので、
    **これから言うことが画面に先に出ていた。**アルテタの回の実例:
      読み「この話が出た翌日、アーセナルはサンダーランドと戦いました」
      画面「サンダーランドに2対0」← 結果を先に見せている
    """
    raw = _raw()
    raw["sections"] = [
        {
            "id": f"s{n}", "heading": "見出し", "tier": "背景",
            "telop": "先に言ってしまう見出し",
            "narrator": "キャスター", "official": False, "sources": [],
            "say": ["この話が出た翌日、試合がありました。", "2行目です。"],
        }
        for n in (1, 2, 3)
    ]
    text = to_script(build_notes(raw), _plan())
    assert "telop: この話が出た翌日、試合がありました" in text
    assert "先に言ってしまう見出し" not in text


def test_ショート専用の行がタイトルと重なったら止める():
    """**`_advise_repeats` には穴があった**（2026-09-15 ユーザー指摘）。

    ショート専用の行（`short_only`）は「本編には出ないので前の節と同じで
    当たり前」として**まるごと見ていなかった**。ところがショートでは、
    その行は**タイトルを読む1行目のすぐ下**に来る。遠藤の回で
    「遠藤航が4試合続けて出番なし」が2秒のあいだに二度読まれていた。

    9/14 に「節をまたいで同じことを言わない」を入れたのに、
    **同じ型の重複がユーザーの目で見つかった。比べる相手が違っていた。**
    """
    from src.research import _advise_short_repeats, build_notes

    raw = _raw()
    raw["theme"]["title"] = "遠藤航が4試合続けて出番なし。監督が語った理由とは"
    raw["sections"][1]["say"] = [
        {"short_only": True,
         "text": "遠藤航がリーグ戦で4試合続けて出番なし。登録からも外れています。"},
        "ここから監督の話です。",
    ]
    notes = build_notes(raw)
    got = _advise_short_repeats(notes)
    assert got and "4試合続けて出番なし" in got[0], got


def test_タイトルに無いことだけなら通す():
    """前の節と重なるのは構わない。ショートにその節は出てこない。"""
    from src.research import _advise_short_repeats, build_notes

    raw = _raw()
    raw["theme"]["title"] = "遠藤航が4試合続けて出番なし。監督が語った理由とは"
    raw["sections"][1]["say"] = [
        {"short_only": True,
         "text": "リヴァプールの遠藤航は、チャンピオンズリーグの登録からも外れています。"},
        "ここから監督の話です。",
    ]
    notes = build_notes(raw)
    assert _advise_short_repeats(notes) == []


def test_人名の重なりだけでは鳴らさない():
    """節の中の他の行は、ショートでも離れて読まれる。本編と同じ12字で見る。

    8字で見ていたら「はフェルナンデス」で鳴った（2026-09-15）。
    """
    from src.research import _advise_short_repeats, build_notes

    raw = _raw()
    raw["theme"]["title"] = "フォーデンの一発退場。解説陣の見方が割れた"
    raw["sections"][1]["say"] = [
        {"short_only": True, "text": "先に倒したのはフェルナンデスです。"},
        "キーンは、フェルナンデスが小突いたと指摘しています。",
    ]
    notes = build_notes(raw)
    assert _advise_short_repeats(notes) == []


def test_知らないリーグの鍵で止める():
    """`league: premier` が `premier` というタグになっていた（2026-09-15）。"""
    from src.research import build_notes, verify

    raw = _raw()
    raw["theme"]["league"] = "premier"
    got = verify(build_notes(raw), _plan())
    assert any("premier" in p and "知らない鍵" in p for p in got), got


def test_リーグ名は取材メモで上書きできる():
    """**`england` から「プレミアリーグ」が付いていた**（2026-09-15）。

    松木の回はサウサンプトンもブリストル・シティも2部で、中身と食い違う。
    `league` は集計の鍵なので国の単位までしか持てない。
    """
    from src.research import build_notes

    raw = _raw()
    raw["theme"]["league"] = "england"
    raw["theme"]["league_name"] = "イングランド2部"
    assert build_notes(raw).league_name == "イングランド2部"


def test_行頭の強調はYAMLで落ちると教える(tmp_path):
    """**`- **強調**` は YAML の別名扱いで落ちる**（2026-09-16 に3度踏んだ）。

    素の ScannerError は「expected alphabetic or numeric character」としか
    言わないので、強調のせいだと分からない。行番号を添えて教える。
    """
    from src.research import ResearchError, load_notes

    p = tmp_path / "x.yaml"
    p.write_text("sections:\n  - say:\n      - **4試合**になりました。\n", encoding="utf-8")
    try:
        load_notes(p)
    except ResearchError as err:
        assert "引用符で囲んで" in str(err)
        assert "3 行目" in str(err)
    else:
        raise AssertionError("落ちなかった")


def test_写真の無い回の下地は特定クラブの実写にしない():
    """**既定の下地がヴォルフスブルクのスタジアムだった**（2026-09-17 に発覚）。

    ユーザー指摘「動画の画面の左側がぼやけている」から書き出した1コマを見て
    分かった。`crest_still.png` の中身は実写で、LEDの看板に VFL WOLFSBURG と
    読める。**写真の無い回は全部これ**になるので、ホッフェンハイムの話も
    PSVの話もマンUの話も、同じドイツのスタジアムの前で喋っていた。

    9/17 の午前に台本4本を手で直したのに、**既定値を直さなかったため
    その日のうちに新しい台本3本へ戻ってきた**（マンU・トッテナム・ベンフィカ）。
    手で直すだけでは戻る。
    """
    from src.research import STILL_BACKGROUND

    assert "crest_still" not in STILL_BACKGROUND, "クラブの実写に戻っている"
    assert STILL_BACKGROUND.endswith(".png"), "静止画のはず（動画に差し替わる名前は使わない）"


def test_知らないカードの種類はdraftで止める():
    """**書き出しまで気づけなかった**（2026-09-18）。

    `type: bullets` と書いた取材メモが draft を通り、音声を合成し終えた
    あとの render で「カードの type は … のいずれか」で落ちた。正しくは `points`。
    `_check_card` は「落ちる条件を先に見る」ための関数なのに、
    **中身の欄だけ見て、種類の名前を見ていなかった。**
    """
    from src.cards import CARD_TYPES
    from src.research import Section, _check_card

    def make(card):
        return Section(id="s", heading="h", tier="報道", telop="t",
                       say=["a"], sources=["https://example.com/1"], card=card)

    found = _check_card(make({"type": "bullets", "items": ["a", "b"]}))
    assert found, "知らない type を通している"
    assert "points" in found[0], "近い綴りを教えていない"

    # 正しい種類は素通しする
    for kind in CARD_TYPES:
        card = {"type": kind, "title": "x", "items": ["a"],
                "columns": ["a", "b"], "rows": [["1", "2"]]}
        assert not [p for p in _check_card(make(card)) if "知りません" in p], kind


def test_節が下地を指定したらオープニングも合わせる(tmp_path):
    """**オープニングだけ別の下地だった**（2026-09-18 に踏んだ）。

    久保の回で全節に `bg` を書いたのに、オープニングは既定の実写クリップのままで、
    1つ目の切り替わりで場所が変わって見えた。
    「下地は1本のあいだ変えない」（2026-09-14 指示）に、ここだけ従っていなかった。
    """
    import re

    from src.plan import load_plan
    from src.research import load_notes, to_script

    body = (tmp_path / "n.yaml")
    body.write_text("""format: news
voice_min: 20
date: "2026年9月18日"
theme:
  id: t
  league: spain
  kind: other
  topic: レアル・ソシエダ
  title: 久保建英が3試合続けて外れた理由とは
  hook: ひと言だけ。
  question: なぜか
thumbnail:
  line1: あ
  line2: い
  photo: assets/photos/x/01.jpg
sections:
  - id: a
    heading: 何が起きたか
    tier: 報道
    bg: assets/backgrounds/kubo.png
    telop: て
    narrator: キャスター
    say: [いちばん最初の行です。]
    sources: ["https://example.com/1"]
  - id: b
    heading: どう動いたか
    main: true
    tier: 報道
    bg: assets/backgrounds/kubo.png
    telop: ど
    narrator: 解説
    say: [そのあとに起きたことです。]
    sources: ["https://example.com/2"]
  - id: c
    heading: 見通し
    tier: 背景
    bg: assets/backgrounds/kubo.png
    telop: み
    narrator: キャスター
    say: [これから何があるかです。]
    sources: ["https://example.com/3"]
  - id: voices
    heading: 反応
    tier: 未確認
    bg: assets/backgrounds/kubo.png
    telop: こ
    narrator: キャスター
    say:
      - {voice: ネット民, text: なるほど}
    sources: ["https://example.com/4"]
""", encoding="utf-8")
    text = to_script(load_notes(body), load_plan())
    backgrounds = re.findall(r"^@bg: (.+)$", text, re.M)
    assert backgrounds, "下地の指定が1つも無い"
    assert len(set(backgrounds)) == 1, f"1本の中で下地が変わっている: {set(backgrounds)}"
    assert "kubo.png" in backgrounds[0]


def test_ショート専用の行に節のカードを付けない(tmp_path):
    """**表が本編に一度も出なかった**（2026-09-18 に画面で見つかった）。

    節のカードは1行目に付く。ところが取材メモの雛形は、節の頭に
    `only: short` の状況説明を置くことがある。その行は本編では落ちるので、
    **カードごと消える。**クロップの回で、選手の表が画面に出ていなかった。
    `_is_voices_scene` が `only: short` の語りを数えて壊れたのと同じ型で、
    **あの1行はショート専用なのに、節の1行目として扱われていた。**
    """
    import re

    from src.plan import load_plan
    from src.research import load_notes, to_script

    note = tmp_path / "n.yaml"
    note.write_text("""format: news
voice_min: 20
date: "2026年9月18日"
theme:
  id: t
  league: germany
  kind: other
  topic: ドイツ代表
  title: クロップが呼んだ44人は誰だったのか
  hook: ひと言だけ。
  question: 誰か
thumbnail:
  line1: あ
  line2: い
  photo: assets/photos/x/01.jpg
sections:
  - id: a
    heading: 何が起きたか
    tier: 報道
    telop: て
    narrator: キャスター
    say: [いちばん最初の行です。]
    sources: ["https://example.com/1"]
  - id: who
    heading: 誰が呼ばれたか
    main: true
    tier: 報道
    telop: ひ
    narrator: キャスター
    card:
      type: table
      title: 初招集
      columns: ["所属", "名前", "位置", "年齢"]
      rows:
        - ["フランクフルト", "エブヌタリブ", "FW", "23"]
    say:
      - {short_only: true, text: ショートのための状況説明です。}
      - 本編に残る最初の行です。
    sources: ["https://example.com/2"]
  - id: voices
    heading: 反応
    tier: 未確認
    telop: こ
    narrator: キャスター
    say:
      - {voice: ネット民, text: なるほど}
    sources: ["https://example.com/3"]
""", encoding="utf-8")
    text = to_script(load_notes(note), load_plan())
    block = text.split("## 誰が呼ばれたか")[1].split("\n## ")[0]
    # カードが付いた行の1つ前の読み上げを探す
    holder = None
    for line in block.splitlines():
        if re.match(r"^[^ \t#@].*?: ", line):
            holder = line
        if line.strip() == "card: who_card":
            break
    assert holder and "ショートのための状況説明" not in holder, \
        f"ショート専用の行にカードが付いている: {holder}"
    assert "本編に残る最初の行" in holder


def test_ネットの声が少ない回を知らせる(tmp_path):
    """**件数を数えていなかった**（2026-09-18 に気づいた）。

    「読み上げる反応は10〜20件」と 2026-09-07 に決めてあるのに、
    機械は **1件でもあれば通していた**。サンバの回は6件、
    ヴァツケの回は日本語0件のまま書き出せた。
    **止めない**（記事が1本しか出ていない題材では数が伸びない）。
    気づかずに出ることだけを防ぐ。
    """
    from src.plan import load_plan
    from src.research import advise, load_notes

    def note(count):
        says = "\n".join(f"      - {{voice: ネット民, text: こえ{i}}}" for i in range(count))
        path = tmp_path / f"n{count}.yaml"
        path.write_text(f"""format: news
voice_min: 20
date: "2026年9月18日"
theme:
  id: t
  league: england
  kind: other
  topic: マンチェスター・シティ
  title: マンチェスター・シティの17歳が見せたものとは
  hook: ひと言。
  question: なにか
thumbnail:
  line1: あ
  line2: い
  photo: assets/photos/x/01.jpg
sections:
  - id: a
    heading: 何が起きたか
    tier: 報道
    telop: て
    narrator: キャスター
    say: [いちばん最初の行です。]
    sources: ["https://example.com/1"]
  - id: voices
    heading: 反応
    tier: 未確認
    telop: こ
    narrator: キャスター
    say:
{says}
    sources: ["https://example.com/2"]
""", encoding="utf-8")
        return advise(load_notes(path), load_plan())

    few = [n for n in note(6) if "ネットの声が" in n]
    assert few, "6件でも知らせていない"
    assert "6件" in few[0]

    enough = [n for n in note(12) if "ネットの声が" in n]
    assert not enough, "12件で鳴っている"


def test_1節目がショート専用の行で始まっても落ちない(tmp_path):
    """**`shown_for` を数え始める前に使って落ちた**（2026-09-20、プレミア20クラブで踏んだ）。

    数え始めは「本編に残る最初の行」なので、`only: short` の行はその前に来る。
    前の節があればその値が残っていて表に出ないが、**1節目がショート専用の行で
    始まる台本**（日本人のいないクラブは入口の節が無く、基礎DATAから始まる）で
    UnboundLocalError になった。
    """
    from src.plan import load_plan
    from src.research import load_notes, to_script

    note = tmp_path / "n.yaml"
    note.write_text("""format: news
voice_min: 0
date: "2026年9月20日"
theme:
  id: t
  league: england
  kind: other
  topic: アーセナル
  title: アーセナルってどんなクラブ？
  hook: ひと言だけ。
  question: どんなクラブか
thumbnail:
  line1: あ
  line2: い
  photo: assets/photos/x/01.jpg
sections:
  - id: data
    heading: 基礎DATA
    main: true
    tier: 背景
    telop: て
    narrator: 解説
    say:
      - {short_only: true, text: このクラブの、基本のデータです。}
      - 創立は1886年です。
      - 本拠地はエミレーツ・スタジアムです。
    sources: ["https://example.com/1"]
  - id: rival
    heading: 宿敵
    tier: 背景
    telop: と
    narrator: 解説
    say: [宿敵はトッテナムです。]
    sources: ["https://example.com/2"]
  - id: season
    heading: 今季
    tier: 報道
    telop: き
    narrator: 解説
    say: [5試合で4勝です。]
    sources: ["https://example.com/3"]
""", encoding="utf-8")
    text = to_script(load_notes(note), load_plan())
    assert "創立は1886年です。" in text


def test_一言はタイトルより前に読む():
    """**2026-09-21 指示**「最初にクラブを表す一言を述べてから始める」。

    「1行目はタイトル」の決まり（2026-09-07）は残すので、**一言 → タイトル**の順。
    """
    raw = _raw()
    raw["theme"]["lead"] = "プレミアで一番小さなスタジアムのクラブです。"
    text = to_script(build_notes(raw), _plan())
    lines = [x for x in text.splitlines() if x.startswith("キャスター: ")]
    assert lines[0] == "キャスター: プレミアで一番小さなスタジアムのクラブです。"
    assert lines[1] == "キャスター: なぜ移籍が決まらないのか。"


def test_一言を書いていなければタイトルから始まる():
    """書いていない回は、今までどおりタイトルが1行目。**既定を変えない**。"""
    text = to_script(build_notes(_raw()), _plan())
    lines = [x for x in text.splitlines() if x.startswith("キャスター: ")]
    assert lines[0] == "キャスター: なぜ移籍が決まらないのか。"


def test_一言がタイトルの言い直しなら出さない():
    """タイトルと同じことを言う一言は、前置きが増えるだけ。**その行ごと出さない**。"""
    raw = _raw()
    raw["theme"]["lead"] = "なぜ移籍が決まらないのか"
    text = to_script(build_notes(raw), _plan())
    lines = [x for x in text.splitlines() if x.startswith("キャスター: ")]
    assert lines[0] == "キャスター: なぜ移籍が決まらないのか。"
    assert len([x for x in lines if "移籍が決まらないのか" in x]) == 1


def _raw_kanji():
    raw = _raw()
    raw["sections"][0]["say"] = "移籍が決まりました。"
    return raw


def test_サムネが本編で言っていないことを約束していたら知らせる():
    """**2026-09-21 に4本見つかった。**旧台本から節を落としたのに、サムネの文字だけ
    残っていて、その話を一度もしない動画になっていた（アーセナル「1919年、票で決まった」）。
    """
    from src.research import _advise_thumbnail_promise

    raw = _raw_kanji()
    raw["thumbnail"] = {"line1": "酒場の投票で決まった", "line2": "ブレントフォード"}
    hints = _advise_thumbnail_promise(build_notes(raw))
    assert any("line1" in h for h in hints), hints


def test_読み上げに出てくるサムネは知らせない():
    """言い回しは変わるので、**手がかりが1つでも出てくれば通す**。"""
    from src.research import _advise_thumbnail_promise

    raw = _raw_kanji()
    raw["thumbnail"] = {"line1": "移籍のゆくえ", "line2": "なぞ"}
    assert _advise_thumbnail_promise(build_notes(raw)) == []


def test_伏せ字のサムネは見ない():
    """`●●` は隠すのが目的なので、読み上げに無くて当たり前。"""
    from src.research import _advise_thumbnail_promise

    raw = _raw_kanji()
    raw["thumbnail"] = {"line1": "本人が望むのは ●●", "line2": "移籍"}
    assert _advise_thumbnail_promise(build_notes(raw)) == []


def test_サムネの数字は丸ごと一致で見る():
    """**2桁ずつで見ると通ってしまう**（2026-09-21 実測）。サムネ「1919年」が、
    読み上げの「2026年5月19日」の "19" に当たって鳴らなくなった。
    """
    from src.research import _advise_thumbnail_promise

    raw = _raw_kanji()
    raw["sections"][0]["say"] = "移籍は2026年5月19日に決まりました。"
    raw["thumbnail"] = {"line1": "1919年に決まった", "line2": "移籍"}
    assert _advise_thumbnail_promise(build_notes(raw)), "1919 が 19 で通ってしまう"


def test_言い回しが変わっていても通す():
    """サムネ「6回優勝が、3部にいた」に対して読み上げは「1部で6回も優勝している」。
    **丸ごとでは当たらないが、同じ話をしている**ので鳴らせない。
    """
    from src.research import _advise_thumbnail_promise

    raw = _raw_kanji()
    raw["sections"][0]["say"] = "1部で6回も優勝しているクラブが3部にいました。"
    raw["thumbnail"] = {"line1": "6回優勝が、3部にいた", "line2": "移籍"}
    assert _advise_thumbnail_promise(build_notes(raw)) == []


def test_棒グラフの項目は形まで見る():
    """**2026-09-22 に2本が書き出しの途中で落ちた。**`- ["佐野海舟", 5000]` と書いても
    `draft` は「items がある」で通していた。形の誤りは書き出す前に止める。"""
    from src.research import verify

    raw = _raw()
    raw["sections"][0]["card"] = {"type": "bars", "title": "t", "items": [["佐野海舟", 5000]]}
    problems = verify(build_notes(raw), _plan())
    assert any("label" in p for p in problems), problems

    raw["sections"][0]["card"]["items"] = [{"label": "佐野海舟", "value": 5000}]
    assert not any("bars" in p for p in verify(build_notes(raw), _plan()))


def test_行の知らない鍵は止める(tmp_path):
    """2026-09-22: `short_only: true` を `only: short` と書き、前置きが本編にも入った。"""
    import pytest
    from src.research import ResearchError, load_notes

    note = tmp_path / "n.yaml"
    note.write_text(
        "theme:\n  title: 題\nsections:\n  - id: a\n    heading: 見出し\n    say:\n"
        "      - text: 前置き\n        only: short\n      - 本文\n",
        encoding="utf-8")
    with pytest.raises(ResearchError, match="知らない鍵"):
        load_notes(note)


def test_main以外の節のshort_onlyは止める(tmp_path):
    """2026-09-22: 前置きを「何が起きたか」に置き、7本のショートに一度も出なかった。"""
    import pytest
    from src.research import ResearchError, load_notes

    note = tmp_path / "n.yaml"
    note.write_text(
        "theme:\n  title: 題\nsections:\n  - id: a\n    heading: 見出し\n    say:\n"
        "      - text: 前置き\n        short_only: true\n      - 本文\n"
        "  - id: b\n    main: true\n    heading: 山場\n    say:\n      - 山場の本文\n",
        encoding="utf-8")
    with pytest.raises(ResearchError, match="main でない節"):
        load_notes(note)


def test_群れの回はサムネも並べる():
    """2026-09-22: 日本代表の市場価値の回で、佐野1人の写真を出していた。"""
    from src.research import _advise_group_thumbnail, build_notes

    raw = _raw()
    raw["people"] = ["佐野海舟", "鈴木彩艶", "上田綺世"]
    raw["theme"]["title"] = "日本代表の値段が一斉に更新。値上がりしたのは誰か"
    raw["thumbnail"] = {"photo": "a.jpg", "line1": "x", "line2": "y"}
    assert _advise_group_thumbnail(build_notes(raw))
    raw["thumbnail"]["photos"] = ["a.jpg", "b.jpg", "c.jpg"]
    assert _advise_group_thumbnail(build_notes(raw)) == []
    raw["thumbnail"].pop("photos")
    raw["theme"]["title"] = "佐野海舟の値段が上がった"
    assert _advise_group_thumbnail(build_notes(raw)) == []
