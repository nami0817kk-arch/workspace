"""声の無い台本は approve を通らない（2026-09-17 ユーザー指示「声は必ず」）。

流れの点検（tools/flow.py）の控えが無くても通らない（2026-09-22）。
"""
import os
import subprocess
import sys
from contextlib import contextmanager
from pathlib import Path

HEAD = "---\ntitle: ためし\nformat: news\n---\n\n## 本編\n"
VOICED = HEAD + "キャスター: 何かが起きました。\n\nネット民: すごい\n"
ROOT = Path(__file__).resolve().parents[1]


def _run(path, *extra):
    return subprocess.run(
        [sys.executable, "-m", "src.cli", "approve", str(path), *extra],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")


@contextmanager
def _flow_record(script: Path, older: bool = False):
    """流れの点検の控え。approve はこれが無いと通らない（2026-09-22）。"""
    record = ROOT / "output" / "flow" / (script.stem + ".md")
    record.parent.mkdir(parents=True, exist_ok=True)
    record.write_text("# 流れの点検\n無し\n", encoding="utf-8")
    if older:
        stamp = script.stat().st_mtime - 60
        os.utime(record, (stamp, stamp))
    try:
        yield record
    finally:
        record.unlink(missing_ok=True)


def test_声が無い台本は通らない(tmp_path):
    """`draft` は知らせるだけで**止めていなかった**。

    2026-09-17 に、反応の無い台本を3本作ってそのまま出しかけた。
    まとめサイトが試合に追いついていない朝は、待つのが正しい。
    """
    script = tmp_path / "koe_nashi.md"
    script.write_text(HEAD + "キャスター: 何かが起きました。\n", encoding="utf-8")
    done = _run(script)
    assert done.returncode == 1
    assert "ネットの声が1件もありません" in done.stderr


def test_理由を書けば通る(tmp_path):
    """紹介もの（プレミア20クラブ紹介）は、声を入れない型だと決めてある。"""
    script = tmp_path / "shoukai.md"
    script.write_text(HEAD + "キャスター: どんなクラブなのか。\n", encoding="utf-8")
    with _flow_record(script):
        done = _run(script, "--no-voices", "クラブ紹介なので声は入れない")
    assert done.returncode == 0, done.stderr
    assert "声なし" in done.stdout


def test_流れの点検の控えが無ければ通らない(tmp_path):
    """9/13 に作った流れの点検を使わないまま、9/22 に「何を言いたいか分からない」を
    3本で言われた。人の注意に頼らず、関門にする。"""
    script = tmp_path / "nagare_nashi.md"
    script.write_text(VOICED, encoding="utf-8")
    done = _run(script)
    assert done.returncode == 1
    assert "流れの点検の控え" in done.stderr


def test_流れの点検の控えが台本より古ければ通らない(tmp_path):
    """台本を直したら点検もやり直す。"""
    script = tmp_path / "nagare_furui.md"
    script.write_text(VOICED, encoding="utf-8")
    with _flow_record(script, older=True):
        done = _run(script)
    assert done.returncode == 1
    assert "台本より古い" in done.stderr


def test_流れの点検の控えがあれば通る(tmp_path):
    script = tmp_path / "nagare_ok.md"
    script.write_text(VOICED, encoding="utf-8")
    with _flow_record(script):
        done = _run(script)
    assert done.returncode == 0, done.stderr
