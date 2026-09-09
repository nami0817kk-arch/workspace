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
            "is_affiliate": True, "review_count": 3}
    base.update(kw)
    return base


def rows(n, **kw):
    return [row(item_code=f"shop:{i}", **kw) for i in range(n)]


class CheckSnapshotTest(unittest.TestCase):

    def test_正常なデータは何も言わない(self):
        errors, warnings = validate.check_snapshot(rows(270), expected=270)

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

    def test_レビューが全件0なら警告だけ出す(self):
        # 価格履歴には影響しないので、止めずに気づけるようにする
        errors, warnings = validate.check_snapshot(
            rows(270, review_count=0), expected=270)

        self.assertEqual(errors, [])
        self.assertTrue(any("レビュー件数が全件0" in w for w in warnings))

    def test_レビューが1件でもあれば警告しない(self):
        data = rows(269, review_count=0) + [row(item_code="x", review_count=1)]
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

    def test_1商品1件で_slugと名前と価格を持つ(self):
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
        for slug, name, price in idx[:5]:
            self.assertTrue(slug and name)
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
