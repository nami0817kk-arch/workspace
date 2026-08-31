"""動作の確からしさに関わる診断。

秘密情報の扱い、テストの有無、例外の握りつぶし、ファイルの肥大化。
「壊れていることに気づけるか」に直結するものを集めている。
"""

from __future__ import annotations

from ..models import Finding, Snapshot
from ..ruleset import _f, rule


@rule("secret.tracked-env-file")
def _tracked_env(snap: Snapshot) -> Finding | None:
    tracked = snap.get("tracked_env_file") or []
    if not tracked:
        return None
    return _f(
        snap, "secret.tracked-env-file",
        title=".env がリポジトリに入ってしまっている",
        why="API キーなどの実値が Git 履歴に残る。公開リポジトリなら即漏洩、"
            "非公開でも履歴からは消えないため早いほど傷が浅い。",
        action="該当ファイルを `git rm --cached` で追跡から外し、`.gitignore` に `.env` を追加する。"
               "併せて中身のキーをローテーションし、`.env.example` にキー名だけを残す。",
        severity="critical", category="security", topic="secrets",
        evidence=tracked,
    )

@rule("secret.hardcoded")
def _hardcoded_secret(snap: Snapshot) -> Finding | None:
    files = snap.get("hardcoded_secret_files") or []
    if not files:
        return None
    return _f(
        snap, "secret.hardcoded",
        title="コード中にキーらしき文字列が直書きされている疑い",
        why="そのままコミットされると鍵が漏れる。誤検知の可能性もあるので中身の確認が要る。",
        action="該当箇所を確認し、本物のキーなら環境変数（`os.environ`）に逃がしてローテーションする。"
               "ダミー値やテストデータなら、誤検知として無視してよい。",
        severity="critical", category="security", topic="secrets",
        evidence=files,
    )

@rule("secret.gitignore-env", kinds=("python", "node", "flutter"))
def _gitignore_env(snap: Snapshot) -> Finding | None:
    if not snap.has("uses_env_vars") or snap.has("gitignore_covers_env"):
        return None
    return _f(
        snap, "secret.gitignore-env",
        title="環境変数を使っているのに .gitignore が .env を除外していない",
        why="ローカルで `.env` を作った瞬間に、うっかりコミットする事故が起きる。",
        action="`.gitignore` に `.env` を追加する。1行で終わる割に事故の期待値が大きい。",
        severity="high", category="security", topic="secrets",
    )


# --- 動作の確からしさ -----------------------------------------------------

@rule("test.missing", kinds=("python", "node", "flutter"))
def _tests_missing(snap: Snapshot) -> Finding | None:
    if snap.has("has_tests") or snap.get("code_file_count", 0) < 2:
        return None
    return _f(
        snap, "test.missing",
        title="自動テストが1本もない",
        why=f"コードが {snap.get('code_file_count', 0)} ファイル / 約 {snap.get('code_lines', 0)} 行ある。"
            "この規模だと手で全部確かめるのは無理で、壊れたことに気づくのが本番になる。",
        action="まず一番壊れて困る関数1つに対してテストを1本書く。網羅は狙わない。"
               "`tests/test_<対象>.py` を作り、正常系1件・異常系1件から始める。",
        severity="high", category="reliability", topic="tests",
    )

@rule("test.empty-dir")
def _empty_test_dir(snap: Snapshot) -> Finding | None:
    if not snap.has("has_empty_test_dir") or snap.has("has_tests"):
        return None
    return _f(
        snap, "test.empty-dir",
        title="tests/ が空のまま置かれている",
        why="雛形だけ作って中身が入っていない状態。あるように見えて何も守っていない。",
        action="最初の1本を書くか、当面書かないなら tests/ を消して README に方針を書く。"
               "「あとで」を残しておくと、テストが無いことに気づけなくなる。",
        severity="low", category="reliability", topic="tests",
    )

@rule("quality.swallowed-exception")
def _swallowed(snap: Snapshot) -> Finding | None:
    spots = snap.get("swallowed_exceptions") or []
    if not spots:
        return None
    return _f(
        snap, "quality.swallowed-exception",
        title="例外を握りつぶしている箇所がある",
        why="`except ...: pass` は、失敗しても呼び出し側が何も知らないまま先へ進む。"
            "定期実行のように人が見ていない場所だと、壊れていることに誰も気づけない。",
        action="最低でも失敗内容を print / logging で残す。"
               "「失敗しても続行してよい」場所なら、なぜよいのかをコメントに書く。",
        severity="medium", category="reliability", topic="error-handling",
        evidence=spots[:8],
    )

@rule("quality.bare-except")
def _bare_except(snap: Snapshot) -> Finding | None:
    spots = snap.get("bare_excepts") or []
    if not spots:
        return None
    return _f(
        snap, "quality.bare-except",
        title="例外の種類を指定しない except がある",
        why="`except:` は KeyboardInterrupt や SystemExit まで捕まえるので、"
            "Ctrl-C で止まらない・CI が終われない、といった挙動になる。",
        action="`except Exception:` にするか、捕まえたい例外を明示する。",
        severity="medium", category="reliability", topic="error-handling",
        evidence=spots[:8],
    )

@rule("quality.oversized-file")
def _oversized(snap: Snapshot) -> Finding | None:
    files = snap.get("oversized_files") or []
    if not files:
        return None
    return _f(
        snap, "quality.oversized-file",
        title="1ファイルが大きくなりすぎている",
        why="変更のたびに全体を読み直すことになり、手を入れる心理的コストが上がる。",
        action="責務ごとにモジュールを分ける。まず「他から呼ばれていない塊」を別ファイルに出すのが安全。",
        severity="low", category="quality", topic="structure",
        evidence=files,
    )


@rule("quality.long-function")
def _long_function(snap: Snapshot) -> Finding | None:
    spots = snap.get("long_functions") or []
    if not spots:
        return None
    return _f(
        snap, "quality.long-function",
        title="1つの関数が長くなりすぎている",
        why="100行を超える関数は、頭に入れながら読むのが難しい。"
            "変更のたびに全体を追い直すことになり、テストも書きづらい。",
        action="関数の中で「まとまった仕事」をしている塊を、名前を付けて切り出す。"
               "切り出した先はテストしやすくなるので、そこから1本書ける。",
        # ファイルの行数より、直す場所を名指しできるこちらを優先して見せる
        severity="medium", category="quality", topic="structure",
        evidence=spots[:8],
    )
