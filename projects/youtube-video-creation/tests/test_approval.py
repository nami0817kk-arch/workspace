"""台本の確認が済むまで書き出さない（2026-09-11）。"""


def test_控えに無い台本は通さない(tmp_path):
    """ユーザー指示「**どんな時も台本確認は必須です**」。

    それまでも決まりはあったが人の注意に頼っていたので抜けた。
    9/11 にマンUと中村敬斗の回を、台本を見せないまま書き出している。
    """
    from src import approval

    ledger = tmp_path / "approved.json"
    assert approval.is_approved("scripts/20260911_manu.md", ledger) is False
    assert "台本確認は必須" in approval.refusal("scripts/20260911_manu.md")

    approval.approve("scripts/20260911_manu.md", ledger)
    assert approval.is_approved("scripts/20260911_manu.md", ledger) is True
    assert approval.approved_at("scripts/20260911_manu.md", ledger)


def test_置き場所が変わっても同じ鍵(tmp_path):
    from src import approval

    ledger = tmp_path / "approved.json"
    approval.approve("scripts/20260911_manu.md", ledger)
    assert approval.is_approved("output/20260911_manu.md", ledger)
    assert approval.key_of("a/b/20260911_manu.md") == "20260911_manu"


def test_壊れた控えでも止まらない(tmp_path):
    """**控えが読めないときは「未確認」に倒す。**通してしまうほうが危ない。"""
    from src import approval

    ledger = tmp_path / "approved.json"
    ledger.write_text("{壊れている", encoding="utf-8")
    assert approval.is_approved("scripts/x.md", ledger) is False
