"""e-Stat（政府統計の総合窓口）の統計表検索。

各省庁が出した統計そのものを引ける。「〜と言われている」ではなく
元の統計表に当たりたいときの入口。

- 無料。アプリケーションID（appId）の登録が要る
- 検索結果が1件のときだけ dict、2件以上だと list で返ってくる仕様なので、
  受け取り側で必ず均す（ここを忘れると1件のときだけ落ちる）
"""

from __future__ import annotations

from ..core.connector import AuthSpec, CheckResult, Connector, RateLimit
from ..core.errors import AuthError, ConnectorError
from ..core.registry import register
from ..core.types import FeedItem

API_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getStatsList"
#: 人が見るページ（統計表IDから開ける）
VIEW_URL = "https://www.e-stat.go.jp/dbview?sid="


@register
class EstatFeed(Connector):
    name = "estat"
    category = "feed"
    summary = "e-Stat の統計表検索（政府統計の一次情報）"
    priority = 15
    auth = AuthSpec(
        env=("ESTAT_APP_ID",),
        signup_url="https://www.e-stat.go.jp/api/",
        note="無料。利用登録するとアプリケーションIDが発行される",
    )
    terms_url = "https://www.e-stat.go.jp/api/api-info/api-spec"
    rate_limit = RateLimit(requests=60, per_seconds=60)

    def check(self) -> CheckResult:
        if not self.is_available():
            return CheckResult(self.name, ok=False, detail=self.unavailable_reason(), skipped=True)
        body = self.get_json(
            API_URL,
            params={"appId": self.api_key(), "searchWord": "人口", "limit": 1},
            use_cache=False,
            timeout=30,
        )
        _raise_for_status(body)
        return CheckResult(self.name, ok=True, detail="アプリケーションID有効")

    def fetch_items(self, query: str, *, limit: int = 10, timeout: int = 30) -> list[FeedItem]:
        """キーワードで統計表を探す。"""
        if not self.is_available():
            raise AuthError(self.unavailable_reason())

        body = self.get_json(
            API_URL,
            params={
                "appId": self.api_key(),
                "searchWord": query,
                "limit": max(1, min(limit, 100)),
            },
            timeout=timeout,
        )
        _raise_for_status(body)

        datalist = (_root(body) or {}).get("DATALIST_INF") or {}
        return [_to_item(row) for row in _as_list(datalist.get("TABLE_INF"))][:limit]


def _root(body: dict) -> dict:
    return (body or {}).get("GET_STATS_LIST") or {}


def _raise_for_status(body: dict) -> None:
    """e-Stat は HTTP 200 のまま本文でエラーを返す。"""
    result = _root(body).get("RESULT") or {}
    status = str(result.get("STATUS", "0"))
    if status not in ("0", ""):
        raise ConnectorError(f"estat: {result.get('ERROR_MSG') or f'エラー {status}'}")


def _as_list(value) -> list[dict]:
    """1件のときは dict、複数のときは list で返る仕様を均す。"""
    if value is None:
        return []
    if isinstance(value, dict):
        return [value]
    return [row for row in value if isinstance(row, dict)]


def _text(value) -> str:
    """{"@code": "...", "$": "表示名"} の形と素の文字列の両方を受ける。"""
    if isinstance(value, dict):
        return str(value.get("$", ""))
    return "" if value is None else str(value)


def _to_item(row: dict) -> FeedItem:
    table_id = str(row.get("@id") or "")
    statistics = _text(row.get("STATISTICS_NAME"))
    title = _text(row.get("TITLE"))
    return FeedItem(
        source="estat",
        title=" ".join(part for part in (statistics, title) if part) or "(無題)",
        url=f"{VIEW_URL}{table_id}" if table_id else "",
        published=_text(row.get("UPDATED_DATE")),
        summary=_text(row.get("SURVEY_DATE")),
        author=_text(row.get("GOV_ORG")),
        tags=[tag for tag in (_text(row.get("STAT_NAME")),) if tag],
        meta={
            "table_id": table_id,
            "survey_date": _text(row.get("SURVEY_DATE")),
            "open_date": _text(row.get("OPEN_DATE")),
        },
    )
