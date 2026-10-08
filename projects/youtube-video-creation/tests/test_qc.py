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


def test_時刻の書き方():
    assert qc.clock(0) == "0:00"
    assert qc.clock(287.0) == "4:47"
    assert qc.clock(3671.0) == "1:01:11"
