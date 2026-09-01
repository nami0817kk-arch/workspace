"""ブラウザ自動操作の共通設定。

Claude Code のリモート実行環境(コンテナ)とローカル PC の両方で
同じコードが動くように、Chromium の実行ファイルと起動引数を解決する。
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

# リモート実行環境で HTTPS を終端しているエージェントプロキシの CA。
# ローカル PC には存在しないので、その場合は何もしない。
AGENT_PROXY_CA = Path("/root/.ccr/agent-proxy-ca.crt")

# Playwright にプリインストールされている Chromium(リモート環境のみ)。
PREINSTALLED_CHROMIUM = Path("/opt/pw-browsers/chromium")


def chromium_executable() -> str | None:
    """Playwright の ``executable_path`` に渡す値を返す。

    None を返した場合は Playwright が自前でダウンロードした Chromium を使う。
    リモート環境では Playwright のバージョンとプリインストール版のビルド番号が
    ずれているため、実行ファイルを明示しないと起動できない。
    """
    env_path = os.environ.get("CHROMIUM_PATH")
    if env_path and Path(env_path).exists():
        return env_path
    if PREINSTALLED_CHROMIUM.exists():
        return str(PREINSTALLED_CHROMIUM)
    return None


def _ca_spki_hash(cert: Path) -> str | None:
    """CA 証明書の公開鍵 (SPKI) の SHA-256 を base64 で返す。"""
    if not cert.exists() or shutil.which("openssl") is None:
        return None

    pipeline = (
        f'openssl x509 -in "{cert}" -pubkey -noout '
        "| openssl pkey -pubin -outform der "
        "| openssl dgst -sha256 -binary "
        "| openssl enc -base64"
    )
    try:
        result = subprocess.run(
            ["sh", "-c", pipeline],
            capture_output=True,
            text=True,
            timeout=15,
            check=True,
        )
    except (subprocess.SubprocessError, OSError):
        return None
    return result.stdout.strip() or None


def launch_args() -> list[str]:
    """この環境で必要な Chromium の追加起動引数を返す。

    リモート実行環境では HTTPS がプロキシで再終端されるため、Chromium が
    証明書を検証できない。証明書検証そのものは有効なままにして、
    このプロキシ CA の公開鍵だけを SPKI 指定で例外にする。
    ローカル PC では空リストになる。
    """
    spki = _ca_spki_hash(AGENT_PROXY_CA)
    return [f"--ignore-certificate-errors-spki-list={spki}"] if spki else []
