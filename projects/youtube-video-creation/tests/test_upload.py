"""投稿の中身を、送る前に確かめる。

投稿は取り返しがつかない。認証も通信もせずに、
何が送られるかを見られるようにしておく。
"""

import json

import pytest

from src import upload as upload_mod


def _built(tmp_path, tags=("サッカー", "トッテナム"), title="【速報】見出し", body="本文"):
    (tmp_path / "video.mp4").write_bytes(b"x" * 100)
    (tmp_path / "thumbnail.png").write_bytes(b"x")
    (tmp_path / "description.txt").write_text(f"{title}\n\n{body}", encoding="utf-8")
    (tmp_path / "script.json").write_text(
        json.dumps({"tags": list(tags)}, ensure_ascii=False), encoding="utf-8"
    )
    return tmp_path


def test_書き出しから投稿の中身を組み立てる(tmp_path):
    draft = upload_mod.prepare(_built(tmp_path))
    assert draft.title == "【速報】見出し"
    assert draft.description == "本文"
    assert draft.tags == ["サッカー", "トッテナム"]
    assert draft.privacy == "private"
    assert draft.problems == []


def test_タグは台本から取る(tmp_path):
    # description.txt には本文しか無い。タグは script.json にしかない
    built = _built(tmp_path)
    (built / "script.json").unlink()
    assert upload_mod.prepare(built).tags == []


def test_壊れたscript_jsonで止まらない(tmp_path):
    built = _built(tmp_path)
    (built / "script.json").write_text("{壊れている", encoding="utf-8")
    assert upload_mod.prepare(built).tags == []


def test_動画が無ければ問題として挙げる(tmp_path):
    built = _built(tmp_path)
    (built / "video.mp4").unlink()
    assert any("動画がありません" in note for note in upload_mod.prepare(built).problems)


def test_サムネが無ければ黙って外す(tmp_path):
    built = _built(tmp_path)
    (built / "thumbnail.png").unlink()
    draft = upload_mod.prepare(built)
    assert draft.thumbnail is None
    assert draft.problems == []


def test_公開設定の綴り違いを止める(tmp_path):
    draft = upload_mod.prepare(_built(tmp_path), privacy="publik")
    assert any("privacy" in note for note in draft.problems)


def test_タイトルが長すぎれば止める(tmp_path):
    built = _built(tmp_path, title="あ" * 101)
    assert any("タイトル" in note for note in upload_mod.prepare(built).problems)


def test_タグの合計が上限を超えたら削る(tmp_path):
    from src import tags as tags_mod

    many = [f"タグ{n:03d}あいうえおかきくけこ" for n in range(80)]
    draft = upload_mod.prepare(_built(tmp_path, tags=many))
    assert tags_mod.text_length(draft.tags) <= tags_mod.MAX_TAGS_TEXT
    assert draft.problems == []


def test_送る前に一画面で見せる(tmp_path):
    lines = "\n".join(upload_mod.prepare(_built(tmp_path)).lines())
    assert "【速報】見出し" in lines
    assert "private" in lines
    assert "トッテナム" in lines


def test_問題があるまま送ろうとすると止まる(tmp_path):
    with pytest.raises(upload_mod.UploadError):
        upload_mod.upload(tmp_path / "ない.mp4", "題", "本文")

def test_概要欄の更新は題名とタグを消さない():
    """**snippet は部分更新ができない。**渡さなかった項目は消える。

    概要欄だけ差し替えるつもりで description だけ送ると、題名が空になる。
    """
    from src.upload import update_description

    sent = {}

    class Videos:
        def list(self, part, id):
            class R:
                def execute(self_):
                    return {"items": [{"snippet": {
                        "title": "もとの題名", "description": "もとの概要",
                        "tags": ["サッカー"], "categoryId": "17"}}]}
            return R()

        def update(self, part, body):
            sent.update(body)

            class R:
                def execute(self_):
                    return {}
            return R()

    class Service:
        def videos(self):
            return Videos()

    update_description(Service(), "abc123", "新しい概要")
    assert sent["snippet"]["description"] == "新しい概要"
    assert sent["snippet"]["title"] == "もとの題名"      # 消さない
    assert sent["snippet"]["tags"] == ["サッカー"]       # 消さない
    assert sent["snippet"]["categoryId"] == "17"


def test_見つからない動画は止める():
    from src.upload import UploadError, fetch_snippet

    class Videos:
        def list(self, part, id):
            class R:
                def execute(self_):
                    return {"items": []}
            return R()

    class Service:
        def videos(self):
            return Videos()

    try:
        fetch_snippet(Service(), "nope")
    except UploadError as err:
        assert "見つかりません" in str(err)
    else:
        raise AssertionError("無い動画を通した")

def test_クレジットだけを足す():
    """**丸ごと差し替えない。**公開中と手元で尺が違い、章の時刻がずれる
    （実測 2026-09-06: 公開 2分03秒 / 手元 1分52秒）。
    """
    from src.upload import add_credits

    nl = chr(10)
    now = nl.join(["0:00 オープニング", "0:15 何が起きたか", "",
                   "■ クレジット", "音声: VOICEVOX（…）", "",
                   "#サッカー #海外サッカー"])
    got = add_credits(now, ["画像: Wikimedia Commons"], ["※ 画像: File:X / CC BY 3.0"])

    # 章はそのまま
    assert "0:15 何が起きたか" in got
    # 上の1行は「音声:」の直後
    rows = got.split(nl)
    assert rows[rows.index("音声: VOICEVOX（…）") + 1] == "画像: Wikimedia Commons"
    # 詳細はハッシュタグより後ろ
    assert got.index("#サッカー") < got.index("※ 画像: File:X")


def test_何度足しても増えない():
    """やり直しても同じ行が並ばない。**途中で止まっても、もう一度叩ける。**"""
    from src.upload import add_credits

    nl = chr(10)
    now = nl.join(["■ クレジット", "音声: VOICEVOX", "", "#サッカー"])
    once = add_credits(now, ["画像: Wikimedia Commons"], ["※ 画像: File:X"])
    twice = add_credits(once, ["画像: Wikimedia Commons"], ["※ 画像: File:X"])
    assert once == twice
    assert once.count("画像: Wikimedia Commons") == 1
    assert once.count("※ 画像: File:X") == 1


def test_書き出しの途中を掴んだら止める(tmp_path):
    """video.mp4 だけ先にあって description.txt がまだ、という隙がある。

    2026-09-08、作り直しの最中に投稿処理が入り、タイトルがフォルダ名・
    概要欄が空のまま送られかけた。通信が切れて事なきを得ただけだった。
    """
    built = _built(tmp_path)
    (built / "description.txt").write_text("", encoding="utf-8")
    draft = upload_mod.prepare(built)
    notes = draft.problems
    assert any("フォルダ名" in note for note in notes)
    assert any("概要欄が空" in note for note in notes)


def test_動画より古い説明を掴んだら止める(tmp_path):
    """バレンシアの回で、動画は新しく、タグだけ前の書き出しのものを送った。

    2026-09-08。動画が書き上がった時点で投稿側の合図が立ち、
    description.txt と script.json はそのあとに書かれる。
    """
    import os

    built = _built(tmp_path)
    video_at = (built / "video.mp4").stat().st_mtime
    for name in ("description.txt", "script.json"):
        path = built / name
        if path.exists():
            os.utime(path, (video_at - 600, video_at - 600))
    notes = upload_mod.prepare(built).problems
    assert any("動画より古い" in note for note in notes)


def test_同じ書き出しなら通る(tmp_path):
    built = _built(tmp_path)
    assert upload_mod.prepare(built).problems == []


class _Req:
    def __init__(self, response):
        self._response = response

    def next_chunk(self):
        return None, self._response

    def execute(self):
        return self._response


class _Boom:
    def execute(self):
        raise RuntimeError("HttpError 429: The user has uploaded too many thumbnails recently")


class _FakeService:
    """videos.insert は通り、thumbnails.set だけ落ちるサービス。"""

    def videos(self):
        return type("V", (), {"insert": lambda self, **kw: _Req({"id": "vid_ok"})})()

    def thumbnails(self):
        return type("T", (), {"set": lambda self, **kw: _Boom()})()


def test_サムネで落ちても動画のidは返す(tmp_path, monkeypatch, capsys):
    """2026-09-08、thumbnails.set の 429 で例外になり、呼ぶ側が掛け直して
    サンチョのショートとCLの本編が2本ずつ公開された。動画はもう上がっている。"""
    from src import quota

    built = _built(tmp_path)
    monkeypatch.setattr(upload_mod, "get_service", lambda: _FakeService())
    monkeypatch.setattr(upload_mod, "_load_deps",
                        lambda: (None, None, None, None, lambda *a, **k: object()))
    monkeypatch.setattr(quota, "record", lambda *a, **k: None)
    video_id = upload_mod.upload(built / "video.mp4", "T", "本文",
                                 thumbnail=built / "thumbnail.png")
    assert video_id == "vid_ok"
    assert "サムネイルは付きませんでした" in capsys.readouterr().err


def test_過ぎた時刻は止める():
    """09:00 を指定したのが 09:11 で、黙って翌日に回り6本が1日ずれかけた（2026-09-09）。"""
    from datetime import datetime, timedelta, timezone

    import pytest

    jst = timezone(timedelta(hours=9))
    now = datetime(2026, 9, 9, 9, 11, tzinfo=jst)
    with pytest.raises(upload_mod.UploadError, match="過ぎています"):
        upload_mod.when_to_publish("09:00", now)
    # まだ先の時刻なら今日のその時刻
    assert upload_mod.when_to_publish("10:30", now) == "2026-09-09T01:30:00Z"


def test_分で渡せる():
    """並べて予約するときは時計の時刻より確実。"""
    from datetime import datetime, timedelta, timezone

    import pytest

    jst = timezone(timedelta(hours=9))
    now = datetime(2026, 9, 9, 9, 11, tzinfo=jst)
    assert upload_mod.when_to_publish("+45", now) == "2026-09-09T00:56:00Z"
    assert upload_mod.when_to_publish("+90", now) == "2026-09-09T01:41:00Z"
    with pytest.raises(upload_mod.UploadError):
        upload_mod.when_to_publish("+5", now)


def test_投稿の枠は9時から24時():
    """**9時より前に出さない**（2026-09-16 ユーザー決定。7時→9時）。

    「その日の何本目か」の影響を外して測り直したら、危ないのは9時より前だけだった。
    7〜8時の6本のうち3本が100回未満（1回・26回・18回）、0〜6時は6本中5本。
    9〜20時の68本は中央値1,065回で**100回未満がゼロ**。
    **書き出しが押すと、気づいたら朝イチの枠に落ちる。**ここで止める。
    """
    from datetime import datetime, timedelta, timezone

    import pytest

    jst = timezone(timedelta(hours=9))
    now = datetime(2026, 9, 10, 23, 0, tzinfo=jst)

    # 枠の中はそのまま通る
    assert upload_mod.when_to_publish("23:30", now) == "2026-09-10T14:30:00Z"
    assert upload_mod.when_to_publish("明日09:00", now) == "2026-09-11T00:00:00Z"

    # 深夜は止める（時計でも、分での指定でも）
    with pytest.raises(upload_mod.UploadError, match="枠の外"):
        upload_mod.when_to_publish("明日02:00", now)
    with pytest.raises(upload_mod.UploadError, match="枠の外"):
        upload_mod.when_to_publish("+120", now)      # 翌 01:00

    # **朝イチの7〜8時台も止める**（ここが 2026-09-16 に変わったところ）
    with pytest.raises(upload_mod.UploadError, match="枠の外"):
        upload_mod.when_to_publish("明日07:00", now)
    with pytest.raises(upload_mod.UploadError, match="枠の外"):
        upload_mod.when_to_publish("明日08:59", now)

    # 9時ちょうどは通る。24時（＝0時）は枠の外
    assert upload_mod.when_to_publish("明日09:00", now)
    with pytest.raises(upload_mod.UploadError, match="枠の外"):
        upload_mod.when_to_publish("明日00:00", now)


def test_予約すると非公開で送られる(tmp_path, monkeypatch):
    """YouTube の決まりで、予約するあいだは private でなければならない。"""
    from src import quota

    sent = {}

    class _Req:
        def next_chunk(self):
            return None, {"id": "vid"}

    class _Videos:
        def insert(self, **kw):
            sent.update(kw["body"]["status"])
            return _Req()

    class _Service:
        def videos(self):
            return _Videos()

    built = _built(tmp_path)
    monkeypatch.setattr(upload_mod, "get_service", lambda: _Service())
    monkeypatch.setattr(upload_mod, "_load_deps",
                        lambda: (None, None, None, None, lambda *a, **k: object()))
    monkeypatch.setattr(quota, "record", lambda *a, **k: None)
    upload_mod.upload(built / "video.mp4", "T", "本文", privacy="public",
                      publish_at="2026-09-09T22:30:00Z")
    assert sent["privacyStatus"] == "private"
    assert sent["publishAt"] == "2026-09-09T22:30:00Z"


def test_さっき上がった同じ題名を見つける():
    """投稿は成功したのに控えを残す前に処理が終わり、掛け直しで二重に上がった。

    2026-09-09、上田の本編が2本・バロンドールのショートが3本。
    """
    from datetime import datetime, timedelta, timezone

    now = datetime.now(timezone.utc)

    def item(title, minutes, vid):
        at = (now - timedelta(minutes=minutes)).strftime("%Y-%m-%dT%H:%M:%SZ")
        return {"snippet": {"title": title, "publishedAt": at,
                            "resourceId": {"videoId": vid}}}

    class _Service:
        def channels(self):
            return type("C", (), {"list": lambda self, **k: type("R", (), {
                "execute": lambda self: {"items": [{"contentDetails": {
                    "relatedPlaylists": {"uploads": "UU"}}}]}})()})()

        def playlistItems(self):
            return type("P", (), {"list": lambda self, **k: type("R", (), {
                "execute": lambda self: {"items": [
                    item("上田綺世が初先発で決めた日", 3, "new1"),
                    item("ずっと前に出した動画", 500, "old1"),
                ]}})()})()

    from src import quota

    original, quota.record = quota.record, lambda *a, **k: None
    try:
        assert upload_mod.recently_uploaded(_Service(), "上田綺世が初先発で決めた日") == "new1"
        assert upload_mod.recently_uploaded(_Service(), "ずっと前に出した動画") is None
        assert upload_mod.recently_uploaded(_Service(), "まだ無い題名") is None
    finally:
        quota.record = original


def test_明日の時刻で予約できる():
    """**夜に書き出して朝に出す**ときに要る（2026-09-09）。

    実測で、朝に出した回は435〜993回、夜に出した回は0〜35回だった。
    `+750` のような分数での指定は、書き出しに手間取ると狙いが狂う。
    """
    from datetime import datetime, timedelta, timezone

    from src.upload import UploadError, when_to_publish

    jst = timezone(timedelta(hours=9))
    now = datetime(2026, 9, 9, 19, 30, tzinfo=jst)

    got = when_to_publish("明日09:30", now)
    assert got == "2026-09-10T00:30:00Z"          # 翌日09:30 JST = 当日00:30 UTC
    assert when_to_publish("翌 10:15", now) == "2026-09-10T01:15:00Z"

    # 今日の指定は、過ぎていればこれまでどおり止める
    try:
        when_to_publish("07:30", now)
    except UploadError as err:
        assert "過ぎています" in str(err)
    else:
        raise AssertionError("過ぎた時刻を通した")


def test_投稿できなかったことが最後の行に出る(capsys):
    """**末尾しか見ないと成功に見えた**（2026-09-15）。

    認証が切れて6本とも投げられていないのに、手前に出ている
    「予約公開 …」の行を見て「予約しました」と報告した。
    stderr に出すと `> file 2>&1` で**先頭に回り込む**ので、stdout に出す。
    """
    from src.cli import report_upload_failure

    print("■ 予約公開　09/15 08:00 JST（それまでは非公開）")
    report_upload_failure(RuntimeError("invalid_grant: Token has been expired or revoked."))
    lines = [x for x in capsys.readouterr().out.splitlines() if x.strip()]
    assert "投稿は0本" in lines[-1], lines
    assert any("認証が切れています" in x for x in lines), lines


def test_ショートの概要欄に本編への行が入る(tmp_path, monkeypatch):
    """**ショートから本編へ、誰も流れていなかった**（2026-09-15 実測）。

    9/1〜9/15 でショートは72,281再生。そこから本編に来たのは**1回**。
    概要欄にリンクが無かった。収益化に要る4,000時間は本編の視聴時間しか
    数えないので、いちばん人がいる場所から橋を架ける。
    """
    import json

    from src import posted as posted_mod
    from src.upload import prepare

    ledger = tmp_path / "posted.json"
    ledger.write_text(json.dumps([
        {"build": "20260916_mitoma", "video_id": "M9eDi6wKWj8",
         "at": "2026-09-15T10:00:00+00:00"},
    ]), encoding="utf-8")
    monkeypatch.setattr(posted_mod, "LEDGER", ledger)

    short = tmp_path / "20260916_mitoma_short"
    short.mkdir()
    (short / "description.txt").write_text(
        "三笘薫の退団報道\n\nリード\n\n■ 出典\nhttps://example.com/a\n",
        encoding="utf-8")
    (short / "video.mp4").write_bytes(b"x")

    lines = prepare(short).description.splitlines()
    assert "■ この話の本編" in lines
    assert "https://youtu.be/M9eDi6wKWj8" in lines
    # **リードのすぐ下に置く。**出典やクレジットの下では誰も開かない
    assert lines.index("■ この話の本編") < lines.index("■ 出典")
    assert lines[0] == "リード"


def test_本編には本編への行を足さない(tmp_path):
    """足すのはショートだけ。自分自身へのリンクは意味が無い。"""
    from src.upload import prepare

    main = tmp_path / "20260916_mitoma"
    main.mkdir()
    (main / "description.txt").write_text("題\n\nリード\n", encoding="utf-8")
    (main / "video.mp4").write_bytes(b"x")
    assert "この話の本編" not in prepare(main).description


def test_本編をまだ投稿していないショートは何も足さない(tmp_path, monkeypatch):
    """**ショートだけ先に出す回がある。**そこで止めると投稿が止まる。"""
    import json

    from src import posted as posted_mod
    from src.upload import prepare

    ledger = tmp_path / "posted.json"
    ledger.write_text(json.dumps([]), encoding="utf-8")
    monkeypatch.setattr(posted_mod, "LEDGER", ledger)

    short = tmp_path / "20260917_foo_short"
    short.mkdir()
    (short / "description.txt").write_text("題\n\nリード\n", encoding="utf-8")
    (short / "video.mp4").write_bytes(b"x")
    assert "この話の本編" not in prepare(short).description


def test_同じ行を二度足さない(tmp_path):
    """概要欄を書き直して上げ直したときに、本編の行が二重に並ばない。"""
    from src.upload import MAIN_LINK_HEADING, _with_main_link

    link = MAIN_LINK_HEADING + "\nhttps://youtu.be/AAA"
    once = _with_main_link("リード\n\n本文", link)
    assert once.count(MAIN_LINK_HEADING) == 1
    assert _with_main_link(once, link) == once
