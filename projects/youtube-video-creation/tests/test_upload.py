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
