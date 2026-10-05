"""サムネの型ごとのクリック率（2026-10-05）。型の分け方と、API を呼ばない計算の部分を確かめる。"""
import importlib.util
import sys
from datetime import date
from pathlib import Path

import pytest

spec = importlib.util.spec_from_file_location(
    "thumbctr", Path(__file__).resolve().parent.parent / "tools" / "thumbctr.py")
mod = importlib.util.module_from_spec(spec)
sys.modules["thumbctr"] = mod   # dataclass が自分のモジュールを引くので先に登録する
spec.loader.exec_module(mod)


def everything(_path):
    """写真は全部手元にあり、印のファイルは無い。"""
    return not (_path.endswith(".thumbonly") or _path.endswith(".statboard.txt"))


# ---------------------------------------------------------------- 型

def test_写真1枚():
    assert mod.classify_thumbnail({"photo": "assets/images/x/01.jpg", "line1": "a"}, everything) == mod.T_PHOTO


def test_写真2枚並びと3枚並び():
    two = {"photos": ["a.jpg", "b.jpg"]}
    three = {"photos": ["a.jpg", "b.jpg", "c.jpg"], "photo": "a.jpg"}
    assert mod.classify_thumbnail(two, everything) == mod.T_PHOTOS2
    assert mod.classify_thumbnail(three, everything) == mod.T_PHOTOS3


def test_並びにVSの印があればVS():
    t = {"photos": ["a.jpg", "b.jpg"], "face_link": "VS"}
    assert mod.classify_thumbnail(t, everything) == mod.T_VS


def test_手元に無い写真は並びに数えない():
    """src/thumbnail.py は実在する写真だけで並べる。2枚書いても1枚しか無ければ1枚の型。"""
    t = {"photos": ["a.jpg", "missing.jpg"]}
    assert mod.classify_thumbnail(t, lambda p: p == "a.jpg") == mod.T_PHOTO


def test_エンブレム主役は写真より先():
    t = {"crest_main": ["バルセロナ", "レアル・マドリード"], "face_link": "VS", "photos": ["a.jpg", "b.jpg"]}
    assert mod.classify_thumbnail(t, everything) == mod.T_CREST


def test_基礎DATAの板():
    t = {"crest_main": ["バルセロナ"], "board": "assets/stats/ll_barcelona_data_t.png"}
    assert mod.classify_thumbnail(t, everything) == mod.T_DATA_BOARD


def test_ほかの板は数字の板():
    assert mod.classify_thumbnail({"board": "assets/stats/scorers_20260928_spain.png"}, everything) == mod.T_BOARD
    # 写真の欄に板を書いた回も板
    assert mod.classify_thumbnail({"photo": "assets/stats/run.png"}, everything) == mod.T_BOARD


def test_statboardの控えがある絵も板():
    t = {"photo": "assets/images/x/board.png"}
    assert mod.classify_thumbnail(t, lambda p: True) == mod.T_BOARD


def test_写真2枚以上は板より先():
    """src/thumbnail.py は板の回でも写真が2枚以上あれば並べる。"""
    t = {"board": "assets/stats/x.png", "photos": ["a.jpg", "b.jpg"]}
    assert mod.classify_thumbnail(t, everything) == mod.T_PHOTOS2


def test_thumbonlyの印がある写真は全面写真と通算の表():
    t = {"photo": "assets/images/20261004_player_342229/thumbfull/01.jpg", "photos": []}
    assert mod.classify_thumbnail(t, lambda p: not p.endswith(".statboard.txt")) == mod.T_FULL_PANEL


def test_取材メモが無い_指定が無い():
    assert mod.classify_thumbnail(None) == mod.T_UNKNOWN
    assert mod.classify_thumbnail({"line1": "a", "line2": "b"}, everything) == mod.T_NONE


# ---------------------------------------------------------------- 種類・日付

def test_シリーズと日本人枠とほか():
    assert mod.genre_of({"series": "選手紹介", "slot": "japan_1"}) == mod.G_SERIES
    assert mod.genre_of({"slot": "japan_3"}) == mod.G_JAPAN
    assert mod.genre_of({"slot": "japanese_2"}) == mod.G_JAPAN
    assert mod.genre_of({"slot": "premier_2", "series": ""}) == mod.G_OTHER
    assert mod.genre_of(None) == mod.G_UNKNOWN


def test_ショートの出力先は本編の取材メモを引く():
    assert mod.base_name("20261005_doan_captain_short") == "20261005_doan_captain"
    assert mod.is_short("20261005_doan_captain_short")
    assert not mod.is_short("20261005_doan_captain")


def test_公開日は太平洋時間の日付():
    # 日本時間 10/5 9:00 ＝ UTC 10/5 0:00 ＝ 太平洋時間 10/4 17:00
    assert mod.pacific_day("2026-10-05T00:00:00Z") == date(2026, 10, 4)
    assert mod.pacific_day("2026-10-05T09:30:00+00:00") == date(2026, 10, 5)
    assert mod.pacific_day("だめ") is None


def test_対象の選び方():
    posted = [
        {"build": "a", "video_id": "A", "publish_at": "2026-09-20T03:00:00Z"},
        {"build": "a_short", "video_id": "B", "publish_at": "2026-09-20T03:30:00Z"},
        {"build": "old", "video_id": "C", "at": "2026-08-01T00:00:00+00:00"},   # 期間の外
        {"build": "(以前)-D", "video_id": "D", "at": "2026-09-20T00:00:00+00:00"},  # 旧名
        {"build": "gone", "video_id": "E", "at": "2026-09-20T05:00:00+00:00", "deleted": True},
        {"build": "a", "video_id": "A", "publish_at": "2026-09-20T03:00:00Z"},  # 二重
    ]
    got = mod.pick_videos(posted, date(2026, 9, 1), date(2026, 9, 30))
    assert [(v.video_id, v.short) for v in got] == [("A", False), ("B", True)]


def test_取材メモから型と種類を付ける(tmp_path):
    (tmp_path / "20260920_x.yaml").write_text(
        "slot: japan_1\nthumbnail:\n  photos: [a.jpg, b.jpg]\n", encoding="utf-8")
    videos = [mod.Video("A", "20260920_x", False, date(2026, 9, 20)),
              mod.Video("B", "20260920_x_short", True, date(2026, 9, 20)),
              mod.Video("C", "20260920_none", False, date(2026, 9, 20))]
    mod.label(videos, tmp_path, everything)
    assert [(v.thumb_type, v.genre) for v in videos] == [
        (mod.T_PHOTOS2, mod.G_JAPAN), (mod.T_PHOTOS2, mod.G_JAPAN), (mod.T_UNKNOWN, mod.G_UNKNOWN)]


# ---------------------------------------------------------------- 数字

def test_公開から3日だけを日ごとに引く():
    v = mod.Video("A", "a", False, date(2026, 9, 28))
    w = mod.windows([v], last=date(2026, 9, 29))
    assert sorted(w) == [date(2026, 9, 28), date(2026, 9, 29)]   # 30日はまだ数字が無い


def test_サムネが出る場所から来た再生を分ける():
    v = mod.Video("A", "a", False, date(2026, 9, 28))
    mod.apply_source_rows([v], [["A", "SUBSCRIBER", 10], ["A", "YT_SEARCH", 5],
                                ["A", "SHORTS", 100], ["A", "NOTIFICATION", 2], ["Z", "SUBSCRIBER", 9]])
    assert v.views == 117 and v.thumb_views == 15


def test_到達レポートのCSVを読む():
    text = ("date,channel_id,video_id,video_thumbnail_impressions,video_thumbnail_impressions_ctr\n"
            "20260920,UC1,A,1000,4.5\n20260921,UC1,A,1000,5.5\n20260920,UC1,B,0,0\n")
    rows = mod.parse_reach_csv(text)
    assert rows[0] == ("20260920", "A", 1000, 4.5)
    per, unit = mod.aggregate_reach(rows)
    assert unit == "percent"
    assert per["A"] == (2000, pytest.approx(5.0))
    assert per["B"] == (0, 0.0)


def test_クリック率が割合で来ても百分率に直す():
    per, unit = mod.aggregate_reach([("d", "A", 100, 0.04), ("d", "A", 300, 0.08)])
    assert unit == "fraction"
    assert per["A"][1] == pytest.approx(7.0)


def test_まとめは本編とショートと種類と型で分ける():
    vs = []
    for i, n in enumerate((10, 20, 30)):
        v = mod.Video(f"m{i}", "a", False, date(2026, 9, 20), thumb_type=mod.T_PHOTO, genre=mod.G_JAPAN, views=n)
        vs.append(v)
    s = mod.Video("s", "a_short", True, date(2026, 9, 20), thumb_type=mod.T_PHOTO, genre=mod.G_JAPAN, views=999)
    s.impressions, s.ctr = 100, 3.0
    out = mod.summarize(vs + [s])
    main = [g for g in out if g["kind"] == "本編"][0]
    assert main["n"] == 3 and main["views"]["median"] == 20 and main["ctr"] is None
    short = [g for g in out if g["kind"] == "ショート"][0]
    assert short["ctr"]["median"] == 3.0


def test_本数が少ない型は少ないと書く():
    v = mod.Video("A", "a", False, date(2026, 9, 20), thumb_type=mod.T_VS, genre=mod.G_OTHER, views=5)
    text = mod.render(mod.summarize([v]), [v], "（理由）", date(2026, 9, 1), date(2026, 9, 28),
                      date(2026, 10, 5), 0, "", True)
    assert "1（少ない）" in text
    assert "表示回数とクリック率は取れていない" in text
    assert "前半" in text and "後半" in text


def test_dry_runは数字を渡せば最後まで通る(tmp_path):
    (tmp_path / "a.yaml").write_text("slot: world_1\nthumbnail:\n  photo: p.jpg\n", encoding="utf-8")
    posted = [{"build": "a", "video_id": "A", "publish_at": "2026-09-20T03:00:00Z"}]
    fixture = {"last_day": "2026-09-30", "rows": [["A", "YT_SEARCH", 7]],
               "reach_rows": [["20260920", "A", 200, 5.0]]}
    text, videos, _ = mod.run(posted, date(2026, 10, 5), 28, fixture=fixture, research=tmp_path,
                              exists=everything)
    assert videos[0].views == 7 and videos[0].impressions == 200 and videos[0].ctr == 5.0
    assert "写真1枚" in text and "取れていない" not in text
