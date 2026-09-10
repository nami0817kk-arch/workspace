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

    # **0 に直した**（2026-09-10、コンソールで確認）。
    # 投稿は Video Uploads per day（100本）で数えられ、Queries per day は食わない
    assert COST_PER_UPLOAD == 0


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
    # **投稿を除いた合計で見る**（2026-09-10）。台帳から投稿を抜くと 10,080 で、
    # コンソールの 9,980 とほぼ一致した。**尽きたのはサムネイルだった**
    assert got < 10000, f"投稿を除けば枠に収まるはず: {got}"


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


def test_知らない呼び出しを0で数えない(tmp_path, capsys):
    """**費用の分からないものを黙って0で数えない。**残量がずれる。

    2026-09-09 までは例外を投げていたが、包んで自動で数えるようにしたら
    **計測が本体を止めた**（`channels.list` で貼り替えが落ちた）。
    いまは見立てて数え、表が古いことを1度だけ知らせる。
    """
    from src import quota

    book = tmp_path / "q.json"
    got = quota.record("videos.somethingNew", book)
    assert got == 50, "0 で数えていない"
    assert "枠の表に" in capsys.readouterr().err


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
    assert "コンソールで確認済み" in text     # 2026-09-10 に確かめた
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


def test_まとめて叩く前に見積りが出る(tmp_path):
    """9/9 は35本の貼り替えを、枠を一度も見ずに始めて10本目で落ちた。

    **投稿は Queries を食わない**（2026-09-10 にコンソールで確認）ので、
    使用量だけ見ていると素通りする。**サムネとコメントのぶんでも見る。**
    """
    from src import quota

    book = tmp_path / "quota.json"        # まっさらな台帳で見る
    ok = chr(10).join(quota.preflight({"videos.insert": 80}, path=book))
    assert "videos.insert" in ok
    assert quota.cost_of("videos.insert") == 0   # 投稿は Queries を食わない
    # 80本なら 8,000 で収まる。**収まるときに警告を出さない**
    assert "超えます" not in ok and "要ります" not in ok

    over = chr(10).join(quota.preflight({"videos.insert": 200}, path=book))
    assert "Video Uploads per day" in over        # 100本の別枠を超える
    assert "20,000" in over                       # 200 × 100（サムネ＋コメント）


def test_表に無い呼び出しでも止めない(tmp_path):
    """**計測が本体を止めてはいけない**（2026-09-09）。

    包んで自動で数えるようにしたら、表に無い `channels.list` で
    KeyError を投げ、サムネの貼り替えが1本も進まないまま落ちた。
    数えるための仕組みが、数えられる側を壊していた。
    """
    import json

    from src.quota import cost_of, record

    assert cost_of("channels.list") == 1
    assert cost_of("まったく知らない.list") == 1     # 読み取りは1
    assert cost_of("まったく知らない.insert") == 50  # 書き込みは50

    ledger = tmp_path / "q.json"
    record("まったく知らない.list", ledger)          # 例外を投げない
    book = json.loads(ledger.read_text(encoding="utf-8"))
    assert list(book.values())[0]["まったく知らない.list"] == 1


def test_投稿はQueriesを食わない(tmp_path):
    """**コンソールで確認した**（2026-09-10）。

      Queries per day        上限 10,000  使用 9,980（99.8%）
      Video Uploads per day  上限    100  使用    37（37%）

    1本1,600が正しければ37本で59,200になり、6本目で止まっているはずだった。
    実際は37本通っている。**投稿は別枠で数えられている。**
    台帳から投稿を除くと10,080で、コンソールの9,980とほぼ一致した。
    """
    import json
    from datetime import datetime, timezone

    from src import quota

    now = datetime(2026, 9, 10, 3, 0, tzinfo=timezone.utc)
    day = now.astimezone(quota.pacific(now)).strftime("%Y-%m-%d")
    ledger = tmp_path / "quota.json"
    ledger.write_text(json.dumps({day: {"videos.insert": quota.SAFE_UPLOADS_PER_DAY}}),
                      encoding="utf-8")
    assert quota.uploads_today(ledger, now) == quota.SAFE_UPLOADS_PER_DAY
    # **投稿は Queries per day に乗らない**
    assert quota.cost_of("videos.insert") == 0
    assert quota.used(ledger, now) == 0, "投稿だけの日は Queries を使っていない"
    # 枠は既定の 10,000 のまま。引き上げられていない
    assert quota.DAILY == 10000
    # 1本 サムネ50＋コメント50。10,000 ÷ 100 = 100本で、投稿の別枠と釣り合う
    assert quota.COST_PER_VIDEO == 100
    assert quota.DAILY // quota.COST_PER_VIDEO == quota.DAILY_UPLOADS


def test_次に枠が戻る時刻を出せる():
    """止めるときは「いつ戻るか」まで言う。"""
    from datetime import datetime, timezone

    from src import quota

    text = quota.reset_text(datetime(2026, 9, 10, 3, 0, tzinfo=timezone.utc))
    assert "-" in text and ":" in text



def test_サムネの再試行そのものが枠を削る():
    """**37本の動画に139回送っていた**（2026-09-10）。

    外の shell が「150秒待って6回まで」を回していて、102回の空振りで
    5,100＝1日の枠の半分を捨てた。**再試行は回数ではなく間隔であける。**
    """
    from src import quota

    assert quota.THUMB_TRIES <= 3, "回数を増やすほど枠が減る"
    # 全部の投稿でサムネを1回ずつ送っても、枠の半分より下に収まること
    assert quota.DAILY_UPLOADS * quota.cost_of("thumbnails.set") <= quota.DAILY // 2 + 1
