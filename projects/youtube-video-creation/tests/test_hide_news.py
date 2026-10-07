"""tools/hide_news.py — 審査の前にニュースの動画を引っ込める道具の、仕分けと API への渡し方。"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_spec = importlib.util.spec_from_file_location("hide_news", ROOT / "tools" / "hide_news.py")
hide_news = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(hide_news)


def _script(dir_: Path, name: str, front: str) -> None:
    (dir_ / f"{name}.md").write_text(f"---\n{front}\n---\n本文\n", encoding="utf-8")


def test_series_is_kept_even_if_format_is_news(tmp_path):
    # クラシコの比較やクラブ紹介は format: news のまま series が付いている
    _script(tmp_path, "20261003_compare_clasico", "format: news\nseries: クラブ同士の比較")
    assert hide_news.classify("20261003_compare_clasico", tmp_path) == "keep"


def test_news_and_quote_are_hidden(tmp_path):
    _script(tmp_path, "20261003_kubo_marriage", "format: news")
    _script(tmp_path, "20260926_itojunya", "format: quote")
    assert hide_news.classify("20261003_kubo_marriage", tmp_path) == "hide"
    assert hide_news.classify("20260926_itojunya", tmp_path) == "hide"


def test_short_follows_its_main_script(tmp_path):
    _script(tmp_path, "20260920_pl17_newcastle", "series: プレミア20クラブ紹介")
    assert hide_news.classify("20260920_pl17_newcastle_short", tmp_path) == "keep"
    assert hide_news.classify("output/20260920_pl17_newcastle_tiktok", tmp_path) == "keep"


def test_missing_script_is_reported_separately(tmp_path):
    assert hide_news.classify("20260906_madrid", tmp_path) == "noscript"


def test_plan_dedupes_and_honours_keep(tmp_path):
    _script(tmp_path, "a", "format: news")
    _script(tmp_path, "b", "series: x")
    rows = [{"build": "a", "video_id": "V1"}, {"build": "a", "video_id": "V1"},
            {"build": "a_short", "video_id": "V2"}, {"build": "b", "video_id": "V3"},
            {"build": "c", "video_id": "V4"}]
    got = hide_news.plan(rows, tmp_path, keep={"V4"})
    assert [x["video_id"] for x in got["hide"]] == ["V1", "V2"]
    assert got["hide"][1]["short"] is True
    assert [x["video_id"] for x in got["keep"]] == ["V3", "V4"]
    assert got["noscript"] == []


class _Req:
    def __init__(self, result):
        self.result = result

    def execute(self):
        return self.result


class _Videos:
    def __init__(self, status):
        self.status = status
        self.updates = []

    def list(self, part, id):
        return _Req({"items": [{"id": v, "status": dict(self.status[v])}
                               for v in id.split(",") if v in self.status]})

    def update(self, part, body):
        self.updates.append(body)
        self.status[body["id"]] = dict(body["status"])
        return _Req({})

    def delete(self, **_):      # 呼ばれたら落とす
        raise AssertionError("削除してはいけない")


class _Service:
    def __init__(self, status):
        self._v = _Videos(status)

    def videos(self):
        return self._v


def test_apply_sets_private_and_restore_puts_back(tmp_path, monkeypatch):
    monkeypatch.setattr(hide_news, "HIDDEN", tmp_path / "hidden.json")
    service = _Service({"V1": {"privacyStatus": "public", "license": "youtube"},
                        "V2": {"privacyStatus": "private"}})      # V2 はもう非公開
    groups = {"keep": [], "noscript": [],
              "hide": [{"video_id": "V1", "build": "a", "short": False},
                       {"video_id": "V2", "build": "b", "short": False}]}
    assert hide_news.apply(service, groups) == 1
    sent = service._v.updates[0]
    assert sent["id"] == "V1" and sent["status"]["privacyStatus"] == "private"
    assert sent["status"]["license"] == "youtube"        # 他の欄を落とさない
    assert (tmp_path / "hidden.json").exists()

    assert hide_news.restore(service) == 1
    assert service._v.status["V1"]["privacyStatus"] == "public"


def test_apply_clears_schedule_and_restore_reschedules_future(tmp_path, monkeypatch):
    monkeypatch.setattr(hide_news, "HIDDEN", tmp_path / "hidden.json")
    service = _Service({"V1": {"privacyStatus": "private", "publishAt": "2999-01-01T10:00:00Z"}})
    groups = {"keep": [], "noscript": [], "hide": [{"video_id": "V1", "build": "a", "short": True}]}
    assert hide_news.apply(service, groups) == 1
    assert "publishAt" not in service._v.status["V1"]    # 予約が残ると勝手に公開される
    hide_news.restore(service)
    assert service._v.status["V1"]["publishAt"] == "2999-01-01T10:00:00Z"


def _built(dir_: Path, name: str, lines: list[tuple[str, str]], viewpoint_lines: int = 0) -> None:
    scenes = [{"lines": [{"speaker": sp, "text": tx} for sp, tx in lines]}]
    if viewpoint_lines:
        scenes.append({"viewpoint": True,
                       "lines": [{"speaker": "解説", "text": "あ" * 10}] * viewpoint_lines})
    (dir_ / name).mkdir(parents=True)
    (dir_ / name / "script.json").write_text(json.dumps({"scenes": scenes}, ensure_ascii=False),
                                             encoding="utf-8")


def test_content_class_by_other_voices(tmp_path):
    # 他人の声が半分を超えたら危ない
    _built(tmp_path, "ng", [("キャスター", "あ" * 10), ("ネット民", "い" * 8), ("久保", "う" * 8)])
    # 見立てがあって反応も少なければ大丈夫
    _built(tmp_path, "safe", [("キャスター", "あ" * 30), ("久保", "う" * 10)], viewpoint_lines=2)
    # 他人の声は少ないが見立てが無い
    _built(tmp_path, "border", [("キャスター", "あ" * 30), ("久保", "う" * 10)])
    assert hide_news.content_class("ng", tmp_path) == "ng"
    assert hide_news.content_class("safe", tmp_path) == "safe"
    assert hide_news.content_class("border_short", tmp_path) == "border"   # ショートは本編で決める
    assert hide_news.content_class("missing", tmp_path) is None


def test_only_ng_keeps_dangerous_main_and_its_short(tmp_path):
    _built(tmp_path, "a", [("ネット民", "い" * 30), ("キャスター", "あ" * 10)])
    _built(tmp_path, "b", [("キャスター", "あ" * 30)], viewpoint_lines=1)
    groups = {"keep": [], "noscript": [{"video_id": "N", "build": "x", "short": False}],
              "hide": [{"video_id": "A", "build": "a", "short": False},
                       {"video_id": "As", "build": "a", "short": True},
                       {"video_id": "B", "build": "b", "short": False}]}
    got = hide_news.only_ng(groups, tmp_path)
    assert [x["video_id"] for x in got["hide"]] == ["A", "As"]   # 本編が先
    assert got["noscript"] == []      # 台本の無いものは「危ない」と言えないので触らない


def test_apply_stops_at_limit_and_reserve(tmp_path, monkeypatch):
    monkeypatch.setattr(hide_news, "HIDDEN", tmp_path / "hidden.json")
    status = {v: {"privacyStatus": "public"} for v in ("V1", "V2", "V3")}
    groups = {"keep": [], "noscript": [],
              "hide": [{"video_id": v, "build": v, "short": False} for v in ("V1", "V2", "V3")]}
    service = _Service(dict(status))
    assert hide_news.apply(service, groups, limit=2, left=lambda: None) == 2
    # 枠の残りが取り置きを切るなら、1本も触らない
    service = _Service({v: {"privacyStatus": "public"} for v in ("V1", "V2", "V3")})
    monkeypatch.setattr(hide_news, "HIDDEN", tmp_path / "hidden2.json")
    assert hide_news.apply(service, groups, reserve=3000, left=lambda: 3020) == 0
    assert service._v.updates == []
