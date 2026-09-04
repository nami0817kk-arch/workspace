"""画像に誰が写っているかの確認。

ファイル名に `Ayase Ueda` と入った写真の被写体が、構造化データでは別人
（Joris Kramer）だった。ライセンス判定は3件とも OK を返しており、
機械では防げていなかった。**ファイル名は根拠にならない。**
"""

from dataclasses import dataclass, field

import pytest
import requests

from src.subjects import Subjects, SubjectError, fetch, verify


@dataclass
class FakeResponse:
    status_code: int = 200
    payload: dict | None = None

    def json(self):
        if self.payload is None:
            raise ValueError("no json")
        return self.payload


@dataclass
class FakeSession:
    """Commons と Wikidata の2回の問い合わせに順に答える。"""

    payloads: list = field(default_factory=list)
    error: Exception | None = None
    calls: int = 0

    def get(self, url, params=None, headers=None, timeout=None):
        if self.error:
            raise self.error
        payload = self.payloads[min(self.calls, len(self.payloads) - 1)]
        self.calls += 1
        return FakeResponse(payload=payload)


def _commons(ids):
    return {"entities": {"M1": {"statements": {"P180": [
        {"mainsnak": {"datavalue": {"value": {"id": i}}}} for i in ids
    ]}}}}


def _wikidata(pairs):
    return {"entities": {
        qid: {"labels": {lang: {"value": v} for lang, v in labels.items()}}
        for qid, labels in pairs.items()
    }}


def test_被写体に本人が明記されていれば通る():
    session = FakeSession([
        _commons(["Q1"]),
        _wikidata({"Q1": {"ja": "上田綺世", "en": "Ayase Ueda"}}),
    ])
    ok, why = verify("File:x.jpg", "上田綺世", "Ayase Ueda", session=session)
    assert ok
    assert "明記" in why


def test_被写体が別人なら弾く():
    """実測の事例。ファイル名は Ayase Ueda だが depicts は Joris Kramer。"""
    session = FakeSession([
        _commons(["Q27893964"]),
        _wikidata({"Q27893964": {"ja": "ヨリス・クラマー", "en": "Joris Kramer"}}),
    ])
    ok, why = verify("File:x.jpg", "上田綺世", "Ayase Ueda", session=session)
    assert not ok
    assert "ヨリス・クラマー" in why


def test_被写体の指定が無ければ弾く():
    """「本人ではない」ではなく「確かめられない」。断定せずに使わない。"""
    session = FakeSession([{"entities": {"M1": {"statements": {}}}}])
    ok, why = verify("File:x.jpg", "上田綺世", session=session)
    assert not ok
    assert "断定できません" in why


def test_日本語ラベルだけでも当たる():
    """Wikidata のラベルは言語ごとに別。英語だけで照合すると取りこぼす。"""
    session = FakeSession([
        _commons(["Q1"]),
        _wikidata({"Q1": {"ja": "リオネル・メッシ"}}),
    ])
    ok, _ = verify("File:x.jpg", "リオネル・メッシ", "Lionel Messi", session=session)
    assert ok


def test_File接頭辞は自動で付く():
    session = FakeSession([{"entities": {"M1": {"statements": {}}}}])
    assert fetch("x.jpg", session=session).title == "File:x.jpg"


def test_つながらないときは理由を言う():
    session = FakeSession(error=requests.ConnectionError("切断"))
    with pytest.raises(SubjectError, match="確かめられません"):
        fetch("File:x.jpg", session=session)


def test_人物以外も被写体に入る():
    """football shirt のような物も depicts に入る。人物と混ざる。"""
    found = Subjects(title="File:x.jpg", ids=["Q1", "Q2"],
                     names=["ヨリス・クラマー", "football shirt"])
    assert found.stated
    assert not found.includes("上田綺世", "Ayase Ueda")
