"""再生リストと英語の題名（chiso/channel.py）・許可の確かめ（upload.service / reauth）。API は偽物に差し替える。"""
import json
from datetime import datetime
from types import SimpleNamespace

import pytest

from chiso import channel, cli, script, upload as up

JA_DESC = """■ 目次
0:00 地表：清を滅ぼした悪女？
2:23 下級官僚の娘
1:05:28 見立て

■ 音声
VOICEVOX:剣崎雌雄
VOICEVOX:春日部つむぎ

■ 画面の絵（いずれも著作権の切れた作品）
紫禁城の玉座

■ 次回：吉良上野介
次回のひとこと。

■ 絵の出典（Wikimedia Commons）
https://commons.wikimedia.org/wiki/File:X.jpg（PD）

#歴史の地層 #悪女と呼ばれた女たち

運営：つるはし社
"""


class Call:
    def __init__(self, fn):
        self.fn = fn

    def execute(self):
        return self.fn()


class FakeYouTube:
    """playlists・playlistItems・videos だけの偽物。書き込みの回数を数える。"""

    def __init__(self, lists=None, items=None, video=None):
        self.lists = dict(lists or {})            # 題名 → id
        self.items = {k: list(v) for k, v in (items or {}).items()}   # id → [videoId]
        self.video = video
        self.writes = []

    def playlists(self):
        fake = self

        class P:
            def list(self, **kw):
                return Call(lambda: {"items": [{"id": i, "snippet": {"title": t}} for t, i in fake.lists.items()]})

            def insert(self, part, body):
                def go():
                    pid = f"PL{len(fake.lists) + 1}"
                    fake.lists[body["snippet"]["title"]] = pid
                    fake.writes.append(("playlists.insert", body))
                    return {"id": pid}
                return Call(go)
        return P()

    def playlistItems(self):
        fake = self

        class I:
            def list(self, playlistId, **kw):
                ids = fake.items.get(playlistId, [])
                # 2ページに分けて返す（ページ送りの確認）
                if "pageToken" not in kw and len(ids) > 1:
                    return Call(lambda: {"items": [_item(ids[0])], "nextPageToken": "p2"})
                rest = ids[1:] if "pageToken" in kw else ids
                return Call(lambda: {"items": [_item(v) for v in rest]})

            def insert(self, part, body):
                def go():
                    sn = body["snippet"]
                    fake.items.setdefault(sn["playlistId"], []).append(sn["resourceId"]["videoId"])
                    fake.writes.append(("playlistItems.insert", body))
                    return {}
                return Call(go)
        return I()

    def videos(self):
        fake = self

        class V:
            def list(self, part, id):
                return Call(lambda: {"items": [fake.video] if fake.video else []})

            def update(self, part, body):
                def go():
                    fake.writes.append(("videos.update", part, body))
                    return body
                return Call(go)
        return V()


def _item(vid):
    return {"snippet": {"resourceId": {"videoId": vid}}}


def _sc(**over):
    d = {"title": "t", "series": "悪女と呼ばれた女たち",
         "timeline": {"start": 1755, "end": 1793, "events": [[1755, "誕生"]]},
         "sections": [{"title": "一", "lines": [{"語り": "a"}]}, {"title": "二", "lines": [{"語り": "b"}]},
                      {"title": "見立て", "lines": [{"語り": "c"}]}]}
    d.update(over)
    return script.parse(d)


# --- 台本 ---------------------------------------------------------------

def test_playlists_default_to_series_and_can_be_overridden():
    assert _sc().playlists == ["悪女と呼ばれた女たち"]
    assert _sc(series="").playlists == []
    assert _sc(playlists=["A", "B", "A"]).playlists == ["A", "B"]
    assert _sc(playlists="A").playlists == ["A"]
    assert _sc(playlists=[]).playlists == []                 # 書けば series: より優先（空ならどこにも入れない）
    assert _sc().shorts_playlists == [] and _sc(shorts_playlists=["S"]).shorts_playlists == ["S"]


def test_english_checks():
    sc = _sc(en={"title": "Cixi", "description": "d", "chapters": ["A", "B", "C"]})
    assert sc.en["chapters"] == ["A", "B", "C"]
    with pytest.raises(script.ScriptError):
        _sc(en={"description": "no title"})
    with pytest.raises(script.ScriptError):
        _sc(en={"title": "x" * 101})
    with pytest.raises(script.ScriptError):
        _sc(en={"title": "a", "chapters": ["only one"]})       # 節は3つ
    with pytest.raises(script.ScriptError):
        _sc(en={"title": "a <b>"})


# --- 計画 ---------------------------------------------------------------

POSTED = [
    {"key": "b:main", "video_id": "B", "publish_at": "2026-10-06 19:00"},
    {"key": "a:main", "video_id": "A", "publish_at": "2026-10-04 23:30"},
    {"key": "a:short:s1", "video_id": "As1", "publish_at": "2026-10-05 11:00"},
    {"key": "gone:main", "video_id": "G", "publish_at": "2026-10-01 19:00"},
]


def test_plan_puts_mains_in_publish_order_and_shorts_apart():
    scripts = {"a": _sc(shorts_playlists=["ショート"]), "b": _sc(playlists=["悪女と呼ばれた女たち", "世界史"])}
    p = channel.plan(scripts, POSTED)
    assert p.lists["悪女と呼ばれた女たち"] == [("a:main", "A"), ("b:main", "B")]
    assert p.lists["世界史"] == [("b:main", "B")]
    assert p.lists["ショート"] == [("a:short:s1", "As1")]
    assert p.max_units() == 3 * 50 + 4 * 50
    assert channel.plan(scripts, POSTED, only="b").lists.keys() == {"悪女と呼ばれた女たち", "世界史"}


def test_posted_scripts_reads_only_existing(tmp_path):
    (tmp_path / "scripts").mkdir()
    (tmp_path / "posted.json").write_text(json.dumps(POSTED), encoding="utf-8")
    import yaml
    (tmp_path / "scripts" / "a.yaml").write_text(yaml.safe_dump(
        {"title": "t", "series": "S", "sections": [{"title": "一", "lines": [{"語り": "a"}]}]}, allow_unicode=True),
        encoding="utf-8")
    got = cli.posted_scripts(tmp_path)
    assert list(got) == ["a"] and got["a"].playlists == ["S"]


# --- 再生リストの書き込み -------------------------------------------------

def test_sync_creates_missing_list_and_skips_videos_already_inside():
    fake = FakeYouTube(lists={"悪女と呼ばれた女たち": "PLx"}, items={"PLx": ["A", "Z"]})
    p = channel.Plan()
    p.add("悪女と呼ばれた女たち", "a:main", "A")
    p.add("悪女と呼ばれた女たち", "b:main", "B")
    p.add("新しいリスト", "a:short:s1", "As1")
    logs = []
    r = channel.sync(fake, p, {"新しいリスト": {"description": "説明"}}, channel.Budget(3000), log=logs.append)
    assert r["created"] == ["新しいリスト"] and r["skipped"] == 1
    assert [w[0] for w in fake.writes] == ["playlistItems.insert", "playlists.insert", "playlistItems.insert"]
    body = fake.writes[1][1]
    assert body["status"]["privacyStatus"] == "public" and body["snippet"]["description"] == "説明"
    assert fake.items["PLx"] == ["A", "Z", "B"]
    # もう一度打っても何も書かない
    fake.writes.clear()
    r2 = channel.sync(fake, p, {}, channel.Budget(3000), log=logs.append)
    assert fake.writes == [] and r2["skipped"] == 3


def test_sync_stops_before_the_budget():
    fake = FakeYouTube()
    p = channel.Plan()
    for i in range(5):
        p.add("L", f"k{i}", f"v{i}")
    r = channel.sync(fake, p, {}, channel.Budget(160), log=lambda *_: None)   # 一覧1＋作る50＋足す50×2＝151
    assert r["stopped"] and len(r["added"]) == 2


def test_playlist_body_default_description_and_privacy():
    b = channel.playlist_body("鎖国")
    assert "「鎖国」の回" in b["snippet"]["description"] and b["status"]["privacyStatus"] == "public"
    with pytest.raises(ValueError):
        channel.playlist_body("x", {"privacy": "friends"})


# --- 英語の説明 -----------------------------------------------------------

def test_en_description_uses_japanese_chapter_times_and_copies_credits():
    en = {"title": "Cixi", "description": "Was Cixi the villain who destroyed the Qing?",
          "chapters": ["Surface", "Daughter of a minor official", "Verdict"]}
    text = channel.en_description(en, JA_DESC)
    assert text.startswith("Was Cixi")
    assert "Chapters\n0:00 Surface\n2:23 Daughter of a minor official\n1:05:28 Verdict" in text
    assert "VOICEVOX:剣崎雌雄" in text and "VOICEVOX:春日部つむぎ" in text       # 規約のクレジットは必ず残す
    assert "https://commons.wikimedia.org/wiki/File:X.jpg（PD）" in text
    assert "次回" not in text and "#歴史の地層" not in text
    assert "運営：つるはし社" in text


def test_en_description_rejects_chapter_count_mismatch():
    with pytest.raises(ValueError):
        channel.en_description({"title": "x", "chapters": ["a", "b"]}, JA_DESC)


def test_localize_keeps_snippet_and_other_languages():
    video = {"id": "V1", "snippet": {"title": "西太后", "description": JA_DESC, "tags": ["西太后"], "categoryId": "27",
                                    "defaultAudioLanguage": "ja", "publishedAt": "x", "channelId": "c",
                                    "thumbnails": {}, "localized": {}},
             "localizations": {"fr": {"title": "Cixi fr", "description": "fr"}}}
    fake = FakeYouTube(video=video)
    en = {"title": "Cixi", "description": "d", "chapters": ["A", "B", "C"]}
    body = channel.localize(fake, "V1", en, dry_run=True, log=lambda *_: None)
    assert fake.writes == []                                  # 試しでは書かない
    channel.localize(fake, "V1", en, log=lambda *_: None)
    (_, part, sent), = fake.writes
    assert part == "snippet,localizations"
    sn = sent["snippet"]
    assert sn["title"] == "西太后" and sn["tags"] == ["西太后"] and sn["categoryId"] == "27"   # 送らないと消える欄
    assert sn["defaultLanguage"] == "ja" and "publishedAt" not in sn and "localized" not in sn
    assert set(sent["localizations"]) == {"fr", "en"} and sent["localizations"]["en"]["title"] == "Cixi"
    assert body == sent


def test_upload_sends_localizations_part(tmp_path, monkeypatch):
    sent = {}

    class Req:
        def next_chunk(self):
            return None, {"id": "NEW"}

    class Videos:
        def insert(self, part, body, media_body):
            sent.update(part=part, body=body)
            return Req()

    svc = SimpleNamespace(videos=lambda: Videos())
    monkeypatch.setattr(up, "recently_uploaded", lambda *a, **k: None)
    monkeypatch.setattr(up, "_deps", lambda: (None, None, None, None, lambda *a, **k: object()))
    video = tmp_path / "v.mp4"
    video.write_bytes(b"x")
    loc = {"en": {"title": "T", "description": "D"}}
    assert up.upload(svc, video, "題", "説明", [], "2026-10-10T10:00:00Z", localizations=loc) == "NEW"
    assert sent["part"] == "snippet,status,localizations" and sent["body"]["localizations"] == loc
    assert sent["body"]["snippet"]["defaultLanguage"] == "ja"
    up.upload(svc, video, "題", "説明", [], "2026-10-10T10:00:00Z")
    assert sent["part"] == "snippet,status" and "localizations" not in sent["body"]


# --- 許可 ---------------------------------------------------------------

def test_service_stops_without_token_and_never_opens_a_browser(tmp_path, monkeypatch):
    monkeypatch.setattr(up, "_deps", lambda: (None, None, None, None, None))
    with pytest.raises(up.NeedConsent) as e:
        up.credentials(tmp_path)
    assert "reauth" in str(e.value) and "歴史の地層" in str(e.value)


def test_service_needs_manage_scope(tmp_path, monkeypatch):
    monkeypatch.setattr(up, "credentials", lambda secrets: object())
    monkeypatch.setattr(up, "_deps", lambda: (None, None, None, lambda *a, **k: "svc", None))
    only_upload = {"https://www.googleapis.com/auth/youtube.upload"}
    with pytest.raises(up.NeedConsent) as e:
        up.service(tmp_path, need_manage=True, scopes_of=lambda c: only_upload)
    assert "取り直す" in str(e.value)
    assert up.service(tmp_path, need_manage=False, scopes_of=lambda c: only_upload) == "svc"
    force = only_upload | {"https://www.googleapis.com/auth/youtube.force-ssl"}
    assert up.service(tmp_path, need_manage=True, scopes_of=lambda c: force) == "svc"
    assert up.can_manage({"https://www.googleapis.com/auth/youtube"})


def test_reauth_keeps_the_old_token(tmp_path):
    (tmp_path / "client_secret.json").write_text("{}", encoding="utf-8")
    (tmp_path / "token.json").write_text('{"old": 1}', encoding="utf-8")
    new = SimpleNamespace(to_json=lambda: '{"new": 1}')
    backup = up.reauth(tmp_path, run_flow=lambda: new, now=datetime(2026, 10, 8, 21, 5, 0, tzinfo=up.JST))
    assert backup.name == "token.20261008-210500.json.old"
    assert json.loads(backup.read_text(encoding="utf-8")) == {"old": 1}
    assert json.loads((tmp_path / "token.json").read_text(encoding="utf-8")) == {"new": 1}


def test_reauth_failure_leaves_token_untouched(tmp_path):
    (tmp_path / "client_secret.json").write_text("{}", encoding="utf-8")
    (tmp_path / "token.json").write_text('{"old": 1}', encoding="utf-8")

    def cancel():
        raise RuntimeError("ユーザーが閉じた")
    with pytest.raises(RuntimeError):
        up.reauth(tmp_path, run_flow=cancel)
    assert json.loads((tmp_path / "token.json").read_text(encoding="utf-8")) == {"old": 1}


def test_playlists_command_without_sync_does_not_touch_the_api(monkeypatch, capsys):
    monkeypatch.setattr(cli, "_service", lambda **k: pytest.fail("API を使った"))
    assert cli.main(["playlists"]) == 0
    out = capsys.readouterr().out
    assert "計画だけ" in out or "入れる再生リストがありません" in out
