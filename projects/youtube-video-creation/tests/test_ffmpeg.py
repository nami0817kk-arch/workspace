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
