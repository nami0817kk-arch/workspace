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


class 掲載文の掃除Test(unittest.TestCase):
    """楽天の掲載文をそのまま載せると、当サイトが勧めているように映る。

    実測（2026-09-28）で、説明のある12,750件のうち2,028件（15.9%）に
    「ぜひ」「オススメ」「超お買い得です」が入り、1,360件は
    「関連商品＼楽天1位獲得／…1,000円1,000円…」という別商品の羅列だった。
    """

    def setUp(self):
        from src import theme
        self.theme = theme

    def test_別商品の羅列は説明として出さない(self):
        text = "関連商品 ゴルフ クリーナー 1,000円 リストレスト 1,200円 " * 3

        self.assertEqual(self.theme.clean_caption(text), "")

    def test_飾りの入った掲載文は出さない(self):
        self.assertEqual(self.theme.clean_caption("＼楽天1位／ すごい商品 " * 5), "")

    def test_煽りの文だけ落として仕様は残す(self):
        text = ("内容量は300mLです。素材はステンレスで、食洗機に対応しています。"
                "是非ぴったりな一本を見つけてください。"
                "保証は購入から1年間です。お問い合わせは店舗までどうぞ。")

        out = self.theme.clean_caption(text)

        self.assertIn("内容量は300mLです。", out)
        self.assertIn("保証は購入から1年間です。", out)
        self.assertNotIn("是非", out)

    def test_落とした残りが短ければ出さない(self):
        self.assertEqual(self.theme.clean_caption("ぜひどうぞ。オススメです。"), "")


class 名前の途中の宣伝Test(unittest.TestCase):
    """先頭だけ落としていたので、途中に紛れた売り文句が題にも一覧にも出ていた
    （実測2026-09-28で491件・3.7%）。"""

    def setUp(self):
        from src import theme
        self.theme = theme

    def test_途中の順位や煽りを落とす(self):
        cases = [
            ("SDカードリーダー 楽天ランキング1位 大容量対応", "楽天ランキング1位"),
            ("【楽天1位獲得】ケーブル 3m", "楽天1位"),
            ("鍵盤カバー ＜クーポンで3980円＞ 日本製", "クーポンで3980円"),
            ("加湿器 今だけ 静音 4.5L", "今だけ"),
            ("ブランケット 累計20万枚突破 シングル", "累計20万枚突破"),
            ("ホットカーラー 楽天最安値挑戦中 海外兼用", "最安値挑戦"),
        ]
        for name, gone in cases:
            with self.subTest(name=name):
                self.assertNotIn(gone, self.theme.clean_name(name))

    def test_商品を見分ける言葉は残す(self):
        keep = "ゴミ箱 45リットル 送料無料 2個セット 1年保証 新品 公式"

        out = self.theme.clean_name(keep)

        for word in ("送料無料", "2個セット", "1年保証", "新品", "公式"):
            with self.subTest(word=word):
                self.assertIn(word, out)

    def test_削りすぎたら元に戻す(self):
        self.assertEqual(self.theme.clean_name("楽天1位"), "楽天1位")


class 価格の位置の言い方Test(unittest.TestCase):
    def setUp(self):
        from src import theme
        self.theme = theme

    def row(self, prices):
        return {"price": prices[-1],
                "tail": [[f"2026-09-{i + 1:02d}", p, 1] for i, p in enumerate(prices)]}

    def test_いまが記録上いちばん高いときはそう言う(self):
        """「この価格以下だったのは10日（100%）」は、安い日が多いように読める。
        事実は逆で、いまがいちばん高い。実測で1,035件がこの状態だった。"""
        out = self.theme.cheaper_days(self.row([900] * 9 + [1000]))

        self.assertIn("これより安かった日はありません", out)
        self.assertIn("いちばん高い", out)
        self.assertNotIn("100%", out)

    def test_今日だけならそう言う(self):
        out = self.theme.cheaper_days(self.row([1000] * 9 + [900]))

        self.assertIn("今日だけ", out)


class 先頭の飾りTest(unittest.TestCase):
    """記号で始まる名前が87件残っていた（2026-09-28 実測）。

    絵文字・矢印・音符が落とす記号に入っておらず、そこで止まって
    その後ろの宣伝の囲みまで残っていた。さらに、名前の途中の宣伝を
    落とすと記号が先頭に来るのに、頭の掃除がもう一度走っていなかった。
    """

    def setUp(self):
        from src import theme
        self.theme = theme

    def test_絵文字で始まっても後ろの宣伝まで落とす(self):
        out = self.theme.clean_name(
            "✨【限定配布1,000円OFF】ポータブルDVDプレーヤー 17.9型 大画面")

        self.assertTrue(out.startswith("ポータブルDVDプレーヤー"), out)

    def test_矢印や音符も落とす(self):
        for name, head in (("⇒2,999円*送料無料 パネルヒーター 足元", "2,999円"),
                           ("♪抗菌クロス セット販売 ヤマハ ピアニカ", "抗菌クロス"),
                           ("➡ モバイルバッテリー 大容量 軽量", "モバイルバッテリー")):
            with self.subTest(name=name):
                self.assertTrue(self.theme.clean_name(name).startswith(head))

    def test_途中の宣伝を落とした残りの記号も落とす(self):
        """「TIMESALE！1,730円～ …」は TIMESALE を落とすと「！」が先頭に来る。"""
        out = self.theme.clean_name("TIMESALE！1,730円～ ハンディファン 冷却プレート")

        self.assertFalse(out.startswith("！"), out)
        self.assertIn("ハンディファン", out)

    def test_商品情報の囲みは残す(self):
        for name in ("【中古】ニンテンドースイッチ 本体",
                     "【公式】掛け時計 おしゃれ 北欧",
                     "《メーカー保証1年付き》YAMAHA ピアニカ"):
            with self.subTest(name=name):
                self.assertEqual(self.theme.clean_name(name), name)


class 題の重複Test(unittest.TestCase):
    """64文字まで伸ばしても同じになる商品がある。

    同じ商品を複数の店が出しているためで、実測（2026-09-28）では
    重複していた598枚のうち290枚は組の中の店が全部違った。
    """

    def setUp(self):
        from src import theme
        self.theme = theme

    def rows(self, *pairs):
        return [{"item_code": f"s{i}:1", "name": n, "shop": shop}
                for i, (n, shop) in enumerate(pairs)]

    def test_店が違えば店名で分ける(self):
        name = "ワイヤレスイヤホン " * 10
        out = self.theme.page_titles(self.rows((name, "A店"), (name, "B店")))

        self.assertEqual(len(set(out.values())), 2)
        self.assertTrue(any("（A店）" in t for t in out.values()))
        self.assertTrue(any("（B店）" in t for t in out.values()))

    def test_同じ店なら無理に分けない(self):
        """分ける材料が無いのに番号を足しても読み手の役に立たない。"""
        name = "ワイヤレスイヤホン " * 10
        out = self.theme.page_titles(self.rows((name, "A店"), (name, "A店")))

        self.assertEqual(len(set(out.values())), 1)
        self.assertNotIn("（", list(out.values())[0])

    def test_ぶつからない題は短いまま(self):
        out = self.theme.page_titles(self.rows(("まったく違う商品", "A店"),
                                               ("ぜんぜん別の品", "B店")))

        for t in out.values():
            with self.subTest(t=t):
                self.assertNotIn("（A店）", t)
                self.assertNotIn("（B店）", t)


class 期限切れの倍率Test(unittest.TestCase):
    """楽天は期限の過ぎた倍率を返してくることがある。

    実測（2026-09-28・取得日と同じ日のビルド）で93件あり、うち63件は
    倍率が1より大きかった。そのまま出すと「ポイント2倍 / 実質13,710円」と、
    もう受け取れない値引きを見せることになる。
    """

    def summary(self, last_date, rate):
        return {"a:1": {"last": 1000, "min": 900, "max": 1100, "days": 10,
                        "prev": 1000, "last_rate": rate, "prev_rate": rate,
                        "last_date": last_date, "min_date": "2026-09-20",
                        "tail": [[f"2026-09-{d:02d}", 1000, rate] for d in range(19, 29)]}}

    def rows(self, until, last_date="2026-09-28", rate=2):
        return analyze.evaluate_all(
            self.summary(last_date, rate),
            {"a:1": {"name": "見本", "point_until": until}}, 0.05, 0.02)

    def test_期限が取得日より前なら倍率を出さない(self):
        row = self.rows("2026-09-27")[0]

        self.assertEqual(row["point_rate"], 1)
        self.assertIsNone(row["point_until"])
        self.assertTrue(row["point_rate_expired"])
        # 倍率1は「通常ポイント1%」なので価格と同じにはならない。
        # 期限切れの2倍ではなく、1倍で計算されていることを見る。
        self.assertEqual(row["eff_price"], analyze.effective(row["price"], 1))
        self.assertNotEqual(row["eff_price"], analyze.effective(row["price"], 2))

    def test_期限が当日なら残す(self):
        row = self.rows("2026-09-28")[0]

        self.assertEqual(row["point_rate"], 2)
        self.assertEqual(row["point_until"], "2026-09-28")

    def test_期限が先なら残す(self):
        row = self.rows("2026-10-05")[0]

        self.assertEqual(row["point_rate"], 2)

    def test_期限が無ければそのまま(self):
        row = self.rows(None)[0]

        self.assertEqual(row["point_rate"], 2)
        self.assertFalse(row.get("point_rate_expired"))


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

    def test_一度も動いていない商品は最安値を名乗らない(self):
        """ずっと同じ値段なら、その値段が自動的に記録上の最安値になる。

        安くなったわけではないのに札が付くと、読み手は値下がりがあったと
        受け取る。実測（2026-09-28・記録23日）では、「記録した中で最安」の
        札が付いていた3,925件のうち3,701件（94.3%）が1円も動いていなかった。
        """
        v = analyze.evaluate(self.rec([1000] * 10), 0.05, 0.02)

        self.assertTrue(v["trustworthy"])
        self.assertFalse(v["moved"])
        self.assertFalse(v["at_low"])
        self.assertFalse(v["near_low"])
        self.assertEqual(v["label"], "変動なし")

    def test_動いて最安に来た商品は最安値を名乗る(self):
        v = analyze.evaluate(self.rec([1200] * 7 + [1000]), 0.05, 0.02)

        self.assertTrue(v["moved"])
        self.assertTrue(v["at_low"])
        self.assertEqual(v["label"], "記録した中で最安")

    def test_値幅が小さい商品は最安値に近いと言わない(self):
        """値幅がしきい値以下だと、どの日を取っても「最安値に近い」になる。

        実測では「最安値に近い」87件のうち66件がこれで、そのうち50件は
        いまが記録上の最高値だった。
        """
        # 全体の値幅は 1000→1010 の1.0%で、しきい値2%より小さい
        v = analyze.evaluate(self.rec([1000] + [1010] * 7), 0.05, 0.02)

        self.assertTrue(v["moved"])
        self.assertFalse(v["near_low"])
        self.assertFalse(v["at_low"])
        self.assertAlmostEqual(v["spread_pct"], 10 / 1010)

    def test_値幅が十分あれば最安値に近いと言う(self):
        v = analyze.evaluate(self.rec([800] + [1000] * 6 + [810]), 0.05, 0.02)

        self.assertTrue(v["near_low"])
        self.assertGreater(v["spread_pct"], 0.02)

    def test_動いていない商品は最安値への近さで点を取らない(self):
        """自分の値段と自分の最安値を比べているだけなので情報にならない。

        直す前は「いま条件がそろっている商品」600件のうち358件がこれだった。
        """
        flat = analyze.evaluate(self.rec([1000] * 10), 0.05, 0.02)
        moved = analyze.evaluate(self.rec([1200] * 7 + [1000]), 0.05, 0.02)

        parts = dict(analyze.score_breakdown(flat))
        self.assertEqual(parts["最安値への近さ"], 0)
        self.assertEqual(dict(analyze.score_breakdown(moved))["最安値への近さ"], 40)

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


class ByGenreTest(unittest.TestCase):
    """ジャンル別の入口ページ。単品ページで大手と competing するより、
    ジャンル単位で内部リンクを集約するための一覧。"""

    def row(self, code, genre, drop=0.0, vs_low=0.5, off_high=0.0):
        return {"item_code": code, "source_genre": genre, "drop_pct": drop,
                "vs_low_pct": vs_low, "off_high_pct": off_high}

    def test_取得元ジャンルで絞る(self):
        rows = [self.row("a", "100026"), self.row("b", "562637"),
                self.row("c", "100026")]

        out = analyze.by_genre(rows, "100026")

        self.assertEqual([r["item_code"] for r in out], ["a", "c"])

    def test_数値と文字列のジャンルIDを同じものとして扱う(self):
        # config は文字列、取得側が数値で入ることがある
        out = analyze.by_genre([self.row("a", 100026)], "100026")

        self.assertEqual(len(out), 1)

    def test_下げ幅の大きい順に並ぶ(self):
        rows = [self.row("small", "g", drop=0.02), self.row("big", "g", drop=0.30),
                self.row("mid", "g", drop=0.10)]

        out = analyze.by_genre(rows, "g")

        self.assertEqual([r["item_code"] for r in out], ["big", "mid", "small"])

    def test_値下がりが無くても空にならない(self):
        # 値下がり0件の日でもページが成立するよう、最安値の近さで順序が付く
        rows = [self.row("far", "g", vs_low=0.40), self.row("near", "g", vs_low=0.01)]

        out = analyze.by_genre(rows, "g")

        self.assertEqual([r["item_code"] for r in out], ["near", "far"])

    def test_取得元ジャンルが無い商品は出さない(self):
        # source_genre を記録する前に取った商品が混ざっても、誤ったページに出さない
        out = analyze.by_genre([{"item_code": "old", "drop_pct": 0.5,
                                 "vs_low_pct": 0.0, "off_high_pct": 0.0}], "g")

        self.assertEqual(out, [])

    def test_件数を絞れる(self):
        rows = [self.row(str(i), "g") for i in range(10)]

        self.assertEqual(len(analyze.by_genre(rows, "g", limit=3)), 3)


class 記録を始めてからの変化Test(unittest.TestCase):
    """価格.com の価格推移ページは冒頭に「初値 / 現在 / 差額・値下がり率」を置く。
    同じ形を置くが、うちは**実質価格の変化も並べる**。
    価格が1円も動いていないのに実質が19.2%下がる商品が実在する
    （dentendo-10026508-15813ae1・2026-09-28 実測）。
    価格.com の見せ方だけでは、この動きは丸ごと見落とす。
    """

    def setUp(self):
        from src import theme
        self.theme = theme

    def test_価格が動かなくても倍率が動けば実質の行に出る(self):
        row = {"tail": [["2026-09-08", 1408, 1], ["2026-09-28", 1408, 20]]}

        out = self.theme.since_start(row)

        self.assertIn("実質", out)
        self.assertIn("変わらず", out)      # 価格の行
        self.assertIn("−268円", out)        # 実質の行（1,394 → 1,126）

    def test_倍率がずっと1倍なら実質の行は出さない(self):
        # 実質は価格の1%引きを並べるだけになり、読み手に何も足さない
        row = {"tail": [["2026-09-08", 2000, 1], ["2026-09-28", 1800, 1]]}

        out = self.theme.since_start(row)

        self.assertNotIn("実質", out)
        self.assertIn("10.0%", out)

    def test_記録が1日しかないときは出さない(self):
        out = self.theme.since_start({"tail": [["2026-09-28", 1000, 1]]})

        self.assertEqual(out, "")

    def test_発売時の値段だとは書かない(self):
        """うちが持っているのは記録を始めた日の値段。価格.com の「初値」とは違う。"""
        row = {"tail": [["2026-09-08", 2000, 1], ["2026-09-28", 1800, 1]]}

        out = self.theme.since_start(row)

        self.assertNotIn("初値", out)
        self.assertIn("発売時の値段ではありません", out)


class 記録の表の前日差Test(unittest.TestCase):
    """価格.com の「日別の価格変動」に倣った列。
    どの日に動いたかを、金額を読み比べずに追えるようにする。
    """

    def setUp(self):
        from src import theme
        self.theme = theme

    def test_前の日から下がった日は差を出す(self):
        row = {"tail": [["2026-09-26", 2000, 1], ["2026-09-27", 1800, 1],
                        ["2026-09-28", 1800, 1]]}

        out = self.theme.history_table(row)

        self.assertIn("前日差", out)
        self.assertIn("−200", out)

    def test_価格が同じでも倍率が動けば実質の差に出る(self):
        row = {"tail": [["2026-09-27", 1408, 1], ["2026-09-28", 1408, 20]]}

        out = self.theme.history_table(row)

        self.assertIn("−268", out)

    def test_倍率が付いた日は倍率も残す(self):
        """実質価格だけだと、値引きが倍率で来たのか価格で来たのかが読めない。"""
        row = {"tail": [["2026-09-27", 1408, 1], ["2026-09-28", 1408, 20]]}

        out = self.theme.history_table(row)

        self.assertIn("20倍", out)
        self.assertNotIn("1倍", out)   # 通常ポイントは書かない



class 一覧の道具Test(unittest.TestCase):
    """`?free=1` 付きのURLを開くと、一覧の道具が丸ごと死んでいた
    （2026-09-28 に発見）。

    `var freeonly = ...` を使うより後に書いていたため、`var` の巻き上げで
    宣言だけが上がり、値は `undefined` のまま `undefined.checked = true` に
    なって例外が出ていた。チェックを入れると URL に `?free=1` が入るので、
    再読み込みや共有のたびに並び替えも価格帯も効かなくなる。
    """

    def setUp(self):
        from src import theme
        self.theme = theme

    def test_初期値を入れるより前に要素を取り出している(self):
        js = self.theme.LIST_JS

        # 巻き上げで宣言だけが上がるので、値を入れる行より前に取り出す
        for name, use in (("freeonly", "freeonly.checked = true"),
                          ("instock", "instock.checked = true"),
                          ("reset", "reset.addEventListener")):
            with self.subTest(name=name):
                self.assertLess(js.index(f"var {name} = document.getElementById"),
                                js.index(use), f"{name} を取り出す前に使っている")

    def test_絞り込みの印はURLに残る(self):
        js = self.theme.LIST_JS

        self.assertIn("p.set('free', '1')", js)
        self.assertIn("q.get('free')", js)


class 記録を全部残すTest(unittest.TestCase):
    """価格履歴の蓄積がこのPJTの価値なので、古い日を捨てない。
    既定は直近14日で、それより前は畳んでおく（開く印を出す）。
    """

    def setUp(self):
        from src import theme
        self.theme = theme

    def tail(self, n):
        return [[f"2026-09-{i + 1:02d}", 1000 + i, 1] for i in range(n)]

    def test_14日を超えたら古い日も表に残す(self):
        out = self.theme.history_table({"tail": self.tail(20)})

        self.assertIn("09/01", out)          # いちばん古い日
        self.assertIn("記録20日ぶんをすべて見る", out)
        self.assertIn("limited", out)

    def test_14日以下なら畳む印を出さない(self):
        out = self.theme.history_table({"tail": self.tail(10)})

        self.assertNotIn("すべて見る", out)
        self.assertNotIn("limited", out)

    def test_表を2枚出さない(self):
        # 13,406ページあるので、同じ表を2枚書くと配信物がその分ふくらむ
        out = self.theme.history_table({"tail": self.tail(30)})

        self.assertEqual(out.count("<table"), 1)


class 説明と判定が食い違わないTest(unittest.TestCase):
    """点の付け方の説明（`/about/`）と `score_breakdown` の中身を揃える。

    動いていない商品を点から外したときに、説明のほうを直していなかった。
    「最安値との差が0%なら40点」とだけ書いてあると、変動なしの商品が
    0点なのは説明と食い違う。
    """

    def test_動いていない商品が0点であることを説明にも書く(self):
        from src import analyze, pages

        near = dict(analyze.score_breakdown({"moved": False, "vs_low_pct": 0.0}))
        self.assertEqual(near["最安値への近さ"], 0)

        body = pages.about_body({"name": "テスト", "owner": "つるはし社",
                                 "contact_email": "a@example.com",
                                 "base_url": "https://e.dev"})
        self.assertIn("一度も価格が動いていない商品は0点", body)


class ポイント込みの最安Test(unittest.TestCase):
    """楽天の値引きは価格ではなくポイント倍率で動くことが多い。
    価格だけで最安を決めると、いちばん得な日を取り逃す。

    実測（2026-09-28・記録が7日以上ある5,074件）で、価格が記録した中で最安
    なのは224件だが、実質価格で見ると481件あり、269件は価格では最安でなかった。
    """

    def entries(self, last_price, last_rate):
        """7日ぶんの 1,000円（倍率1）のあとに、最後の1日を足す。"""
        days = [[f"2026-09-{i + 1:02d}", 1000, 1] for i in range(7)]
        return days + [["2026-09-08", last_price, last_rate]]

    def rec(self, entries):
        prices = [e[1] for e in entries]
        return {"last": entries[-1][1], "prev": entries[-2][1],
                "min": min(prices), "max": max(prices),
                "days": len(entries), "last_rate": entries[-1][2],
                "prev_rate": entries[-2][2], "min_date": entries[0][0],
                "tail": [list(e) for e in entries]}

    def ev(self, entries):
        return analyze.evaluate(self.rec(entries), 0.05, 0.02)

    def test_価格は最安でなくても実質が最安なら札を出す(self):
        # 価格は 1,000 → 1,100 と上がっているが、倍率20倍で実質は 990 → 880
        out = self.ev(self.entries(1100, 20))

        self.assertFalse(out["at_low"])
        self.assertTrue(out["eff_at_low"])
        self.assertEqual(out["label"], "ポイント込みで最安")

    def test_価格が最安ならそちらの札を優先する(self):
        out = self.ev(self.entries(900, 20))

        self.assertTrue(out["at_low"])
        self.assertEqual(out["label"], "記録した中で最安")

    def test_実質が一度も動いていなければ札を出さない(self):
        # 価格も倍率も動いていない。自分の値段と自分の最安値を比べているだけ
        out = self.ev(self.entries(1000, 1))

        self.assertFalse(out["eff_at_low"])
        self.assertEqual(out["label"], "変動なし")

    def test_記録が足りない商品には札を出さない(self):
        rec = self.rec(self.entries(1100, 20))
        rec["days"] = analyze.MIN_DAYS_FOR_LOW - 1

        out = analyze.evaluate(rec, 0.05, 0.02)

        self.assertFalse(out["eff_at_low"])
        self.assertEqual(out["label"], "記録中")

    def test_最安値圏の一覧に入れる(self):
        row = {"at_low": False, "near_low": False, "eff_at_low": True,
               "vs_low_pct": 0.1, "days": 20}

        self.assertEqual(analyze.lows([row]), [row])

    def test_実質がどれだけ下がったかを添える(self):
        """「最安」と言うだけでは値幅2%の商品と30%の商品が同じ顔になる。
        実測（2026-09-28）で、ポイント込みで最安の467件のうち71件は
        実質の値幅が2%以下だった。"""
        from src import theme
        row = self.ev(self.entries(1100, 20))
        row["eff_at_low"] = True

        out = theme.verdict_note(row)

        self.assertIn("記録8日の実質の最高", out)
        self.assertIn("下がっています", out)

    def test_価格が動いていなくても一文を出す(self):
        """倍率だけが動いた商品は moved が偽。そこで打ち切ると、
        いちばん言うべきことが消えていた。"""
        from src import theme
        row = self.ev(self.entries(1000, 20))

        self.assertFalse(row["moved"])
        self.assertTrue(row["eff_at_low"])
        self.assertIn("ポイント倍率が上がった", theme.verdict_note(row))


class ポイントが減って高くなるTest(unittest.TestCase):
    """倍率が下がる（期限切れを含む）と、価格が同じでも実質は上がる。
    「もう得ではない」は、待っていた人にいちばん要る知らせで、
    価格しか見ない作りでは出せない。

    実測（2026-09-28・しきい値5%）で、価格が上がったのは45件だが実質では
    139件あり、101件は価格では上がっていなかった。
    """

    def rec(self, price, rate, prev, prev_rate):
        days = [[f"2026-09-{i + 1:02d}", prev, prev_rate] for i in range(7)]
        days.append(["2026-09-08", price, rate])
        return {"last": price, "prev": prev, "prev_rate": prev_rate,
                "last_rate": rate, "min": min(price, prev),
                "max": max(price, prev), "days": 8,
                "min_date": "2026-09-01", "tail": days}

    def ev(self, price, rate, prev, prev_rate):
        return analyze.evaluate(self.rec(price, rate, prev, prev_rate), 0.05, 0.02)

    def test_価格が同じでも倍率が下がれば実質は上がる(self):
        # 倍率 20 → 1。価格は 1,000 のまま
        out = self.ev(1000, 1, 1000, 20)

        self.assertEqual(out["rise_pct"], 0.0)
        self.assertGreater(out["eff_rise_pct"], 0.05)

    def test_値上がりの一覧に入れる(self):
        row = self.ev(1000, 1, 1000, 20)
        row["price"] = 1000

        self.assertEqual(analyze.rises([row], 0.05), [row])

    def test_一文で何が起きたかを言う(self):
        from src import theme
        row = self.ev(1000, 1, 1000, 20)

        out = theme.verdict_note(row)

        self.assertIn("ポイント倍率が下がった", out)
        self.assertIn("高くなっています", out)

    def test_価格も上がった回は印を繰り返さない(self):
        """同じ割合がカードの価格の行にも出る。1枚に2回並んでいた。"""
        from src import theme
        row = self.ev(2000, 1, 1000, 1)

        self.assertGreater(row["rise_pct"], 0.05)
        self.assertNotIn("▲", theme.point_note(row))

    def test_倍率が1に戻っても実質の行を出す(self):
        """倍率1で打ち切っていたので、いちばん知らせるべき回に何も出なかった。"""
        from src import theme
        row = self.ev(1000, 1, 1000, 20)

        out = theme.point_note(row)

        self.assertIn("実質", out)
        self.assertIn("▲", out)
        self.assertNotIn("ポイント1倍", out)


class 期限切れの倍率を履歴にも反映するTest(unittest.TestCase):
    """期限が切れた倍率は1として扱うが、`last_rate` しか直していなかった。

    図も「記録を始めてからの変化」も「価格の記録」も tail から作るので、
    画面の中で食い違う。実測（2026-09-28）で、頭は「実質 27,225円 ▲16.5%」
    なのに表の同じ日が 23,375円 になっている商品があった。
    """

    def setUp(self):
        self.summary = {"a": {
            "last": 27500, "prev": 27500, "min": 27500, "max": 27500,
            "days": 8, "last_rate": 15, "prev_rate": 15,
            "last_date": "2026-09-28", "min_date": "2026-09-21",
            "tail": [[f"2026-09-{20 + i:02d}", 27500, 15] for i in range(9)]}}
        self.items = {"a": {"name": "空気清浄機", "price": 27500,
                            "point_until": "2026-09-20", "shop": "店"}}

    def test_履歴の最終日の倍率も1に直す(self):
        rows = analyze.evaluate_all(self.summary, self.items, 0.05, 0.02)

        row = rows[0]
        self.assertEqual(row["point_rate"], 1)
        self.assertEqual(row["tail"][-1][2], 1)
        # 表が使う最終日の実質と、頭が使う eff_price が同じであること
        last = row["tail"][-1]
        self.assertEqual(analyze.effective(last[1], last[2]), row["eff_price"])

    def test_期限が切れていなければ触らない(self):
        self.items["a"]["point_until"] = "2026-10-31"

        row = analyze.evaluate_all(self.summary, self.items, 0.05, 0.02)[0]

        self.assertEqual(row["point_rate"], 15)
        self.assertEqual(row["tail"][-1][2], 15)


class 日付別も実質で見るTest(unittest.TestCase):
    """過ぎた日の一覧と最安値の更新も、価格しか見ていなかった。

    実測（2026-09-28）で、9/26 は価格52件に対し実質69件、
    9/27 は17件に対し27件が下がっていた。
    """

    def row(self, tail, **kw):
        base = {"item_code": "a", "name": "テスト", "price": tail[-1][1],
                "trustworthy": True, "at_low": False, "eff_at_low": False,
                "low_date": tail[0][0], "off_high_pct": 0.0, "tail": tail}
        base.update(kw)
        return base

    def test_価格が同じでも倍率が上がった日は値下がりに入れる(self):
        tail = [["2026-09-01", 1000, 1], ["2026-09-02", 1000, 20]]

        hit = analyze.drops_on([self.row(tail)], "2026-09-02", 0.05)

        self.assertEqual(len(hit), 1)
        self.assertFalse(hit[0]["dropped"])        # 価格は下がっていない
        self.assertGreater(hit[0]["eff_drop_pct"], 0.05)

    def test_価格が下がった日はこれまでどおり(self):
        tail = [["2026-09-01", 1000, 1], ["2026-09-02", 800, 1]]

        hit = analyze.drops_on([self.row(tail)], "2026-09-02", 0.05)

        self.assertTrue(hit[0]["dropped"])
        self.assertAlmostEqual(hit[0]["drop_pct"], 0.2)

    def test_実質で最安を塗り替えた日も更新に入れる(self):
        tail = [["2026-09-01", 1000, 1], ["2026-09-02", 1000, 20]]
        row = self.row(tail, eff_at_low=True)

        self.assertEqual(analyze.new_lows([row], "2026-09-02"), [row])
        self.assertEqual(analyze.new_lows([row], "2026-09-01"), [])


class 日付別の題Test(unittest.TestCase):
    """中身は「価格が下がったもの」と「ポイント倍率が上がって実質が下がったもの」の
    両方なのに、題が「値下がり」のままだった（一覧の題は中身に合わせる）。
    """

    def test_題に値下がりと限定しない(self):
        from src import theme
        html = theme.archive_index([("2026-09-26", 69)],
                                   {"name": "テスト", "base_url": "https://e.dev"},
                                   "https://e.dev/archive/", "2026-09-28")

        self.assertIn("日付別 安くなった商品", html)
        self.assertNotIn("日付別の値下がり", html)
        self.assertIn("実質価格が下がったもの", html)


class ジャンルらしい語Test(unittest.TestCase):
    """価格.com のトップはカテゴリの下にサブ項目を2行置いていて、それが
    「ここに何があるか」を伝えている。うちは楽天のジャンルを8つしか取って
    おらず下の階層を持たないので、商品名から出す。
    """

    def setUp(self):
        from src import relate
        self.relate = relate

    def test_そのジャンルに偏った語を選ぶ(self):
        # 「セット」はどのジャンルにもあるので手がかりにならない
        got = self.relate.genre_terms({
            "a": ["イヤホン セット"] * 100,
            "b": ["ドッグフード セット"] * 100,
            "c": ["ギター セット"] * 100}, limit=1)

        self.assertEqual(got["a"], ["イヤホン"])
        self.assertEqual(got["b"], ["ドッグフード"])
        self.assertEqual(got["c"], ["ギター"])

    def test_同じものの別表記を並べない(self):
        """「ヤマハ」と「yamaha」は同じ商品名に両方書かれている。
        読みの対応は辞書なしでは付けられないが、共起なら数えられる。"""
        got = self.relate.genre_terms({
            "a": ["ヤマハ yamaha 電子ピアノ"] * 60 + ["ギター 初心者"] * 40})

        self.assertEqual(len([w for w in got["a"] if w in ("ヤマハ", "yamaha")]), 1)

    def test_同じ商品群にしか出ない別のものは落とさない(self):
        """文字種の条件が無いと、「ヤマハ」と「電子ピアノ」まで同一視していた。"""
        got = self.relate.genre_terms({
            "a": ["ヤマハ 電子ピアノ"] * 60 + ["ギター 初心者"] * 40})

        self.assertIn("ヤマハ", got["a"])
        self.assertIn("電子ピアノ", got["a"])

    def test_数量の語は選ばない(self):
        got = self.relate.genre_terms({
            "a": ["ビール 350ml 24本 4pk"] * 80 + ["ワイン 750ml"] * 20})

        for word in ("350ml", "24本", "750ml", "4pk"):
            self.assertNotIn(word, got["a"])

    def test_言葉を含む方だけを残す(self):
        got = self.relate.genre_terms({
            "a": ["イヤホン"] * 50 + ["ワイヤレスイヤホン"] * 50,
            "b": ["まったく別の語"] * 100})

        self.assertEqual(len([w for w in got["a"] if "イヤホン" in w]), 1)


class 語の絞り込みTest(unittest.TestCase):
    """価格.com のカテゴリページは「注目スペック」を件数つきで並べていて、
    1,500件の中から1手で奥へ入れる。うちはページ送りしか無かった。

    行き先は相対パスなので、**組み立て済みの文字列で渡さない**。
    ページ送りの2枚目からは階層が1つ深くなり、`../../` を外から渡すと
    404 になる（2026-09-28 に実際に踏んだ）。
    """

    def setUp(self):
        from src import theme
        self.theme = theme
        self.site = {"name": "テスト", "base_url": "https://e.dev"}

    def page(self, prefix, page):
        return self.theme.listing(
            "パソコン・周辺機器の価格記録", "説明", [], self.site,
            "https://e.dev/genre/1/", "2026-09-28", prefix=prefix,
            page=page, pages=3, terms=[("インク", 622), ("bci", 237)])

    def test_1枚目と2枚目で行き先の深さが変わる(self):
        first = self.page("../../", 1)
        second = self.page("../../../", 2)

        self.assertIn('href="../../search/?q=', first)
        self.assertIn('href="../../../search/?q=', second)

    def test_件数を添える(self):
        # 価格.com の「ダイキン(747)」と同じで、押す前に手応えが分かる
        self.assertIn("622", self.page("../../", 1))

    def test_0件の語は出さない(self):
        html = self.theme.listing(
            "題", "説明", [], self.site, "https://e.dev/genre/1/", "2026-09-28",
            prefix="../../", terms=[("インク", 0)])

        self.assertNotIn("chips", html)
