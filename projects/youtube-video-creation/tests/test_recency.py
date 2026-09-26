"""最近すでに読み上げた人を見つける（2026-09-18）。

ユーザー指摘「かこにかいたやつばっかー」。8件の題材が全部×になり、
5件は**前日の代表発表の回で名前を読み上げたばかり**だった。
"""

from __future__ import annotations

from datetime import date

import pytest

from src import recency


def _script(folder, name: str, title: str, body: str) -> None:
    (folder / name).write_text(
        f"---\ntitle: {title}\ntopic: {title}\n---\n\n## 何が起きたか\n\n{body}\n",
        encoding="utf-8",
    )


@pytest.fixture
def scripts(tmp_path):
    folder = tmp_path / "scripts"
    folder.mkdir()
    # 昨日の代表発表。**題名は「4人の新規メンバー」で、名前は本文にしか出ない**
    _script(folder, "20260917_daihyo_new.md", "初招集の4人は誰か",
            "キャスター: 谷村海那、中野就斗、齋藤俊輔、松木玖生の4人が初招集です。")
    _script(folder, "20260917_kubo.md", "久保建英について、スペイン紙が「2度目」と書いた",
            "キャスター: 久保建英の評価が上がっています。")
    _script(folder, "20260916_itakura.md", "板倉滉に何が起きているか",
            "キャスター: 板倉滉はボルシアMGでの立場を守りました。")
    return folder


def test_題材にした人は見出しが違っても見つかる(scripts):
    found = recency.advise(["久保建英「国籍は関係ない」"], root=scripts,
                           today=date(2026, 9, 18), subjects_only=True)
    assert len(found) == 1
    assert "久保建英" in found[0]
    assert "09/17" in found[0]
    assert "題材にした" in found[0]


def test_名前を読み上げただけの人も見つかる(scripts):
    """**控えに残らない人。**代表発表の回で名前を読んだ4人は
    `covered.yaml` にも取材メモの id にも出てこない。"""
    title = "谷村海那がA代表初選出を伝えられた瞬間"
    assert not recency.advise([title], root=scripts, today=date(2026, 9, 18),
                              subjects_only=True)
    loose = recency.advise([title], root=scripts, today=date(2026, 9, 18))
    assert len(loose) == 1
    assert "谷村海那" in loose[0]
    assert "名前を" in loose[0]


def test_出していない人は鳴らない(scripts):
    assert not recency.advise(["伊藤涼太郎、シント＝トロイデンが復帰を画策"],
                              root=scripts, today=date(2026, 9, 18))


def test_古い台本は数えない(scripts):
    _script(scripts, "20260901_ito.md", "伊藤涼太郎の移籍",
            "キャスター: 伊藤涼太郎が動きます。")
    assert not recency.advise(["伊藤涼太郎の近況"], root=scripts,
                              today=date(2026, 9, 18), days=5)
    assert recency.advise(["伊藤涼太郎の近況"], root=scripts,
                          today=date(2026, 9, 18), days=30)


def test_日付はファイル名から取る(scripts, tmp_path):
    """**更新時刻ではない。**あとから直した台本が「今日の台本」に化ける"""
    (scripts / "notes.md").write_text("久保建英", encoding="utf-8")
    days = [p.day for p in recency.past(5, scripts, date(2026, 9, 18))]
    assert date(2026, 9, 17) in days
    assert len(days) == 3      # 日付の付いていない notes.md は入らない


def test_どの回にも出る語では鳴らない(tmp_path):
    """「日本代表」「試合」で全部の見出しが当たると、読めない一覧になる。"""
    folder = tmp_path / "scripts"
    folder.mkdir()
    for n in range(10):
        _script(folder, f"2026091{n}_x{n}.md", f"何かの話{n}",
                "キャスター: 日本代表の試合がありました。")
    assert not recency.advise(["日本代表の試合が近い"], root=folder,
                              today=date(2026, 9, 18), days=30)


def test_題材にした回を先に並べる(scripts):
    """名前を1回読んだだけの回より、主役にした回のほうが重い。"""
    found = recency.hits("久保建英と松木玖生", recency.past(5, scripts, date(2026, 9, 18)))
    assert [h.subject for h in found] == sorted([h.subject for h in found], reverse=True)


def test_重なりの知らせに過去の題名を出す(scripts):
    """**語だけでは判断を誤る**（2026-09-18）。

    「久保建英（09/17 題材にした）」だけを見て、こちらは「試合結果は別の中身」と
    判断して押し通した。実際には 9/14 に「久保建英が2戦続けてベンチ。
    出番が来たのは何分からか」があり、本文に「地元紙が採点をつけなかった」まで
    入っていた。**題名が見えていれば、同じ形だとその場で分かる。**
    """
    found = recency.advise(["久保建英「国籍は関係ない」"], root=scripts,
                           today=date(2026, 9, 18), subjects_only=True)
    assert "久保建英について、スペイン紙が「2度目」と書いた" in found[0], \
        "過去の題名が出ていない"


def test_題名はtitle行から取る(scripts):
    """台本の頭は YAML。**`# ` の見出しは無い**（最初これで探して空振りした）。"""
    one = [p for p in recency.past(5, scripts, date(2026, 9, 18))
           if p.path.name == "20260917_kubo.md"][0]
    assert one.headline == "久保建英について、スペイン紙が「2度目」と書いた"
