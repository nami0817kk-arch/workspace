"""YouTube への予約投稿（歴史の地層のチャンネル）。

サッカーのチャンネル（projects/youtube-video-creation/src/upload.py）で踏んで直したことを写してある：
- 予約公開は private ＋ publishAt
- サムネイルで落ちても動画の id は返す（掛け直すと同じ動画が2本になる。2026-09-08 に実際に起きた）
- 掛け直す前に、同じ題名が少し前に上がっていないかを見る（二重投稿の防止）
- 認証が失効していたら、同意画面からやり直す（prompt=consent で毎回 refresh token を出させる）
新しく足したもの：字幕ファイル（SRT）の登録、控え（posted.json）。

鍵と許可はリポジトリの外に置く（workspace は public）：
    C:/Users/なみ/dev/output/rekishi-chiso/secrets/client_secret.json   … Google Cloud「rekishi-chiso」のクライアント
    C:/Users/なみ/dev/output/rekishi-chiso/secrets/token.json           … 「歴史の地層」のチャンネルを選んで許可したもの
API の枠はサッカーと分けてある（別の Google Cloud プロジェクト。2026-10-04 ユーザー決定）。
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

SCOPES = [
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.force-ssl",     # 字幕の登録と、公開後の概要欄の直しに使う
]
SECRETS = Path(os.environ.get("CHISO_SECRETS", r"C:/Users/なみ/dev/output/rekishi-chiso/secrets"))
JST = timezone(timedelta(hours=9))
OPEN_HOUR, CLOSE_HOUR = 9, 24        # 公開は9時から24時（チャンネル共通の決まり）
CATEGORY_EDUCATION = "27"


class UploadError(RuntimeError):
    pass


def _deps():
    try:
        from google.auth.transport.requests import Request
        from google.oauth2.credentials import Credentials
        from google_auth_oauthlib.flow import InstalledAppFlow
        from googleapiclient.discovery import build
        from googleapiclient.http import MediaFileUpload
    except ImportError as exc:
        raise UploadError("投稿用の依存がありません: pip install -r requirements-upload.txt") from exc
    return Request, Credentials, InstalledAppFlow, build, MediaFileUpload


def service(secrets: Path = SECRETS):
    Request, Credentials, InstalledAppFlow, build, _ = _deps()
    token, client = secrets / "token.json", secrets / "client_secret.json"
    cred = Credentials.from_authorized_user_file(str(token), SCOPES) if token.exists() else None
    if not cred or not cred.valid:
        refreshed = False
        if cred and cred.expired and cred.refresh_token:
            try:
                cred.refresh(Request())
                refreshed = True
            except Exception as err:  # noqa: BLE001
                if "invalid_grant" not in str(err):
                    raise
                print("■ 保存してある許可が失効していました。同意画面を開きます")
                token.replace(token.with_name("token.json.revoked"))
        if not refreshed:
            if not client.exists():
                raise UploadError(f"クライアント情報がありません: {client}（Google Cloud の rekishi-chiso から）")
            print("■ ブラウザで許可の画面を開きます。**「歴史の地層」のチャンネルを選んで**許可してください")
            cred = InstalledAppFlow.from_client_secrets_file(str(client), SCOPES).run_local_server(
                port=0, prompt="consent")
        token.parent.mkdir(parents=True, exist_ok=True)
        token.write_text(cred.to_json(), encoding="utf-8")
    return build("youtube", "v3", credentials=cred)


def channel_title(svc) -> str:
    got = svc.channels().list(part="snippet", mine=True).execute()
    items = got.get("items") or []
    return items[0]["snippet"]["title"] if items else ""


def publish_time(text: str, now: datetime | None = None) -> str:
    """'2026-10-05 19:00'（日本時間）を RFC3339（UTC）にする。過去と、9時〜24時の外は止める。"""
    now = now or datetime.now(JST)
    try:
        at = datetime.strptime(text.strip(), "%Y-%m-%d %H:%M").replace(tzinfo=JST)
    except ValueError as exc:
        raise UploadError(f"公開時刻は 'YYYY-MM-DD HH:MM'（日本時間）で書きます: {text}") from exc
    if at <= now + timedelta(minutes=15):
        raise UploadError(f"公開時刻が過ぎているか近すぎます（15分以上先にする）: {text}")
    if not (OPEN_HOUR <= at.hour < CLOSE_HOUR):
        raise UploadError(f"公開は {OPEN_HOUR}時から{CLOSE_HOUR}時のあいだにします: {text}")
    return at.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def recently_uploaded(svc, title: str, minutes: int = 180) -> str | None:
    """同じ題名の動画が少し前に上がっていないか（掛け直しで2本にしないため）。"""
    ch = svc.channels().list(part="contentDetails", mine=True).execute()
    uploads = ch["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"]
    got = svc.playlistItems().list(part="snippet", playlistId=uploads, maxResults=15).execute()
    edge = datetime.now(timezone.utc) - timedelta(minutes=minutes)
    for item in got.get("items") or []:
        sn = item["snippet"]
        try:
            at = datetime.fromisoformat((sn.get("publishedAt") or "").replace("Z", "+00:00"))
        except ValueError:
            continue
        if at >= edge and sn.get("title", "").strip() == title.strip():
            return str(sn["resourceId"]["videoId"])
    return None


def upload(svc, video: Path, title: str, description: str, tags: list[str], publish_at: str,
           thumbnail: Path | None = None, captions: Path | None = None, made_for_kids: bool = False) -> str:
    """予約投稿して videoId を返す。サムネイルと字幕は落ちても警告だけ（あとで付け直せる）。"""
    *_, MediaFileUpload = _deps()
    if not video.exists():
        raise UploadError(f"動画がありません: {video}")
    dup = recently_uploaded(svc, title)
    if dup:
        raise UploadError(f"同じ題名の動画がもう上がっています: https://youtu.be/{dup}（掛け直さない）")
    body = {
        "snippet": {"title": title[:100], "description": description[:5000], "tags": tags[:30],
                    "categoryId": CATEGORY_EDUCATION, "defaultLanguage": "ja", "defaultAudioLanguage": "ja"},
        "status": {"privacyStatus": "private", "publishAt": publish_at,
                   "selfDeclaredMadeForKids": made_for_kids},
    }
    req = svc.videos().insert(part="snippet,status", body=body,
                              media_body=MediaFileUpload(str(video), chunksize=-1, resumable=True))
    resp = None
    while resp is None:
        status, resp = req.next_chunk()
        if status:
            print(f"  アップロード {int(status.progress() * 100)}%")
    vid = resp["id"]
    if thumbnail and thumbnail.exists():
        try:
            svc.thumbnails().set(videoId=vid, media_body=str(thumbnail)).execute()
        except Exception as err:  # noqa: BLE001 - 動画はもう上がっている
            print(f"! サムネイルは付きませんでした（{str(err)[:80]}）。あとで thumb-set で付けてください")
    if captions and captions.exists():
        try:
            svc.captions().insert(part="snippet", body={"snippet": {"videoId": vid, "language": "ja",
                                                                     "name": "日本語", "isDraft": False}},
                                  media_body=MediaFileUpload(str(captions), mimetype="application/octet-stream")
                                  ).execute()
        except Exception as err:  # noqa: BLE001
            print(f"! 字幕は付きませんでした（{str(err)[:80]}）")
    return vid


def record(log: Path, entry: dict) -> None:
    """投稿の控え（同じ台本を二度出さないため）。"""
    data = json.loads(log.read_text(encoding="utf-8")) if log.exists() else []
    data.append(entry)
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def already_posted(log: Path, key: str) -> dict | None:
    if not log.exists():
        return None
    for e in json.loads(log.read_text(encoding="utf-8")):
        if e.get("key") == key:
            return e
    return None
