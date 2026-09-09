"""APIの枠の数え方。

**2026-09-06 にコンソールで実測し、それまでの記述が6倍ちがっていた。**
18本投稿して Queries per day は 4,815 / 10,000。1本あたり約270。
記録には「1本1,600、1日6本が上限」と書いてあり、そのせいで枠が半分
残っているのに「使い切った」と判断して投稿を止めていた。
"""


def test_1本あたりの費用は公表値の1600():
    """**270 にしていたのは誤りだった**（2026-09-09 に訂正）。

    根拠は「2026-09-06 に18本投稿して Queries per day が 4,815」という
    記録だったが、**その数字が何を指していたのかを確かめていない。**
    9/9 に枠を使い切ったとき、1,600 で積むと落ちた地点とぴったり合う。
    """
    from src.quota import COST_PER_UPLOAD

    assert COST_PER_UPLOAD == 1600


def test_9月9日に枠が尽きた日の合計を再現できる(tmp_path):
    """**モデルが現実と合っているかを、実際に起きた日で確かめる。**

    投稿64回・サムネ76回・題名54回・コメント14回・検索9回・読み取り102回で
    quotaExceeded になった。合計が 11万前後になること。
    """
    from src import quota

    book = tmp_path / "q.json"
    for name, times in (("videos.insert", 64), ("thumbnails.set", 76),
                        ("videos.update", 54), ("commentThreads.insert", 14),
                        ("search.list", 9), ("videos.list", 92),
                        ("playlistItems.list", 10)):
        for _ in range(times):
            quota.record(name, book)
    got = quota.used(book)
    assert 108000 <= got <= 112000, f"合計 {got}（実際に落ちたのは 110,602 付近）"


def test_投稿数の上限でも止まる(tmp_path):
    """**枠が余っていても、投稿数の上限（100本/日）がある。**"""
    from src import quota

    book = tmp_path / "q.json"
    for _ in range(quota.DAILY_UPLOADS):
        quota.record("videos.insert", book)
    assert quota.uploads_left(book) == 0


def test_日付は太平洋時間で切り替わる():
    """**枠が戻るのは太平洋時間の深夜0時＝日本時間16時。**"""
    from datetime import datetime, timedelta, timezone

    from src.quota import _today

    jst = timezone(timedelta(hours=9))
    # 日本時間 9/7 15:59 は、太平洋時間ではまだ 9/6
    assert _today(datetime(2026, 9, 7, 15, 59, tzinfo=jst)) == "2026-09-06"
    # 16:00 を回ると 9/7 に変わる
    assert _today(datetime(2026, 9, 7, 16, 1, tzinfo=jst)) == "2026-09-07"


def test_知らない呼び出しは弾く(tmp_path):
    """**費用の分からないものを黙って0で数えない。**残量がずれる"""
    from src import quota

    try:
        quota.record("videos.somethingNew", tmp_path / "q.json")
    except KeyError as err:
        assert "費用の分からない" in str(err)
    else:
        raise AssertionError("知らない呼び出しを通した")


def test_太平洋時間の夏と冬で枠の戻る時刻が1時間ずれる():
    """**UTC-7 を決め打ちしていた**（2026-09-09 に Gemini にも確認）。

    夏（PDT）は日本時間16時、冬（PST）は17時に枠が戻る。
    決め打ちのままだと11月に入ってから枠の日付を1時間ぶん間違える。
    """
    from datetime import datetime, timedelta, timezone

    from src.quota import PACIFIC_SUMMER, PACIFIC_WINTER, pacific, resets_at

    summer = datetime(2026, 7, 1, 4, tzinfo=timezone.utc)
    winter = datetime(2026, 12, 15, 4, tzinfo=timezone.utc)
    assert pacific(summer) == PACIFIC_SUMMER
    assert pacific(winter) == PACIFIC_WINTER
    # 切り替わりの前後（現地2:00）
    assert pacific(datetime(2026, 3, 8, 9, tzinfo=timezone.utc)) == PACIFIC_WINTER
    assert pacific(datetime(2026, 3, 8, 11, tzinfo=timezone.utc)) == PACIFIC_SUMMER
    assert pacific(datetime(2026, 11, 1, 8, tzinfo=timezone.utc)) == PACIFIC_SUMMER
    assert pacific(datetime(2026, 11, 1, 10, tzinfo=timezone.utc)) == PACIFIC_WINTER

    jst = timezone(timedelta(hours=9))
    assert resets_at(summer).astimezone(jst).hour == 16
    assert resets_at(winter).astimezone(jst).hour == 17


def test_枠の表示は上限を断定しない():
    """DAILY は未確認の目安。**「あと0本」で止まらせない**（2026-09-09）。"""
    from src.quota import report

    text = "\n".join(report())
    assert "未確認" in text
    assert "→ **あと" not in text


class _Req:
    def __init__(self, tag): self.tag = tag; self.runs = 0
    def execute(self): self.runs += 1; return {"ok": self.tag}
    def next_chunk(self): self.runs += 1; return None, {"id": "x"}


class _Resource:            # googleapiclient の Resource のふり
    def __init__(self): self.__class__.__name__ = "Resource"
    def list(self, **kw): return _Req("list")
    def insert(self, **kw): return _Req("insert")
    def set(self, **kw): return _Req("set")


class _Service:
    def videos(self): return _Resource()
    def thumbnails(self): return _Resource()


def test_包んだサービスは叩いたぶんを自動で数える(tmp_path):
    """**呼ぶ側の書き忘れに頼らない**（2026-09-09）。

    使い捨てのスクリプトが record() を通らず、search.list 9回＝900 が
    丸ごと台帳の外にあった。サービスを包んで、叩いた時点で数える。
    """
    import json

    from src.quota import counted

    ledger = tmp_path / "q.json"
    service = counted(_Service(), ledger)
    service.videos().list(id="a").execute()
    service.videos().list(id="b").execute()
    service.thumbnails().set(videoId="a").execute()

    book = json.loads(ledger.read_text(encoding="utf-8"))
    row = list(book.values())[0]
    assert row["videos.list"] == 2
    assert row["thumbnails.set"] == 1


def test_分割送信は何度呼ばれても1回だけ数える(tmp_path):
    """resumable な投稿は next_chunk が繰り返し呼ばれる。"""
    import json

    from src.quota import counted

    ledger = tmp_path / "q.json"
    request = counted(_Service(), ledger).videos().insert(body={})
    request.next_chunk()
    request.next_chunk()
    request.next_chunk()
    book = json.loads(ledger.read_text(encoding="utf-8"))
    assert list(book.values())[0]["videos.insert"] == 1


def test_失敗した投稿も数える(tmp_path):
    """**投げた時点で枠は減る。**9/9 は失敗6回＝9,600を無駄にした。"""
    import json

    from src.quota import counted

    class _Boom(_Resource):
        def insert(self, **kw):
            class R:
                def execute(self): raise RuntimeError("落ちた")
            return R()

    class _S:
        def videos(self): return _Boom()

    ledger = tmp_path / "q.json"
    try:
        counted(_S(), ledger).videos().insert(body={}).execute()
    except RuntimeError:
        pass
    book = json.loads(ledger.read_text(encoding="utf-8"))
    assert list(book.values())[0]["videos.insert"] == 1


def test_枠切れとサムネの連投制限を取り違えない():
    """待てば直るもの（429）と、日をまたぐまで直らないもの（quotaExceeded）。"""
    from src.quota import is_exhausted

    assert is_exhausted("HttpError 403 ... 'reason': 'quotaExceeded'")
    assert is_exhausted("'domain': 'youtube.quota'")
    assert not is_exhausted("HttpError 429 ... uploadRateLimitExceeded")
    assert not is_exhausted("HttpError 403 ... uploadLimitExceeded")


def test_まとめて叩く前に見積りが出る():
    """9/9 は35本の貼り替えを、枠を一度も見ずに始めて10本目で落ちた。"""
    from src.quota import preflight

    lines = "\n".join(preflight({"videos.insert": 80}))
    assert "実測でぶつかった線" in lines        # 超えるので警告が出る
    assert "128,000" in lines                  # 80 × 1600
    assert "超えます" in lines
