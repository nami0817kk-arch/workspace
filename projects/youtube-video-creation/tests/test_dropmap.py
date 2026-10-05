"""離脱した行の地図（2026-10-03）。作り物の曲線と台本で、計算の部分だけを確かめる。"""
import importlib.util
import sys
from datetime import date, datetime, timezone
from pathlib import Path

import pytest

spec = importlib.util.spec_from_file_location(
    "dropmap", Path(__file__).resolve().parent.parent / "tools" / "dropmap.py")
mod = importlib.util.module_from_spec(spec)
sys.modules["dropmap"] = mod   # dataclass が自分のモジュールを引くので先に登録する
spec.loader.exec_module(mod)


def _script():
    """10秒の台本。タイトル2秒・語り2秒・数字2秒・節の頭2秒・反応2秒。"""
    return {"scenes": [
        {"title": "オープニング", "lines": [
            {"speaker": "キャスター", "text": "久保建英が結婚を発表。", "start": 0.0, "duration": 2.0},
            {"speaker": "キャスター", "text": "2日の夜に発表しました。", "start": 2.0, "duration": 2.0},
            {"speaker": "キャスター", "text": "今季は7試合で3得点。", "start": 4.0, "duration": 2.0},
        ]},
        {"title": "反応", "lines": [
            {"speaker": "解説", "text": "仲間からも祝福が届きました。", "start": 6.0, "duration": 2.0},
            {"speaker": "久保建英", "text": "支えてくれた人に感謝します", "start": 8.0, "duration": 1.0},
            {"speaker": "ネット民", "text": "おめでとう！", "start": 9.0, "duration": 1.0},
        ]},
    ]}


# 0〜10秒で 100% → 50% に落ちる直線（尺10秒）
LINEAR = [(0.0, 1.0), (1.0, 0.5)]


def test_行への割り当ては秒を尺で割った地点の維持率():
    lines = mod.script_lines(_script())
    drops = mod.map_lines(LINEAR, lines, 10.0)
    assert [round(d.top, 3) for d in drops] == [1.0, 0.9, 0.8, 0.7, 0.6, 0.55]
    assert [round(d.bottom, 3) for d in drops] == [0.9, 0.8, 0.7, 0.6, 0.55, 0.5]


def test_落ち幅と秒あたり():
    drops = mod.map_lines([(0.0, 1.0), (0.2, 0.4), (1.0, 0.4)], mod.script_lines(_script()), 10.0)
    # 0〜2秒で 1.0 → 0.4 に落ち、そのあとは平ら
    assert drops[0].drop == pytest.approx(0.6)
    assert drops[0].per_second == pytest.approx(0.3)
    assert all(d.drop == pytest.approx(0.0) for d in drops[1:])


def test_startが無い行はdurationを積み上げる():
    script = {"scenes": [{"title": "a", "lines": [
        {"speaker": "キャスター", "text": "一", "duration": 3.0},
        {"speaker": "キャスター", "text": "二", "duration": 2.5},
    ]}, {"title": "b", "lines": [{"speaker": "解説", "text": "三", "duration": 1.0}]}]}
    lines = mod.script_lines(script)
    assert [ln.start for ln in lines] == [0.0, 3.0, 5.5]


def test_種類の分類():
    kinds = [mod.classify(ln) for ln in mod.script_lines(_script())]
    assert kinds == ["タイトル", "その他の語り", "数字", "前置き", "代弁", "反応"]


def test_締めと海外の反応():
    script = {"scenes": [
        {"title": "a", "lines": [{"speaker": "キャスター", "text": "題", "duration": 1}]},
        {"title": "b", "lines": [
            {"speaker": "キャスター", "text": "続報が入りました。", "duration": 1},
            {"speaker": "海外のファン", "text": "Kubo!", "duration": 1},
        ]},
        {"title": "c", "lines": [
            {"speaker": "キャスター", "text": "本編はチャンネルから見られます。", "duration": 1},
            {"speaker": "キャスター", "text": "続報をお伝えします。", "duration": 1},
            {"speaker": "キャスター", "text": "チャンネル登録もお願いします。", "duration": 1},
        ]},
    ]}
    kinds = [mod.classify(ln) for ln in mod.script_lines(script)]
    # 途中の節の「続報」は中身の話（締めではない）。最後の節だけ締めに数える
    assert kinds == ["タイトル", "前置き", "反応", "締め", "締め", "締め"]


def test_数字が1つだけの語りは数字の行にしない():
    script = {"scenes": [{"title": "a", "lines": [
        {"speaker": "キャスター", "text": "題", "duration": 1},
        {"speaker": "キャスター", "text": "前置き", "duration": 1},
        {"speaker": "キャスター", "text": "7試合ぶりの出場です。", "duration": 1},
    ]}]}
    assert mod.classify(mod.script_lines(script)[2]) == "その他の語り"


def test_冒頭30秒の落ち幅():
    assert mod.first_drop(LINEAR, 60.0) == pytest.approx(0.25)
    # 30秒より短い動画は最後まで
    assert mod.first_drop(LINEAR, 20.0) == pytest.approx(0.5)


def _posted():
    return [
        {"build": "a", "video_id": "A", "at": "2026-10-01T00:00:00+00:00"},
        {"build": "a_short", "video_id": "As", "at": "2026-10-01T00:00:00+00:00",
         "publish_at": "2026-10-01T03:00:00Z"},
        {"build": "(以前)-X", "video_id": "X", "at": "2026-10-01T00:00:00+00:00"},
        {"build": "b", "video_id": "B", "at": "2026-10-01T00:00:00+00:00", "deleted": True},
        {"build": "c", "video_id": "C", "at": "2026-10-02T00:00:00+00:00"},
        {"build": "old", "video_id": "O", "at": "2026-09-01T00:00:00+00:00"},
    ]


def test_測れなかった本数を理由ごとに数える(tmp_path):
    import json

    for build in ("a", "a_short", "c"):
        (tmp_path / build).mkdir()
        (tmp_path / build / "script.json").write_text(
            json.dumps(_script(), ensure_ascii=False), encoding="utf-8")
    # A と As には曲線があり、C はまだ無い
    fixture = {"A": [[0.0, 1.0], [1.0, 0.5]], "As": [[0.0, 1.0], [1.0, 0.2]]}
    text, summary = mod.run(14, "all", True, fixture, date(2026, 10, 3), tmp_path, _posted())
    assert summary["measured"] == 2
    assert summary["skipped"] == 3
    assert summary["reasons"] == {"台本が手元に無い": 1, "削除済み": 1, "曲線がまだ無い": 1}
    assert summary["calls"] == 0
    assert "測れた 2本 / 測れなかった 3本" in text
    assert summary["groups"]["ショート"]["videos"] == 1
    assert summary["groups"]["本編"]["skipped"] == 3


def test_種類を絞ると反対側は数えない():
    since = datetime(2026, 9, 20, tzinfo=timezone.utc)
    shorts = mod.pick_targets(_posted(), since, "short", lambda b: True)
    assert [t.video_id for t in shorts] == ["As"]
    mains = mod.pick_targets(_posted(), since, "main", lambda b: True)
    assert "As" not in [t.video_id for t in mains] and "O" not in [t.video_id for t in mains]


# ---------------------------------------------------------------- 壊れた例で × になるか

def test_空の曲線は黙って0にしない():
    with pytest.raises(ValueError):
        mod.ratio_at([], 0.5)


def test_尺が0なら止める():
    with pytest.raises(ValueError):
        mod.map_lines(LINEAR, mod.script_lines(_script()), 0.0)


def test_尺を取り違えると割り当てがずれる():
    """尺を倍に間違えると、行の始まりの維持率が変わる。ずれを見逃さない。"""
    lines = mod.script_lines(_script())
    right = mod.map_lines(LINEAR, lines, 10.0)
    wrong = mod.map_lines(LINEAR, lines, 20.0)
    assert [d.top for d in right] != [d.top for d in wrong]


def test_曲線の無い動画を測れた側に数えない(tmp_path):
    """全部の曲線が空なら、測れた本数は0で、レポートにもそう出る。"""
    import json

    (tmp_path / "a").mkdir()
    (tmp_path / "a" / "script.json").write_text(json.dumps(_script()), encoding="utf-8")
    posted = [{"build": "a", "video_id": "A", "at": "2026-10-01T00:00:00+00:00"}]
    text, summary = mod.run(14, "all", True, {}, date(2026, 10, 3), tmp_path, posted)
    assert summary["measured"] == 0 and summary["skipped"] == 1
    assert "測れた 0本 / 測れなかった 1本" in text
    assert "測れた動画なし" in text


# ---------------------------------------------------------------- 節の種類でまとめる（2026-10-05）

def _main_script(series=""):
    """本編の形。一言 → 題 → 出来事 → 本人の言葉 → 見立て → ネットの反応（20秒）。"""
    return {"title": "久保建英が結婚を発表", "series": series, "scenes": [
        {"title": "オープニング", "lines": [
            {"speaker": "キャスター", "text": "まさかの発表。", "start": 0.0, "duration": 2.0},
            {"speaker": "キャスター", "text": "久保建英が結婚を発表。", "start": 2.0, "duration": 2.0},
        ]},
        {"title": "何が起きたか", "lines": [
            {"speaker": "キャスター", "text": "2日の夜に発表しました。", "start": 4.0, "duration": 4.0},
            {"speaker": "キャスター", "text": "今季は7試合で3得点。", "start": 8.0, "duration": 2.0},
        ]},
        {"title": "本人が語ったこと", "lines": [
            {"speaker": "久保建英", "text": "支えてくれた人に感謝します", "start": 10.0, "duration": 3.0},
            {"speaker": "キャスター", "text": "そう話しました。", "start": 13.0, "duration": 1.0},
        ]},
        {"title": "結婚とこの先の日程", "viewpoint": True, "lines": [
            {"speaker": "解説", "text": "次は10日のマジョルカ戦。", "start": 14.0, "duration": 2.0},
        ]},
        {"title": "ネットの反応", "lines": [
            {"speaker": "ネット民", "text": "おめでとう！", "start": 16.0, "duration": 2.0},
            {"speaker": "キャスター", "text": "チャンネル登録もお願いします。", "start": 18.0, "duration": 2.0},
        ]},
    ]}


def test_節の種類は話者の割合と印と見出しで決める():
    k = mod.section_kind
    assert k("その夜", {}, None, ["ネット民", "ネット民", "キャスター"]) == "ネットの反応"
    assert k("会見で", {}, None, ["久保建英", "久保建英", "キャスター"]) == "本人の言葉"
    assert k("何が変わるか", {"viewpoint": True}, None, ["解説"]) == "見立て"
    # 取材メモの印でも見立てになる（script.json の文字列 "True" も読む）
    assert k("何が変わるか", {"viewpoint": "True"}, None, ["解説"]) == "見立て"
    assert k("いま見る理由と基礎DATA", {}, None, ["キャスター"]) == "基礎DATA"
    assert k("1911年の揉め事", {}, {"id": "history"}, ["解説"]) == "歩み"
    assert k("このクラブを語る3人", {}, {"id": "legends"}, ["キャスター"]) == "人物"
    assert k("これから何を見るか", {}, {"id": "next"}, ["解説"]) == "これから"
    assert k("何が起きたか", {}, {"id": "what"}, ["キャスター"]) == "出来事"
    assert k("選ばれた30人", {}, {"id": "list", "card": {"type": "table"}}, ["解説"]) == "数字の表"
    assert k("最後のユニフォーム", {}, {"id": "kit"}, ["解説"]) == "その他"


def test_話者の割合は見出しより先に当てる():
    """「何が起きたか」でも、ネットの声が半分以上なら反応の節として数える。"""
    assert mod.section_kind("何が起きたか", {}, {"id": "what"},
                            ["ネット民", "現地サポ"]) == "ネットの反応"


def test_行の種類は題の行と冒頭と締めを切り出す():
    kinds = [k for k, _ in mod.line_kinds(_main_script(), None)]
    # 一言（0行目）は冒頭、題と同じ文の行がタイトル。最後の登録の行は締め
    assert kinds == ["冒頭", "タイトル", "出来事", "出来事", "本人の言葉", "本人の言葉",
                     "見立て", "ネットの反応", "締め"]


def test_題と一致する行が無ければ最初の行をタイトルにする():
    script = _main_script()
    script["title"] = "台本と違う題"
    kinds = [k for k, _ in mod.line_kinds(script, None)]
    assert kinds[:2] == ["タイトル", "冒頭"]


def test_取材メモの節のidで種類を決める():
    script = {"title": "題", "scenes": [
        {"title": "オープニング", "lines": [{"speaker": "キャスター", "text": "題。", "duration": 2}]},
        {"title": "そこから18年", "lines": [{"speaker": "解説", "text": "一", "duration": 2}]},
    ]}
    research = {"sections": [{"id": "history3", "heading": "そこから18年"}]}
    assert [k for k, _ in mod.line_kinds(script, research)] == ["タイトル", "歩み"]
    # 取材メモが無ければ見出しだけで決める（この見出しは当たらない）
    assert [k for k, _ in mod.line_kinds(script, None)] == ["タイトル", "その他"]


def test_節をまとめて終了画面を足す():
    script = _main_script()
    lines = mod.script_lines(script)
    segs = mod.build_segments(LINEAR, lines, mod.line_kinds(script, None), 25.0)
    assert [(s.kind, s.start, s.end) for s in segs] == [
        ("冒頭", 0.0, 2.0), ("タイトル", 2.0, 4.0), ("出来事", 4.0, 10.0),
        ("本人の言葉", 10.0, 14.0), ("見立て", 14.0, 16.0), ("ネットの反応", 16.0, 18.0),
        ("締め", 18.0, 20.0), ("締め", 20.0, 25.0)]
    assert segs[-1].heading == mod.END_CARD
    # 25秒で 100% → 50%（秒あたり 2ポイント）。出来事は 6秒で 12ポイント
    assert segs[2].drop == pytest.approx(0.12)
    assert segs[2].per_second == pytest.approx(0.02)
    assert segs[2].position == pytest.approx(4.0 / 25.0)


def test_位置帯の境目で節を切る():
    seg = mod.Segment(heading="h", kind="出来事", start=5.0, end=35.0, top=0, bottom=0,
                      length=100.0)
    pieces = mod.band_pieces(seg, [(0.0, 1.0), (1.0, 0.0)])
    assert [(b, round(sec, 3), round(drop, 3)) for b, sec, drop, _ in pieces] == [
        ("0〜10秒", 5.0, 0.05), ("10〜30秒", 20.0, 0.2), ("30〜60秒", 5.0, 0.05)]


def test_同じ曲線の本だけなら位置の分を引いた残りは0():
    lines = mod.script_lines(_main_script())
    maps = []
    for vid in ("A", "B"):
        m = mod.VideoMap(video_id=vid, build=vid, short=False, length=20.0, points=LINEAR)
        m.segments = mod.build_segments(LINEAR, lines, mod.line_kinds(_main_script(), None), 20.0)
        maps.append(m)
    baseline = mod.position_baseline(maps)
    assert len(baseline) == 20 and baseline[0] == pytest.approx(0.025)
    for s in maps[0].segments:
        assert s.drop - mod.expected_drop(s, baseline) == pytest.approx(0.0, abs=1e-9)


def test_位置のふつうより多く落ちた節は正になる():
    """A は出来事（4〜10秒）だけ急に落ち、B は平ら。A の出来事は正、B の出来事は負。"""
    lines = mod.script_lines(_main_script())
    kinds = mod.line_kinds(_main_script(), None)
    steep = [(0.0, 1.0), (4 / 20, 1.0), (10 / 20, 0.4), (1.0, 0.4)]
    flat = [(0.0, 1.0), (1.0, 1.0)]
    maps = []
    for vid, pts in (("A", steep), ("B", flat)):
        m = mod.VideoMap(video_id=vid, build=vid, short=False, length=20.0, points=pts)
        m.segments = mod.build_segments(pts, lines, kinds, 20.0)
        maps.append(m)
    baseline = mod.position_baseline(maps)
    ev_a = next(s for s in maps[0].segments if s.kind == "出来事")
    ev_b = next(s for s in maps[1].segments if s.kind == "出来事")
    assert ev_a.drop - mod.expected_drop(ev_a, baseline) == pytest.approx(0.3)
    assert ev_b.drop - mod.expected_drop(ev_b, baseline) == pytest.approx(-0.3)


def test_節の単位で回すとニュースとシリーズに分けて数える(tmp_path):
    import json

    out_root = tmp_path / "output"
    res_root = tmp_path / "research"
    res_root.mkdir()
    for build, series in (("n1", ""), ("s1", "ラ・リーガチーム紹介"), ("n2", "")):
        (out_root / build).mkdir(parents=True)
        (out_root / build / "script.json").write_text(
            json.dumps(_main_script(series), ensure_ascii=False), encoding="utf-8")
    # n2 は取材メモで本人の言葉の節を「what」にしてあるが、話者の割合が先に効く
    (res_root / "n2.yaml").write_text(
        "sections:\n- id: what\n  heading: 本人が語ったこと\n", encoding="utf-8")
    posted = [{"build": b, "video_id": b.upper(), "at": "2026-10-01T00:00:00+00:00"}
              for b in ("n1", "s1", "n2")]
    posted.append({"build": "n3", "video_id": "N3", "at": "2026-10-01T00:00:00+00:00"})
    fixture = {"curves": {"N1": [[0.0, 1.0], [1.0, 0.5]], "S1": [[0.0, 1.0], [1.0, 0.2]],
                          "N2": [[0.0, 1.0], [1.0, 0.6]]},
               "views": {"N1": 50, "S1": 300, "N2": 120}}
    text, summary = mod.run(28, "main", True, fixture, date(2026, 10, 5), out_root, posted,
                            by="section", research_root=res_root)
    assert summary["measured"] == 3
    assert summary["reasons"] == {"台本が手元に無い": 1}
    groups = summary["groups"]
    assert groups["全体"]["videos"] == 3
    assert groups["ニュース"]["videos"] == 2 and groups["シリーズ"]["videos"] == 1
    kinds = groups["全体"]["kinds"]
    assert kinds["本人の言葉"]["segments"] == 3
    assert kinds["見立て"]["videos"] == 3
    # 再生100回以上の本だけの中央値は2本ぶん（N1 は50回なので外れる）
    assert kinds["出来事"]["n_many"] == 2
    # 出てくる位置（秒・割合）の中央値。尺は台本の終わり20秒＋締めのカード3秒
    assert kinds["出来事"]["start"] == pytest.approx(4.0)
    assert kinds["出来事"]["position"] == pytest.approx(4.0 / 23.0)
    assert "測れた 3本 / 測れなかった 1本" in text
    assert "シリーズの回: 測れた 1本" in text
    assert "## ④ 同じ位置帯で種類を比べる（全体" in text
    assert mod.END_CARD not in text.split("## ⑤")[1]


def test_落ち幅の上位から終了画面を外す():
    m = mod.VideoMap(video_id="A", build="a", short=False, length=10.0, views=500)
    m.segments = [
        mod.Segment(heading="何が起きたか", kind="出来事", start=0, end=5, top=1.0, bottom=0.8, length=10),
        mod.Segment(heading=mod.END_CARD, kind="締め", start=5, end=10, top=0.8, bottom=0.1, length=10),
    ]
    assert [s.heading for _, s in mod.top_segments([m])] == ["何が起きたか"]
    # 再生の下限より少ない本は、位置の分を引いた並びから外す
    assert mod.top_segments([m], baseline=[0.0] * 10, min_views=1000) == []


def test_曲線と再生数の控えの形も読む():
    curves, views = mod.split_fixture({"curves": {"A": [[0, 1]]}, "views": {"A": 3}})
    assert curves == {"A": [[0, 1]]} and views == {"A": 3}
    curves, views = mod.split_fixture({"A": [[0, 1]]})
    assert curves == {"A": [[0, 1]]} and views == {}
