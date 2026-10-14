"""シリーズの回の冒頭と、この回だけの数字（2026-10-06「動画の質を上げる仕組み ⑩」）。"""
from src.research import (SERIES_DATA_READ_MAX, YARD_STRONG_MARK, Notes, Section,
                          _advise_series_numbers, _advise_series_opening)


def _sec(id, heading, say, voices=None, viewpoint=False, card=None, line_cards=None, images=None):
    return Section(id=id, heading=heading, tier="背景", telop="", say=say, voices=voices or [],
                   viewpoint=viewpoint, card=card, line_cards=line_cards or [],
                   line_images=images or [])


def _notes(sections, series="監督の経歴"):
    return Notes(date="2026-10-06", title="t", question="", sections=sections, series=series)


# 基礎DATAの節で読む項目（強い一点なし）
DATA = ["日本代表を率いたメキシコ人の監督、ハビエル・アギーレ。",
        "生まれは1958年、メキシコの首都メキシコシティです。",
        "両親はスペインのバスク地方の出身。",
        "選手時代は中盤の守備の選手でした。",
        "監督としては、メキシコ代表を2度率いています。",
        "日本代表を率いたのは、2014年の夏からです。",
        "いまはスペインのバレンシアを率いています。"]
VIEW_TABLE = {"type": "table", "rows": [["ブラガ", "50%"], ["サウジ", "81.1%"]]}


def test_基礎DATAが最初で長いと知らせる():
    hints = _advise_series_opening(_notes([_sec("data", "基礎DATA", DATA)]))
    assert len(hints) == 2
    assert "基礎DATAから始まって" in hints[0]
    assert f"{len(DATA)}行" in hints[1]
    assert not any(h.startswith(YARD_STRONG_MARK) for h in hints)


def test_強い一点を前に置けば冒頭は知らせない():
    front = ["代表監督として、ここまで4戦4勝。クラブ時代を通じて、いちばんの滑り出しです。"]
    data = DATA[:SERIES_DATA_READ_MAX]
    assert _advise_series_opening(_notes([_sec("data", "基礎DATA", front + data)])) == []
    # 1行目に数字、2行目に比べの言葉でもよい（1〜2行）
    two = ["代表監督として、ここまで4戦4勝です。", "クラブの歴史で、いちばんの滑り出しです。"]
    assert _advise_series_opening(_notes([_sec("data", "基礎DATA", two + data)])) == []
    # 別の節（どんな選手か）が先にあれば、基礎DATAの位置は咎めない
    hook = _sec("hook", "どんな選手か", ["ヴィティーニャ。すべてのパスを受けに行く司令塔です。"])
    assert _advise_series_opening(_notes([hook, _sec("data", "基礎DATA", data)])) == []


def test_強い一点を置いても読み上げが長ければ知らせる():
    front = ["代表監督として、ここまで4戦4勝。クラブ時代を通じて、いちばんの滑り出しです。"]
    hints = _advise_series_opening(_notes([_sec("data", "基礎DATA", front + DATA)]))
    assert len(hints) == 1 and "読み上げる語り" in hints[0]


def test_クラブ紹介のいま見る理由は強い一点として数える():
    reasons = ["今季は公式戦8戦8勝。", "率いるのはフリック監督。", "胸に入れたのはユニセフ。"]
    images = [f"assets/stats/ll_barcelona_data_r{k}.png" for k in (1, 2, 3)]
    data = DATA[:4]
    sec = _sec("data", "いま見る理由と基礎DATA", reasons + data,
               images=images + ["assets/stats/ll_barcelona_data0.png"] * len(data))
    assert _advise_series_opening(_notes([sec], series="ラ・リーガチーム紹介")) == []
    # 板を9項目すべて読み上げると、読み上げの長さだけ知らせる
    sec = _sec("data", "いま見る理由と基礎DATA", reasons + DATA,
               images=images + ["assets/stats/ll_barcelona_data0.png"] * len(DATA))
    hints = _advise_series_opening(_notes([sec], series="ラ・リーガチーム紹介"))
    assert len(hints) == 1 and "読み上げる語り" in hints[0]


def test_本人の言葉とショート専用の行は読み上げに数えない():
    say = DATA[:5] + ["私は10番だった。", "かつては、ピッチの上のリーダーだった。"]
    voices = [""] * 5 + ["ジネディーヌ・ジダン"] * 2
    hints = _advise_series_opening(_notes([_sec("data", "基礎DATA", say, voices=voices)]))
    assert len(hints) == 1 and "基礎DATAから始まって" in hints[0]


def test_ニュースの回は見ない():
    data = _sec("data", "基礎DATA", DATA)
    view = _sec("view", "見立て", ["素晴らしい活躍でした。"], viewpoint=True)
    assert _advise_series_opening(_notes([data, view], series="")) == []
    assert _advise_series_numbers(_notes([data, view], series="")) == []


def test_見立てに比べが無いと強めに知らせる():
    # 表も、数字2つの比べの1行も無い（見立ての一言の引用カードだけ）
    view = _sec("view", "エムバペとの今季の差", ["発表までにこの差が開くのか。", "注目です。"],
                viewpoint=True, card={"type": "quote", "text": "見立て"})
    hints = _advise_series_numbers(_notes([view]))
    assert len(hints) == 1 and hints[0].startswith(YARD_STRONG_MARK)
    assert "自分で数えた表" in hints[0] and "数字2つを比べた1行" in hints[0]
    # 比べの1行はあっても、表が無ければ知らせる
    view = _sec("view", "ヤマルと同じ8点", ["ヤマルは8試合8点。オリーセは7試合で、同じ8点です。"],
                viewpoint=True, card={"type": "quote", "text": "見立て"})
    hints = _advise_series_numbers(_notes([view]))
    assert len(hints) == 1 and "自分で数えた表" in hints[0] and "数字2つを比べた1行" not in hints[0]
    # 表はあっても、数字を比べた行が無ければ知らせる
    view = _sec("view", "時期ごとの勝率", ["代表はまだ無敗です。", "次の試合が楽しみです。"],
                viewpoint=True, card=VIEW_TABLE)
    hints = _advise_series_numbers(_notes([view]))
    assert len(hints) == 1 and "数字2つを比べた1行" in hints[0]


def test_見立てに表と比べがあれば知らせない():
    view = _sec("view", "勝ち点のペース", ["勝ち点は16で3位。首位の21とは、5の差です。"],
                viewpoint=True, card=VIEW_TABLE)
    assert _advise_series_numbers(_notes([view])) == []
    # 行ごとの card でもよい。比べは続く2行にまたがってもよい
    say = ["勝率を時期ごとに束ねると、ブラガでは50%。", "リスボンの名門2つでは、68.5%に上がります。"]
    view = _sec("view", "時期ごとの勝率", say, viewpoint=True,
                line_cards=[VIEW_TABLE, VIEW_TABLE])
    assert _advise_series_numbers(_notes([view])) == []
