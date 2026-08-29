"""YouTube Data API v3 での投稿（ローカル実行用）。

事前準備は docs/pipeline.md を参照。google-api-python-client と
google-auth-oauthlib が必要なので、requirements-upload.txt を入れてから使う。
"""

from __future__ import annotations

from pathlib import Path

SCOPES = ["https://www.googleapis.com/auth/youtube.upload"]
TOKEN_PATH = Path("secrets/token.json")
CLIENT_SECRET_PATH = Path("secrets/client_secret.json")


class UploadError(RuntimeError):
    pass


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


def upload(
    video_path: Path,
    title: str,
    description: str = "",
    tags: list[str] | None = None,
    privacy: str = "private",
    category_id: str = "22",
    thumbnail: Path | None = None,
) -> str:
    """動画を投稿して videoId を返す。既定は限定公開ではなく非公開(private)。"""
    if privacy not in ("private", "unlisted", "public"):
        raise UploadError(f"privacy は private/unlisted/public のいずれか: {privacy}")
    if not video_path.exists():
        raise UploadError(f"動画がありません: {video_path}")

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
    media = MediaFileUpload(str(video_path), chunksize=-1, resumable=True)
    request = service.videos().insert(part="snippet,status", body=body, media_body=media)

    response = None
    while response is None:
        status, response = request.next_chunk()
        if status:
            print(f"  アップロード {int(status.progress() * 100)}%")
    video_id = response["id"]

    if thumbnail and thumbnail.exists():
        service.thumbnails().set(videoId=video_id, media_body=str(thumbnail)).execute()
    return video_id
