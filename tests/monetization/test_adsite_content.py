from datetime import date

from adsite.content import Page, load_pages, parse_front_matter
from adsite.markdown import render, render_blocks, word_count


def test_front_matter_splits_meta_and_body():
    meta, body = parse_front_matter("---\ntitle: テスト\nads: false\n---\n\n本文です。\n")
    assert meta == {"title": "テスト", "ads": "false"}
    assert body.strip() == "本文です。"


def test_missing_front_matter_treats_all_as_body():
    meta, body = parse_front_matter("見出しのない本文")
    assert meta == {} and body == "見出しのない本文"


def test_unterminated_front_matter_yields_no_body():
    meta, body = parse_front_matter("---\ntitle: 壊れている\n\n本文")
    assert body == ""


def test_load_pages_reads_metadata(tmp_path):
    root = tmp_path / "content"
    (root / "tools").mkdir(parents=True)
    (root / "index.md").write_text("---\ntitle: トップ\n---\n本文", encoding="utf-8")
    (root / "tools" / "calc.md").write_text(
        "---\ntitle: 計算\ndescription: せつめい\ntool: calc\nkeywords: a, b\n"
        "updated: 2026-08-31\nads: false\npriority: 0.9\n---\n本文",
        encoding="utf-8",
    )
    pages = load_pages(root)

    assert [p.slug for p in pages] == ["index", "tools/calc"]  # index が先頭
    calc = pages[1]
    assert calc.tool == "calc" and calc.is_tool
    assert calc.keywords == ("a", "b")
    assert calc.updated == date(2026, 8, 31)
    assert calc.ads is False and calc.priority == 0.9
    assert calc.url_path == "/tools/calc/"
    assert calc.output_path == "tools/calc/index.html"


def test_index_page_maps_to_root():
    page = Page(slug="index", title="t", description="d", body_md="")
    assert page.url_path == "/" and page.output_path == "index.html"


def test_markdown_escapes_html():
    assert render("<script>alert(1)</script>") == "<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>"


def test_markdown_renders_structures():
    html = render("## 見出し\n\n- a\n- b\n\n| x | y |\n|---|---|\n| 1 | 2 |\n")
    assert '<h2 id="見出し">見出し</h2>' in html
    assert "<ul><li>a</li><li>b</li></ul>" in html
    assert "<th>x</th>" in html and "<td>1</td>" in html


def test_external_links_get_rel_attributes():
    html = render("[外部](https://example.com) と [内部](/tools/)")
    assert 'href="https://example.com" target="_blank" rel="noopener nofollow"' in html
    assert '<a href="/tools/">内部</a>' in html


def test_code_span_content_is_not_interpreted():
    assert render("`**not bold**`") == "<p><code>**not bold**</code></p>"


def test_code_block_stays_one_block():
    blocks = render_blocks("p\n\n```\na\nb\n```\n")
    assert len(blocks) == 2
    assert blocks[1] == "<pre><code>a\nb</code></pre>"


def test_word_count_counts_japanese_characters():
    assert word_count("あいうえお hello world") == 5 + 2
