"""2026-11-19 の決まり(docs/writing.md の冒頭)を qc が止めるかの確かめ。python -m pytest tests/test_rules.py"""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from naze import qc  # noqa: E402


def _short(tmp_path, lines):
    d = tmp_path / "s1"
    d.mkdir()
    (d / "ep.py").write_text("EP = dict(lines=[])\n", encoding="utf-8")          # 縦(aspect の指定なし)
    return dict(lines=lines, _folder=d)


def _good():
    return [
        dict(id="a1", text="エベレストは8,849m。いちばん高いから、そこで止まっていると思いますよね。", open="belief"),
        dict(id="a2", text="ところが、火星には22kmの山があります。エベレストの2.5倍です。"),
        dict(id="a3", text="地球の山は、なぜそこで止まるのか。"),
        dict(id="a4", text="山は重い。高くなるほど、下の岩に重さがかかります。"),
        dict(id="a5", text="岩は、ある重さを超えると、つぶれて流れます。"),
        dict(id="a6", text="火星は、重さが地球の4割しかありません。"),
        dict(id="a7", text="だから、同じ岩でも高く積めます。"),
        dict(id="a8", text="地球の山を止めているのは、山そのものの重さでした。", answer=True),
        dict(id="a9", text="次に高い山を見たら、その下の岩を思い出してください。"),
    ]


def test_good_short_passes(tmp_path):
    f, _ = qc.rules(_short(tmp_path, _good()))
    assert f == []


def test_no_open_mark_fails(tmp_path):
    ls = _good()
    ls[0] = {k: v for k, v in ls[0].items() if k != "open"}
    f, _ = qc.rules(_short(tmp_path, ls))
    assert any("冒頭の印" in x for x in f)


def test_belief_without_twist_fails(tmp_path):
    ls = _good()
    ls[1] = dict(id="a2", text="火星には22kmの山があります。エベレストの2.5倍です。")
    f, _ = qc.rules(_short(tmp_path, ls))
    assert any("裏切っていない" in x for x in f)


def test_answer_early_fails(tmp_path):
    ls = _good()
    ls[2] = dict(ls[2], answer=True)
    f, _ = qc.rules(_short(tmp_path, ls))
    assert any("答えが早い" in x for x in f)


def test_no_answer_fails(tmp_path):
    ls = [{k: v for k, v in d.items() if k != "answer"} for d in _good()]
    f, _ = qc.rules(_short(tmp_path, ls))
    assert any("答えの行に印が無い" in x for x in f)


@pytest.mark.parametrize("t", ["もう十分高いよね。ええ、十分高いんです。", "それって重いからじゃないの？"])
def test_daiben_fails(tmp_path, t):
    ls = _good()
    ls[3] = dict(id="a4", text=t)
    f, _ = qc.rules(_short(tmp_path, ls))
    assert any("代弁" in x for x in f)


def test_no_compare_fails(tmp_path):
    ls = [dict(d, text=d["text"].replace("2.5倍", "高い").replace("4割", "少し")) for d in _good()]
    f, _ = qc.rules(_short(tmp_path, ls))
    assert any("身近な物" in x for x in f)


def test_long_chapter_positions(tmp_path):
    (tmp_path / "long.py").write_text("LONG = dict(title='t', parts=[dict(title='a', ep='ch1'), dict(title='b', ep='ch2'), dict(title='c', ep='ch3')])\n",
                                      encoding="utf-8")
    eps = {}
    for n in ("ch1", "ch2", "ch3"):
        (tmp_path / n).mkdir()
        (tmp_path / n / "ep.py").write_text("EP = dict(aspect='landscape', lines=[])\n", encoding="utf-8")
        eps[n] = dict(lines=_good(), _folder=tmp_path / n)
    assert [qc.position(eps[n]) for n in ("ch1", "ch2", "ch3")] == ["first", "middle", "last"]
    f, _ = qc.rules(eps["ch2"])                                    # 途中の章に答え → 止める
    assert any("最後の章より前に答え" in x for x in f)
    assert qc.rules(eps["ch3"])[0] == []                           # 最後の章は答えてよい


def test_gate_rejects_old_rules(tmp_path):
    v = tmp_path / "x.mp4"
    v.write_bytes(b"0")
    st = v.stat()
    base = dict(passed=True, video=v.name, size=st.st_size, mtime=st.st_mtime, fails=[])
    (tmp_path / "qc.json").write_text(json.dumps(base), encoding="utf-8")
    with pytest.raises(SystemExit, match="古い決まり"):
        qc.gate(v)
    (tmp_path / "qc.json").write_text(json.dumps(dict(base, rules=qc.RULES)), encoding="utf-8")
    qc.gate(v)                                                     # 今の決まりで通っていれば通す
