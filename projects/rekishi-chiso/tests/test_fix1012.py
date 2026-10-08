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


# --- 5. 節の頭の「ここまでの地層」が1.2秒で読めない ---------------------------------------
def test_recap_section_head_gets_a_longer_gap_unless_pause_is_written(tmp_path):
    from types import SimpleNamespace as NS
    from chiso import mix, voice
    L = lambda i, sec, pause=None: NS(index=i, speaker="語り", text="あ", tone="普通", section=sec, pause=pause)
    assert voice.gap_before(L(0, 0), L(1, 1), recap={1}) == voice.GAP_RECAP >= 2.5
    assert voice.gap_before(L(0, 0), L(1, 1)) == voice.GAP_SECTION
    assert voice.gap_before(L(0, 0), L(1, 1, pause=1.5), recap={1}) == 1.5          # 台本の pause が優先
    lines = [L(0, 0), L(1, 1), L(2, 2)]
    spoken = {i: NS(wav=None, seconds=1.0) for i in range(3)}
    cues, _ = mix.plan(lines, spoken, recap={1})
    assert round(cues[1].start - cues[0].end, 3) == voice.GAP_RECAP
    assert round(cues[2].start - cues[1].end, 3) == voice.GAP_SECTION


def test_recap_sections_follow_the_look_switch():
    from chiso import render
    card = lambda h: {"head": h, "body": "x"}
    secs = [{"title": t, "lines": [{"語り": "a", "card": card("1600年")}, {"語り": "b", "card": card("1601年")}]}
            for t in ("一", "二", "三", "まとめ")]
    sc = script.parse({"title": "t", "recap": True, "sections": secs})
    assert render.recap_sections({}, sc) == {1, 2}                  # 最初の節・まとめの節の頭は出さない
    sc.look = {}
    assert render.recap_sections({}, sc) == set()                   # recap を使わない回は今までどおり
    assert render.recap_sections({"recap": True}, sc) == {1, 2}


def test_qc_does_not_count_the_recap_gap_as_silence():
    from chiso import qc
    rep = qc.Report(duration=200.0, silences=[(49.8, 3.1), (120.0, 3.0)], subs_end=188.0,
                    sections=[(0.0, "第1節 一"), (49.9, "第2節 二")])
    text = "\n".join(qc.summarize(rep))
    assert "無音（-45dB 未満）：1か所" in text and "2:00" in text


# --- 7. 年表の名札が詰まって字幕の箱に隠れる ------------------------------------------------
def _timeline_painter(tmp_path):
    from test_port import _painter
    ev = [[1537, "誕生"], [1573, "長浜城主"], [1582, "大返し"], [1585, "関白"], [1590, "天下一統"], [1598, "死去"],
          [1797, "絵本太閤記"]]
    sc = script.parse({"title": "t", "timeline": {"start": 1530, "end": 1810, "events": ev},
                       "sections": [{"title": "一", "lines": [{"語り": "a"}]}]})
    return _painter(tmp_path, sc)


def test_timeline_labels_use_two_rows_at_most_and_always_show_the_current_one(tmp_path):
    from chiso import render
    p = _timeline_painter(tmp_path)
    rows = p.timeline_rows(470, 1450, None)
    assert all(r is None or 0 <= r < render.TIMELINE_ROWS for r in rows)
    assert None in rows                                            # 詰まった所は出さない
    for k, (y, _l) in enumerate(p.script.events):
        assert p.timeline_rows(470, 1450, y)[k] == 0               # いまの年の名札は必ず、すぐ下の段に


def test_check_tells_when_timeline_events_are_too_close(tmp_path):
    from chiso import check
    p = _timeline_painter(tmp_path)
    got = check.timeline_crowding(p)
    assert len(got) == 1 and "年表の出来事が近すぎて" in got[0]
    p.script.events = [(1537, "誕生"), (1598, "死去"), (1797, "絵本太閤記")]
    assert check.timeline_crowding(p) == []


# --- 8. 折れ線の端の目盛りの字が枠で欠ける ------------------------------------------------
def test_line_end_labels_stay_inside_the_panel(tmp_path):
    from chiso import numbers
    from test_port import _painter
    p = _painter(tmp_path)
    labels = ["1567年ごろ 結婚", "1570年 金ヶ崎", "1573年 小谷落城", "1582年 再婚", "1583年 北ノ庄"]
    xs = [400 + 275 * k for k in range(5)]
    f, cx = numbers.line_labels(p, labels, xs, 330, 1590)
    ws = [f.getlength(t) for t in labels]
    assert cx[0] - ws[0] / 2 >= 330 and cx[-1] + ws[-1] / 2 <= 1590
    assert all(cx[i] + ws[i] / 2 < cx[i + 1] - ws[i + 1] / 2 for i in range(4))
    f2, cx2 = numbers.line_labels(p, ["1565年", "1598年"], [400, 1500], 330, 1590)
    assert cx2 == [400, 1500]                                  # 収まる字は動かさない


# --- 9. 赤ペンの丸が地図の地名に掛かる -------------------------------------------------------
def test_map_labels_move_out_of_the_red_circle(tmp_path):
    import json
    from chiso import figures, pen
    from test_tools import _painter as tools_painter
    m = {"type": "map", "title": "賤ヶ岳から北ノ庄へ", "bounds": [135.6, 136.9, 35.25, 36.25],
         "places": [["賤ヶ岳", 136.21, 35.53], ["北ノ庄", 136.22, 36.06], ["小谷", 136.28, 35.46]],
         "route": ["賤ヶ岳", "北ノ庄"], "note": "10年前の小谷城のすぐ北"}
    sc = script.parse({"title": "t", "sections": [{"title": "一", "lines": [
        {"語り": "a", "figure": m, "mark": {"type": "circle", "at": 3}}]}]})
    p = tools_painter(tmp_path, sc)
    (tmp_path / "maps").mkdir(exist_ok=True)
    for name in ("land_50m.geojson", "rivers_50m.geojson"):
        (tmp_path / "maps" / name).write_text(json.dumps({"type": "FeatureCollection", "features": []}))
    spec = dict(m, _ring=[2])
    boxes = figures.item_boxes(p, spec)
    ring = pen.circle_bounds(boxes[2])
    def inter(a, b):
        return max(0, min(a[2], b[2]) - max(a[0], b[0])) * max(0, min(a[3], b[3]) - max(a[1], b[1]))
    plain = figures.item_boxes(p, m)[0]
    assert boxes[0] != plain                                        # 丸のそばの「賤ヶ岳」の名札は動く
    assert inter(boxes[0], ring) < inter(plain, ring)               # 丸に掛かる所が減る（残るのは点そのもの）
    from chiso import render
    p.base(render.state_of(sc.lines[0]))                                           # 描いて落ちない
