import gzip
import json
import sys
import tempfile
import unittest
import unittest.mock
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from src import analyze, rakuten, store  # noqa: E402


def item(code, price, **kw):
    return {"item_code": code, "price": price, "review_count": kw.get("review_count", 0),
            "review_average": kw.get("review_average", 0.0)}


class ParseTest(unittest.TestCase):
    def payload(self, wrapped: bool):
        raw = {
            "itemCode": "shop:1001", "itemName": "テスト商品", "itemPrice": 12800,
            "shopName": "テスト店", "itemUrl": "https://item.rakuten.co.jp/shop/1001/",
            "affiliateUrl": "https://hb.afl.rakuten.co.jp/x/abc",
            "mediumImageUrls": [{"imageUrl": "https://thumb.example/1.jpg?_ex=128x128"}],
            "reviewCount": "12", "reviewAverage": "4.5", "genreId": "555",
        }
        return {"Items": [{"Item": raw} if wrapped else raw]}

    def test_both_response_shapes_are_accepted(self):
        """API のバージョンで Items の中身の形が変わるため、両方通ること。"""
        for wrapped in (True, False):
            with self.subTest(wrapped=wrapped):
                rows = rakuten.parse_items(self.payload(wrapped))
                self.assertEqual(len(rows), 1)
                self.assertEqual(rows[0]["item_code"], "shop:1001")
                self.assertEqual(rows[0]["price"], 12800)
                self.assertEqual(rows[0]["review_count"], 12)
                self.assertAlmostEqual(rows[0]["review_average"], 4.5)

    def test_affiliate_url_is_preferred(self):
        row = rakuten.parse_items(self.payload(False))[0]
        self.assertTrue(row["url"].startswith("https://hb.afl.rakuten.co.jp/"))
        self.assertTrue(row["is_affiliate"])

    def test_falls_back_to_plain_url_without_affiliate_id(self):
        payload = self.payload(False)
        del payload["Items"][0]["affiliateUrl"]
        row = rakuten.parse_items(payload)[0]
        self.assertTrue(row["url"].startswith("https://item.rakuten.co.jp/"))
        self.assertFalse(row["is_affiliate"])

    def test_image_query_string_is_stripped(self):
        self.assertEqual(rakuten.parse_items(self.payload(False))[0]["image"],
                         "https://thumb.example/1.jpg")

    def test_rows_without_usable_price_are_dropped(self):
        payload = {"Items": [
            {"itemCode": "a:1", "itemPrice": None},
            {"itemCode": "a:2", "itemPrice": "0"},
            {"itemCode": "", "itemPrice": "100"},
            {"itemCode": "a:3", "itemPrice": "980"},
        ]}
        rows = rakuten.parse_items(payload)
        self.assertEqual([r["item_code"] for r in rows], ["a:3"])

    def test_empty_payload(self):
        self.assertEqual(rakuten.parse_items({}), [])


class ThrottleTest(unittest.TestCase):
    def test_waits_at_least_the_interval_between_requests(self):
        """楽天の制限は1秒1回。超えると一定時間締め出される。"""
        now, slept = [0.0], []

        def sleep(sec):
            slept.append(sec)
            now[0] += sec

        t = rakuten.Throttle(interval=1.1, sleep=sleep, clock=lambda: now[0])
        t.wait()            # 1回目は待たない
        now[0] += 0.2       # 0.2秒しか経っていない
        t.wait()
        self.assertEqual(len(slept), 1)
        self.assertAlmostEqual(slept[0], 0.9)

    def test_does_not_wait_when_enough_time_passed(self):
        now, slept = [0.0], []
        t = rakuten.Throttle(interval=1.1, sleep=slept.append, clock=lambda: now[0])
        t.wait()
        now[0] += 5.0
        t.wait()
        self.assertEqual(slept, [])


class StoreTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def test_snapshot_round_trip(self):
        store.write_snapshot(self.dir, "2026-08-29", [item("a:1", 1000), item("a:2", 2000)])
        rows = store.read_snapshot(self.dir, "2026-08-29")
        self.assertEqual({r["item_code"]: r["price"] for r in rows}, {"a:1": 1000, "a:2": 2000})

    def test_snapshot_is_compressed(self):
        store.write_snapshot(self.dir, "2026-08-29", [item("a:1", 1000)])
        path = store.snapshot_path(self.dir, "2026-08-29")
        self.assertEqual(path.read_bytes()[:2], b"\x1f\x8b")
        with gzip.open(path, "rt", encoding="utf-8") as fh:
            self.assertIn("a:1", fh.read())

    def test_rerunning_the_same_day_does_not_duplicate_rows(self):
        store.write_snapshot(self.dir, "2026-08-29", [item("a:1", 1000)])
        store.write_snapshot(self.dir, "2026-08-29", [item("a:1", 900)])
        rows = store.read_snapshot(self.dir, "2026-08-29")
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["price"], 900)

    def test_missing_snapshot_reads_as_empty(self):
        self.assertEqual(store.read_snapshot(self.dir, "1999-01-01"), [])

    def test_corrupt_json_falls_back_to_default(self):
        path = self.dir / "summary.json"
        path.write_text("{not json", encoding="utf-8")
        self.assertEqual(store.load_json(path, {}), {})


class SummaryTest(unittest.TestCase):
    def build(self, series):
        summary = {}
        for day, price in series:
            summary = store.update_summary(summary, [item("a:1", price)], day, tail_days=90)
        return summary["a:1"]

    def test_tracks_min_max_and_previous(self):
        rec = self.build([("2026-08-01", 1000), ("2026-08-02", 1200), ("2026-08-03", 800)])
        self.assertEqual((rec["min"], rec["max"], rec["last"]), (800, 1200, 800))
        self.assertEqual(rec["min_date"], "2026-08-03")
        self.assertEqual(rec["prev"], 1200)
        self.assertEqual(rec["days"], 3)

    def test_running_twice_in_one_day_is_idempotent(self):
        """Actions の再実行や手動実行が重なっても履歴が歪まないこと。"""
        once = self.build([("2026-08-01", 1000), ("2026-08-02", 900)])
        twice = self.build([("2026-08-01", 1000), ("2026-08-02", 900), ("2026-08-02", 900)])
        self.assertEqual(once, twice)

    def test_same_day_correction_recomputes_the_low(self):
        """同じ日を安い値で上書きしたあと元に戻したら、最安値も戻ること。"""
        rec = self.build([("2026-08-01", 1000), ("2026-08-02", 500), ("2026-08-02", 1100)])
        self.assertEqual(rec["min"], 1000)
        self.assertEqual(rec["min_date"], "2026-08-01")
        self.assertEqual(rec["last"], 1100)

    def test_tail_is_capped(self):
        series = [(f"2026-{(i // 28) + 1:02d}-{(i % 28) + 1:02d}", 1000 + i) for i in range(100)]
        rec = self.build(series)
        self.assertEqual(len(rec["tail"]), 90)
        self.assertEqual(rec["days"], 90)


class AnalyzeTest(unittest.TestCase):
    def rec(self, prices, start_day=1):
        summary = {}
        for i, price in enumerate(prices):
            day = f"2026-08-{start_day + i:02d}"
            summary = store.update_summary(summary, [item("a:1", price)], day, tail_days=90)
        return summary["a:1"]

    def test_does_not_claim_a_low_before_enough_history(self):
        """初日は全商品が最安値になってしまうため、名乗らせない。"""
        v = analyze.evaluate(self.rec([1000]), 0.05, 0.02)
        self.assertFalse(v["at_low"])
        self.assertFalse(v["trustworthy"])
        self.assertEqual(v["label"], "記録中")

    def test_claims_a_low_once_history_is_long_enough(self):
        v = analyze.evaluate(self.rec([1000] * 7 + [800]), 0.05, 0.02)
        self.assertTrue(v["at_low"])
        self.assertEqual(v["label"], "記録した中で最安")

    def test_near_low_is_within_the_threshold(self):
        v = analyze.evaluate(self.rec([800] + [1000] * 6 + [810]), 0.05, 0.02)
        self.assertTrue(v["near_low"])
        self.assertFalse(v["at_low"])
        self.assertAlmostEqual(v["vs_low_pct"], 0.0125)

    def test_drop_percentage(self):
        v = analyze.evaluate(self.rec([2000, 1800]), 0.05, 0.02)
        self.assertTrue(v["dropped"])
        self.assertAlmostEqual(v["drop_pct"], 0.1)
        self.assertEqual(v["rise_pct"], 0.0)

    def test_small_drop_is_not_reported(self):
        v = analyze.evaluate(self.rec([2000, 1960]), 0.05, 0.02)
        self.assertFalse(v["dropped"])

    def test_price_rise_is_recorded_separately(self):
        v = analyze.evaluate(self.rec([1000, 1300]), 0.05, 0.02)
        self.assertFalse(v["dropped"])
        self.assertAlmostEqual(v["rise_pct"], 0.3)

    def test_items_missing_from_todays_fetch_are_excluded(self):
        """今日取れなかった商品を出すと、古い価格を今日の価格として見せてしまう。"""
        summary = store.update_summary({}, [item("a:1", 1000), item("a:2", 500)],
                                       "2026-08-01", tail_days=90)
        rows = analyze.evaluate_all(summary, {"a:1": {"name": "残った商品"}}, 0.05, 0.02)
        self.assertEqual([r["item_code"] for r in rows], ["a:1"])

    def test_drops_are_sorted_by_size(self):
        rows = [
            {"dropped": True, "drop_pct": 0.10, "price": 100},
            {"dropped": True, "drop_pct": 0.30, "price": 200},
            {"dropped": False, "drop_pct": 0.0, "price": 300},
        ]
        self.assertEqual([r["drop_pct"] for r in analyze.drops(rows)], [0.30, 0.10])


if __name__ == "__main__":
    unittest.main(verbosity=2)


class RevenueTest(unittest.TestCase):
    """楽天の報酬規則そのものを固定する。ここを間違えると狙う価格帯を誤る。"""

    def test_reward_is_capped_per_item(self):
        from src import revenue
        self.assertEqual(revenue.reward(30000, 0.02), 600)
        self.assertEqual(revenue.reward(50000, 0.02), 1000)
        self.assertEqual(revenue.reward(80000, 0.02), 1000)   # 上限で頭打ち

    def test_effective_rate_falls_above_the_cap(self):
        from src import revenue
        self.assertAlmostEqual(revenue.effective_rate(30000, 0.02), 0.02)
        self.assertAlmostEqual(revenue.effective_rate(100000, 0.02), 0.01)

    def test_cap_price_moves_with_the_rate(self):
        from src import revenue
        self.assertEqual(revenue.cap_price(0.02), 50000)
        self.assertEqual(revenue.cap_price(0.04), 25000)

    def test_break_even_pv(self):
        from src import revenue
        # 3万円の商品・料率2%・注文率0.5% → 1PVあたり3円 → 15,000円には5,000PV
        self.assertEqual(revenue.break_even_pv(15000, 30000, 0.02, 0.005), 5000)

    def test_margin_rises_with_revenue_because_there_is_no_variable_cost(self):
        from src import revenue
        self.assertAlmostEqual(revenue.margin(15000, 15000), 0.0)
        self.assertAlmostEqual(revenue.margin(30000, 15000), 0.5)
        self.assertAlmostEqual(revenue.margin(150000, 15000), 0.9)

    def test_margin_is_negative_below_break_even(self):
        from src import revenue
        self.assertLess(revenue.margin(5000, 15000), 0)


class RequestShapeTest(unittest.TestCase):
    """リクエスト先と認証パラメータを固定する。

    2026-05-13 に旧APIが廃止され、ホスト・バージョン・accessKey の
    どれが欠けても取得できない。これは例外ではなく「0件」として
    静かに現れるので、URLとパラメータをテストで留めておく。
    """

    def setUp(self):
        self.env = unittest.mock.patch.dict(
            "os.environ",
            {"RAKUTEN_APP_ID": "app-uuid", "RAKUTEN_ACCESS_KEY": "pk_test",
             "RAKUTEN_AFFILIATE_ID": "aff-id"})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.seen = []

    def opener(self, payload):
        def _open(req, timeout=None):
            self.seen.append(req.full_url)
            body = json.dumps(payload).encode("utf-8")

            class Res:
                def read(self_inner):
                    return body

                def __enter__(self_inner):
                    return self_inner

                def __exit__(self_inner, *exc):
                    return False
            return Res()
        return _open

    def query(self, url):
        from urllib.parse import parse_qs, urlsplit
        return parse_qs(urlsplit(url).query)

    def test_商品検索は新ホストと新バージョンを叩く(self):
        rakuten.search_genre("100", 1, rakuten.Throttle(interval=0),
                             self.opener({"Items": [], "pageCount": 1}))

        url = self.seen[0]
        self.assertIn("https://openapi.rakuten.co.jp/ichibams/api/", url)
        self.assertIn("/IchibaItem/Search/20260701", url)
        self.assertNotIn("app.rakuten.co.jp", url)

    def test_商品検索はアプリIDとアクセスキーを両方送る(self):
        rakuten.search_genre("100", 1, rakuten.Throttle(interval=0),
                             self.opener({"Items": [], "pageCount": 1}))

        q = self.query(self.seen[0])
        self.assertEqual(q["applicationId"], ["app-uuid"])
        self.assertEqual(q["accessKey"], ["pk_test"])
        self.assertEqual(q["affiliateId"], ["aff-id"])

    def test_ジャンル検索は別ホスト_ichibagt_を叩く(self):
        rakuten.genre_children("0", rakuten.Throttle(interval=0),
                               self.opener({"children": []}))

        url = self.seen[0]
        self.assertIn("https://openapi.rakuten.co.jp/ichibagt/api/", url)
        self.assertIn("/IchibaGenre/Search/20260701", url)
        q = self.query(url)
        self.assertEqual(q["accessKey"], ["pk_test"])

    def test_アクセスキーが無ければ取得前に落ちる(self):
        with unittest.mock.patch.dict("os.environ", {"RAKUTEN_ACCESS_KEY": ""}):
            with self.assertRaises(rakuten.RakutenError) as cm:
                rakuten.credentials()
        self.assertIn("RAKUTEN_ACCESS_KEY", str(cm.exception))


class ErrorDetailTest(unittest.TestCase):
    """403 の理由を握りつぶさない。ただしキーはログに出さない。"""

    def test_redactは認証情報を落として他は残す(self):
        url = ("https://openapi.rakuten.co.jp/ichibagt/api/IchibaGenre/Search/20260701"
               "?applicationId=app-uuid&accessKey=pk_secret&affiliateId=aff&genreId=0")

        out = rakuten.redact(url)

        self.assertNotIn("pk_secret", out)
        self.assertNotIn("app-uuid", out)
        self.assertNotIn("aff", out)
        self.assertIn("genreId=0", out)
        self.assertIn("IchibaGenre/Search/20260701", out)

    def test_HTTPエラーの本文を例外に載せる(self):
        import io
        import urllib.error

        def opener(req, timeout=None):
            raise urllib.error.HTTPError(
                req.full_url, 403, "Forbidden", {},
                io.BytesIO(b'{"error":"wrong_parameter"}'))

        with unittest.mock.patch.dict(
                "os.environ",
                {"RAKUTEN_APP_ID": "app-uuid", "RAKUTEN_ACCESS_KEY": "pk_secret",
                 "RAKUTEN_AFFILIATE_ID": ""}):
            with self.assertRaises(rakuten.RakutenError) as cm:
                rakuten.genre_children("0", rakuten.Throttle(interval=0), opener)

        msg = str(cm.exception)
        self.assertIn("403", msg)
        self.assertIn("wrong_parameter", msg)
        self.assertNotIn("pk_secret", msg)


class NewApiFieldTest(unittest.TestCase):
    """新API(20260701)で変わった項目名と、429 の扱いを固定する。"""

    def setUp(self):
        self.env = unittest.mock.patch.dict(
            "os.environ",
            {"RAKUTEN_APP_ID": "app-uuid", "RAKUTEN_ACCESS_KEY": "pk_test",
             "RAKUTEN_AFFILIATE_ID": ""})
        self.env.start()
        self.addCleanup(self.env.stop)

    def _opener(self, payloads):
        """payloads を順に返す。要素が int ならその HTTP エラーを起こす。"""
        import io
        import urllib.error
        seq = list(payloads)

        def _open(req, timeout=None):
            nxt = seq.pop(0)
            if isinstance(nxt, int):
                raise urllib.error.HTTPError(
                    req.full_url, nxt, "err", {}, io.BytesIO(b'{"message":"Rate limit"}'))
            body = json.dumps(nxt).encode("utf-8")

            class Res:
                def read(self_inner):
                    return body

                def __enter__(self_inner):
                    return self_inner

                def __exit__(self_inner, *exc):
                    return False
            return Res()
        return _open

    def test_ジャンル名はnameJaから読む(self):
        opener = self._opener([{"children": [{"genreId": "101", "nameJa": "パソコン"}]}])

        out = rakuten.genre_children("0", rakuten.Throttle(interval=0), opener)

        self.assertEqual(out, [{"genre_id": "101", "name": "パソコン"}])

    def test_旧名genreNameしか無くても名前を落とさない(self):
        opener = self._opener([{"children": [{"genreId": "101", "genreName": "旧名"}]}])

        out = rakuten.genre_children("0", rakuten.Throttle(interval=0), opener)

        self.assertEqual(out[0]["name"], "旧名")

    def test_429は間隔を広げてやり直す(self):
        slept = []
        throttle = rakuten.Throttle(interval=1.0, sleep=slept.append,
                                    clock=lambda: 0.0)
        opener = self._opener([429, {"children": [{"genreId": "1", "nameJa": "A"}]}])

        out = rakuten.genre_children("0", throttle, opener)

        self.assertEqual(out[0]["name"], "A")
        self.assertGreater(throttle.interval, 1.0)  # 次回以降は広がっている

    def test_429が続けば理由つきで諦める(self):
        throttle = rakuten.Throttle(interval=0, sleep=lambda _: None, clock=lambda: 0.0)
        opener = self._opener([429] * (rakuten.RATE_LIMIT_RETRIES + 1))

        with self.assertRaises(rakuten.RakutenError) as cm:
            rakuten.genre_children("0", throttle, opener)

        self.assertIn("429", str(cm.exception))
