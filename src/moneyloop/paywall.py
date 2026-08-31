"""無料版と有料版のレンダリング。

無料版は「価値の証明」だけを渡し、結論は渡さない。
ここでの分量調整が無料→有料の転換率を決める唯一のレバー。
"""

from __future__ import annotations

from .models import Issue, Niche
from .pricing import Plan

UPGRADE_CTA = "この続き（全{n}項目の分析と、明日やることリスト）は{plan}プラン（月${price:.0f}）でお読みいただけます。"


def render_free(issue: Issue, niche: Niche, paid_plan: Plan | None = None) -> str:
    """無料版: タイトル + ティザー + 要点の先頭1件 + アップグレード導線。"""
    parts = [f"# {issue.title}", "", f"*{niche.name} / {issue.issue_date.isoformat()}*", "", issue.teaser_md]
    if issue.takeaways:
        parts += ["", "## 今号の要点", f"- {issue.takeaways[0]}"]
        if len(issue.takeaways) > 1:
            parts.append(f"- ほか{len(issue.takeaways) - 1}点（有料版）")
    if paid_plan:
        parts += [
            "",
            "---",
            "",
            UPGRADE_CTA.format(n=len(issue.item_hashes), plan=paid_plan.name, price=paid_plan.monthly_usd),
        ]
    return "\n".join(parts) + "\n"


def render_paid(issue: Issue, niche: Niche) -> str:
    """有料版: 全文。"""
    parts = [f"# {issue.title}", "", f"*{niche.name} / {issue.issue_date.isoformat()}*", "", issue.teaser_md]
    if issue.takeaways:
        parts += ["", "## 今号の要点"] + [f"- {t}" for t in issue.takeaways]
    parts += ["", "---", "", issue.body_md]
    return "\n".join(parts) + "\n"


def render_for_plan(issue: Issue, niche: Niche, plan: Plan, paid_plan: Plan | None = None) -> tuple[str, str]:
    """プランに応じた本文と variant 名を返す。"""
    if plan.paywalled:
        return render_paid(issue, niche), "paid"
    return render_free(issue, niche, paid_plan), "free"
