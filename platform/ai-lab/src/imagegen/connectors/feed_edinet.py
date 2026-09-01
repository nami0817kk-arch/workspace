"""EDINET（金融庁）の提出書類一覧。

有価証券報告書・四半期報告書・大量保有報告書などの**一次情報そのもの**が出る。
株の分析で「報道ではなく提出書類で確かめる」ときの入口。

- API v2 は無料だが登録が要る（Subscription-Key）
- 一覧は日付単位。証券コードを渡したときは、その日の一覧から絞り込む
- 書類そのもの（PDF / XBRL）の取得にも同じキーが要るので、
  返す URL にはキーを載せない（出力や JSON に秘密を混ぜないため）
"""

from __future__ import annotations

import re
from datetime import date

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError
from ..core.registry import register
from ..core.types import FeedItem

API_BASE = "https://api.edinet-fsa.go.jp/api/v2"
DOCUMENTS_URL = f"{API_BASE}/documents.json"

DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
CODE_RE = re.compile(r"^\d{4,5}$")

#: 書類種別コード（よく出るものだけ。一覧は EDINET の仕様書にある）
DOC_TYPES = {
    "120": "有価証券報告書",
    "130": "訂正有価証券報告書",
    "140": "四半期報告書",
    "160": "半期報告書",
    "180": "臨時報告書",
    "350": "大量保有報告書",
    "360": "変更報告書",
    "030": "有価証券届出書",
}


@register
class EdinetFeed(Connector):
    name = "edinet"
    category = "feed"
    summary = "EDINET の提出書類一覧（有報・四半期・大量保有などの一次情報）"
    priority = 10
    auth = AuthSpec(
        env=("EDINET_API_KEY",),
        signup_url="https://api.edinet-fsa.go.jp/api/auth/index.html",
        note="無料。登録すると Subscription-Key が発行される",
    )
    terms_url = "https://disclosure2dl.edinet-fsa.go.jp/guide/static/disclosure/WZEK0110.html"
    rate_limit = RateLimit(requests=60, per_seconds=60)

    # --- 問い合わせ ---------------------------------------------------
    def _params(self, target: date, *, full: bool = True) -> dict:
        return {
            "date": target.isoformat(),
            "type": 2 if full else 1,  # 2=書類一覧つき、1=メタデータのみ
            "Subscription-Key": self.api_key() or "",
        }

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        body = self.get_json(
            DOCUMENTS_URL, params=self._params(date.today(), full=False), use_cache=False, timeout=30
        )
        status = str(((body or {}).get("metadata") or {}).get("status", ""))
        if status and status != "200":
            message = ((body or {}).get("metadata") or {}).get("message", "")
            return CheckResult(self.name, ok=False, detail=f"EDINET が {status} を返しました（{message}）")
        return CheckResult(self.name, ok=True, detail="APIキー有効")

    def fetch_items(self, query: str, *, limit: int = 10, timeout: int = 30) -> list[FeedItem]:
        """提出書類の一覧を返す。

        query の書き方:
          "2026-09-01"  … その日の提出書類
          "7203"        … 今日の一覧から、その証券コードのものだけ
          ""            … 今日の提出書類
        """
        if not self.is_available():
            raise AuthError(self.unavailable_reason())

        target, code = _parse_query(query)
        body = self.get_json(DOCUMENTS_URL, params=self._params(target), timeout=timeout)
        results = (body or {}).get("results") or []

        items = [_to_item(row) for row in results if _matches(row, code)]
        return items[:limit]


def _parse_query(query: str) -> tuple[date, str]:
    """query から (対象日, 証券コード) を決める。"""
    text = (query or "").strip()
    if not text:
        return date.today(), ""
    found_date = DATE_RE.search(text)
    target = date.fromisoformat(found_date.group()) if found_date else date.today()

    rest = DATE_RE.sub("", text).strip()
    code = rest if CODE_RE.match(rest) else ""
    return target, code


def _matches(row: dict, code: str) -> bool:
    if not code:
        return True
    # EDINET の secCode は5桁（末尾0）。4桁で渡されても引けるようにする
    sec_code = str(row.get("secCode") or "")
    return sec_code == code or sec_code[:4] == code[:4]


def _to_item(row: dict) -> FeedItem:
    doc_id = str(row.get("docID") or "")
    doc_type = str(row.get("docTypeCode") or "")
    filer = str(row.get("filerName") or "")
    description = str(row.get("docDescription") or "")
    return FeedItem(
        source="edinet",
        title=f"{filer} {description}".strip() or "(無題)",
        # キーを含めない。取得するときは同じ Subscription-Key が要る
        url=f"{API_BASE}/documents/{doc_id}?type=2" if doc_id else "",
        published=str(row.get("submitDateTime") or ""),
        summary=DOC_TYPES.get(doc_type, ""),
        author=filer,
        tags=[tag for tag in (DOC_TYPES.get(doc_type, ""), str(row.get("secCode") or "")) if tag],
        meta={
            "doc_id": doc_id,
            "doc_type_code": doc_type,
            "sec_code": str(row.get("secCode") or ""),
            "edinet_code": str(row.get("edinetCode") or ""),
            "has_pdf": bool(row.get("pdfFlag") in (1, "1", True)),
        },
    )
