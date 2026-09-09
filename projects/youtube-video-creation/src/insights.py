"""視聴維持率と、動画ごとの成績を読む（2026-09-09）。

2026-09-07 に分析用の読み取り権限（yt-analytics.readonly）を足したのに、
**それを使うコードが1行も無かった**。どこで見られなくなっているかを測らずに、
冒頭・テンポ・サムネを直していた。これが無いと改善が当てずっぽうになる。

読むだけ。動画には触らない。数字が返らない日もある（集計に数日かかる）ので、
空のときは黙って0を返さず「まだ出ていない」と言う。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, timedelta

API = "youtubeAnalytics"
VERSION = "v2"


class InsightsError(RuntimeError):
    pass


@dataclass
class VideoRow:
    video_id: str
    views: int = 0
    minutes: float = 0.0
    avg_seconds: float = 0.0
    avg_percent: float = 0.0
    subscribers: int = 0
    likes: int = 0
    title: str = ""

    def line(self) -> str:
        return (f"  {self.views:>5}回  維持{self.avg_percent:>5.1f}%  "
                f"{self.avg_seconds:>4.0f}秒  登録{self.subscribers:+d}  "
                f"♥{self.likes:<3} {self.title[:34]}")


@dataclass
class Curve:
    """視聴維持の曲線。elapsed は 0.0〜1.0、ratio は残っている割合。"""

    video_id: str
    points: list[tuple[float, float]] = field(default_factory=list)

    def at(self, elapsed: float) -> float:
        """その地点で残っている割合。無ければ直前の点。"""
        best = 0.0
        for x, y in self.points:
            if x <= elapsed:
                best = y
        return best

    def biggest_drop(self) -> tuple[float, float]:
        """いちばん落ちた区間の (開始地点, 落ち幅)。**そこを直す。**"""
        worst = (0.0, 0.0)
        for (x1, y1), (_, y2) in zip(self.points, self.points[1:]):
            drop = y1 - y2
            if drop > worst[1]:
                worst = (x1, drop)
        return worst


def service(builder=None):
    """分析API のクライアント。認証は投稿と同じトークンを使い回す。"""
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build as _build

    from .upload import SCOPES, TOKEN_PATH, get_service

    get_service()   # トークンが無ければここで作られる（同意画面が出る）
    creds = Credentials.from_authorized_user_file(str(TOKEN_PATH), SCOPES)
    return (builder or _build)(API, VERSION, credentials=creds)


def per_video(api, days: int = 7, today: date | None = None, limit: int = 25) -> list[VideoRow]:
    """動画ごとの再生・視聴維持・登録・高評価。再生の多い順。"""
    today = today or date.today()
    got = api.reports().query(
        ids="channel==MINE",
        startDate=str(today - timedelta(days=days)),
        endDate=str(today),
        metrics="views,estimatedMinutesWatched,averageViewDuration,"
                "averageViewPercentage,subscribersGained,likes",
        dimensions="video",
        sort="-views",
        maxResults=limit,
    ).execute()
    rows = []
    for row in got.get("rows") or []:
        rows.append(VideoRow(
            video_id=str(row[0]), views=int(row[1]), minutes=float(row[2]),
            avg_seconds=float(row[3]), avg_percent=float(row[4]),
            subscribers=int(row[5]), likes=int(row[6]),
        ))
    return rows


def retention(api, video_id: str, days: int = 30, today: date | None = None) -> Curve:
    """1本の視聴維持の曲線。**どこで捨てられたかを見る。**"""
    today = today or date.today()
    got = api.reports().query(
        ids="channel==MINE",
        startDate=str(today - timedelta(days=days)),
        endDate=str(today),
        metrics="audienceWatchRatio",
        dimensions="elapsedVideoTimeRatio",
        filters=f"video=={video_id}",
        sort="elapsedVideoTimeRatio",
    ).execute()
    points = [(float(r[0]), float(r[1])) for r in (got.get("rows") or [])]
    return Curve(video_id=video_id, points=points)


def bar(ratio: float, width: int = 28) -> str:
    filled = max(0, min(width, round(ratio * width)))
    return "█" * filled + "·" * (width - filled)


def curve_lines(curve: Curve, seconds: float = 0.0, step: float = 0.1) -> list[str]:
    """曲線を10分割で見せる。尺が分かれば秒数も添える。"""
    if not curve.points:
        return ["  （まだ数字が出ていません。集計に数日かかります）"]
    lines = []
    elapsed = 0.0
    while elapsed <= 1.0001:
        ratio = curve.at(elapsed)
        when = f"{elapsed * seconds:>4.0f}秒" if seconds else f"{elapsed * 100:>3.0f}%"
        lines.append(f"  {when}  {bar(ratio)}  {ratio * 100:>5.1f}%")
        elapsed += step
    where, drop = curve.biggest_drop()
    if drop > 0:
        at = f"{where * seconds:.0f}秒" if seconds else f"{where * 100:.0f}%"
        lines.append(f"  → いちばん落ちるのは {at} のあたり（{drop * 100:.1f}ポイント）")
    return lines
