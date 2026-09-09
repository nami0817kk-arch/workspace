"""YouTube Data API v3 での投稿（ローカル実行用）。

事前準備は docs/pipeline.md を参照。google-api-python-client と
google-auth-oauthlib が必要なので、requirements-upload.txt を入れてから使う。
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass, field
from pathlib import Path

from . import tags as tags_mod

# upload だけでは**公開済み動画の概要欄を書き換えられない**（403）。
# クレジットの形を直すたびに手作業になるので、force-ssl を足した
# （2026-09-06 ユーザーが同意画面にスコープを追加）。
# **強い権限なので、使うのは概要欄の更新まで。**削除には触らない
SCOPES = [
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.force-ssl",
    # 視聴維持率を読むための**読み取り専用**の権限
    # （2026-09-07 ユーザーが同意画面に追加）。動画には触れない
    "https://www.googleapis.com/auth/yt-analytics.readonly",
]
TOKEN_PATH = Path("secrets/token.json")
CLIENT_SECRET_PATH = Path("secrets/client_secret.json")


from . import quota


class UploadError(RuntimeError):
    pass


@dataclass
class Draft:
    """投稿の中身。送る前にそのまま見られるようにしておく。"""

    video: Path
    title: str
    description: str = ""
    tags: list[str] = field(default_factory=list)
    thumbnail: Path | None = None
    privacy: str = "private"
    source: Path | None = None

    @property
    def problems(self) -> list[str]:
        """このまま送ると弾かれるところ。"""
        found = list(tags_mod.problems(self.title, self.description, self.tags))
        if not self.video.exists():
            found.append(f"動画がありません: {self.video}")
        if not self.title.strip():
            found.append("タイトルが空です")
        # **書き出しの途中を掴んでいないか。**video.mp4 は先に書かれ、
        # description.txt と thumbnail.png は後から書かれる。その隙に投稿へ入ると
        # タイトルがフォルダ名・概要欄が空のまま公開される（2026-09-08 に発生）
        if self.source is not None and self.title.strip() == self.source.name:
            found.append("タイトルがフォルダ名のままです。"
                         "description.txt がまだ書かれていません")
        if not self.description.strip():
            found.append("概要欄が空です。書き出しの途中かもしれません")
        found += self._stale_meta()
        # サムネイルは**無くても止めない**。投稿のあとに setthumb で
        # 付ける流れが先にあり、そちらは今も使っている
        if self.thumbnail is not None and not self.thumbnail.exists():
            found.append(f"サムネイルがありません: {self.thumbnail}")
        if self.privacy not in ("private", "unlisted", "public"):
            found.append(f"privacy は private/unlisted/public のいずれか: {self.privacy}")
        return found

    def _stale_meta(self) -> list[str]:
        """動画より古い説明・タグを掴んでいないか（2026-09-08）。

        バレンシアの回で、**動画は作り直したもの、タグは前の作り直しのもの**を
        送ってしまった。動画が書き上がった時点で投稿側の合図が立ち、
        description.txt と script.json はそのあとに書かれるので、
        1本ぶんずれる隙がある。「動画があること」だけを合図にしていたのが穴。

        揃っていれば同じ書き出しの産物なので、動画より古い説明は前の回のもの。
        """
        if self.source is None or not self.video.exists():
            return []
        video_at = self.video.stat().st_mtime
        late = []
        for name in ("description.txt", "script.json"):
            path = self.source / name
            if not path.exists():
                late.append(f"{name} がありません")
            elif path.stat().st_mtime < video_at - 1:
                late.append(f"{name} が動画より古いです")
        if late:
            return ["／".join(late) + "。前の書き出しの説明やタグを送ろうとしています"]
        return []

    def lines(self) -> list[str]:
        """何が送られるかを1画面で見せる。"""
        size = self.video.stat().st_size / 1_000_000 if self.video.exists() else 0.0
        head = self.description.strip().splitlines()
        return [
            f"タイトル　{self.title}　（{len(self.title)}字）",
            f"公開設定　{self.privacy}",
            f"動画　　　{self.video}　{size:.1f}MB",
            f"サムネ　　{self.thumbnail if self.thumbnail else '（無し）'}",
            f"タグ　　　{len(self.tags)}個 / 合計{tags_mod.text_length(self.tags)}字",
            f"　　　　　{' / '.join(self.tags) or '（無し）'}",
            f"概要欄　　{len(self.description)}字　先頭: {head[0][:40] if head else '（空）'}",
        ]


def prepare(build_dir: Path, privacy: str = "private") -> Draft:
    """書き出したディレクトリから、投稿の中身を組み立てる。

    タグは台本にしか無い（description.txt は本文だけ）。
    ビルドが書いた script.json から取る。
    """
    build_dir = Path(build_dir)
    text = ""
    description_file = build_dir / "description.txt"
    if description_file.exists():
        text = description_file.read_text(encoding="utf-8")
    title, _, body = text.partition("\n")

    found: list[str] = []
    script_json = build_dir / "script.json"
    if script_json.exists():
        try:
            data = json.loads(script_json.read_text(encoding="utf-8"))
            found = [str(tag) for tag in (data.get("tags") or [])]
        except (OSError, ValueError):
            found = []

    thumbnail = build_dir / "thumbnail.png"
    return Draft(
        video=build_dir / "video.mp4",
        title=title.strip() or build_dir.name,
        description=body.strip(),
        tags=tags_mod.fit(found),
        thumbnail=thumbnail if thumbnail.exists() else None,
        privacy=privacy,
        source=build_dir,
    )


def recently_uploaded(service, title: str, minutes: int = 90) -> str | None:
    """同じ題名の動画が、この少し前に上がっていないか（2026-09-09）。

    **投稿は成功したのに、その控えを残す前に処理が終わることがある。**
    実際に起きた: 投稿中の python を止めたら、呼び出し側が「失敗した」と見て
    掛け直し、上田の本編が2本・バロンドールのショートが3本上がった。
    掛け直す前にここを見れば、二度目を投げずに済む。
    """
    from datetime import datetime, timedelta, timezone

    quota.record("playlistItems.list")
    channel = service.channels().list(part="contentDetails", mine=True).execute()
    uploads = channel["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"]
    got = service.playlistItems().list(part="snippet", playlistId=uploads,
                                       maxResults=15).execute()
    edge = datetime.now(timezone.utc) - timedelta(minutes=minutes)
    wanted = title.strip()
    for item in got.get("items") or []:
        snippet = item["snippet"]
        when = snippet.get("publishedAt") or ""
        try:
            at = datetime.fromisoformat(when.replace("Z", "+00:00"))
        except ValueError:
            continue
        if at >= edge and snippet.get("title", "").strip() == wanted:
            return str(snippet["resourceId"]["videoId"])
    return None


def when_to_publish(clock: str, now=None) -> str:
    """公開時刻を RFC3339（UTC）にする。2つの書き方を受ける。

    ``07:30``  … 今日のその時刻。**過ぎていたら止める**（2026-09-09）。
                 09:00 を指定したのが 09:11 で、黙って翌日の09:00に回り、
                 6本ぜんぶ1日ずれるところだった。黙って明日に回さない。
    ``+45``    … いまから45分後。**並べて予約するときはこちら。**
                 時計の時刻だと、書き出しに手間取ったぶんだけ過ぎてしまう。
    """
    from datetime import datetime, timedelta, timezone

    jst = timezone(timedelta(hours=9))
    now = now or datetime.now(jst)
    if now.tzinfo is None:
        now = now.replace(tzinfo=jst)
    now = now.astimezone(jst)

    text = str(clock).strip()
    if text.startswith("+"):
        try:
            minutes = int(text[1:])
        except ValueError as exc:
            raise UploadError(f"+のあとは分の数で渡してください: {clock}") from exc
        if minutes < 15:
            raise UploadError("予約は15分より先にしてください（それより近いなら --at を外す）")
        target = now + timedelta(minutes=minutes)
    else:
        try:
            hour, minute = (int(x) for x in text.split(":"))
        except ValueError as exc:
            raise UploadError(f"時刻は 07:30 か +45 の形で渡してください: {clock}") from exc
        target = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
        if target <= now + timedelta(minutes=1):
            raise UploadError(
                f"{text} はもう過ぎています（いま {now:%H:%M}）。"
                "**黙って明日に回しません。**先の時刻にするか、+45 のように分で渡してください")
    return target.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _load_deps():
    try:
        from google.auth.transport.requests import Request
        from google.oauth2.credentials import Credentials
        from google_auth_oauthlib.flow import InstalledAppFlow
        from googleapiclient.discovery import build
        from googleapiclient.http import MediaFileUpload
    except ImportError as exc:
        raise UploadError(
            "投稿用の依存が未インストールです: pip install -r requirements-upload.txt"
        ) from exc
    return Request, Credentials, InstalledAppFlow, build, MediaFileUpload


def get_service(client_secret: Path = CLIENT_SECRET_PATH, token: Path = TOKEN_PATH):
    Request, Credentials, InstalledAppFlow, build, _ = _load_deps()
    credentials = None
    if token.exists():
        credentials = Credentials.from_authorized_user_file(str(token), SCOPES)
    if not credentials or not credentials.valid:
        if credentials and credentials.expired and credentials.refresh_token:
            credentials.refresh(Request())
        else:
            if not client_secret.exists():
                raise UploadError(
                    f"OAuth クライアント情報がありません: {client_secret}\n"
                    "Google Cloud で YouTube Data API v3 を有効化し、"
                    "デスクトップアプリの client_secret.json を配置してください。"
                )
            flow = InstalledAppFlow.from_client_secrets_file(str(client_secret), SCOPES)
            credentials = flow.run_local_server(port=0)
        token.parent.mkdir(parents=True, exist_ok=True)
        token.write_text(credentials.to_json(), encoding="utf-8")
    return build("youtube", "v3", credentials=credentials)


def fetch_snippet(service, video_id: str) -> dict:
    """いまの題名・概要欄・タグを取る。**書き換える前に、現物を見る。**"""
    quota.record("videos.list")
    got = service.videos().list(part="snippet", id=video_id).execute()
    items = got.get("items") or []
    if not items:
        raise UploadError(f"動画が見つかりません: {video_id}")
    return items[0]["snippet"]


def set_thumbnail(service, video_id: str, thumbnail: Path) -> str:
    """サムネイルだけを後から設定する。

    **投稿し直さない。**短時間に何本も上げると、動画は通るのに
    サムネイルだけ 429（uploadRateLimitExceeded）で落ちることがある
    （2026-09-06 実測。6本まとめて上げて6本ともこれだった）。
    投稿からやり直すと同じ動画が二重に上がるので、ここだけを叩く。
    """
    if not thumbnail.exists():
        raise UploadError(f"サムネイルがありません: {thumbnail}")
    service.thumbnails().set(videoId=video_id, media_body=str(thumbnail)).execute()
    return video_id


def set_privacy(service, video_id: str, privacy: str = "public") -> str:
    """公開設定だけを変える。

    **status も部分更新ができない。**渡さなかった項目は消えるので、
    取ってきたものを詰め直す（snippet と同じ落とし穴）。
    """
    if privacy not in ("private", "unlisted", "public"):
        raise UploadError(f"知らない公開設定です: {privacy}")
    quota.record("videos.list")
    got = service.videos().list(part="status", id=video_id).execute()
    items = got.get("items") or []
    if not items:
        raise UploadError(f"動画が見つかりません: {video_id}")
    status = dict(items[0]["status"])
    status["privacyStatus"] = privacy
    quota.record("videos.update")
    service.videos().update(
        part="status", body={"id": video_id, "status": status}).execute()
    return video_id


def add_credits(current: str, top: list[str], tail: list[str]) -> str:
    """いまの概要欄に、クレジットだけを足す。

    **丸ごと差し替えない。**公開中の動画と手元の台本は尺が違うことがあり
    （実測 2026-09-06: 公開 2分03秒 / 手元 1分52秒）、章の時刻が11秒ずれる。
    足したいのはクレジットであって、章を直したいわけではない。

    上の行は「音声:」のすぐ下、詳細はいちばん末尾に置く。
    すでに入っている行は足さない（何度実行しても増えない）。
    """
    nl = chr(10)
    lines = current.split(nl)
    have = set(current.split(nl))

    for one in reversed([x for x in top if x not in have]):
        at = next((i for i, ln in enumerate(lines) if ln.startswith("音声:")), None)
        if at is None:
            at = len(lines) - 1
        lines.insert(at + 1, one)

    missing = [x for x in tail if x not in have]
    if missing:
        rule = "─" * 12
        body = lines + ([""] if lines and lines[-1] else [])
        if rule not in have:
            body.append(rule)
        body.extend(missing)
        lines = body
    return nl.join(lines).rstrip() + nl


def update_description(service, video_id: str, description: str) -> str:
    """概要欄だけを差し替える。

    **題名・タグ・カテゴリはそのまま返す。**snippet は部分更新ができず、
    渡さなかった項目は消える。取ってきたものを詰め直すのが唯一の安全策。
    """
    snippet = fetch_snippet(service, video_id)
    snippet["description"] = description[:5000]
    quota.record("videos.update")
    service.videos().update(
        part="snippet", body={"id": video_id, "snippet": snippet}).execute()
    return video_id


def upload(
    video_path: Path,
    title: str,
    description: str = "",
    tags: list[str] | None = None,
    privacy: str = "private",
    category_id: str = "22",
    thumbnail: Path | None = None,
    publish_at: str = "",
) -> str:
    """動画を投稿して videoId を返す。既定は限定公開ではなく非公開(private)。"""
    draft = Draft(
        video=video_path, title=title, description=description,
        tags=list(tags or []), thumbnail=thumbnail, privacy=privacy,
    )
    if draft.problems:
        raise UploadError("このままでは投稿できません:\n  - " + "\n  - ".join(draft.problems))

    *_, MediaFileUpload = _load_deps()
    service = get_service()
    body = {
        "snippet": {
            "title": title[:100],
            "description": description[:5000],
            "tags": (tags or [])[:30],
            "categoryId": category_id,
        },
        "status": {"privacyStatus": privacy, "selfDeclaredMadeForKids": False},
    }
    if publish_at:
        # **予約公開**（2026-09-09）。昨夜は12本を86分で投げ、間隔の中央値が6分
        # だった（こちらのコード自身が45分と警告していた）。朝に出した6本は
        # 435〜993回、夜に出した6本は0〜35回。時刻を選べるようにする。
        # YouTube の決まりで、予約するあいだは private でなければならない
        body["status"]["privacyStatus"] = "private"
        body["status"]["publishAt"] = publish_at
    media = MediaFileUpload(str(video_path), chunksize=-1, resumable=True)
    quota.record("videos.insert")
    request = service.videos().insert(part="snippet,status", body=body, media_body=media)

    response = None
    while response is None:
        status, response = request.next_chunk()
        if status:
            print(f"  アップロード {int(status.progress() * 100)}%")
    video_id = response["id"]

    if thumbnail and thumbnail.exists():
        quota.record("thumbnails.set")
        # **サムネで落ちても、動画はもう上がっている。**ここで例外を投げると
        # 呼ぶ側は「投稿に失敗した」と見て掛け直し、同じ動画が2本になる。
        # 2026-09-08 に thumbnails.set の 429（サムネの送りすぎ）でそれが起き、
        # サンチョのショートが2本、CLの本編が2本公開された。
        # サムネは後から setthumb で付け直せるので、ここは警告だけにして id を返す
        try:
            service.thumbnails().set(videoId=video_id, media_body=str(thumbnail)).execute()
        except Exception as err:  # noqa: BLE001 - 何が来ても動画の id は返す
            print(f"! サムネイルは付きませんでした（{str(err)[:80]}）。"
                  f"動画は上がっています: {video_id}。あとで setthumb で付けてください",
                  file=sys.stderr)
    return video_id
