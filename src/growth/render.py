"""出力の整形。Markdown ダイジェスト / ダッシュボード / Issue 本文。

提案には必ず「Claude にそのまま貼れる依頼文」を添える。
毎回こちらが依頼文を考えるのをやめるのがこのシステムの目的なので、
指摘だけして終わりにはしない。
"""

from __future__ import annotations

from datetime import datetime, timezone

from .ledger import Ledger
from .models import CATEGORY_LABEL_JA, SEVERITY_LABEL_JA, Proposal, Snapshot
from .planner import Plan

MARKER_PREFIX = "growth-loop:"
SPARK = "▁▂▃▄▅▆▇█"

KIND_LABEL_JA = {
    "python": "Python",
    "flutter": "Flutter",
    "node": "Node",
    "scaffold": "雛形のみ",
    "other": "その他",
    "unknown": "取得不可",
}


def _today() -> str:
    return datetime.now(timezone.utc).date().isoformat()


def issue_marker(fingerprint: str) -> str:
    """Issue の重複起票を防ぐための埋め込みマーカー。"""
    return f"<!-- {MARKER_PREFIX}{fingerprint} -->"


def claude_prompt(proposal: Proposal, repo_slug: str) -> str:
    """Claude にそのまま渡せる依頼文。"""
    f = proposal.finding
    lines = [
        f"{repo_slug} の「{f.title}」に対応してください。",
        "",
        f"背景: {f.why}",
        f"やること: {f.action}",
    ]
    if f.exemplar:
        lines.append(f"お手本: {f.exemplar} の実装に合わせる。")
    # お手本の情報は上で書いているので、根拠からは落として重複を避ける
    evidence = [e for e in f.evidence if not e.startswith("お手本:")]
    if evidence:
        lines.append("該当: " + " / ".join(evidence[:5]))
    lines += [
        "",
        "小さく1コミットにまとめ、なぜその変更が要るかを README か"
        "コミットメッセージに一行残してください。",
    ]
    return "\n".join(lines)


def _sparkline(values: list[int]) -> str:
    if not values:
        return ""
    if len(set(values)) == 1:
        return SPARK[3] * len(values)
    lo, hi = min(values), max(values)
    return "".join(SPARK[int((v - lo) / (hi - lo) * (len(SPARK) - 1))] for v in values)


def _delta_label(delta: int) -> str:
    if delta > 0:
        return f"+{delta}"
    if delta < 0:
        return str(delta)
    return "±0"


def _proposal_block(proposal: Proposal, snapshots: list[Snapshot], index: int) -> list[str]:
    f = proposal.finding
    slug = next(
        (s.ref.slug for s in snapshots if s.ref.key == f.ref_key), f.ref_key
    )
    sev = SEVERITY_LABEL_JA.get(f.severity, f.severity)
    cat = CATEGORY_LABEL_JA.get(f.category, f.category)
    age = "" if proposal.is_new else f" / {proposal.seen_count}回目"
    out = [
        f"### {index}. [{sev}] {f.title}",
        "",
        f"- 対象: `{slug}`",
        f"- 種別: {cat}{age}",
        f"- なぜ: {f.why}",
        f"- やること: {f.action}",
    ]
    if f.evidence:
        out.append("- 根拠: " + " / ".join(f"`{e}`" for e in f.evidence[:6]))
    if proposal.issue_url:
        out.append(f"- Issue: {proposal.issue_url}")
    out += [
        "",
        "<details><summary>Claude にそのまま貼る依頼文</summary>",
        "",
        "```",
        claude_prompt(proposal, slug),
        "```",
        "",
        f"やらない場合: `python -m growth dismiss {proposal.fingerprint} --note \"理由\"`",
        "</details>",
        "",
    ]
    return out


def render_digest(plan: Plan, ledger: Ledger) -> str:
    """その回のダイジェスト（docs/growth/YYYY-MM-DD.md）。"""
    lines = [
        f"# 成長ループ ダイジェスト {_today()}",
        "",
        f"対象 {len(plan.scores)} プロジェクト / 平均成熟度 **{plan.average_score}** / "
        f"未対応 {len(plan.proposals) + len(plan.deferred)} 件",
        "",
    ]

    if plan.resolved:
        lines += ["## ✅ 前回から解決したもの", ""]
        for item in plan.resolved:
            lines.append(f"- `{item['project']}` {item['title']}")
        lines.append("")

    if plan.regressed:
        lines += ["## ⚠️ 一度直ったのに戻ったもの", ""]
        for item in plan.regressed:
            lines.append(f"- `{item['project']}` {item['title']}")
        lines.append("")

    if plan.proposals:
        lines += ["## 今回の推奨アクション", ""]
        for i, proposal in enumerate(plan.proposals, start=1):
            lines += _proposal_block(proposal, plan.snapshots, i)
    else:
        lines += ["## 今回の推奨アクション", "", "なし。すべて対応済みか、保留中。", ""]

    if plan.deferred:
        lines += [
            "## 見送った分",
            "",
            f"1回あたりの提案数の上限に達したため、{len(plan.deferred)} 件は次回以降に回した。",
            "",
        ]
        for proposal in plan.deferred[:20]:
            f = proposal.finding
            lines.append(
                f"- `{f.ref_key}` {f.title}（{SEVERITY_LABEL_JA.get(f.severity, f.severity)}）"
            )
        lines.append("")

    lines += _score_table(plan)
    return "\n".join(lines).rstrip() + "\n"


def _score_table(plan: Plan) -> list[str]:
    lines = ["## プロジェクト別の成熟度", "", "| プロジェクト | 種別 | 成熟度 | 前回比 | 未対応 |", "|---|---|---:|---:|---:|"]
    open_by_project: dict[str, int] = {}
    for proposal in [*plan.proposals, *plan.deferred]:
        key = proposal.finding.ref_key
        open_by_project[key] = open_by_project.get(key, 0) + 1

    for snap in sorted(plan.snapshots, key=lambda s: -plan.scores.get(s.ref.key, -1)):
        if snap.unavailable:
            continue
        key = snap.ref.key
        lines.append(
            f"| `{key}` | {KIND_LABEL_JA.get(snap.kind, snap.kind)} | "
            f"{plan.scores.get(key, 0)} | {_delta_label(plan.score_delta.get(key, 0))} | "
            f"{open_by_project.get(key, 0)} |"
        )
    lines.append("")
    return lines


def render_dashboard(plan: Plan, ledger: Ledger) -> str:
    """常に最新に置き換わるダッシュボード（GROWTH.md）。"""
    history = ledger.history[-24:]
    trend = _sparkline([h.get("average", 0) for h in history])
    resolved_total = sum(
        1 for e in ledger.proposals.values() if e.get("status") == "resolved"
    )

    lines = [
        "# 成長ダッシュボード",
        "",
        "このファイルは `growth-loop` ワークフローが自動生成している。手で編集しても次回上書きされる。",
        "",
        f"- 最終更新: {_today()}",
        f"- 平均成熟度: **{plan.average_score}** {trend and f'`{trend}`'}",
        f"- これまでに解決: **{resolved_total}** 件",
        f"- 未対応: **{len(plan.proposals) + len(plan.deferred)}** 件",
        "",
    ]
    lines += _score_table(plan)

    lines += ["## 次にやること", ""]
    if plan.proposals:
        for i, proposal in enumerate(plan.proposals[:5], start=1):
            f = proposal.finding
            sev = SEVERITY_LABEL_JA.get(f.severity, f.severity)
            lines.append(f"{i}. **[{sev}] {f.title}** — `{f.ref_key}`")
            # 箇条書きが崩れないよう、複数行のアクションは1行に畳む
            lines.append("   - " + " ".join(f.action.split("\n")))
        lines.append("")
        lines.append(f"詳細と依頼文は `docs/growth/{_today()}.md` を見る。")
    else:
        lines.append("なし。")
    lines.append("")

    if plan.resolved:
        lines += ["## 直近で解決したもの", ""]
        for item in plan.resolved[:10]:
            lines.append(f"- `{item['project']}` {item['title']}")
        lines.append("")

    lines += [
        "## 使い方",
        "",
        "```bash",
        "python -m growth run --workspace ../growth-workspace   # 観測 → 提案 → 出力",
        "python -m growth status                       # 今の未対応一覧",
        "python -m growth dismiss <fingerprint> -n 理由 # その提案を今後出さない",
        "python -m growth done <fingerprint>            # 対応済みにする",
        "```",
        "",
    ]
    return "\n".join(lines).rstrip() + "\n"


def render_issue(proposal: Proposal, repo_slug: str) -> tuple[str, str]:
    """(タイトル, 本文) を返す。"""
    f = proposal.finding
    sev = SEVERITY_LABEL_JA.get(f.severity, f.severity)
    title = f"[成長ループ/{sev}] {f.title}"
    body_lines = [
        issue_marker(proposal.fingerprint),
        "",
        f"**対象**: `{repo_slug}`",
        f"**種別**: {CATEGORY_LABEL_JA.get(f.category, f.category)}",
        "",
        "## なぜ",
        "",
        f.why,
        "",
        "## やること",
        "",
        f.action,
        "",
    ]
    if f.evidence:
        body_lines += ["## 根拠", "", *[f"- `{e}`" for e in f.evidence[:10]], ""]
    body_lines += [
        "## Claude への依頼文",
        "",
        "```",
        claude_prompt(proposal, repo_slug),
        "```",
        "",
        "---",
        f"この Issue は ai-lab の成長ループが自動起票した（ルール `{f.rule_id}` / "
        f"指紋 `{proposal.fingerprint}`）。不要なら Issue を close すれば、次回以降は起票しない。",
    ]
    return title, "\n".join(body_lines)


def render_summary_issue(plan: Plan, ledger: Ledger) -> tuple[str, str, str]:
    """(マーカー, タイトル, 本文) を返す。

    週次の結果を1本の Issue にまとめて通知する。各リポジトリへの個別起票と違って
    既定の GITHUB_TOKEN だけで動くので、追加の設定なしに「向こうから伝わる」状態になる。
    """
    date = _today()
    marker = f"<!-- {MARKER_PREFIX}digest:{date} -->"
    title = f"[成長ループ] {date} の点検結果 — 提案 {len(plan.proposals)} 件"

    body = [
        marker,
        "",
        f"対象 {len(plan.scores)} プロジェクト / 平均成熟度 **{plan.average_score}** / "
        f"未対応 {len(plan.proposals) + len(plan.deferred)} 件",
        "",
    ]
    if plan.resolved:
        body += ["### 前回から解決したもの", ""]
        body += [f"- `{i['project']}` {i['title']}" for i in plan.resolved]
        body.append("")
    if plan.regressed:
        body += ["### 一度直ったのに戻ったもの", ""]
        body += [f"- `{i['project']}` {i['title']}" for i in plan.regressed]
        body.append("")

    body += ["### 今回の推奨アクション", ""]
    if plan.proposals:
        for i, proposal in enumerate(plan.proposals, start=1):
            f = proposal.finding
            sev = SEVERITY_LABEL_JA.get(f.severity, f.severity)
            body.append(f"{i}. **[{sev}] {f.title}** — `{f.ref_key}`")
            body.append("   - " + " ".join(f.action.split("\n")))
    else:
        body.append("なし。")
    body += [
        "",
        f"依頼文つきの詳細は [`docs/growth/{date}.md`](docs/growth/{date}.md)、"
        "全体の状況は [`GROWTH.md`](GROWTH.md) を見る。",
        "",
        "---",
        "この Issue は成長ループが自動起票した。対応が済んだら close してよい"
        "（次回の点検結果は新しい Issue として立つ）。",
    ]
    return marker, title, "\n".join(body)


def render_status(ledger: Ledger) -> str:
    """CLI 用のテキスト出力。"""
    rows = [
        (fp, e) for fp, e in ledger.proposals.items() if e.get("status") == "open"
    ]
    rows.sort(key=lambda r: (r[1].get("project", ""), r[1].get("rule_id", "")))
    if not rows:
        return "未対応の提案はありません。"
    out = [f"未対応 {len(rows)} 件", ""]
    for fp, entry in rows:
        seen = entry.get("seen_count", 1)
        out.append(f"  {fp}  {entry.get('project', '?'):<34} {entry.get('title', '?')} ({seen}回目)")
    return "\n".join(out)
