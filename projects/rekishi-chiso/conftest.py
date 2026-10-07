# tests から chiso を import できるようにする（パッケージは入れずに使う）
import pytest


@pytest.fixture(autouse=True)
def _no_rembg(monkeypatch):
    """手元に rembg（人物の切り抜き）が入っていても、テストでは切り抜かない（CI と同じ結果に）。
    切り抜きを見るテストは thumbfx._segment を自分で差し替える。"""
    from chiso import thumbfx
    monkeypatch.setattr(thumbfx, "_segment", lambda tile: None)
    thumbfx._MEMO.clear()
