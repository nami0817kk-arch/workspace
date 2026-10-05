"""サムネの型ごとのクリック率（2026-10-05 ユーザーが実施を決めた）。

    python tools/thumbctr.py [--days 28] [--out research/metrics/thumbctr_<日付>.md]
    python tools/thumbctr.py --reach-status        # 表示回数・クリック率が取れる状態かだけ見る
    python tools/thumbctr.py --create-job          # 到達レポートのジョブを作る（ユーザーの OK のあとで1回だけ）
    python tools/thumbctr.py --dry-run --fixture f.json   # API を呼ばずに動かす

動画ごとに「サムネの型」を取材メモ（`research/<名前>.yaml` の `thumbnail`）から決め、
型ごとに本数・表示回数・クリック率を並べる。本編とショート、シリーズとニュースは分けて出す。

**表示回数（サムネのインプレッション）とクリック率は、YouTube Analytics API では取れない。**
2026-10-05 に確かめた：`videoThumbnailImpressions` などは名前としては通るが、
どの組み合わせ（動画別・日別・絞り込み・流入元別）でも「The query is not supported」。
2026-01-15 に増えたのは **YouTube Reporting API**（まとめて落とす方）の到達レポート
`channel_reach_basic_a1`（date, channel_id, video_id, video_thumbnail_impressions,
video_thumbnail_impressions_ctr）だけ。使うには

  1. Google Cloud のプロジェクトで「YouTube Reporting API」を有効にする（無料。いまは無効で 403）
  2. 到達レポートのジョブを1つ作る（`--create-job`。チャンネルに残る設定なのでユーザーの OK を取る）
  3. 約48時間後から、作った日の **30日前からの分**もまとめて落とせる（過去分のファイルは30日で消える）

認証は今のトークン（`yt-analytics.readonly`）でよい。**Data API の枠は使わない。**

それまでの代わりの数字として、Analytics から動画ごとの「公開から3日間の再生回数」と、
そのうち**サムネが出る場所から来た再生**（ブラウジング・検索・関連動画・チャンネルページなど）を出す。
これは「配られた量×クリック率」で、型の良し悪しと配られ方を分けられない。結論は表示回数が取れてから。

計算（型の分け方・日付・まとめ）は API と切り離した関数にしてある（tests/test_thumbctr.py）。
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import statistics
import sys
from dataclasses import asdict, dataclass, field
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

THUMB_ONLY_MARK = ".thumbonly"     # tools/thumbpanel.py が「サムネ専用の絵」に置く印
REACH_REPORT = "channel_reach_basic_a1"
REACH_CACHE = ROOT / "research" / "metrics" / "reach"
# Analytics の1日は太平洋時間で切られる
try:
    from zoneinfo import ZoneInfo
    PACIFIC = ZoneInfo("America/Los_Angeles")
except Exception:   # tzdata が無い環境（夏時間の -7 で代用）
    PACIFIC = timezone(timedelta(hours=-7))

# サムネの型（src/thumbnail.py の 16:9 の組み方と同じ優先順で決める）
T_DATA_BOARD = "データの板（基礎DATA）"
T_BOARD = "数字の板"
T_CREST = "エンブレム主役"
T_VS = "顔2〜3枚＋VSの印"
T_PHOTOS3 = "写真3枚並び"
T_PHOTOS2 = "写真2枚並び"
T_FULL_PANEL = "全面写真＋通算の表"
T_PHOTO = "写真1枚"
T_NONE = "指定なし（台本の背景）"
T_UNKNOWN = "取材メモが無い"
TYPES = (T_PHOTO, T_PHOTOS2, T_PHOTOS3, T_VS, T_CREST, T_DATA_BOARD, T_BOARD,
         T_FULL_PANEL, T_NONE, T_UNKNOWN)

# サムネが出る場所から来た再生（Analytics の insightTrafficSourceType）。
# SUBSCRIBER は「ブラウジング機能」（ホーム・登録チャンネル）。SHORTS はショートのフィードで、
# そこはサムネではなく動画そのものが流れるので入れない。通知・外部リンクも入れない
THUMB_SOURCES = ("SUBSCRIBER", "YT_SEARCH", "RELATED_VIDEO", "YT_CHANNEL",
                 "YT_PLAYLIST_PAGE", "YT_OTHER_PAGE")
FIRST_DAYS = 3          # 公開日を含めて何日ぶんの再生で比べるか
FEW = 5                 # これ未満の本数は「少ない」と書く
BATCH = 50              # 1回の問い合わせに入れる動画の数（200本だと 500 が返った）


# ---------------------------------------------------------------- 型を決める

def is_board(path: str) -> bool:
    """その絵は「板」か（src/render.py の _is_board と同じ見方。印のファイルは exists で見る）。"""
    text = str(path or "").replace("\\", "/")
    return "/assets/stats/" in text or text.startswith("assets/stats/")


def classify_thumbnail(thumb: dict | None, exists=None) -> str:
    """取材メモの `thumbnail` からサムネの型を1つ返す。

    src/thumbnail.py の本編（16:9）の組み方に合わせた優先順：
      板でなくエンブレム主役があればエンブレム → 写真2枚以上なら並び（face_link なら VS）
      → 板（`_data_t` は基礎DATA）→ `.thumbonly` の印がある写真は全面写真＋表 → 写真1枚
    `exists(path)` は写真が手元にあるか（並びは実在する写真だけで組まれる）。
    """
    if thumb is None:
        return T_UNKNOWN
    if not isinstance(thumb, dict):
        return T_NONE
    exists = exists or (lambda p: (ROOT / p).exists())
    board = str(thumb.get("board") or "")
    photo = str(thumb.get("photo") or "")
    background = board or photo
    on_board = is_board(background) or (bool(background) and exists(background + ".statboard.txt"))
    crest_main = [c for c in (thumb.get("crest_main") or []) if c]
    photos = [str(p) for p in (thumb.get("photos") or []) if p and exists(str(p))]
    if not on_board and crest_main:
        return T_CREST
    if len(photos) >= 2:
        if thumb.get("face_link"):
            return T_VS
        return T_PHOTOS3 if len(photos) >= 3 else T_PHOTOS2
    if on_board:
        return T_DATA_BOARD if "_data_t" in Path(background.replace("\\", "/")).stem else T_BOARD
    if photo and exists(photo + THUMB_ONLY_MARK):
        return T_FULL_PANEL
    if photo or photos:
        return T_PHOTO
    return T_NONE


def base_name(build: str) -> str:
    return build[:-len("_short")] if build.endswith("_short") else build


def is_short(build: str) -> bool:
    return build.endswith("_short")


G_SERIES = "シリーズ"
G_JAPAN = "ニュース・日本人枠"
G_OTHER = "ニュース・ほか"
G_UNKNOWN = "不明"
GENRES = (G_SERIES, G_JAPAN, G_OTHER, G_UNKNOWN)


def genre_of(notes: dict | None) -> str:
    """シリーズか、日本人枠のニュースか、ほかのニュースか。

    取材メモの `series:` があればシリーズ。無ければ `slot`（japan_3・japanese_2 など）で
    日本人枠を分ける。**本編の再生上位はほぼ日本人の回**なので、混ぜると型ではなく題材の差を見る
    """
    if notes is None:
        return G_UNKNOWN
    if str(notes.get("series") or "").strip():
        return G_SERIES
    return G_JAPAN if str(notes.get("slot") or "").startswith("jap") else G_OTHER


def pacific_day(when: str) -> date | None:
    """公開日時（UTC の ISO 文字列）を、Analytics の1日（太平洋時間）に直す。"""
    try:
        at = datetime.fromisoformat(str(when).replace("Z", "+00:00"))
    except ValueError:
        return None
    if at.tzinfo is None:
        at = at.replace(tzinfo=timezone.utc)
    return at.astimezone(PACIFIC).date()


# ---------------------------------------------------------------- 対象を選ぶ

@dataclass
class Video:
    video_id: str
    build: str
    short: bool
    published: date
    thumb_type: str = T_UNKNOWN
    genre: str = "不明"
    series: str = ""
    # 公開から FIRST_DAYS 日の再生（Analytics）
    views: int = 0
    thumb_views: int = 0
    sources: dict = field(default_factory=dict)
    # 到達レポート（取れたときだけ）
    impressions: int | None = None
    ctr: float | None = None      # 0〜100 の %


def pick_videos(posted: list[dict], first: date, last: date) -> list[Video]:
    """控えから、公開日（太平洋時間）が first〜last の動画を選ぶ。削除済み・旧名は外す。"""
    out, seen = [], set()
    for row in posted:
        vid = str(row.get("video_id") or "")
        build = str(row.get("build") or "")
        if not vid or vid in seen or row.get("deleted") or build.startswith("("):
            continue
        day = pacific_day(row.get("publish_at") or row.get("at") or "")
        if day is None or not (first <= day <= last):
            continue
        seen.add(vid)
        out.append(Video(video_id=vid, build=build, short=is_short(build), published=day))
    return out


def load_notes(build: str, research: Path) -> dict | None:
    path = research / f"{base_name(build)}.yaml"
    if not path.exists():
        return None
    import yaml
    loader = getattr(yaml, "CSafeLoader", yaml.SafeLoader)
    try:
        data = yaml.load(path.read_text(encoding="utf-8"), Loader=loader)
    except yaml.YAMLError:
        return None
    return data if isinstance(data, dict) else None


def label(videos: list[Video], research: Path, exists=None) -> None:
    cache: dict[str, dict | None] = {}
    for v in videos:
        key = base_name(v.build)
        if key not in cache:
            cache[key] = load_notes(v.build, research)
        notes = cache[key]
        v.genre = genre_of(notes)
        v.series = str((notes or {}).get("series") or "")
        v.thumb_type = classify_thumbnail(None if notes is None else notes.get("thumbnail"), exists)


# ---------------------------------------------------------------- Analytics（代わりの数字）

def windows(videos: list[Video], last: date) -> dict[date, list[str]]:
    """日ごとに「その日が公開から FIRST_DAYS 日以内」の動画を並べる（1日1回で引けるように）。"""
    out: dict[date, list[str]] = {}
    for v in videos:
        for k in range(FIRST_DAYS):
            day = v.published + timedelta(days=k)
            if day > last:
                break
            out.setdefault(day, []).append(v.video_id)
    return out


def apply_source_rows(videos: list[Video], rows: list[list]) -> None:
    """[video, source, views] の行を足し込む。"""
    by_id = {v.video_id: v for v in videos}
    for vid, source, views, *_ in rows:
        v = by_id.get(vid)
        if v is None:
            continue
        v.views += int(views)
        v.sources[source] = v.sources.get(source, 0) + int(views)
        if source in THUMB_SOURCES:
            v.thumb_views += int(views)


def fetch_sources(api, videos: list[Video], last: date) -> int:
    """公開から FIRST_DAYS 日の、動画×流入元の再生を引く。返り値は呼んだ回数。"""
    import time
    calls = 0
    for day, ids in sorted(windows(videos, last).items()):
        for i in range(0, len(ids), BATCH):
            query = api.reports().query(
                ids="channel==MINE", startDate=day.isoformat(), endDate=day.isoformat(),
                dimensions="video,insightTrafficSourceType", metrics="views",
                filters="video==" + ",".join(ids[i:i + BATCH]),
            )
            for attempt in range(3):     # 一度に多く頼むと 500（backendError）が返ることがある
                calls += 1
                try:
                    r = query.execute()
                    break
                except Exception as e:
                    if attempt == 2 or "500" not in str(e)[:40] and "backendError" not in str(e):
                        raise
                    time.sleep(2 * (attempt + 1))
            apply_source_rows(videos, r.get("rows", []))
    return calls


def last_data_day(api, today: date) -> date | None:
    """Analytics に数字が入っている最後の日（2〜3日遅れる）。"""
    r = api.reports().query(ids="channel==MINE", startDate=(today - timedelta(days=10)).isoformat(),
                            endDate=today.isoformat(), dimensions="day", metrics="views").execute()
    days = [date.fromisoformat(d) for d, n in r.get("rows", []) if n]
    return max(days) if days else None


# ---------------------------------------------------------------- Reporting API（表示回数・クリック率）

def reach_service():
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build as _build

    from src.upload import SCOPES, TOKEN_PATH
    creds = Credentials.from_authorized_user_file(str(ROOT / TOKEN_PATH), SCOPES)
    return _build("youtubereporting", "v1", credentials=creds), creds


def reach_status(rep) -> tuple[dict | None, str]:
    """(到達レポートのジョブ, 取れない理由)。ジョブがあれば理由は空。"""
    try:
        jobs = rep.jobs().list().execute().get("jobs", [])
    except Exception as e:     # googleapiclient.errors.HttpError
        text = str(e)
        if "SERVICE_DISABLED" in text or "has not been used" in text:
            return None, ("YouTube Reporting API がこのプロジェクトで無効（403 SERVICE_DISABLED）。"
                          "Google Cloud のコンソールで有効にする（無料）")
        if "insufficient" in text.lower() or "scope" in text.lower():
            return None, "今のトークンのスコープで Reporting API を読めない: " + text[:200]
        return None, "Reporting API の呼び出しに失敗: " + text[:200]
    for job in jobs:
        if job.get("reportTypeId") == REACH_REPORT:
            return job, ""
    return None, (f"到達レポート（{REACH_REPORT}）のジョブが無い。`--create-job` で作る"
                  "（作ってから約48時間後に、30日前からの分が落とせる）")


def parse_reach_csv(text: str) -> list[tuple[str, str, int, float]]:
    """到達レポートの CSV を (date, video_id, impressions, ctr) に。列は見出しの名前で引く。"""
    out = []
    for row in csv.DictReader(io.StringIO(text)):
        vid = row.get("video_id") or ""
        if not vid:
            continue
        try:
            imp = int(float(row.get("video_thumbnail_impressions") or 0))
            ctr = float(row.get("video_thumbnail_impressions_ctr") or 0)
        except ValueError:
            continue
        out.append((row.get("date") or "", vid, imp, ctr))
    return out


def aggregate_reach(rows: list[tuple[str, str, int, float]], unit: str = "auto"
                    ) -> tuple[dict[str, tuple[int, float]], str]:
    """動画ごとに (表示回数の合計, 表示回数で重みづけしたクリック率 %) を出す。

    公式の説明は「percentage（clicks / impressions）」で、0〜1 か 0〜100 かが文面から決まらない。
    auto は 1 を超える値が1つでもあれば %、無ければ割合（0〜1）とみなして % に直す。
    """
    if unit == "auto":
        unit = "percent" if any(c > 1 for *_, c in rows) else "fraction"
    scale = 1.0 if unit == "percent" else 100.0
    imp: dict[str, int] = {}
    clicks: dict[str, float] = {}
    for _, vid, n, c in rows:
        imp[vid] = imp.get(vid, 0) + n
        clicks[vid] = clicks.get(vid, 0.0) + n * c * scale / 100.0
    return ({vid: (n, (clicks[vid] / n * 100.0) if n else 0.0) for vid, n in imp.items()}, unit)


def fetch_reach(rep, creds, job_id: str, first: date, last: date) -> list[tuple[str, str, int, float]]:
    """ジョブのレポートを落として（控えに残し）、期間の行を返す。過去分は30日で消えるので控える。"""
    from google.auth.transport.requests import AuthorizedSession
    session = AuthorizedSession(creds)
    REACH_CACHE.mkdir(parents=True, exist_ok=True)
    reports, token = [], None
    while True:
        r = rep.jobs().reports().list(jobId=job_id, pageToken=token).execute()
        reports += r.get("reports", [])
        token = r.get("nextPageToken")
        if not token:
            break
    rows = []
    for rpt in reports:
        day = str(rpt.get("startTime", ""))[:10]
        if not day or not (first.isoformat() <= day <= last.isoformat()):
            continue
        cached = REACH_CACHE / f"{day}_{rpt.get('id')}.csv"
        if cached.exists():
            text = cached.read_text(encoding="utf-8")
        else:
            resp = session.get(rpt["downloadUrl"])
            resp.raise_for_status()
            text = resp.content.decode("utf-8")
            cached.write_text(text, encoding="utf-8")
        rows += parse_reach_csv(text)
    return rows


def create_job(rep) -> dict:
    return rep.jobs().create(body={"reportTypeId": REACH_REPORT, "name": "thumbctr"}).execute()


# ---------------------------------------------------------------- まとめ

def stats(values: list[float]) -> dict | None:
    if not values:
        return None
    return {"n": len(values), "median": statistics.median(values),
            "mean": statistics.fmean(values), "min": min(values), "max": max(values)}


def summarize(videos: list[Video]) -> list[dict]:
    """(本編/ショート, シリーズ/ニュース, 型) ごとの数字。"""
    groups: dict[tuple, list[Video]] = {}
    for v in videos:
        groups.setdefault(("ショート" if v.short else "本編", v.genre, v.thumb_type), []).append(v)
    out = []
    order = {t: i for i, t in enumerate(TYPES)}
    for (kind, genre, ttype), vs in sorted(groups.items(),
                                            key=lambda kv: (kv[0][0] != "本編", kv[0][1], order.get(kv[0][2], 99))):
        reach = [v for v in vs if v.impressions]
        out.append({
            "kind": kind, "genre": genre, "type": ttype, "n": len(vs),
            "from": min(v.published for v in vs).isoformat(),
            "to": max(v.published for v in vs).isoformat(),
            "views": stats([v.views for v in vs]),
            "thumb_views": stats([v.thumb_views for v in vs]),
            "impressions": stats([v.impressions for v in reach]),
            "ctr": stats([v.ctr for v in reach if v.ctr is not None]),
        })
    return out


def _fmt(s: dict | None, key: str, digits: int = 0) -> str:
    if not s:
        return "—"
    return f"{s[key]:.{digits}f}"


def _range(s: dict | None, digits: int = 0) -> str:
    if not s:
        return "—"
    return f"{s['min']:.{digits}f}〜{s['max']:.{digits}f}"


def render(summary: list[dict], videos: list[Video], reach_reason: str, first: date, last: date,
           today: date, calls: int, ctr_unit: str, dry_run: bool) -> str:
    lines = [f"# サムネの型ごとのクリック率（{today}）", ""]
    lines.append(f"- 対象：公開日（太平洋時間）{first}〜{last} の {len(videos)} 本"
                 f"（本編 {sum(not v.short for v in videos)}・ショート {sum(v.short for v in videos)}）。"
                 "取り直しは `python tools/thumbctr.py --out <このファイル>`")
    if reach_reason:
        lines.append(f"- **表示回数とクリック率は取れていない。**{reach_reason}")
        lines.append("  - YouTube Analytics API の `videoThumbnailImpressions`・`videoThumbnailImpressionsClickRate` は"
                     "どの組み合わせでも「The query is not supported」（10/5 に5通り試した）。"
                     "取れるのは Reporting API の到達レポート `channel_reach_basic_a1` だけ")
    else:
        lines.append(f"- 表示回数・クリック率は Reporting API の到達レポート（クリック率の単位の読み: {ctr_unit}）。"
                     "期間は対象の動画の公開日〜最後の日の合計")
    lines.append(f"- 代わりの数字：公開日を含む **{FIRST_DAYS}日間の再生**（Analytics）と、そのうち"
                 "**サムネが出る場所から来た再生**（ブラウジング・検索・関連動画・チャンネルページなど。"
                 "ショートのフィードは入れない）。**配られた量×クリック率なので、型の良し悪しだけを表す数字ではない**")
    lines.append(f"- Analytics の呼び出し {calls} 回。Data API の枠は使っていない" + ("（dry-run）" if dry_run else ""))
    lines.append(f"- 本数が {FEW} 本未満の型は「少ない」と書いた。中央値も平均も、その本数では揺れる")
    unknown = sum(1 for v in videos if v.thumb_type == T_UNKNOWN)
    if unknown:
        lines.append(f"- 取材メモが手元に無く型を決められなかった動画 {unknown} 本（表の「{T_UNKNOWN}」）")
    lines.append("")
    for kind in ("本編", "ショート"):
        rows = [s for s in summary if s["kind"] == kind]
        if not rows:
            continue
        lines.append(f"## {kind}" + ("（主に見るのはこちら）" if kind == "本編" else
                                     "（フィードではサムネが使われない。参考）"))
        lines.append("")
        for genre in GENRES:
            sel = [s for s in rows if s["genre"] == genre]
            if not sel:
                continue
            lines.append(f"### {kind}・{genre}")
            lines.append("")
            lines.append("| 型 | 本数 | 公開日 | 表示回数 中央値 | CTR 中央値 | CTR 平均 | CTR 幅 | "
                         f"{FIRST_DAYS}日の再生 中央値 | 平均 | 幅 | うちサムネ経由 中央値 | 平均 | 幅 |")
            lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
            for s in sel:
                few = "（少ない）" if s["n"] < FEW else ""
                lines.append(
                    f"| {s['type']} | {s['n']}{few} | {s['from'][5:]}〜{s['to'][5:]} | "
                    f"{_fmt(s['impressions'], 'median')} | {_fmt(s['ctr'], 'median', 1)} | "
                    f"{_fmt(s['ctr'], 'mean', 1)} | {_range(s['ctr'], 1)} | "
                    f"{_fmt(s['views'], 'median')} | {_fmt(s['views'], 'mean')} | {_range(s['views'])} | "
                    f"{_fmt(s['thumb_views'], 'median')} | {_fmt(s['thumb_views'], 'mean')} | "
                    f"{_range(s['thumb_views'])} |")
            lines.append("")
    lines += render_halves(videos, first, last)
    return "\n".join(lines) + "\n"


def halves(videos: list[Video], first: date, last: date) -> dict:
    """本編を期間の前半・後半に割って、(種類, 型) ごとの再生を集める。

    9月は登録者が増え続けていて、同じ型でも後半ほど再生が多い。型の差と時期の差を混ぜないため
    """
    mid = first + (last - first) / 2
    groups: dict = {}
    for v in videos:
        if v.short:
            continue
        half = 0 if v.published <= mid else 1
        groups.setdefault((v.genre, v.thumb_type), ([], []))[half].append(v.views)
    return {"mid": mid, "groups": groups}


def render_halves(videos: list[Video], first: date, last: date) -> list[str]:
    h = halves(videos, first, last)
    lines = [f"## 本編を前半（{first.isoformat()[5:]}〜{h['mid'].isoformat()[5:]}）と後半"
             f"（〜{last.isoformat()[5:]}）に割って（同じ時期で比べる）", "",
             f"{FIRST_DAYS}日の再生の中央値（本数）。登録者が増えるほど同じ型でも数字が上がるので、"
             "型どうしは同じ列の中で比べる", "",
             "| 種類 | 型 | 前半 | 後半 |", "|---|---|---|---|"]
    order = {t: i for i, t in enumerate(TYPES)}
    gorder = {g: i for i, g in enumerate(GENRES)}

    def cell(xs: list[int]) -> str:
        return f"{statistics.median(xs):.0f}（{len(xs)}）" if xs else "—"

    for (genre, ttype), (a, b) in sorted(h["groups"].items(),
                                         key=lambda kv: (gorder.get(kv[0][0], 9), order.get(kv[0][1], 99))):
        lines.append(f"| {genre} | {ttype} | {cell(a)} | {cell(b)} |")
    return lines + [""]


# ---------------------------------------------------------------- 実行

def run(posted: list[dict], today: date, days: int, api=None, fixture: dict | None = None,
        reach: tuple | None = None, research: Path | None = None, exists=None) -> tuple[str, list[Video], list[dict]]:
    """fixture: {"last_day": "YYYY-MM-DD", "rows": [[video, source, views], ...],
                 "reach_rows": [[date, video, impressions, ctr], ...]}（無ければ到達レポートは無し）"""
    research = research or ROOT / "research"
    dry = fixture is not None
    if dry:
        last = date.fromisoformat(fixture["last_day"])
    else:
        last = last_data_day(api, today) or today - timedelta(days=3)
    start = last - timedelta(days=days - 1)
    # 公開から FIRST_DAYS 日が丸ごと入る本だけを比べる（新しすぎる本は数字がまだ伸びる途中）
    newest = last - timedelta(days=FIRST_DAYS - 1)
    videos = pick_videos(posted, start, newest)
    label(videos, research, exists)
    calls = 0
    if dry:
        apply_source_rows(videos, fixture.get("rows", []))
    else:
        calls = fetch_sources(api, videos, last)
    reach_rows, reason = None, ""
    if dry:
        if "reach_rows" in fixture:
            reach_rows = [tuple(r) for r in fixture["reach_rows"]]
        else:
            reason = "（dry-run。到達レポートの行を渡していない）"
    else:
        rep, creds = reach if reach else reach_service()
        job, reason = reach_status(rep)
        if job:
            reach_rows = fetch_reach(rep, creds, job["id"], start, last)
            if not reach_rows:
                reason = (f"到達レポートのジョブ（{job.get('createTime', '')[:10]} 作成）はあるが、"
                          "期間の分がまだ落とせない（作ってから約48時間かかる）")
    unit = ""
    if reach_rows:
        per_video, unit = aggregate_reach(reach_rows)
        for v in videos:
            if v.video_id in per_video:
                v.impressions, v.ctr = per_video[v.video_id]
    summary = summarize(videos)
    text = render(summary, videos, reason, start, newest, today, calls, unit, dry)
    return text, videos, summary


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="サムネの型ごとのクリック率")
    parser.add_argument("--days", type=int, default=28)
    parser.add_argument("--out", help="結果の Markdown（同じ名前の .json に動画ごとの数字も残す）")
    parser.add_argument("--reach-status", action="store_true", help="到達レポートが取れる状態かだけ見る")
    parser.add_argument("--create-job", action="store_true",
                        help="到達レポートのジョブを作る（チャンネルに残る設定。ユーザーの OK のあとで）")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--fixture", help="--dry-run で使う数字（JSON）")
    parser.add_argument("--today", help="YYYY-MM-DD（既定は今日）")
    args = parser.parse_args(argv)

    if args.reach_status or args.create_job:
        rep, _ = reach_service()
        job, reason = reach_status(rep)
        if job:
            print(f"到達レポートのジョブあり: {job.get('id')}（{job.get('createTime', '')[:10]} 作成）")
            return 0
        print(reason)
        if args.create_job and "ジョブが無い" in reason:
            job = create_job(rep)
            print(f"作った: {job.get('id')}。約48時間後から、30日前からの分が落とせる")
        return 0

    today = date.fromisoformat(args.today) if args.today else date.today()
    posted = json.loads((ROOT / "research" / "posted.json").read_text(encoding="utf-8"))
    fixture = json.loads(Path(args.fixture).read_text(encoding="utf-8")) if args.fixture else None
    if args.dry_run and fixture is None:
        fixture = {"last_day": (today - timedelta(days=3)).isoformat(), "rows": []}
    api = None
    if fixture is None:
        from src import insights
        api = insights.service()
    text, videos, summary = run(posted, today, args.days, api=api, fixture=fixture)
    print(text)
    if args.out:
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text, encoding="utf-8")
        out.with_suffix(".json").write_text(json.dumps(
            {"videos": [{**asdict(v), "published": v.published.isoformat()} for v in videos],
             "summary": summary}, ensure_ascii=False, indent=1), encoding="utf-8")
        print("書いた:", out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
