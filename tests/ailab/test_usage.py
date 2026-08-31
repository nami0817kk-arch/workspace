"""利用量の記録と集計。"""

import json

from ailab import usage
from ailab.core.types import GeneratedImage


def image(provider="openai", model="gpt-image-2", data=b"xxx"):
    return GeneratedImage(data=data, provider=provider, model=model, prompt="猫のイラスト")


def test_record_appends_one_line_per_generation(tmp_path):
    log = tmp_path / "usage.jsonl"

    usage.record([image(), image()], path=log)
    usage.record([image(provider="local", model="abstract-v1")], path=log)

    entries = usage.load(log)
    assert len(entries) == 2
    assert entries[0]["images"] == 2
    assert entries[0]["provider"] == "openai"
    assert entries[1]["cost_usd"] == 0.0  # local は無料


def test_record_of_nothing_is_a_noop(tmp_path):
    log = tmp_path / "usage.jsonl"
    usage.record([], path=log)
    assert not log.exists()


def test_record_failure_does_not_raise(tmp_path):
    """記録できなくても生成そのものは成功させる。"""
    usage.record([image()], path=tmp_path / "no" / "such" / "dir" / "x" / "usage.jsonl")


def test_broken_lines_are_skipped(tmp_path):
    log = tmp_path / "usage.jsonl"
    log.write_text('{"provider": "openai", "images": 1}\n壊れている\n[]\n', encoding="utf-8")
    assert len(usage.load(log)) == 1


def test_unit_cost_matches_the_longest_model_prefix():
    assert usage.unit_cost("openai", "gpt-image-2") == 0.03
    assert usage.unit_cost("stability", "ultra") == 0.08
    assert usage.unit_cost("pollinations", "flux") == 0.0
    assert usage.unit_cost("unknown-provider", "x") == 0.0


def test_costs_can_be_overridden(tmp_path, monkeypatch):
    monkeypatch.setenv("AILAB_OUTPUT_DIR", str(tmp_path))
    (tmp_path / usage.COSTS_NAME).write_text(
        json.dumps({"openai": {"gpt-image-2": 0.5}}), encoding="utf-8"
    )
    assert usage.unit_cost("openai", "gpt-image-2") == 0.5


def test_broken_cost_file_falls_back_to_defaults(tmp_path, monkeypatch):
    monkeypatch.setenv("AILAB_OUTPUT_DIR", str(tmp_path))
    (tmp_path / usage.COSTS_NAME).write_text("{壊れている", encoding="utf-8")
    assert usage.unit_cost("openai", "gpt-image-2") == 0.03


def test_summary_groups_by_provider_and_model(tmp_path):
    log = tmp_path / "usage.jsonl"
    usage.record([image(), image()], path=log)
    usage.record([image(provider="replicate", model="black-forest-labs/flux-schnell")], path=log)

    summary = usage.summarize(path=log)

    assert summary["images"] == 3
    assert summary["breakdown"][0]["provider"] == "openai"  # 高い順
    assert summary["cost_usd"] > 0


def test_summary_can_be_limited_to_recent_days(tmp_path):
    log = tmp_path / "usage.jsonl"
    log.write_text(
        json.dumps({"ts": "2020-01-01T00:00:00", "provider": "openai", "images": 1, "cost_usd": 1})
        + "\n",
        encoding="utf-8",
    )
    assert usage.summarize(days=7, path=log)["entries"] == 0
    assert usage.summarize(path=log)["entries"] == 1


def test_generation_through_the_entry_point_is_recorded(tmp_path, monkeypatch):
    """CLI・レシピ・MCP は imagegen.generate を通るので、そこで記録する。"""
    from ailab import imagegen

    monkeypatch.setenv("AILAB_OUTPUT_DIR", str(tmp_path))
    imagegen.generate("記録テスト", provider="local", size="64x64")

    entries = usage.load(tmp_path / usage.LOG_NAME)
    assert len(entries) == 1 and entries[0]["provider"] == "local"
