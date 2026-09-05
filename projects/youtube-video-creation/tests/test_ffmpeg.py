"""背景トラックの組み立て。

台本の bg に、まだ作っていない mp4 を書いてあると、以前は ffmpeg の生の
エラー出力だけが出て原因が分からなかった。draft が作る台本の既定が
`stadium.mp4` で、init-assets は png しか作らないため、新しい枠を1本作ると
必ずここで止まっていた。
"""

from pathlib import Path

import pytest

from src.ffmpeg import FfmpegError, build_background_track


def test_素材が無ければ_ffmpeg_に渡す前に止める(tmp_path):
    missing = tmp_path / "stadium.mp4"
    with pytest.raises(FfmpegError) as caught:
        build_background_track([(missing, 3.0)], tmp_path / "out.mp4", (1920, 1080))
    message = str(caught.value)
    assert "stadium.mp4" in message
    assert "init-assets" in message      # 静止画の作り方
    assert "make-clip" in message        # 動く背景の作り方


def test_素材がひとつも無いときも言う(tmp_path):
    with pytest.raises(FfmpegError, match="素材がありません"):
        build_background_track([], tmp_path / "out.mp4", (1920, 1080))


def test_draft_の既定の背景は_init_assets_が作るもの():
    """既定が mp4 だと、素材を作っていない人は必ず1本目で止まる。"""
    from src import research

    source = Path(research.__file__).read_text(encoding="utf-8")
    assert '"bg": "assets/backgrounds/stadium.png"' in source

    template = Path("scripts/templates/weekly.md").read_text(encoding="utf-8")
    assert "bg: assets/backgrounds/stadium.png" in template


def test_寄る速さは場面の長さで変わらない():
    """総量を固定していたため、長い場面ほど1秒あたりの動きが小さくなっていた。

    実測（2026-09-05）で20秒の場面はほぼ静止して見えた。
    **長い場面こそ動きが要る。**秒あたりの速さを一定にする。
    """
    from src.ffmpeg import MAX_ZOOM, REFERENCE_SECONDS

    def rate(seconds: float, zoom: float = 1.12) -> float:
        total = min(MAX_ZOOM, 1.0 + (zoom - 1.0) / REFERENCE_SECONDS * seconds)
        return (total - 1.0) / seconds

    assert abs(rate(4) - rate(20)) < 0.0005      # 短くても長くても同じ速さ
    assert rate(10) > 0.005                       # 止まって見えない程度には動く


def test_寄りすぎないよう上限がある():
    """長い場面で寄り続けると絵が荒れる。"""
    from src.ffmpeg import MAX_ZOOM, REFERENCE_SECONDS

    total = min(MAX_ZOOM, 1.0 + (1.12 - 1.0) / REFERENCE_SECONDS * 300)
    assert total == MAX_ZOOM
