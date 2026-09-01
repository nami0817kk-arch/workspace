"""一次情報のコネクタ（EDINET / e-Stat）。"""

from datetime import date

import pytest
from fakes import FakeResponse, FakeSession

from imagegen.connectors.feed_edinet import EdinetFeed
from imagegen.connectors.feed_estat import EstatFeed
from imagegen.core.errors import AuthError, ConnectorError

EDINET_BODY = {
    "metadata": {"status": "200", "message": "OK"},
    "results": [
        {
            "docID": "S100ABCD",
            "edinetCode": "E02144",
            "secCode": "72030",
            "filerName": "トヨタ自動車株式会社",
            "docDescription": "有価証券報告書－第121期",
            "docTypeCode": "120",
            "submitDateTime": "2026-09-01 09:05",
            "pdfFlag": 1,
        },
        {
            "docID": "S100WXYZ",
            "edinetCode": "E01234",
            "secCode": "99840",
            "filerName": "ソフトバンク株式会社",
            "docDescription": "大量保有報告書",
            "docTypeCode": "350",
            "submitDateTime": "2026-09-01 10:00",
            "pdfFlag": 0,
        },
    ],
}

ESTAT_BODY = {
    "GET_STATS_LIST": {
        "RESULT": {"STATUS": 0, "ERROR_MSG": "正常に終了しました。"},
        "DATALIST_INF": {
            "NUMBER": 2,
            "TABLE_INF": [
                {
                    "@id": "0003448233",
                    "STAT_NAME": {"@code": "00200521", "$": "国勢調査"},
                    "GOV_ORG": {"@code": "00200", "$": "総務省"},
                    "STATISTICS_NAME": "令和2年国勢調査",
                    "TITLE": {"@no": "1", "$": "人口等基本集計"},
                    "SURVEY_DATE": "202010",
                    "UPDATED_DATE": "2026-08-20",
                    "OPEN_DATE": "2026-08-01",
                },
                {
                    "@id": "0003448234",
                    "STAT_NAME": "住宅・土地統計調査",
                    "GOV_ORG": {"$": "総務省"},
                    "STATISTICS_NAME": "住宅数概数集計",
                    "TITLE": "全国編",
                    "UPDATED_DATE": "2026-07-01",
                },
            ],
        },
    }
}


# --- EDINET -----------------------------------------------------------
@pytest.fixture
def edinet(monkeypatch):
    monkeypatch.setenv("EDINET_API_KEY", "test-key")
    return lambda session: EdinetFeed(session=session)


def test_edinet_lists_the_days_filings(edinet):
    session = FakeSession([FakeResponse(json_data=EDINET_BODY)])
    items = edinet(session).fetch_items("2026-09-01")

    assert len(items) == 2
    assert items[0].title == "トヨタ自動車株式会社 有価証券報告書－第121期"
    assert items[0].summary == "有価証券報告書"  # 書類種別コードを日本語にする
    assert items[0].meta["doc_id"] == "S100ABCD"
    assert session.last_params()["date"] == "2026-09-01"


def test_edinet_never_puts_the_key_in_the_returned_url(edinet):
    """URL は出力にも JSON にも出る。秘密を混ぜない。"""
    items = edinet(FakeSession([FakeResponse(json_data=EDINET_BODY)])).fetch_items("2026-09-01")
    assert "Subscription-Key" not in items[0].url
    assert "test-key" not in items[0].url
    assert items[0].url.endswith("/documents/S100ABCD?type=2")


def test_edinet_filters_by_securities_code(edinet):
    """4桁で渡しても、EDINET の5桁表記に合わせて引ける。"""
    items = edinet(FakeSession([FakeResponse(json_data=EDINET_BODY)])).fetch_items("7203")
    assert [item.meta["sec_code"] for item in items] == ["72030"]


def test_edinet_defaults_to_today(edinet):
    session = FakeSession([FakeResponse(json_data=EDINET_BODY)])
    edinet(session).fetch_items("")
    assert session.last_params()["date"] == date.today().isoformat()


def test_edinet_accepts_a_date_and_a_code_together(edinet):
    session = FakeSession([FakeResponse(json_data=EDINET_BODY)])
    items = edinet(session).fetch_items("2026-09-01 9984")
    assert session.last_params()["date"] == "2026-09-01"
    assert [item.meta["sec_code"] for item in items] == ["99840"]


def test_edinet_respects_the_limit(edinet):
    items = edinet(FakeSession([FakeResponse(json_data=EDINET_BODY)])).fetch_items("", limit=1)
    assert len(items) == 1


def test_edinet_requires_a_key():
    with pytest.raises(AuthError, match="EDINET_API_KEY"):
        EdinetFeed(session=FakeSession()).fetch_items("2026-09-01")


def test_edinet_check_is_skipped_without_a_key():
    result = EdinetFeed(session=FakeSession()).check()
    assert not result.ok and result.skipped


def test_edinet_check_reports_an_api_level_error(edinet):
    body = {"metadata": {"status": "404", "message": "not found"}}
    result = edinet(FakeSession([FakeResponse(json_data=body)])).check()
    assert not result.ok
    assert "404" in result.detail


def test_edinet_check_asks_only_for_metadata(edinet):
    session = FakeSession([FakeResponse(json_data={"metadata": {"status": "200"}})])
    assert edinet(session).check().ok
    assert session.last_params()["type"] == 1  # 一覧まで取らない


# --- e-Stat -----------------------------------------------------------
@pytest.fixture
def estat(monkeypatch):
    monkeypatch.setenv("ESTAT_APP_ID", "test-app-id")
    return lambda session: EstatFeed(session=session)


def test_estat_searches_statistics_tables(estat):
    session = FakeSession([FakeResponse(json_data=ESTAT_BODY)])
    items = estat(session).fetch_items("国勢調査")

    assert len(items) == 2
    assert items[0].title == "令和2年国勢調査 人口等基本集計"
    assert items[0].author == "総務省"
    assert items[0].url.endswith("0003448233")
    assert session.last_params()["searchWord"] == "国勢調査"


def test_estat_handles_both_shapes_of_field(estat):
    """{"$": "..."} でも素の文字列でも読めること。"""
    items = estat(FakeSession([FakeResponse(json_data=ESTAT_BODY)])).fetch_items("住宅")
    assert items[1].title == "住宅数概数集計 全国編"
    assert items[1].tags == ["住宅・土地統計調査"]


def test_estat_handles_a_single_result(estat):
    """1件のときは list ではなく dict で返る（ここを均さないと落ちる）。"""
    single = {
        "GET_STATS_LIST": {
            "RESULT": {"STATUS": 0},
            "DATALIST_INF": {"NUMBER": 1, "TABLE_INF": {"@id": "1", "TITLE": "単票"}},
        }
    }
    items = estat(FakeSession([FakeResponse(json_data=single)])).fetch_items("単票")
    assert len(items) == 1
    assert items[0].title == "単票"


def test_estat_handles_no_results(estat):
    empty = {"GET_STATS_LIST": {"RESULT": {"STATUS": 0}, "DATALIST_INF": {"NUMBER": 0}}}
    assert estat(FakeSession([FakeResponse(json_data=empty)])).fetch_items("該当なし") == []


def test_estat_raises_on_an_error_body(estat):
    """HTTP 200 のまま本文でエラーを返してくるので、そこを見る。"""
    error = {"GET_STATS_LIST": {"RESULT": {"STATUS": 100, "ERROR_MSG": "appId が不正です。"}}}
    with pytest.raises(ConnectorError, match="appId が不正"):
        estat(FakeSession([FakeResponse(json_data=error)])).fetch_items("人口")


def test_estat_requires_an_app_id():
    with pytest.raises(AuthError, match="ESTAT_APP_ID"):
        EstatFeed(session=FakeSession()).fetch_items("人口")


def test_estat_check_is_skipped_without_a_key():
    result = EstatFeed(session=FakeSession()).check()
    assert not result.ok and result.skipped


def test_estat_check_uses_the_key(estat):
    session = FakeSession([FakeResponse(json_data=ESTAT_BODY)])
    assert estat(session).check().ok
    assert session.last_params()["appId"] == "test-app-id"
