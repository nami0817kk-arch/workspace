"""保存前の検査のテスト。

ここで守りたいのは「実際に起きた壊れ方を、次は記録前に止められること」。
各テストは過去に踏んだ事故に対応している。
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from src import validate  # noqa: E402


def row(**kw):
    base = {"item_code": "shop:1", "name": "テレビ", "price": 39800,
            "is_affiliate": True, "review_count": 3, "point_rate": 1}
    base.update(kw)
    return base


def rows(n, **kw):
    return [row(item_code=f"shop:{i}", **kw) for i in range(n)]


class CheckSnapshotTest(unittest.TestCase):

    def test_正常なデータは何も言わない(self):
        data = rows(269) + [row(item_code="x", point_rate=10)]

        errors, warnings = validate.check_snapshot(data, expected=270)

        self.assertEqual(errors, [])
        self.assertEqual(warnings, [])

    def test_0件なら止める(self):
        # 旧APIが廃止されて取得できなくなった状態
        errors, _ = validate.check_snapshot([], expected=270)

        self.assertEqual(len(errors), 1)
        self.assertIn("1件も取得できていません", errors[0])

    def test_件数が期待の8割を切れば止める(self):
        # 3ジャンルのうち1つが落ちた状態
        errors, _ = validate.check_snapshot(rows(180), expected=270)

        self.assertTrue(any("件数が少なすぎます" in e for e in errors))

    def test_8割ちょうどは通す(self):
        # 重複除去で多少減るのは正常。境界で毎日止まると使えない
        errors, _ = validate.check_snapshot(rows(216), expected=270)

        self.assertEqual(errors, [])

    def test_商品名が空ばかりなら止める(self):
        # genreName から nameJa へ項目名が変わったときの壊れ方
        data = rows(200) + rows(70, name="")
        errors, _ = validate.check_snapshot(data, expected=270)

        self.assertTrue(any("商品名が空" in e for e in errors))

    def test_名前の欠けが少数なら通す(self):
        data = rows(265) + rows(5, name="")
        errors, _ = validate.check_snapshot(data, expected=270)

        self.assertEqual(errors, [])

    def test_価格が取れていなければ止める(self):
        data = rows(260) + rows(10, price=0)
        errors, _ = validate.check_snapshot(data, expected=270)

        self.assertTrue(any("価格が取れていない" in e for e in errors))

    def test_価格がNoneでも不正として数える(self):
        data = rows(260) + rows(10, price=None)
        errors, _ = validate.check_snapshot(data, expected=270)

        self.assertTrue(any("価格が取れていない" in e for e in errors))

    def test_アフィリエイトリンクが落ちていたら止める(self):
        # 記録はできるが収益が発生しない。気づかないと最も損が大きい
        data = rows(200) + rows(70, is_affiliate=False)
        errors, _ = validate.check_snapshot(data, expected=270)

        self.assertTrue(any("アフィリエイトリンクでない" in e for e in errors))

    def test_ポイント倍率が全件1倍なら警告する(self):
        # 実測では7.3%が2倍以上だった。全件1倍は項目が返らなくなった合図で、
        # 実質価格の判定が丸ごと死ぬ
        errors, warnings = validate.check_snapshot(rows(270), expected=270)

        self.assertEqual(errors, [])
        self.assertTrue(any("ポイント倍率が全件1倍" in w for w in warnings))

    def test_倍率が1つでも高ければ警告しない(self):
        data = rows(269) + [row(item_code="x", point_rate=10)]

        _, warnings = validate.check_snapshot(data, expected=270)

        self.assertFalse(any("ポイント倍率" in w for w in warnings))

    def test_レビューが全件0なら警告だけ出す(self):
        # 価格履歴には影響しないので、止めずに気づけるようにする
        errors, warnings = validate.check_snapshot(
            rows(270, review_count=0), expected=270)

        self.assertEqual(errors, [])
        self.assertTrue(any("レビュー件数が全件0" in w for w in warnings))

    def test_レビューが1件でもあれば警告しない(self):
        data = (rows(268, review_count=0) + [row(item_code="x", review_count=1)]
                + [row(item_code="y", point_rate=10)])

        _, warnings = validate.check_snapshot(data, expected=270)

        self.assertEqual(warnings, [])

    def test_複数の異常はまとめて報告する(self):
        # 1つ直して再実行、を繰り返さずに済むように
        data = rows(100, name="", is_affiliate=False)
        errors, _ = validate.check_snapshot(data, expected=270)

        self.assertGreaterEqual(len(errors), 3)


class VerificationTagTest(unittest.TestCase):
    """Search Console の所有権確認タグ。

    pages.dev は自分のドメインではないため DNS 方式が使えず、この HTML タグが
    唯一の確認手段になる。入っていないと登録そのものができない。
    """

    def setUp(self):
        from src import theme
        self.theme = theme
        self.site = {"name": "テスト", "base_url": "https://example.pages.dev"}

    def render(self, **kw):
        return self.theme.head("題", "説明", "https://example.pages.dev/",
                               {**self.site, **kw})

    def test_値があれば全ページのheadに入る(self):
        html = self.render(google_site_verification="abc123")

        self.assertIn('<meta name="google-site-verification" content="abc123">', html)

    def test_未設定なら何も出さない(self):
        # 空タグを出すと確認に失敗するので、出さない方が正しい
        self.assertNotIn("google-site-verification", self.render())
        self.assertNotIn("google-site-verification",
                         self.render(google_site_verification="   "))

    def test_値はエスケープする(self):
        # head には見守りの script が常に入るので、タグの有無では検査できない。
        # 検証タグの content から抜け出せないことを見る。
        html = self.render(google_site_verification='a"><script>x</script>')

        self.assertNotIn('"><script>x', html)
        self.assertIn("&quot;&gt;&lt;script&gt;", html)


class CardSparkTest(unittest.TestCase):
    """一覧の小さな価格推移。記録が薄いうちは何も出さない。"""

    def setUp(self):
        from src import theme
        self.theme = theme

    def test_点が2つ未満なら何も出さない(self):
        # 「記録が足りません」を一覧に並べても邪魔になるだけ
        self.assertEqual(self.theme.card_spark({"tail": []}), "")
        self.assertEqual(self.theme.card_spark({"tail": [("2026-09-08", 100)]}), "")

    def test_点が揃えば線を描く(self):
        html = self.theme.card_spark({"tail": [("2026-09-07", 100), ("2026-09-08", 90)]})

        self.assertIn("<svg", html)
        self.assertIn("card-spark", html)


class SearchIndexTest(unittest.TestCase):
    """商品名で探すための索引。5,000件あると一覧を辿るだけでは見つけられない。"""

    def test_1商品1件で_slugと名前と価格と商品コードと判定を持つ(self):
        import json
        import subprocess
        import sys
        import tempfile
        from pathlib import Path

        root = Path(__file__).resolve().parent.parent
        with tempfile.TemporaryDirectory() as tmp:
            subprocess.run([sys.executable, str(root / "build.py"), "--out", tmp],
                           cwd=root, check=True, capture_output=True)
            idx = json.loads((Path(tmp) / "search-index.json").read_text(encoding="utf-8"))
            page = (Path(tmp) / "search" / "index.html").read_text(encoding="utf-8")

        self.assertTrue(idx, "索引が空")
        for slug, name, price, code, mark in idx[:5]:
            self.assertTrue(slug and name and code)
            self.assertIsInstance(price, int)
            self.assertIn(mark, (0, 1, 2, 3))
        self.assertIn('id="q"', page)
        # 索引はページに埋め込まず、必要になってから取りに行く
        self.assertNotIn(idx[0][1], page)


class PointRateTest(unittest.TestCase):
    """ポイント倍率。楽天の値引きは価格ではなくここで動く。"""

    def setUp(self):
        from src import rakuten
        self.rakuten = rakuten

    def payload(self, **kw):
        item = {"itemCode": "shop:1", "itemPrice": 10000, "itemName": "テレビ"}
        item.update(kw)
        return {"Items": [item]}

    def test_倍率を取り込む(self):
        row = self.rakuten.parse_items(self.payload(pointRate=10))[0]

        self.assertEqual(row["point_rate"], 10)

    def test_無ければ通常の1倍として扱う(self):
        self.assertEqual(self.rakuten.parse_items(self.payload())[0]["point_rate"], 1)

    def test_壊れた値は1倍に倒す(self):
        # 判定に使う値なので、変な数字が入ると実質価格が狂う
        for bad in ("", None, "abc", 0, -5, 999):
            row = self.rakuten.parse_items(self.payload(pointRate=bad))[0]
            self.assertEqual(row["point_rate"], 1, f"pointRate={bad!r}")

    def test_日次の記録に列として残る(self):
        import gzip
        import csv
        import tempfile
        from pathlib import Path
        from src import store

        with tempfile.TemporaryDirectory() as tmp:
            store.write_snapshot(Path(tmp), "2026-09-10",
                                 [{"item_code": "a", "price": 100, "point_rate": 10}])
            path = store.snapshot_path(Path(tmp), "2026-09-10")
            rows = list(csv.DictReader(gzip.open(path, "rt", encoding="utf-8")))

        self.assertEqual(rows[0]["point_rate"], "10")


class EffectivePriceTest(unittest.TestCase):
    """ポイント込みの実質価格。楽天の値引きは価格よりここで動く。"""

    def setUp(self):
        from src import analyze
        self.analyze = analyze

    def rec(self, **kw):
        base = {"last": 10000, "prev": 10000, "min": 9000, "max": 11000,
                "days": 10, "min_date": "2026-09-05", "tail": []}
        base.update(kw)
        return base

    def test_倍率のぶんだけ実質価格が下がる(self):
        self.assertEqual(self.analyze.effective(10000, 10), 9000)
        self.assertEqual(self.analyze.effective(10000, 1), 9900)

    def test_倍率が上がれば価格据え置きでも実質は下がる(self):
        # 2026-09-10 に実際に起きた形。価格を見ているだけでは取り逃す
        v = self.analyze.evaluate(self.rec(last_rate=10, prev_rate=1), 0.05, 0.02)

        self.assertGreater(v["eff_drop_pct"], 0.05)
        self.assertEqual(v["point_rate"], 10)

    def test_倍率が未記録の日とは比較しない(self):
        # 記録を始めた翌日に、偽の「実質値下がり」が一斉に出るのを防ぐ
        v = self.analyze.evaluate(self.rec(last_rate=10, prev_rate=None), 0.05, 0.02)

        self.assertEqual(v["eff_drop_pct"], 0.0)
        self.assertIsNone(v["eff_prev"])

    def test_実質で下がったものだけを拾う(self):
        rows = [{"eff_drop_pct": 0.10, "price": 100, "item_code": "a"},
                {"eff_drop_pct": 0.01, "price": 100, "item_code": "b"},
                {"price": 100, "item_code": "c"}]

        out = self.analyze.effective_drops(rows, 0.05)

        self.assertEqual([r["item_code"] for r in out], ["a"])

    def test_古い2要素の履歴も読める(self):
        # 倍率を記録し始めたのは 2026-09-10。それ以前の点は日付と価格しかない
        from src import store
        self.assertEqual(store.entry(["2026-09-08", 500]), ("2026-09-08", 500, 1))
        self.assertEqual(store.entry(["2026-09-11", 500, 10]), ("2026-09-11", 500, 10))


class PagingAndExtrasTest(unittest.TestCase):
    """ページ送りと、付随して出す成果物。

    最安値圏は4,029件ある（2026-09-24 時点）。100件で打ち切っていた頃は、
    記録した資産の97%を捨てていた。
    """

    @classmethod
    def setUpClass(cls):
        import subprocess
        import sys
        import tempfile
        from pathlib import Path

        cls.root = Path(__file__).resolve().parent.parent
        cls.tmp = tempfile.TemporaryDirectory()
        cls.out = Path(cls.tmp.name)
        subprocess.run([sys.executable, str(cls.root / "build.py"), "--out", str(cls.out)],
                       cwd=cls.root, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_100件を超える一覧はページ送りになる(self):
        pages = sorted(p for p in (self.out / "lows").iterdir() if p.is_dir())

        self.assertTrue(pages, "2ページ目以降が作られていない")
        self.assertTrue((self.out / "lows" / "2" / "index.html").exists())

    def test_ページ送りは前後に辿れる(self):
        first = (self.out / "lows" / "index.html").read_text(encoding="utf-8")
        second = (self.out / "lows" / "2" / "index.html").read_text(encoding="utf-8")

        self.assertIn('rel="next"', first)
        self.assertIn('rel="prev"', second)

    def test_一覧に構造化データが入る(self):
        s = (self.out / "index.html").read_text(encoding="utf-8")

        self.assertIn("ItemList", s)

    def test_404と共有画像とフィードを出す(self):
        for name in ("404.html", "og.svg", "feed.xml"):
            self.assertTrue((self.out / name).exists(), name)

    def test_フィードは妥当なXML(self):
        import xml.etree.ElementTree as ET

        root = ET.parse(self.out / "feed.xml").getroot()

        self.assertEqual(root.tag, "rss")

    def test_商品ページの更新日は価格が動いた日(self):
        # 全ページを「今日更新」と申告すると、変わっていないページまで
        # 再クロールさせることになる
        import re
        s = (self.out / "sitemap.xml").read_text(encoding="utf-8")
        mods = set(re.findall(r"<lastmod>(.*?)</lastmod>", s))

        self.assertGreater(len(mods), 1, "全ページが同じ更新日になっている")


class ActiveAndNewLowsTest(unittest.TestCase):
    """ためた履歴からしか作れない一覧。"""

    def setUp(self):
        from src import analyze
        self.analyze = analyze

    def row(self, code, tail, **kw):
        base = {"item_code": code, "tail": tail, "vs_low_pct": 0.1, "price": 1000,
                "at_low": False, "trustworthy": True, "low_date": None,
                "off_high_pct": 0.0}
        base.update(kw)
        return base

    def test_値動きの回数を数える(self):
        tail = [["d1", 100], ["d2", 100], ["d3", 90], ["d4", 90], ["d5", 95]]

        self.assertEqual(self.analyze.change_count({"tail": tail}), 2)

    def test_2回以上動いた商品だけを拾う(self):
        rows = [self.row("still", [["d1", 100], ["d2", 100]]),
                self.row("once", [["d1", 100], ["d2", 90]]),
                self.row("busy", [["d1", 100], ["d2", 90], ["d3", 80]])]

        out = self.analyze.active(rows)

        self.assertEqual([r["item_code"] for r in out], ["busy"])

    def test_その日に最安値を更新したものだけ(self):
        rows = [self.row("today", [], at_low=True, low_date="2026-09-23"),
                self.row("older", [], at_low=True, low_date="2026-09-20"),
                self.row("thin", [], at_low=True, low_date="2026-09-23",
                         trustworthy=False)]

        out = self.analyze.new_lows(rows, "2026-09-23")

        self.assertEqual([r["item_code"] for r in out], ["today"])


class StaleDataTest(unittest.TestCase):
    """取得は成功しているのに中身が前日と同じ、という壊れ方を捕まえる。"""

    def rows(self, n, price=1000, rate=1):
        return [{"item_code": f"c{i}", "price": price, "point_rate": rate}
                for i in range(n)]

    def test_全件が前回と同一なら止める(self):
        prev = {f"c{i}": (1000, 1) for i in range(120)}

        errs = validate.check_against_previous(self.rows(120), prev)

        self.assertTrue(errs)
        self.assertIn("すべてが同一", errs[0])

    def test_1件でも動いていれば通す(self):
        prev = {f"c{i}": (1000, 1) for i in range(120)}
        rows = self.rows(120)
        rows[0]["price"] = 900

        self.assertEqual(validate.check_against_previous(rows, prev), [])

    def test_前回が無ければ何も言わない(self):
        self.assertEqual(validate.check_against_previous(self.rows(120), {}), [])

    def test_重なりが少なければ判定しない(self):
        # 商品が入れ替わっただけの日を誤って止めない
        prev = {f"c{i}": (1000, 1) for i in range(10)}

        self.assertEqual(validate.check_against_previous(self.rows(120), prev), [])


class ArchiveDayTest(unittest.TestCase):
    """過ぎた日の値下がり。

    最初の実装は「最後に価格が動いたのがその日」かつ「今日の値下がり」の積に
    なっており、9/20 は本来37件のところ1件しか出ていなかった。
    """

    def setUp(self):
        from src import analyze
        self.analyze = analyze

    def row(self, code, tail):
        return {"item_code": code, "tail": tail, "price": tail[-1][1],
                "name": code, "vs_low_pct": 0.0}

    def test_その日に下がったものを拾う(self):
        rows = [self.row("a", [["d1", 1000], ["d2", 900], ["d3", 900]])]

        out = self.analyze.drops_on(rows, "d2", 0.05)

        self.assertEqual(len(out), 1)
        self.assertAlmostEqual(out[0]["drop_pct"], 0.1)
        self.assertEqual(out[0]["price"], 900)
        self.assertEqual(out[0]["prev"], 1000)

    def test_その後に動いていても当日の下げを出す(self):
        # 「最後に動いた日」で判定していたときに取りこぼしていた形
        rows = [self.row("a", [["d1", 1000], ["d2", 900], ["d3", 1200]])]

        self.assertEqual(len(self.analyze.drops_on(rows, "d2", 0.05)), 1)

    def test_閾値に満たない下げは出さない(self):
        rows = [self.row("a", [["d1", 1000], ["d2", 990]])]

        self.assertEqual(self.analyze.drops_on(rows, "d2", 0.05), [])

    def test_上がった日は出さない(self):
        rows = [self.row("a", [["d1", 900], ["d2", 1000]])]

        self.assertEqual(self.analyze.drops_on(rows, "d2", 0.05), [])

    def test_記録の初日は前日が無いので出さない(self):
        rows = [self.row("a", [["d1", 1000], ["d2", 900]])]

        self.assertEqual(self.analyze.drops_on(rows, "d1", 0.05), [])


class ToolsTest(unittest.TestCase):
    """使う人ができることを増やした部分。"""

    def setUp(self):
        from src import theme
        self.theme = theme

    def tail(self, *prices):
        return [[f"2026-09-{i + 1:02d}", p] for i, p in enumerate(prices)]

    def test_グラフに最安と最高の目盛りが入る(self):
        html = self.theme.chart(self.tail(1000, 800, 900))

        self.assertIn("chart-svg", html)
        self.assertIn("1,000", html)
        self.assertIn("800", html)

    def test_記録が薄いときはグラフを出さない(self):
        self.assertIn("記録が足りません", self.theme.chart(self.tail(1000)))

    def test_この価格以下だった日数を出す(self):
        row = {"price": 800, "tail": self.tail(1000, 900, 800, 800, 1000, 900, 950)}

        note = self.theme.cheaper_days(row)

        self.assertIn("2日", note)

    def test_記録が7日未満なら日数を出さない(self):
        # 母数が薄いうちに割合を出しても判断材料にならない
        row = {"price": 800, "tail": self.tail(1000, 800)}

        self.assertEqual(self.theme.cheaper_days(row), "")

    def test_カードに並び替え用の値が入る(self):
        row = {"item_code": "a", "name": "テレビ", "price": 1000, "dropped": False,
               "days": 10, "eff_price": 900, "at_low": False, "near_low": False,
               "label": "横ばい", "image": "", "shop": "店"}

        html = self.theme.card(row)

        self.assertIn('data-price="1000"', html)
        self.assertIn('data-eff="900"', html)
        self.assertIn('data-days="10"', html)


class WatchAndFeedTest(unittest.TestCase):
    """見守りとフィード。"""

    def setUp(self):
        from src import theme
        self.theme = theme
        self.site = {"name": "テスト", "base_url": "https://example.pages.dev",
                     "description": "説明"}

    def test_見守るボタンに登録時の価格が入る(self):
        # 価格を控えないと「見始めてから下がったか」が出せない
        row = {"item_code": "a", "name": "テレビ", "price": 1000, "dropped": False,
               "days": 10, "at_low": False, "near_low": False, "label": "横ばい",
               "image": "", "shop": "店", "low": 900, "high": 1100,
               "vs_low_pct": 0.1, "off_high_pct": 0.0, "trustworthy": True,
               "tail": [["2026-09-01", 1000], ["2026-09-02", 1000]]}

        html = self.theme.item_page(row, self.site, "2026-09-24")

        self.assertIn('id="watch"', html)
        self.assertIn('data-price="1000"', html)

    def test_フィードに日付が入る(self):
        rows = [{"item_code": "a", "name": "テレビ", "price": 900, "drop_pct": 0.1,
                 "point_rate": 1}]

        xml = self.theme.feed(self.site, rows, "2026-09-24")

        self.assertIn("<pubDate>", xml)
        self.assertIn("2026", xml)

    def test_日付が壊れていてもフィードは壊さない(self):
        self.assertEqual(self.theme._rfc822("おかしな値"), "")

    def test_アーカイブの前後移動は端で欠ける(self):
        both = self.theme.archive_nav("2026-09-20", "2026-09-19", "2026-09-21")
        newest = self.theme.archive_nav("2026-09-21", "2026-09-20", None)

        self.assertIn("2026-09-19", both)
        self.assertIn("2026-09-21", both)
        self.assertNotIn("2026-09-22", newest)


class ScriptTimingTest(unittest.TestCase):
    """一覧より前に置いた script が、DOM を待たずに要素を探していないか。

    2026-09-24 に、並び替えと見守りが公開サイトで丸ごと動いていなかった。
    script が一覧より前にあり、実行時点で .cards も .watch-mini も存在しな
    かったため。以後は「前に置くなら待つ」を機械的に守らせる。
    """

    @classmethod
    def setUpClass(cls):
        import subprocess
        import sys
        import tempfile
        from pathlib import Path

        root = Path(__file__).resolve().parent.parent
        cls.tmp = tempfile.TemporaryDirectory()
        out = Path(cls.tmp.name)
        subprocess.run([sys.executable, str(root / "build.py"), "--out", str(out)],
                       cwd=root, check=True, capture_output=True)
        cls.html = (out / "lows" / "index.html").read_text(encoding="utf-8")
        cls.robots = (out / "robots.txt").read_text(encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_一覧を探す処理はDOMを待ってから動く(self):
        for target in (".cards", ".watch-mini"):
            i = self.html.index(f"querySelector") if target == ".cards" else 0
            self.assertIn(target, self.html)
        # 一覧より前に script があること自体は許す。待っていることを見る。
        self.assertLess(self.html.index('id="sort"'), self.html.index('<ul class="cards">'))
        self.assertGreaterEqual(self.html.count("DOMContentLoaded"), 2)

    def test_見守りの仕組みは1回だけ定義する(self):
        self.assertEqual(self.html.count("var PTWatch"), 1)

    def test_配布用の大きなファイルはクロールさせない(self):
        for name in ("history.csv", "data.csv", "search-index.json"):
            self.assertIn(f"Disallow: /{name}", self.robots)


class ShortNameTest(unittest.TestCase):
    """一覧に出す商品名。

    楽天の商品名は中央値130文字あり、そのまま並べると1件で画面が埋まる。
    実際に見守り一覧で173文字の名前が出ていた。
    """

    def setUp(self):
        from src import theme
        self.theme = theme

    def test_先頭の補足を落とす(self):
        out = self.theme.short_name("【送料無料】テレビ 42型")

        self.assertEqual(out, "テレビ 42型")

    def test_長い名前は切って記号を付ける(self):
        out = self.theme.short_name("あ" * 80)

        self.assertEqual(len(out), 47)
        self.assertTrue(out.endswith("…"))

    def test_短い名前はそのまま(self):
        self.assertEqual(self.theme.short_name("テレビ"), "テレビ")

    def test_補足だけの名前は元に戻す(self):
        # 【】を外すと空になる場合、切り詰める前の名前を使う
        self.assertEqual(self.theme.short_name("【特価品】"), "【特価品】")

    def test_空でも壊れない(self):
        self.assertEqual(self.theme.short_name(""), "")
        self.assertEqual(self.theme.short_name(None), "")

    def test_一覧には短い名前_全文はtitleに残す(self):
        row = {"item_code": "a", "name": "【割引】" + "あ" * 80, "price": 1000,
               "dropped": False, "days": 10, "at_low": False, "near_low": False,
               "label": "横ばい", "image": "", "shop": "店"}

        html = self.theme.card(row)

        self.assertIn("title=", html)
        self.assertIn("…", html)


class ImageLoadingTest(unittest.TestCase):
    """画面に最初から見えている画像を、自分で遅らせない。"""

    def setUp(self):
        from src import theme
        self.theme = theme

    def row(self, code):
        return {"item_code": code, "name": "【割引】" + "あ" * 90, "price": 1000,
                "dropped": False, "days": 10, "at_low": False, "near_low": False,
                "label": "横ばい", "image": "https://example.com/a.jpg", "shop": "店"}

    def test_先頭は先に読み_あとは遅らせる(self):
        rows = [self.row(f"c{i}") for i in range(6)]

        html = self.theme.listing("題", "説明", rows,
                                  {"name": "T", "base_url": "https://e.dev"},
                                  "https://e.dev/", "2026-09-24")

        self.assertEqual(html.count('loading="eager"'), 3)
        self.assertEqual(html.count('loading="lazy"'), 3)

    def test_altは短い名前にする(self):
        # 173文字の商品名をそのまま読み上げさせない
        html = self.theme.card(self.row("a"))

        import re
        alt = re.search(r'alt="([^"]*)"', html).group(1)
        self.assertLessEqual(len(alt), 41)
        self.assertNotIn("【割引】", alt)


class ItemPageTest(unittest.TestCase):
    """商品ページ。検索結果に出る文字数と、詳細で消えていた情報。"""

    def setUp(self):
        from src import theme
        self.theme = theme
        self.site = {"name": "テスト", "base_url": "https://e.dev"}

    def row(self, **kw):
        base = {"item_code": "a", "name": "あ" * 180, "price": 1000, "low": 900,
                "high": 1100, "days": 19, "vs_low_pct": 0.1, "off_high_pct": 0.0,
                "at_low": False, "near_low": False, "dropped": False,
                "trustworthy": True, "label": "横ばい", "shop": "店",
                "image": "https://e.dev/a.jpg", "low_date": "2026-09-05",
                "tail": [[f"2026-09-{i + 1:02d}", 1000 + i] for i in range(19)]}
        base.update(kw)
        return base

    def html(self, **kw):
        return self.theme.item_page(self.row(**kw), self.site, "2026-09-24")

    def test_タイトルは検索結果に収まる長さ(self):
        # 180文字の商品名をそのまま入れると204文字になり、要点が全部切られる
        import re
        title = re.search(r"<title>(.*?)</title>", self.html()).group(1)

        self.assertLess(len(title), 60)

    def test_説明も長すぎない(self):
        import re
        desc = re.search(r'name="description" content="(.*?)"', self.html()).group(1)

        self.assertLess(len(desc), 130)

    def test_商品画像を出す(self):
        # 一覧にサムネイルがあるのに詳細で消えるのは不親切だった
        self.assertIn('class="hero"', self.html())

    def test_画像が無ければ出さない(self):
        self.assertNotIn('class="hero"', self.html(image=""))

    def test_一度も動いていない商品に割合を出さない(self):
        # 「この価格以下だったのは19日です（100%）」は情報にならない
        flat = self.row(tail=[[f"2026-09-{i + 1:02d}", 1000] for i in range(19)])

        note = self.theme.cheaper_days(flat)

        self.assertIn("変わっていません", note)
        self.assertNotIn("100%", note)

    def test_一覧へ戻れる(self):
        self.assertIn('class="back"', self.html())

    def test_値が動かなくてもグラフが潰れない(self):
        flat = [[f"2026-09-{i + 1:02d}", 1000] for i in range(19)]

        svg = self.theme.chart(flat)

        self.assertIn("<svg", svg)
        self.assertIn("polyline", svg)


class ShippingAndStockTest(unittest.TestCase):
    """送料と在庫。買うかどうかに直結するのに記録していなかった。"""

    def setUp(self):
        from src import rakuten, theme
        self.rakuten = rakuten
        self.theme = theme

    def parse(self, **kw):
        item = {"itemCode": "a", "itemPrice": 1000, "itemName": "X"}
        item.update(kw)
        return self.rakuten.parse_items({"Items": [item]})[0]

    def test_postageFlagの0は送料込み(self):
        self.assertTrue(self.parse(postageFlag=0)["free_shipping"])
        self.assertFalse(self.parse(postageFlag=1)["free_shipping"])

    def test_在庫の有無を読む(self):
        self.assertTrue(self.parse(availability=1)["in_stock"])
        self.assertFalse(self.parse(availability=0)["in_stock"])

    def test_値が無ければ送料別_在庫なしに倒す(self):
        # 分からないものを「送料無料」と表示すると誤解を与える
        row = self.parse()
        self.assertFalse(row["free_shipping"])
        self.assertFalse(row["in_stock"])

    def test_送料無料と在庫切れを表示する(self):
        self.assertIn("送料無料", self.theme.conditions({"free_shipping": True}))
        self.assertIn("在庫切れ", self.theme.conditions({"in_stock": False}))
        self.assertEqual(self.theme.conditions({"in_stock": True}), "")

    def test_下げ幅を円でも出す(self):
        # 高額品は率が小さくても金額は大きい
        row = {"item_code": "a", "name": "テレビ", "price": 90000, "prev": 100000,
               "drop_pct": 0.1, "dropped": True, "days": 10, "at_low": False,
               "near_low": False, "label": "値下がり", "image": "", "shop": "店"}

        html = self.theme.card(row)

        self.assertIn("10,000円", html)

    def test_日次の記録に送料と在庫が残る(self):
        import csv
        import gzip
        import tempfile
        from pathlib import Path
        from src import store

        with tempfile.TemporaryDirectory() as tmp:
            store.write_snapshot(Path(tmp), "2026-09-24",
                                 [{"item_code": "a", "price": 100, "point_rate": 1,
                                   "free_shipping": True, "in_stock": False}])
            rows = list(csv.DictReader(gzip.open(
                store.snapshot_path(Path(tmp), "2026-09-24"), "rt", encoding="utf-8")))

        self.assertEqual(rows[0]["free_shipping"], "1")
        self.assertEqual(rows[0]["in_stock"], "0")


class PointDeadlineTest(unittest.TestCase):
    """ポイント倍率の期限。「10倍がいつまでか」は待つか今かの判断そのもの。"""

    def setUp(self):
        from src import analyze, rakuten, theme
        self.analyze, self.rakuten, self.theme = analyze, rakuten, theme

    def row(self, until, rate=10):
        return {"item_code": until or "x", "point_rate": rate, "point_until": until,
                "price": 1000, "eff_price": 900, "name": "X"}

    def test_期限を取り込む(self):
        r = self.rakuten.parse_items({"Items": [
            {"itemCode": "a", "itemPrice": 1, "itemName": "X",
             "pointRateEndTime": "2026-09-28 11:59"}]})[0]

        self.assertEqual(r["point_until"], "2026-09-28 11:59")

    def test_3日以内に終わるものを終わりが早い順に(self):
        rows = [self.row("2026-09-27 23:59"), self.row("2026-09-25 11:59"),
                self.row("2026-09-30 23:59")]

        out = self.analyze.ending_soon(rows, "2026-09-24")

        self.assertEqual([r["point_until"][:10] for r in out],
                         ["2026-09-25", "2026-09-27"])

    def test_倍率が1倍なら期限があっても出さない(self):
        rows = [self.row("2026-09-25 11:59", rate=1)]

        self.assertEqual(self.analyze.ending_soon(rows, "2026-09-24"), [])

    def test_期限が壊れていても落ちない(self):
        rows = [self.row("おかしな値"), self.row("")]

        self.assertEqual(self.analyze.ending_soon(rows, "2026-09-24"), [])

    def test_期限を画面に出す(self):
        html = self.theme.point_note(self.row("2026-09-28 11:59"))

        self.assertIn("09/28まで", html)

    def test_期限が無ければ出さない(self):
        self.assertNotIn("まで", self.theme.point_note(self.row("")))

    def test_商品説明は出典を添えて出す(self):
        block = self.theme.caption_block({"caption": "説明の冒頭"})

        self.assertIn("説明の冒頭", block)
        self.assertIn("リンク先", block)
        self.assertEqual(self.theme.caption_block({"caption": ""}), "")


class SearchDisplayTest(unittest.TestCase):
    """検索と見守りの表示。

    索引を4要素に詰め直していたため判定が落ち、3,910件が「記録した中で最安」
    なのにバッジが1つも出ていなかった（2026-09-24 に公開サイトで確認）。
    商品名も中央値125文字のままで、一覧だけ詰めて検索を取り残していた。
    """

    @classmethod
    def setUpClass(cls):
        import subprocess
        import sys
        import tempfile
        from pathlib import Path

        root = Path(__file__).resolve().parent.parent
        cls.tmp = tempfile.TemporaryDirectory()
        out = Path(cls.tmp.name)
        subprocess.run([sys.executable, str(root / "build.py"), "--out", str(out)],
                       cwd=root, check=True, capture_output=True)
        cls.search = (out / "search" / "index.html").read_text(encoding="utf-8")
        cls.watch = (out / "watch" / "index.html").read_text(encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_索引の判定を落とさない(self):
        # norm した名前で上書きすると判定が消える
        self.assertIn("r[3], r[4], norm(r[1])", self.search)
        self.assertIn("index[i][5]", self.search)

    def test_検索結果の名前を詰める(self):
        self.assertIn("ptShort(r[1], 46)", self.search)

    def test_見守りの名前も詰める(self):
        self.assertIn("ptShort(h.name, 46)", self.watch)

    def test_短縮処理は1度だけ定義する(self):
        self.assertEqual(self.search.count("function ptShort"), 1)


class SitePagesAuditTest(unittest.TestCase):
    """全ページを実機で操作して見つけた取りこぼし。

    2026-09-24 の点検で3件見つかった。404 が深い階層で崩れること、
    サイトの仕組みの説明がプライバシーポリシーに紛れ込んでいたこと、
    ジャンル索引の件数だけ桁区切りが無かったこと。
    """

    @classmethod
    def setUpClass(cls):
        import subprocess
        import sys
        import tempfile
        from pathlib import Path

        root = Path(__file__).resolve().parent.parent
        cls.tmp = tempfile.TemporaryDirectory()
        cls.out = Path(cls.tmp.name)
        subprocess.run([sys.executable, str(root / "build.py"), "--out", str(cls.out)],
                       cwd=root, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def read(self, *parts):
        from pathlib import Path
        return (self.out.joinpath(*parts)).read_text(encoding="utf-8")

    def test_404はどの深さでも壊れない(self):
        # Cloudflare Pages は存在しないパスすべてにこれを返し、URL は要求のまま
        html = self.read("404.html")

        self.assertIn('href="/style.', html)
        for href in ('"/search/"', '"/lows/"'):
            self.assertIn(href, html)
        self.assertNotIn('href="search/"', html)

    def test_仕組みの説明はサイト紹介に置く(self):
        self.assertIn("実質価格", self.read("about", "index.html"))
        self.assertNotIn("実質価格", self.read("privacy", "index.html"))

    def test_件数は桁区切りで出す(self):
        self.assertIn("商品", self.read("genre", "index.html"))
        self.assertRegex(self.read("genre", "index.html"), r"\d,\d{3}商品")

    def test_ナビのリンクに余分な階層を挟まない(self):
        for path in (("index.html",), ("lows", "index.html"), ("404.html",)):
            self.assertNotIn("/./", self.read(*path), path)


class ConditionScoreTest(unittest.TestCase):
    """条件のそろい具合。推奨ではなく、満たした条件の合計。"""

    def setUp(self):
        from src import analyze
        self.analyze = analyze

    def row(self, **kw):
        base = {"vs_low_pct": 1.0, "eff_drop_pct": 0.0, "drop_pct": 0.0,
                "free_shipping": False, "tail": [], "trustworthy": True,
                "in_stock": True, "item_code": "a"}
        base.update(kw)
        return base

    def test_条件が何も無ければ0点(self):
        self.assertEqual(self.analyze.condition_score(self.row()), 0)

    def test_すべて満たせば100点(self):
        r = self.row(vs_low_pct=0.0, eff_drop_pct=0.2, drop_pct=0.2,
                     free_shipping=True,
                     tail=[["d%d" % i, 100 + i * 10] for i in range(6)])

        self.assertEqual(self.analyze.condition_score(r), 100)

    def test_内訳の合計が点数と一致する(self):
        # 画面に出す内訳と合計がずれると根拠にならない
        r = self.row(vs_low_pct=0.15, eff_drop_pct=0.1, free_shipping=True)

        parts = self.analyze.score_breakdown(r)

        self.assertEqual(sum(p for _, p in parts),
                         self.analyze.condition_score(r))

    def test_各項目に上限がある(self):
        # 1つの条件だけで上位を占めないようにする
        r = self.row(drop_pct=5.0, eff_drop_pct=5.0, vs_low_pct=0.0)

        for name, pt in self.analyze.score_breakdown(r):
            self.assertLessEqual(pt, dict(self.analyze.SCORE_PARTS)[name])

    def test_記録が薄いものと在庫切れは並べない(self):
        rows = [self.row(item_code="ok", vs_low_pct=0.0),
                self.row(item_code="thin", trustworthy=False, vs_low_pct=0.0),
                self.row(item_code="out", in_stock=False, vs_low_pct=0.0)]

        out = self.analyze.well_stocked(rows)

        self.assertEqual([r["item_code"] for r in out], ["ok"])

    def test_点の高い順に並ぶ(self):
        rows = [self.row(item_code="low", vs_low_pct=0.3),
                self.row(item_code="high", vs_low_pct=0.0, free_shipping=True)]

        out = self.analyze.well_stocked(rows)

        self.assertEqual([r["item_code"] for r in out], ["high", "low"])


class CleanNameTest(unittest.TestCase):
    """商品名の頭に積まれた宣伝を落とす。

    落とさないと、検索結果に出る28文字が商品名ではなく宣伝で埋まる。
    実測（12,593件・2026-09-25）で 1,940件が記号か煽りで始まっていて、
    文言が同一のため別商品なのに同じ題になっていたものが 1,531件あった。
    """

    def setUp(self):
        from src import theme
        self.theme = theme

    def test_長い断り書きも落とす(self):
        # 旧実装は【】の中身を30文字までしか見ておらず、これが素通りしていた
        out = self.theme.clean_name(
            "【9/25限定！抽選で最大100%P還元※要エントリー｜楽天カード新規入会】"
            "ロイヤルカナン インドア 4kg")

        self.assertEqual(out, "ロイヤルカナン インドア 4kg")

    def test_煽りの囲みを落とす(self):
        out = self.theme.clean_name("＼★高評価★累計販売数4,000個突破／犬用キーホルダー")

        self.assertEqual(out, "犬用キーホルダー")

    def test_積み重なった宣伝を全部落とす(self):
        out = self.theme.clean_name("【送料無料】＼楽天1位獲得／★P5倍★ SDカードリーダー")

        self.assertEqual(out, "SDカードリーダー")

    def test_期間のうたい文句を落とす(self):
        out = self.theme.clean_name("9/25〜9/27までP5倍 ピアノ用イス 高低自在")

        self.assertEqual(out, "ピアノ用イス 高低自在")

    def test_短い商品名は残す(self):
        # 下限を6文字にしていたとき、この4件を宣伝付きの元の名前へ戻していた
        for name in ("＼送料無料／白メダカ", "【P5倍】ミートピア"):
            with self.subTest(name=name):
                self.assertNotIn("／", self.theme.clean_name(name))

    def test_宣伝しか書かれていない名前を空にしない(self):
        # 空にすると何の商品か分からなくなる。3文字を割ったら元へ戻す
        self.assertEqual(self.theme.clean_name("【送料無料】"), "【送料無料】")
        self.assertIn("特価", self.theme.clean_name("★特価★"))

    def test_商品名の途中は触らない(self):
        # 「送料無料」が名前の中に出てくるのは残す。落としてよいのは先頭だけ
        out = self.theme.clean_name("プリンター インク 5本セット 送料無料 純正")

        self.assertEqual(out, "プリンター インク 5本セット 送料無料 純正")

    def test_囲みの中がブランド名なら残す(self):
        # 中身を見ずに囲みを落とすと、題が型番だけになって何の商品か分からない
        # （実測で33件が元の3割未満まで削れていた）
        out = self.theme.clean_name(
            "【ゆうパケット・送料無料】*【松岡良治】【クラシックギター用弦セット】　MC1000MT")

        self.assertEqual(out, "【松岡良治】【クラシックギター用弦セット】　MC1000MT")

    def test_割引と締切の書き方を落とす(self):
        # トップの先頭に出ていた形
        out = self.theme.clean_name(
            "20%OFF!1点1280円!25(金)23:59迄 nintendo switch カバー")

        self.assertEqual(out, "nintendo switch カバー")

    def test_全品割引クーポンの配布告知を落とす(self):
        out = self.theme.clean_name(
            "全品50％OFFクーポン配布中 09/25(金)23:59まで 羽毛掛け布団 シングル")

        self.assertEqual(out, "羽毛掛け布団 シングル")

    def test_順位の自慢を落とす(self):
        out = self.theme.clean_name("楽天ランキング1位受賞 逆鱗マイバチ")

        self.assertEqual(out, "逆鱗マイバチ")

    def test_空でも壊れない(self):
        self.assertEqual(self.theme.clean_name(""), "")
        self.assertEqual(self.theme.clean_name(None), "")


class PageTitleTest(unittest.TestCase):
    """商品ページの題は重ならないようにする。

    28文字で切ると容量違い・色違いが全部同じ題になり、検索側で区別できない。
    実測で 1,580件が同じ題だった。
    """

    def setUp(self):
        from src import theme
        self.theme = theme

    def test_ぶつかった分だけ後ろへ伸ばす(self):
        rows = [{"item_code": "a", "name": "あ" * 28 + "16GB"},
                {"item_code": "b", "name": "あ" * 28 + "32GB"},
                {"item_code": "c", "name": "まったく別の商品"}]

        out = self.theme.page_titles(rows)

        self.assertNotEqual(out["a"], out["b"])
        self.assertEqual(out["c"], "まったく別の商品")

    def test_ぶつからないものは28文字のまま(self):
        rows = [{"item_code": "a", "name": "あ" * 60},
                {"item_code": "b", "name": "い" * 60}]

        out = self.theme.page_titles(rows)

        self.assertEqual(len(out["a"]), 29)  # 28文字 + …

    def test_名前が完全に同じなら諦める(self):
        # 店だけ違う同一商品。無限に伸ばしても分かれないので止まること
        rows = [{"item_code": "a", "name": "テレビ壁掛け金具"},
                {"item_code": "b", "name": "テレビ壁掛け金具"}]

        out = self.theme.page_titles(rows)

        self.assertEqual(len(out), 2)

    def test_宣伝を落としてから題を決める(self):
        rows = [{"item_code": "a", "name": "【9/25限定】" + "あ" * 30}]

        self.assertFalse(self.theme.page_titles(rows)["a"].startswith("【"))


class PagerReachTest(unittest.TestCase):
    """ページ送りの奥まで届くこと。

    近辺しか出さないと、81ページある一覧の40ページ目へ行くのに20回押す。
    読み手が着けない場所は、クロールも同じ理由で着かない。
    """

    def setUp(self):
        from src import theme
        self.theme = theme

    def test_深い一覧には飛び先を出す(self):
        out = self.theme.pager(1, 81, "lows/", 4023)

        self.assertIn("飛ぶ", out)
        for n in (6, 41, 81):
            with self.subTest(page=n):
                self.assertIn(f'href="lows/{n}/"', out)

    def test_どのページからも3回で着く(self):
        # 飛び先（5刻み）→ 近辺（±2）→ 目的 の3手で全ページに届くこと
        pages = 81
        jumps = {1} | set(range(6, pages + 1, 5))
        for target in range(1, pages + 1):
            with self.subTest(page=target):
                self.assertTrue(any(abs(j - target) <= 2 or j == target
                                    for j in jumps), target)

    def test_浅い一覧には出さない(self):
        self.assertNotIn("飛ぶ", self.theme.pager(1, 5, "drops/", 210))

    def test_1ページだけなら何も出さない(self):
        self.assertEqual(self.theme.pager(1, 1, "drops/", 10), "")


class SellerPraiseTest(unittest.TestCase):
    """売り手の自賛は商品名ではない。

    トップの1件目が「20%OFF!1点1000円!25(金)23:59迄 高評価★4.59 …」で
    始まっていた。何の商品かが見える位置に出てこない。
    """

    def setUp(self):
        from src import theme
        self.theme = theme

    def test_評点と締切を落として商品名から始める(self):
        out = self.theme.clean_name(
            "20%OFF!1点1000円!25(金)23:59迄 高評価★4.59 Nintendo Switch 収納ケース")

        self.assertEqual(out, "Nintendo Switch 収納ケース")

    def test_販売実績の自慢を落とす(self):
        for name, want in (
                ("シリーズ累計160万台突破！ 防湿庫 カメラ", "防湿庫 カメラ"),
                ("累計販売数6万突破！シェーバー メンズ", "シェーバー メンズ"),
                ("大人気！究極のレジスター CLOVER", "究極のレジスター CLOVER")):
            with self.subTest(name=name):
                self.assertEqual(self.theme.clean_name(name), want)


class LayoutTest(unittest.TestCase):
    """画面の作り。実測で見つけた詰まりを、元に戻らないように固定する。"""

    def setUp(self):
        from src import theme
        self.theme = theme
        self.site = {"name": "S", "base_url": "https://e.test",
                     "owner": "o", "contact_email": "c@e.test"}

    def row(self, code="a"):
        return {"item_code": code, "name": "テスト商品 の名前", "price": 1000,
                "low": 900, "high": 1200, "days": 20, "vs_low_pct": 0.1,
                "at_low": False, "near_low": False, "dropped": False,
                "label": "横ばい", "image": "", "shop": "店", "url": "",
                "low_date": "2026-09-20", "tail": []}

    def test_ナビは主要5つを出し残りを畳む(self):
        # 14項目を横に流していたとき、携帯では3項目しか見えていなかった
        html = self.theme.nav_html("")

        head = html.split("<details")[0]
        self.assertEqual(head.count("<a "), 5)
        for _, label in self.theme.NAV_MORE:
            with self.subTest(label=label):
                self.assertIn(label, html)   # 畳んでも消さない

    def test_絞り込みは畳んだ状態で出す(self):
        # 開いたまま置くと、携帯では1件目の商品が730px下にあった
        html = self.theme.listing("題", "説明", [self.row()], self.site,
                                  "https://e.test/", "2026-09-26")

        self.assertIn('<details class="tools-box">', html)
        self.assertNotIn('<details class="tools-box" open', html)

    def test_上のページ送りには飛び先と件数を出さない(self):
        # どちらも下にあれば足りる。上に積むと最初の商品が画面の外へ出る
        top = self.theme.pager(1, 81, "lows/", 4023, jumps=False)
        bottom = self.theme.pager(1, 81, "lows/", 4023)

        self.assertNotIn("飛ぶ", top)
        self.assertNotIn("全4,023件", top)   # 件数は見出しにも出ている
        self.assertIn("飛ぶ", bottom)
        self.assertIn("全4,023件", bottom)

    def test_点の内訳は条件ごとに分ける(self):
        # 1つの span に「・」で繋いでいたため、画面では
        # 「100/100最安値への近さ 40・…」と地続きに見えていた
        row = dict(self.row(), at_low=True, free_shipping=True)
        html = self.theme.score_bar(row)

        self.assertGreaterEqual(html.count('class="part"'), 2)
        self.assertNotIn("・", html)

    def test_商品ページの正式名称は畳む(self):
        # 題から外した宣伝が、本文の先頭に戻ってこないこと
        row = dict(self.row(), name="【送料無料】" + "あ" * 80)
        html = self.theme.item_page(row, self.site, "2026-09-26")

        self.assertIn('<details class="fullname">', html)
        # 見出しに出る文字（title 属性の控えは別物なので中身だけ見る）
        import re as _re
        h1 = _re.search(r"<h1[^>]*>(.*?)</h1>", html, _re.S).group(1)
        self.assertNotIn("【送料無料】", h1)

    def test_ジャンル索引は名前と件数を分ける(self):
        # CSSが当たっておらず「パソコン・周辺機器1,524商品」と繋がっていた
        html = self.theme.genre_index(
            [{"genre_id": "1", "name": "家電", "count": 1538}],
            self.site, "https://e.test/genre/", "2026-09-26")

        self.assertIn('<ul class="genres">', html)
        self.assertIn('<span class="count">1,538商品</span>', html)
