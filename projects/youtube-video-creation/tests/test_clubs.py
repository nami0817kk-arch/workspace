"""クラブ名の別名辞書。

見出しは英語・現地語・日本語・略称が混ざる。
同じクラブだと分かっていないと、採点も、まとめも、リーグの割り当ても外す。
"""

import pytest

from src import clubs


@pytest.fixture
def book():
    return clubs.load()


def test_辞書が読める(book):
    assert len(book) > 40
    names = [club.canonical for club in book]
    assert len(names) == len(set(names))


def test_略称から正式表記に寄せる(book):
    assert clubs.canonical("Spurs sign a striker", book) == ["トッテナム"]
    assert clubs.canonical("Man Utd close in", book) == ["マンチェスター・ユナイテッド"]
    assert clubs.canonical("バルサが獲得", book) == ["バルセロナ"]


def test_長い別名を先に当てる(book):
    # Inter Milan を インテル と ミラン の2件にしない
    assert clubs.canonical("Inter Milan agree deal", book) == ["インテル"]
    assert clubs.canonical("AC Milan agree deal", book) == ["ミラン"]


def test_出てきた順に返す(book):
    assert clubs.canonical("Arsenal hijack Chelsea move", book) == ["アーセナル", "チェルシー"]


def test_英字の別名は語の切れ目でだけ当てる(book):
    # Roma が Romano（記者名）に当たってはいけない
    assert clubs.canonical("Fabrizio Romano reports", book) == []
    # Villa が Villarreal に当たってはいけない
    assert clubs.canonical("Villarreal win", book) == ["ビジャレアル"]


def test_曖昧な略称は辞書に入れない(book):
    # AFC は AFC Bournemouth にも当たるので、アーセナルの別名にしない
    assert clubs.canonical("AFC Bournemouth sign a keeper", book) == []


def test_リーグは1つに定まるときだけ返す(book):
    assert clubs.league_of("Spurs beat Newcastle", book) == "england"
    # 移籍は2クラブにまたがる。どちらの話かは書き手が決める
    assert clubs.league_of("Bayern want a Chelsea forward", book) == ""
    assert clubs.league_of("no club here", book) == ""


def test_日本語の見出しからもリーグが読める(book):
    assert clubs.league_of("トッテナムがクドゥスの獲得で合意", book) == "england"
    assert clubs.league_of("浦和レッズが完全移籍を発表", book) == "japan"


def test_ビッグクラブは英語の見出しでも当たる(book):
    assert clubs.is_big("Spurs agree deal", book)
    assert not clubs.is_big("Brentford agree deal", book)


def test_話題の当たりは先に出たクラブ(book):
    assert clubs.topic_of("Arsenal hijack Chelsea move", book) == "アーセナル"
    assert clubs.topic_of("誰の話でもない", book) == ""


def test_辞書が無ければ空(tmp_path):
    assert clubs.load(tmp_path / "ない.yaml") == []


def test_採点はクラブ名の辞書でも当たる():
    from src.candidates import Candidate, score

    scoring = {"weights": {"big_club": 2}, "big_clubs": ["レアル・マドリード"]}
    # scoring.big_clubs は日本語表記しか並んでいない。英語の見出しでも効くこと
    item = score([Candidate(id="a", title="Spurs agree deal", hours_ago=99.0)], scoring)[0]
    assert item.big_club
    assert item.breakdown["ビッグクラブ"] == 2


def test_別のクラブの話はまとめない():
    from src.collect import group, parse

    hits = parse(
        "Arsenal agree deal for defender\thttps://a.com/arsenal-defender\n"
        "Manchester United agree deal for defender\thttps://b.com/united-defender"
    )
    assert len(group(hits)) == 2


def test_同じクラブなら書き方が違ってもまとめる():
    from src.collect import group, parse

    hits = parse(
        "Man Utd close in on defender deal\thttps://a.com/man-utd-defender\n"
        "Manchester United agree deal for defender\thttps://b.com/united-defender"
    )
    assert len(group(hits)) == 1


def test_候補ファイルに話題とリーグの当たりが入る():
    from src.collect import parse, to_yaml

    text = to_yaml(parse("Spurs agree deal\thttps://a.com/spurs-deal"), "2026年8月31日")
    assert 'topic: "トッテナム"' in text
    assert "league: england" in text
