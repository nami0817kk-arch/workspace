"""台本の確認が済むまで書き出さない（2026-09-11）。"""


def _script(tmp_path, name, text="# 台本\n読み上げる文\n"):
    path = tmp_path / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def test_控えに無い台本は通さない(tmp_path):
    """ユーザー指示「**どんな時も台本確認は必須です**」。

    それまでも決まりはあったが人の注意に頼っていたので抜けた。
    9/11 にマンUと中村敬斗の回を、台本を見せないまま書き出している。
    """
    from src import approval

    ledger = tmp_path / "approved.json"
    script = _script(tmp_path, "scripts/20260911_manu.md")
    assert approval.is_approved(script, ledger) is False
    assert "台本確認は必須" in approval.refusal(script, ledger)

    approval.approve(script, ledger)
    assert approval.is_approved(script, ledger) is True
    assert approval.approved_at(script, ledger)


def test_置き場所が変わっても同じ鍵(tmp_path):
    """中身が同じなら、どこに置いても同じ台本として通る。"""
    from src import approval

    ledger = tmp_path / "approved.json"
    here = _script(tmp_path, "scripts/20260911_manu.md")
    there = _script(tmp_path, "output/20260911_manu.md")
    approval.approve(here, ledger)
    assert approval.is_approved(there, ledger)
    assert approval.key_of("a/b/20260911_manu.md") == "20260911_manu"


def test_OKのあとに直したら通さない(tmp_path):
    """**2026-09-11 に足した。**名前だけで控えていたので、OKをもらったあとに
    台本を直しても素通りした。実際、伊藤涼太郎の回で
    「まとめサイトの」という一行を直したあとに書き出しが走っている。
    """
    from src import approval

    ledger = tmp_path / "approved.json"
    script = _script(tmp_path, "scripts/20260911_ito.md")
    approval.approve(script, ledger)
    assert approval.is_approved(script, ledger) is True

    script.write_text("# 台本\n直した文\n", encoding="utf-8")
    assert approval.is_approved(script, ledger) is False
    assert approval.changed_since_approval(script, ledger) is True
    assert "中身が変わっています" in approval.refusal(script, ledger)

    approval.approve(script, ledger)          # 見せ直して OK をもらった
    assert approval.is_approved(script, ledger) is True


def test_中身の印が無い古い控えは通さない(tmp_path):
    """印を持つ前の控え。**迷ったら聞く側に倒す。**"""
    from src import approval

    ledger = tmp_path / "approved.json"
    ledger.write_text('{"20260911_ito": "2026-09-11T13:46:35+09:00"}', encoding="utf-8")
    script = _script(tmp_path, "scripts/20260911_ito.md")
    assert approval.is_approved(script, ledger) is False


def test_壊れた控えでも止まらない(tmp_path):
    """**控えが読めないときは「未確認」に倒す。**通してしまうほうが危ない。"""
    from src import approval

    ledger = tmp_path / "approved.json"
    ledger.write_text("{壊れている", encoding="utf-8")
    assert approval.is_approved("scripts/x.md", ledger) is False
