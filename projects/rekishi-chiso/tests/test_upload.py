from datetime import datetime

import pytest

from chiso import upload as up


def test_publish_time_converts_jst_to_utc():
    now = datetime(2026, 10, 4, 12, 0, tzinfo=up.JST)
    assert up.publish_time("2026-10-05 19:00", now) == "2026-10-05T10:00:00Z"


@pytest.mark.parametrize("text", ["2026-10-04 12:05", "2026-10-05 08:30", "あした19時"])
def test_publish_time_rejects_past_early_or_malformed(text):
    with pytest.raises(up.UploadError):
        up.publish_time(text, datetime(2026, 10, 4, 12, 0, tzinfo=up.JST))


def test_record_and_already_posted(tmp_path):
    log = tmp_path / "posted.json"
    assert up.already_posted(log, "a:main") is None
    up.record(log, {"key": "a:main", "video_id": "x", "publish_at": "t"})
    assert up.already_posted(log, "a:main")["video_id"] == "x"
