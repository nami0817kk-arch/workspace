import json

from moneyloop.cli import main
from tests.monetization.conftest import CONFIG_RAW


def _config_file(tmp_path):
    raw = dict(CONFIG_RAW)
    raw["db_path"] = str(tmp_path / "cli.db")
    raw["output_dir"] = str(tmp_path / "issues")
    path = tmp_path / "config.json"
    path.write_text(json.dumps(raw), encoding="utf-8")
    return str(path)


def _last_json(capsys) -> dict:
    out = capsys.readouterr().out
    return json.loads(out[out.index("{") :])


def test_subscriber_lifecycle_and_report(tmp_path, capsys):
    cfg = _config_file(tmp_path)

    assert main(["--config", cfg, "sub", "add", "a@x.test", "--niche", "ai-ops", "--plan", "pro"]) == 0
    assert main(["--config", cfg, "revenue", "accrue"]) == 0
    assert main(["--config", cfg, "report", "--json"]) == 0

    report = _last_json(capsys)
    assert report["revenue_usd"] == 30.0
    assert report["paying_subscribers"] == 1

    assert main(["--config", cfg, "sub", "cancel", "a@x.test", "--niche", "ai-ops"]) == 0
    assert main(["--config", cfg, "sub", "cancel", "ghost@x.test", "--niche", "ai-ops"]) == 1


def test_adding_unknown_plan_fails_loudly(tmp_path):
    cfg = _config_file(tmp_path)
    try:
        main(["--config", cfg, "sub", "add", "a@x.test", "--niche", "ai-ops", "--plan", "enterprise"])
    except KeyError as exc:
        assert "enterprise" in str(exc)
    else:
        raise AssertionError("未定義プランはエラーになるべき")


def test_plan_command_backsolves_subscriber_count(tmp_path, capsys):
    cfg = _config_file(tmp_path)
    assert main(
        ["--config", cfg, "plan", "--target-profit", "3000", "--assumed-cost", "30", "--conversion", "5"]
    ) == 0
    out = capsys.readouterr().out
    assert "必要な有料購読者: 101人" in out  # (3000 + 30) / 30 = 101
    assert "必要な無料読者規模 2020人" in out
