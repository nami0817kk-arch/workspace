"""配信。ファイル出力とWebhookを標準装備し、実際のメール送信は外部サービスに委ねる。

配信基盤を自前で持つとドメイン評判・法令対応・バウンス処理を抱え込むことになるため、
ここでは「配信サービスに渡す」までを責務とする。
"""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Protocol

from .models import Issue, Niche, Subscriber
from .paywall import render_for_plan
from .pricing import Plan
from .storage import Storage


@dataclass
class DeliveryResult:
    free: int = 0
    paid: int = 0
    skipped: int = 0
    errors: list[str] = field(default_factory=list)


class Deliverer(Protocol):
    def send(self, issue: Issue, niche: Niche, subscriber: Subscriber, body_md: str, variant: str) -> None: ...


class FileDeliverer:
    """号ごとに free/paid のMarkdownを1回だけ書き出す。

    購読者ごとに同じ内容を書き直しても意味がないので、variant単位で1ファイル。
    """

    def __init__(self, output_dir: Path) -> None:
        self.output_dir = Path(output_dir)
        self.written: set[Path] = set()

    def send(self, issue: Issue, niche: Niche, subscriber: Subscriber, body_md: str, variant: str) -> None:
        path = self.output_dir / issue.niche / f"{issue.issue_date.isoformat()}-{variant}.md"
        if path in self.written:
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body_md, encoding="utf-8")
        self.written.add(path)


class WebhookDeliverer:
    """配信SaaS（Buttondown/Substack/Zapier等）へJSONをPOSTする。"""

    def __init__(self, url: str, timeout: float = 20.0) -> None:
        self.url = url
        self.timeout = timeout

    def send(self, issue: Issue, niche: Niche, subscriber: Subscriber, body_md: str, variant: str) -> None:
        payload = json.dumps(
            {
                "email": subscriber.email,
                "plan": subscriber.plan,
                "variant": variant,
                "niche": issue.niche,
                "issue_date": issue.issue_date.isoformat(),
                "subject": issue.title,
                "body_markdown": body_md,
            },
            ensure_ascii=False,
        ).encode("utf-8")
        req = urllib.request.Request(
            self.url, data=payload, headers={"Content-Type": "application/json"}, method="POST"
        )
        with urllib.request.urlopen(req, timeout=self.timeout):
            pass


def deliver_issue(
    storage: Storage,
    issue: Issue,
    niche: Niche,
    subscribers: list[Subscriber],
    plans: dict[str, Plan],
    deliverers: list[Deliverer],
) -> DeliveryResult:
    """購読者ごとにプラン相当の版を配信する。

    配信記録は先に取り、同じ号を同じ人へ二度送らない。
    """
    # 無料版のCTAは最安の有料プランを提示する（最初の一歩の心理的ハードルを下げる）。
    paid_plan = min(
        (p for p in plans.values() if p.paywalled and p.monthly_usd > 0),
        key=lambda p: p.monthly_usd,
        default=None,
    )
    result = DeliveryResult()

    for sub in subscribers:
        plan = plans.get(sub.plan)
        if plan is None:
            result.errors.append(f"{sub.email}: 未定義プラン '{sub.plan}' のためスキップ")
            result.skipped += 1
            continue

        body_md, variant = render_for_plan(issue, niche, plan, paid_plan)

        if not storage.record_delivery(issue.id, sub.id, variant):
            result.skipped += 1
            continue

        for deliverer in deliverers:
            try:
                deliverer.send(issue, niche, sub, body_md, variant)
            except (urllib.error.URLError, OSError) as exc:
                result.errors.append(f"{sub.email}: 配信失敗 ({exc})")

        if variant == "paid":
            result.paid += 1
        else:
            result.free += 1

    return result
