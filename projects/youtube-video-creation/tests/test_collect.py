import pytest

from src import collect
from src.collect import Hit, enrich, parse, slug, to_yaml
from src.freshness import read


def test_a_title_and_url_on_one_line():
    (hit,) = parse("見出しです\thttps://example.com/a")
    assert hit.title == "見出しです"
    assert hit.url == "https://example.com/a"


def test_a_title_on_the_line_before_the_url():
    (hit,) = parse("見出しです\n  https://example.com/a")
    assert hit.title == "見出しです"


def test_a_url_on_its_own_leaves_the_title_empty():
    (hit,) = parse("https://example.com/a")
    assert hit.title == ""


def test_list_markers_and_trailing_punctuation_are_stripped():
    (hit,) = parse("- 見出し（https://example.com/a）")
    assert hit.url == "https://example.com/a"
    assert "-" not in hit.title[:1]


def test_several_results_are_kept_in_order():
    hits = parse(
        "一件目\thttps://example.com/1\n"
        "二件目\thttps://example.com/2\n"
        "https://example.com/3\n"
    )
    assert [h.url[-1] for h in hits] == ["1", "2", "3"]
    assert hits[2].title == ""


def test_text_without_a_url_yields_nothing():
    assert parse("ただの文章です\nURLはありません") == []


def test_the_url_fills_in_the_site_and_date():
    hits = enrich(parse("見出し\thttps://www.footballchannel.jp/2026/08/29/post1000500/"), read)
    assert hits[0].site == "footballchannel.jp"
    assert hits[0].posted_on == "2026-08-29"


def test_sky_match_report_urls_are_recognised():
    hits = enrich(
        parse("Spurs 0-2\thttps://www.skysports.com/football/spurs-vs-newcastle/report/559463"),
        read,
    )
    assert hits[0].site == "skysports.com"
    assert hits[0].number == 559463


def test_ids_skip_numbers_and_generic_path_words():
    body = to_yaml(
        [Hit(title="Spurs 0-2", url="https://www.skysports.com/football/spurs-vs-newcastle/report/559463")],
        "2026年8月30日",
    )
    # 「report」も「559463」も中身を表さない
    assert "id: spurs_vs_newcastle" in body


def test_ids_fall_back_to_the_headline():
    body = to_yaml([Hit(title="Emiliano Martinez signs", url="https://example.com/1/2/3")], "d")
    assert "id: emiliano_martinez_signs" in body


def test_slugs_drop_pure_numbers():
    assert slug("559463") == ""
    assert slug("emiliano-martinez-signs-for-chelsea") == "emiliano_martinez_signs"


def test_the_draft_leaves_the_judgement_fields_empty():
    body = to_yaml([Hit(title="見出し", url="https://example.com/a")], "2026年8月30日")
    assert 'topic: ""' in body
    assert 'league: ""' in body
    assert "tier: " in body              # 見出しからの当たりが入る
    assert "見て直す" in body or "判断できず" in body


def test_a_missing_headline_is_left_as_a_blank_to_fill():
    body = to_yaml([Hit(title="", url="https://example.com/a")], "d")
    assert "見出しを書く" in body


def test_quotes_in_a_headline_do_not_break_the_file():
    import yaml

    body = to_yaml([Hit(title='彼は "残る" と語った', url="https://example.com/a")], "d")
    assert yaml.safe_load(body)["candidates"][0]["title"] == "彼は '残る' と語った"


def test_a_readable_date_is_noted_as_a_comment():
    body = to_yaml(
        [Hit(title="見出し", url="https://x.example/a", posted_on="2026-08-29")], "d"
    )
    assert "公開日: 2026-08-29" in body


def test_the_same_story_from_two_outlets_becomes_one_candidate():
    from src.collect import group

    hits = [
        Hit("Spurs 0-2 Newcastle: Tottenham suffer second defeat",
            "https://www.skysports.com/football/tottenham-hotspur-vs-newcastle-united/report/559463"),
        Hit("Tottenham suffer back-to-back defeats after Newcastle inflict 2-0 loss",
            "https://www.espn.com/soccer/story/_/id/49764441/spurs-vs-newcastle-premier-league-result"),
        Hit("Emiliano Martinez signs for Chelsea!",
            "https://www.chelseafc.com/en/news/article/emiliano-martinez-signs-for-chelsea"),
    ]
    bunches = group(hits)
    assert [len(b) for b in bunches] == [2, 1]


def test_unrelated_stories_stay_apart():
    from src.collect import group

    hits = [
        Hit("Arsenal sign Julian Alvarez", "https://x.example/arsenal-julian-alvarez"),
        Hit("Bayern beat Dortmund", "https://x.example/bayern-dortmund-result"),
    ]
    assert len(group(hits)) == 2


def test_merged_sources_land_in_the_candidate():
    hits = [
        Hit("Chelsea sign Emi Martinez", "https://a.example/chelsea-emi-martinez"),
        Hit("Emi Martinez joins Chelsea", "https://b.example/emi-martinez-chelsea-joins"),
    ]
    body = to_yaml(hits, "d")
    assert body.count("- id:") == 1
    assert "https://a.example" in body and "https://b.example" in body
    assert "同じ話を 2媒体" in body


def test_merging_can_be_switched_off():
    hits = [
        Hit("Chelsea sign Emi Martinez", "https://a.example/chelsea-emi-martinez"),
        Hit("Emi Martinez joins Chelsea", "https://b.example/emi-martinez-chelsea-joins"),
    ]
    assert to_yaml(hits, "d", merge=False).count("- id:") == 2


def test_english_keywords_come_from_the_url_slug():
    from src.collect import english_words

    assert english_words(
        "https://www.chelseafc.com/en/news/article/emiliano-martinez-signs-for-chelsea"
    ) == "Emiliano Martinez Chelsea"
    assert english_words(
        "https://www.skysports.com/football/tottenham-hotspur-vs-newcastle-united/report/559463"
    ) == "Tottenham Hotspur Newcastle United"


def test_no_english_keywords_from_a_japanese_url():
    from src.collect import english_words

    # 作れないときは空を返す。当てにならない語を入れるより手で書くほうが早い
    assert english_words("https://www.footballchannel.jp/2026/08/29/post1000500/") == ""


def test_generic_words_are_not_used_as_keywords():
    from src.collect import english_words

    keywords = english_words(
        "https://www.skysports.com/football/news/1/2/julian-alvarez-transfer-news-latest-update"
    )
    assert "Transfer" not in keywords and "News" not in keywords
    assert keywords.startswith("Julian Alvarez")


def test_official_wording_reads_as_confirmed():
    from src.collect import guess_tier

    for title in (
        "Emiliano Martinez signs for Chelsea! | Official Site",
        "Chelsea complete signing of Emi Martinez",
        "アトレティコが公式発表！移籍交渉を拒否",
        "浦和が完全移籍加入を発表",
    ):
        assert guess_tier(title) == "確定", title


def test_reporting_wording_reads_as_reported():
    from src.collect import guess_tier

    for title in (
        "Arsenal ready if Julian Alvarez transfer door opens - sources",
        "Spurs and Everton in talks over separate deals",
        "デゼルビ監督が語った",
    ):
        assert guess_tier(title) == "報道", title


def test_rumour_wording_reads_as_unconfirmed():
    from src.collect import guess_tier

    for title in (
        "Liverpool transfer news: Reds continue talks - Paper Talk",
        "Arsenal linked with Julian Alvarez",
        "佐野海舟にリバプールが関心",
    ):
        assert guess_tier(title) == "未確認", title


def test_a_scoreline_reads_as_confirmed():
    from src.collect import guess_tier

    # 点数は事実。試合結果は確定でよい
    assert guess_tier("Spurs 0-2 Newcastle: Tottenham suffer second defeat") == "確定"
    assert guess_tier("Chelsea 3-1 Arsenal (Aug 30, 2026) Game Analysis") == "確定"


def test_a_question_reads_as_unconfirmed():
    from src.collect import guess_tier

    # 疑問形は観測・分析。事実の報道ではない
    assert guess_tier("Does booing increase his chances of a move?") == "未確認"
    assert guess_tier("Why Tottenham cannot score") == "未確認"


def test_an_unreadable_headline_gives_nothing():
    from src.collect import guess_tier

    assert guess_tier("Tottenham Hotspur") == ""
    assert guess_tier("") == ""


def test_the_guess_lands_in_the_draft():
    body = to_yaml([Hit("Emiliano Martinez signs for Chelsea!", "https://a.example/x-y")], "d")
    assert "tier: 確定" in body
    assert "見て直す" in body


def test_an_unguessable_headline_says_so_in_the_draft():
    body = to_yaml([Hit("Tottenham Hotspur", "https://a.example/x-y")], "d")
    assert "tier: 報道" in body
    assert "判断できず" in body


# 見出しの言い回しだけで確度を当てると、噂まとめの「Official: ...」が『確定』になる。
# その群では置けない確度なので、書いた瞬間に lint が × を出す。
# 実測で、拾った56件のうち5件がこれだった。


def _plan_with_tiers():
    from src.plan import build_plan

    return build_plan({
        "tiers": {"確定": {}, "報道": {}, "未確認": {}},
        "domains": {
            "official": ["arsenal.com"],
            "english": ["skysports.com"],
            "rumour": ["caughtoffside.com"],
        },
        "domain_tiers": {"official": "確定", "english": "報道", "rumour": "未確認"},
        "routines": {"morning": {"name": "朝", "steps": [
            {"id": "a", "what": "a", "tier": "確定", "queries": []}]}},
    })


def _tier_of(line: str) -> str:
    return line.split("tier:")[1].split("#")[0].strip()


def _yaml_for(title, url, plan=None):
    hit = collect.Hit(title=title, url=url)
    return collect.to_yaml([hit], "8月31日", plan=plan)


def test_噂まとめの公式発表風の見出しは未確認で止まる():
    body = _yaml_for("Official: £22m deal completed",
                     "https://caughtoffside.com/a", _plan_with_tiers())
    line = [l for l in body.splitlines() if "tier:" in l][0]
    assert _tier_of(line) == "未確認"
    assert "この情報源では未確認まで" in line


def test_上限の内側なら当たりのまま残す():
    body = _yaml_for("Official: Arsenal confirm signing",
                     "https://arsenal.com/news/1", _plan_with_tiers())
    assert _tier_of([l for l in body.splitlines() if "tier:" in l][0]) == "確定"


def test_見出しから判断できないものも上限は超えない():
    body = _yaml_for("Scottish Premiership round-up",
                     "https://caughtoffside.com/b", _plan_with_tiers())
    assert _tier_of([l for l in body.splitlines() if "tier:" in l][0]) == "未確認"


def test_網の外のサイトは当たりのまま():
    """上限が分からないものを、分かったことにしない。"""
    body = _yaml_for("Official: deal completed",
                     "https://example.com/a", _plan_with_tiers())
    assert _tier_of([l for l in body.splitlines() if "tier:" in l][0]) == "確定"


def test_planを渡さなければ今までどおり():
    body = _yaml_for("Official: deal completed", "https://caughtoffside.com/a")
    assert _tier_of([l for l in body.splitlines() if "tier:" in l][0]) == "確定"


# id が重なると、後から出てきたほうが既出として弾かれる。
# 実測で、1回の収集で拾った56件のうち18件がこれで落ちていた。


def test_kickerの記事が全部同じidにならない():
    """kicker は全記事が `/artikel#omrss` で終わる。12件が同じ id になっていた。"""
    hits = [
        Hit(title="Puertas Doppel-Wechsel", url="https://www.kicker.de/puertas-doppel-wechsel-1248504/artikel#omrss"),
        Hit(title="Benzema loest Vertrag auf", url="https://www.kicker.de/benzema-loest-vertrag-auf-1248330/artikel#omrss"),
    ]
    keys = [l.split("id:")[1].strip() for l in collect.to_yaml(hits, "8月31日", merge=False).splitlines() if "- id:" in l]
    assert len(set(keys)) == 2
    assert keys[0].startswith("puertas")
    assert keys[1].startswith("benzema")


def test_どうしても重なるときは番号で分ける():
    """同じ書き出しの記事は、URLが違っても最初の3語が同じになる。"""
    hits = [
        Hit(title="Arsenal latest", url="https://www.skysports.com/football/live-blog/1/2/arsenal-transfer-news-live"),
        Hit(title="Papers: Arsenal", url="https://www.skysports.com/football/news/1/3/arsenal-transfer-news-rashford"),
    ]
    keys = [l.split("id:")[1].strip() for l in collect.to_yaml(hits, "8月31日", merge=False).splitlines() if "- id:" in l]
    assert keys == ["arsenal_transfer_news", "arsenal_transfer_news_2"]


def test_リーグ別の棚はidにしない():
    """サッカーキングの /world/eng/ は棚であって記事の識別ではない。"""
    hits = [
        Hit(title="ニューカッスルがパルド獲得へ", url="https://www.soccer-king.jp/news/world/eng/20260831/2199302.html"),
        Hit(title="高井幸大がレンタル移籍か", url="https://www.soccer-king.jp/news/world/eng/20260831/2199304.html"),
    ]
    keys = [l.split("id:")[1].strip() for l in collect.to_yaml(hits, "8月31日", merge=False).splitlines() if "- id:" in l]
    assert "eng" not in keys
    assert len(set(keys)) == 2


# URL からの検索語に、ホスト名とフラグメントが混ざっていた。
# kicker の `.../artikel#omrss` から "Omrss Transferticker Www Kicker" ができ、
# 貼っても何も返らない検索語になっていた（実測）。


def test_検索語にフラグメントを混ぜない():
    from src.collect import english_words

    assert "Omrss" not in english_words(
        "https://www.kicker.de/bvb-durchbruch-bei-nwaneri-1248510/artikel#omrss"
    )


def test_検索語にホスト名を混ぜない():
    from src.collect import english_words

    words = english_words("https://www.kicker.de/transferticker-953155/artikel#omrss")
    assert "Kicker" not in words
    assert "Www" not in words


def test_記事のスラッグからは今までどおり作る():
    from src.collect import english_words

    assert english_words(
        "https://www.kicker.de/bvb-durchbruch-bei-nwaneri-1248510/artikel#omrss"
    ) == "Bvb Durchbruch Bei Nwaneri"


def test_スラッグが無いURLは当てずに空を返す():
    """記事名の入っていないURLから無理に語を作ると、検索が空振りする。"""
    from src.collect import english_words

    assert english_words("https://www.kicker.de/transferticker-953155/artikel#omrss") == ""


# gather が全件 kind: transfer と決め打ちしていたので、フィードに試合結果が
# 流れてきても「移籍」として書き出されていた。実測で1日88件すべて transfer に
# なり、stats の「試合結果 一度も扱っていない」が永久に消えない状態だった。


def test_スコアが入っていれば試合結果と見る():
    from src.collect import guess_kind

    assert guess_kind("Chelsea 4-3 Brighton") == "match"
    assert guess_kind("Elversberg 3 - 2 Leverkusen") == "match"
    assert guess_kind("Arsenal sign Nwaneri from loan") == "transfer"


def test_金額をスコアと取り違えない():
    from src.collect import guess_kind

    assert guess_kind("Official: £22m deal completed") == "transfer"
    assert guess_kind("€14m package plus 20% sell-on clause") == "transfer"


def test_スコアが無くても試合の話は拾う():
    from src.collect import guess_kind

    assert guess_kind("鈴木彩艶のプレミアデビュー戦ハイライト") == "match"
    assert guess_kind("Man Utd player ratings") == "match"


def test_取得元で分かっているリーグを辞書の推定で上書きしない():
    from src import collect

    hit = collect.Hit(title="FC Utrecht 1 - 6 PSV（Eredivisie）",
                      url="https://example.com/a", league="netherlands", kind="match")
    body = collect.to_yaml([hit], "8月30日", merge=False)
    assert "league: netherlands" in body
    assert "kind: match" in body


def test_取得元で決まったフラグを候補に書く():
    from src import collect

    hit = collect.Hit(title="Man United 5 - 2 Ipswich", url="https://example.com/a",
                      league="england", kind="match",
                      flags={"goals": True, "numbers": True})
    body = collect.to_yaml([hit], "8月30日", merge=False)
    assert "goals: true" in body
    assert "numbers: true" in body
    assert "upset:" not in body       # 立っていないものは書かない
