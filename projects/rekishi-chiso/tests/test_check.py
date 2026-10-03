from types import SimpleNamespace as NS

from chiso import check
from chiso.voice import Voice


def _sc(lines, shorts=None):
    return NS(lines=lines, shorts=shorts or {}, short_lines=lambda sid: [l for l in lines if sid in l.shorts])


def L(text, speaker="語り", tone="普通", card=None, shorts=()):
    return NS(index=0, text=text, speaker=speaker, tone=tone, card=card, shorts=shorts, background=None, portrait=None)


def test_lint_long_line_and_short_estimate():
    sc = _sc([L("あ" * 100, shorts=("s1",)), L("い" * 400, shorts=("s1",))], {"s1": {}})
    w = check.lint(sc, short_limit=60)
    assert any("100字" in x for x in w)
    assert any("ショート s1" in x for x in w)


def test_saturation_counts_only_hard_limits():
    sc = _sc([L("え", speaker="聞き", tone="驚き"), L("う", speaker="聞き")])
    strong = {"聞き": Voice(8, speed=1.12, intonation=1.45)}
    calm = {"聞き": Voice(8, speed=1.0, intonation=1.0, tone_strength=0.4, max_intonation=1.3, max_speed=1.08)}
    assert check.saturation(sc, strong)["聞き"] == (1, 2)          # 驚きで 2.0 を超える
    assert check.saturation(sc, calm)["聞き"] == (0, 2)            # 控えめの上限は狙いどおり


def test_missing_assets(tmp_path):
    (tmp_path / "a.jpg").write_bytes(b"x")
    pic = lambda n: NS(image=n)
    sc = _sc([NS(background=pic("a.jpg"), portrait=pic("b.jpg"))])
    assert check.missing_assets(sc, tmp_path) == ["b.jpg"]
