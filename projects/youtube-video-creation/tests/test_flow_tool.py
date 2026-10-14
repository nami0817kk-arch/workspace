"""tools/flow.py が --help や順番違いの --prompt で Gemini を呼ばない（2026-10-04）。"""
import importlib.util
from pathlib import Path


def _flow():
    spec = importlib.util.spec_from_file_location("flow_tool", Path("tools/flow.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_helpやpromptではGeminiを呼ばない(monkeypatch, capsys):
    flow = _flow()
    called = []
    monkeypatch.setattr(flow, "run", lambda script: called.append(script))
    assert flow.main(["--help"]) == 0
    assert flow.main(["scripts/x.md", "--prompt"]) == 0
    assert flow.main(["--prompt", "scripts/x.md"]) == 0
    assert flow.main(["--unknown"]) == 2
    assert called == []
