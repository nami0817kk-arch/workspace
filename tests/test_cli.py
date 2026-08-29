import json

from ailab import cli
from ailab.illust import downloader as dl, openverse
from fakes import FakeResponse, FakeSession

OPENVERSE_BODY = {
    "results": [
        {
            "id": "abc",
            "title": "Cat",
            "url": "https://example.com/cat.png",
            "foreign_landing_url": "https://example.com/page",
            "license": "by",
            "license_version": "4.0",
            "creator": "Taro",
            "width": 100,
            "height": 100,
        }
    ]
}


def test_status_lists_providers_and_sources(capsys):
    assert cli.main(["status"]) == 0
    out = capsys.readouterr().out
    assert "local" in out and "openverse" in out


def test_gen_writes_image(tmp_path, capsys):
    assert cli.main(["gen", "テスト", "--provider", "local", "--size", "64x64", "-o", str(tmp_path)]) == 0
    files = list(tmp_path.glob("*.png"))
    assert len(files) == 1
    assert "保存しました" in capsys.readouterr().out


def test_gen_multiple_images(tmp_path):
    cli.main(["gen", "複数", "--provider", "local", "--size", "64x64", "-n", "2", "-o", str(tmp_path)])
    assert len(list(tmp_path.glob("*.png"))) == 2


def test_gen_reports_missing_api_key(monkeypatch, capsys):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    monkeypatch.setattr(cli, "load_dotenv", lambda *a, **k: {})
    assert cli.main(["gen", "猫", "--provider", "openai"]) == 1
    assert "OPENAI_API_KEY" in capsys.readouterr().err


def test_gen_reports_invalid_size(capsys):
    assert cli.main(["gen", "猫", "--provider", "local", "--size", "おおきい"]) == 1
    assert "サイズの指定が不正" in capsys.readouterr().err


def test_search_json_output(monkeypatch, capsys):
    monkeypatch.setattr(
        openverse, "session", lambda headers=None: FakeSession([FakeResponse(json_data=OPENVERSE_BODY)])
    )
    assert cli.main(["search", "猫", "--source", "openverse", "--json"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload[0]["license"] == "BY 4.0"
    assert payload[0]["attribution"].startswith('"Cat" by Taro')


def test_search_text_output(monkeypatch, capsys):
    monkeypatch.setattr(
        openverse, "session", lambda headers=None: FakeSession([FakeResponse(json_data=OPENVERSE_BODY)])
    )
    cli.main(["search", "猫", "--source", "openverse"])
    out = capsys.readouterr().out
    assert "ライセンス: BY 4.0" in out


def test_fetch_downloads_and_writes_credits(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(
        openverse, "session", lambda headers=None: FakeSession([FakeResponse(json_data=OPENVERSE_BODY)])
    )
    monkeypatch.setattr(
        dl, "session", lambda headers=None: FakeSession([FakeResponse(content=b"\x89PNG\r\n\x1a\n")])
    )
    assert cli.main(["fetch", "猫", "--source", "openverse", "-l", "1", "-o", str(tmp_path)]) == 0
    assert (tmp_path / "CREDITS.md").exists()
    assert "保存しました" in capsys.readouterr().out


def test_fetch_reports_no_results(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(
        openverse, "session", lambda headers=None: FakeSession([FakeResponse(json_data={"results": []})])
    )
    assert cli.main(["fetch", "存在しない", "--source", "openverse", "-o", str(tmp_path)]) == 1
    assert "見つかりませんでした" in capsys.readouterr().out


def test_network_error_is_reported_without_traceback(monkeypatch, capsys):
    import requests

    def boom(*args, **kwargs):
        raise requests.ConnectionError("接続できません")

    monkeypatch.setattr(cli.illust, "search", boom)
    assert cli.main(["search", "猫", "--source", "openverse"]) == 1
    assert "ネットワークエラー" in capsys.readouterr().err
