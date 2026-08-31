from adsite.ads import ad_unit, ads_allowed, head_scripts, place_ads
from adsite.config import AdsConfig
from adsite.content import Page

ADS = AdsConfig(
    client="ca-pub-123",
    slot_top="1",
    slot_inline="2",
    slot_bottom="3",
    min_words_for_ads=10,
)


def _page(**kw) -> Page:
    defaults = dict(slug="p", title="t", description="d", body_md="あ" * 100)
    defaults.update(kw)
    return Page(**defaults)


def _blocks(n: int) -> list[str]:
    return [f"<p>block{i}</p>" for i in range(n)]


def test_no_ads_without_client():
    allowed, reason = ads_allowed(_page(), AdsConfig())
    assert not allowed and "クライアントID" in reason


def test_no_ads_on_thin_pages():
    allowed, reason = ads_allowed(_page(body_md="短い"), ADS)
    assert not allowed and "本文量が不足" in reason


def test_no_ads_when_page_opts_out_or_is_noindex():
    assert not ads_allowed(_page(ads=False), ADS)[0]
    assert not ads_allowed(_page(noindex=True), ADS)[0]


def test_places_three_units_on_long_page():
    out = place_ads(_blocks(20), _page(), ADS)
    assert sum("ad-slot" in b for b in out) == 3
    assert "ad-bottom" in out[-1]


def test_short_page_gets_fewer_units():
    out = place_ads(_blocks(4), _page(), ADS)
    positions = [b for b in out if "ad-slot" in b]
    assert len(positions) == 2  # 中盤枠は8ブロック未満では出さない


def test_never_places_ad_next_to_interactive_block():
    blocks = ["<p>intro</p>", '<div class="tool" data-tool="calc"></div>'] + _blocks(18)
    out = place_ads(blocks, _page(), ADS)
    for i, block in enumerate(out):
        if "ad-slot" in block:
            neighbours = out[max(0, i - 1) : i + 2]
            assert not any("data-tool" in n for n in neighbours)


def test_never_splits_heading_from_its_body():
    blocks = ["<p>intro</p>", "<h2 id='a'>A</h2>"] + _blocks(18)
    out = place_ads(blocks, _page(), ADS)
    for i, block in enumerate(out):
        if "ad-slot" in block and i > 0:
            assert not out[i - 1].startswith("<h2")


def test_max_units_is_respected():
    out = place_ads(_blocks(20), _page(), AdsConfig(client="c", slot_top="1", slot_inline="2", slot_bottom="3", min_words_for_ads=10, max_units_per_page=1))
    assert sum("ad-slot" in b for b in out) == 1


def test_ad_unit_reserves_height_to_avoid_layout_shift():
    html = ad_unit("42", ADS, "top")
    assert f"min-height:{ADS.reserved_height_px}px" in html
    assert 'data-ad-slot="42"' in html
    assert ">広告<" in html  # 広告であることの明示


def test_head_scripts_empty_without_client():
    assert head_scripts(AdsConfig()) == ""
    assert "adsbygoogle.js" in head_scripts(ADS)


def test_consent_script_precedes_adsense_loader():
    ads = AdsConfig(client="c", consent_required=True, consent_cmp_script="<script>CMP</script>")
    out = head_scripts(ads)
    assert out.index("CMP") < out.index("adsbygoogle.js")
