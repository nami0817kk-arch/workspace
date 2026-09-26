import json
import re
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

import build as builder  # noqa: E402
from src import store, theme  # noqa: E402

CONFIG = {
    "name": "テストサイト", "base_url": "https://example.test/price",
    "description": "テスト", "owner": "テスト運営", "contact_email": "test@example.test",
    "genres": [{"genre_id": "1"}], "hits_per_genre": 30,
    "drop_threshold": 0.05, "near_low_threshold": 0.02, "history_tail_days": 90,
}


def make_data(tmp: Path, items: dict, series: dict):
    """series: {item_code: [価格を古い順に]} から履歴を組み立てる。

    None を挟むとその日は記録しない。途中から追跡し始めた商品を作るのに使う。
    """
    summary = {}
    days = max(len(v) for v in series.values())
    for i in range(days):
        day = f"2026-07-{i + 1:02d}"
        rows = [{"item_code": c, "price": p[i], "review_count": 0, "review_average": 0.0}
                for c, p in series.items() if i < len(p) and p[i] is not None]
        summary = store.update_summary(summary, rows, day, 90)
    store.save_json(tmp / "data" / "summary.json", summary)
    store.save_json(tmp / "data" / "items.json", items)
    store.save_json(tmp / "config.json", CONFIG)


class BuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name)
        make_data(cls.root, {
            "shop:falling": {"name": "値下がりした商品", "shop": "店A",
                             "url": "https://hb.afl.rakuten.co.jp/x/1",
                             "image": "https://img.test/1.jpg", "genre_id": "1"},
            "shop:cheap": {"name": "最安値の商品", "shop": "店B",
                           "url": "https://hb.afl.rakuten.co.jp/x/2",
                           "image": "", "genre_id": "1"},
            "shop:evil</script><script>alert(1)</script>": {
                "name": '危険な名前</script><script>alert(1)</script>&"', "shop": "店C",
                "url": "https://hb.afl.rakuten.co.jp/x/3", "image": "", "genre_id": "1"},
            "shop:gone": {"name": "履歴のない商品", "shop": "店D", "url": "", "image": "",
                          "genre_id": "1"},
        }, {
            "shop:falling": [10000] * 9 + [8000],
            "shop:cheap": [5000] * 8 + [4000, 4000],
            "shop:evil</script><script>alert(1)</script>": [3000] * 10,
        })
        cls.out = cls.root / "dist"
        cls.stats = builder.build(cls.root, cls.out)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def read(self, *parts) -> str:
        return (self.out.joinpath(*parts)).read_text(encoding="utf-8")

    def css_name(self) -> str:
        """配信するスタイルの名前。中身の指紋が入るので毎回変わる。"""
        found = [p.name for p in self.out.glob("style.*.css")]
        self.assertEqual(len(found), 1, found)
        return found[0]

    # --- 構成 ---
    def test_スタイルの名前に中身の指紋が入る(self):
        """style.css 固定だと、直しても Cloudflare のキャッシュ（実測4時間）が
        切れるまで読み手に届かない。名前が変われば即座に取りに来る。"""
        css = self.css_name()

        self.assertRegex(css, r"^style\.[0-9a-f]{8}\.css$")
        # 全ページが実在するファイルを指していること
        for path in list(self.out.rglob("*.html"))[:20]:
            with self.subTest(path=path.name):
                ref = re.search(r'rel="stylesheet" href="([^"]+)"',
                                path.read_text(encoding="utf-8")).group(1)
                self.assertTrue(ref.endswith(css), ref)

    def test_expected_pages_exist(self):
        for path in ("index.html", "lows/index.html", "about/index.html",
                     "privacy/index.html", "contact/index.html",
                     "sitemap.xml", "robots.txt"):
            with self.subTest(path=path):
                self.assertTrue((self.out / path).exists(), path)

    def test_item_without_history_gets_no_page(self):
        """今日の価格が無い商品を出すと、古い値を今日の値として見せてしまう。"""
        self.assertEqual(self.stats["items"], 3)
        self.assertNotIn("履歴のない商品", self.read("index.html") + self.read("lows", "index.html"))

    def test_drop_is_listed_on_the_front_page(self):
        # トップは案内だけのページになり、点で並べた一覧は /now/ へ移した
        # （2026-09-26 ユーザー指示）
        page = self.read("now", "index.html")
        self.assertIn("値下がりした商品", page)
        self.assertIn("▼20.0%", page)
        self.assertIn("10,000円", page)   # 変更前の価格

    def test_low_is_listed(self):
        self.assertIn("最安値の商品", self.read("lows", "index.html"))

    # --- 収益と法令 ---
    def test_every_affiliate_link_is_marked_sponsored(self):
        """rel の申告が無いリンクは検索エンジンへの違反になる。"""
        for path in self.out.rglob("*.html"):
            html = path.read_text(encoding="utf-8")
            for link in re.findall(r'<a\b[^>]*href="https://hb\.afl\.rakuten\.co\.jp[^"]*"[^>]*>', html):
                with self.subTest(path=path.name):
                    self.assertIn('rel="sponsored nofollow noopener"', link)

    def test_disclosure_appears_on_every_page(self):
        """ステマ規制。広告である旨の表示が無いページがあってはならない。"""
        for path in self.out.rglob("*.html"):
            with self.subTest(path=str(path.relative_to(self.out))):
                self.assertIn("楽天アフィリエイト", path.read_text(encoding="utf-8"))

    def test_lowest_price_claim_is_qualified(self):
        """「最安値」が市場全体の最安値だと誤解されないよう、範囲を明示する。"""
        self.assertIn("当サイトが記録した期間内での比較", self.read("index.html"))

    # --- 安全性 ---
    def test_item_name_cannot_break_out_of_the_json_ld_block(self):
        page = self.read("item", theme.slug("shop:evil</script><script>alert(1)</script>"),
                         "index.html")
        block = re.search(r'<script type="application/ld\+json">(.*?)</script>', page, re.S)
        self.assertIsNotNone(block)
        self.assertNotIn("<script>alert", block.group(1))
        parsed = json.loads(block.group(1))   # 妥当なJSONとして読めること
        self.assertIn("alert(1)", parsed["name"])   # 中身は失われていない

    def test_item_name_is_escaped_in_the_body(self):
        page = self.read("item", theme.slug("shop:evil</script><script>alert(1)</script>"),
                         "index.html")
        self.assertNotIn("<script>alert(1)</script>", page.split("application/ld+json")[0])

    def test_slugs_are_url_safe_and_unique(self):
        a = theme.slug("shop:evil</script>")
        b = theme.slug("shop:evil<script>")
        self.assertRegex(a, r"^[a-z0-9-]+$")
        self.assertNotEqual(a, b)   # 記号を潰しても別商品が衝突しないこと

    # --- 配信 ---
    def test_asset_paths_are_relative(self):
        """GitHub Pages のサブディレクトリ配信で絶対パスは 404 になる。"""
        css = self.css_name()
        self.assertIn(f'href="{css}"', self.read("index.html"))
        self.assertIn(f'href="../{css}"', self.read("lows", "index.html"))
        self.assertIn(f'href="../../{css}"',
                      self.read("item", theme.slug("shop:cheap"), "index.html"))

    def test_no_absolute_asset_paths_anywhere(self):
        """404 だけは例外。存在しないパスすべてに返され、URL は要求されたまま
        （例 /item/存在しない/更に深い/）なので、相対では CSS もリンクも壊れる。
        その 404 も "/" 決め打ちではなく base_url から導いている（root_prefix）。"""
        for path in self.out.rglob("*.html"):
            if path.name == "404.html":
                continue
            with self.subTest(path=path.name):
                self.assertNotIn('href="/style.', path.read_text(encoding="utf-8"))

    def test_404_uses_the_site_root_not_a_hardcoded_slash(self):
        # サブディレクトリ配信では "/" 決め打ちが壊れる
        html = self.read("404.html")
        self.assertIn('href="/price/style.', html)
        self.assertIn('href="/price/lows/"', html)

    def test_canonical_uses_the_public_url(self):
        self.assertIn('<link rel="canonical" href="https://example.test/price/">',
                      self.read("index.html"))

    def test_sitemap_lists_every_generated_page(self):
        sm = self.read("sitemap.xml")
        self.assertEqual(sm.count("<loc>"), self.stats["pages"])
        self.assertIn("https://example.test/price/lows/", sm)

    def test_rebuild_is_clean(self):
        """消した商品のページが残り続けないこと。"""
        stale = self.out / "item" / "stale-page"
        stale.mkdir(parents=True, exist_ok=True)
        (stale / "index.html").write_text("old", encoding="utf-8")
        builder.build(self.root, self.out)
        self.assertFalse(stale.exists())


class EmptyDataTest(unittest.TestCase):
    def test_builds_without_crashing_when_there_is_no_data_yet(self):
        """初回、データが無い状態でも公開できる形にはなること。"""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            store.save_json(root / "config.json", CONFIG)
            out = root / "dist"
            stats = builder.build(root, out)
            self.assertEqual(stats["items"], 0)
            # 点で並べた一覧は /now/（2026-09-26 にトップを案内ページへ replaced）。
            # 値下がりは動きの少ない日にほぼ空になるため、入口に置かない。
            top = (out / "now" / "index.html").read_text(encoding="utf-8")
            self.assertIn("条件がそろった商品はまだありません", top)
            self.assertIn("判定できるほどの値下がりはありません",
                          (out / "drops" / "index.html").read_text(encoding="utf-8"))
            # 空でも行き止まりにしない
            self.assertIn("商品を探す", top)


if __name__ == "__main__":
    unittest.main(verbosity=2)


class ThinItemTest(unittest.TestCase):
    """記録が1日しかない商品は索引に載せない。

    どの一覧にも載らないまま検索結果にだけ出るページになる（実測270件）。
    推移も最安値も示せないので、載せても読み手の役に立たない。
    ページ自体は残す。見守りや外の記事からの行き先になっている。
    """

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name)
        make_data(cls.root, {
            "shop:old": {"name": "記録のある商品", "shop": "店A",
                         "url": "https://hb.afl.rakuten.co.jp/x/1", "image": "",
                         "genre_id": "1"},
            "shop:new": {"name": "今日から記録した商品", "shop": "店B",
                         "url": "https://hb.afl.rakuten.co.jp/x/2", "image": "",
                         "genre_id": "1"},
        }, {
            "shop:old": [9000] * 9 + [8000],
            "shop:new": [None] * 9 + [5000],
        })
        cls.out = cls.root / "dist"
        builder.build(cls.root, cls.out)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def page(self, code: str) -> str:
        return (self.out / "item" / theme.slug(code) / "index.html").read_text(
            encoding="utf-8")

    def test_1日だけの商品はnoindex(self):
        self.assertIn('content="noindex,follow"', self.page("shop:new"))

    def test_1日だけの商品はサイトマップに載せない(self):
        sitemap = (self.out / "sitemap.xml").read_text(encoding="utf-8")

        self.assertNotIn(theme.slug("shop:new"), sitemap)

    def test_ページ自体は残す(self):
        self.assertTrue((self.out / "item" / theme.slug("shop:new")).exists())

    def test_記録のある商品は索引に載せる(self):
        sitemap = (self.out / "sitemap.xml").read_text(encoding="utf-8")

        self.assertIn('content="index,follow', self.page("shop:old"))
        self.assertIn(theme.slug("shop:old"), sitemap)


class SearchAppearanceTest(unittest.TestCase):
    """検索結果に出る文字列。題と説明が他のページと区別が付くこと。"""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name)
        make_data(cls.root, {
            "shop:a": {"name": "【9/25限定！抽選で最大100%P還元※要エントリー】"
                               "ロイヤルカナン インドア 4kg",
                       "shop": "店A", "url": "https://hb.afl.rakuten.co.jp/x/1",
                       "image": "", "genre_id": "1"},
        }, {"shop:a": [5000] * 9 + [4000]})
        cls.out = cls.root / "dist"
        builder.build(cls.root, cls.out)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_題は宣伝ではなく商品名から始まる(self):
        page = (self.out / "item" / theme.slug("shop:a") / "index.html").read_text(
            encoding="utf-8")
        title = re.search(r"<title>([^<]*)</title>", page).group(1)

        self.assertTrue(title.startswith("ロイヤルカナン"), title)

    def test_説明に値段と日付を入れる(self):
        page = (self.out / "item" / theme.slug("shop:a") / "index.html").read_text(
            encoding="utf-8")
        desc = re.search(r'name="description" content="([^"]*)"', page).group(1)

        # 商品名を繰り返すだけでは、検索結果に並んだとき見分けが付かない
        self.assertIn("4,000円", desc)
        self.assertIn("月", desc)

    def test_検索の索引にも宣伝を積まない(self):
        index = json.loads((self.out / "search-index.json").read_text(encoding="utf-8"))

        self.assertTrue(index[0][1].startswith("ロイヤルカナン"), index[0][1])


class UpdatedDateTest(unittest.TestCase):
    """「最終更新」は価格を記録した日であること。

    ビルドした日を出していたため、取得が失敗した朝でも「最終更新 今日」と
    表示され、前日の価格を今日の価格として見せていた（2026-09-26 に発生）。
    """

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name)
        make_data(cls.root, {
            "shop:a": {"name": "記録のある商品", "shop": "店A",
                       "url": "https://hb.afl.rakuten.co.jp/x/1", "image": "",
                       "genre_id": "1"},
        }, {"shop:a": [9000] * 9 + [8000]})
        # 取得できた最後の日を 2026-09-25 とする（今日ではない）
        snaps = cls.root / "data" / "snapshots"
        snaps.mkdir(parents=True, exist_ok=True)
        for day in ("2026-09-24", "2026-09-25"):
            (snaps / f"{day}.csv.gz").write_bytes(b"")
        cls.out = cls.root / "dist"
        cls.stats = builder.build(cls.root, cls.out)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_最終更新は記録した日を出す(self):
        self.assertEqual(self.stats["updated"], "2026-09-25")
        self.assertIn("最終更新: 2026-09-25",
                      (self.out / "index.html").read_text(encoding="utf-8"))

    def test_ビルドした日は出さない(self):
        page = (self.out / "index.html").read_text(encoding="utf-8")

        self.assertNotIn(builder.today(), page)

    def test_記録が1日も無ければ今日で組む(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            make_data(root, {"shop:a": {"name": "商品", "shop": "店", "url": "",
                                        "image": "", "genre_id": "1"}},
                      {"shop:a": [1000] * 10})

            stats = builder.build(root, root / "dist")

        self.assertEqual(stats["updated"], builder.today())


class HomeSearchTest(unittest.TestCase):
    """トップの一番上の検索窓。

    トップは一覧そのもので、検索から来た人はいきなり600件の並びと採点の
    説明を読まされていた。価格を追うサイトで最初にやるのは
    「自分の商品を探す」。
    """

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name)
        make_data(cls.root, {
            "shop:a": {"name": "商品A", "shop": "店A",
                       "url": "https://hb.afl.rakuten.co.jp/x/1", "image": "",
                       "genre_id": "1"},
        }, {"shop:a": [9000] * 9 + [8000]})
        cls.out = cls.root / "dist"
        builder.build(cls.root, cls.out)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_一覧より前に置く(self):
        # 検索が第一の用事。一覧の索引より前に来ること
        page = (self.out / "index.html").read_text(encoding="utf-8")

        self.assertLess(page.index('class="hero"'), page.index('class="views"'))

    def test_トップに商品を並べない(self):
        # 案内だけのページにする（2026-09-26 ユーザー指示）
        page = (self.out / "index.html").read_text(encoding="utf-8")

        self.assertNotIn('class="card"', page)

    def test_他の一覧には出さない(self):
        # どのページにも置くと、一覧の題より前に窓が並ぶ
        self.assertNotIn('class="hero"',
                         (self.out / "lows" / "index.html").read_text(encoding="utf-8"))

    def test_JavaScriptを待たずに飛べる(self):
        # 読み込みが終わる前に打ち始めても取りこぼさないこと。
        # 検索ページは URL の q を読んでそのまま結果を出す
        page = (self.out / "index.html").read_text(encoding="utf-8")
        form = page.split('class="hero"')[1].split("</form>")[0]

        self.assertIn('method="get"', page.split('<form class="hero"')[0][-80:]
                      + page.split('class="hero"')[1][:80])
        self.assertIn('name="q"', form)
        self.assertIn('action="search/"', page)

    def test_件数は下の行と二度出さない(self):
        page = (self.out / "index.html").read_text(encoding="utf-8")
        hero = page.split('class="hero"')[1].split("</form>")[0]

        self.assertNotIn("商品を追跡", hero)


class LandingPageTest(unittest.TestCase):
    """トップは案内だけのページ（2026-09-26 ユーザー指示）。

    以前のトップは一覧そのもので、検索から来た人がいきなり600件の並びと
    採点の説明を読まされていた。一覧は /now/ へ移した。
    """

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name)
        make_data(cls.root, {
            "shop:a": {"name": "商品A", "shop": "店A",
                       "url": "https://hb.afl.rakuten.co.jp/x/1", "image": "",
                       "genre_id": "1"},
        }, {"shop:a": [9000] * 9 + [8000]})
        cls.out = cls.root / "dist"
        builder.build(cls.root, cls.out)
        cls.home = (cls.out / "index.html").read_text(encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_一覧はnowへ移した(self):
        self.assertTrue((self.out / "now" / "index.html").exists())
        self.assertIn("商品A",
                      (self.out / "now" / "index.html").read_text(encoding="utf-8"))

    def test_入口をひととおり置く(self):
        for part in ('class="hero"', 'class="views"', "ジャンルから探す",
                     "何をしているサイトか"):
            with self.subTest(part=part):
                self.assertIn(part, self.home)

    def test_一覧の索引の先頭はnow(self):
        views = self.home.split('class="views"')[1]

        self.assertLess(views.index('href="now/"'), views.index('href="drops/"'))

    def test_ヘッダと同じ文を本文で繰り返さない(self):
        # ヘッダの tagline が config の description を出している。
        # 本文の lead で同じ文をもう一度書かないこと
        lead = re.search(r'<p class="lead">(.*?)</p>', self.home, re.S).group(1)
        tagline = re.search(r'<p class="tagline">(.*?)</p>', self.home, re.S).group(1)

        self.assertEqual(tagline, CONFIG["description"])
        self.assertNotEqual(lead, tagline)

    def test_最安値の範囲をトップでも断る(self):
        # 市場全体の最安値と誤解されないことは、入口でも守る
        self.assertIn("記録を開始してからの期間内での最安値", self.home)

    def test_サイトマップにトップと一覧の両方を入れる(self):
        sitemap = (self.out / "sitemap.xml").read_text(encoding="utf-8")

        self.assertIn("<loc>https://example.test/price/</loc>", sitemap)
        self.assertIn("<loc>https://example.test/price/now/</loc>", sitemap)

    def test_ナビの先頭はnowを指す(self):
        self.assertIn('<a href="now/">いま条件がそろう</a>', self.home)


class FaviconTest(unittest.TestCase):
    """検索結果に出る印。

    data: の URI を <link rel="icon"> に直接書いていた。ブラウザのタブには
    出るが、Google は取りに行けるURLからしか印を拾わない。実際、携帯の
    検索結果では3件とも地球儀の代替アイコンになっていた（2026-09-26）。
    """

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name)
        make_data(cls.root, {
            "shop:a": {"name": "商品A", "shop": "店A", "url": "", "image": "",
                       "genre_id": "1"},
        }, {"shop:a": [1000] * 10})
        cls.out = cls.root / "dist"
        builder.build(cls.root, cls.out)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_印をファイルとして置く(self):
        for name in ("icon.png", "favicon.ico"):
            with self.subTest(name=name):
                self.assertTrue((self.out / name).exists(), name)

    def test_dataURIで指定しない(self):
        # 取りに行けない形だと検索結果には出ない
        page = (self.out / "index.html").read_text(encoding="utf-8")
        tag = re.search(r'<link rel="icon"[^>]*>', page).group(0)

        self.assertNotIn("data:", tag)
        self.assertIn("icon.png", tag)

    def test_深い階層からも辿れる(self):
        # 商品ページは2階層下。相対で書くので prefix が要る
        page = (self.out / "item" / theme.slug("shop:a") / "index.html").read_text(
            encoding="utf-8")

        self.assertIn('href="../../icon.png"', page)

    def test_PNGとして妥当(self):
        import struct
        import zlib

        data = (self.out / "icon.png").read_bytes()

        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        w, h, depth, color = struct.unpack(">IIBB", data[16:26])
        self.assertEqual((w, h), (192, 192))   # 48の倍数の正方形
        self.assertEqual((depth, color), (8, 6))
        off = 8
        while off < len(data):
            ln = struct.unpack(">I", data[off:off + 4])[0]
            kind = data[off + 4:off + 8]
            body = data[off + 8:off + 8 + ln]
            crc = struct.unpack(">I", data[off + 8 + ln:off + 12 + ln])[0]
            with self.subTest(chunk=kind):
                self.assertEqual(zlib.crc32(kind + body) & 0xFFFFFFFF, crc)
            off += 12 + ln

    def test_サイト名を検索側に渡す(self):
        # 検索結果が「kakaku.dailyquarry.com」と生のドメインで出ていた
        page = (self.out / "index.html").read_text(encoding="utf-8")
        block = re.search(r'\{"@context": "https://schema\.org", "@type": "WebSite".*?\}'
                          r'</script>', page, re.S).group(0)[:-9]
        data = json.loads(block.replace("\u003c", "<").replace("\u003e", ">")
                          .replace("\u0026", "&"))

        self.assertEqual(data["name"], CONFIG["name"])
        self.assertEqual(data["url"], "https://example.test/price/")

    def test_WebSiteはトップにだけ置く(self):
        # サイト全体の情報なので、全ページに撒くものではない
        listing = (self.out / "lows" / "index.html").read_text(encoding="utf-8")

        self.assertNotIn('"@type": "WebSite"', listing)


class OfferFieldsTest(unittest.TestCase):
    """Offer に何を書き、何を書かないか。

    Search Console から6項目の推奨（重大ではない）が届いた（2026-09-27）。
    持っていないものを埋めると検索結果に嘘を出すことになるので、
    正直に書けるものだけ入れる。
    """

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name)
        make_data(cls.root, {
            "shop:free": {"name": "送料無料の商品", "shop": "店A", "url": "",
                          "image": "", "genre_id": "1", "free_shipping": True},
            "shop:paid": {"name": "送料別の商品", "shop": "店B", "url": "",
                          "image": "", "genre_id": "1", "free_shipping": False},
        }, {"shop:free": [1000] * 10, "shop:paid": [2000] * 10})
        cls.out = cls.root / "dist"
        builder.build(cls.root, cls.out)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def offer(self, code):
        page = (self.out / "item" / theme.slug(code) / "index.html").read_text(
            encoding="utf-8")
        block = re.search(r'(\{"@context": "https://schema\.org", "@type": "Product".*?\})'
                          r'</script>', page, re.S).group(1)
        return json.loads(block.replace("\u003c", "<").replace("\u003e", ">")
                          .replace("\u0026", "&"))["offers"]

    def test_値段が言える期間を書く(self):
        offer = self.offer("shop:free")

        self.assertEqual(offer["validFrom"], builder.today())
        self.assertGreater(offer["priceValidUntil"], offer["validFrom"])

    def test_送料無料の回だけ送料を書く(self):
        self.assertIn("shippingDetails", self.offer("shop:free"))
        # 有料の回は金額を知らない。推測で埋めない
        self.assertNotIn("shippingDetails", self.offer("shop:paid"))

    def test_送料無料は0円として書く(self):
        rate = self.offer("shop:free")["shippingDetails"]["shippingRate"]

        self.assertEqual(rate["value"], 0)
        self.assertEqual(rate["currency"], "JPY")

    def test_持っていないレビューを書かない(self):
        # 楽天のレビューであって当サイトのものではない。画面にも出していない。
        # 出していないものを構造化データにだけ書くのは、検索側への嘘になる
        offer = self.offer("shop:free")
        page = (self.out / "item" / theme.slug("shop:free") / "index.html").read_text(
            encoding="utf-8")

        self.assertNotIn("aggregateRating", page)
        self.assertNotIn('"review"', page)
        self.assertNotIn("aggregateRating", json.dumps(offer))

    def test_知らない返品条件を書かない(self):
        # 当サイトは販売者ではない
        page = (self.out / "item" / theme.slug("shop:free") / "index.html").read_text(
            encoding="utf-8")

        self.assertNotIn("hasMerchantReturnPolicy", page)

    def test_推測した型番や銘柄を書かない(self):
        # 楽天APIが返さない。名前から推測すると外す
        page = (self.out / "item" / theme.slug("shop:free") / "index.html").read_text(
            encoding="utf-8")

        self.assertNotIn('"gtin', page)
        self.assertNotIn('"brand"', page)


class SharedScriptTest(unittest.TestCase):
    """JavaScript は外に出して使い回す。

    以前は全ページに同じ本文を直書きしていた（商品ページ2.5KB × 12,658枚、
    一覧5.7KB × 約200枚）。ページを移るたび読み直させていて、
    キャッシュも効かなかった。
    """

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name)
        make_data(cls.root, {
            "shop:a": {"name": "商品A", "shop": "店A",
                       "url": "https://hb.afl.rakuten.co.jp/x/1", "image": "",
                       "genre_id": "1"},
        }, {"shop:a": [9000] * 9 + [8000]})
        cls.out = cls.root / "dist"
        builder.build(cls.root, cls.out)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def names(self, pattern):
        return sorted(p.name for p in self.out.glob(pattern))

    def test_指紋付きで書き出す(self):
        for pattern, head in (("app.*.js", "app."), ("list.*.js", "list.")):
            with self.subTest(pattern=pattern):
                got = self.names(pattern)
                self.assertEqual(len(got), 1, got)
                self.assertRegex(got[0], r"^%s[0-9a-f]{8}\.js$" % re.escape(head))

    def test_全ページが共有の本文を指す(self):
        app = self.names("app.*.js")[0]
        for rel in ("index.html", "lows/index.html",
                    f"item/{theme.slug('shop:a')}/index.html"):
            with self.subTest(rel=rel):
                page = (self.out / rel).read_text(encoding="utf-8")
                self.assertIn(app, page)

    def test_見守りの本文をページに直書きしない(self):
        page = (self.out / "item" / theme.slug("shop:a") / "index.html").read_text(
            encoding="utf-8")

        self.assertNotIn("var PTWatch", page)
        self.assertNotIn("PTWatch.toggle", page)

    def test_共有の本文はheadで先に読む(self):
        # 本文側が PTWatch を使うので、後から読ませると壊れる。
        # defer にもしない（読み込み終わりまで待たれると順序が変わる）
        page = (self.out / "index.html").read_text(encoding="utf-8")
        tag = re.search(r'<script src="[^"]*app\.[0-9a-f]{8}\.js"[^>]*>', page).group(0)

        self.assertNotIn("defer", tag)
        self.assertNotIn("async", tag)
        self.assertLess(page.index(tag), page.index("<body"))

    def test_一覧の本文は一覧にだけ読ませる(self):
        lst = self.names("list.*.js")[0]

        self.assertIn(lst, (self.out / "lows" / "index.html").read_text(encoding="utf-8"))
        # 商品ページには並び替えも絞り込みも無い
        self.assertNotIn(lst, (self.out / "item" / theme.slug("shop:a")
                               / "index.html").read_text(encoding="utf-8"))

    def test_深い階層からも辿れる(self):
        app = self.names("app.*.js")[0]
        page = (self.out / "item" / theme.slug("shop:a") / "index.html").read_text(
            encoding="utf-8")

        self.assertIn(f'src="../../{app}"', page)
