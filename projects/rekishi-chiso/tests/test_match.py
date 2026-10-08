"""話と画面の一致（10-08 ユーザー指摘「会話している内容と画面の内容が合ってない」）。"""
from chiso import check, match, script

PLACES = {"京都": (135.77, 35.01), "堺": (135.48, 34.57), "江戸": (139.77, 35.68)}
CATALOG = {
    "rakuchu.jpg": ("洛中洛外図屏風（上杉本）右隻。金雲の間に京の町", "信長上洛時の京都・町衆の都"),
    "honnoji.jpg": ("炎の本能寺で弓を引く信長", "本能寺の変・最期"),
    "nagashino.jpg": ("長篠合戦図屏風。馬防柵・鉄砲隊", "長篠の戦い全体"),
    "kameyama.jpg": ("丹波国亀山城絵図。城と城下町の平面図", "亀山城からの出陣（本能寺へ向かう出発点）"),
}


def _sc(sections, timeline=(1530, 1590), **top):
    data = {"title": "t", "timeline": {"start": timeline[0], "end": timeline[1]}, "sections": sections, **top}
    return script.parse(data, places=PLACES)


def _rows(sc):
    return [i + 1 for i, _ in match.line_notes(sc, CATALOG, list(PLACES))]


def test_honnoji_talk_over_kyoto_town_screen_is_flagged_with_following_lines():
    # 見本の1〜3行目：「京都の本能寺」と話すあいだ、京都の町の屏風が出ていた
    sc = _sc([{"title": "1582年 天下人・織田信長", "background": {"image": "p/rakuchu.jpg", "credit": "洛中洛外図屏風"},
               "lines": [{"語り": "1582年6月、京都の本能寺。信長は百人ほどの供と泊まっていました。"},
                         {"聞き": "供が百人だけ？"},
                         {"語り": "今日は、その信長を掘っていきます。"}]}])
    assert _rows(sc) == [1, 2, 3]
    note = match.notes(sc, CATALOG, list(PLACES))
    assert len(note) == 1 and note[0].startswith("話と画面：1〜3行目") and "本能寺" in note[0]


def test_same_talk_over_honnoji_picture_passes():
    sc = _sc([{"title": "1582年 本能寺の変", "background": {"image": "p/honnoji.jpg", "credit": "大日本名将鑑"},
               "lines": [{"語り": "1582年6月、京都の本能寺。信長は百人ほどの供と泊まっていました。"}]}])
    assert _rows(sc) == []


def test_other_place_inside_a_battle_section_is_flagged():
    # 見本の30〜32行目：節の題も背景も長篠のまま、「上洛した1568年、堺に矢銭」
    sc = _sc([{"title": "1575年 長篠の戦い", "background": {"image": "p/nagashino.jpg", "credit": "長篠合戦図屏風"},
               "lines": [{"語り": "1575年、三河の長篠で、武田の軍とぶつかります。"},
                         {"語り": "ちなみに上洛した1568年、信長は堺に矢銭を求めています。",
                          "figure": {"type": "calc", "title": "堺に求めた矢銭", "terms": [["2万貫", "1568年"], ["約20億円"]], "ops": ["＝"]}},
                         {"聞き": "20億円！？", "figure": {"type": "calc", "title": "堺に求めた矢銭", "terms": [["2万貫", "1568年"], ["約20億円"]], "ops": ["＝"]}}]}])
    assert _rows(sc) == [2, 3]                  # 図に「堺」があっても、背景が別の出来事（長篠）の絵なら知らせる


def test_hook_that_jumps_to_the_next_event_is_flagged():
    sc = _sc([{"title": "1575年 長篠の戦い", "background": {"image": "p/nagashino.jpg"},
               "lines": [{"語り": "7年後の1582年、信長は京都の本能寺に泊まります。", "hook": True}]}])
    assert _rows(sc) == [1]


def test_passing_mentions_without_a_year_are_not_flagged():
    # 年を言わずに触れるだけ（話のついで）は数えない。既存7本ではこれが大半だった
    sc = _sc([{"title": "1575年 長篠の戦い", "background": {"image": "p/nagashino.jpg"},
               "lines": [{"語り": "のちに本能寺で信長を討つ明智光秀も、この戦いにいました。"},
                         {"語り": "3000挺の話は、桶狭間の奇襲と同じ本が出どころです。"}]}])
    assert _rows(sc) == []


def test_year_far_from_the_section_title_is_flagged_but_later_research_years_are_not():
    sc = _sc([{"title": "1534年 尾張の若殿", "lines": [
        {"語り": "1551年ごろ、父の葬儀で、抹香を投げつけました。"},       # 節の題と17年ちがう
        {"語り": "1540年ごろには、もう城を任されていたと言われます。"},     # 6年：近い
        {"語り": "2014年の研究では、この話も見直されています。"}]}])       # 年表の外＝後の時代の話
    assert _rows(sc) == [1]


def test_stale_card_year_is_flagged():
    sc = _sc([{"title": "日本だけではなかった", "lines": [
        {"語り": "明は1371年に海禁を出します。", "card": {"head": "1371年", "body": "明の海禁"}},
        {"語り": "清も1655年に海禁を出しています。"}]}], timeline=(1300, 1900))
    assert _rows(sc) == [2]


def test_summary_section_and_teaser_are_not_checked():
    sc = _sc([{"title": "1560年 桶狭間", "background": {"image": "p/rakuchu.jpg"}, "lines": [{"語り": "桶狭間の話です。"}]},
              {"title": "まとめ：信長とは", "background": {"image": "p/honnoji.jpg"},
               "lines": [{"語り": "1560年の桶狭間から1582年の本能寺まで、22年でした。"},
                         {"聞き": "次回は江戸の鎖国。"}]}])
    assert _rows(sc) == []


def test_catalog_fits_column_gives_places_but_not_events():
    # 「合う場面」は使い道の案（亀山城の絵に「本能寺へ向かう出発点」）。出来事は「何か」からだけ拾う
    sc = _sc([{"title": "丹波の5年", "background": {"image": "p/kameyama.jpg"},
               "lines": [{"語り": "1575年、光秀は丹波攻めを命じられます。今の京都府の中部です。"}]}])
    assert _rows(sc) == []


def test_teaser_line_gets_no_place_map():
    sc = _sc([{"title": "まとめ：信長とは", "lines": [
        {"語り": "今日の地層は、ここまでです。"},
        {"聞き": "次回は江戸の鎖国。日本って、ほんとに国を閉じてたの？"},
        {"語り": "江戸の町では、どうだったのでしょう。"}]}])
    assert sc.lines[1].place is None
    assert sc.lines[2].place and sc.lines[2].place[0] == "江戸"   # 予告でない行は今までどおり地図が付く


def test_load_catalog_reads_columns_by_header(tmp_path):
    (tmp_path / "x_assets.md").write_text(
        "| ファイル名 | 何か | 年 | 作者 | 台本で合う場面 | Commons |\n|---|---|---|---|---|---|\n"
        "| x_honnoji.jpg | 炎の本能寺 | 1878 | 芳年 | 本能寺の変・最期 | url |\n", encoding="utf-8")
    cat = match.load_catalog(tmp_path)
    assert cat == {"x_honnoji.jpg": ("炎の本能寺", "本能寺の変・最期")}
    assert match.load_catalog(tmp_path / "none") == {}


def test_report_puts_mismatch_in_the_fix_group():
    rows = check.report([], ["話と画面：1〜3行目 「1582年・本能寺」と話すあいだ、画面は「京都」（出来事が違う）"])
    assert rows[0].startswith("! 話と画面：")


def test_showcase_has_no_mismatch():
    # 見本は話と画面を合わせて作り直した（10-08）。CI には絵の一覧が無いので、台本の文字（節の題・出典・名札）だけで照らす
    from pathlib import Path
    sc = script.load(Path(__file__).resolve().parent.parent / "scripts" / "_showcase.yaml")
    assert match.notes(sc, {}) == []
