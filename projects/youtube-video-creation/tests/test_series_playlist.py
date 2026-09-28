"""シリーズの再生リストは無ければ作って控える（2026-09-28 収益化の整理 2）。"""
import json


class _Insert:
    def __init__(self, log):
        self.log = log

    def execute(self):
        self.log.append("insert")
        return {"id": "PLNEW123"}


class _Playlists:
    def __init__(self, log):
        self.log = log

    def insert(self, part, body):
        self.log.append(body["snippet"]["title"])
        return _Insert(self.log)


class _Api:
    def __init__(self):
        self.log = []

    def playlists(self):
        return _Playlists(self.log)


def test_知らないシリーズは再生リストを作って控える(tmp_path, monkeypatch):
    from src import cli

    monkeypatch.setattr(cli, "PLAYLISTS_FILE", tmp_path / "playlists.json")
    api = _Api()
    assert cli._series_playlist(api, "") == cli.MAIN_PLAYLIST
    assert cli._series_playlist(api, "プレミアリーグチーム紹介") == "PLEG5zd5gf28Q"
    assert api.log == []
    assert cli._series_playlist(api, "ラ・リーガチーム紹介") == "PLNEW123"
    assert api.log == ["ラ・リーガチーム紹介", "insert"]
    # 2回目は作らない
    assert cli._series_playlist(api, "ラ・リーガチーム紹介") == "PLNEW123"
    assert api.log == ["ラ・リーガチーム紹介", "insert"]
    assert json.loads((tmp_path / "playlists.json").read_text(encoding="utf-8")) == {"ラ・リーガチーム紹介": "PLNEW123"}
