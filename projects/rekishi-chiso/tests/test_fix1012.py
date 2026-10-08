"""10-09 点検（qc_1012）で見つかった画面の不具合の直し。"""
from chiso import match, script

PL = {"江戸": (139.77, 35.68), "北京": (116.4, 39.9), "堺": (135.48, 34.57), "小田原": (139.15, 35.25),
      "奈良": (135.8, 34.68), "京都": (135.77, 35.01)}


def _places(lines, **sec):
    d = {"title": "t", "timeline": {"start": 1500, "end": 2100},
         "sections": [{"title": "一", "lines": lines, **sec}]}
    sc = script.parse(d, places=PL)
    return [l.place[0] if l.place else None for l in sc.lines]


# --- 1. 場所の小さな地図の誤反応 -------------------------------------------------
def test_edo_as_an_era_is_not_a_place():
    for said in ("だから江戸の浮世絵にも、船団が描かれてる。", "江戸の軍記から今の小説まで。", "江戸の読み物で形になった。",
                 "江戸時代の本です。", "江戸の初めに書かれた。", "江戸の人たちは知っていた。", "儒学を重んじた江戸では暴君に。"):
        assert _places([{"語り": said}]) == [None], said


def test_edo_as_a_place_is_picked():
    for said in ("江戸城の松之大廊下で。", "使いが江戸へやって来ます。", "1641年、江戸で生まれました。", "江戸の町に火が出た。",
                 "江戸の屋敷に入る。", "江戸湾に船が来た。", "江戸に潜む。", "江戸から京都まで。"):
        assert _places([{"語り": said}]) == ["江戸"], said


def test_university_and_person_names_are_not_places():
    assert _places([{"語り": "2009年に北京大学が受け入れた竹簡。"}]) == [None]
    assert _places([{"語り": "1985年の、堺屋太一の小説です。"}]) == [None]
    assert _places([{"語り": "京都大の研究です。"}]) == [None]
    assert _places([{"語り": "北京に戻ります。"}]) == ["北京"]
    assert _places([{"語り": "堺の商人たち。"}]) == ["堺"]
    assert _places([{"語り": "江戸屋敷で。"}]) == ["江戸"]            # 屋敷は場所


def test_place_blank_keeps_length():
    t = "北京大学と堺屋太一と江戸の本と江戸城"
    out = script.place_blank(t, PL)
    assert len(out) == len(t) and "北京" not in out and "堺" not in out and out.endswith("江戸城")


def test_match_uses_the_same_place_rules():
    # 点検（話と画面）でも「堺屋太一」「江戸の読み物」は場所として数えない
    d = {"title": "t", "timeline": {"start": 1500, "end": 2100}, "sections": [
        {"title": "京都の町", "background": {"image": "p/x.jpg", "credit": "京都の町"},
         "lines": [{"語り": "1600年の、堺屋太一の話です。"}, {"語り": "1600年、江戸の読み物になりました。"},
                   {"語り": "1600年、堺に来ました。"}]}]}
    sc = script.parse(d, places=PL)
    why = dict(match.line_notes(sc, {}, list(PL)))
    assert 0 not in why and 1 not in why and "堺" in why[2]


# --- 2. 地図が長く残る ---------------------------------------------------------
def test_place_map_ends_when_the_line_moves_to_another_year():
    # 秀長の回：「3月、兄は小田原へ」の地図が「1591年1月22日、秀長は郡山城で亡くなりました」まで残った
    got = _places([{"語り": "3月、兄は小田原へ出陣する前に、弟を見舞います。", "card": {"head": "1590年3月"}},
                   {"聞き": "母ちゃんが会いに来るの、つらいね。"},
                   {"語り": "1591年1月22日、秀長は郡山城で亡くなりました。", "card": {"head": "1591年1月"}}])
    assert got == ["小田原", "小田原", None]


def test_place_map_stays_when_the_year_moves_without_saying_it_unless_far():
    lines = [{"語り": "小田原へ向かう。", "year": 1590}, {"語り": "長い道のり。", "year": 1591}, {"語り": "まだ道中。"}]
    assert _places(lines) == ["小田原"] * 3                            # 行が年を言わない1年は同じ場面
    lines[1]["year"] = 1600
    assert _places(lines) == ["小田原", None, None]                     # 10年以上は別の場面


def test_waiting_place_comes_back_when_mentioned_after_a_year_change():
    got = _places([{"語り": "京都と奈良を回る。", "year": 1590}, {"語り": "1600年、話は変わります。", "year": 1600},
                   {"語り": "奈良の町へ。"}])
    assert got == ["京都", None, "奈良"]


# --- 3. 次回予告の紹介文の割れ -----------------------------------------------------
def _end_painter(tmp_path, teaser):
    from test_port import _painter
    sc = script.parse({"title": "t", "next": {"title": "豊臣秀長", "teaser": teaser},
                       "sections": [{"title": "一", "lines": [{"語り": "a"}]}]})
    return _painter(tmp_path, sc)


def test_teaser_never_leaves_one_or_two_chars_on_the_last_row(tmp_path):
    p = _end_painter(tmp_path, "")
    long = "その姿を広めたのは、1985年の小説だった。" * 3
    for teaser in ("秀吉を支えた「補佐役」。その姿を広めたのは、1985年の小説だった。",
                   "申年生まれだから「猿」。いま有力な生まれ年は、申年ではありません。", long):
        size, lh, rows = p.teaser_rows(teaser, 440, 576)
        assert all(p.font("serif", size).getlength(r) <= p.END_RIGHT - 120 for r in rows)
        assert all(len(r) > 2 for r in rows), rows
        assert 440 + lh * (len(rows) - 1) + size * 1.25 <= 576


def test_teaser_shrinks_to_keep_each_sentence_within_two_rows(tmp_path):
    p = _end_painter(tmp_path, "")
    text = "あ" * 100 + "。"                # 内蔵フォントは1字が字の大きさの半分
    size, _lh, rows = p.teaser_rows(text, 440, 700)
    assert len(rows) <= 2 and size < p.TEASER_SIZES[0]


def test_end_card_text_stays_above_the_left_cast_and_left_of_the_end_screen(tmp_path):
    from PIL import ImageChops
    teaser = "秀吉を支えた「補佐役」。その姿を広めたのは、1985年の小説だった。"
    p = _end_painter(tmp_path, teaser)
    with_text = p.end_card(None)
    p.script.next = {}
    plain = p.end_card(None)
    box = ImageChops.difference(with_text.convert("RGB"), plain.convert("RGB")).getbbox()
    assert box is not None and box[3] < p.end_cast_top() and box[2] <= 1080


# --- 4・6. 節の題が寄りのヘルメット・右上の札・額に隠れる ------------------------------------
def _title_painter(tmp_path, lines, title="一"):
    from PIL import Image
    from test_port import _painter
    (tmp_path / "p").mkdir(exist_ok=True)
    Image.new("RGB", (300, 400), (200, 180, 150)).save(tmp_path / "p" / "tall.png")
    Image.new("RGB", (1100, 500), (120, 140, 90)).save(tmp_path / "p" / "byobu.png")
    sc = script.parse({"title": "t", "terms": {"唐入り": "明を従えようとした構想"},
                       "sections": [{"title": title, "lines": lines}]})
    return _painter(tmp_path, sc)


def test_title_room_stops_before_the_term_card_and_the_reaction_figure(tmp_path):
    from chiso import render
    p = _title_painter(tmp_path, [{"語り": "a"}, {"語り": "唐入りです"},
                                  {"聞き": "えっ", "reaction": {"number": "70km"}}])
    free, term, react = (p.title_room(render.state_of(l)) for l in p.script.lines)
    assert free == 1920 - 240
    from chiso.extras import TERM_BOX
    assert term == TERM_BOX[0] - 24 - 120
    from chiso import reaction
    edge = reaction.left_edge(p, p.script.lines[2].reaction, *render.TITLE_BAND)
    assert react == edge - 30 - 120 and react < free


def test_long_title_is_not_drawn_over_the_reaction_figure(tmp_path):
    from PIL import ImageChops
    from chiso import render
    long = "長い題" * 80
    p = _title_painter(tmp_path, [{"聞き": "えっ", "reaction": {"number": "70km"}}], title=long)
    st = render.state_of(p.script.lines[0])
    assert p.title_size(long, p.title_room(st)) is None
    with_title = p.base(st)
    p.script.sections[0].title = ""
    without = p.base(st)
    box = ImageChops.difference(with_title.convert("RGB"), without.convert("RGB")).crop((0, 140, 1920, 215)).getbbox()
    assert box is None                                       # 収まらない題は寄りのあいだ出さない


def test_wide_portrait_moves_below_the_title(tmp_path):
    from chiso import extras, render
    p = _title_painter(tmp_path, [{"語り": "a", "portrait": {"image": "p/tall.png", "caption": "人"}},
                                  {"語り": "b", "portrait": {"image": "p/byobu.png", "caption": "屏風"}}])
    tall, wide = (p.script.lines[i].portrait for i in (0, 1))
    assert extras.portrait_box(p, tall)[1] == 70                         # 縦長の肖像は今までどおり上
    px, py, pw, ph = extras.portrait_box(p, wide)
    assert py - 34 >= render.TITLE_BAND[1] and px - 20 > 640              # 横長の額は題の下、メモにかからない
    assert p.title_room(render.state_of(p.script.lines[1])) == 1920 - 240  # 題は右の端まで使える


def test_check_stops_when_a_section_title_cannot_fit(tmp_path):
    from chiso import check
    p = _title_painter(tmp_path, [{"語り": "a"}, {"語り": "唐入りです"}], title="あ" * 150)
    got = check.section_title_fit(p)
    assert len(got) == 1 and "1節" in got[0] and "1〜2行目" in got[0]
    p.script.sections[0].title = "1591年 秀長の死"
    assert check.section_title_fit(p) == []
