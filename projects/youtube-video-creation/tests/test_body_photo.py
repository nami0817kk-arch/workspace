"""サムネ専用の絵（表を描き込んだもの）を本文に挟まない（2026-10-29）。"""
from pathlib import Path

from src import pipeline
from src.research import THUMB_ONLY_MARK

ROOT = Path(pipeline.__file__).resolve().parents[1]


def _make(tmp_name: str, thumb_only: bool) -> tuple[str, str]:
    folder = ROOT / "assets" / "images" / "_test_body_photo"
    folder.mkdir(parents=True, exist_ok=True)
    panel = folder / f"{tmp_name}_panel.jpg"
    base = folder / f"{tmp_name}_w.jpg"
    panel.write_bytes(b"x")
    base.write_bytes(b"x")
    mark = Path(str(panel) + THUMB_ONLY_MARK)
    if thumb_only:
        mark.write_text("", encoding="utf-8")
    elif mark.exists():
        mark.unlink()
    rel = lambda p: p.relative_to(ROOT).as_posix()
    return rel(panel), rel(base)


def test_サムネ専用の絵は本文に挟まず台本の写真に替える():
    panel, base = _make("a", thumb_only=True)
    assert pipeline.body_photo({"thumbnail_photo": panel, "bg": base}) == base


def test_下地が動画ならサムネ専用の絵は挟まない():
    panel, _ = _make("b", thumb_only=True)
    assert pipeline.body_photo({"thumbnail_photo": panel, "bg": "assets/backgrounds/stock/x.mp4"}) == ""


def test_ふつうのサムネの写真はそのまま挟む():
    panel, base = _make("c", thumb_only=False)
    assert pipeline.body_photo({"thumbnail_photo": panel, "bg": base}) == panel


def teardown_module(module):
    import shutil
    shutil.rmtree(ROOT / "assets" / "images" / "_test_body_photo", ignore_errors=True)
