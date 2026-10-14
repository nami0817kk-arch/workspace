"""書き出す前の4コマの下見（tools/preview4.py、2026-10-05）。小さな台本で、声を作らずに絵ができるかを見る。"""
from pathlib import Path

import pytest
from PIL import Image, ImageDraw

from src import faces, tts
from src.config import load_config
from src.script_model import parse_script
from tools import preview4


def _script(tmp_path: Path) -> Path:
    """写真1枚・節2つの台本。下地も写真も tmp に作る（assets/ は gitignore なので CI に無い）。"""
    bg = tmp_path / "bg.png"
    Image.new("RGB", (1920, 1080), (20, 60, 40)).save(bg)
    photo = tmp_path / "photo.jpg"
    grad = Image.linear_gradient("L").resize((1600, 900)).convert("RGB")
    grad.save(photo)
    body = (
        "---\n"
        "title: 下見の台本\n"
        f"bg: {bg.as_posix()}\n"
        f"thumbnail_photo: {photo.as_posix()}\n"
        "---\n\n"
        "## オープニング\n\n"
        "キャスター: 下見の台本です。声を作らずに4コマを並べます。\n"
        "キャスター: 書き出す前に、顔に板がかからないかを見ます。\n\n"
        "## 山場の節\n@main: true\n\n"
        "解説: ここが山場です。数字は3つあります。\n"
        "解説: 1つ目は10、2つ目は20、3つ目は30です。\n"
        "キャスター: 以上が山場の節でした。\n"
    )
    path = tmp_path / "20990101_preview_test.md"
    path.write_text(body, encoding="utf-8")
    return path


def test_本編の下見の絵ができて4つの時点が並ぶ(tmp_path):
    out = tmp_path / "main.png"
    result = preview4.preview(_script(tmp_path), out_path=out)
    assert result.path == out and out.exists()
    labels = [shot.label for shot in result.shots]
    # 尺が70秒以下なので「60秒」の代わりに「中ほど」（facecheck.py と同じ）
    assert labels == ["冒頭 0:03", "山場の頭", "中ほど", "最後の5秒前"]
    assert all(shot.image.size == (1920, 1080) for shot in result.shots)
    # 本編の最後は15秒の終了画面（config titles.outro）まで入っている
    assert result.total > 15
    assert result.real_lines == 0          # 書き出していない台本は見積りだけ
    assert isinstance(result.problems, list)


def test_ショートの下見は縦の絵で出る(tmp_path):
    out = tmp_path / "short.png"
    result = preview4.preview(_script(tmp_path), short=True, out_path=out)
    assert out.exists()
    assert all(shot.image.size == (1080, 1920) for shot in result.shots)
    assert result.shots[0].label == "冒頭 0:03"


@pytest.mark.skipif(not faces.available(), reason="OpenCV が無い")
def test_顔の無い冒頭はバツの一覧で返る(tmp_path):
    result = preview4.preview(_script(tmp_path), out_path=tmp_path / "p.png")
    marks = [(name, mark) for name, mark, text in result.problems if text.startswith("(a)")]
    assert marks == [("冒頭 0:03（3.0秒）", "×")]


def test_写真だけの絵と比べて顔にかかった板を見つける():
    base = Image.new("RGB", (400, 300), (120, 110, 100))
    box = (100, 80, 100, 100)
    over = base.copy()
    ImageDraw.Draw(over).rectangle([80, 120, 320, 260], fill=(20, 30, 60))   # 顔の下6割に表
    edge = base.copy()
    ImageDraw.Draw(edge).rectangle([80, 168, 320, 260], fill=(20, 30, 60))   # 顎の先だけ
    assert preview4.covered(base, base, [box], []) == []
    hit = preview4.covered(over, base, [box], [])
    assert [m for m, _ in hit] == ["×"] and "60%" in hit[0][1]
    assert [m for m, _ in preview4.covered(edge, base, [box], [])] == ["△"]
    # facecheck の (c) がもう出ている顔は二重に出さない
    told = [("×", "(c) 顔に濃い板（表・テロップの帯）がかかっています（顔の枠の60%）: 顔 x100 y80 100px")]
    assert preview4.covered(over, base, [box], told) == []


def test_見積りの長さは話速と間で決まる():
    config = load_config()
    script = parse_script("---\ntitle: T\n---\n\n## 節\n\nキャスター: 十文字の文章ですよね。\n解説: 短い。\n")
    assert preview4.set_timing(script, config, None) == 0
    first, second = script.lines
    member = config.resolve_speaker(first.speaker)
    want = first.estimated_duration() / tts.voice_params(first, member)[0] * preview4.PACE + first.pause
    assert first.duration == pytest.approx(want)
    assert first.pause == tts.pause_for(config, first)
    assert second.start == pytest.approx(first.duration)


class _FakeEngine:
    """書き出しと同じ鍵で wav を置くための偽の ENGINE（VOICEVOX は呼ばない）。"""

    name = "engine"

    def sync_user_dict(self, words):
        pass

    def synthesize(self, line, member):
        return tts._silent_wav(1.5)


def test_書き出し済みの声があれば実尺を使う(tmp_path):
    config = load_config()
    body = "---\ntitle: T\n---\n\n## 節\n\nキャスター: 堂安律が話しました。\n解説: 短い。\n"
    built = parse_script(body)
    tts.synthesize_script(built, config, tmp_path, backend=_FakeEngine())
    fresh = parse_script(body)
    assert preview4.set_timing(fresh, config, tmp_path) == 2
    assert [l.duration for l in fresh.lines] == pytest.approx([l.duration for l in built.lines])
