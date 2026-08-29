"""成長ループの CLI。

    python -m growth run       観測 → 提案 → ダイジェスト/ダッシュボード生成
    python -m growth status    未対応の提案一覧
    python -m growth dismiss   その提案を今後出さない（学習させる）
    python -m growth done      対応済みにする
    python -m growth fetch     対象リポジトリを浅くクローン/更新する
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from . import github, rules
from .ledger import DISMISSED, RESOLVED, SNOOZED, Ledger
from .planner import build_plan
from .registry import expand_subprojects, load_registry, repo_names
from .render import (
    issue_marker,
    render_dashboard,
    render_digest,
    render_issue,
    render_status,
    render_summary_issue,
)
from .survey import collect

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REGISTRY = REPO_ROOT / "growth" / "projects.toml"
DEFAULT_LEDGER = REPO_ROOT / "growth" / "ledger.json"
DEFAULT_DIGEST_DIR = REPO_ROOT / "docs" / "growth"
DEFAULT_DASHBOARD = REPO_ROOT / "GROWTH.md"


def _today() -> str:
    return datetime.now(timezone.utc).date().isoformat()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="growth", description="プロジェクト成長ループ")
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    sub = parser.add_subparsers(dest="command", required=True)

    run = sub.add_parser("run", help="観測して提案を出す")
    run.add_argument("--workspace", type=Path, required=True,
                     help="各リポジトリのクローンが並んでいるディレクトリ")
    run.add_argument("--digest-dir", type=Path, default=DEFAULT_DIGEST_DIR)
    run.add_argument("--dashboard", type=Path, default=DEFAULT_DASHBOARD)
    run.add_argument("--publish-issues", action="store_true",
                     help="提案を対象リポジトリの Issue として起票する（要 GROWTH_TOKEN）")
    run.add_argument("--summary-issue", metavar="OWNER/REPO", default=None,
                     help="点検結果をまとめた Issue を1本立てて通知する")
    run.add_argument("--dry-run", action="store_true", help="ファイルを書かず結果だけ表示する")
    run.add_argument("--json", action="store_true", help="結果を JSON で標準出力に出す")

    fetch = sub.add_parser("fetch", help="対象リポジトリをクローン/更新する")
    fetch.add_argument("--workspace", type=Path, required=True)

    sub.add_parser("status", help="未対応の提案一覧")

    dismiss = sub.add_parser("dismiss", help="この提案を今後出さない")
    dismiss.add_argument("fingerprint")
    dismiss.add_argument("-n", "--note", default=None, help="やらない理由")

    snooze = sub.add_parser("snooze", help="見たうえで今はやらない（理由を残す）")
    snooze.add_argument("fingerprint")
    snooze.add_argument("-n", "--note", required=True, help="今やらない理由")

    done = sub.add_parser("done", help="対応済みにする")
    done.add_argument("fingerprint")

    return parser


def _load_refs(registry_path: Path, workspace: Path | None):
    refs, config = load_registry(registry_path)
    if workspace is not None:
        refs = expand_subprojects(refs, workspace, registry_path)
    return refs, config


def cmd_fetch(args) -> int:
    refs, _ = _load_refs(args.registry, None)
    failed = 0
    for repo in repo_names(refs):
        try:
            path = github.clone_repo(repo, args.workspace)
            print(f"  ok   {repo} -> {path}")
        except Exception as exc:  # noqa: BLE001 - 1件失敗しても他は続ける
            failed += 1
            print(f"  fail {repo}: {exc}", file=sys.stderr)
    return 1 if failed else 0


def cmd_run(args) -> int:
    refs, config = _load_refs(args.registry, args.workspace)
    snapshots = [collect(args.workspace, ref) for ref in refs if ref.active]

    missing = [s.ref.key for s in snapshots if s.unavailable]
    if missing:
        print(f"[warn] クローンが見つからず観測できなかった: {', '.join(missing)}", file=sys.stderr)
    if all(s.unavailable for s in snapshots):
        print("[error] 観測できたプロジェクトが1つもありません。先に `growth fetch` を実行してください。",
              file=sys.stderr)
        return 2

    ledger = Ledger.load(args.ledger)
    findings = rules.run_all(snapshots)
    plan = build_plan(snapshots, findings, ledger, config)

    publish = args.publish_issues or bool(config.get("publish_issues"))
    if publish and not args.dry_run:
        _publish_issues(plan, ledger)

    summary_repo = args.summary_issue or config.get("summary_issue_repo")
    if summary_repo and not args.dry_run:
        _publish_summary(plan, ledger, summary_repo)

    digest = render_digest(plan, ledger)
    dashboard = render_dashboard(plan, ledger)

    if args.dry_run:
        print(digest)
    else:
        args.digest_dir.mkdir(parents=True, exist_ok=True)
        (args.digest_dir / f"{_today()}.md").write_text(digest, encoding="utf-8")
        args.dashboard.write_text(dashboard, encoding="utf-8")
        ledger.save()

    if args.json:
        print(json.dumps(plan.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(
            f"プロジェクト {len(plan.scores)} 件 / 平均成熟度 {plan.average_score} / "
            f"提案 {len(plan.proposals)} 件（見送り {len(plan.deferred)}） / "
            f"解決 {len(plan.resolved)} 件 / 退行 {len(plan.regressed)} 件"
        )
        for proposal in plan.proposals:
            f = proposal.finding
            print(f"  [{f.severity:<8}] {f.ref_key:<34} {f.title}")
    return 0


def _publish_issues(plan, ledger: Ledger) -> None:
    slug_of = {s.ref.key: s.ref.slug for s in plan.snapshots}
    repo_of = {s.ref.key: s.ref.repo for s in plan.snapshots}
    for proposal in plan.proposals:
        if proposal.issue_url:
            continue
        repo = repo_of.get(proposal.finding.ref_key)
        if not repo:
            continue
        marker = issue_marker(proposal.fingerprint)
        try:
            existing = github.find_issue_by_marker(repo, marker)
            if existing:
                ledger.attach_issue(proposal.fingerprint, existing.get("html_url", ""))
                if existing.get("state") == "closed":
                    # 人が閉じた = やらない判断。以後この提案は出さない。
                    ledger.mark(proposal.fingerprint, DISMISSED, note="Issue が閉じられた")
                continue
            title, body = render_issue(proposal, slug_of.get(proposal.finding.ref_key, repo))
            url = github.create_issue(repo, title, body)
            if url:
                ledger.attach_issue(proposal.fingerprint, url)
                proposal.issue_url = url
                print(f"  issue {url}")
        except github.GitHubError as exc:
            print(f"[warn] Issue 起票に失敗 ({repo}): {exc}", file=sys.stderr)


def _publish_summary(plan, ledger: Ledger, repo: str) -> None:
    """週次の結果を1本の Issue にまとめて立てる。同じ日に二重起票はしない。

    重複判定はまず台帳で行う。GitHub の Issue 一覧 API は作成直後の Issue を
    返さないことがあり、API だけを根拠にすると同じ日に2本立つ。
    """
    date = _today()
    existing = ledger.summary_issue_for(date)
    if existing:
        print(f"  summary: 本日分は起票済み ({existing})")
        return

    marker, title, body = render_summary_issue(plan, ledger)
    try:
        found = github.find_issue_by_marker(repo, marker)
    except github.GitHubError as exc:
        # 確認できなかったときは起票しない。二重に立てるより出さないほうがまし。
        print(f"[warn] 既存 Issue を確認できなかったため起票を見送る ({repo}): {exc}",
              file=sys.stderr)
        return
    if found:
        ledger.record_summary_issue(date, found.get("html_url", ""))
        print(f"  summary: {repo} には本日分の Issue が既にある。起票しない。")
        return

    try:
        url = github.create_issue(repo, title, body)
    except github.GitHubError as exc:
        print(f"[warn] サマリ Issue の起票に失敗 ({repo}): {exc}", file=sys.stderr)
        return
    if url:
        ledger.record_summary_issue(date, url)
        print(f"  summary {url}")


def cmd_status(args) -> int:
    print(render_status(Ledger.load(args.ledger)))
    return 0


def cmd_mark(args, status: str) -> int:
    ledger = Ledger.load(args.ledger)
    note = getattr(args, "note", None)
    if not ledger.mark(args.fingerprint, status, note):
        print(f"指紋 {args.fingerprint} は台帳にありません。", file=sys.stderr)
        return 1
    ledger.save()
    label = {
        DISMISSED: "今後出しません",
        RESOLVED: "対応済みにしました",
        SNOOZED: "保留にしました（理由つきで残ります）",
    }[status]
    print(f"{args.fingerprint}: {label}")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "run":
        return cmd_run(args)
    if args.command == "fetch":
        return cmd_fetch(args)
    if args.command == "status":
        return cmd_status(args)
    if args.command == "dismiss":
        return cmd_mark(args, DISMISSED)
    if args.command == "snooze":
        return cmd_mark(args, SNOOZED)
    if args.command == "done":
        return cmd_mark(args, RESOLVED)
    return 1
