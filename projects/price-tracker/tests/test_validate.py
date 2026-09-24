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
        html = self.render(google_site_verification='a"><script>x</script>')

        self.assertNotIn("<script>", html)


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

    def test_1商品1件で_slugと名前と価格と商品コードを持つ(self):
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
        for slug, name, price, code in idx[:5]:
            self.assertTrue(slug and name and code)
            self.assertIsInstance(price, int)
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
