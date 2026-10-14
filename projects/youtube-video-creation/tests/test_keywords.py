"""検索候補から続く語を数える道具（`tools/keywords.py`）。

**通信はしない。**仕込みの応答（`FAKE`）を食わせて試す。
いちばん大事なのは2つ:
 1. **決まりに当たる語（Jリーグ・女子・賭け・違法視聴・ゲーム）が候補から外れる**
 2. **題名の候補が決まりを満たす**（頭は名前・答えを言い切らない・結び方がそろわない・札は頭に置かない）
"""
import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("keywords_tool", ROOT / "tools" / "keywords.py")
kw = importlib.util.module_from_spec(spec)
sys.modules["keywords_tool"] = kw
spec.loader.exec_module(kw)

from src import review as review_mod  # noqa: E402
from src import tags as tags_mod      # noqa: E402
from src import variety as variety_mod  # noqa: E402

NAME = "久保建英"
# 実際の検索候補に近い形（10-08 に取った並びを元に、決まりに当たる語を混ぜてある）
FAKE = {
    NAME: [NAME, f"{NAME} 移籍", f"{NAME} ゴール", f"{NAME} 怪我", f"{NAME} 評価"],
    NAME + " ": [f"{NAME} 移籍 2026", f"{NAME} ソシエダ", f"{NAME} 海外の反応"],
    f"{NAME} あ": [f"{NAME} アーセナル", f"{NAME} 嫁"],
    f"{NAME} か": [f"{NAME} 怪我", f"{NAME} 彼女"],
    f"{NAME} さ": [f"{NAME} 賭け", f"{NAME} オッズ"],
    f"{NAME} た": [f"{NAME} ウイイレ", f"{NAME} efootball 能力値"],
    f"{NAME} な": [f"{NAME} 無料視聴", f"{NAME} ハイライト"],
    f"{NAME} は": [f"{NAME} Jリーグ時代", f"{NAME} 女子"],
    f"{NAME} ま": [f"{NAME} まとめ"],
    f"{NAME} や": [f"{NAME} 移籍"],
}


def fake_fetch(query: str) -> list[str]:
    """仕込みの応答。**本番には出ない。**"""
    return FAKE.get(query, [])


def collected(wait: float = 0.0) -> dict:
    return kw.collect(NAME, wait=wait, fetcher=fake_fetch)


def built() -> dict:
    return kw.build(NAME, collected())


# ───────────────────────── 決まりに当たる語を外す ─────────────────────────
def test_決まりに当たる語は候補から外れる():
    """**Jリーグ・女子・賭け・違法視聴・ゲームは、題名にもタグにも入れない。**

    扱うリーグは欧州7つ（2026-09-15）・女子は扱わない（2026-09-16）・
    中身と食い違うタグは付けない（`src/tags.py`）。
    """
    data = built()
    使えない = ["Jリーグ時代", "女子", "賭け", "オッズ", "ウイイレ", "efootball",
                "無料視聴", "ハイライト"]
    場 = " ".join(data["titles"]) + " " + "、".join(data["tags"]) + " " + " ".join(data["hashtags"])
    for 語 in 使えない:
        assert 語 not in 場, f"『{語}』が題名かタグに残っています"


def test_外した語は理由つきで出る():
    """**外したことを黙って済ませない。**人が見て判断できるように理由を添える。"""
    data = built()
    外した = {w: why for w, _n, _m, why in data["dropped"]}
    assert "Jリーグ時代" in 外した and "欧州7つ" in 外した["Jリーグ時代"]
    assert "女子" in 外した and "女子サッカーは扱わない" in 外した["女子"]
    assert "ハイライト" in 外した
    text = kw.report(data)
    assert "## 外した語とその理由" in text
    assert "女子サッカーは扱わない（2026-09-16 指示）" in text


def test_人の話と一般の語は印を付けて残す():
    """嫁・彼女は**外さず印だけ**（題材にするかは人が決める）。題名とタグには使わない。"""
    assert kw.mark("嫁") == "private"
    assert kw.mark("彼女") == "private"
    assert kw.mark("まとめ") == "generic"
    data = built()
    表 = {w: m for w, _n, m in data["words"]}
    assert 表.get("嫁") == "人の話"
    assert "嫁" not in "、".join(data["tags"])


def test_海外の反応は使える語のまま():
    """**このチャンネルは海外の反応を必ず混ぜる決まり**なので、中身と食い違わない（2026-09-16）。"""
    assert kw.mark("海外の反応") == ""
    data = built()
    assert any("海外の反応" in t for t in data["tags"])


def test_FIFAは団体の名前でもある():
    """「fifa ランキング」はゲームではない。短い英字は語として一致したときだけ数える。"""
    assert kw.mark("fifa 能力値") == "game"
    assert kw.mark("fifa ランキング") == ""
    assert kw.mark("bettina") == ""        # bet を含むが別の語


# ───────────────────────── 題名の候補 ─────────────────────────
def test_題名の候補は決まりを満たす():
    """頭は人名かクラブ名（`check_title_subject`）／答えを言い切らない（`check_title_hook`）／
    札は頭に置かない。**`src/review.py` の検査をそのまま当てる。**"""
    from types import SimpleNamespace

    titles = built()["titles"]
    assert len(titles) == 3
    for t in titles:
        assert not t.startswith("【"), f"札が頭にあります: {t}"
        assert t.startswith(NAME), f"頭が名前ではありません: {t}"
        shim = SimpleNamespace(title=t)
        assert review_mod.check_title_subject(shim).ok, t
        assert review_mod.check_title_hook(shim).ok, t
        assert len(t) <= tags_mod.MAX_TITLE


def test_題名の結び方はそろえない():
    """**毎回同じ結び方だと一覧で見分けが付かない**（2026-09-08 に9本中7本が同じだった）。
    候補どうしでも、直近の本の結びとも重ねない。"""
    titles = built()["titles"]
    assert len(titles) == 3, f"3つ出ていません: {titles}"
    kinds = [variety_mod._tail_kind(t) for t in titles]
    assert len(set(kinds)) == len(kinds), f"結び方が重なっています: {kinds}"

    # 直近の本の結びを渡したら、それは避ける
    words = kw.plain_words(kw.count(NAME, collected())[0])
    避ける = [variety_mod._tail_kind(t) for t in titles[:1]]
    別 = kw.title_candidates(NAME, words, avoid=避ける)
    assert all(variety_mod._tail_kind(t) not in 避ける for t in 別)


def test_語が薄くても題名は作れる():
    """候補が1語しか取れない日でも、埋めの語で決まりを満たす候補を出す。"""
    from types import SimpleNamespace

    titles = kw.title_candidates("アーセナル", ["移籍"])
    assert len(titles) == 3
    for t in titles:
        assert review_mod.check_title_subject(SimpleNamespace(title=t)).ok, t


# ───────────────────────── タグとハッシュタグ ─────────────────────────
def test_タグは15個までで500字に収まる():
    """タグは合計500字・1つ30字（`src/tags.py` の `fit`）。"""
    tags = built()["tags"]
    assert len(tags) <= 15
    assert tags[0] == NAME, "人の名前がいちばん前に来ていません"
    assert tags_mod.text_length(tags) <= tags_mod.MAX_TAGS_TEXT
    assert all(len(t) <= tags_mod.MAX_TAG_LENGTH for t in tags)
    assert len(set(tags)) == len(tags)


def test_ハッシュタグは3つで空白を含まない():
    """**概要欄に出すのは前の3つだけ**（`tags.HASHTAGS`）。16個以上あると YouTube は全部無視する。
    **ハッシュタグに空白は使えない**ので、「名前＋語」の形はタグにだけ使う。"""
    data = built()
    hash_ = data["hashtags"]
    assert len(hash_) == tags_mod.HASHTAGS == 3
    assert hash_[0] == NAME
    assert all(" " not in t for t in hash_), hash_
    assert len(hash_) <= tags_mod.HASHTAG_LIMIT
    # タグのほうには「名前＋語」の形が入る（人が実際に打っている言い回し）
    assert any(" " in t for t in data["tags"])


def test_クラブの別名はタグで正式名に直す():
    """`Arsenal` で調べても、タグには辞書の正式名（アーセナル）を入れる。"""
    tags = kw.tag_candidates("Arsenal", ["移籍", "試合"])
    assert "アーセナル" in tags


# ───────────────────────── 数え方・取材メモ ─────────────────────────
def test_候補の上のほうほど重く数える():
    """suggestqueries は実数を返さないので、**順位を重みにする**。"""
    words, phrases = kw.count(NAME, collected())
    assert words["移籍"] > words["評価"], dict(words)
    assert phrases["移籍"] > 0


def test_取る回数には上限がある():
    """**相手に負担をかけない。**1つの名前で取る回数を決めてある。"""
    assert len(kw.queries(NAME)) <= kw.MAX_QUERIES
    assert len(kw.queries(NAME, full=True)) <= kw.MAX_QUERIES_ALL
    assert kw.WAIT > 0, "1回ごとに間を空ける"
    raw = collected()
    assert len(raw) <= kw.MAX_QUERIES


def test_取材メモから名前を拾う(tmp_path):
    """`theme.topic`・`people:`・`thumbnail.crest_main` から拾う（`--note`）。"""
    note = tmp_path / "20261008_x.yaml"
    note.write_text(
        "date: 2026年10月8日\n"
        "people:\n"
        "- ミケル・アルテタ\n"
        "- アーセナル\n"
        "theme:\n"
        "  topic: アーセナル\n"
        "  title: アルテタ、2030年まで\n"
        "thumbnail:\n"
        "  crest_main: [アーセナル, リーズ]\n",
        encoding="utf-8")
    names = kw.names_from_note(note)
    assert names == ["アーセナル", "ミケル・アルテタ", "リーズ"]
    assert kw.names_from_date("20261008", root=tmp_path) == names


def test_控えを残す(tmp_path):
    """控えは `research/keywords/<名前>.json`。"""
    path = kw.save(built(), out_dir=tmp_path)
    assert path.name == f"{NAME}.json"
    import json

    data = json.loads(path.read_text(encoding="utf-8"))
    assert data["name"] == NAME and data["words"]


def test_通信が落ちても止まらない(monkeypatch):
    """候補が取れない日は空で返す（例外を投げない）。"""
    class R:
        returncode = 1
        stdout = b""

    monkeypatch.setattr(kw.subprocess, "run", lambda *a, **k: R())
    assert kw.fetch("久保建英") == []


def test_報告は日本語で全部の見出しが出る():
    text = kw.report(built())
    for 見出し in ("よく続く語", "題名の候補", "タグの候補（15）",
                   "ハッシュタグの候補（3つ", "外した語とその理由"):
        assert 見出し in text, 見出し
