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
