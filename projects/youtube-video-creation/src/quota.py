"""APIの枠を自分で数える。

**APIは残量を教えてくれない。**Google Cloud のコンソールを開けば実際の
使用量は見えるが、投稿の途中で毎回開くわけにはいかない。

2026-09-06 に、枠が残っているのに「使い切った」と思い込んで投稿を止めた。
16時50分の時点でリセット済みだと正しく判断していたのに、11本上げたあと
**確かめずに「使い切った」と繰り返していた。**数えていれば起きなかった。

数えるのはこちらが叩いたぶんだけ。手でStudioから上げたぶんは入らないので、
**目安であって正確な残量ではない。**それでも「まだ余っている / もう危ない」
の判断には足りる。
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

# **2026-09-09 に 1,600 へ戻した。**
#
# それまで 270 にしていた。根拠は「2026-09-06 に18本投稿して Queries per day が
# 4,815 だった」という記録だが、**この数字が何を指していたのかを確かめていない。**
# 9/9 に枠を使い切ったとき、公表値の1,600で積むと
#   投稿64回×1600 = 102,400 ＋ その他 8,202 ＝ 110,602
# となり、**落ちた地点とぴったり合う。**270だと 25,482 にしかならず、
# 枠が尽きた説明が付かない。**公表値のほうが実態に合っている。**
COST_PER_UPLOAD = 1600     # videos.insert 1回。公表値であり、9/9 の実測とも合う
COSTS = {
    "videos.insert": COST_PER_UPLOAD,
    "videos.update": 50,
    "videos.list": 1,
    # **単独で叩くと50かかる**（2026-09-09 実測）。公開済み35本のサムネを
    # 貼り替えようとして、10本で quotaExceeded に落ちた。投稿に付いてくるぶんは
    # COST_PER_UPLOAD に入っているので少し重複して数えるが、
    # **足りないと思って止まるより、多めに見て確かめるほうが安い**
    "thumbnails.set": 50,
    "commentThreads.insert": 50,   # 最初のコメント（2026-09-08）。公式の表の値
    "playlistItems.list": 1,       # 掛け直す前の確認（2026-09-09）。読み取りは1
    # **いちばん高い。**参考チャンネルを探すのに8回叩いて800使った（2026-09-09）。
    # 調べもので気軽に使うと、投稿の枠をそこで削ることになる
    "search.list": 100,
}
# 1日に使えるリクエストの合計。
# **この数字は確かめていない。**Google の既定値をそのまま書いただけで、
# 2026-09-09 に実測と 食い違った:
#   この枠の日（太平洋時間 09-08）に動画を64本上げて、題名も59回貼り替えて、
#   それでも通っていた。既定の10,000なら**6本目あたりで止まっているはず**。
#   つまりこのプロジェクトの枠は10,000ではなく、もっと大きい（審査を通すと上がる）。
# 正しい数はGoogle Cloud のコンソール（APIとサービス → YouTube Data API v3 →
# 割り当て）にしか出ない。**ここの数字で「もう出せない」と判断しない。**
# 実際に叩いて quotaExceeded が返るかどうかだけが確かな合図
DAILY = 10000
# **投稿数そのものにも上限がある**（Video Uploads per day）。
# 記録していなかったが、コンソールに出ている。ふつうは Queries が先に尽きる
DAILY_UPLOADS = 100
# **先に尽きるのはこちら**（2026-09-09 実測）。枠を1600×本数で使い切るので、
# 投稿数の100本より前に止まる。64本目の投稿は通り、その直後に落ちた
SAFE_UPLOADS_PER_DAY = 60
# **実際にぶつかった線**（2026-09-09）。110,602 使ったところで quotaExceeded。
# 正確な上限はコンソールにしか無いので、**通った/落ちたの境目**を目安にする
OBSERVED_CEILING = 110000
LEDGER = Path("research/quota.json")
# 枠は太平洋時間の深夜0時に戻る。**夏と冬で1時間ずれる**
#   夏（PDT / UTC-7、3月第2日曜〜11月第1日曜）… 日本時間 16:00
#   冬（PST / UTC-8）                          … 日本時間 17:00
# 2026-09-09 に Gemini にも確認した。それまで UTC-7 を決め打ちしていたので、
# **11月に入ると枠の切り替わる日付を1時間ぶん間違える**ところだった
PACIFIC_SUMMER = timezone(timedelta(hours=-7))
PACIFIC_WINTER = timezone(timedelta(hours=-8))


def _second_sunday_march(year: int) -> datetime:
    at = datetime(year, 3, 8, tzinfo=timezone.utc)
    while at.weekday() != 6:
        at += timedelta(days=1)
    return at


def _first_sunday_november(year: int) -> datetime:
    at = datetime(year, 11, 1, tzinfo=timezone.utc)
    while at.weekday() != 6:
        at += timedelta(days=1)
    return at


def pacific(now: datetime | None = None) -> timezone:
    """そのときの太平洋時間。夏時間なら UTC-7、冬なら UTC-8。"""
    at = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    start = _second_sunday_march(at.year) + timedelta(hours=10)   # 現地 2:00
    end = _first_sunday_november(at.year) + timedelta(hours=9)    # 現地 2:00
    return PACIFIC_SUMMER if start <= at < end else PACIFIC_WINTER


def _today(now: datetime | None = None) -> str:
    """いまが太平洋時間で何日か。**枠はこの日付で切り替わる。**"""
    at = (now or datetime.now(timezone.utc)).astimezone(pacific(now))
    return at.strftime("%Y-%m-%d")


def _load(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def record(call: str, path: Path = LEDGER, now: datetime | None = None) -> int:
    """叩いたぶんを足して、その日の合計を返す。"""
    cost = COSTS.get(call)
    if cost is None:
        raise KeyError(f"費用の分からない呼び出しです: {call}")
    day = _today(now)
    book = _load(path)
    today = dict(book.get(day) or {})
    today[call] = int(today.get(call, 0)) + 1
    book[day] = today
    # 昨日までは残しておく。**いつ何本上げたかを後から見返せる**
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(book, ensure_ascii=False, indent=2), encoding="utf-8")
    return used(path, now)


def used(path: Path = LEDGER, now: datetime | None = None) -> int:
    today = _load(path).get(_today(now)) or {}
    return sum(COSTS.get(name, 0) * int(count) for name, count in today.items())


def left(path: Path = LEDGER, now: datetime | None = None) -> int:
    return max(0, DAILY - used(path, now))


def uploads_today(path: Path = LEDGER, now: datetime | None = None) -> int:
    today = _load(path).get(_today(now)) or {}
    return int(today.get("videos.insert", 0))


def uploads_left(path: Path = LEDGER, now: datetime | None = None) -> int:
    """あと何本上げられるか。**2つの上限のうち、先に尽きるほうで決まる。**"""
    by_cost = left(path, now) // COST_PER_UPLOAD
    by_count = DAILY_UPLOADS - uploads_today(path, now)
    return max(0, min(by_cost, by_count))


def resets_at(now: datetime | None = None) -> datetime:
    """次に枠が戻る時刻（そのまま日本時間で表示できる）。"""
    at = (now or datetime.now(timezone.utc)).astimezone(pacific(now))
    return (at + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)


def report(path: Path = LEDGER, now: datetime | None = None) -> list[str]:
    today = _load(path).get(_today(now)) or {}
    jst = timezone(timedelta(hours=9))
    lines = [f"■ APIの枠　{used(path, now)} 使用（上限は不明。{DAILY} は未確認の目安）"]
    for name, count in sorted(today.items()):
        lines.append(f"  {name:<16} {count:>3}回 × {COSTS.get(name, 0)} = "
                     f"{COSTS.get(name, 0) * count}")
    lines.append(f"  投稿 {uploads_today(path, now)} / {DAILY_UPLOADS} 本")
    # **「あと何本」を鵜呑みにしない**（2026-09-09）。DAILY が実際と桁違いなので、
    # 0 と出ていても出せることがある。確かなのは quotaExceeded が返るかどうかだけ
    lines.append(f"  投稿数から見た残り **{DAILY_UPLOADS - uploads_today(path, now)}本**"
                 "（枠の上限は Cloud コンソールでしか見えない）")
    lines.append(f"  次のリセット: 日本時間 "
                 f"{resets_at(now).astimezone(jst).strftime('%m-%d %H:%M')}")
    if not today:
        lines.append("  ※ 記録がありません。手で上げたぶんは数えられません")
    return lines


# ---------------------------------------------------------------- 数え漏らしを無くす
#
# **2026-09-09 に枠を使い切った。**そのとき台帳と実際が食い違っていた原因は2つ。
#   1. `thumbnails.set` を 0 として数えていた（単独で叩くと50かかる）
#   2. **手で書いた使い捨てのスクリプトが `record()` を通らない。**
#      参考チャンネルを探す `search.list` 9回（900）が丸ごと台帳の外にあった
#
# 呼ぶ側の書き忘れに頼るのをやめて、**サービスを包んで自動で数える。**

class _CountedRequest:
    """1回のリクエスト。**投げた時点で数える**（失敗しても枠は減るため）。"""

    def __init__(self, inner, name: str, path: Path):
        self._inner = inner
        self._name = name
        self._path = path
        self._counted = False

    def __getattr__(self, attr):
        return getattr(self._inner, attr)

    def _mark(self) -> None:
        if not self._counted:
            self._counted = True
            record(self._name, self._path)

    def execute(self, *args, **kwargs):
        self._mark()
        return self._inner.execute(*args, **kwargs)

    def next_chunk(self, *args, **kwargs):
        # 分割送信は何度も呼ばれる。**数えるのは最初の1回だけ**
        self._mark()
        return self._inner.next_chunk(*args, **kwargs)


class _Counted:
    """`service.videos().list(...)` の連なりを追いかけて、呼び名を組み立てる。"""

    def __init__(self, inner, prefix: str = "", path: Path = LEDGER):
        self._inner = inner
        self._prefix = prefix
        self._path = path

    def __getattr__(self, attr):
        got = getattr(self._inner, attr)
        if not callable(got):
            return got

        def wrapped(*args, **kwargs):
            made = got(*args, **kwargs)
            full = f"{self._prefix}.{attr}" if self._prefix else attr
            if hasattr(made, "execute"):
                return _CountedRequest(made, full, self._path)
            if made.__class__.__name__ == "Resource":
                return _Counted(made, full, self._path)
            return made

        return wrapped


def counted(service, path: Path = LEDGER):
    """APIのクライアントを包んで、叩いたぶんを自動で台帳に付ける。"""
    return _Counted(service, "", path)


def is_exhausted(error) -> bool:
    """枠切れ（quotaExceeded）か。**これは待っても直らない。**

    サムネの連投制限（429 / uploadRateLimitExceeded）は待てば解けるが、
    こちらは太平洋時間の深夜0時まで戻らない。取り違えて3分おきに
    叩き続けると、次の日の枠まで削る（2026-09-09）。
    """
    text = str(error)
    return "quotaExceeded" in text or "youtube.quota" in text


def estimate(plan: dict[str, int]) -> int:
    """これから叩くぶんの見積り。`{"videos.insert": 9, "thumbnails.set": 9}`。"""
    return sum(COSTS.get(name, 0) * int(count) for name, count in plan.items())


def preflight(plan: dict[str, int], path: Path = LEDGER,
              now: datetime | None = None) -> list[str]:
    """**まとめて叩く前に見る。**止めはしないが、必ず言葉にして出す。

    2026-09-09 に、公開済み35本のサムネを貼り替えようとして10本目で落ちた。
    **始める前に `quota` を一度も見ていなかった。**数える仕組みは3日前から
    あったのに、使っていない。だから「見に行く」のではなく
    「始めるときに勝手に出る」形にする。
    """
    want = estimate(plan)
    spent = used(path, now)
    lines = [f"■ これから {want:,} 使います（今日ここまで {spent:,}）"]
    for name, count in sorted(plan.items()):
        lines.append(f"    {name:<24} {count:>4}回 × {COSTS.get(name, 0):>5}"
                     f" = {COSTS.get(name, 0) * int(count):>8,}")
    # **実測でぶつかった線**（2026-09-09、110,602 で quotaExceeded）。
    # DAILY は当てにならないので、こちらを目安にする
    if spent + want > OBSERVED_CEILING:
        lines.append(f"  ! 実測でぶつかった線（{OBSERVED_CEILING:,}）を超えます。"
                     "**枠切れになる見込みです。**分けて回すか、日をまたいでください")
    return lines
