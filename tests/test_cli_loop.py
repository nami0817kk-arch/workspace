"""CLI を通した通し試験。

「1回目に指摘 → 直す → 2回目は解決として記録される」という
このシステムの一番大事なループが本当に閉じているかを見る。
"""

from __future__ import annotations

import json

import pytest

from growth.cli import main
from growth.ledger import Ledger
from helpers import PY_APP2, make_repo

REGISTRY = """
[config]
max_proposals_per_project = 3
max_proposals_total = 10

[[project]]
key = "app"
repo = "owner/app"

[[project]]
key = "tidy"
repo = "owner/tidy"
"""

TIDY = {
    "README.md": "# tidy\n## 使い方\n```bash\npytest\n```\n",
    "main.py": PY_APP2,
    "util.py": PY_APP2,
    "requirements.txt": "requests==2.31.0\n",
    ".gitignore": ".env\n",
    "CLAUDE.md": "# tidy\n",
    "tests/test_util.py": "def test_x():\n    assert True\n",
    ".github/workflows/ci.yml": "jobs:\n  t:\n    steps:\n      - uses: actions/checkout@v4\n      - run: pytest\n",
    ".github/dependabot.yml": "version: 2\n",
}


def _setup(tmp_path):
    ws = tmp_path / "ws"
    make_repo(ws, "app", {"main.py": PY_APP2, "util.py": PY_APP2})
    make_repo(ws, "tidy", TIDY)
    registry = tmp_path / "projects.toml"
    registry.write_text(REGISTRY, encoding="utf-8")
    return ws, registry


def _run(tmp_path, ws, registry, extra=()):
    return main([
        "--registry", str(registry),
        "--ledger", str(tmp_path / "ledger.json"),
        "run",
        "--workspace", str(ws),
        "--digest-dir", str(tmp_path / "digests"),
        "--dashboard", str(tmp_path / "GROWTH.md"),
        *extra,
    ])


def test_full_loop_writes_digest_dashboard_and_ledger(tmp_path):
    ws, registry = _setup(tmp_path)
    assert _run(tmp_path, ws, registry) == 0

    digests = list((tmp_path / "digests").glob("*.md"))
    assert len(digests) == 1
    assert "成長ループ ダイジェスト" in digests[0].read_text(encoding="utf-8")
    assert (tmp_path / "GROWTH.md").exists()

    ledger = Ledger.load(tmp_path / "ledger.json")
    assert ledger.open_fingerprints()
    assert ledger.latest_scores()["tidy"] > ledger.latest_scores()["app"]


def test_second_run_is_idempotent(tmp_path):
    """同じ状態で2回走らせても、提案が増殖しない。

    「何回言ったか」は日単位で数えるので、同じ日の2回目では増えない。
    手元で確認のため繰り返し実行しても、提案が沈まないようにするため。
    """
    ws, registry = _setup(tmp_path)
    _run(tmp_path, ws, registry)
    before = len(Ledger.load(tmp_path / "ledger.json").proposals)

    _run(tmp_path, ws, registry)
    after = Ledger.load(tmp_path / "ledger.json")
    assert len(after.proposals) == before
    assert all(e["seen_count"] == 1 for e in after.proposals.values())


def test_fixing_a_gap_is_recorded_as_resolved(tmp_path):
    ws, registry = _setup(tmp_path)
    _run(tmp_path, ws, registry)

    ledger = Ledger.load(tmp_path / "ledger.json")
    missing_tests = next(
        fp for fp, e in ledger.proposals.items()
        if e["project"] == "app" and e["rule_id"] == "test.missing"
    )
    score_before = ledger.latest_scores()["app"]

    # 指摘どおりテストを足す
    (ws / "app" / "tests").mkdir()
    (ws / "app" / "tests" / "test_util.py").write_text(
        "def test_x():\n    assert True\n", encoding="utf-8"
    )
    _run(tmp_path, ws, registry)

    ledger = Ledger.load(tmp_path / "ledger.json")
    assert ledger.proposals[missing_tests]["status"] == "resolved"
    assert ledger.latest_scores()["app"] > score_before


def test_dismiss_stops_a_proposal_from_coming_back(tmp_path):
    ws, registry = _setup(tmp_path)
    _run(tmp_path, ws, registry)

    ledger = Ledger.load(tmp_path / "ledger.json")
    target = next(
        fp for fp, e in ledger.proposals.items()
        if e["project"] == "app" and e["rule_id"] == "test.missing"
    )
    assert main([
        "--registry", str(registry), "--ledger", str(tmp_path / "ledger.json"),
        "dismiss", target, "-n", "この PJT では書かない",
    ]) == 0

    _run(tmp_path, ws, registry, ["--json"])
    reloaded = Ledger.load(tmp_path / "ledger.json")
    assert reloaded.proposals[target]["status"] == "dismissed"
    assert reloaded.proposals[target]["note"] == "この PJT では書かない"


def test_dry_run_writes_nothing(tmp_path):
    ws, registry = _setup(tmp_path)
    assert _run(tmp_path, ws, registry, ["--dry-run"]) == 0
    assert not (tmp_path / "ledger.json").exists()
    assert not (tmp_path / "GROWTH.md").exists()
    assert not (tmp_path / "digests").exists()


def test_json_output_is_machine_readable(tmp_path, capsys):
    ws, registry = _setup(tmp_path)
    _run(tmp_path, ws, registry, ["--json"])
    payload = json.loads(capsys.readouterr().out)
    assert payload["projects"] and payload["proposals"]
    assert set(payload["proposals"][0]) >= {"fingerprint", "rule_id", "project", "priority"}


def test_missing_workspace_fails_loudly(tmp_path):
    _, registry = _setup(tmp_path)
    assert _run(tmp_path, tmp_path / "nowhere", registry) == 2


def test_status_and_done_commands(tmp_path, capsys):
    ws, registry = _setup(tmp_path)
    _run(tmp_path, ws, registry)
    capsys.readouterr()

    assert main([
        "--registry", str(registry), "--ledger", str(tmp_path / "ledger.json"), "status",
    ]) == 0
    assert "未対応" in capsys.readouterr().out

    fp = Ledger.load(tmp_path / "ledger.json").open_fingerprints()[0]
    assert main([
        "--registry", str(registry), "--ledger", str(tmp_path / "ledger.json"), "done", fp,
    ]) == 0
    assert Ledger.load(tmp_path / "ledger.json").proposals[fp]["status"] == "resolved"


def test_done_on_unknown_fingerprint_returns_error(tmp_path):
    _, registry = _setup(tmp_path)
    assert main([
        "--registry", str(registry), "--ledger", str(tmp_path / "ledger.json"),
        "done", "0123456789ab",
    ]) == 1


# --- サマリ Issue の重複起票 ---------------------------------------------

class _FakeGitHub:
    """Issue 一覧 API の遅延を再現するスタブ。

    実際の GitHub は、作成直後の Issue を一覧 API がまだ返さないことがある。
    そこで重複起票したのが実運用で踏んだ不具合なので、その状況を固定する。
    """

    def __init__(self, *, visible=False, lookup_fails=False):
        self.created: list[tuple[str, str]] = []
        self.visible = visible
        self.lookup_fails = lookup_fails

    def find_issue_by_marker(self, repo, marker):
        if self.lookup_fails:
            raise _gh.GitHubError("boom")
        if self.visible and self.created:
            return {"html_url": "https://example.test/1", "state": "open"}
        return None

    def create_issue(self, repo, title, body):
        self.created.append((repo, title))
        return f"https://example.test/{len(self.created)}"


from growth import github as _gh  # noqa: E402


def _patch_github(monkeypatch, fake):
    monkeypatch.setattr(_gh, "find_issue_by_marker", fake.find_issue_by_marker)
    monkeypatch.setattr(_gh, "create_issue", fake.create_issue)


def test_summary_issue_is_filed_once(tmp_path, monkeypatch):
    ws, registry = _setup(tmp_path)
    fake = _FakeGitHub()
    _patch_github(monkeypatch, fake)

    _run(tmp_path, ws, registry, ["--summary-issue", "owner/home"])
    assert len(fake.created) == 1
    assert Ledger.load(tmp_path / "ledger.json").summary_issues


def test_summary_issue_is_not_duplicated_when_the_api_lags(tmp_path, monkeypatch):
    ws, registry = _setup(tmp_path)
    # visible=False: 作った直後の Issue が一覧に出てこない状況
    fake = _FakeGitHub(visible=False)
    _patch_github(monkeypatch, fake)

    _run(tmp_path, ws, registry, ["--summary-issue", "owner/home"])
    _run(tmp_path, ws, registry, ["--summary-issue", "owner/home"])
    assert len(fake.created) == 1


def test_summary_issue_is_skipped_when_the_check_fails(tmp_path, monkeypatch):
    """確認できないときは、二重に立てるより出さないほうがまし。"""
    ws, registry = _setup(tmp_path)
    fake = _FakeGitHub(lookup_fails=True)
    _patch_github(monkeypatch, fake)

    assert _run(tmp_path, ws, registry, ["--summary-issue", "owner/home"]) == 0
    assert fake.created == []


def test_existing_issue_found_on_github_is_adopted(tmp_path, monkeypatch):
    ws, registry = _setup(tmp_path)
    fake = _FakeGitHub(visible=True)
    fake.created.append(("owner/home", "既にある"))
    _patch_github(monkeypatch, fake)

    _run(tmp_path, ws, registry, ["--summary-issue", "owner/home"])
    assert len(fake.created) == 1
    assert Ledger.load(tmp_path / "ledger.json").summary_issues


# --- 保留（snooze） --------------------------------------------------------

def test_snooze_keeps_the_record_but_frees_the_action_slot(tmp_path):
    """「今はやらない」を、消さずに理由つきで残せること。"""
    ws, registry = _setup(tmp_path)
    _run(tmp_path, ws, registry)

    ledger = Ledger.load(tmp_path / "ledger.json")
    target = next(
        fp for fp, e in ledger.proposals.items()
        if e["project"] == "app" and e["rule_id"] == "test.missing"
    )
    assert main([
        "--registry", str(registry), "--ledger", str(tmp_path / "ledger.json"),
        "snooze", target, "-n", "先に設計を決めるため",
    ]) == 0

    _run(tmp_path, ws, registry)
    reloaded = Ledger.load(tmp_path / "ledger.json")
    entry = reloaded.proposals[target]
    assert entry["status"] == "snoozed"
    assert entry["note"] == "先に設計を決めるため"
    # 台帳には残るが、未対応の作業としては数えない
    assert target not in reloaded.open_fingerprints()
    assert target in reloaded.snoozed_fingerprints()


def test_snoozed_item_appears_in_the_digest_with_its_reason(tmp_path):
    ws, registry = _setup(tmp_path)
    _run(tmp_path, ws, registry)
    ledger = Ledger.load(tmp_path / "ledger.json")
    target = ledger.open_fingerprints()[0]
    main(["--registry", str(registry), "--ledger", str(tmp_path / "ledger.json"),
          "snooze", target, "-n", "上流の方針待ち"])

    _run(tmp_path, ws, registry)
    digest = next((tmp_path / "digests").glob("*.md")).read_text(encoding="utf-8")
    assert "保留中（理由あり）" in digest
    assert "上流の方針待ち" in digest


def test_snoozed_finding_that_gets_fixed_is_recorded_as_resolved(tmp_path):
    """保留にしたものを直したら、ちゃんと解決として数えられること。"""
    ws, registry = _setup(tmp_path)
    _run(tmp_path, ws, registry)
    ledger = Ledger.load(tmp_path / "ledger.json")
    target = next(
        fp for fp, e in ledger.proposals.items()
        if e["project"] == "app" and e["rule_id"] == "test.missing"
    )
    main(["--registry", str(registry), "--ledger", str(tmp_path / "ledger.json"),
          "snooze", target, "-n", "あとで"])

    (ws / "app" / "tests").mkdir()
    (ws / "app" / "tests" / "test_util.py").write_text(
        "def test_x():\n    assert True\n", encoding="utf-8"
    )
    _run(tmp_path, ws, registry)
    assert Ledger.load(tmp_path / "ledger.json").proposals[target]["status"] == "resolved"


def test_snooze_requires_a_reason(tmp_path, capsys):
    ws, registry = _setup(tmp_path)
    _run(tmp_path, ws, registry)
    fp = Ledger.load(tmp_path / "ledger.json").open_fingerprints()[0]
    with pytest.raises(SystemExit):
        main(["--registry", str(registry), "--ledger", str(tmp_path / "ledger.json"),
              "snooze", fp])
