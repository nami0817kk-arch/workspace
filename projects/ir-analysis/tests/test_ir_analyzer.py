"""分析まわりの、ネットワークに出ないテスト。"""
from src.analysis.ir_analyzer import analyze_ir


def test_empty_text_short_circuits_without_calling_the_api():
    item = analyze_ir({"company": "テスト社", "title": "決算", "text": "   "})
    assert item["analysis"]["summary"] == "テキスト取得不可"
    assert item["analysis"]["impact"] == "neutral"


def test_api_failure_degrades_to_neutral_instead_of_raising(monkeypatch):
    import src.analysis.ir_analyzer as mod

    def _boom():
        raise RuntimeError("no api key")

    monkeypatch.setattr(mod, "get_client", _boom)
    item = analyze_ir({"company": "テスト社", "title": "決算", "text": "本文あり"})
    assert item["analysis"]["swing_relevance"] == "low"
    assert "分析エラー" in item["analysis"]["summary"]
