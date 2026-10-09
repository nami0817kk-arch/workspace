# -*- coding: utf-8 -*-
"""出来上がった動画の点検（tools/qc.py、2026-10-08）。

**本物の動画は使わない。**ffmpeg の出力を仕込みの文字列で食わせて、
読み取りと数え方だけを試す。一覧の画像は PIL で作った無地のコマで組む。
"""
from pathlib import Path

import pytest
from PIL import Image

from tools import qc


# --- 仕込みの ffmpeg の出力 ------------------------------------------------------------

def _scene(tag: str, pairs) -> str:
    """metadata=mode=print が出す形（絵の枝）。"""
    out = []
    for number, (at, score) in enumerate(pairs):
        out.append(f"[{tag} @ 000001] frame:{number}  pts:{int(at * 1000)}  pts_time:{at}")
        out.append(f"[{tag} @ 000001] lavfi.scene_score={score}")
    return "\n".join(out)


def _levels(tag: str, pairs) -> str:
    """ametadata=mode=print が出す形（音の枝）。"""
    out = []
    for number, (at, db) in enumerate(pairs):
        out.append(f"[{tag} @ 000002] frame:{number}  pts:{int(at * 48000)}  pts_time:{at}")
        out.append(f"[{tag} @ 000002] lavfi.astats.Overall.RMS_level={db}")
    return "\n".join(out)


def _showinfo(times) -> str:
    return "\n".join(
        f"[Parsed_showinfo_3 @ 000003] n:{k} pts:{int(t * 1000)} pts_time:{t} "
        f"pos:0 fmt:rgb24 sar:1/1 s:320x180"
        for k, t in enumerate(times))


LOUDNORM = """[Parsed_loudnorm_5 @ 000004]
{
\t"input_i" : "-14.30",
\t"input_tp" : "-1.00",
\t"input_lra" : "3.20",
\t"input_thresh" : "-24.50",
\t"output_i" : "-14.00"
}
"""


# --- 読み取り --------------------------------------------------------------------------

def test_絵と音の行が入り混じっても時刻と値を取り違えない():
    """**この取り違えがいちばん怖い。**1回の読み取りで絵と音を同時に流すので、
    ffmpeg の出力は枝ごとの行が混ざる。隣の行と素朴に組むと音の値に絵の時刻が付く。"""
    mixed = "\n".join([
        "[Parsed_metadata_1 @ 000001] frame:0  pts:0  pts_time:1.0",
        "[Parsed_ametadata_7 @ 000002] frame:0  pts:0  pts_time:0.5",
        "[Parsed_metadata_1 @ 000001] lavfi.scene_score=0.900000",
        "[Parsed_ametadata_7 @ 000002] lavfi.astats.Overall.RMS_level=-17.5",
    ])
    assert qc.parse_scene_scores(mixed) == [(1.0, 0.9)]
    assert qc.parse_levels(mixed) == [(0.5, -17.5)]


def test_音が完全に無い刻みは無限小として読む():
    text = _levels("Parsed_ametadata_7", [(0.0, -20.0)]) + "\n" + \
        "[Parsed_ametadata_7 @ 000002] frame:1  pts:24000  pts_time:0.5\n" + \
        "[Parsed_ametadata_7 @ 000002] lavfi.astats.Overall.RMS_level=-inf"
    levels = qc.parse_levels(text)
    assert levels[0] == (0.0, -20.0)
    assert levels[1][1] == float("-inf")
    # 中央値を取るときに -inf を混ぜない（境が -inf になって何も拾えなくなる）
    assert qc.quiet_floor(levels) == pytest.approx(-20.0 - qc.QUIET_GAP)


def test_loudnorm_は最後のかたまりを読む():
    assert qc.parse_loudnorm("ゴミ\n" + LOUDNORM)["input_i"] == pytest.approx(-14.3)
    assert qc.parse_loudnorm("何も無い") == {}


def test_コマの時刻は_showinfo_から取る():
    """番号×間隔と決め打ちにすると、1枚落ちただけで以降の時刻が全部ずれる。"""
    assert qc.parse_frame_times(_showinfo([0.0, 20.0, 40.0])) == [0.0, 20.0, 40.0]


def test_字幕の終わりを読む():
    srt = ("1\n00:00:00,000 --> 00:00:01,500\nキャスター: あ\n\n"
           "2\n00:04:30,200 --> 00:04:31,470\n解説: い\n")
    assert qc.parse_srt(srt)[-1][1] == pytest.approx(271.47)


# --- 数え方 ---------------------------------------------------------------------------

def test_画面が変わらない区間は変わった時刻で尺を切る():
    scores = [(5.0, 0.90), (5.2, 0.01), (30.0, 0.50)]
    runs = qc.still_runs(scores, 40.0, threshold=0.08)
    assert [(round(s, 1), round(d, 1)) for s, d in runs] == [(0.0, 5.0), (5.0, 25.0), (30.0, 10.0)]


def test_しきい値を下げると区間が割れる():
    """縦型（ショート）を 0.06 で見るのはこのため。色だけ替わる差し替えが 0.064 だった。"""
    scores = [(6.0, 0.064), (24.0, 0.40)]
    assert len(qc.still_runs(scores, 54.0, threshold=qc.SCENE)) == 2          # 0.08 では繋がる
    assert len(qc.still_runs(scores, 54.0, threshold=qc.SCENE_SHORT)) == 3    # 0.06 なら割れる


def test_語りの切れ目は語りの大きさを基準に探す():
    """BGM が -22dB で鳴っているので、絶対値の silencedetect では1件も出ない。"""
    levels = [(k * 0.5, -17.0) for k in range(20)]
    levels += [(10.0 + k * 0.5, -40.0) for k in range(6)]     # 3秒ぶん静か
    levels += [(13.0 + k * 0.5, -17.0) for k in range(10)]
    floor = qc.quiet_floor(levels)
    assert floor == pytest.approx(-29.0)
    runs = qc.quiet_runs(levels, 18.0, floor)
    assert [(round(s, 1), round(d, 1)) for s, d in runs] == [(10.0, 3.0)]


def test_節の時刻は書き出した台本から取る():
    data = {"scenes": [
        {"title": "オープニング", "lines": [{"start": 0.0, "duration": 6.0}]},
        {"title": "山場", "main": True, "lines": [{"start": 6.0, "duration": 30.0}]},
        {"title": "見立て", "viewpoint": True, "lines": [{"start": 36.0, "duration": 10.0}]},
    ]}
    assert qc.sections_from_script(data) == [
        (0.0, "第1節 オープニング"), (6.0, "第2節 山場（山場）"), (36.0, "第3節 見立て（見立て）")]


def test_start_の無い古い書き出しは長さを積んで数える():
    data = {"scenes": [
        {"title": "あ", "lines": [{"duration": 4.0}, {"duration": 2.0}]},
        {"title": "い", "lines": [{"duration": 5.0}]},
    ]}
    assert qc.sections_from_script(data) == [(0.0, "第1節 あ"), (6.0, "第2節 い")]


def test_上限は_review_の決まりをそのまま使う():
    from src.review import SAME_SCREEN_MAX, SHORT_CARD_HOLD_MAX
    assert qc.still_limit(False) == SAME_SCREEN_MAX == 20.0
    assert qc.still_limit(True) == SHORT_CARD_HOLD_MAX == 8.0


def test_コマの大きさは縦型と横型で変える():
    assert qc.thumb_size(1920, 1080) == (320, 180)
    assert qc.thumb_size(1080, 1920) == (180, 320)


# --- ○△× の付け方 ---------------------------------------------------------------------

def _report(**kw) -> qc.Report:
    base = dict(name="20261008_test", duration=287.0, portrait=False, step=20.0,
                scene=qc.SCENE, outro=15.0,
                scores=[(k * 5.0, 0.5) for k in range(1, 57)],   # 5秒ごとに大きく変わる
                levels=[(k * 0.5, -17.0) for k in range(574)],
                loud={"input_i": -14.3, "input_tp": -1.0, "input_lra": 3.2},
                subs_end=271.5,
                sections=[(0.0, "第1節 オープニング")])
    base.update(kw)
    return qc.Report(**base)


def _mark(findings, label: str) -> str:
    return next(f.mark for f in findings if f.label.startswith(label))


def test_よく出来た1本は全部丸になる():
    findings = qc.judge(_report())
    assert [f.mark for f in findings] == ["○", "○", "○", "○"]


def test_上限を超えて止まった画面は_バツ():
    """**壊れた例。**1:00 から 1:40 まで40秒、画面が大きく変わらない。"""
    scores = [(k * 5.0, 0.5) for k in range(1, 57) if not 60.0 < k * 5.0 < 100.0]
    findings = qc.judge(_report(scores=scores))
    assert _mark(findings, "画面が大きく変わらない") == "×"
    stuck = next(f for f in findings if f.label.startswith("画面が大きく変わらない"))
    assert "超え 1か所" in stuck.detail
    assert stuck.extra[0].startswith("1:00〜1:40（40秒）")
    assert "上限超え" in stuck.extra[0]


def test_惜しい長さは三角():
    scores = [(k * 5.0, 0.5) for k in range(1, 57) if not 60.0 < k * 5.0 < 78.0]
    assert _mark(qc.judge(_report(scores=scores)), "画面が大きく変わらない") == "△"


def test_ショートは8秒で見る():
    """同じ並びでも、縦型なら上限が 8秒なので ×。"""
    scores = [(k * 10.0, 0.5) for k in range(1, 6)]   # 10秒ごとに大きく変わる
    main = qc.judge(_report(duration=54.0, scores=scores))
    short = qc.judge(_report(duration=54.0, portrait=True, step=5.0, outro=0.0,
                             scene=qc.SCENE_SHORT, subs_end=52.8,
                             levels=[(k * 0.5, -17.0) for k in range(108)], scores=scores))
    assert _mark(main, "画面が大きく変わらない") == "○"
    assert _mark(short, "画面が大きく変わらない") == "×"


def test_終了画面の15秒は差として数えない():
    """本編の最後は終了画面の置き場。そのぶんを引いてから見る。"""
    assert _mark(qc.judge(_report(subs_end=271.5)), "字幕の終わり") == "○"      # 差 15.5秒
    assert _mark(qc.judge(_report(subs_end=265.0)), "字幕の終わり") == "×"      # 差 22秒
    assert _mark(qc.judge(_report(subs_end=285.0)), "字幕の終わり") == "×"      # 置き場が無い


def test_ショートは終了画面を置かないので1_5秒で見る():
    short = dict(duration=54.0, portrait=True, step=5.0, outro=0.0, scene=qc.SCENE_SHORT,
                 levels=[(k * 0.5, -17.0) for k in range(108)],
                 scores=[(k * 5.0, 0.5) for k in range(1, 11)])
    assert _mark(qc.judge(_report(subs_end=53.5, **short)), "字幕の終わり") == "○"
    assert _mark(qc.judge(_report(subs_end=50.5, **short)), "字幕の終わり") == "×"


def test_字幕が読めなければバツ():
    assert _mark(qc.judge(_report(subs_end=None)), "字幕の終わり") == "×"


def test_音が基準から2dBずれたらバツ():
    assert _mark(qc.judge(_report(loud={"input_i": -16.5})), "音の大きさ") == "×"
    assert _mark(qc.judge(_report(loud={"input_i": -15.5})), "音の大きさ") == "△"
    assert _mark(qc.judge(_report(loud={})), "音の大きさ") == "△"


def test_途中の長い無音はバツ_終了画面の中は数えない():
    quiet = [(k * 0.5, -17.0) for k in range(574)]
    # 1:00 から 2.5秒、誰も喋っていない
    body = [(at, -45.0 if 60.0 <= at < 62.5 else db) for at, db in quiet]
    findings = qc.judge(_report(levels=body))
    gap = next(f for f in findings if f.label == "語りの切れ目")
    assert gap.mark == "×"
    assert gap.extra[0].startswith("1:00（2.5秒）")

    # 同じ長さでも、字幕が終わったあと（終了画面）なら × にしない
    tail = [(at, -45.0 if at >= 272.0 else db) for at, db in quiet]
    after = next(f for f in qc.judge(_report(levels=tail)) if f.label == "語りの切れ目")
    assert after.mark == "○"
    assert "終了画面の中に" in after.detail


# --- 一覧の画像と控え -------------------------------------------------------------------

def _frames(times, size=(320, 180)):
    return [(t, Image.new("RGB", size, (int(t) % 255, 60, 90))) for t in times]


def test_コマは節ごとの段に分かれる():
    groups = qc.bands(_frames([0.0, 20.0, 40.0, 60.0]), [(0.0, "第1節 あ"), (35.0, "第2節 い")])
    assert [(name, [t for t, _ in tiles]) for name, tiles in groups] == [
        ("第1節 あ", [0.0, 20.0]), ("第2節 い", [40.0, 60.0])]


def test_節が読めなければ1段にまとめる():
    groups = qc.bands(_frames([0.0, 20.0]), [])
    assert len(groups) == 1 and len(groups[0][1]) == 2


def test_一覧の画像ができる(tmp_path: Path):
    sheet = qc.sheet(_frames([0.0, 20.0, 40.0]), [(0.0, "第1節 あ"), (35.0, "第2節 い")],
                     title="見本", alerts=[(0.0, 30.0)])
    assert sheet.width > 320 and sheet.height > 180
    out = tmp_path / "qc.png"
    sheet.save(out)
    assert out.exists()


def test_コマが1枚も無ければ一覧は作らない():
    with pytest.raises(ValueError):
        qc.sheet([], [])


def test_控えは日本語で結果と一覧を並べる():
    rep = _report()
    text = qc.markdown(rep, qc.judge(rep), Path("output/x/qc.png"))
    assert "# 動画の点検：20261008_test" in text
    assert "本編・長さ 4:47" in text
    assert "![一覧](qc.png)" in text
    assert "review" in text          # どれが review と同じ物差しかを控えにも書く


# --- 台本と突き合わせて、板の中の変化を数に入れる（2026-10-09） ------------------------

# 光らせる行だけが違う同じ年表。`card_look` は同じで、`highlight_row` だけが違う
ROWS = [["1892年", "青と白"], ["1896年", "赤へ"], ["1964年", "全身の赤"]]
CARDS = {
    "crest_card": {"type": "timeline", "title": "エンブレム", "rows": ROWS},
    "crest_1_card": {"type": "timeline", "title": "エンブレム", "rows": ROWS},
    "crest_2_card": {"type": "timeline", "title": "エンブレム", "rows": ROWS, "highlight_row": 0},
    "crest_3_card": {"type": "timeline", "title": "エンブレム", "rows": ROWS, "highlight_row": 2},
    "colour_card": {"type": "table", "title": "ユニフォーム", "rows": ROWS},
}


def _lines(*rows) -> dict:
    """(始まり, 長さ, カード, 写真, テロップ) の並びから script.json の形を作る。"""
    return {"scenes": [{"title": "山場", "main": True, "lines": [
        {"start": start, "duration": length, "card": card, "image": image, "telop": telop}
        for start, length, card, image, telop in rows]}]}


def test_光らせる行だけ替えたカードは画面が動いていると数える():
    """**この回を × にしていた。**暗い板の中で1行の色が変わっても scene は 0.046 しか上がらない。"""
    data = _lines(
        (10.0, 5.0, "crest_1_card", "", "あ"),
        (15.0, 5.0, "crest_2_card", "", "い"),
        (20.0, 5.0, "crest_3_card", "", "う"),
    )
    moves = qc.visual_moves(data, CARDS)
    assert [(at, tag) for at, _, tag in moves] == [(15.0, "光る行"), (20.0, "光る行")]
    assert "光る行・光る点が動いた（crest_2_card）" in moves[0][1]


def test_同じ中身のカードは名前が違っても動いたことにしない():
    """`crest_card` と `crest_1_card` は中身が1字も違わない（台本の別名）。絵は変わらない。"""
    data = _lines(
        (10.0, 5.0, "crest_card", "", "あ"),
        (15.0, 5.0, "crest_1_card", "", "い"),
    )
    assert qc.visual_moves(data, CARDS) == []


def test_言葉だけ替わった行は動いたことにしない():
    """テロップは行ごとに変わる。数に入れると「止まっている区間」が1つも出なくなる。"""
    data = _lines(
        (10.0, 5.0, "crest_2_card", "", "あ"),
        (15.0, 5.0, "crest_2_card", "", "まったく別の言葉"),
    )
    assert qc.visual_moves(data, CARDS) == []


def test_板の絵も写真も替わったら動いたと数える():
    data = _lines(
        (0.0, 5.0, None, "assets/stats/ll_espanyol_data0.png", "あ"),
        (5.0, 5.0, None, "assets/stats/ll_espanyol_data1.png", "い"),
        (10.0, 5.0, None, "assets/backgrounds/stadium_in.png", "う"),
    )
    moves = qc.visual_moves(data, CARDS)
    assert [(at, tag) for at, _, tag in moves] == [(5.0, "板の絵替わり"), (10.0, "写真替わり")]
    assert "ll_espanyol_data1.png" in moves[0][1]


def test_カードの絵そのものが替わったら動いたと数える():
    data = _lines(
        (0.0, 5.0, "crest_2_card", "", "あ"),
        (5.0, 5.0, "colour_card", "", "い"),
    )
    assert [tag for _, _, tag in qc.visual_moves(data, CARDS)] == ["カード替わり"]


def test_台本にカードの中身が無ければ名前で見分ける():
    """`cards` を渡さないときは `review.card_look` と同じく名前に落ちる。控えにもそう書く。"""
    data = _lines(
        (0.0, 5.0, "crest_1_card", "", "あ"),
        (5.0, 5.0, "crest_2_card", "", "い"),
    )
    moves = qc.visual_moves(data, {})
    assert len(moves) == 1
    assert "名前で見分けた" in moves[0][1]


def test_書き込みが増えた行も動いたと数える():
    data = {"scenes": [{"title": "山場", "lines": [
        {"start": 0.0, "duration": 5.0, "card": "crest_2_card", "marks": []},
        {"start": 5.0, "duration": 5.0, "card": "crest_2_card", "marks": [{"kind": "circle"}]},
    ]}]}
    assert [tag for _, _, tag in qc.visual_moves(data, CARDS)] == ["赤ペン"]


def test_start_の無い古い書き出しは長さを積んで数える_台本の根拠():
    data = {"scenes": [{"title": "山場", "lines": [
        {"duration": 4.0, "card": "crest_2_card"},
        {"duration": 2.0, "card": "crest_3_card"},
    ]}]}
    assert [at for at, _, _ in qc.visual_moves(data, CARDS)] == [4.0]


def test_台本に根拠のある時刻で区間を割る():
    scores = [(6.0, 0.5), (24.0, 0.5)]
    moves = [(12.0, "カードの光る行が動いた（crest_2_card）", "光る行"),
             (18.0, "カードの光る行が動いた（crest_3_card）", "光る行")]
    found = qc.stalls(scores, 30.0, threshold=0.06, moves=moves)
    middle = next(s for s in found if s.start == 6.0)
    assert middle.length == pytest.approx(18.0)
    assert [(round(a, 1), round(d, 1)) for a, d in middle.pieces] == [
        (6.0, 6.0), (12.0, 6.0), (18.0, 6.0)]
    assert middle.worst == pytest.approx(6.0)


def test_根拠が無い区間は割らない():
    """**短いほうに倒さない。**台本に根拠が無ければ、今までどおり長いまま出す。"""
    found = qc.stalls([(6.0, 0.5), (24.0, 0.5)], 30.0, threshold=0.06, moves=[])
    middle = next(s for s in found if s.start == 6.0)
    assert middle.pieces == [(6.0, 18.0)] and middle.worst == pytest.approx(18.0)


def test_区間の端にかかる変化では割らない():
    """0秒の切れ端を作らない（区間の始まりは、もともと scene が拾った変わり目）。"""
    found = qc.stalls([(6.0, 0.5)], 30.0, threshold=0.06,
                      moves=[(6.05, "板の絵が替わった", "板の絵替わり")])
    assert found[-1].pieces == [(6.0, 24.0)]


def _short(**kw) -> qc.Report:
    base = dict(duration=54.0, portrait=True, step=5.0, outro=0.0, scene=qc.SCENE_SHORT,
                subs_end=52.8, levels=[(k * 0.5, -17.0) for k in range(108)],
                # 6秒ごとに大きく変わるが、0:06〜0:24 の18秒だけ scene が動かない
                scores=[(6.0, 0.5)] + [(24.0 + k * 6.0, 0.5) for k in range(5)])
    base.update(kw)
    return _report(**base)


def test_光る行が動いた区間は_バツ_にしない():
    """壊れた例の裏返し。18秒のうち 6秒ごとに板の光る行が動いていれば、画面は動いている。"""
    moves = [(12.0, "カードの光る行・光る点が動いた（crest_2_card）", "光る行"),
             (18.0, "カードの光る行・光る点が動いた（crest_3_card）", "光る行")]
    findings = qc.judge(_short(moves=moves, specs=5))
    stuck = next(f for f in findings if f.label.startswith("画面が大きく変わらない"))
    assert stuck.mark == "○"
    assert "超え 0か所" in stuck.detail
    # **黙って通さない。**何か所を割ったか、何を根拠に動いていると数えたかが出る
    assert "台本の根拠で割った区間 1か所" in stuck.detail
    assert any("台本では動いている" in line and "光る行・光る点が動いた" in line
               for line in stuck.extra)


def test_本当に何も変わらない区間は_バツ_のまま():
    """同じ18秒でも、台本に根拠が無ければ ×。**これがこの道具の値打ち。**"""
    stuck = next(f for f in qc.judge(_short(moves=[]))
                 if f.label.startswith("画面が大きく変わらない"))
    assert stuck.mark == "×"
    assert "超え 1か所" in stuck.detail
    assert "台本の根拠で割った区間" not in stuck.detail


def test_割っても上限を超えて残る区間は_バツ_のまま():
    """根拠が1つあっても、割った切れ端が上限を超えていれば ×（短いほうに倒さない）。"""
    moves = [(8.1, "板の絵が替わった（a.png）", "板の絵替わり")]
    stuck = next(f for f in qc.judge(_short(moves=moves, specs=5))
                 if f.label.startswith("画面が大きく変わらない"))
    assert stuck.mark == "×"
    assert "超え 1か所" in stuck.detail          # 8.1〜24.0 の 15.9秒が残る
    assert "台本の根拠で割った区間 1か所" in stuck.detail


def test_台本のカードの中身が読めなければ控えにもそう書く():
    moves = [(12.0, "カードが替わった（crest_2_card・台本にカードの中身が無いので名前で見分けた）",
              "カード名替わり"),
             (18.0, "カードが替わった（crest_3_card・台本にカードの中身が無いので名前で見分けた）",
              "カード名替わり")]
    stuck = next(f for f in qc.judge(_short(moves=moves, specs=0))
                 if f.label.startswith("画面が大きく変わらない"))
    assert "名前で見分けています" in stuck.detail


def test_台本の中身は元の台本から読む(tmp_path: Path):
    """`script.json` にはカードの名前しか残らないので、`scripts/<名前>.md` を見に行く。"""
    (tmp_path / "scripts").mkdir()
    (tmp_path / "scripts" / "20261009_kit.md").write_text(
        "---\ntitle: 見本\ncards:\n  crest_2_card:\n    type: timeline\n"
        "    highlight_row: 0\n---\n\nキャスター: あ\n", encoding="utf-8")
    (tmp_path / "output" / "20261009_kit_short").mkdir(parents=True)
    # ショートは本編の台本から切り出すので、同じファイルを見る
    specs = qc.card_specs(tmp_path / "output" / "20261009_kit_short")
    assert specs["crest_2_card"]["highlight_row"] == 0
    # 台本が無ければ空（今までどおりの数え方に落ちる）
    (tmp_path / "output" / "20261009_other").mkdir()
    assert qc.card_specs(tmp_path / "output" / "20261009_other") == {}


def test_一覧は赤枠を出さずに金の札を添える():
    """根拠のある所は「停滞」の赤枠ではなく、金の枠と札（「光る行」）。"""
    frames = _frames([0.0, 5.0, 10.0], size=(180, 320))
    plain = qc.sheet(frames, [(0.0, "第1節 あ")])
    noted = qc.sheet(frames, [(0.0, "第1節 あ")], notes=[(5.0, 5.0, "光る行")])
    alerted = qc.sheet(frames, [(0.0, "第1節 あ")], alerts=[(5.0, 5.0)])
    assert qc.ALERT in [c for _, c in alerted.getcolors(maxcolors=1 << 20)]
    assert qc.ALERT not in [c for _, c in noted.getcolors(maxcolors=1 << 20)]
    assert noted.tobytes() != plain.tobytes()


def test_赤枠と金の札は重ならない():
    """上限を超えて残った切れ端には札を出さない（赤枠が出るので）。"""
    moves = [(12.0, "板の絵が替わった（a.png）", "板の絵替わり"),
             (14.0, "板の絵が替わった（b.png）", "板の絵替わり")]
    found = qc.stalls([(6.0, 0.5), (24.0, 0.5)], 30.0, threshold=0.06, moves=moves)
    # 切れ端は 6秒・2秒・10秒。札が付くのは真ん中の2秒だけで、10秒のほうは赤枠
    assert qc.sheet_notes(found, 8.0) == [
        (pytest.approx(12.0), pytest.approx(2.0), "板の絵替わり")]


def test_控えに何を根拠に動いていると数えたかが出る():
    moves = [(12.0, "カードの光る行・光る点が動いた（crest_2_card）", "光る行")]
    rep = _short(moves=moves, specs=5)
    text = qc.markdown(rep, qc.judge(rep), Path("output/x/qc.png"))
    assert "台本の上で画面が動いた時刻 1か所" in text
    assert "台本から読めたカードの中身 5件" in text
    assert "光る行・光る点が動いた" in text
    assert "金の枠と札" in text


def test_台本の根拠が無い回は控えにもそう書く():
    rep = _short(moves=[])
    text = qc.markdown(rep, qc.judge(rep), Path("output/x/qc.png"))
    assert "台本の根拠は使っていない" in text


def test_時刻の書き方():
    assert qc.clock(0) == "0:00"
    assert qc.clock(287.0) == "4:47"
    assert qc.clock(3671.0) == "1:01:11"
