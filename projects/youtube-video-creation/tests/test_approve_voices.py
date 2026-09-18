"""声の無い台本は approve を通らない（2026-09-17 ユーザー指示「声は必ず」）。"""
import subprocess
import sys
from pathlib import Path

HEAD = "---\ntitle: ためし\nformat: news\n---\n\n## 本編\n"


def _run(path, *extra):
    return subprocess.run(
        [sys.executable, "-m", "src.cli", "approve", str(path), *extra],
        cwd=Path(__file__).resolve().parents[1],
        capture_output=True, text=True, encoding="utf-8", errors="replace")


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
    done = _run(script, "--no-voices", "クラブ紹介なので声は入れない")
    assert done.returncode == 0, done.stderr
    assert "声なし" in done.stdout
